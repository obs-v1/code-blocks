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

## Tear down

```bash
make destroy
```
