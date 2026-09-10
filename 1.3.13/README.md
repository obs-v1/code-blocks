# 1.3.13 — relabel_configs demo (see every label before you shape it)

A one-job Prometheus for teaching relabeling. It discovers **every pod** in a
kind cluster and shows the full set of labels service discovery attaches, so
`relabel_configs` (1.3.13) and `keep`/`drop`/`replace`/`labelmap` (1.3.14) have
real labels to act on.

## Prereqs

- A **kind** cluster with host port `9090` mapped (the labs' standard kind
  config), and the `prometheus-community` Helm repo added:
  ```bash
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update
  ```

## Apply

```bash
curl -L -O https://raw.githubusercontent.com/obs-v1/code-blocks/refs/heads/main/1.3.13/prometheus-values-relabel-demo.yaml

helm upgrade -i prometheus prometheus-community/prometheus -n monitoring \
  --create-namespace -f prometheus-values-relabel-demo.yaml
```

Open the UI at `http://localhost:9090` (kind maps host `:9090` → NodePort
`30990`).

## Where the labels live

- **Status → Service Discovery** — the star of the demo. For every target it
  shows **Discovered labels** (the full `__meta_kubernetes_*` firehose) beside
  **Target labels** (what survives relabeling). No trick needed — this screen
  *is* the lesson.
- **Graph** — run `up{job="relabel-demo"}`. Because the shipped `labelmap` rule
  promotes every pod label onto the metric, each series carries every pod
  label. `up` is emitted for every target (1 or 0), so labels show even for
  pods that expose no `/metrics` — which is exactly what you want for a label
  demo.

## The teaching arc

The file ships with **Step 1 only** (the `labelmap` firehose). Uncomment the
later steps in `prometheus-values-relabel-demo.yaml` **one at a time**, re-run
the `helm upgrade` above, and refresh Status → Targets / Service Discovery:

| Step | Action | What the class sees |
|------|--------|---------------------|
| 1 | `labelmap` | Every pod label appears on `up` — discovery knows a *lot*. |
| 2 | `replace` | Tidy `namespace` / `pod` / `node` labels derived from `__meta_*`. |
| 3 | `keep` | Most targets vanish — only pods with `prometheus.io/scrape: "true"` stay. |
| 4 | `drop` | Non-Running pods (Pending/Succeeded/Failed) fall away. |

The punchline for 1.3.15: uncommenting Step 3 reproduces exactly what the
chart's built-in `kubernetes-pods` job does — annotation-based opt-in scraping.

## Notes

- With no `keep` rule, Prometheus tries to scrape every discovered pod, so many
  targets show **DOWN** (they expose no `/metrics`). That's expected and
  harmless in a small kind cluster — the labels are the point, not the scrape.
- Teardown: `helm uninstall prometheus -n monitoring`.
