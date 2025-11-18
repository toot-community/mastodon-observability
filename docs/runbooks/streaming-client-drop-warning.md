# Runbook: MastodonStreamingClientDropWarning

## Summary
Connected streaming clients and outbound messages dropped >50% vs recent baseline for the configured window. Early signal of partial outage or delivery stall.

## Quick checks
- Grafana: Streaming dashboard → client baseline vs current, messages sent/received, eventloop lag.
- Logs: Streaming logs for reconnect storms or delivery errors.

## Diagnosis steps
1) Confirm drop scope: partial vs near-total. Check if messages received are steady while sent drops (delivery stalled).  
2) Look for deploy/ingress/network changes causing reconnects.  
3) Check pod health and restart count; ensure baseline window has repopulated after maintenance.

## Mitigation
- Restart unhealthy streaming pods if stuck; roll back recent streaming deploy if correlated.  
- If ingress/network related, revert recent config/cert changes.  
- If delivery stalled (recv steady, sent low), inspect Redis pub/sub connectivity or code paths handling outbound fanout.

## Verification
- Clients and messages return near baseline; alert clears after window.  
- Logs show normal connect/deliver patterns; no sustained lag or errors.
