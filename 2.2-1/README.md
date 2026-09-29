# 2.2-1 — Loki with a SIDECAR shipper

The same Loki + pipeline as [2.2](../2.2), delivered the **sidecar** way instead
of a node **DaemonSet**. The app writes its logs to a file on a volume it
**shares with a Promtail container in the same pod**; that sidecar tails the file
and pushes to Loki. Deploy it to see the pattern the DaemonSet lab is the
alternative to.

> Fully isolated in namespace **`sidecar-demo`** with its own Loki release — it
> does **not** touch the 2.2 lab (`monitoring` / `demo`). Run both side by side.

## DaemonSet (2.2) vs sidecar (here)

| | 2.2 — DaemonSet | 2.2-1 — sidecar |
|---|---|---|
| Shipper count | one agent **per node** | one shipper **per pod** |
| Sees | every pod's logs on the node (`/var/log/pods`, hostPath) | **only this pod's** logs (shared `emptyDir`) |
| Discovery | `kubernetes_sd` + relabel to pick namespaces | none — a fixed `__path__`, nothing to discover |
| App change | none | add a container + shared volume to the pod |
| Node access | needs host log path | none — good for locked-down / multi-tenant nodes |
| Cost | efficient (N nodes) | heavier (one per pod), but isolated per app |

**When a sidecar wins:** you can't read node logs (restricted/managed nodes), the
app logs only to a file (not stdout), or a team needs its own shipper pipeline
independent of the cluster agent.

## How it works

```
┌─────────────── Pod: sidecar-app ───────────────┐
│  app container ──writes──▶ /var/log/app/app.log │   (emptyDir, shared)
│  promtail sidecar ──tails─▶ same file ──push──▶ Loki
└─────────────────────────────────────────────────┘
```

The sidecar's config uses `static_configs` with a fixed `__path__`
(`/var/log/app/*.log`) — no Kubernetes discovery, no relabeling — then runs the
identical four pipeline stages as 2.2: **parse** (json) → **drop** (healthchecks)
→ **scrub** (password/PAN) → **timestamp** → **promote** (`level`, `service`).

## Run it

```bash
make setup     # Loki (own namespace) + the app-with-sidecar
make verify    # LogQL drills + the two absence assertions
make logql     # port-forward Loki for hand LogQL / a Grafana datasource
make destroy   # tear it down
```

`make verify` asserts the sidecar shipped `sidecar-app` lines, that `healthz`
lines were **dropped**, and that the planted `Sup3rSecret` password never reached
the store (only the `REDACTED` marker remains).

## Files

- [`app-with-sidecar.yaml`](app-with-sidecar.yaml) — namespace, the sidecar
  Promtail `ConfigMap`, and the Deployment (app + promtail sharing an `emptyDir`)
- [`loki-values.yaml`](loki-values.yaml) — single-binary Loki (same as 2.2)
- [`verify.sh`](verify.sh) — the LogQL cross-check
