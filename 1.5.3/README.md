# 1.5.3 — Variables: one dashboard, many contexts

A **template variable** turns one dashboard into hundreds. Instead of building a
dashboard per service, you build *one* with a `$service` dropdown and every panel
re-scopes to the selection.

## The variable
```
name:  service
type:  query
query: label_values(http_server_request_duration_seconds_count, service)   # every service that has served a request
multi: true      includeAll: true      allValue: .*
```
Grafana runs that PromQL `label_values(...)` to populate the dropdown, so the list
stays in sync with what's actually running — add a service, it appears.

One wrinkle worth knowing: a Prometheus client library publishes nothing for a
labelled metric family until its first observation, so a service that has served
no request is absent from the dropdown. It is idle, not uninstrumented — drive
traffic (the load runner does) and it shows up.

## How panels use it
Every query filters with `{service=~"$service"}`:
```promql
sum(rate(http_server_request_duration_seconds_count{service=~"$service"}[5m]))
histogram_quantile(0.95, sum by (le) (rate(http_server_request_duration_seconds_bucket{service=~"$service"}[5m])))
```
Because it's a regex match (`=~`) with `allValue: .*`, picking **All** shows the
whole fleet; picking one or many services narrows instantly — same panels, no edits.

## Provision & view
With a Grafana + datasource running (`cd ../1.5.1 && make`), import **only this
dashboard** from here:
```bash
make apply GRAFANA_URL=http://<node-ip>:13000
```
Open uid `obs-variables` and change the **Service** dropdown — every panel follows.
(All 1.5 dashboards at once: the **`../1.5.8`** lab.)

**Verified**: the variable resolves to 35 services on the live fleet; panels re-scope correctly.
