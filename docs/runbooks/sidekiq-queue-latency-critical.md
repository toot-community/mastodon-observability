# Runbook: MastodonSidekiqQueueLatencyCritical

## Summary
p95 queue latency > critical threshold for 10m. Jobs are backing up and user-visible actions (notifications, timelines) may lag.

## Quick checks
- Grafana: Sidekiq dashboard → per-queue latency (critical window) and backlog.  
- Grafana: Overview → Sidekiq latency panel for context.  
- Logs: Web/Sidekiq logs for job failures or Redis/DB errors.

## Diagnosis steps
1) Identify which queue(s) are hot.  
2) Check worker saturation: CPU, memory, and DB pool utilization.  
3) Inspect failure rate (`mastodon:sidekiq_jobs:failed_rate5m`) and dead/retry growth.  
4) Verify Redis health if all queues stall together.

## Mitigation
- Scale Sidekiq workers for the hot queue; ensure Redis and DB can handle added load.  
- Pause or throttle non-essential jobs if infrastructure is constrained.  
- Fix failing jobs that churn retries/dead queue quickly.  
- Roll back recent code/config if regressions align with deploy.

## Verification
- Queue p95 drops below the critical threshold; backlog shrinks.  
- Failure rate stabilizes; no large dead/retry growth.  
- Web latency/availability unaffected or improving.
