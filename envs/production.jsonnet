local alerts = import '../lib/mastodon/alerts.libsonnet';
local baseConfig = import '../lib/mastodon/config.libsonnet';
local records = import '../lib/mastodon/records.libsonnet';
local dashboards = {
  overall: import '../lib/mastodon/dashboards/overall.libsonnet',
  web: import '../lib/mastodon/dashboards/web.libsonnet',
  sidekiq: import '../lib/mastodon/dashboards/sidekiq.libsonnet',
  streaming: import '../lib/mastodon/dashboards/streaming.libsonnet',
  edge: import '../lib/mastodon/dashboards/edge.libsonnet',
};

local config = baseConfig.withDefaultNamespace('toot-community');

{
  'alerts/recording-rules.yaml': records.prometheusRule(config),
  'alerts/alert-rules.yaml': alerts.prometheusRule(config),
  'alerts/recording-rules.promtool.yaml': records.prometheusRule(config).spec,
  'alerts/alert-rules.promtool.yaml': alerts.prometheusRule(config).spec,
  'dashboards/overall.json': dashboards.overall.dashboard(config),
  'dashboards/web.json': dashboards.web.dashboard(config),
  'dashboards/sidekiq.json': dashboards.sidekiq.dashboard(config),
  'dashboards/streaming.json': dashboards.streaming.dashboard(config),
  'dashboards/edge.json': dashboards.edge.dashboard(config),
}
