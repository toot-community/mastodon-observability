local cfg = import './config.libsonnet';
local fmt(str, args) = std.format(str, args);
local helper(config) = {
  nsRegex: '^(?:' + std.join('|', config.supportedNamespaces) + ')$',
  alertNsRegex: '^(?:' + std.join('|', config.alertNamespaces) + ')$',
  selector(extra=''):: fmt('namespace=~"%s"%s', [self.nsRegex, if extra != '' then ',' + extra else '']),
  alertSelector(extra=''):: fmt('namespace=~"%s"%s', [self.alertNsRegex, if extra != '' then ',' + extra else '']),
  metric(metricName, extra=''):: fmt('%s{%s}', [metricName, self.alertSelector(extra)]),
};

local buildGroups(config) =
  (local h = helper(config);
   [
     {
       name: 'mastodon-web-alerts',
       rules: [
         {
           alert: 'MastodonWebAvailabilityCritical',
           expr:
             fmt('(%s > 14) and (%s > 14)', [
               h.metric('mastodon:web_availability:burn_rate_5m'),
               h.metric('mastodon:web_availability:burn_rate_1h'),
             ]),
           'for': '5m',
           labels: {
             severity: 'critical',
             service: 'mastodon-web',
           },
           annotations: {
             summary: 'Web availability SLO burn running hot',
             description: 'Sustained >14x error budget burn (5m & 1h) for user-facing requests in {{ $labels.namespace }} — fast-burn multiplier for 30d 99.5% SLO (budget would exhaust in ~2h). Check dashboards: Mastodon Overview (availability/burn) and Web logs panel (namespace prefilled).',
             runbook: 'https://github.com/toot-community/mastodon-observability/blob/main/docs/runbooks/web-availability-critical.md',
             grafana_dashboards: 'overview:web logs',
           },
         },
         {
           alert: 'MastodonWebAvailabilityWarning',
           expr:
             fmt('(%s > 3) and (%s > 1)', [
               h.metric('mastodon:web_availability:burn_rate_30m'),
               h.metric('mastodon:web_availability:burn_rate_6h'),
             ]),
           'for': '15m',
           labels: {
             severity: 'warning',
             service: 'mastodon-web',
           },
           annotations: {
             summary: 'Web availability budget burn elevated',
             description: 'Error budget burn is trending high (30m/6h) in {{ $labels.namespace }} — investigate before paging impact. Pivot: Mastodon Overview (burn) → Web dashboard → Web logs panel (filter namespace).',
             runbook: 'https://github.com/toot-community/mastodon-observability/blob/main/docs/runbooks/web-availability-warning.md',
             grafana_dashboards: 'overview:web logs',
           },
         },
         {
           alert: 'MastodonWebLatencyCritical',
           expr:
             fmt('(%s > %.3f) and (%s > 1)', [
               h.metric('mastodon:web_latency:p99_seconds'),
               config.slo.latency.frustratedSeconds,
               h.metric('mastodon:web_requests_user:rate5m'),
             ]),
           'for': '10m',
           labels: {
             severity: 'critical',
             service: 'mastodon-web',
           },
           annotations: {
             summary: 'Web p99 latency is above 1s',
             description: fmt('User-facing request p99 latency is above %.0f ms while traffic is present in {{ $labels.namespace }}. Check Web/Overview dashboards and Web logs for errors/slow endpoints.', [config.slo.latency.frustratedSeconds * 1000]),
             runbook: 'https://github.com/toot-community/mastodon-observability/blob/main/docs/runbooks/web-latency-critical.md',
             grafana_dashboards: 'web:web logs',
           },
         },
         {
           alert: 'MastodonWebLatencyWarning',
           // TODO(traefik-refactor): Ensure edge APDEX alert tracks Traefik-derived recording rule semantics.
           expr: fmt('%s < 0.85', [h.metric('mastodon:edge_apdex:overall')]),
           'for': '15m',
           labels: {
             severity: 'warning',
             service: 'mastodon-web',
           },
           annotations: {
             summary: 'Web latency APDEX degraded',
             description: 'Approximate APDEX dropped below 0.85 in {{ $labels.namespace }}; review SQL vs app latency panels and Web logs for errors/slow routes.',
             runbook: 'https://github.com/toot-community/mastodon-observability/blob/main/docs/runbooks/web-latency-warning.md',
             grafana_dashboards: 'web:web logs',
           },
         },
       ],
     },

     {
       name: 'mastodon-sidekiq-alerts',
       rules: [
         {
           alert: 'MastodonSidekiqQueueLatencyCritical',
           expr:
             fmt('%s > %d', [
               h.metric('mastodon:sidekiq_queue_latency:p95'),
               config.sidekiq.latencyCriticalSeconds,
             ]),
           'for': config.sidekiq.latencyCriticalWindow,
           labels: {
             severity: 'critical',
             service: 'mastodon-sidekiq',
           },
           annotations: {
             summary: fmt('Sidekiq p95 latency above %d seconds', [config.sidekiq.latencyCriticalSeconds]),
             description: fmt('Queue {{ $labels.queue }} latency p95 is %.0f seconds in {{ $labels.namespace }}; backlog is user-visible.', [config.sidekiq.latencyCriticalSeconds]),
             runbook: 'https://github.com/toot-community/mastodon-observability/blob/main/docs/runbooks/sidekiq-queue-latency-critical.md',
           },
         },
         {
           alert: 'MastodonSidekiqQueueLatencyWarning',
           expr:
             fmt('%s > %d', [
               h.metric('mastodon:sidekiq_queue_latency:p95_short'),
               config.sidekiq.latencyWarningSeconds,
             ]),
           'for': config.sidekiq.latencyWarningWindow,
           labels: {
             severity: 'warning',
             service: 'mastodon-sidekiq',
           },
           annotations: {
             summary: 'Sidekiq p95 latency trending high',
             description: fmt('Queue {{ $labels.queue }} latency > %d seconds for %s in {{ $labels.namespace }}.', [config.sidekiq.latencyWarningSeconds, config.sidekiq.latencyWarningWindow]),
             runbook: 'https://github.com/toot-community/mastodon-observability/blob/main/docs/runbooks/sidekiq-queue-latency-warning.md',
           },
         },
         {
           alert: 'MastodonSidekiqDeadQueueWarning',
           expr: fmt('%s > %.3f', [h.metric('mastodon:sidekiq_dead_growth_ratio_1h'), config.sidekiq.deadQueue.warningGrowthRatio]),
           'for': config.sidekiq.deadQueue.evaluationWindow,
           labels: {
             severity: 'warning',
             service: 'mastodon-sidekiq',
           },
           annotations: {
             summary: 'Sidekiq dead queue growth excessive',
             description: fmt('Dead queue is growing faster than %.1f%% of processed jobs in {{ $labels.namespace }}.', [config.sidekiq.deadQueue.warningGrowthRatio * 100]),
             runbook: 'https://github.com/toot-community/mastodon-observability/blob/main/docs/runbooks/sidekiq-dead-queue-warning.md',
           },
         },
       ],
     },

     {
       name: 'mastodon-streaming-alerts',
       rules: [
         {
           alert: 'MastodonStreamingClientDropWarning',
           expr:
             fmt('(%s > %.2f) and (%s > %.2f)', [
               h.metric('mastodon:streaming_clients:drop_ratio'),
               config.streaming.drop.warningRatio,
               h.metric('mastodon:streaming_messages_sent:drop_ratio'),
               config.streaming.drop.warningRatio,
             ]),
           'for': config.streaming.drop.window,
           labels: {
             severity: 'warning',
             service: 'mastodon-streaming',
           },
           annotations: {
             summary: 'Streaming clients dropped significantly',
             description: fmt('Connected clients and outbound messages dropped >%.0f%% vs recent baseline in {{ $labels.namespace }}. Check streaming dashboard for reconnect storms or delivery stalls.', [config.streaming.drop.warningRatio * 100]),
             runbook: 'https://github.com/toot-community/mastodon-observability/blob/main/docs/runbooks/streaming-client-drop-warning.md',
             grafana_dashboards: 'streaming',
           },
         },
         {
           alert: 'MastodonStreamingClientDropCritical',
           expr:
             fmt('(%s > %.2f) and (%s > %.2f)', [
               h.metric('mastodon:streaming_clients:drop_ratio'),
               config.streaming.drop.criticalRatio,
               h.metric('mastodon:streaming_messages_sent:drop_ratio'),
               config.streaming.drop.criticalRatio,
             ]),
           'for': config.streaming.drop.window,
           labels: {
             severity: 'critical',
             service: 'mastodon-streaming',
           },
           annotations: {
             summary: 'Streaming clients severely dropped',
             description: fmt('Connected clients and outbound messages dropped >%.0f%% vs recent baseline in {{ $labels.namespace }}. Investigate streaming availability.', [config.streaming.drop.criticalRatio * 100]),
             runbook: 'https://github.com/toot-community/mastodon-observability/blob/main/docs/runbooks/streaming-client-drop-critical.md',
             grafana_dashboards: 'streaming',
           },
         },
         {
           alert: 'MastodonStreamingEventloopLag',
           expr:
             fmt('(%s > %.3f) and (%s > 0)', [
               h.metric('mastodon:streaming_eventloop_lag_p99'),
               config.streaming.eventloopLagWarningSeconds,
               h.metric('mastodon:streaming_connected_clients_total'),
             ]),
           'for': config.streaming.lagWindow,
           labels: {
             severity: 'warning',
             service: 'mastodon-streaming',
           },
           annotations: {
             summary: fmt('Streaming event loop lag > %.0f ms', [config.streaming.eventloopLagWarningSeconds * 1000]),
             description: fmt('Event loop lag p99 is above %.0f ms while clients are connected in {{ $labels.namespace }}. Check Streaming dashboard and logs for slow handlers/Redis issues.', [config.streaming.eventloopLagWarningSeconds * 1000]),
             runbook: 'https://github.com/toot-community/mastodon-observability/blob/main/docs/runbooks/streaming-eventloop-lag.md',
             grafana_dashboards: 'streaming:streaming logs',
           },
         },
       ],
     },
   ]);

{
  groups(config=cfg):: buildGroups(config),

  prometheusRule(config=cfg):: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      name: 'mastodon-alert-rules',
      namespace: config.observabilityNamespace,
      labels: {
        app: 'mastodon-observability',
        role: 'alerting',
      },
    },
    spec: {
      groups: buildGroups(config),
    },
  },
}
