# Mastodon Logs (VictoriaLogs)

## Where logs come from

- Mastodon pods (web, Sidekiq, streaming) write app logs to stdout/files.
- Vector ships logs to VictoriaLogs. You do **not** need to configure ingestion here.
- Each log entry has at least:
  - `_time`, `_msg`
  - `kubernetes.pod_namespace`
  - `kubernetes.pod_name`
  - `kubernetes.container_name`
  - `kubernetes.pod_labels.*` (includes `app.kubernetes.io/name`)

Namespaces:
- `toot-community` (prod)
- `microblog-network` (test)

## Grafana logs panels

All panels use the VictoriaLogs datasource (set in `lib/mastodon/config.libsonnet` under `grafana.logsDatasource`).

- **Overview dashboard**: “Recent Mastodon logs” — filters by `$namespace` and Mastodon pods (web/sidekiq/streaming), last 30m, optional `log_search` textbox applies `_msg =~ <text>` (empty matches all).
- **Web dashboard**: “Web logs (last 30m)” — filters namespace + `mastodon-web`; textbox `web_log_search` applies `_msg =~ <text>`.
- **Sidekiq dashboard**: “Sidekiq logs (last 30m)” — filters namespace + `mastodon-sidekiq.*`; textbox `sidekiq_log_search` applies `_msg =~ <text>`.
- **Streaming dashboard**: “Streaming logs (last 30m)” — filters namespace + `mastodon-streaming`.

## How to pivot from alerts to logs

When an alert fires:
1) Open the linked dashboard in the annotation (Overview/Web for web alerts, Streaming for streaming alerts).
2) Set `namespace` to the firing namespace (prepopulated in annotation hints).
3) Use the logs panel on that dashboard:
   - For web: search `_msg` for `ERROR`, route names, or exceptions.
   - For sidekiq: search job names/queue names or `FATAL/ERROR`.
   - For streaming: search for Redis/WS errors or slow handlers.
4) Time range: panels default to last 30m; adjust if the alert persisted longer.

Notes:
- No log-derived metrics are created. These panels are for troubleshooting only.
- Avoid touching `toot-community` for experiments; use `microblog-network` when testing queries.***
