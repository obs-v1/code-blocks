# 1.5.2 — Panels: matching the visual to the question

Every panel type answers a *different kind of question*. Picking the wrong one is
the most common way a dashboard becomes hard to read. `panels.json` puts the main
types side by side, each labelled with the question it answers, all driven by the
live bankobs fleet.

| Panel | Question it answers | Type |
|-------|--------------------|------|
| Fleet request rate | "how much traffic right now?" — one number | **stat** |
| Targets up | "is the fleet healthy?" — a count with thresholds | **stat** (bg) |
| Success ratio | "what fraction succeeds?" — a bounded 0–100% | **gauge** |
| Busiest services | "which services get the most?" — a ranking | **bar gauge** |
| Request rate over time | "how is it trending?" — change over time | **time series** |
| Per-service snapshot | "exact numbers, many rows, sortable" | **table** |

## The rule
- **A number now** → stat. **A bounded ratio** → gauge. **A ranking** → bar gauge.
- **Change over time** → time series. **Many exact rows** → table.
- If you're reaching for a time series to show a single current value, stop — that's a stat.

## Provision & view
This dashboard is loaded by the capstone in **`../1.5.8`** (`make setup`), then open
Grafana → *Observability Course* → this dashboard (uid `obs-panels`).

**Verified** on the live fleet: all six panels render against
`http_server_requests_seconds_count` and `up`.
