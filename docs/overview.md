# Mastodon Observability Overview

This repository renders a complete stack for the `mastodon-observability` namespace. It consumes live metrics scraped by VictoriaMetrics and never applies resources inside `toot-community` or `microblog-network`.

## Repository layout

- `lib/mastodon/config.libsonnet` – knobs for namespaces, SLO targets, Sidekiq thresholds, and request-class regexes.
- `lib/mastodon/records.libsonnet` – Prometheus/VictoriaMetrics recording rules scoped by the `namespace` label so a single rule file covers both Mastodon instances.
- `lib/mastodon/alerts.libsonnet` – alert rules that page only on symptom-focused outages (web availability, Sidekiq latency, streaming health).
- `lib/mastodon/dashboards/*.libsonnet` – Grafonnet-style dashboards rendered to JSON.
- `envs/*.jsonnet` – entry points for `jsonnet -m` (default namespace differs per file).
- `generated/` – rendered outputs (YAML for rules, JSON dashboards) created by `make generate`.
- `deploy/kustomization.yaml` – packages the generated artifacts into ConfigMaps and `PrometheusRule` resources for `mastodon-observability`.

## Build + deployment flow

1. `make generate` (or `make ENV=toot-community generate`) renders Jsonnet via `jsonnet -m generated envs/<env>.jsonnet`.
2. `make lint` runs `jsonnetfmt`, `jsonnet-lint`, and `promtool check rules generated/alerts/*.yaml`.
3. `make apply` calls `kubectl apply -k deploy`, which only touches the `mastodon-observability` namespace. Dashboards are emitted as ConfigMaps with `grafana_dashboard: "1"` so the Grafana sidecar auto-loads them.

## Metrics + validation

- All metric names/labels come from the dumps in `metrics-examples/` and were cross-checked inside the `victoriametrics` namespace (`kubectl exec vmsingle-vm … wget http://localhost:8428/api/v1/query?...`) while filtering on `namespace="microblog-network"`.
- Web traffic uses `ruby_http_requests_total`, `ruby_http_request_duration_seconds_*`, and SQL/Redis sub-metrics. Sidekiq relies on `sidekiq_queue_latency_seconds`, `sidekiq_jobs_total`, `sidekiq_stats_*`, and `ActiveRecord` pool gauges. Streaming panels use `connected_clients`, `messages_sent_total`, `nodejs_eventloop_lag_*`, and `pg_pool_*`. Edge dashboards consume Traefik `traefik_service_*` histograms.
- Web traffic uses `ruby_http_requests_total`, `ruby_http_request_duration_seconds_*`, and SQL/Redis sub-metrics. Sidekiq relies on `sidekiq_queue_latency_seconds`, `sidekiq_jobs_total`, `sidekiq_stats_*`, and `ActiveRecord` pool gauges. Streaming panels use `connected_clients`, `messages_sent_total`, `nodejs_eventloop_lag_*`, and `pg_pool_*`. Edge dashboards consume Traefik `traefik_service_*` histograms.

## SLOs + alerts at a glance

- **Web availability**: 99.5 % target, multi-window burn-rate alerts (5 m/1 h critical, 30 m/6 h warning). Only 5xx responses on classified user-facing controllers count as errors.
- **Web latency**: APDEX is ingress-based (100/500ms) via `mastodon:edge_apdex:overall`; a critical alert fires if p99 > 1 s with traffic present. Percentiles remain app-side for diagnostics.
- **Sidekiq**: Alerts focus on queue latency (p95 > 120 s for 10 m → critical, >30 s for 5 m → warning) and dead queue growth relative to processed volume.
- **Streaming**: Pages if all clients drop for >10 m, warns if eventloop lag p99 > 100 ms while clients exist.
- **Edge**: Dashboard-only (RPS, latency, cache hit ratio) per spec.

Classification regexes live in Jsonnet config; adjust them once new controllers/actions appear to improve SLI fidelity.
