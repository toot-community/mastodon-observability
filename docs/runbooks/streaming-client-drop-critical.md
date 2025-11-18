# Runbook: MastodonStreamingClientDropCritical

## Summary
Connected streaming clients and outbound messages dropped >80% vs recent baseline (or close to zero) for the configured window. Streaming timelines/notifications likely impaired.

## Quick checks
- Grafana: Streaming dashboard → client baseline vs current, messages sent/received.  
- Logs: Streaming logs for disconnect storms, delivery errors.

## Diagnosis steps
1) Determine if drop is global or tied to a deploy/ingress change.  
2) Check pod health/restarts; ensure baseline has repopulated post-maintenance.  
3) If messages received are steady but sent is near zero, delivery is stuck; inspect Redis pub/sub connectivity and outbound handlers.

## Mitigation
- Restart unhealthy streaming pods; roll back recent streaming changes if correlated.  
- Revert ingress/network changes if they align with the drop.  
- If delivery stalled, address Redis/pubsub issues or offending code paths.

## Verification
- Clients and messages return near baseline; alert clears.  
- Logs show normal connect/deliver patterns; users report recovered timelines.
