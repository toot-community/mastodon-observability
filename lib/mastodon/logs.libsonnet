// Helpers for log dashboards using VictoriaLogs as datasource.
// This module is intentionally minimal: no ingestion or parsing logic.
// It exposes the configured logs datasource and helpers to build label filters.
{
  logs(config):: {
    datasource: config.grafana.logsDatasource,

    // Build a map of label filters for a specific app in a namespace.
    selectorForApp(namespace, appName): {
      'kubernetes.pod_namespace': namespace,
      'kubernetes.pod_labels.app.kubernetes.io/name': appName,
    },

    // Build a map of label filters for only Mastodon app pods in a namespace.
    selectorForMastodon(namespace): {
      'kubernetes.pod_namespace': namespace,
      'kubernetes.pod_labels.app.kubernetes.io/name': 'mastodon-.*',
    },
  },
}
