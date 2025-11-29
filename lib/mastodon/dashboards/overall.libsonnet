local cfg = import '../config.libsonnet';
local logs = import '../logs.libsonnet';
local h = import './helpers.libsonnet';

{
  dashboard(config=cfg)::
    local logSearchVar = {
      name: 'log_search',
      label: 'Log search text',
      type: 'textbox',
      query: '',
      current: { text: '', value: '' },
    };
    local base = h.baseDashboard(config {
      extraTemplating: [logSearchVar],
      logsDatasource: config.grafana.logsDatasource,
    }, 'Mastodon Overview', 'mastodon-overall');
    base {
      panels: [
        h.statPanel(config, 1, 'Availability (30d)', 'mastodon:web_availability:availability_30d{namespace="$namespace"}', 'percentunit', 0, 0, description='Long-window availability SLO attainment for user-facing routes.'),
        h.statPanel(config, 2, 'APDEX (edge)', 'mastodon:edge_apdex:overall{namespace="$namespace"}', 'none', 4, 0, description='Traefik edge APDEX (100/500ms) excluding streaming routes; fast health snapshot.'),
        h.statPanel(config, 3, 'Streaming clients', 'mastodon:streaming_connected_clients_total{namespace="$namespace"}', 'none', 8, 0, description='Total connected streaming clients right now.'),

        h.timeseriesPanel(config, 4, 'Error budget burn', [
          { expr: 'mastodon:web_availability:burn_rate_5m{namespace="$namespace"}', legendFormat: '5m burn' },
          { expr: 'mastodon:web_availability:burn_rate_1h{namespace="$namespace"}', legendFormat: '1h burn' },
          { expr: 'mastodon:web_availability:burn_rate_30m{namespace="$namespace"}', legendFormat: '30m burn' },
        ], 'none', 0, 5, 12, 8, description='Multi-window burn rates vs web availability SLO; alert source.'),

        h.timeseriesPanel(config, 5, 'Web latency percentiles', [
          { expr: 'mastodon:web_latency:p50_seconds{namespace="$namespace"}', legendFormat: 'p50' },
          { expr: 'mastodon:web_latency:p90_seconds{namespace="$namespace"}', legendFormat: 'p90' },
          { expr: 'mastodon:web_latency:p99_seconds{namespace="$namespace"}', legendFormat: 'p99' },
        ], 's', 12, 5, 12, 8, description='App-side latency percentiles (diagnostic).'),

        h.timeseriesPanel(config, 6, 'Request mix (req/s)', [
          { expr: 'mastodon:web_requests_user:rate5m{namespace="$namespace"}', legendFormat: 'user-facing' },
          { expr: 'mastodon:web_requests_federation:rate5m{namespace="$namespace"}', legendFormat: 'federation' },
          { expr: 'mastodon:web_requests_uncategorized:rate5m{namespace="$namespace"}', legendFormat: 'uncategorized' },
        ], 'p/s', 0, 13, 12, 8, description='Traffic split; confirms user-facing load vs federation/background.'),

        h.timeseriesPanel(config, 7, 'Sidekiq queue latency (p95)', [
          { expr: 'max by (namespace, queue) (mastodon:sidekiq_queue_latency:p95{namespace="$namespace",queue!=""})', legendFormat: '{{queue}}' },
        ], 's', 12, 13, 12, 8, description='p95 queue latency across Sidekiq queues; alerts derive from this.'),

        h.timeseriesPanel(config, 8, 'Streaming clients by type', [
          { expr: 'mastodon:streaming_connected_clients{namespace="$namespace"}', legendFormat: '{{type}}' },
        ], 'none', 0, 21, 12, 8, description='Streaming client mix (websocket/eventsource) over time.'),

        h.timeseriesPanel(config, 9, 'Ingress vs app traffic', [
          { expr: 'sum by (namespace) (mastodon:edge_rps{namespace="$namespace"})', legendFormat: 'edge rps' },
          { expr: 'mastodon:web_requests:rate5m{namespace="$namespace"}', legendFormat: 'app rps' },
        ], 'p/s', 12, 21, 12, 8, description='Ingress request rate vs app-handled rate; gap approximates cache hits.'),

        h.timeseriesPanel(config, 10, 'Cache hit ratio (estimated)', [
          { expr: 'mastodon:edge_cache_hit_ratio{namespace="$namespace"}', legendFormat: 'ratio' },
        ], 'percentunit', 0, 29, 12, 6, description='Estimated cache-hit ratio from ingress vs app RPS.'),

        {
          id: 11,
          type: 'logs',
          title: 'Recent Mastodon logs',
          gridPos: { x: 0, y: 36, w: 24, h: 8 },
          datasource: logs.logs(config).datasource,
          options: {
            query: {
              query: '',
              refId: 'A',
              expr: '',
              intervals: [],
            },
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
              expr: h.logExpr('mastodon-(web|sidekiq.*|streaming)', '$log_search'),
            },
          ],
        },
      ],
    },
}
