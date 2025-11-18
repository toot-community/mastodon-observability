# Runbook: MastodonWebAvailabilityWarning

## Summary
Web availability burn elevated (30m/6h). Early warning of rising 5xx for user-facing routes.

## Quick checks
- Grafana: Mastodon Overview → Burn panels, Web dashboard → 5xx rate/classification.  
- Logs: Web logs panel (filter `$namespace`) to see recurring 5xx patterns.

## Diagnosis steps
1) Identify the controllers/actions producing 5xx (classification + logs).  
2) Check resource pressure: Puma backlog/threads, DB pool utilization/waiters, Sidekiq queue latency for linked jobs.  
3) Look for ingress timeouts vs app errors.

## Mitigation
- Fix obvious bad deploy or config; roll back if needed.  
- Scale web replicas if CPU/backlog high; adjust DB pool cautiously if waiters are chronic.  
- Coordinate with Sidekiq if failures depend on job lag.

## Verification
- Burn rates drop below warning thresholds; 5xx trend toward zero.  
- Latency/APDEX normal; no backlog/pool waiters sustained.
