local fmt(str, args) = std.format(str, args);

// Shared helpers for namespace selectors and small utilities reused across alerts/records/dashboards.
{
  // Join items into a regex; anchored by default to match the full label.
  regexFrom(items, anchored=true)::
    if std.length(items) == 0 then '.*'
    else if anchored then '^(?:' + std.join('|', items) + ')$' else std.join('|', items),

  // Build common selectors/metrics for namespaces (and alert namespaces).
  selectors(config):: (
    local nsRegex = self.regexFrom(config.supportedNamespaces);
    local alertNsRegex = self.regexFrom(config.alertNamespaces);
    {
      nsRegex: nsRegex,
      alertNsRegex: alertNsRegex,
      selector(extra=''):: fmt('namespace=~"%s"%s', [nsRegex, if extra != '' then ',' + extra else '']),
      alertSelector(extra=''):: fmt('namespace=~"%s"%s', [alertNsRegex, if extra != '' then ',' + extra else '']),
      metric(metricName, extra=''):: fmt('%s{%s}', [metricName, self.selector(extra)]),
      alertMetric(metricName, extra=''):: fmt('%s{%s}', [metricName, self.alertSelector(extra)]),
    }
  ),
}
