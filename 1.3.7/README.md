# 1.3.7 — remote_write to long-term storage (Mimir)

Spins up a single EC2 box running **Grafana Mimir** in single-process mode, then
hands you a Prometheus values file that `remote_write`s into it. This is the
"give Prometheus a bigger, longer memory" half of `remote_write`. Mimir is
Cortex's successor (forked from it in 2022) and the market default today.

```
  Prometheus (kind)  ──remote_write──►  Mimir (EC2 :9009)
   scrape + forward                      durable blocks on disk
                                         └─ query with the Prometheus API
```

| Box | Name tag | What it runs |
|-----|----------|--------------|
| 1 | `mimir` | Mimir single binary (`-target=all`) — push on `/api/v1/push`, query on `/prometheus/api/v1/...` |

## Prereqs

- Terraform >= 1.5, AWS credentials for the target account.
- The AMI has password SSH enabled — `remote-exec` connects as
  `ec2-user` / `DevOps321`, so no key pair is needed.
- The **default security group must allow inbound 22** (provisioning) and
  **9009** from wherever your Prometheus runs (so it can push).

## Run

```bash
make setup      # init + apply (or just `make`)
make output     # mimir IP, remote_write URL, query URL
```

State is local — nothing remote.

## Point Prometheus at it

`terraform apply` writes **`prometheus-values-mimir.rendered.yaml`** with the
live mimir IP already filled in. Use it in a kind cluster:

```bash
helm upgrade -i prometheus prometheus-community/prometheus -n monitoring --create-namespace \
    -f prometheus-values-mimir.rendered.yaml
```

(The committed `prometheus-values-mimir.yaml` is the same thing with a
placeholder IP, for reference.)

## Verify the demo

Mimir speaks the Prometheus query API. It's multi-tenant, so you **must** send
the tenant header — without `X-Scope-OrgID` you land in an empty tenant and see
nothing:

```bash
curl -s -H "X-Scope-OrgID: demo" \
  "http://$(terraform output -raw mimir_public_ip):9009/prometheus/api/v1/query?query=up" | jq .
```

Once your kind Prometheus is pushing, you'll see its series in Mimir —
tagged `prom_server="kind-prom"` — even though Mimir scraped nothing itself.

## Tear down

```bash
make destroy
```

## Production shape

The single binary above is the lab. `prod/` holds a microservices Mimir
(`docker-compose`) — distributor, ingesters ×3 with RF3, querier,
query-frontend, store-gateway, compactor, all reading/writing a shared object
store — which is how you'd actually run it. See `prod/README.md`.

> Note: this Mimir code has not been redeploy-verified on a fresh box. The
> config pins the two things that bit us on Cortex (`instance_addr: 127.0.0.1`
> and an absolute `activity_tracker.filepath`), so it should come up clean, but
> treat a first `make setup` as the smoke test.
