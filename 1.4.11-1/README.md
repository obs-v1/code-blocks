# 1.4.11-1 — Rules the Operator way: PrometheusRule CRDs

Same rules as 1.4.10 / 1.4.11, but delivered as **`PrometheusRule` custom
resources** instead of a chart's `serverFiles`. This is how you manage rules when
you run the **Prometheus Operator** (kube-prometheus-stack): you `kubectl apply` a
CRD, the Operator discovers it by a **label**, and writes it into Prometheus for
you — no ConfigMap edit, no manual reload.

| serverFiles way (1.4.10 / 1.4.11) | Operator way (here) |
|---|---|
| Rules live in Helm `values.yaml` | Rules are `PrometheusRule` objects you `kubectl apply` |
| Reload after a ConfigMap sync (can lag) | Operator reconciles them in seconds |
| One chart owns the rules | Any team can ship rules to their namespace |

## How discovery works

The Prometheus CR has a `ruleSelector`. kube-prometheus-stack's default selects
`PrometheusRule` objects labelled **`release: <helm-release-name>`**. So every
rule file here carries:

```yaml
metadata:
  labels:
    release: kube-prometheus-stack   # <-- matched by the Prometheus ruleSelector
```

Change the release name → change this label to match.

## Install

```bash
make setup
```

That installs the Operator + Prometheus (exposed on NodePort 30990 via
[`values.yaml`](values.yaml)) and applies both rule files. Iterating on the
rules later:

```bash
make apply     # kubectl apply the local recording-rules.yaml + alerting-rules.yaml
```

## See it work

```bash
make crds      # the PrometheusRule objects the Operator sees
make rules     # the rules Prometheus actually loaded
make alerts    # alert states (PaymentsMetricsMissing: pending -> firing)
```

In the UI (`http://<node>:30990`): **Status → Rules** lists the groups and
**Alerts** shows the lifecycle. A recorded series like
`job:prometheus_http_requests:rate5m` returns pre-computed data; the `absent()`
alert `PaymentsMetricsMissing` fires because `job=payments` isn't scraped here.

## Files

- [`recording-rules.yaml`](recording-rules.yaml) — `PrometheusRule/custom-recording-rules`
  (`level:metric:operation` naming; see 1.4.10 for the theory)
- [`alerting-rules.yaml`](alerting-rules.yaml) — `PrometheusRule/custom-alerting-rules`
  (`expr` + `for` + `labels` + `annotations`; `absent()` no-data; see 1.4.11)
- [`values.yaml`](values.yaml) — exposes Prometheus and keeps the default
  release-label `ruleSelector`

> **Not loading?** The label must match the `ruleSelector`
> (`kubectl -n monitoring get prometheus -o yaml | grep -A5 ruleSelector`), and
> the `PrometheusRule` must be in a namespace the Operator watches (default: all).
> A malformed `expr` makes the Operator reject the whole object — check
> `kubectl -n monitoring describe prometheusrule custom-alerting-rules`.
