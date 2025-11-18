local cfg = import '../config.libsonnet';
local h = import './helpers.libsonnet';

{
  dashboard(config=cfg)::
    local base = h.baseDashboard(config, 'Mastodon Edge', 'mastodon-edge');
    base {
      panels: [
        h.statPanel(config, 1, 'Cache hit ratio', 'mastodon:edge_cache_hit_ratio{namespace="$namespace"}', 'percentunit', 0, 0, description='Estimated varnish/nginx cache hit ratio from edge vs app RPS.'),
        h.statPanel(config, 2, 'Edge RPS', 'sum by (namespace) (mastodon:edge_rps{namespace="$namespace"})', 'p/s', 4, 0, description='Total ingress request rate at the edge.'),
        h.statPanel(config, 3, 'Edge 5xx rps', 'sum by (namespace) (mastodon:edge_errors_rate{namespace="$namespace"})', 'p/s', 8, 0, description='Edge-served 5xx per second (ingress/varnish layer).'),

        h.timeseriesPanel(config, 4, 'Requests per host', [
          { expr: 'mastodon:edge_rps{namespace="$namespace",host!=""}', legendFormat: '{{host}}' },
        ], 'p/s', 0, 5, 12, 8, description='Edge request rate by host; useful for host-specific issues.'),

        h.timeseriesPanel(config, 5, 'Edge errors per host', [
          { expr: 'mastodon:edge_errors_rate{namespace="$namespace",host!=""}', legendFormat: '{{host}}' },
        ], 'p/s', 12, 5, 12, 8, description='Edge 5xx rate per host to pinpoint failing ingress/varnish paths.'),

        h.timeseriesPanel(config, 6, 'Cache hit ratio over time', [
          { expr: 'mastodon:edge_cache_hit_ratio{namespace="$namespace"}', legendFormat: 'ratio' },
        ], 'percentunit', 0, 13, 12, 6, description='Cache hit ratio trend; falling values mean more traffic to app.'),

        h.timeseriesPanel(config, 7, 'Edge latency p50/p90/p99', [
          { expr: 'mastodon:edge_latency_p50{namespace="$namespace",host!=""}', legendFormat: 'p50 {{host}}' },
          { expr: 'mastodon:edge_latency_p90{namespace="$namespace",host!=""}', legendFormat: 'p90 {{host}}' },
          { expr: 'mastodon:edge_latency_p99{namespace="$namespace",host!=""}', legendFormat: 'p99 {{host}}' },
        ], 's', 0, 13, 12, 8, description='Ingress latency percentiles per host; reflects user-facing edge timing.'),

        h.timeseriesPanel(config, 8, 'Ingress controller CPU usage', [
          { expr: 'sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="ingress-nginx",pod=~"ingress-nginx-controller.*",container!=""}[5m]))', legendFormat: '{{pod}}' },
        ], 'cores', 12, 13, 12, 8, description='Ingress controller CPU by pod; saturation can hurt latency.'),

        h.timeseriesPanel(config, 9, 'Ingress controller memory', [
          { expr: 'sum by (pod) (container_memory_working_set_bytes{namespace="ingress-nginx",pod=~"ingress-nginx-controller.*",container!=""})', legendFormat: '{{pod}}' },
        ], 'bytes', 12, 21, 12, 8, description='Ingress controller memory by pod; watch for OOM risk.'),
      ],
    },
}
