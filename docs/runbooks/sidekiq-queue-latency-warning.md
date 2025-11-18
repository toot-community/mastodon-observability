# Runbook: MastodonSidekiqQueueLatencyWarning

## Summary
p95 queue latency above warning threshold for 5m. Early signal of backlog growth.

## Quick checks
- Grafana: Sidekiq dashboard → short-window latency per queue; backlog.  
- Logs: Sidekiq/Web for job failures or Redis/DB issues.

## Diagnosis steps
1) Identify affected queues; check if load spike or failures.  
2) Inspect resource pressure: CPU/memory, DB pool utilization.  
3) Review failed rate and dead/retry trends.

## Mitigation
- Scale workers for hot queues if infrastructure headroom exists.  
- Fix failing jobs causing retries; clean dead queue if blocking.  
- Coordinate with web/app if upstream changes caused load spikes.

## Verification
- Latency returns below warning threshold; backlog not growing.  
- Failure rates normal; dead/retry stable.
