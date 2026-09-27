# 1.5.7 — Dashboard design: the craft that decides 3 a.m. usability

The difference between a dashboard you *glance* at and one you *fight* is design,
not data. `red-overview.json` applies the craft to a real RED view of the fleet.

## What "good" looks like here
- **Top-down, most-important-first.** Row 1 is the three RED numbers as big,
  colour-coded stats (Rate · Errors · Duration) — the "is it healthy?" answer in
  one glance. Trends sit below, detail below that. You read it like a headline.
- **Colour means something.** Errors and latency stats go green → orange → red on
  thresholds, so "bad" is pre-attentive — you see it before you read it.
- **Consistent, correct units.** `reqps`, `percentunit`, `s` — never raw numbers.
- **One variable for scope.** A `$service` dropdown drills the whole board from
  fleet to a single service without a second dashboard.
- **Events in context.** Restart annotations overlay the graphs, so a dip explains
  itself.
- **Restraint.** Six panels, not sixty. Depth belongs in drill-downs, not the
  overview.

## The anti-patterns it avoids
Wall-of-graphs with no hierarchy · single values drawn as time series · rainbow
colours that signal nothing · mixed/raw units · a dashboard per service instead of
one with a variable.

## Provision & view
With a Grafana + datasource running (`cd ../1.5.1 && make`), import **only this
dashboard**:
```bash
make apply GRAFANA_URL=http://<node-ip>:13000
```
Open uid `obs-red` — the one you'd actually pin as the fleet's front door. (All 1.5
dashboards at once: the **`../1.5.8`** lab.)

**Verified**: Rate/Errors/Duration and the percentile panels render live; the
`$service` scope and restart annotations work against the fleet.
