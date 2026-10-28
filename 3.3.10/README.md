# 3.3.10 — Four signals, one run, end to end

The capstone of chapter 3.3. Two purpose-built sample apps sit in front of a full,
self-contained observability stack, so you can drive the **whole investigation funnel**
on your own cluster:

```
metric  →  trace  →  log  →  code
 (where)  (which hop) (what)  (why)
```

- **Python `gateway`** (FastAPI) takes a request and calls…
- **Go `worker`**, which does the CPU-hot work.

Both are OpenTelemetry-instrumented (traces + metrics + logs) **and** both are
Pyroscope-profiled — so the funnel reaches all the way to the hot line of code, in
two languages.

## What's running (all in namespace `monitoring`)

| Component | Role |
|---|---|
| **OTel Collector** | the hub for THREE signals — apps send OTLP, it fans out to Jaeger / Prometheus / Loki |
| **Prometheus** | metrics, with `exemplar-storage` on (the metric→trace join) |
| **Jaeger** | traces (OTLP in) |
| **Loki** | logs (native OTLP); `trace_id` and the caller `file:line` arrive as labels |
| **Pyroscope** | profiles — CPU/alloc flame graphs, pushed by the app SDKs directly |
| **Grafana** | the single pane; all four datasources wired to pivot into each other |
| gateway · worker · loadgen | the two apps + a steady trickle of checkouts |

> **Profiles don't go through the Collector.** Three signals flow app → OTLP → Collector;
> profiles flow app → Pyroscope SDK → Pyroscope. (The OTel *profiling* signal is still
> experimental, so this is the honest "all with OTEL" today.)

## Prerequisites

The shared kind cluster from `student-practice/cluster` (this lab adds no cluster of its
own) and Docker on the box. The Pyroscope **UI** on host port 4040 needs the
`30040→4040` mapping in `kind-config.yaml` — if your cluster predates it, recreate kind.
You don't need it for the demo: Grafana reaches Pyroscope in-cluster.

## Run it

```bash
make up        # build both images, load into kind, deploy the whole stack
make verify    # PASS/FAIL — all four signals present + every pivot wired
make fault     # inject the incident: worker CPU burn ↑ and ~30% of checkouts fail
make heal      # back to the healthy baseline
make ui        # print the URLs
make destroy
```

## The demo — drive the funnel

1. `make fault`. Within a minute the worker's **p99 jumps** (~250 ms) and errors climb to ~30%.
2. **Grafana → the latency panel** (metric: *where*). Click an **exemplar** dot on the histogram.
3. You land in the **trace** (which hop): the `gateway → worker` waterfall, the `process` span red and slow.
4. From that span, **Logs for this span** → the **Loki** lines (what): `debit failed`, carrying the
   same `trace_id` **and** `code_file_path` / `code_line_number` — the **log→code** caller field.
5. From the same span, **Profiles for this span** → the **Pyroscope flame graph** (why / **code**):
   `main.process → main.computeScore → crypto/sha256.Sum256` dominating CPU. That's the hot line.
6. `make heal`.

Steps 2→4 are the three-pillar funnel from earlier in 3.3; step 5 is the fourth pillar
this lab adds.

## The pivots (how Grafana links them)

- **metric → trace** — Prometheus datasource `exemplarTraceIdDestinations` → Jaeger.
- **trace → logs** — Jaeger datasource `tracesToLogsV2` → Loki.
- **log → trace** — Loki datasource `derivedFields` on the `trace_id` label → Jaeger.
- **trace → code** — Jaeger datasource `tracesToProfiles` → Pyroscope (the span carries a
  `pyroscope.profile.id` tag). *Note:* on Tempo this is turnkey; it also works on **Jaeger**,
  which is what this lab (and the course) uses.

---
_Verified 2026-10-28 on kind (namespace `monitoring`): `make up → verify` green, 9/9 —
four signals from both services, gateway→worker traces joined, and all four pivots wired.
Under `make fault`: worker p99 ≈ 247 ms, ~17–30% errors, error logs with trace_id + caller
line, and the flame graph hot on `computeScore → sha256`._

Pinned images (what validated): collector `0.133.0`, prometheus `v3.1.0`, loki `3.3.2`,
jaeger `1.64.0`, pyroscope `1.13.4`, grafana `11.4.0`; Go builder `golang:1.26`.
