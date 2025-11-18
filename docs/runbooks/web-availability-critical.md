# Runbook: MastodonWebAvailabilityCritical

## Summary
Critical web availability burn (>14x on 5m & 1h) for user-facing routes. Users are receiving 5xx at scale.

## Quick checks
- Grafana: Mastodon Overview → Availability/Burn panels (`$namespace` set from alert).
- Grafana: Web dashboard → 5xx rate, request classification, APDEX, latency panels.
- Logs: Web logs panel (filter `$namespace`) for dominant 5xx signatures.

## Diagnosis steps
1) Confirm 5xx source: is the spike ingress (timeouts) or app (controller-specific)? Use Web 5xx panel + logs.  
2) Look for saturation: Puma backlog/threads, DB pool utilization/waiters, Redis/queue latency panels.  
3) Check upstream dependencies: Sidekiq queue latency (Overview/Sidekiq dashboards) if 5xx correlate with background lag; Streaming only if relevant.

## Mitigation
- If app overload: scale web replicas or Puma workers conservatively; reduce expensive features if toggles exist.  
- If DB pool exhaustion: increase pool size cautiously or lower concurrency; restart hot pods if stuck.  
- If ingress timeouts: lengthen upstream_timeout/keepalive only if known, otherwise scale web.  
- Roll back recent deploy if a change correlates with spike.

## Verification
- Burn rates fall below alert thresholds and 5xx rate returns near zero for the namespace.  
- APDEX/latency recover; backlog and pool waiters normal.  
- Close alert only after sustained stability across fast/slow windows.
