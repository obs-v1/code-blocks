# 2.2.14 — limits_config: the overload-protection simulation

A before/after you can run: flood Loki with a runaway, high-cardinality producer
and watch what happens **with the limits open** vs **with them set**.

## Run

```bash
make            # PROBLEM (limits open) then FIX (limits set) — one command
make clean      # uninstall + delete the namespace
```

`make` does two rounds against the same Loki, each flooding **200 unique
streams** (the 2.2.3 cardinality trap):

```
>>> PROBLEM — limits wide open (max_global_streams_per_user: 100000)
    pushed 200 unique streams  ->  accepted(204)=200   rejected(429)=0   other=0
    every stream was accepted — nothing capped the cardinality.

>>> FIX — max_global_streams_per_user: 50
    pushed 200 unique streams  ->  accepted(204)=50    rejected(429)=150  other=0
    a limit is holding the line: 150 streams were refused, Loki protected.
```

Same flood, same producer — the only thing that changed is `limits_config`.

## What each phase shows

- **Problem** ([`values-loose.yaml`](values-loose.yaml)) — `max_global_streams_per_user`
  is effectively unlimited, so all 200 streams are accepted. In a real fleet those
  streams pile into ingester memory and the index; a few runaway producers like
  this are how Loki OOMs.
- **Fix** ([`values-tight.yaml`](values-tight.yaml)) — set
  `max_global_streams_per_user: 50` and Loki **rejects** every stream past the cap
  with **HTTP 429** ("Maximum active stream limit exceeded"). The flood is
  contained; well-behaved tenants are unaffected.

`make solve` restarts Loki after applying the tight config, so the ingester starts
with a clean slate and you see the cap engage from stream 51 onward.

## The other knobs in `values-tight.yaml`

The same file also sets the rate guards from 2.2.14 — they protect against a
different flavor of flood (volume, not cardinality):

| Setting | Caps |
|---------|------|
| `max_global_streams_per_user` | active streams per tenant (this demo) |
| `ingestion_rate_mb` / `ingestion_burst_size_mb` | how fast a tenant can write |
| `per_stream_rate_limit` / `..._burst` | how fast a **single** stream can write |

To see a *rate* limit fire instead, drop `per_stream_rate_limit` to something tiny
(e.g. `1KB`) and push many lines to one stream — you'll get 429s from that cap.

## Needs

`kubectl`, `helm`, `curl`, and a cluster. Uses namespace `loki-limits`.
