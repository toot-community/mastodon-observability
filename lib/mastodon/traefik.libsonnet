local fmt(str, args) = std.format(str, args);

local regexFrom(items) =
  if std.length(items) == 0 then '.*' else std.join('|', items);

// Helper utilities for Traefik metrics with derived namespace/ingress labels.
// These helpers are read-only wrappers around existing Traefik metrics.
{
  // Map of known service kinds; extendable if new routes are added.
  serviceKinds:: {
    app: 'varnish-for-app',
    static: 'varnish-for-static',
    streaming: 'mastodon-streaming',
    web: 'mastodon-web',
  },

  helper(config):: (
    local nsPattern = regexFrom(config.supportedNamespaces);
    local kindPattern = regexFrom(std.objectValues(self.serviceKinds));
    local serviceRegex = fmt('^(%s)-(%s)-http-[0-9]+@kubernetesgateway$', [nsPattern, kindPattern]);
    local selector(extra='') = fmt('exported_service=~"%s"%s', [serviceRegex, if extra != '' then ',' + extra else '']);
    local normalizeKinds(kinds) =
      local arr = if std.isArray(kinds) then kinds else [kinds];
      [if std.objectHas(self.serviceKinds, k) then self.serviceKinds[k] else k for k in arr];
    {
      serviceKinds: self.serviceKinds,
      namespacePattern: nsPattern,
      serviceRegex: serviceRegex,
      selector: selector,
      selectorForKinds(kinds, extra=''):: fmt('exported_service=~"^(%s)-(%s)-http-[0-9]+@kubernetesgateway$"%s', [
        nsPattern,
        regexFrom(normalizeKinds(kinds)),
        if extra != '' then ',' + extra else '',
      ]),
      metric(metricName, extra=''):: fmt('%s{%s}', [metricName, selector(extra)]),
      metricForKinds(metricName, kinds, extra=''):: fmt('%s{%s}', [metricName, self.selectorForKinds(kinds, extra)]),
      // Derive namespace+ingress labels from the exported_service label (group1=namespace, group2=route/kind).
      labelNamespaceIngress(expr):: fmt(
        'label_replace(label_replace(%s, "ingress", "$2", "exported_service", "%s"), "namespace", "$1", "exported_service", "%s")',
        [expr, serviceRegex, serviceRegex]
      ),
      // Entrypoint-level helpers (no relabeling; keep as-is).
      entrypointMetric(metricName, extra=''):: fmt('%s%s', [
        metricName,
        if extra != '' then fmt('{%s}', [extra]) else '',
      ]),
    }
  ),
}
