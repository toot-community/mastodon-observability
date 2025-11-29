# Ingress / Edge

## Metrics

- `traefik_service_requests_total{exported_service,code,method,protocol}` – edge request/response counters; we relabel `exported_service` to `{namespace, ingress}` (e.g., `varnish-for-app`, `varnish-for-static`) for per-namespace views and error slicing.
- `traefik_service_request_duration_seconds_bucket{...}` / `_sum` / `_count` – latency histograms powering p50/p90/p99 and APDEX derived from Traefik edge timing.
- `traefik_entrypoint_requests_total`, `traefik_open_connections` – entrypoint-level health (websecure) for quick pressure checks.
- Derived recording rules live in `mastodon:edge_*` (RPS, errors, latency, APDEX) to keep Grafana queries short and label-consistent.
- **Cache hit ratio**: `mastodon:edge_cache_hit_ratio = clamp(1 - (app_rps / sum(edge_rps)), 0, 1)` approximates Varnish/Traefik cache behaviour by comparing edge vs app-layer traffic.

## Dashboard (`generated/dashboards/edge.json`)

1. **Cache hit ratio / RPS stats** – quickly shows whether load is handled at the edge or passed downstream.
2. **Requests per ingress** – filter by `$namespace` and inspect per-route traffic splits (e.g., `varnish-for-app` vs `varnish-for-static`).
3. **Edge errors** – 5xx rates per ingress for find-and-fix; if they spike but the web 5xx panel is quiet, focus on ingress/varnish issues (timeouts, upstream disconnects).
4. **Latency quantiles** – p50/p90/p99 per ingress from the Traefik service histograms.
5. **Traefik entrypoint health** – open connections and entrypoint RPS (cluster-wide) to spot pressure on the gateway.

## Alerting

Per the specification there are **no alerts** tied to cache/edge behaviour; the goal is visualization only. Recording rules exist so you can add alerts later if desired.

Logs are not part of this package; metrics panels and rules rely solely on Prometheus/VictoriaMetrics ingress exporters.
