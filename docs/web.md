# Mastodon Web

## Key metrics

- `ruby_http_requests_total{namespace,controller,action,status}` – source of request volume, error counting, and classification.
- `ruby_http_request_duration_seconds_{sum,count}` – mean latency (diagnostic only; APDEX now derived from Traefik edge histograms).
- `ruby_http_request_duration_seconds{quantile="0.5|0.9|0.99"}` – per-controller percentiles averaged across pods for dashboard plots.
- `ruby_http_request_sql_duration_seconds_*`, `ruby_http_request_redis_duration_seconds_*`, `ruby_http_request_queue_duration_seconds_*` – SQL/cache/queue components for latency breakdowns.
- Puma saturation: `ruby_puma_running_threads`, `ruby_puma_thread_pool_capacity`, `ruby_puma_max_threads`, `ruby_puma_request_backlog`.
- DB pool pressure: `ruby_active_record_connection_pool_{busy,size,waiting}`.
- GC/memory health: `ruby_heap_{live,free}_slots`, `ruby_{major,minor}_gc_ops_total`, `ruby_{marking,sweeping}_time`.
- `ruby_http_requests_total{status=~"5.."}` – only 5xx responses count toward availability SLOs.

## SLIs and SLOs

- **Availability (99.5 %)** – For each namespace we calculate:
  - good events: all user-facing controllers (regex list in `config.libsonnet`) regardless of 2xx/3xx/4xx status (4xx do **not** count as errors).
  - bad events: identical selector but `status=~"5.."`.
  - `mastodon:web_availability:error_ratio_<window>` = `increase(bad[window])/increase(total[window])` for 5 m / 30 m / 1 h / 6 h / 30 d windows.
  - Burn rate = error ratio ÷ error budget (0.5 %). Multi-window alerts fire when both fast and slow windows are exhausted simultaneously to guard against false positives.
- **Latency** – We compute `mastodon:web_latency:mean_seconds` and component averages from `*_sum / *_count`. P50/90/99 panels use the exporter quantiles averaged per namespace.
- **APDEX (edge)** – Derived from `traefik_service_request_duration_seconds_bucket` at the edge, keyed by `{namespace, ingress}` and excluding streaming routes. We treat ≤100 ms as satisfied, 100–500 ms as tolerating (0.5 weight), >500 ms or 5xx as frustrated. This reflects user-facing latency better than the former mean-based approximation from Puma summaries.

## Alerts

1. **MastodonWebAvailabilityCritical** – error budget burn >14× on both 5 m and 1 h windows for ≥5 m. This only considers user-facing controllers, so federation spikes never page.
2. **MastodonWebAvailabilityWarning** – lower burn (30 m >3× and 6 h >1×) to surface slow degradation before the pager rings.
3. **MastodonWebLatencyCritical** – `p99 > 1 s` while `mastodon:web_requests_user:rate5m > 1 req/s` for 10 m.
4. **MastodonWebLatencyWarning** – APDEX (edge) <0.85 for 15 m indicates systemic slowness (often SQL-bound).

Each alert links to this document (`docs/web.md#alerts`) and lives in `mastodon-observability`.

## Dashboard guide (`generated/dashboards/web.json`)

1. **Availability / APDEX stats** – confirm SLO status quickly. Values come from recording rules, so they match the alert logic exactly.
2. **Latency percentiles** – look for regressions in p50/90/99. When p99 spikes but p50 stays low, throttles usually hit only a subset of routes.
3. **SQL vs App latency** – isolating `mastodon:web_latency:sql_avg_seconds`, `redis_avg_seconds`, and `queue_avg_seconds` exposes backend contributors; `app_avg_seconds` shows what’s left inside the Rails app.
4. **5xx rate** – `errors/sec` derived from user-facing 5xx only; check here before diving deeper.
5. **Request classification** – stack of user-facing vs federation vs uncategorized traffic; use it to verify classification regexes.
6. **Puma capacity/backlog** – running vs capacity vs max threads and per-pod backlog highlight saturation before 5xxs appear.
7. **DB pool utilization/waiters** – utilization ratio and waiting requests catch connection starvation; spikes often precede latency blow-ups.
8. **Top controllers (rate/latency)** – `topk` slices by controller/action surface noisy or slow routes quickly.
9. **CPU / memory vs requests/limits** – uses cAdvisor usage metrics plotted against KSM requests/limits for pods matching `mastodon-web.*`. Headroom issues become obvious when usage lines sit on top of request/limit lines.
10. **Heap/GC health** – live/free slots and GC op rates show leak/regression risk across pods.

## Notes

- Classification regexes cover controllers seen in `metrics-examples/web-metrics.txt` (home, statuses, notifications, accounts, inboxes, webfinger, etc.). Adjust them in `config.libsonnet` if new controllers appear.
- APDEX is now ingress-based; Puma summaries remain only for mean/percentile diagnostics.
- Rails latency panels exclude `media_proxy` because media fetch/relay endpoints are inherently slow and noisy. These panels remain diagnostic (per-pod/namespace) while the SLO-authoritative latency view is the Traefik edge histogram panel, which includes all user traffic.
