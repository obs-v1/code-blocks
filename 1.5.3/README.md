# 1.5.3 — Variables: one dashboard, many contexts

A **template variable** turns one dashboard into hundreds. Instead of building a
dashboard per service, you build *one* with a `$service` dropdown and every panel
re-scopes to the selection.

## The variable
```
name:  service
type:  query
query: label_values(http_server_requests_seconds_count, service)   # 35 services
multi: true      includeAll: true      allValue: .*
```
Grafana runs that PromQL `label_values(...)` to populate the dropdown, so the list
stays in sync with what's actually running — add a service, it appears.

## How panels use it
Every query filters with `{service=~"$service"}`:
```promql
sum(rate(http_server_requests_seconds_count{service=~"$service"}[5m]))
histogram_quantile(0.95, sum by (le) (rate(http_server_requests_seconds_bucket{service=~"$service"}[5m])))
```
Because it's a regex match (`=~`) with `allValue: .*`, picking **All** shows the
whole fleet; picking one or many services narrows instantly — same panels, no edits.

## Provision & view
Loaded by **`../1.5.8`** (`make setup`). Open uid `obs-variables`, then change the
**Service** dropdown at the top and watch every panel follow.

**Verified**: the variable resolves to 35 services on the live fleet; panels re-scope correctly.
