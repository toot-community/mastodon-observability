# Runbook: MastodonWebLatencyCritical

## Summary
User-facing p90 latency >1s for 10m with traffic present. Symptom-level: users perceive slowness. Using p90 instead of p99 avoids noisy alerts from outliers while still catching systemic issues.

## Quick checks
- Grafana: Web dashboard → Latency percentiles, SQL/Redis/Queue breakdown, APDEX, 5xx rate.  
- Logs: Web logs (namespace) for slow endpoints/errors.

## Diagnosis steps
1) Pin the component: compare SQL/Redis/Queue averages vs app. High SQL → DB/queries; high Queue → ingress queues; Redis → cache.  
2) Check resource contention: CPU, Puma backlog/threads, DB pool waiters.  
3) Identify hot controllers/actions via classification + logs.

## Mitigation
- For DB-bound latency: add indexes, kill bad queries, or temporarily scale DB resources; restart runaway pods if needed.  
- For app overload: scale web replicas; reduce expensive features if toggles exist.  
- For queue/ingress: review ingress timeout/keepalive, but prefer scaling web first.

## Verification
- p90 returns <1s and APDEX recovers; backlogs/pool waiters subside.
- No sustained 5xx spike accompanying the latency.
