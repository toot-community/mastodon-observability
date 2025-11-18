local cfg = import '../config.libsonnet';
local logs = import '../logs.libsonnet';
local h = import './helpers.libsonnet';

{
  dashboard(config=cfg)::
    local logSearchVar = {
      name: 'streaming_log_search',
      label: 'Streaming log search',
      type: 'textbox',
      query: '.*',
      current: { text: '.*', value: '.*' },
    };
    local base = h.baseDashboard(config {
      extraTemplating: [logSearchVar],
      logsDatasource: config.grafana.logsDatasource,
    }, 'Mastodon Streaming', 'mastodon-streaming');
    base {
      panels: [
        h.statPanel(config, 1, 'Connected clients', 'mastodon:streaming_connected_clients_total{namespace="$namespace"}', 'none', 0, 0, description='Total streaming clients; dropping to zero freezes timelines.'),
        h.statPanel(config, 2, 'Eventloop lag p99', 'mastodon:streaming_eventloop_lag_p99{namespace="$namespace"}', 's', 4, 0, description='P99 eventloop lag; >100ms sustained means CPU/GC trouble.'),
        h.statPanel(config, 3, 'PG pool utilization', 'mastodon:streaming_pg_pool_utilization{namespace="$namespace"}', 'percentunit', 8, 0, description='Busy/total PG connections; near 1 shows DB contention.'),

        h.timeseriesPanel(config, 4, 'Connected clients by type', [
          { expr: 'mastodon:streaming_connected_clients{namespace="$namespace"}', legendFormat: '{{pod}} {{type}}' },
        ], 'none', 0, 5, 12, 8, description='Client counts per pod and transport (websocket/eventsource).'),

        h.timeseriesPanel(config, 5, 'Client baseline vs current (drop ratio)', [
          { expr: 'mastodon:streaming_connected_clients_total{namespace="$namespace"}', legendFormat: 'current' },
          { expr: 'mastodon:streaming_clients:baseline{namespace="$namespace"}', legendFormat: 'baseline' },
          { expr: 'mastodon:streaming_clients:drop_ratio{namespace="$namespace"}', legendFormat: 'drop ratio' },
        ], 'none', 12, 5, 12, 8, description='Current vs rolling baseline and drop ratio for connected clients.'),

        h.timeseriesPanel(config, 6, 'Channels', [
          { expr: 'sum by (namespace, type) (connected_channels{namespace="$namespace",type!=""})', legendFormat: '{{type}}' },
        ], 'none', 12, 5, 12, 8, description='Active streaming channels by type; correlates with subscriptions/load.'),

        h.timeseriesPanel(config, 7, 'Messages sent', [
          { expr: 'mastodon:streaming_messages_sent_rate5m{namespace="$namespace",type!=""}', legendFormat: '{{type}} out' },
        ], 'none', 0, 13, 12, 8, description='Messages delivered to clients by type (rate).'),

        h.timeseriesPanel(config, 8, 'Messages received from Redis', [
          { expr: 'mastodon:streaming_messages_recv_rate5m{namespace="$namespace"}', legendFormat: 'redis' },
        ], 'none', 12, 13, 12, 8, description='Ingress from Redis pub/sub (rate); should track outbound messages.'),

        h.timeseriesPanel(config, 9, 'Eventloop lag distribution', [
          { expr: 'max by (namespace) (nodejs_eventloop_lag_p50_seconds{namespace="$namespace"})', legendFormat: 'p50' },
          { expr: 'max by (namespace) (nodejs_eventloop_lag_p90_seconds{namespace="$namespace"})', legendFormat: 'p90' },
          { expr: 'max by (namespace) (nodejs_eventloop_lag_p99_seconds{namespace="$namespace"})', legendFormat: 'p99' },
        ], 's', 0, 21, 12, 8, description='Eventloop latency percentiles; rising p99 with stable p50 suggests bursts.'),

        h.timeseriesPanel(config, 10, 'CPU usage (total)', [
          { expr: 'sum by (namespace) (rate(container_cpu_usage_seconds_total{namespace="$namespace",pod=~"mastodon-streaming.*",container!=""}[5m]))', legendFormat: 'total usage' },
        ], 'cores', 0, 29, 12, 8, description='Total CPU for streaming pods; link with lag spikes.'),

        h.timeseriesPanel(config, 11, 'Memory usage (total)', [
          { expr: 'sum by (namespace) (container_memory_working_set_bytes{namespace="$namespace",pod=~"mastodon-streaming.*",container!=""})', legendFormat: 'total usage' },
        ], 'bytes', 12, 29, 12, 8, description='Total memory for streaming pods; watch for leaks.'),

        h.timeseriesPanel(config, 12, 'GC duration by kind', [
          { expr: 'sum by (namespace, kind) (rate(nodejs_gc_duration_seconds_sum{namespace="$namespace",kind!=""}[5m])) / clamp_min(sum by (namespace, kind) (rate(nodejs_gc_duration_seconds_count{namespace="$namespace",kind!=""}[5m])), 1e-6)', legendFormat: '{{kind}} mean' },
        ], 's', 0, 37, 12, 8, description='Mean GC pause per kind; spikes often align with lag or heap growth.'),

        h.timeseriesPanel(config, 13, 'File descriptors', [
          { expr: 'process_open_fds{namespace="$namespace"}', legendFormat: '{{pod}} open' },
          { expr: 'process_open_fds{namespace="$namespace"} / clamp_min(process_max_fds{namespace="$namespace"}, 1)', legendFormat: '{{pod}} utilization' },
        ], 'none', 12, 37, 12, 8, description='Open FDs and utilization (open/max); rising lines suggest leak or overload.'),

        h.timeseriesPanel(config, 14, 'Redis subscriptions', [
          { expr: 'redis_subscriptions{namespace="$namespace"}', legendFormat: '{{pod}} subscriptions' },
        ], 'none', 0, 45, 12, 8, description='Redis channels subscribed; should track channels and client activity.'),

        h.timeseriesPanel(config, 15, 'PG pool waiting queries', [
          { expr: 'pg_pool_waiting_queries{namespace="$namespace"}', legendFormat: '{{pod}} waiting' },
        ], 'none', 12, 45, 12, 8, description='Queries waiting for PG connections; any >0 means contention.'),

        h.timeseriesPanel(config, 16, 'Active Node handles/requests/resources', [
          { expr: 'nodejs_active_handles_total{namespace="$namespace"}', legendFormat: '{{pod}} handles' },
          { expr: 'nodejs_active_requests_total{namespace="$namespace"}', legendFormat: '{{pod}} requests' },
          { expr: 'nodejs_active_resources_total{namespace="$namespace"}', legendFormat: '{{pod}} resources' },
        ], 'none', 0, 53, 12, 8, description='Active handles/requests/resources; slow drift up suggests leaks between deploys.'),

        {
          id: 17,
          type: 'logs',
          title: 'Streaming logs (last 30m)',
          gridPos: { x: 0, y: 61, w: 24, h: 16 },
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
                'kubernetes.pod_name:~"^mastodon-streaming" and ' +
                '_msg:~$streaming_log_search',
            },
          ],
        },
      ],
    },
}
