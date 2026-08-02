# 1.3.7 — Mimir in production on Kubernetes

Deploys **Grafana Mimir in its microservices (production) shape** onto a
Kubernetes cluster using the official `grafana/mimir-distributed` Helm chart.
This is the k8s counterpart to the single-binary VM lab one level up — same
long-term-storage story, real production topology.

```
 Prometheus ──remote_write──► mimir-gateway ──► distributor ──► (Kafka) ──► ingesters ×3 (RF3)
                                                                                    │
                                                                                    ▼
                                                                             object storage (MinIO)
                                                                                    ▲
 Grafana ──► mimir-gateway ──► query-frontend ──► querier ──► store-gateway ────────┘
```

## What runs

Chart `grafana/mimir-distributed` **6.1.0** (Mimir app **v3.1.2**). Every
component is its own workload:

| Group | Components |
|-------|-----------|
| Write | `distributor` ×2 → `kafka` → `ingester` ×3 (RF 3) |
| Read  | `gateway` (nginx) → `query-frontend` → `query-scheduler` → `querier` ×2 → `store-gateway` |
| Background | `compactor`, `rollout-operator` |
| Storage | `minio` (bundled S3, buckets `mimir-tsdb` / `mimir-ruler`) |
| Caches | memcached: `chunks-cache`, `index-cache`, `metadata-cache`, `results-cache` |

> **Note — Kafka ingest storage.** Mimir 3.x / chart 6.x default to the new
> *ingest-storage* write path: the distributor appends to Kafka and ingesters
> consume from it, which decouples write scaling from the ingesters. That's why
> a `mimir-kafka-0` pod appears. The gossip (memberlist) ring still ties the
> components together for discovery.

## Lab sizing

`mimir-values.yaml` keeps the real prod split but trims it to a **single-node
kind** cluster:

- **zone-aware replication off** for ingester + store-gateway — one node can't
  spread three zones; instead the ingester is a single StatefulSet with 3
  replicas, preserving the RF-3 story.
- replica counts on the stateless parts kept low (distributor/querier ×2, rest ×1).
- memcached cache memory shrunk to a few hundred MB each.
- `multitenancy_enabled: true` — every request needs an `X-Scope-OrgID` header.
- `ruler` / `alertmanager` / `overrides_exporter` disabled.

The chart's own defaults (pod anti-affinity, topology spread) are all
`ScheduleAnyway`, so everything lands on the one node.

## Deploy

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm upgrade -i mimir grafana/mimir-distributed \
    -n mimir --create-namespace \
    --version 6.1.0 \
    -f mimir-values.yaml
```

Wait for pods (first boot churns for ~1–2 min while the ring forms):

```bash
kubectl -n mimir get pods
```

## Endpoints (in-cluster)

The `mimir-gateway` service is the single entry point for both push and query:

```
push :  http://mimir-gateway.mimir.svc/api/v1/push
query:  http://mimir-gateway.mimir.svc/prometheus/api/v1/query
```

## Verify

Ring is healthy (expect **3 ACTIVE** ingesters):

```bash
kubectl -n mimir exec deploy/mimir-distributor -- \
  wget -qO- http://localhost:8080/ingester/ring | grep -o ACTIVE | wc -l
```

Full round-trip — point a throwaway Prometheus at the gateway and read the
series back (remember the tenant header):

```bash
# remote_write:
#   - url: http://mimir-gateway.mimir.svc/api/v1/push
#     headers: { X-Scope-OrgID: demo }

curl -s -H "X-Scope-OrgID: demo" \
  "http://mimir-gateway.mimir.svc/prometheus/api/v1/query?query=up"
```

Without `X-Scope-OrgID` you land in an empty tenant and see nothing — that's the
multi-tenancy lesson, same as the VM lab.

## Tear down

```bash
helm -n mimir uninstall mimir
kubectl delete ns mimir
```

---

**Verified 2026-08-02** on a single-node kind cluster (k8s v1.36, 16 CPU /
123 Gi): all 15 workloads Ready, ingester ring 3× ACTIVE, and an in-cluster
Prometheus round-tripped `up{prom_server="in-cluster-test"}` through the gateway
into Mimir and back out via the query API.
