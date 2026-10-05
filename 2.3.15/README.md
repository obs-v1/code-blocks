# 2.3.15 — CAPSTONE: trace a payment across the fleet (in Jaeger)

The tracing chapter converges here. One flagship UPI payment, fanning through the whole
bank, is finally **one picture** in Jaeger — and the deliberate **Kafka break** shows where
a trace dies. Seeded into the Jaeger from `code-blocks/2.3.1`.

```
api-gateway  POST /api/upi/pay                              ───────────────────────  650ms
  ├ auth-service       GET /validate            ──
  └ upi-service        POST /pay                   ──────────────────────────────    574ms
      ├ fraud-service  POST /score                   ──  (└ ml-model-infer)
      ├ account-service POST /debit                     ───  (└ ledger-service /post)
      ├ payment-gateway POST /settle                          ─────────────         340ms
      │   └ bank-network POST /authorize                        ────────            310ms  <- slowest leaf
      └ (PRODUCER) payment.completed -> Kafka                              ·  traceparent NOT injected
                                                                              └─X  the break

  notification-service  payment.completed process   [SEPARATE trace]  <- consumer, no parent
      └ sms-service     POST /send
```

Eight services in one trace; the consumer lands in its **own** parentless trace because the
producer never injected `traceparent`.

## The four capstone moves — and what this demo covers

| Move | How | Covered here |
|------|-----|--------------|
| 1. See the payment whole | open the big trace in Jaeger | ✅ seeded |
| 2. Script the hunt | `make hunt` — slowest span via the trace API | ✅ seeded |
| 3. Follow one id across signals | pivot a `trace_id` from Jaeger into **Loki** | ⚠️ needs the live stack (see below) |
| 4. Diagnose the Kafka break | the orphan consumer trace | ✅ seeded |

## Prereqs

- The Jaeger from **`code-blocks/2.3.1`** already running (`observability` namespace).
- `kubectl`, `jq`, `openssl`.

## Run

```bash
make            # WIPES Jaeger's old traces, then seeds the payment journey + Kafka break
make verify     # prove the 8-service trace + the orphan consumer landed
make hunt       # move 2 — the slowest span, scripted against the trace API
make ui         # Jaeger URL
```

`make hunt` prints the real culprit:

```
slowest leaf span:  POST /authorize   310 ms   (page the team that owns it)
```

## Show it to students

1. `make ui` → `Service = api-gateway` → **Find Traces** → open the big payment trace.
   Point out the full fan-out, the long `payment-gateway → bank-network` branch, and the
   `PRODUCER payment.completed` span at the end.
2. `make hunt` → the slowest span, found by script, not by eye.
3. Search `Service = notification-service` → a **separate** trace for the same event. Open
   its root → `expected.trace_id` ≠ `actual.trace_id`, `trace.status = BROKEN`. *"Our traces
   stop at the queue."* Fix = inject/extract (2.3.6).

## Move 3 (cross-signal) needs the live stack

Seeded traces have no matching logs, so the Jaeger → Loki pivot can't be faked. To do it for
real, run the fleet with Loki (`code-blocks/2.2`) and take a `trace_id` from a Jaeger span
into `{namespace="bankobs"} | json | trace_id="<id>"`. The log-first version of this capstone
is `code-blocks/2.5`.

## Clean up

```bash
make clean      # restarts Jaeger to wipe its in-memory store
```
