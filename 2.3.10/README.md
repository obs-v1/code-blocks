# 2.3.10 — DEMO: waterfall analysis (finding the slow span)

Reading a trace is a skill with a handful of moves. This demo seeds **one deliberately-slow
checkout trace** that shows every move at once, plus **two fast baselines** so the slow one
stands out in Jaeger's duration scatter. The key spans carry an `analysis` tag that names
what you're looking at.

```
api-gateway  GET /api/checkout                          ──────────────────────────  900ms
  ·········· 120ms GAP (nothing) = uninstrumented wait (connection pool / queue) ··········
  ├ cart-service      GET /items        ──                                            40ms  ┐
  ├ pricing-service   GET /quote           ──                                         50ms  │ run in a LINE
  ├ inventory-service GET /check              ──                                      45ms  ┘ (could be parallel)
  └ payment-service   POST /charge               ───────────────────────────────    560ms  <- THE LONG BAR
        └ bank-gateway POST /authorize              ─────────────────────────────    492ms  <- SLOW IN ITS OWN CODE
```

The four reading moves, all present:

| Move | Where in this trace |
|------|---------------------|
| **Parallelizable work** | cart / pricing / inventory run sequentially (~145ms in a line, ~50ms if parallel) |
| **The one long bar** | the `payment-service` chain — 560 of the 900ms; start your read here |
| **Slow-self vs waits-on-children** | `payment-service` is slow only via its child; `bank-gateway` (a leaf) is slow in its **own** code — different teams to page |
| **Negative space (a gap)** | 120ms before the first child = real work with no span (pool/queue/GC) |

## Prereqs

- The Jaeger from **`code-blocks/2.3.1`** already running (`monitoring` namespace).
- `kubectl`, `jq`, `openssl`.

## Run

```bash
make            # WIPES Jaeger's old traces, then seeds the slow trace + 2 baselines
make verify     # prove the slow waterfall + baselines landed
make ui         # Jaeger URL
```

Use `make seed` to add the demo *without* clearing what's already there.

## Show it to students

1. `make ui`, open Jaeger, `Service = api-gateway` → **Find Traces**.
2. The scatter plot at the top shows two dots near ~115ms and **one outlier at ~900ms** —
   "find the slow one" is literally a click.
3. Open the 900ms trace and read top-to-bottom:
   - the **120ms gap** before the first bar (negative space),
   - the three short bars that run **in a line** (parallelizable),
   - the **one long bar** (`payment-service`), and inside it,
   - `payment-service` waiting on its child vs **`bank-gateway` being slow itself** (the leaf).
4. Click each highlighted span → its `analysis` tag spells out the lesson. The bank-gateway
   leaf is the span you'd actually ticket.

## Clean up

```bash
make clean      # restarts Jaeger to wipe its in-memory store
```

## Note

These traces are **seeded** to show the shape. The `analysis` tags are a teaching aid — real
spans won't tell you they're the culprit; the skill is reading the bars and the gaps yourself.
