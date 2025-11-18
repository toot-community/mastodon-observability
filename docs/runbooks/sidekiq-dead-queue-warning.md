# Runbook: MastodonSidekiqDeadQueueWarning

## Summary
Dead queue growth > configured ratio of processed jobs over 1h. Risk of lost work or user-visible lag.

## Quick checks
- Grafana: Sidekiq dashboard → dead vs retry growth panel; failure rate.  
- Logs: Sidekiq/Web for recurring exceptions tied to dead jobs.

## Diagnosis steps
1) Inspect dead jobs to find common failure classes/queues.  
2) Check retries: are they churning and then dying?  
3) Verify dependencies: Redis/DB connectivity, external APIs if jobs call out.

## Mitigation
- Fix or roll back offending code; redeploy workers.  
- Retry dead jobs selectively after fixing the root cause; avoid mass retries without a fix.  
- If external dependency outage: pause jobs hitting it and resume when stable.

## Verification
- Dead queue stops growing; failure rate normalizes.  
- Queue latencies remain healthy; no new error spikes in logs.
