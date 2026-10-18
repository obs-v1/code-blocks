# 2.4.4 — Logs → Loki

This is the lab that most justifies the **DaemonSet** shape. The apps don't ship logs at all — they
just `print()` JSON to stdout, like any normal container. Kubernetes writes that to a file on the
node (`/var/log/pods/...`). The Collector, running as a node-agent, **tails those files** with its
`filelog` receiver, attaches k8s metadata, and sends the lines to **Loki** over OTLP. No logging SDK,
no app change — the node-agent reads what's already on disk.

```
  service-a  stdout ─┐  (node file)   ┌──────────────┐   OTLP   ┌──────┐
                     ├─ /var/log/pods ┤  Collector   │─────────▶│ Loki │
  service-b  stdout ─┘   (tailed)     │ (DaemonSet)  │  /otlp   └──────┘
                                      └──────────────┘
```

Each app line already carries its `trace_id` (the app stamps the active span's id into the JSON) —
which is what makes **logs ↔ traces correlation** possible later (2.4.6).

**Two gotchas baked into the config:**
- `filelog.include` is scoped to `otel24_service-*` pods only. Tailing *everything* would also tail
  Loki's own logs and create a shipping feedback loop.
- Loki here is **3.x**, which ingests OTLP natively at `/otlp` (older Loki needs a push API). It
  promotes resource attributes like `k8s.namespace.name`/`k8s.container.name` to stream labels.

## What's here

| File | Purpose |
|---|---|
| `app.py` + `Dockerfile` | the shared app; here it only writes stdout (all OTLP exporters `none`) |
| `services.yaml` | the two services + a driver (just generating log lines) |
| `collector.yaml` | Collector **DaemonSet** with a `filelog` receiver + a `/var/log/pods` hostPath mount → `otlphttp` to Loki |
| `loki.yaml` | a minimal single-binary **Loki 3.x** (filesystem storage, OTLP ingest) |
| `Makefile` / `verify.sh` | `make` · `verify` · `ui` · `destroy` |

## Run

```bash
make            # build + deploy Loki + Collector + services
make verify     # prove the app's stdout logs reached Loki (retries on cold start)
make ui         # Loki API — curl '.../loki/api/v1/query_range?query={k8s_container_name="app"}'
```

## Verify

`verify.sh` queries Loki for `{k8s_container_name="app"}` lines containing the app's
`"msg": "frontend calling backend"` — proof the lines came from the app (not from Loki's own logs)
and arrived via the Collector's filelog receiver.

## Tear down

```bash
make destroy
```

**Verified 2026-10-19 on kind:** after scoping filelog to the app pods, Loki returned **14 app lines**,
each the real JSON with a `trace_id` (e.g. `{"service":"service-a","msg":"frontend calling
backend","trace_id":"3155a56..."}`) → PASS.
