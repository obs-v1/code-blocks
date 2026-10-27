# 3.2.4 — Install Alertmanager, and wire Prometheus to it

Prometheus decides *when* an alert fires; **Alertmanager decides what happens next** (group, route,
inhibit, silence, deduplicate — the five jobs). They are two separate processes, and this lab stands
both up and connects them, so you have a working alerting pipeline to build routing and inhibition on
in 3.2.5–3.2.10.

## What you'll see
- **Prometheus** (`:9090`) → *Status ▸ Runtime & Build Information* lists the discovered Alertmanager — that's the wiring.
- A demo alert (`DemoAlwaysFiring`) goes **pending → firing** on the Alerts tab.
- **Alertmanager** (`:9093`) shows that same alert — proof it travelled Prometheus → Alertmanager.

## The one block that connects them
Inside `prometheus.yml` (in `prometheus.yaml`):
```yaml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ["alertmanager.monitoring.svc:9093"]
```
That's it — Prometheus pushes every firing alert to each Alertmanager listed here. The rest of the
alerting behaviour lives in `alertmanager.yml` (in `alertmanager.yaml`): a `route` and a `receiver`.

## Prerequisites
A kind cluster that publishes host ports **9090** (Prometheus) and **9093** (Alertmanager). This repo's
`student-practice/cluster/kind-config.yaml` maps both (`30909→9090`, `30993→9093`). Bring the cluster
up with that config first. _If your cluster predates the 9093 mapping, add it to the kind config and
recreate the cluster._

## Run it
```bash
make setup     # Prometheus + Alertmanager, already wired together
make ui        # the two URLs
make verify    # PASS/FAIL: Prometheus knows AM, the demo alert fires and reaches AM
make destroy
```

## What's running
| File | Role |
|---|---|
| `prometheus.yaml` | Prometheus (ConfigMap `prometheus.yml` + `rules.yml`, Deployment, NodePort :9090). Scrapes itself, evaluates one demo rule, and is wired to Alertmanager. |
| `alertmanager.yaml` | Alertmanager (ConfigMap `alertmanager.yml` with a route + a null receiver, Deployment, NodePort :9093). |

The receiver is intentionally a **null receiver** (notifies nowhere) — alerts still appear in the
Alertmanager UI, so you can prove the pipeline without wiring Slack/PagerDuty. You add real routing,
inhibition, silences and a mock receiver in **3.2.10**.

---
_Verified 2026-10-26 on kind (namespace `monitoring`): `make setup → verify` green — Prometheus discovers the Alertmanager, DemoAlwaysFiring flows Prometheus → Alertmanager and shows in its UI (:9093)._
