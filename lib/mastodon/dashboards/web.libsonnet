local cfg = import '../config.libsonnet';
local logs = import '../logs.libsonnet';
local h = import './helpers.libsonnet';

{
  dashboard(config=cfg)::
    local logSearchVar = {
      name: 'web_log_search',
      label: 'Web log search',
      type: 'textbox',
      query: '.*',
      current: { text: '.*', value: '.*' },
    };
    local base = h.baseDashboard(config {
      extraTemplating: [logSearchVar],
      logsDatasource: config.grafana.logsDatasource,
    }, 'Mastodon Web', 'mastodon-web');
    base {
      panels: [
        h.statPanel(config, 1, 'Availability (5m)', 'mastodon:web_availability:availability_5m{namespace="$namespace"}', 'percentunit', 0, 0, description='User-facing success ratio over the last 5m; 1.0 means no 5xx.'),
        h.statPanel(config, 2, 'Availability (30d)', 'mastodon:web_availability:availability_30d{namespace="$namespace"}', 'percentunit', 4, 0, description='Long-window availability to gauge SLO burn over the period.'),
        // TODO(traefik-refactor): Verify edge APDEX series now reflect Traefik-derived recordings.
        h.statPanel(config, 3, 'APDEX (edge)', 'mastodon:edge_apdex:overall{namespace="$namespace"}', 'none', 8, 0, description='Traefik edge APDEX (100/500ms) excluding streaming routes; reflects user experience.'),

        h.timeseriesPanel(config, 4, 'Latency percentiles', [
          { expr: 'mastodon:web_latency:p50_seconds{namespace="$namespace"}', legendFormat: 'p50' },
          { expr: 'mastodon:web_latency:p90_seconds{namespace="$namespace"}', legendFormat: 'p90' },
          { expr: 'mastodon:web_latency:p99_seconds{namespace="$namespace"}', legendFormat: 'p99' },
        ], 's', 0, 5, 12, 8, description='User-facing response time percentiles from app summaries (diagnostic).'),

        h.timeseriesPanel(config, 5, 'APDEX (edge) over time', [
          { expr: 'mastodon:edge_apdex:overall{namespace="$namespace"}', legendFormat: 'overall' },
          { expr: 'mastodon:edge_apdex:app{namespace="$namespace",ingress!=""}', legendFormat: '{{ingress}} app' },
          { expr: 'mastodon:edge_apdex:static{namespace="$namespace",ingress!=""}', legendFormat: '{{ingress}} static' },
        ], 'none', 12, 5, 12, 8, description='Edge APDEX by ingress to spot latency regressions users actually feel.'),

        h.timeseriesPanel(config, 6, 'SQL vs app latency', [
          { expr: 'mastodon:web_latency:sql_avg_seconds{namespace="$namespace"}', legendFormat: 'SQL' },
          { expr: 'mastodon:web_latency:redis_avg_seconds{namespace="$namespace"}', legendFormat: 'Redis' },
          { expr: 'mastodon:web_latency:queue_avg_seconds{namespace="$namespace"}', legendFormat: 'Queue' },
          { expr: 'mastodon:web_latency:app_avg_seconds{namespace="$namespace"}', legendFormat: 'App only' },
        ], 's', 12, 5, 12, 8, description='Avg latency components for user-facing requests; use to isolate slow layers.'),

        h.timeseriesPanel(config, 7, '5xx error rate', [
          { expr: 'mastodon:web_requests_user:errors5m{namespace="$namespace"}', legendFormat: 'errors/sec' },
        ], 'p/s', 0, 13, 12, 7, description='User-facing 5xx per second (matching availability SLO scope).'),

        h.timeseriesPanel(config, 8, 'Request classification', [
          { expr: 'mastodon:web_requests_user:rate5m{namespace="$namespace"}', legendFormat: 'user-facing' },
          { expr: 'mastodon:web_requests_federation:rate5m{namespace="$namespace"}', legendFormat: 'federation' },
          { expr: 'mastodon:web_requests_uncategorized:rate5m{namespace="$namespace"}', legendFormat: 'other' },
        ], 'p/s', 12, 13, 12, 7, description='Traffic mix split by controller/action regexes; validates classification.'),

        h.timeseriesPanel(config, 9, 'CPU usage (total)', [
          { expr: 'sum by (namespace) (rate(container_cpu_usage_seconds_total{namespace="$namespace",pod=~"mastodon-web.*",container!=""}[5m]))', legendFormat: 'total usage' },
        ], 'cores', 0, 20, 12, 8, description='Total CPU for web pods; compare to requests/limits elsewhere for headroom.'),

        h.timeseriesPanel(config, 10, 'Memory usage (total)', [
          { expr: 'sum by (namespace) (container_memory_working_set_bytes{namespace="$namespace",pod=~"mastodon-web.*",container!=""})', legendFormat: 'total usage' },
        ], 'bytes', 12, 20, 12, 8, description='Total memory for web pods; track against OOM/limits.'),

        h.timeseriesPanel(config, 11, 'Puma capacity', [
          { expr: 'ruby_puma_running_threads{namespace="$namespace",pod!=""}', legendFormat: '{{pod}} running' },
          { expr: 'ruby_puma_thread_pool_capacity{namespace="$namespace",pod!=""}', legendFormat: '{{pod}} capacity' },
          { expr: 'ruby_puma_max_threads{namespace="$namespace",pod!=""}', legendFormat: '{{pod}} max' },
        ], 'none', 0, 28, 12, 8, description='Per-pod thread usage vs capacity/max; rising to capacity signals saturation.'),

        h.timeseriesPanel(config, 12, 'Puma backlog', [
          { expr: 'ruby_puma_request_backlog{namespace="$namespace",pod!=""}', legendFormat: '{{pod}} backlog' },
        ], 'none', 12, 28, 12, 8, description='Queued requests waiting for a free Puma thread; should stay near zero.'),

        h.timeseriesPanel(config, 13, 'DB pool utilization', [
          { expr: 'sum by (namespace, pod) (ruby_active_record_connection_pool_busy{namespace="$namespace"}) / clamp_min(sum by (namespace, pod) (ruby_active_record_connection_pool_size{namespace="$namespace"}), 1)', legendFormat: '{{pod}} busy/size' },
        ], 'percentunit', 0, 36, 12, 8, description='Busy/size per pod for DB pool; near 1 indicates connection starvation.'),

        h.timeseriesPanel(config, 14, 'DB pool waiters', [
          { expr: 'ruby_active_record_connection_pool_waiting{namespace="$namespace",pod!=""}', legendFormat: '{{pod}} waiting' },
        ], 'none', 12, 36, 12, 8, description='Requests waiting for a DB connection; any sustained >0 implies bottleneck.'),

        h.timeseriesPanel(config, 15, 'Top controllers by request rate', [
          { expr: 'topk(5, sum by (namespace, controller, action) (rate(ruby_http_requests_total{namespace="$namespace"}[5m])))', legendFormat: '{{controller}}#{{action}}' },
        ], 'p/s', 0, 44, 12, 8, description='Highest request rates by controller/action over 5m to spot noisy routes.'),

        h.timeseriesPanel(config, 16, 'Top controllers by avg latency', [
          { expr: 'topk(5, sum by (namespace, controller, action) (rate(ruby_http_request_duration_seconds_sum{namespace="$namespace"}[5m])) / clamp_min(sum by (namespace, controller, action) (rate(ruby_http_request_duration_seconds_count{namespace="$namespace"}[5m])), 1e-6))', legendFormat: '{{controller}}#{{action}}' },
        ], 's', 12, 44, 12, 8, description='Slowest controllers by mean latency; target optimizations here first.'),

        h.timeseriesPanel(config, 17, 'Ruby heap slots', [
          { expr: 'ruby_heap_live_slots{namespace="$namespace",pod!=""}', legendFormat: '{{pod}} live' },
          { expr: 'ruby_heap_free_slots{namespace="$namespace",pod!=""}', legendFormat: '{{pod}} free' },
        ], 'none', 0, 52, 12, 8, description='Live vs free heap slots per pod; persistent growth hints at leaks.'),

        h.timeseriesPanel(config, 18, 'GC operations rate', [
          { expr: 'rate(ruby_major_gc_ops_total{namespace="$namespace"}[5m])', legendFormat: 'major/s' },
          { expr: 'rate(ruby_minor_gc_ops_total{namespace="$namespace"}[5m])', legendFormat: 'minor/s' },
          { expr: 'rate(ruby_marking_time{namespace="$namespace"}[5m])', legendFormat: 'marking time/s' },
          { expr: 'rate(ruby_sweeping_time{namespace="$namespace"}[5m])', legendFormat: 'sweeping time/s' },
        ], 'none', 12, 52, 12, 8, description='GC activity rates; spikes can explain latency or CPU jumps.'),

        h.statPanel(config, 19, 'Exporter healthy', 'min by (namespace) (ruby_collector_working{namespace="$namespace"})', 'none', 0, 60, 4, 5, description='Exporter self-check; should be 1.'),
        h.statPanel(config, 20, 'Bad metrics seen', 'sum by (namespace) (increase(ruby_collector_bad_metrics_total{namespace="$namespace"}[1h]))', 'none', 4, 60, 4, 5, description='Bad metrics processed in last hour (summed across web pods); rising counts imply exporter issues.'),

        {
          id: 21,
          type: 'logs',
          title: 'Web logs (last 30m)',
          gridPos: { x: 0, y: 65, w: 24, h: 16 },
          datasource: logs.logs(config).datasource,
          options: {
            query: { query: '', refId: 'A', expr: '', intervals: [] },
            queryType: 'logs',
            timeFrom: 'now-30m',
            timeTo: 'now',
            derivedFields: [],
            limit: 100,
          },
          targets: [
            {
              refId: 'A',
              datasource: logs.logs(config).datasource,
              queryType: 'logs',
              expr:
                'kubernetes.pod_namespace:~$namespace and ' +
                'kubernetes.pod_name:~"^mastodon-web" and ' +
                '_msg:~$web_log_search',
            },
          ],
        },
      ],
    },
}
