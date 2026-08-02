# 1.3.13 — the opt-in annotation pattern

A working demo of the pattern from the doc: workloads **declare themselves** with
`prometheus.io/scrape` annotations, and Prometheus discovers every pod but
**scrapes only the ones that opted in**. Nothing in Prometheus changes when a
team ships a new service — they just add the annotation.

```
  kubernetes_sd (role: pod)  ──discovers ALL pods──►  relabel_configs
                                                         │ keep prometheus.io/scrape="true"
                                                         │ scrape the declared port/path
                                                         ▼
                                              only opted-in pods are scraped
```

## What's here

| File | Purpose |
|------|---------|
| `prometheus-values.yaml` | Prometheus (helm) with the annotation scrape job — the `relabel_configs` are the lesson |
| `demo-app.yaml` | two apps: `example-annotated` (opts in) and `example-plain` (no annotation) |
| `verify.sh` | cross-check: annotated pod is scraped, plain pod is dropped |
| `Makefile` | `make` / `make verify` / `make destroy` |

## Prereqs

- A Kubernetes cluster with `kubectl` + `helm` (this was validated on single-node
  `kind`). Prometheus is exposed as a NodePort on `30990`; on kind that maps to
  host `:9090` if the cluster was created with the matching `extraPortMappings`.

## Run

```bash
make setup      # helm-install Prometheus + deploy the two demo apps
```

The scrape job that does the work (in `prometheus-values.yaml`):

```yaml
- job_name: kubernetes-pods
  kubernetes_sd_configs:
    - role: pod
  relabel_configs:
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
      action: keep            # keep ONLY pods that opted in
      regex: "true"
    - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]
      action: replace         # scrape the port the pod declared
      target_label: __address__
      ...
```

## Verify

```bash
make verify PROM_URL=http://<node-ip>:9090     # or http://localhost:9090
```

Expected:

```
== active targets from the demo namespace ==
  example-annotated-xxxx   up   http://10.244.0.x:8080/metrics
== example-plain among DROPPED targets ==
  dropped example-plain endpoints: 1
== up{namespace="demo"} ==
  example-annotated-xxxx = 1
annotated targets scraped: 1   |   plain targets scraped: 0
PASS — only the opted-in pod is scraped.
```

So `example-plain` **is** discovered by service discovery — it shows up under
*dropped* targets — but the `keep` rule removes it before any scrape happens.
Add the annotation and it would start being scraped on the next SD refresh,
with nothing to change in Prometheus.

You can see the annotated app's own metrics flow through, too — generate a little
traffic and read the counter back:

```bash
# hit the app a few times, then:
curl -s "http://<node-ip>:9090/api/v1/query" \
     --data-urlencode 'query=http_requests_total{namespace="demo"}'
```

> Note: on a cluster that already runs annotated workloads (e.g. the
> `bankobserve360` lab), this same job will auto-discover **all** of them — which
> is the pattern working as intended: zero per-service config. `verify.sh` scopes
> its checks to the `demo` namespace so the assertion stays clean.

## Tear down

```bash
make destroy
```

---

**Verified 2026-08-02** on single-node kind (k8s v1.36): `example-annotated`
scraped (`up=1`, `http_requests_total=20` after traffic), `example-plain`
discovered-but-dropped (0 scrapes) — confirmed via the NodePort at `:9090`.
