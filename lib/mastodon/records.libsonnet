local cfg = import './config.libsonnet';
local fmt(str, args) = std.format(str, args);

local regexFrom(items) = if std.length(items) == 0 then '.*' else '^(?:' + std.join('|', items) + ')$';

local helper(config) = {
  nsRegex: '^(?:' + std.join('|', config.supportedNamespaces) + ')$',
  selector(extra=''):: fmt('namespace=~"%s"%s', [self.nsRegex, if extra != '' then ',' + extra else '']),
  metric(metricName, extra=''):: fmt('%s{%s}', [metricName, self.selector(extra)]),
  sumRate(metricName, window, extra=''):: fmt('sum by (namespace) (rate(%s[%s]))', [self.metric(metricName, extra), window]),
  sumIncrease(metricName, window, extra=''):: fmt('sum by (namespace) (increase(%s[%s]))', [self.metric(metricName, extra), window]),
  avgQuantile(metricName, quantile):: fmt('avg by (namespace) (%s)', [self.metric(metricName, fmt('quantile="%s"', [quantile]))]),
  requestClassFilter(className):: fmt('controller=~"%s",action=~"%s"', [
    regexFrom(config.requestClasses[className].controllers),
    regexFrom(config.requestClasses[className].actions),
  ]),
};

local errorBudget(config) = 1 - config.slo.availabilityTarget;
local sloWindows = ['5m', '30m', '1h', '6h', '30d'];

