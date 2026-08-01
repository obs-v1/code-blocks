# 1.3.7 — remote_write to long-term storage (Cortex)

Spins up a single EC2 box running **Cortex** in single-process mode, then hands
you a Prometheus values file that `remote_write`s into it. This is the
"give Prometheus a bigger, longer memory" half of `remote_write`.

```
  Prometheus (kind)  ──remote_write──►  Cortex (EC2 :9009)
   scrape + forward                      durable blocks on disk
                                         └─ query with the Prometheus API
```

| Box | Name tag | What it runs |
|-----|----------|--------------|
| 1 | `cortex` | Cortex single binary — push on `/api/v1/push`, query on `/prometheus/api/v1/...` |

## Prereqs

- Terraform >= 1.5, AWS credentials for the target account.
- The AMI has password SSH enabled — `remote-exec` connects as
  `ec2-user` / `DevOps321`, so no key pair is needed.
- The **default security group must allow inbound 22** (provisioning) and
  **9009** from wherever your Prometheus runs (so it can push).

## Run

```bash
make setup      # init + apply (or just `make`)
make output     # cortex IP, remote_write URL, query URL
```

State is local — nothing remote.

## Point Prometheus at it

`terraform apply` writes **`prometheus-values-cortex.rendered.yaml`** with the
live cortex IP already filled in. Use it in a kind cluster:

```bash
helm upgrade -i prometheus prometheus-community/prometheus -n monitoring --create-namespace \
    -f https://raw.githubusercontent.com/obs-v1/code-blocks/refs/heads/main/1.3.7/prometheus-values-cortex.yaml
```

(The committed `prometheus-values-cortex.yaml` is the same thing with a
placeholder IP, for reference.)

## Verify the demo

Cortex speaks the Prometheus query API, so query it directly:

```bash
curl -s "$(terraform output -raw cortex_public_ip):9009/prometheus/api/v1/query?query=up" | jq .
```

Once your kind Prometheus is pushing, you'll see its series in Cortex —
tagged `prom_server="kind-prom"` — even though Cortex scraped nothing itself.

## Tear down

```bash
make destroy
```
