# 1.3.13 — relabel demo: keep only the `payments` namespace

A one-job kind Prometheus for teaching `relabel_configs`. It discovers **every
pod in every namespace**, shows which namespace each came from, and then — with
one `keep` rule — throws away every target that isn't in the **`payments`**
namespace. The everyday "discovery finds all, relabeling decides who stays."

## Prereqs

- A **kind** cluster with host port `9090` mapped (the labs' standard kind
  config), and the `prometheus-community` Helm repo:
  ```bash
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update
  ```

## 0 · Deploy the sample workloads

So the filter has something real to act on — a `payments` namespace and an
`orders` namespace with labeled pods:

```bash
curl -L -O https://raw.githubusercontent.com/obs-v1/code-blocks/refs/heads/main/1.3.13/payments-demo.yaml
kubectl apply -f payments-demo.yaml
```

| Namespace | Pods |
|-----------|------|
| `payments` | `payment-api` ×2, `payment-worker` ×1 |
| `orders` | `order-api` ×1 |
| `kube-system` | coredns, kube-proxy, … (already there) |

## 1 · Apply the demo Prometheus

```bash
curl -L -O https://raw.githubusercontent.com/obs-v1/code-blocks/refs/heads/main/1.3.13/prometheus-values-relabel-demo.yaml
helm upgrade -i prometheus prometheus-community/prometheus -n monitoring \
  --create-namespace -f prometheus-values-relabel-demo.yaml
```

Open `http://localhost:9090` (kind maps host `:9090` → NodePort `30990`).

## 2 · Before — every namespace is scraped

**Status → Targets** (or **Status → Service Discovery**) lists pods from
**payments, orders, and kube-system**. The `namespace` label is filled in by a
`replace` rule, so students can see exactly what we're about to filter on. Run
`up{job="relabel-demo"}` and you'll see targets from all namespaces.

## 3 · The demo — drop everything that isn't payments

Edit `prometheus-values-relabel-demo.yaml` and **uncomment the keep rule** at
the bottom of the `relabel-demo` job:

```yaml
      - source_labels: [__meta_kubernetes_namespace]
        action: keep
        regex: payments
```

Re-apply and refresh **Status → Targets**:

```bash
helm upgrade -i prometheus prometheus-community/prometheus -n monitoring \
  --create-namespace -f prometheus-values-relabel-demo.yaml
```

**Everything outside `payments` disappears** — orders and kube-system are gone;
only `payment-api` and `payment-worker` remain. That's the teaching point:

> `keep` keeps what matches and drops the rest — so **"keep `payments`" is
> exactly "drop every scrape that isn't in the payments namespace."** `keep` is
> the idiom for "only these": Prometheus' regex engine (RE2) has no negative
> match, so you express "drop everything that isn't X" as `keep` on X, not as a
> `drop`.

## Teardown

```bash
helm uninstall prometheus -n monitoring
kubectl delete -f payments-demo.yaml
```

## Notes

- With no `keep` rule, Prometheus tries to scrape every discovered pod, so many
  targets show **DOWN** (nginx exposes no `/metrics`). That's fine — this demo
  is about *which targets exist*, not their metric values; the Targets and
  Service Discovery pages show discovered targets regardless of scrape success.
- Verified with `helm template`: the values file renders a single `relabel-demo`
  job, and the chart still grants the `pods: [get,list,watch]` RBAC that
  `kubernetes_sd` needs even with all built-in jobs disabled.
