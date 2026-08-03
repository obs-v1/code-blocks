// Dashboards as code with Grafonnet — generate the JSON instead of hand-writing it.
//
// Grafonnet is a Jsonnet library of typed helpers; you compose a dashboard from
// functions and render it to the same JSON model Grafana provisions. The win is
// reuse: one function can stamp out a RED row for every service in a loop.
//
//   jb install github.com/grafana/grafonnet/gen/grafonnet-latest@main
//   jsonnet -J vendor red.jsonnet > red-generated.json     # then provision the JSON
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local dashboard = g.dashboard;
local ts = g.panel.timeSeries;
local prometheus = g.query.prometheus;

// a reusable panel factory — this is the point of code-gen
local ratePanel(title, expr) =
  ts.new(title)
  + ts.queryOptions.withTargets([
    prometheus.new('prometheus', expr) + prometheus.withLegendFormat('{{service}}'),
  ])
  + ts.standardOptions.withUnit('reqps')
  + ts.gridPos.withH(8) + ts.gridPos.withW(12);

dashboard.new('RED (generated with Grafonnet)')
+ dashboard.withUid('obs-red-jsonnet')
+ dashboard.withTags(['obs-course', '1.5.6'])
+ dashboard.withRefresh('30s')
+ dashboard.withPanels([
  ratePanel('Rate by service', 'sum by (service) (rate(http_server_requests_seconds_count[5m]))')
  + ts.gridPos.withX(0),
  ratePanel('Error rate by service', 'sum by (service) (rate(http_server_requests_seconds_count{outcome!="SUCCESS"}[5m]))')
  + ts.gridPos.withX(12),
])
