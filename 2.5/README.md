# 2.5.4 — Project: trace a payment across the fleet

Everything in Week 2 converges here, on the running bank. You follow a real
payment across services **from the logs**, then find where its identity dies —
the deliberate **Kafka break**.

> A note on this fleet: services propagate a **`correlation_id`** across HTTP hops,
> but each service self-generates its `trace_id` (there is no distributed-tracing
> backend wired up). So the *logs in Loki* are the honest map of how far a
> request's identity actually travels — which makes this a pure cross-signal
> exercise (2.5.2), and shows the break as plainly as a Jaeger waterfall would.

## Prereqs

The **2.2.10 Loki + Promtail** lab must be running (this reads the fleet's logs):

```bash
cd ../2.2 && make        # Loki + Promtail shipping the bankobs fleet
```

## Run

```bash
make investigate   # follow one live payment across the services
make verify        # assert cross-service nav works AND the Kafka break is real
```

## What you see (`make investigate`)

```
== follow it across the fleet — the log-based waterfall ==
   gateway-service  routing
   payment-gateway  routing payment
   upi-service      upi-payment-completed
== how far did it reach? ==
   services reached: gateway-service, payment-gateway, upi-service
```

The payment's `correlation_id` travels the **HTTP tier** — gateway →
payment-gateway → upi-service — and then **stops**. upi-service hands the payment
off to Kafka, and the downstream consumers (ledger, notification, audit…) process
it under their *own* ids. The shared identity never crosses the queue.

## Verify

```
  payment correlation_id: web-52618a92-…
  services reached:       gateway-service,payment-gateway,upi-service
  count:                  3
  downstream consumers reached: 0   (should be 0 — the Kafka break)
PASS — the payment id spans the HTTP tier (cross-service nav works),
       and reaches NO Kafka consumer: context dies at the queue boundary.
```

Two assertions, one positive and one **by absence**: the id spans multiple
services (navigation works), and it reaches *zero* Kafka consumers (the break is
real). "Our traces stop at the queue" is nearly universal in real estates — you
have now found and named it once, here. The fix is 2.3.5: the producer must
**inject** context into the message headers and the consumer must **extract** it.

---

**Verified 2026-08-08** on the live bankobs fleet (via the 2.2 Loki): a payment
`correlation_id` spanned gateway → payment-gateway → upi-service and reached **no**
downstream consumer — the Kafka boundary break, proven from the logs.
