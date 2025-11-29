local fmt(str, args) = std.format(str, args);

local defaultNamespace(config) = if std.objectHas(config, 'defaultNamespace') then config.defaultNamespace else config.supportedNamespaces[0];
local namespaceVar(config) = {
  name: 'namespace',
  label: 'Namespace',
  type: 'query',
  definition: 'label_values(mastodon:web_requests:rate5m, namespace)',
  query: 'label_values(mastodon:web_requests:rate5m, namespace)',
  includeAll: false,
  multi: false,
  refresh: 1,
  sort: 1,
  current: {
    text: defaultNamespace(config),
    value: defaultNamespace(config),
  },
};

{
  namespaceVariable(config):: namespaceVar(config),
  podCpuExpr(appPattern):: fmt('sum by (namespace) (rate(container_cpu_usage_seconds_total{namespace="$namespace",pod=~"%s",container!=""}[5m]))', [appPattern]),
  podMemoryExpr(appPattern):: fmt('sum by (namespace) (container_memory_working_set_bytes{namespace="$namespace",pod=~"%s",container!=""})', [appPattern]),
  logExpr(appPattern, searchVar):: fmt(
    'kubernetes.pod_namespace:~$namespace and kubernetes.pod_labels.app.kubernetes.io/name:~"%s" and _msg:~%s',
    [appPattern, searchVar]
  ),

  baseDashboard(config, title, uid):: {
    title: title,
    uid: uid,
    schemaVersion: 39,
    version: 1,
    tags: ['mastodon'],
    timezone: 'browser',
    editable: true,
    refresh: '30s',
    links: [
      {
        title: 'Mastodon dashboards',
        type: 'dashboards',
        tags: ['mastodon'],
        asDropdown: true,
        includeVars: true,
      },
    ],
    time: {
      from: fmt('now-%s', [config.dashboard.defaultTimeRange]),
      to: 'now',
    },
    templating: {
      list: [namespaceVar(config)] + std.get(config, 'extraTemplating', []),
    },
    panels: [],
  },

  statPanel(config, id, title, expr, unit, x, y, w=4, h=5, description=null):: {
    id: id,
    type: 'stat',
    title: title,
    description: description,
    gridPos: { x: x, y: y, w: w, h: h },
    fieldConfig: {
      defaults: {
        unit: unit,
        decimals: 3,
        color: { mode: 'thresholds' },
        thresholds: {
          mode: 'absolute',
          steps: [
            { color: 'green', value: null },
          ],
        },
      },
      overrides: [],
    },
    options: {
      reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
      orientation: 'auto',
      colorMode: 'value',
      graphMode: 'area',
    },
    targets: [
      {
        expr: expr,
        legendFormat: '{{namespace}}',
        refId: 'A',
      },
    ],
  },

  timeseriesPanel(config, id, title, exprs, unit, x, y, w=12, h=8, description=null)::
    local targets =
      if std.length(exprs) == 0 then []
      else [
        exprs[i] {
          refId+: std.char(65 + i),
          legendFormat: std.get(exprs[i], 'legendFormat', '{{namespace}}'),
        }
        for i in std.range(0, std.length(exprs) - 1)
      ];
    {
      id: id,
      type: 'timeseries',
      title: title,
      description: description,
      gridPos: { x: x, y: y, w: w, h: h },
      fieldConfig: {
        defaults: {
          unit: unit,
          color: { mode: 'palette-classic' },
        },
        overrides: [],
      },
      options: {
        legend: { showLegend: true, displayMode: 'table' },
        tooltip: { mode: 'multi', sort: 'none' },
      },
      targets: targets,
    },
}
