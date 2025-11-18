# Mastodon Sidekiq

## Metrics considered

- `sidekiq_queue_latency_seconds{queue}` – age of the oldest job in each queue. We record both 10 m (`mastodon:sidekiq_queue_latency:p95`) and 5 m (`...:p95_short`) quantiles per namespace.
- `sidekiq_jobs_total`, `sidekiq_failed_jobs_total` – throughput/failure rates grouped by queue.
- `sidekiq_stats_*` gauges – backlog, scheduled, retry, and dead counts. `sidekiq_stats_dead_size` feeds the dead-queue growth ratio rule.
- `sidekiq_dead_jobs_total` – counter used for growth vs processed volume.
- `sidekiq_queue_backlog`, `sidekiq_process_busy`, `sidekiq_process_concurrency` – backlog and saturation per worker process.
- Job performance: `sidekiq_job_duration_seconds_{sum,count}` for mean durations; `sidekiq_failed_jobs_total` vs `sidekiq_jobs_total` for per-job failure ratios.
- `ruby_active_record_connection_pool_*` – produces `mastodon:sidekiq_db_pool_utilization` to show if workers are starved on DB connections.
- Pod resources: `container_cpu_usage_seconds_total`, `container_memory_working_set_bytes`, plus `kube_pod_container_resource_{requests,limits}_*`.

## Alert logic

1. **MastodonSidekiqQueueLatencyCritical** – `p95 > 120 s` (configurable) for 10 m. Fires only when latency stays elevated, preventing brief spikes from paging.
2. **MastodonSidekiqQueueLatencyWarning** – `p95 > 30 s` for 5 m (short window) to spot degradation before backlogs threaten users.
3. **MastodonSidekiqDeadQueueWarning** – the dead queue grows faster than 1 % of processed jobs over 1 h. This captures systemic job failures without paging on federation-specific queues alone.

All alerts run in `mastodon-observability` and inherit the namespace label, so one set of rules watches both instances.

## Dashboard guide (`generated/dashboards/sidekiq.json`)

- **Stats row** – dead-queue growth ratio, DB pool utilization, and total enqueued jobs per namespace.
- **Per-queue latency** – long and short windows plotted per queue (default, push, ingress, mailers, pull, scheduler, fasp). Use it to verify the queue causing an alert.
- **Backlog & saturation** – backlog per queue plus busy vs max concurrency per pod to see whether workers are starved.
- **Throughput & failures** – success/failure rates per queue; top jobs by failure ratio highlight flaky workloads.
- **Dead / retry dynamics** – live sizes and 15 m derivatives show whether queues are draining or filling.
- **Slowest jobs** – top jobs by mean duration surface candidates for optimization.
- **DB pool waiters & heap** – waiters indicate DB contention; heap slots show memory pressure across workers.
- **CPU/memory vs requests/limits** – aggregated usage plotted against Kubernetes requests/limits for pods matching `mastodon-sidekiq.*` so you can see whether throttling or OOM pressure is imminent.

## Operational tips

- If a queue latency alert fires but the corresponding queue handles federation jobs (`ingress`, `pull`, `push`), wait for the warning condition to persist before paging—only the critical alert pages.
- DB pool utilization close to 1 means Sidekiq is bottlenecked on PostgreSQL; scale the CloudNativePG replicas vertically or add more connections before blindly adding Sidekiq pods.
