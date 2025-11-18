# Runbook: MastodonWebLatencyWarning

## Summary
Edge APDEX <0.85 for 15m. Degraded user experience without a hard outage.

## Quick checks
- Grafana: Web dashboard → APDEX over time, latency breakdown, 5xx rate.  
- Logs: Web logs (namespace) to spot slow routes/errors.

## Diagnosis steps
1) Identify if tail or component is driving APDEX drop: check SQL/Redis/Queue averages and percentiles.  
2) Look for localized hot controllers/actions (classification + logs).  
3) Check saturation signals: CPU, Puma backlog/threads, DB pool waiters.

## Mitigation
- Tune or disable the slowest endpoint causing APDEX drop; scale web if CPU/backlog high.  
- Address DB contention (indexes, query fixes) if SQL dominates.  
- If ingress/queue delay suspected, review timeouts briefly; prefer scaling web first.

## Verification
- APDEX rises above 0.85 and latency panels normalize; no backlog/pool waiters sustained.  
- Alert clears after the “for” window with stable metrics.
