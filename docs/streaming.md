# Mastodon Streaming

## Metrics

- `connected_clients{namespace,type}` and `connected_channels` – instantaneous fan-out per transport (websocket/eventsource).
- `messages_sent_total` & `redis_messages_received_total` – counters for client-delivered vs Redis-ingested messages.
- `redis_subscriptions` – Redis channel count; together with `connected_channels` it shows pub/sub health.
- `nodejs_eventloop_lag_pXX_seconds` – native Node.js metrics exported by the streaming pods.
- `nodejs_gc_duration_seconds_{sum,count}` – durations per GC kind; lag spikes often align with major collection.
- `nodejs_active_{handles,requests,resources}_total` – leak detection and runaway asynchronous work.
- `pg_pool_*` – connection pool stats surfaced by the Node.js exporter.
- Pod resource usage: `container_cpu_usage_seconds_total`, `container_memory_working_set_bytes`, `kube_pod_container_resource_{requests,limits}_*`.
- System/process health: `process_open_fds` vs `process_max_fds`, `nodejs_heap_size_*`.

## Alerts

1. **MastodonStreamingNoClients** – total connected clients drops to zero for 10 m. This usually means ingress/websocket issues or Redis/pubsub failures; it pages immediately because timelines will freeze.
2. **MastodonStreamingEventloopLag** – p99 lag >100 ms for 10 m while clients exist. Treat it as an early warning for CPU saturation or runaway listeners.

## Dashboard guide (`generated/dashboards/streaming.json`)

- **Stats** – current client count, event-loop lag, and PG pool utilization.
- **Clients by type** – shows which pods/connection types are active to quickly see imbalance.
- **Channels, subscriptions, and message flow** – `connected_channels`, `redis_subscriptions`, and in/out message rates link client complaints to Redis or PG health.
- **Eventloop percentiles & GC** – p50/90/99 overlays plus per-kind GC durations explain whether lag spikes are CPU starvation or GC.
- **FDs and pool waiters** – open vs max FDs and PG waiting queries catch OS/DB exhaustion early.
- **Active handles/requests/resources** – shows slow creeps/leaks between deploys.
- **Resource panels** – CPU/memory usage vs requests/limits for `mastodon-streaming.*` pods; if usage hits limits, throttle values or vertical scaling is required.

## Response playbook

- When `MastodonStreamingNoClients` fires, verify Traefik websocket routes and Redis connectivity first. If Grafana also shows Redis messages dropping to zero, restart the streaming deployment with extra logging enabled before touching ingress.
- Eventloop lag alerts often correlate with Sidekiq spikes—if Sidekiq pushes too many streaming jobs, consider smoothing via queue rate limiting rather than scaling streaming pods prematurely.