local buildGroups(config) = (
  local h = helper(config);
  // zeroNs provides a namespace-aligned zero time series so arithmetic never drops missing series
  // (e.g., 0 errors still emit a 0 rather than disappearing).
  local zeroNs = fmt('sum by (namespace) (0 * %s)', [h.metric('ruby_http_requests_total')]);
  // We rely on NGINX histogram buckets for APDEX because Rails/Puma only exposes summaries (no buckets),
  // which made the prior mean-based APDEX stay pegged at ~1.0. Using edge latency reflects user experience
  // and aligns with ingress-level SLOs; keep mean latency for diagnostics.
  local edgeApdexExpr(baseSelector, window=config.ingress.latencyWindow, group='namespace, ingress') =
    local satisfiedLe = std.format('%g', config.ingress.apdex.satisfiedSeconds);
    local toleratingLe = std.format('%g', config.ingress.apdex.toleratingSeconds);
    local minRate = config.ingress.apdex.minRequestRate;
    local bucket(le, extra='') = fmt('nginx_ingress_controller_request_duration_seconds_bucket{%s%s,le="%s"}', [baseSelector, extra, le]);
    local base(le, extra='') =
      fmt('sum by (%s) (label_replace(rate(%s[%s]), "namespace", "$1", "exported_namespace", "(.*)"))',
          [group, bucket(le, extra), window]);
    local satisfied = base(satisfiedLe, ',status!~"5.."');
    local tolerating = base(toleratingLe, ',status!~"5.."');
    local total = base('+Inf');
    // If traffic is below minRate, drop the series (no data) instead of misleading 0/1.
    local apdex = fmt('(%s + 0.5 * clamp_min(%s - %s, 0)) / clamp_min(%s, 1e-6)', [satisfied, tolerating, satisfied, total]);
    fmt('(%s) and on (%s) (%s >= %f)', [apdex, group, total, minRate])
  ;
  [
    // Web SLO + latency recording rules
    {
      name: 'mastodon-web-slo',
      rules: [
        {
          record: 'mastodon:web_requests:rate5m',
          expr: h.sumRate('ruby_http_requests_total', '5m'),
        },
        {
          record: 'mastodon:web_requests_user:rate5m',
          expr: h.sumRate('ruby_http_requests_total', '5m', h.requestClassFilter('user_facing')),
        },
        {
          record: 'mastodon:web_requests_federation:rate5m',
          expr: h.sumRate('ruby_http_requests_total', '5m', h.requestClassFilter('federation')),
        },
        {
          record: 'mastodon:web_requests_uncategorized:rate5m',
          expr: 'clamp_min(mastodon:web_requests:rate5m - mastodon:web_requests_user:rate5m - mastodon:web_requests_federation:rate5m, 0)',
        },
        {
          record: 'mastodon:web_requests:errors5m',
          expr: fmt('((%s) or on (namespace) %s)', [h.sumRate('ruby_http_requests_total', '5m', 'status=~"5.."'), zeroNs]),
        },
        {
          record: 'mastodon:web_requests_federation:errors5m',
          expr: fmt('((%s) or on (namespace) %s)', [h.sumRate('ruby_http_requests_total', '5m', h.requestClassFilter('federation') + ',status=~"5.."'), zeroNs]),
        },
        {
          record: 'mastodon:web_requests_user:errors5m',
          expr: 'clamp_min(mastodon:web_requests:errors5m - mastodon:web_requests_federation:errors5m, 0)',
        },
      ] + std.foldl(
        function(acc, win)
          acc + [
            {
              record: fmt('mastodon:web_availability:error_ratio_%s', [win]),
              expr:
                fmt('clamp_min(((%s) or on (namespace) %s) - ((%s) or on (namespace) %s), 0) /\n              clamp_min(((%s) or on (namespace) %s) - ((%s) or on (namespace) %s), 1e-6)', [
                  h.sumIncrease('ruby_http_requests_total', config.slo.windows[win], 'status=~"5.."'),
                  zeroNs,
                  h.sumIncrease('ruby_http_requests_total', config.slo.windows[win], h.requestClassFilter('federation') + ',status=~"5.."'),
                  zeroNs,
                  h.sumIncrease('ruby_http_requests_total', config.slo.windows[win]),
                  zeroNs,
                  h.sumIncrease('ruby_http_requests_total', config.slo.windows[win], h.requestClassFilter('federation')),
                  zeroNs,
                ]),
            },
            {
              record: fmt('mastodon:web_availability:burn_rate_%s', [win]),
              expr: fmt('(mastodon:web_availability:error_ratio_%s) / %.6f', [win, errorBudget(config)]),
            },
            {
              record: fmt('mastodon:web_availability:availability_%s', [win]),
              expr: fmt('1 - mastodon:web_availability:error_ratio_%s', [win]),
            },
          ],
        sloWindows,
        []
      ),
    },

    {
      name: 'mastodon-web-latency',
      rules: [
        {
          record: 'mastodon:web_latency:mean_seconds',
          expr: fmt('(%s) / clamp_min(%s, 1e-6)', [
            h.sumRate('ruby_http_request_duration_seconds_sum', '5m', h.requestClassFilter('user_facing')),
            h.sumRate('ruby_http_request_duration_seconds_count', '5m', h.requestClassFilter('user_facing')),
          ]),
        },
        {
          record: 'mastodon:web_latency:sql_avg_seconds',
          expr: fmt('(%s) / clamp_min(%s, 1e-6)', [
            h.sumRate('ruby_http_request_sql_duration_seconds_sum', '5m', h.requestClassFilter('user_facing')),
            h.sumRate('ruby_http_request_sql_duration_seconds_count', '5m', h.requestClassFilter('user_facing')),
          ]),
        },
        {
          record: 'mastodon:web_latency:redis_avg_seconds',
          expr: fmt('(%s) / clamp_min(%s, 1e-6)', [
            h.sumRate('ruby_http_request_redis_duration_seconds_sum', '5m', h.requestClassFilter('user_facing')),
            h.sumRate('ruby_http_request_redis_duration_seconds_count', '5m', h.requestClassFilter('user_facing')),
          ]),
        },
        {
          record: 'mastodon:web_latency:queue_avg_seconds',
          expr: fmt('(%s) / clamp_min(%s, 1e-6)', [
            h.sumRate('ruby_http_request_queue_duration_seconds_sum', '5m', h.requestClassFilter('user_facing')),
            h.sumRate('ruby_http_request_queue_duration_seconds_count', '5m', h.requestClassFilter('user_facing')),
          ]),
        },
        {
          record: 'mastodon:web_latency:app_avg_seconds',
          expr: 'clamp_min(\n            mastodon:web_latency:mean_seconds\n            - (mastodon:web_latency:sql_avg_seconds or on (namespace) vector(0))\n            - (mastodon:web_latency:redis_avg_seconds or on (namespace) vector(0))\n            - (mastodon:web_latency:queue_avg_seconds or on (namespace) vector(0))\n          , 0)',
        },
        {
          record: 'mastodon:web_latency:p50_seconds',
          expr: h.avgQuantile('ruby_http_request_duration_seconds', '0.5'),
        },
        {
          record: 'mastodon:web_latency:p90_seconds',
          expr: h.avgQuantile('ruby_http_request_duration_seconds', '0.9'),
        },
        {
          record: 'mastodon:web_latency:p99_seconds',
          expr: h.avgQuantile('ruby_http_request_duration_seconds', '0.99'),
        },
      ],
    },

    {
      name: 'mastodon-sidekiq',
      rules: [
        {
          record: 'mastodon:sidekiq_queue_latency:p95',
          expr: fmt('quantile_over_time(0.95, sidekiq_queue_latency_seconds{%s,queue=~"%s"}[%s])', [
            h.selector(),
            '^(?:' + std.join('|', config.sidekiq.queues) + ')$',
            config.sidekiq.latencyCriticalWindow,
          ]),
        },
        {
          record: 'mastodon:sidekiq_queue_latency:p95_short',
          expr: fmt('quantile_over_time(0.95, sidekiq_queue_latency_seconds{%s,queue=~"%s"}[%s])', [
            h.selector(),
            '^(?:' + std.join('|', config.sidekiq.queues) + ')$',
            config.sidekiq.latencyWarningWindow,
          ]),
        },
        {
          record: 'mastodon:sidekiq_queue_latency_current',
          expr: fmt('sidekiq_queue_latency_seconds{%s}', [h.selector()]),
        },
        {
          record: 'mastodon:sidekiq_jobs:processed_rate5m',
          expr: fmt('sum by (namespace, queue) (rate(sidekiq_jobs_total{%s}[5m]))', [h.selector()]),
        },
        {
          record: 'mastodon:sidekiq_jobs:failed_rate5m',
          expr: fmt('sum by (namespace, queue) (rate(sidekiq_failed_jobs_total{%s}[5m]))', [h.selector()]),
        },
        {
          record: 'mastodon:sidekiq_dead_growth_ratio_1h',
          expr:
            fmt('(\n                sum by (namespace) (increase(sidekiq_dead_jobs_total{%s}[%s])) /\n                clamp_min(sum by (namespace) (increase(sidekiq_jobs_total{%s}[%s])), 1)\n              )', [
              h.selector(),
              config.sidekiq.deadQueue.evaluationWindow,
              h.selector(),
              config.sidekiq.deadQueue.evaluationWindow,
            ]),
        },
        {
          record: 'mastodon:sidekiq_db_pool_utilization',
          expr:
            fmt('sum by (namespace) (ruby_active_record_connection_pool_busy{%s}) /\n               clamp_min(sum by (namespace) (ruby_active_record_connection_pool_size{%s}), 1)', [h.selector(), h.selector()]),
        },
      ],
    },

    {
      name: 'mastodon-streaming',
      rules: [
        {
          record: 'mastodon:streaming_connected_clients',
          expr: fmt('sum by (namespace, type) (connected_clients{%s})', [h.selector()]),
        },
        {
          record: 'mastodon:streaming_connected_clients_total',
          expr: fmt('sum by (namespace) (connected_clients{%s})', [h.selector()]),
        },
        {
          record: 'mastodon:streaming_clients:baseline',
          expr: fmt('max_over_time(mastodon:streaming_connected_clients_total{%s}[%s])', [h.selector(), config.streaming.baselineWindow]),
        },
        {
          record: 'mastodon:streaming_clients:drop_ratio',
          expr: 'clamp_min(1 - (mastodon:streaming_connected_clients_total / clamp_min(mastodon:streaming_clients:baseline, 1)), 0)',
        },
        {
          record: 'mastodon:streaming_eventloop_lag_p99',
          expr: fmt('max by (namespace) (nodejs_eventloop_lag_p99_seconds{%s})', [h.selector()]),
        },
        {
          record: 'mastodon:streaming_messages_sent_rate5m',
          expr: fmt('sum by (namespace, type) (rate(messages_sent_total{%s}[5m]))', [h.selector()]),
        },
        {
          record: 'mastodon:streaming_messages_recv_rate5m',
          expr: fmt('sum by (namespace) (rate(redis_messages_received_total{%s}[5m]))', [h.selector()]),
        },
        {
          record: 'mastodon:streaming_messages_sent:baseline',
          expr: fmt('avg_over_time(mastodon:streaming_messages_sent_rate5m{%s}[%s])', [h.selector(), config.streaming.baselineWindow]),
        },
        {
          record: 'mastodon:streaming_messages_sent:drop_ratio',
          expr: 'clamp_min(1 - (mastodon:streaming_messages_sent_rate5m / clamp_min(mastodon:streaming_messages_sent:baseline, 1e-6)), 0)',
        },
        {
          record: 'mastodon:streaming_pg_pool_utilization',
          expr:
            fmt('sum by (namespace) (pg_pool_total_connections{%s} - pg_pool_idle_connections{%s}) /\n               clamp_min(sum by (namespace) (pg_pool_total_connections{%s}), 1)', [h.selector(), h.selector(), h.selector()]),
        },
      ],
    },

    {
      name: 'mastodon-edge',
      rules: (
        // ingress-nginx exposes the target object namespace as "exported_namespace"
        local ingressSelector(extra='') = fmt('exported_namespace=~"%s"%s', [h.nsRegex, if extra != '' then ',' + extra else '']);
        local apdexSelector(extra='') = fmt('%s%s', [ingressSelector(), if extra != '' then ',' + extra else '']);
        local latencySelector(extra='') = fmt('%s,host!~"%s"%s', [ingressSelector(), config.ingress.latencyHostExcludeRegex, if extra != '' then ',' + extra else '']);
        local appIngressRegex = regexFrom(config.ingress.apdex.appIngresses);
        local staticIngressRegex = regexFrom(config.ingress.apdex.staticIngresses);
        local labelNamespace(expr) = fmt('sum by (namespace, ingress, host) (label_replace(%s, "namespace", "$1", "exported_namespace", "(.*)"))', [expr]);
        [
          {
            record: 'mastodon:edge_rps',
            expr: labelNamespace(fmt('sum by (exported_namespace, ingress, host) (rate(nginx_ingress_controller_requests{%s}[%s]))', [ingressSelector(), config.ingress.rpsWindow])),
          },
          {
            record: 'mastodon:edge_errors_rate',
            expr: labelNamespace(fmt('sum by (exported_namespace, ingress, host) (rate(nginx_ingress_controller_requests{%s}[%s]))', [ingressSelector('status=~"5.."'), config.ingress.rpsWindow])),
          },
          {
            record: 'mastodon:edge_apdex:app',
            expr: edgeApdexExpr(apdexSelector(fmt('ingress=~"%s"', [appIngressRegex])), config.ingress.latencyWindow, 'namespace, ingress'),
          },
          {
            record: 'mastodon:edge_apdex:static',
            expr: edgeApdexExpr(apdexSelector(fmt('ingress=~"%s"', [staticIngressRegex])), config.ingress.latencyWindow, 'namespace, ingress'),
          },
          {
            record: 'mastodon:edge_apdex:overall',
            expr: edgeApdexExpr(apdexSelector(fmt('ingress=~"%s"', [appIngressRegex])), config.ingress.latencyWindow, 'namespace'),
          },
          {
            record: 'mastodon:edge_latency_p50',
            expr: labelNamespace(fmt('histogram_quantile(0.5, sum by (exported_namespace, ingress, host, le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{%s}[%s])))', [latencySelector(), config.ingress.latencyWindow])),
          },
          {
            record: 'mastodon:edge_latency_p90',
            expr: labelNamespace(fmt('histogram_quantile(0.9, sum by (exported_namespace, ingress, host, le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{%s}[%s])))', [latencySelector(), config.ingress.latencyWindow])),
          },
          {
            record: 'mastodon:edge_latency_p99',
            expr: labelNamespace(fmt('histogram_quantile(0.99, sum by (exported_namespace, ingress, host, le) (rate(nginx_ingress_controller_request_duration_seconds_bucket{%s}[%s])))', [latencySelector(), config.ingress.latencyWindow])),
          },
          {
            record: 'mastodon:edge_cache_hit_ratio',
            expr: 'clamp_max(1 - (mastodon:web_requests:rate5m / clamp_min(sum by (namespace) (mastodon:edge_rps), 1e-3)), 1)',
          },
        ]
      ),
    },
  ]
);

{
  groups(config=cfg):: buildGroups(config),
  prometheusRule(config=cfg):: {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      name: 'mastodon-recording-rules',
      namespace: config.observabilityNamespace,
      labels: {
        app: 'mastodon-observability',
        role: 'recording',
      },
    },
    spec: {
      groups: buildGroups(config),
    },
  },
}
