# 2.3.5 — DEMO: a propagation-format mismatch, and the multi-propagator fix

A format mismatch is the nastiest kind of broken trace: **nothing errors**, the trace just
silently splits in two. This demo makes that visible in Jaeger by seeding the *same logical
request* two ways, so you can show students the before and after side by side.

The request: `checkout-service` → `order-service`.

```
BROKEN  checkout-service speaks B3 (X-B3-* headers).  order-service reads only W3C
        traceparent, so it CAN'T read the B3 header -> it starts a brand-new trace.
        => ONE request, TWO disjoint traces, no error anywhere.

          checkout-service  [trace 80f198ee…]          order-service  [trace 4aa97799…]
            POST /checkout                                POST /place      <- new root!
              └ CLIENT -> order-service  —X—>                └ reserve-stock
                 (B3 header sent)            (B3 ignored, context lost)

FIXED   order-service is configured with a COMPOSITE propagator (tracecontext + b3).
        It extracts the B3 context -> both services land in ONE trace.

          checkout-service  [trace b26cb9b4…]
            POST /checkout
              └ CLIENT -> order-service
                   └ order-service POST /place   (parent = the caller's span)
                        └ reserve-stock
```

Every span is tagged `demo.scenario=broken|fixed` and carries the actual header values
(`outgoing.b3.header`, `incoming.b3.header`, `extracted.parent`, `expected.trace_id` vs
`actual.trace_id`) so the **why** is visible in each span's **Tags**.

## Prereqs

- The Jaeger from **`code-blocks/2.3.1`** already running (`observability` namespace).
- `kubectl`, `jq`, `openssl`.

## Run

```bash
make            # WIPES Jaeger's old traces (incl. 2.3.1 samples), then seeds this demo
make verify     # prove the split (2 one-service traces) + the fix (1 joined trace)
make ui         # Jaeger URL
```

`make` restarts Jaeger first so the UI shows **only** this demo — a clean slate for class.
Use `make seed` if you want to add the demo *without* clearing what's already there.

## Show it to students

The B3/legacy story is visible **right in the span names** — `[speaks B3 / legacy]`,
`[sends B3 headers]`, `[B3 IGNORED -> new trace]`, `[B3 extracted via composite]` — and every
span carries a `propagation.format` tag (`B3 (Zipkin, legacy)` vs `W3C traceparent only…` vs
`composite (W3C + B3)`). The exact header string is the `outgoing.b3.header` /
`incoming.b3.header` tag on the client/server spans.

1. `make ui`, open Jaeger.
2. **The split.** Search `Service = checkout-service`, Tags `demo.scenario=broken` → the
   trace **ends** at the call to order-service. Now search `Service = order-service`, same
   tag → a **separate** trace with no caller. One request, two half-stories. Open the
   order-service root span → Tags show `incoming.b3.header=…`, `extracted.parent=none`,
   and `expected.trace_id` ≠ `actual.trace_id`. That mismatch is the bug.
3. **The fix.** Tags `demo.scenario=fixed` → **one** trace spanning both services. The
   order-service span's Tags show `propagators=composite(tracecontext,b3)` and
   `extracted.parent=<the caller's span id>`.

## The actual fix (in real code)

The split happens because the two services negotiate context with different propagators.
Tell every service to **read and emit several formats at once**. In OpenTelemetry that's
one environment variable:

```bash
# accept/emit W3C traceparent AND B3 — a mixed fleet stays stitched together
OTEL_PROPAGATORS=tracecontext,baggage,b3
```

(Programmatically: install a composite `TextMapPropagator` of `TraceContext` + `B3`.)
During a migration you leave this on both sides until everything speaks W3C.

## Clean up

```bash
make clean      # restarts Jaeger to wipe its in-memory store (also clears 2.3.1 samples)
```

## Note

These traces are **seeded** — they illustrate the *outcome* (split vs joined) and carry the
header values as tags. To watch a real `traceparent` cross the wire between two live
services, that's the **2.3.11** lab (`code-blocks/2.3`).
