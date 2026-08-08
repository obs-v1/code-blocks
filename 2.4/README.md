# 2.4.8 — Lab: SDK and a Collector with tail sampling

The two services from 2.3 now export to an **OTel Collector** running
`tail_sampling`, not straight to Jaeger. A driver generates a mix — mostly
routine calls, a steady trickle of errors — and the decisive demonstration is
that **every error trace survives while routine traces are thinned to the sample
rate**. Policy observed working beats policy described.

```
  service-a ─► service-b ──OTLP──► OTel Collector ──OTLP──► Jaeger
                                   [ memory_limiter → tail_sampling → batch ]
                                     keep errors · keep slow · sample 10% rest
```

## The policy (`collector.yaml`)

```yaml
tail_sampling:
  decision_wait: 5s                 # buffer a whole trace, then decide
  policies:
    - { name: keep-errors,   type: status_code,   status_code: { status_codes: [ERROR] } }
    - { name: keep-slow,     type: latency,       latency: { threshold_ms: 300 } }
    - { name: sample-the-rest, type: probabilistic, probabilistic: { sampling_percentage: 10 } }
```

Processor order is execution order (2.4.6): `memory_limiter` first (self-protection),
`tail_sampling` in the middle, `batch` last.

## Run

```bash
make setup      # build image, deploy Jaeger + Collector + services
make verify     # fires a burst, then proves the sampling result
```

`make setup` runs on the box (builds an image and `kind load`s it).

## Verify

```
  driver generates ~5x more routine calls than errors
  ------------------------------------------------
  error traces KEPT:    40      (all of them)
  routine traces KEPT:  20      (~10% of ~200 — the sample rate)
  total in Jaeger:      60
PASS — every error trace survived while routine traffic was thinned:
       more errors kept than routine, despite 5x more routine generated.
```

That inversion is the proof: **5× more routine traffic was generated, yet more
error traces ended up in Jaeger** — impossible unless tail sampling kept 100% of
errors and dropped ~90% of routine. Debugging value preserved at a fraction of the
storage (2.3.8).

## The knob with teeth

`decision_wait` sizes the buffer. Too short and you truncate the slow traces you
meant to keep; too long and buffered traces multiply memory by traffic volume and
can OOM the Collector — taking the whole pipeline down. Size it just past your p99
trace duration (2.4.7).

## Tear down

```bash
make destroy
```

---

**Verified 2026-08-08** on kind: from ~40 errors + ~200 routine, the Collector kept
**40 error traces (100%)** and **20 routine traces (~10%)** — errors preserved,
routine thinned to the sample rate.
