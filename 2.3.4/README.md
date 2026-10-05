# 2.3.4 — DEMO: the five span kinds

One compact payment trace that shows **all five span kinds** at once, each span tagged with
what it means. Seeded into the Jaeger from `code-blocks/2.3.1`.

```
upi-service      SERVER    POST /api/upi/pay              ──────────────────────  200ms
  ├ upi-service  CLIENT    -> account-service /debit        ────────────          120ms  ┐ 15ms gap
  │   └ account-service SERVER /debit                         ─────────           105ms  ┘ = NETWORK
  ├ upi-service  INTERNAL  compute-fee                                    ·         15ms
  ├ upi-service  PRODUCER  payment.completed -> Kafka                       ·        5ms
  └ notification-service CONSUMER  payment.completed process                 ──      23ms
```

| Kind | In this trace | Jaeger `span.kind` tag |
|------|---------------|------------------------|
| **SERVER**   | `upi-service` handling `/api/upi/pay`; `account-service` handling `/debit` | `server` |
| **CLIENT**   | `upi-service` calling `account-service` | `client` |
| **PRODUCER** | `upi-service` publishing to Kafka | `producer` |
| **CONSUMER** | `notification-service` processing the message | `consumer` |
| **INTERNAL** | `compute-fee` (in-process, no network) | *(none — see note)* |

> **Note on INTERNAL:** Jaeger records a `span.kind` tag only for the four network kinds.
> INTERNAL is the implicit default and carries **no** `span.kind` tag — so the `compute-fee`
> span is your INTERNAL example, identified by its `note` tag rather than a `span.kind`.

**The teaching detail:** the CLIENT bar is **120ms**, the SERVER bar nested inside it is
**105ms**. That **15ms gap is pure network time** — latency you diagnosed without
instrumenting a single router.

## Prereqs

- The Jaeger from **`code-blocks/2.3.1`** already running (`monitoring` namespace).
- `kubectl`, `jq`, `openssl`.

## Run

```bash
make            # WIPES Jaeger's old traces, then seeds the span-kinds trace (clean slate)
make verify     # prove all the kinds landed
make ui         # Jaeger URL
```

Use `make seed` to add the demo *without* clearing what's already there.

## Show it to students

1. `make ui` → `Service = upi-service` → open the trace.
2. Click each span → **Tags** → `span.kind` names the role. Walk SERVER → CLIENT → SERVER →
   INTERNAL (the `note` tag) → PRODUCER → CONSUMER.
3. **The free network diagnosis:** point at the CLIENT bar (120ms) vs the SERVER bar inside
   it (105ms) — the 15ms difference is time on the wire.
4. **Service map from kinds:** the **System Architecture** tab shows the dependency graph
   Jaeger builds *from* the span kinds — `upi-service → account-service`, `upi-service →
   notification-service`. Mis-kind a span and this map would be wrong.

## Clean up

```bash
make clean      # restarts Jaeger to wipe its in-memory store
```
