local cfg = import '../config.libsonnet';
local h = import './helpers.libsonnet';

{
  dashboard(config=cfg)::
    local base = h.baseDashboard(config, 'Mastodon Sidekiq', 'mastodon-sidekiq');
    base {
      panels: [
        h.statPanel(config, 1, 'Dead queue growth ratio (1h)', 'mastodon:sidekiq_dead_growth_ratio_1h{namespace="$namespace"}', 'percentunit', 0, 0),
        h.statPanel(config, 2, 'DB pool utilization', 'mastodon:sidekiq_db_pool_utilization{namespace="$namespace"}', 'percentunit', 4, 0),
        h.statPanel(config, 3, 'Enqueued backlog', 'sum by (namespace) (sidekiq_stats_enqueued{namespace="$namespace"})', 'none', 8, 0),

        h.timeseriesPanel(config, 4, 'Per-queue latency (p95 seconds)', [
          { expr: 'mastodon:sidekiq_queue_latency:p95{namespace="$namespace",queue!=""}', legendFormat: '{{queue}}' },
        ], 's', 0, 5, 12, 8),

        h.timeseriesPanel(config, 5, 'Queue latency (short window)', [
          { expr: 'max by (namespace, queue) (mastodon:sidekiq_queue_latency:p95_short{namespace="$namespace",queue!=""})', legendFormat: '{{queue}} short' },
        ], 's', 12, 5, 12, 8),

        h.timeseriesPanel(config, 6, 'Job throughput', [
          { expr: 'sum by (namespace, queue) (mastodon:sidekiq_jobs:processed_rate5m{namespace="$namespace",queue!=""})', legendFormat: '{{queue}} processed' },
        ], 'p/s', 0, 13, 12, 8),

        h.timeseriesPanel(config, 7, 'Job failure rate', [
          { expr: 'sum by (namespace, queue) (mastodon:sidekiq_jobs:failed_rate5m{namespace="$namespace",queue!=""})', legendFormat: '{{queue}} failed' },
        ], 'p/s', 12, 13, 12, 8),

        h.timeseriesPanel(config, 8, 'Dead vs retry queue growth', [
          { expr: 'deriv(max by (namespace) (sidekiq_stats_dead_size{namespace="$namespace"})[15m])', legendFormat: 'dead deriv' },
          { expr: 'deriv(max by (namespace) (sidekiq_stats_retry_size{namespace="$namespace"})[15m])', legendFormat: 'retry deriv' },
        ], 'none', 0, 21, 12, 7),

        h.timeseriesPanel(config, 9, 'CPU usage (total)', [
          { expr: 'sum by (namespace) (rate(container_cpu_usage_seconds_total{namespace="$namespace",pod=~"mastodon-sidekiq.*",container!=""}[5m]))', legendFormat: 'total usage' },
        ], 'cores', 0, 28, 12, 8),

        h.timeseriesPanel(config, 10, 'Memory usage (total)', [
          { expr: 'sum by (namespace) (container_memory_working_set_bytes{namespace="$namespace",pod=~"mastodon-sidekiq.*",container!=""})', legendFormat: 'total usage' },
        ], 'bytes', 12, 28, 12, 8),
      ],
    },
}
