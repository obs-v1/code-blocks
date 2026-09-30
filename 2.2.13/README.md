# 2.2.13 — Replication, multi-tenancy, and the gateway

Two runnable demos, one per idea from section 2.2.13. In each, **`make`** deploys
Loki *and* proves the behavior, and **`make clean`** uninstalls.

| Folder | Shows | How it's proven |
|--------|-------|-----------------|
| [`multi-tenancy/`](multi-tenancy/) | `auth_enabled` + `X-Scope-OrgID` isolate tenants | push as team-a & team-b → each sees only its own; untenanted query → 401 |
| [`replication/`](replication/) | `replication_factor: 3` survives an ingester loss | push 10 lines, kill an ingester → still 10 (other replicas have them) |

```bash
cd multi-tenancy   # or replication
make               # deploy + run the proof
make clean         # tear down
```

The third idea — the **gateway** — isn't a separate demo: both labs already talk
to the single `loki-gateway` URL for push *and* query (the multi-tenancy one just
adds the tenant header). That "one door in front of Loki" is the gateway's job.

Needs `kubectl`, `helm`, `jq`, `curl`, and a cluster. Each demo uses its own
namespace (`loki-tenancy` / `loki-replication`), so they don't collide.
