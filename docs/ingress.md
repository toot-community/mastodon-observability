# Ingress / Edge

## Metrics

- `nginx_ingress_controller_requests{namespace,ingress,host,status}` – edge request/response counters used for total RPS and 5xx rates.
- `nginx_ingress_controller_request_duration_seconds_bucket{...}` – histogram buckets for request duration that power the p50/p90/p99 latency charts via `histogram_quantile`.
- Derived recording rules live in `mastodon:edge_*` (RPS, errors, latency) to keep Grafana queries short and label-consistent.
- **Cache hit ratio**: `mastodon:edge_cache_hit_ratio = clamp(1 - (app_rps / sum(edge_rps)), 0, 1)` approximates Varnish/Nginx cache behaviour by comparing upstream vs app-layer traffic.

## Dashboard (`generated/dashboards/edge.json`)

1. **Cache hit ratio / RPS stats** – quickly shows whether load is handled at the edge or passed downstream.
2. **Requests per host** – filter by `$namespace` and inspect per-ingress traffic splits. A sudden traffic shift to `microblog.network` should be visible here.
3. **Edge errors** – 5xx rates per host for find-and-fix; if they spike but the web 5xx panel is quiet, focus on ingress (timeouts, upstream disconnects).
4. **Latency quantiles** – p50/p90/p99 per host from the ingress histogram buckets.
5. **Ingress controller resources** – CPU/memory usage for the ingress-nginx controller pods inside the selected namespace.

## Alerting

Per the specification there are **no alerts** tied to cache/edge behaviour; the goal is visualization only. Recording rules exist so you can add alerts later if desired.

Logs are not part of this package; metrics panels and rules rely solely on Prometheus/VictoriaMetrics ingress exporters.
