# 1.5.4 — Annotations: marking events on graphs

An **annotation** is a vertical marker on a graph that says *what happened, when*.
It turns a mysterious bump into "oh — that's the 14:03 restart." The best ones are
**query-driven**, not hand-placed, so they appear automatically.

## The annotations in this dashboard
Both come from PromQL against the datasource:

```promql
# orange marker — a pod restarted (start time changed)
changes(process_start_time_seconds{namespace="bankobs"}[2m]) > 0

# red marker — a target went down
up{namespace="bankobs"} == 0
```

Grafana evaluates these across the visible range and draws a marker wherever the
expression is true, tagged with the `service` / `pod` labels. Overlay them on the
request-rate graph and every dip has a candidate cause sitting right under it.

## Provision & view
Loaded by **`../1.5.8`** (`make setup`). Open uid `obs-annotations`. To *see* a
marker appear, restart a service:
```bash
kubectl -n bankobs rollout restart deploy/<some-service>
```
Within a minute an orange "restart" marker lands on the graphs.

**Verified**: `process_start_time_seconds` is present (57 series) and `up` is live,
so both annotation queries evaluate against real fleet data.
