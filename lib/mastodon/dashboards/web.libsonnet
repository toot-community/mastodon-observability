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
        h.statPanel(config, 3, 'APDEX (edge)', 'mastodon:edge_apdex:overall{namespace="$namespace"}', 'none', 8, 0, description='Traefik edge APDEX (100/500ms) excluding streaming routes; reflects user experience.'),

        h.timeseriesPanel(config, 4, 'Latency percentiles (edge)', [
          { expr: 'mastodon:edge_latency_p50{namespace="$namespace",ingress="varnish-for-app"}', legendFormat: 'p50 app ingress' },
          { expr: 'mastodon:edge_latency_p90{namespace="$namespace",ingress="varnish-for-app"}', legendFormat: 'p90 app ingress' },
          { expr: 'mastodon:edge_latency_p99{namespace="$namespace",ingress="varnish-for-app"}', legendFormat: 'p99 app ingress' },
        ], 's', 0, 5, 12, 8, description='Edge latency percentiles from Traefik buckets for app ingress (user-facing).'),

        h.timeseriesPanel(config, 22, 'Rails pod latency (approx)', [
          { expr: 'ruby_http_request_duration_seconds{namespace="$namespace",pod!="",quantile="0.5",controller!~"^(media_proxy)$"}', legendFormat: '{{pod}} p50' },
          { expr: 'ruby_http_request_duration_seconds{namespace="$namespace",pod!="",quantile="0.9",controller!~"^(media_proxy)$"}', legendFormat: '{{pod}} p90' },
          { expr: 'ruby_http_request_duration_seconds{namespace="$namespace",pod!="",quantile="0.99",controller!~"^(media_proxy)$"}', legendFormat: '{{pod}} p99' },
        ], 's', 0, 13, 12, 7, description='Diagnostic pod-level Rails latency. Not used for SLO. Does not represent global percentiles.'),

        h.timeseriesPanel(config, 23, 'Rails controllers latency (approx, top)', [
          { expr: 'topk(5, ruby_http_request_duration_seconds{namespace="$namespace",pod!="",quantile="0.5",controller!~"^(media_proxy)$"})', legendFormat: '{{controller}}/{{pod}} p50' },
          { expr: 'topk(5, ruby_http_request_duration_seconds{namespace="$namespace",pod!="",quantile="0.9",controller!~"^(media_proxy)$"})', legendFormat: '{{controller}}/{{pod}} p90' },
          { expr: 'topk(5, ruby_http_request_duration_seconds{namespace="$namespace",pod!="",quantile="0.99",controller!~"^(media_proxy)$"})', legendFormat: '{{controller}}/{{pod}} p99' },
        ], 's', 12, 13, 12, 8, description='Top Rails summary quantiles per controller/pod (p50/p90/p99), excluding media_proxy. Diagnostic only; edge latency remains the SLO view.'),

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
        ], 's', 12, 22, 12, 8, description='Avg latency components for user-facing requests; use to isolate slow layers.'),

        h.timeseriesPanel(config, 7, '5xx error rate', [
          { expr: 'mastodon:web_requests_user:errors5m{namespace="$namespace"}', legendFormat: 'errors/sec' },
        ], 'p/s', 0, 22, 12, 7, description='User-facing 5xx per second (matching availability SLO scope).'),

        h.timeseriesPanel(config, 8, 'Request classification', [
          { expr: 'mastodon:web_requests_user:rate5m{namespace="$namespace"}', legendFormat: 'user-facing' },
          { expr: 'mastodon:web_requests_federation:rate5m{namespace="$namespace"}', legendFormat: 'federation' },
          { expr: 'mastodon:web_requests_uncategorized:rate5m{namespace="$namespace"}', legendFormat: 'other' },
        ], 'p/s', 12, 30, 12, 7, description='Traffic mix split by controller/action regexes; validates classification.'),

        h.timeseriesPanel(config, 9, 'CPU usage (total)', [
          { expr: h.podCpuExpr('mastodon-web.*'), legendFormat: 'total usage' },
        ], 'cores', 0, 30, 12, 8, description='Total CPU for web pods; compare to requests/limits elsewhere for headroom.'),

        h.timeseriesPanel(config, 10, 'Memory usage (total)', [
          { expr: h.podMemoryExpr('mastodon-web.*'), legendFormat: 'total usage' },
        ], 'bytes', 12, 38, 12, 8, description='Total memory for web pods; track against OOM/limits.'),

        h.timeseriesPanel(config, 11, 'Puma capacity', [
          { expr: 'ruby_puma_running_threads{namespace="$namespace",pod!=""}', legendFormat: '{{pod}} running' },
          { expr: 'ruby_puma_thread_pool_capacity{namespace="$namespace",pod!=""}', legendFormat: '{{pod}} capacity' },
          { expr: 'ruby_puma_max_threads{namespace="$namespace",pod!=""}', legendFormat: '{{pod}} max' },
        ], 'none', 0, 38, 12, 8, description='Per-pod thread usage vs capacity/max; rising to capacity signals saturation.'),

        h.timeseriesPanel(config, 12, 'Puma backlog', [
          { expr: 'ruby_puma_request_backlog{namespace="$namespace",pod!=""}', legendFormat: '{{pod}} backlog' },
        ], 'none', 12, 46, 12, 8, description='Queued requests waiting for a free Puma thread; should stay near zero.'),

        h.timeseriesPanel(config, 13, 'DB pool utilization', [
          { expr: 'sum by (namespace, pod) (ruby_active_record_connection_pool_busy{namespace="$namespace"}) / clamp_min(sum by (namespace, pod) (ruby_active_record_connection_pool_size{namespace="$namespace"}), 1)', legendFormat: '{{pod}} busy/size' },
        ], 'percentunit', 0, 46, 12, 8, description='Busy/size per pod for DB pool; near 1 indicates connection starvation.'),

        h.timeseriesPanel(config, 14, 'DB pool waiters', [
          { expr: 'ruby_active_record_connection_pool_waiting{namespace="$namespace",pod!=""}', legendFormat: '{{pod}} waiting' },
        ], 'none', 12, 54, 12, 8, description='Requests waiting for a DB connection; any sustained >0 implies bottleneck.'),

        h.timeseriesPanel(config, 15, 'Top controllers by request rate', [
          { expr: 'topk(5, sum by (namespace, controller, action) (rate(ruby_http_requests_total{namespace="$namespace"}[5m])))', legendFormat: '{{controller}}#{{action}}' },
        ], 'p/s', 0, 54, 12, 8, description='Highest request rates by controller/action over 5m to spot noisy routes.'),

        h.timeseriesPanel(config, 16, 'Top controllers by avg latency', [
          { expr: 'topk(5, sum by (namespace, controller, action) (rate(ruby_http_request_duration_seconds_sum{namespace="$namespace"}[5m])) / clamp_min(sum by (namespace, controller, action) (rate(ruby_http_request_duration_seconds_count{namespace="$namespace"}[5m])), 1e-6))', legendFormat: '{{controller}}#{{action}}' },
        ], 's', 12, 54, 12, 8, description='Slowest controllers by mean latency; target optimizations here first.'),

        // Slow request analysis section (y=62)
        h.timeseriesPanel(config, 24, 'Top controllers by p99 latency', [
          { expr: 'topk(10, ruby_http_request_duration_seconds{namespace="$namespace",quantile="0.99",controller!~"^(media_proxy)$"})', legendFormat: '{{controller}}#{{action}} ({{pod}})' },
        ], 's', 0, 62, 12, 8, description='Controllers with highest p99 latency; these likely drive your tail latency spikes.'),

        h.timeseriesPanel(config, 25, 'p99 latency impact (p99 × request rate)', [
          { expr: 'topk(10, ruby_http_request_duration_seconds{namespace="$namespace",quantile="0.99",controller!~"^(media_proxy)$"} * on (namespace, controller, action) group_left sum by (namespace, controller, action) (rate(ruby_http_requests_total{namespace="$namespace"}[5m])))', legendFormat: '{{controller}}#{{action}}' },
        ], 'none', 12, 62, 12, 8, description='p99 latency weighted by request volume; high values indicate controllers contributing most to overall tail latency.'),

        h.timeseriesPanel(config, 26, 'Latency spread (p99 - mean)', [
          { expr: 'topk(10, max by (namespace, controller, action) (ruby_http_request_duration_seconds{namespace="$namespace",quantile="0.99",controller!~"^(media_proxy)$"}) - (sum by (namespace, controller, action) (rate(ruby_http_request_duration_seconds_sum{namespace="$namespace",controller!~"^(media_proxy)$"}[5m])) / clamp_min(sum by (namespace, controller, action) (rate(ruby_http_request_duration_seconds_count{namespace="$namespace",controller!~"^(media_proxy)$"}[5m])), 1e-6)))', legendFormat: '{{controller}}#{{action}}' },
        ], 's', 0, 70, 12, 8, description='Gap between p99 and mean latency per controller; large gaps indicate inconsistent performance with occasional slow requests.'),

        h.timeseriesPanel(config, 27, 'Slow request ratio (p99 > 1s)', [
          { expr: 'topk(10, (ruby_http_request_duration_seconds{namespace="$namespace",quantile="0.99",controller!~"^(media_proxy)$"} > 1) * on (namespace, controller, action) group_left() (sum by (namespace, controller, action) (rate(ruby_http_requests_total{namespace="$namespace"}[5m])) / clamp_min(sum by (namespace, controller, action) (rate(ruby_http_requests_total{namespace="$namespace"}[5m])), 1e-6)))', legendFormat: '{{controller}}#{{action}}' },
        ], 'percentunit', 12, 70, 12, 8, description='Traffic share of controllers with p99 > 1s; shows what percentage of your traffic goes to slow endpoints.'),

        // Ruby internals section (y=78)
        h.timeseriesPanel(config, 17, 'Ruby heap slots', [
          { expr: 'ruby_heap_live_slots{namespace="$namespace",pod!=""}', legendFormat: '{{pod}} live' },
          { expr: 'ruby_heap_free_slots{namespace="$namespace",pod!=""}', legendFormat: '{{pod}} free' },
        ], 'none', 0, 78, 12, 8, description='Live vs free heap slots per pod; persistent growth hints at leaks.'),

        h.timeseriesPanel(config, 18, 'GC operations rate', [
          { expr: 'rate(ruby_major_gc_ops_total{namespace="$namespace"}[5m])', legendFormat: 'major/s' },
          { expr: 'rate(ruby_minor_gc_ops_total{namespace="$namespace"}[5m])', legendFormat: 'minor/s' },
          { expr: 'rate(ruby_marking_time{namespace="$namespace"}[5m])', legendFormat: 'marking time/s' },
          { expr: 'rate(ruby_sweeping_time{namespace="$namespace"}[5m])', legendFormat: 'sweeping time/s' },
        ], 'none', 12, 78, 12, 8, description='GC activity rates; spikes can explain latency or CPU jumps.'),

        h.statPanel(config, 19, 'Exporter healthy', 'min by (namespace) (ruby_collector_working{namespace="$namespace"})', 'none', 0, 86, 4, 5, description='Exporter self-check; should be 1.'),
        h.statPanel(config, 20, 'Bad metrics seen', 'sum by (namespace) (increase(ruby_collector_bad_metrics_total{namespace="$namespace"}[1h]))', 'none', 4, 86, 4, 5, description='Bad metrics processed in last hour (summed across web pods); rising counts imply exporter issues.'),

        {
          id: 21,
          type: 'logs',
          title: 'Web logs (last 30m)',
          gridPos: { x: 0, y: 91, w: 24, h: 16 },
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
              expr: h.logExpr('mastodon-web.*', '$web_log_search'),
            },
          ],
        },
      ],
    },
}
