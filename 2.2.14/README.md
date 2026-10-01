# 2.2.14 — limits_config: overload protection, two ways

Two runnable demos of the same lesson — that `limits_config` is what keeps one
runaway producer from taking Loki down. Pick by how much drama vs. reliability
you want.

| Folder | Shows | Reliability |
|--------|-------|-------------|
| [`self-destruct/`](self-destruct/) | **Loki actually OOMs** under an unbounded flood, then **survives** the same flood once limits are set | dramatic; needs a little node tuning (memory ceiling vs flood size) |
| [`stream-cap/`](stream-cap/) | the flood is **capped with HTTP 429** once `max_global_streams_per_user` is set (no crash) | always lands cleanly, no tuning |

Both are the same before/after shape — flood with limits off, then set the limits
and re-flood — and both are driven by **`make`** (problem → fix) with **`make
clean`** to tear down.

```bash
cd self-destruct   # or stream-cap
make               # problem, then fix
make clean
```

**Which to use?** `self-destruct/` is the money shot — you literally watch the pod
go `OOMKilled → CrashLoopBackOff` and then stay `Running` once protected. But
whether it OOMs depends on the memory ceiling vs how hard you flood, so it wants
one calibration pass on your node (the README there has the knobs). `stream-cap/`
proves the same point without a real crash, so it's the safe choice if you just
want the 429s to show up on cue.
