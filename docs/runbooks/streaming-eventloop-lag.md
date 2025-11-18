# Runbook: MastodonStreamingEventloopLag

## Summary
Streaming eventloop p99 lag above threshold while clients are connected. Risk of delayed timelines.

## Quick checks
- Grafana: Streaming dashboard → eventloop lag distribution, CPU, connected clients, Redis/PG pool utilization.  
- Logs: Streaming logs for GC pauses, slow handlers, or Redis/PG errors.

## Diagnosis steps
1) Look for CPU saturation or runaway GC: check CPU panel and heap/lag correlation.  
2) Check Redis/PG connectivity latency; verify pub/sub not stalled.  
3) Review recent deploys/config changes that may add heavy synchronous work in the event loop.

## Mitigation
- Restart hot pods to clear leaks; scale streaming replicas if CPU-bound.  
- Move heavy work off the event loop; roll back if a change introduced blocking calls.  
- Address Redis/PG slowness if evident (connection count, timeouts).

## Verification
- Eventloop lag drops below threshold; clients remain connected; no related errors in logs.
