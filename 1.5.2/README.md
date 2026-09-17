# 1.5.2 — Panels: matching the visual to the question

Every panel type answers a *different kind of question*. Picking the wrong one is
the most common way a dashboard becomes hard to read. `panels.json` puts the main
types side by side, each labelled with the question it answers, all driven by the
live bankobs fleet.

Seven panels, **seven distinct types** — one per kind of question, no duplicates:

| Panel | Question it answers | Type |
|-------|--------------------|------|
| Fleet request rate | "how much traffic right now?" — one number | **stat** |
| Success ratio | "what fraction succeeds?" — a bounded 0–100% | **gauge** |
| Busiest services | "which services get the most, right now?" — a ranking | **bar gauge** |
| Request rate over time | "how is it trending?" — change over time | **time series** |
| Per-service snapshot | "exact numbers, many rows, sortable" | **table** |
| Latency distribution over time | "the WHOLE distribution, not just p95?" — buckets | **heatmap** |
| Target up / down over time | "which targets were up/down, and when?" — states | **state timeline** |

## The rule
- **A number now** → stat. **A bounded ratio** → gauge. **A ranking** → bar gauge.
- **Change over time** → time series. **Many exact rows** → table.
- **A full distribution** → heatmap (feed it histogram buckets).
- **Discrete up/down (or any state) over time** → state timeline.
- If you're reaching for a time series to show a single current value, stop — that's a stat.

## Provision & view
Stand up a Grafana with the datasource once (`cd ../1.5.1 && make`), then from this
folder import **only this dashboard**:
```bash
make apply GRAFANA_URL=http://<node-ip>:13000    # make verify / make delete too
```
Open Grafana → uid `obs-panels`. To load every 1.5 dashboard at once instead, use
the **`../1.5.8`** lab.

The panels render against `http_server_requests_seconds_count`, its
`_bucket` histogram (heatmap), and `up` (state timeline). The heatmap needs
Micrometer percentile-histogram buckets — the same `http_server_requests_seconds_bucket`
series the 1.5.3 / 1.5.5 / 1.5.7 dashboards already use.
