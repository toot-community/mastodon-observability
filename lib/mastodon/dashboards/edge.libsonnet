local cfg = import '../config.libsonnet';
local h = import './helpers.libsonnet';

{
  dashboard(config=cfg)::
    local base = h.baseDashboard(config, 'Mastodon Edge', 'mastodon-edge');
    base {
      panels: [
        // Row 0: stat panels (y=0, h=5)
        h.statPanel(config, 1, 'Cache hit ratio', 'mastodon:edge_cache_hit_ratio{namespace="$namespace"}', 'percentunit', 0, 0, description='Estimated varnish/edge cache hit ratio from Traefik vs app RPS.'),
        h.statPanel(config, 2, 'Edge RPS', 'sum by (namespace) (mastodon:edge_rps{namespace="$namespace"})', 'reqps', 4, 0, description='Total Traefik service request rate at the edge.'),
        h.statPanel(config, 3, 'Edge 5xx rps', 'sum by (namespace) (mastodon:edge_errors_rate{namespace="$namespace"})', 'reqps', 8, 0, description='Edge-served 5xx per second (Traefik ingress layer).'),
        h.statPanel(config, 4, 'Traffic In', 'sum by (namespace) (mastodon:edge_request_bytes_rate{namespace="$namespace"})', 'Bps', 12, 0, description='Request bytes per second (incoming traffic).'),
        h.statPanel(config, 5, 'Traffic Out', 'sum by (namespace) (mastodon:edge_response_bytes_rate{namespace="$namespace"})', 'Bps', 16, 0, description='Response bytes per second (outgoing traffic).'),
        h.statPanel(config, 6, 'Avg Request Size', 'sum by (namespace) (mastodon:edge_request_bytes_rate{namespace="$namespace"}) / clamp_min(sum by (namespace) (mastodon:edge_rps{namespace="$namespace"}), 1)', 'decbytes', 20, 0, description='Average request size in bytes.'),

        // Row 1: Requests & Errors per ingress (y=5, h=8)
        h.timeseriesPanel(config, 7, 'Requests per ingress', [
          { expr: 'sum by (ingress) (mastodon:edge_rps{namespace="$namespace",ingress!=""})', legendFormat: '{{ingress}}' },
        ], 'reqps', 0, 5, 12, 8, description='Edge request rate by ingress; useful for per-route issues.'),

        h.timeseriesPanel(config, 8, 'Edge errors per ingress', [
          { expr: 'sum by (ingress) (mastodon:edge_errors_rate{namespace="$namespace",ingress!=""})', legendFormat: '{{ingress}}' },
        ], 'reqps', 12, 5, 12, 8, description='Edge 5xx rate per ingress to pinpoint failing varnish/Traefik paths.'),

        // Row 2: HTTP status codes & bandwidth (y=13, h=8)
        h.timeseriesPanel(config, 9, 'HTTP Status Codes', [
          { expr: 'sum by (code) (mastodon:edge_rps_by_code{namespace="$namespace"})', legendFormat: '{{code}}' },
        ], 'reqps', 0, 13, 12, 8, description='Request rate breakdown by HTTP status code (2xx, 3xx, 4xx, 5xx).'),

        h.timeseriesPanel(config, 10, 'Bandwidth over time', [
          { expr: 'sum by (namespace) (mastodon:edge_request_bytes_rate{namespace="$namespace"})', legendFormat: 'Inbound' },
          { expr: 'sum by (namespace) (mastodon:edge_response_bytes_rate{namespace="$namespace"})', legendFormat: 'Outbound' },
        ], 'Bps', 12, 13, 12, 8, description='Bytes per second in/out at the edge layer.'),

        // Row 3: Cache hit ratio & latency (y=21, h=8)
        h.timeseriesPanel(config, 11, 'Cache hit ratio over time', [
          { expr: 'mastodon:edge_cache_hit_ratio{namespace="$namespace"}', legendFormat: 'ratio' },
        ], 'percentunit', 0, 21, 12, 6, description='Cache hit ratio trend; falling values mean more traffic to app.'),

        h.timeseriesPanel(config, 12, 'Edge latency p50/p90/p99', [
          { expr: 'max by (ingress) (mastodon:edge_latency_p50{namespace="$namespace",ingress!=""})', legendFormat: 'p50 {{ingress}}' },
          { expr: 'max by (ingress) (mastodon:edge_latency_p90{namespace="$namespace",ingress!=""})', legendFormat: 'p90 {{ingress}}' },
          { expr: 'max by (ingress) (mastodon:edge_latency_p99{namespace="$namespace",ingress!=""})', legendFormat: 'p99 {{ingress}}' },
        ], 's', 0, 27, 12, 8, description='Traefik latency percentiles per ingress (deduped across pods); reflects user-facing edge timing.'),

        // Row 4: Request methods & connections (y=35, h=8)
        h.timeseriesPanel(config, 13, 'Request Methods', [
          { expr: 'sum by (method) (mastodon:edge_rps_by_method{namespace="$namespace"})', legendFormat: '{{method}}' },
        ], 'reqps', 12, 21, 12, 8, description='Request rate breakdown by HTTP method (GET, POST, PUT, DELETE, etc.).'),

        h.timeseriesPanel(config, 14, 'Traefik open connections', [
          { expr: 'sum by (entrypoint, protocol) (traefik_open_connections{entrypoint!=""})', legendFormat: '{{entrypoint}} {{protocol}}' },
        ], 'none', 12, 27, 12, 8, description='Active Traefik connections by entrypoint/protocol (summed across pods).'),

        // Row 5: Entrypoint RPS (y=43, h=8)
        h.timeseriesPanel(config, 15, 'Traefik entrypoint RPS', [
          { expr: 'sum by (entrypoint, protocol) (rate(traefik_entrypoint_requests_total[5m]))', legendFormat: '{{entrypoint}} {{protocol}}' },
        ], 'reqps', 0, 35, 24, 8, description='Cluster-wide Traefik entrypoint request rates (helps spot ingress pressure).'),
      ],
    },
}
