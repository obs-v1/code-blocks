# 2.2.13 — replication (replication_factor)

`replication_factor: 3` keeps **three copies** of every chunk across three
ingesters. Lose one ingester and you lose **nothing** — the other two still have
the data. This needs multiple ingesters, so it runs **SimpleScalable** with 3
`write` replicas (the write role *is* the ingesters) + bundled MinIO.

## Run

```bash
make            # deploy (3 ingesters, RF=3) + prove no data loss
make clean      # uninstall + delete the namespace
```

`make` deploys, then `verify.sh` pushes 10 lines, **kills one ingester pod**, and
re-queries:

```
  lines before failure:    10   (should be 10)
  killing one ingester:    loki-write-1
  lines after failure:     10   (should still be 10 — REPLICATED)
PASS — RF=3 kept every line after an ingester was killed. No loss.
```

## The point

- The just-pushed lines are still in **ingester memory** (not yet flushed to
  MinIO). With **RF=3** they sit in *three* ingesters at once, so killing one
  leaves two intact copies — the query still returns all 10.
- With **`replication_factor: 1`** (the lab default elsewhere), those lines would
  live in a *single* ingester; killing it before the flush would lose them. That
  contrast is the whole reason production runs RF=3.
- `write.replicas` must be **≥ `replication_factor`** — you can't keep 3 copies
  with fewer than 3 ingesters, and the chart won't come healthy if you try.

> Durability here comes from **replication**, not object storage — the point is
> that data survives an ingester loss *before* it's ever written to MinIO.
