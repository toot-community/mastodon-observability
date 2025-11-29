local cfg = import '../config.libsonnet';
local h = import './helpers.libsonnet';

{
  dashboard(config=cfg)::
    local base = h.baseDashboard(config, 'Mastodon Edge', 'mastodon-edge');
    base {
      panels: [
        h.statPanel(config, 1, 'Cache hit ratio', 'mastodon:edge_cache_hit_ratio{namespace="$namespace"}', 'percentunit', 0, 0, description='Estimated varnish/edge cache hit ratio from Traefik vs app RPS.'),
        h.statPanel(config, 2, 'Edge RPS', 'sum by (namespace) (mastodon:edge_rps{namespace="$namespace"})', 'p/s', 4, 0, description='Total Traefik service request rate at the edge.'),
        h.statPanel(config, 3, 'Edge 5xx rps', 'sum by (namespace) (mastodon:edge_errors_rate{namespace="$namespace"})', 'p/s', 8, 0, description='Edge-served 5xx per second (Traefik ingress layer).'),

        h.timeseriesPanel(config, 4, 'Requests per ingress', [
          { expr: 'sum by (ingress) (mastodon:edge_rps{namespace="$namespace",ingress!=""})', legendFormat: '{{ingress}}' },
        ], 'p/s', 0, 5, 12, 8, description='Edge request rate by ingress; useful for per-route issues.'),

        h.timeseriesPanel(config, 5, 'Edge errors per ingress', [
          { expr: 'sum by (ingress) (mastodon:edge_errors_rate{namespace="$namespace",ingress!=""})', legendFormat: '{{ingress}}' },
        ], 'p/s', 12, 5, 12, 8, description='Edge 5xx rate per ingress to pinpoint failing varnish/Traefik paths.'),

        h.timeseriesPanel(config, 6, 'Cache hit ratio over time', [
          { expr: 'mastodon:edge_cache_hit_ratio{namespace="$namespace"}', legendFormat: 'ratio' },
        ], 'percentunit', 0, 13, 12, 6, description='Cache hit ratio trend; falling values mean more traffic to app.'),

        h.timeseriesPanel(config, 7, 'Edge latency p50/p90/p99', [
          { expr: 'max by (ingress) (mastodon:edge_latency_p50{namespace="$namespace",ingress!=""})', legendFormat: 'p50 {{ingress}}' },
          { expr: 'max by (ingress) (mastodon:edge_latency_p90{namespace="$namespace",ingress!=""})', legendFormat: 'p90 {{ingress}}' },
          { expr: 'max by (ingress) (mastodon:edge_latency_p99{namespace="$namespace",ingress!=""})', legendFormat: 'p99 {{ingress}}' },
        ], 's', 0, 13, 12, 8, description='Traefik latency percentiles per ingress (deduped across pods); reflects user-facing edge timing.'),

        h.timeseriesPanel(config, 8, 'Traefik open connections', [
          { expr: 'sum by (entrypoint, protocol) (traefik_open_connections{entrypoint!=""})', legendFormat: '{{entrypoint}} {{protocol}}' },
        ], 'none', 12, 13, 12, 8, description='Active Traefik connections by entrypoint/protocol (summed across pods).'),

        h.timeseriesPanel(config, 9, 'Traefik entrypoint RPS', [
          { expr: 'sum by (entrypoint, protocol) (rate(traefik_entrypoint_requests_total[5m]))', legendFormat: '{{entrypoint}} {{protocol}}' },
        ], 'p/s', 12, 21, 12, 8, description='Cluster-wide Traefik entrypoint request rates (helps spot ingress pressure).'),
      ],
    },
}
