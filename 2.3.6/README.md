# 2.3.6 — DEMO: trace context through a message queue (producer & consumer spans)

HTTP propagation is automatic; **queues are not**. The producer must *inject* the trace
context into the message headers, and the consumer must *extract* it — skip either one and
the trace goes dark at the async boundary. This demo seeds the *same event* two ways so you
can show students exactly what PRODUCER and CONSUMER spans look like, joined and broken.

The event: `order-service` publishes `orders.placed`; `notification-service` consumes it
~0.8s later and emails the customer.

```
CONNECTED  producer injects traceparent, consumer extracts it -> ONE trace
           (the queue wait shows as a GAP between the two spans)

  order-service   POST /checkout            ──
    └ PRODUCER    orders.placed send         ·
                     · · · · · · · · · · · · · · · ·  ~844 ms in the queue  · · · · · ·
    └ CONSUMER    orders.placed process                                   notification-service  ──
        └ CLIENT  -> email-service                                                                ─
            └ email-service  POST /send                                                           ·

BROKEN     inject/extract skipped -> message has no context -> TWO traces

  order-service [trace f94b…]            notification-service [trace 008f…]
    POST /checkout                         orders.placed process   <- new root!
      └ PRODUCER orders.placed send          └ -> email-service
         (context NOT injected)                  └ email-service /send
```

Every span is tagged `demo.scenario=connected|broken` and carries `messaging.*` attributes
(`messaging.system=kafka`, `messaging.operation=publish|process`, the Kafka offset) plus the
propagation story (`propagation=... INJECTED/EXTRACTED`, or `expected.trace_id` vs
`actual.trace_id` on the broken consumer).

## Prereqs

- The Jaeger from **`code-blocks/2.3.1`** already running (`monitoring` namespace).
- `kubectl`, `jq`, `openssl`.

## Run

```bash
make            # WIPES Jaeger's old traces, then seeds this demo (clean slate for class)
make verify     # prove the join (1 trace) + the split (producer-only + orphan consumer)
make ui         # Jaeger URL
```

Use `make seed` to add the demo *without* clearing what's already there.

## Show it to students

1. `make ui`, open Jaeger.
2. **Connected.** Tags `demo.scenario=connected` → open the trace. Point out:
   - the **PRODUCER** span (`orders.placed send`, `messaging.operation=publish`),
   - the long **gap** — the message waiting in the queue (`queue.wait_ms=844`),
   - the **CONSUMER** span (`orders.placed process`, `messaging.operation=process`) parented
     under the producer, then its call out to `email-service`. One trace across the queue.
3. **Broken.** Tags `demo.scenario=broken` → search `order-service` (a producer trace that
   stops at the publish) and `notification-service` (a *separate* consumer trace with no
   caller). Open the consumer root → `expected.trace_id` ≠ `actual.trace_id`: the async
   boundary was never propagated.

## The actual fix (in real code)

The producer injects context into the message headers; the consumer extracts it before
starting its span:

```
// PRODUCER — inject the current context into the Kafka record's headers
propagator.inject(Context.current(), record.headers(), SETTER);
producer.send(record);

// CONSUMER — extract it, and start the span as a child of that context
Context ctx = propagator.extract(Context.current(), record.headers(), GETTER);
Span span = tracer.spanBuilder("orders.placed process")
                  .setSpanKind(SpanKind.CONSUMER).setParent(ctx).startSpan();
```

Auto-instrumentation for Kafka/RabbitMQ/SQS does this for you; the manual pattern matters at
any hand-rolled queue boundary.

## Clean up

```bash
make clean      # restarts Jaeger to wipe its in-memory store
```

## Note

These traces are **seeded** to show the shape (producer/consumer, joined vs split). Batch
consumers — one span serving *many* source traces via span **links** — are the next section,
2.3.7.
