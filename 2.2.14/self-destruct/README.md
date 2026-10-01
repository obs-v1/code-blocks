# 2.2.14 self-destruct — overload Loki until it dies, then make it survive

The real thing: no artificial cap to bump into — instead, **turn every protective
limit off**, give the pod a **small memory ceiling**, and flood it with
high-cardinality traffic until the ingester **OOMs and crash-loops**. Then set the
limits and watch the *same* flood bounce off.

## Why not "just use defaults"?

Loki's real defaults already include limits (`max_global_streams_per_user` ~5000,
`ingestion_rate_mb` 4, `per_stream_rate_limit` 3MB) — so with defaults it
**rate-limits the flood instead of dying**. That's the point of limits. To see
Loki fail *itself*, you first have to remove those guards (that's
[`values-unprotected.yaml`](values-unprotected.yaml)).

## Run

```bash
make problem      # limits OFF + 350Mi ceiling -> the flood OOMs Loki
make solve        # limits ON  + same ceiling  -> the same flood is rejected, Loki lives
# or:
make              # both, back to back
make clean        # tear down
```

**Problem** prints something like:
```
rounds: accepted(204)=31   rejected(429)=0   failed(5xx/timeout)=49
=> Loki stopped answering under the flood (see the pod state next).
Loki pod state:
NAME     READY   STATUS             RESTARTS
loki-0   0/1     CrashLoopBackOff   3
  restarts=3  lastReason=OOMKilled
```

**Fix** prints:
```
rounds: accepted(204)=~2  rejected(429)=~78  failed=0
=> limits held: 78 rounds refused with 429, Loki never fell over.
Loki pod state:
loki-0   1/1   Running   0
  restarts=0  lastReason=
```

Same flood, same memory ceiling — the only difference is `limits_config`. Without
it, Loki eats itself; with it, the flood is refused and the pod stays under its
limit.

## Tuning (important — calibrate to your node)

Whether the OOM fires depends on the memory ceiling vs. how hard you flood:

| Knob | Where | Effect |
|------|-------|--------|
| `MEM` (350Mi) | `resources.limits.memory` in `values-unprotected.yaml` | lower ⇒ OOMs sooner; too low ⇒ OOMs on boot |
| `ROUNDS` (80) | `make ... ROUNDS=120` | more rounds ⇒ more streams ⇒ more memory |
| `STREAMS` (500) | `make ... STREAMS=800` | streams per round (cardinality) |

If **problem** ends with `accepted=all, failed=0`, Loki survived — raise `ROUNDS`
/`STREAMS` or lower the memory limit. If it OOMs on startup, raise the limit.
Start with the defaults and nudge from there.

> This is the dramatic version. For a demo that always lands cleanly (no node
> tuning), use the sibling [`../stream-cap/`](../stream-cap/) — it shows the 429
> cap without needing to actually OOM the pod.

## Needs

`kubectl`, `helm`, `curl`, and a cluster with room for a ~350Mi pod. Namespace `loki-oom`.
