# 1.4.11 — Alerting rules: expr, for, labels, annotations

An alerting rule is where PromQL stops informing and starts **paging a human**.
It's four fields, but each one encodes a lesson: get them right and your pages
mean something; get them wrong and you train the team to ignore the pager.

## The lifecycle

On every evaluation the `expr` is checked. While it's false → **Inactive**. The
moment it turns true → **Pending**, and the `for` timer starts. Only if it stays
true for the whole `for` → **Firing**, handed to Alertmanager, which routes it by
its `labels`.

## Install

Installs the full `prometheus-community/prometheus` chart with the alerting rules
in [`values.yaml`](values.yaml):

```bash
make setup
```

or directly:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade -i prometheus prometheus-community/prometheus -n monitoring \
  -f https://raw.githubusercontent.com/obs-v1/code-blocks/refs/heads/main/1.4.11/values.yaml \
  --create-namespace
```

## The four fields

```yaml
- alert: HighErrorRate
  expr: |                     # 1. the condition (built from the PromQL cookbook)
    sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
    / sum(rate(http_requests_total[5m])) by (service) > 0.01
  for: 10m                     # 2. must hold 10m before firing — defeats flapping
  labels:                      # 3. severity + routing keys Alertmanager reads
    severity: critical
  annotations:                 # 4. the human message + runbook, with live templating
    summary: "{{ $labels.service }} error rate is {{ $value | humanizePercentage }}"
    runbook: "https://runbooks.example.com/high-error-rate"
```

## See it fire

```bash
make rules     # the alerting rules Prometheus loaded (health "ok")
make alerts    # current alert states
```

> **If the rules don't show up:** after a `helm upgrade` the rules land in the
> `prometheus-server` ConfigMap immediately, but the projected file inside the
> pod can take a minute to sync before the reloader picks it up. Force it with
> `make reload` (`kubectl -n monitoring rollout restart deploy/prometheus-server`)
> or delete the pod.

In the UI (`http://<node>:30990` → **Alerts**) you'll watch
`PaymentsMetricsMissing` go **Inactive → Pending → Firing** — it uses `absent()`
(below), which is true because `job=payments` isn't scraped here.

## What makes an alert good

- **Alert on symptoms, not causes.** Page on the error ratio or latency users
  feel — not on CPU. High CPU with happy users is not an incident.
- **Always set a `for`.** A page for a 30-second blip burns trust fast.
- **Every alert needs a runbook.** A page with no next action is noise.
- **Let `severity` drive routing.** `critical` pages; `warning` goes to a channel.

## Alerting on no data — `absent()` / `absent_over_time()`

A metric that stops arriving fires nothing — the `expr` simply has no series left
to be true, so the outage is invisible. `absent(up{job="payments"})` returns `1`
exactly when that selector matches nothing — the standard way to page on a scrape
target that vanished. `absent_over_time(up{job="payments"}[10m])` is the range
form: true only when the series was missing for the whole window, so one skipped
scrape doesn't page you. Always pair it with a `for:` and a clear message.
