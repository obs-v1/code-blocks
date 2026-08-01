# 1.3.6 — remote_write demo

Spins up three `t3.small` **spot** instances in the default VPC (us-east-1) to
show Prometheus `remote_write` in action: one Prometheus collects locally and
pushes its samples to a second, central Prometheus.

```
  node-exporter (:9100)
        ▲ scrape
        │
  prom-server-A  ──remote_write──►  prom-server-B
   (forwarder)                       (receiver)
```

| Box | Name tag | What it runs |
|-----|----------|--------------|
| 1 | `node-exporter` | node_exporter on :9100 |
| 2 | `prom-server-A` | Prometheus — scrapes node-exporter, `remote_write` → B |
| 3 | `prom-server-B` | Prometheus — started with `--web.enable-remote-write-receiver` |

## Prereqs

- Terraform >= 1.5, AWS credentials for the target account (`aws configure` / env vars).
- The AMI (`ami-0220d79f3f480ecf5`) has password SSH enabled — `remote-exec`
  connects as `ec2-user` / `DevOps321`, so no key pair is needed.
- The **default security group must allow inbound 22** (for provisioning) and
  ideally 9090/9100 from your IP if you want to browse the UIs.

## Run

```bash
make setup      # init + apply (or just `make`)
```

State is local (`terraform.tfstate`) — nothing remote.

Other targets: `make output` (IPs / UI URLs), `make plan`, `make fmt`.

## Verify the demo

1. Open **prom-server-B** UI (see `terraform output`) → `Status → Targets`
   shows only B itself.
2. In B, run `node_cpu_seconds_total` — you'll see the **node-exporter** series
   even though B never scraped it. It arrived via A's `remote_write`.
3. Check the `prom_server="server-a"` external label on those series to confirm
   they came from A.

## Helm / kind alternative

Same demo without EC2 — two Prometheus releases in a kind cluster. Bring up **B**
(the receiver) first, then **A** (the forwarder), so B is listening before A pushes:

```bash
# B - the receiver (turns on --web.enable-remote-write-receiver)
helm upgrade -i prom-b prometheus-community/prometheus -n monitoring --create-namespace \
    -f https://raw.githubusercontent.com/obs-v1/code-blocks/refs/heads/main/1.3.6/prometheus-values-server-b.yaml

# A - the forwarder (remote_writes to http://prom-b-server/api/v1/write)
helm upgrade -i prom-a prometheus-community/prometheus -n monitoring \
    -f https://raw.githubusercontent.com/obs-v1/code-blocks/refs/heads/main/1.3.6/prometheus-values-server-a.yaml
```

Then port-forward `prom-b-server` and query `prometheus_build_info` — you'll see A's
series (`prom_server="server-a"`) even though B never scraped them.

## Tear down

```bash
make destroy
```
