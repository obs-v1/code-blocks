# 2.3.7 — DEMO: batch processing and span links

Parent-child assumes **one cause per span**. A batch consumer breaks that: one span
processes N messages drawn from N *different* traces. Which one is the parent? None of
them, and all of them. **Span links** express that many-to-one relationship the tree
cannot — the batch span *links* to every origin without claiming to be its descendant.

This demo seeds four independent orders (each published a message to a queue), then one
`batch-processor` span that consumes all four and carries a **link** to each origin.

```
  source traces (4, each its own trace_id)        batch trace
  ─────────────────────────────────────           ───────────
  order 1001  POST /checkout                       batch-processor  process [4 msgs]
                └ PRODUCER orders.placed send  ◄───── link ─┐  └ CLIENT -> ledger
  order 1002  POST /checkout                                │       └ ledger /post-batch
                └ PRODUCER orders.placed send  ◄───── link ─┤
  order 1003  POST /checkout                                │   (the batch span links to
                └ PRODUCER orders.placed send  ◄───── link ─┤    all four source spans —
  order 1004  POST /checkout                                │    one span, four traces)
                └ PRODUCER orders.placed send  ◄───── link ─┘
```

In Jaeger, OTLP span links render as **References of type `FOLLOWS_FROM`**. The batch span
shows four of them, each pointing OUT to a different source trace.

## Prereqs

- The Jaeger from **`code-blocks/2.3.1`** already running (`monitoring` namespace).
- `kubectl`, `jq`, `openssl`.

## Run

```bash
make            # WIPES Jaeger's old traces, then seeds this demo (clean slate for class)
make verify     # prove the batch span links to >= 4 separate source traces
make ui         # Jaeger URL
```

Use `make seed` to add the demo *without* clearing what's already there.

## Show it to students

1. `make ui`, open Jaeger.
2. **The batch trace.** Search `Service = batch-processor` → open the trace. Click the
   **`settle-batch process [4 msgs]`** span → in its detail you'll see **References (4)**
   /linked spans. Each one is a link to a **different** source trace — click one to jump to
   that order's trace. One span, four source traces.
3. **A source trace.** Search `Service = order-service` → open any order. It's a normal
   small trace (checkout + publish). Note the batch is **not** its child: a parent-child
   tree could only have attached the batch under *one* of the four orders — links avoid
   that misattribution and keep all four honest.

## The actual fix (in real code)

The batch consumer adds a link per message as it builds its span:

```java
SpanBuilder b = tracer.spanBuilder("settle-batch process")
                      .setSpanKind(SpanKind.CONSUMER);
for (Message m : batch) {
    Context origin = propagator.extract(Context.root(), m.headers(), GETTER);
    b.addLink(Span.fromContext(origin).getSpanContext());   // one link per source
}
Span span = b.startSpan();
```

Use **links** (not parent-child) whenever one span serves many source traces: batch jobs,
fan-in aggregators, a flush that commits several requests' work at once.

## Clean up

```bash
make clean      # restarts Jaeger to wipe its in-memory store
```

## Note

These traces are **seeded** to show the shape (one span linking to many). Single-message
queue propagation (producer→consumer, one trace) is the previous section, **2.3.6**.
