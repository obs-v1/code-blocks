# 3.1.10 — An SLO with burn-rate alerts, fired for real (with Pyrra)

Everything in 3.1.5–3.1.9 becomes concrete here. You put a **99.9% availability SLO** on a live
service, let **[Pyrra](https://github.com/pyrra-dev/pyrra)** turn a 12-line spec into the recording
rules + multi-window burn-rate alerts (the 3.1.7 recipe), watch the **error budget** on Pyrra's UI,
then inject errors and watch the **fast-burn alert fire** — the page the SLO promised.

You never hand-write the burn-rate math. You write the *intent* (99.9%, over this window) and Pyrra
generates the rest — which is exactly the point 3.1.9 made about SLO tooling.

## What you'll see
- **Healthy:** Pyrra shows the SLO at ~100% budget, green. No alerts.
- **After `make fault`:** the **error budget burns down** in front of you, and within ~2–3 minutes the
  **fast-burn alert** goes `pending` → `firing` in Prometheus/Alertmanager.

## Prerequisites
A kind cluster that publishes the lab's host ports. This repo's
`student-practice/cluster/kind-config.yaml` already maps them:
`9099` (Pyrra), `9090` (Prometheus), `9093` (Alertmanager), `3000` (Grafana). Bring the cluster up
with that config first.

## Run it
```bash
make setup     # kube-prometheus-stack + Pyrra + the demo app  (~3–4 min first time)
make slo       # apply the 12-line SLO → Pyrra generates the rules + burn-rate alerts
make ui        # prints the URLs

# open Pyrra (http://<box-ip>:9099): the SLO sits at ~100% budget, green.
make fault     # inject ~30% errors — the incident begins
#   → watch the budget fall in Pyrra; the fast-burn alert fires in ~2–3 min.
make verify    # PASS/FAIL: SLO present, rules generated, budget burning, alert firing
make fault-stop
make destroy
```

## What's actually running
| Piece | Role |
|---|---|
| **demo-app** (`app.py`) | serves `/work` (200, or 500 at a tunable rate), exposes `http_requests_total{code}`, and self-drives ~20 req/s so the SLI always has data |
| **kube-prometheus-stack** | Prometheus + **Operator** (consumes Pyrra's generated `PrometheusRule`) + Alertmanager + Grafana |
| **Pyrra** | `kubernetes` operator (SLO CRD → `PrometheusRule`) + `api` (the budget/burn-rate UI on :9099) |
| **slo.yaml** | the `ServiceLevelObjective`: 99.9% of non-5xx over the window. The whole input. |
| **grafana-dashboard.yaml** | the SAME SLO in Grafana (budget, burn rate, SLI, request mix) — auto-loaded by the sidecar |

## Two views of the same SLO
- **Pyrra** (`:9099`) — the purpose-built SLO tool: the spec, the generated rules, and a live budget, with no PromQL to write.
- **Grafana** (`:3000/d/slo-demo-app`) — the same SLO expressed as raw PromQL in a dashboard, so you see how to put an SLO into the dashboards you already build (Week 1.5). Budget-remaining stat, the multi-window burn rate with the 14.4× line, the live SLI, and the 2xx/5xx request mix.

Watch both during `make fault`: the budget falls in Pyrra, and the burn-rate line in Grafana crosses 14.4× right as the alert fires.

The SLI is just **non-5xx ÷ all requests**. The SLO targets 99.9% of it. Pyrra computes the budget
`(1 − 0.999) × window` and the burn rate `observed ÷ allowed`, and alerts when the burn is fast
enough to matter — the exact model from 3.1.5–3.1.7.

## Lab-scaled vs production windows
`slo.yaml` uses a **1h window** so a burn plays out in minutes. In production this would be ~28d; the
*shape* of the recording rules and the multi-window alerts is identical — only the clock changes.
That's the lesson of 3.1.7: fast window proves it's happening now, long window proves it's real.

## Clean up
```bash
make destroy
```

---
_Verified 2026-10-26 on kind (namespace `monitoring`): `setup → slo → fault → verify` all green — Pyrra
generates the rules, the critical fast-burn page fires in ~1–2 min under a 30–50% fault, the error budget
burns, and both the Pyrra UI (:9099) and the Grafana SLO dashboard (:3000) show it live._
