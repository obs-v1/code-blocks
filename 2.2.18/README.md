# 2.2.18 — one pipeline for the whole fleet (JSON + every raw format)

A Promtail `pipeline_stages` that parses **all** of bankobs — the 49 structured
(JSON) services *and* the 12 deliberately-unstructured ones — by branching on the
`log_format` pod label and giving each raw format **its own parser**.

## The idea

Every bankobs pod is labelled `log_format: json` or `log_format: raw`. Guessing a
parser per line is the trap: a `json` stage against a log4j line fails silently
(the line ships with no fields). So we choose the parser per pod:

```yaml
pipeline_stages:
  - cri: {}
  - match: { selector: '{log_format="json"}', stages: [ json…, labels: {level,service} ] }
  - match:
      selector: '{log_format="raw"}'
      stages:                              # one parser per format FAMILY, by service
        - match: { selector: '{app=~"…spring/log4j…"}', stages: [ regex level, labels ] }
        - match: { selector: '{app="pci-logger"}',       stages: [ regex pipe level ] }
        - match: { selector: '{app="tomcat-loan-legacy"}', stages: [ regex CLF status ] }
```

The raw formats, taken from the live fleet:

| Service(s) | Format | What we extract |
|---|---|---|
| branch / cheque / nach / cersai / cbs-adapter / weblogic | Spring console + log4j | `level` |
| pci-logger | pipe-delimited (`ts\|LEVEL\|…`) | `level` |
| tomcat-loan-legacy | CLF access log | `status` (no level exists) |
| ibm-mq-bridge / sms / whatsapp / email | genuinely unstructured | shipped as-is (no mislabel) |

The win: `{namespace="bankobs", level="ERROR"}` works across structured *and*
log-pattern services, and the CLF access log is queried by `status`, not stamped
with a fake level.

## Run

```bash
make            # Loki + Promtail + Grafana, then verify every format parsed
make ui         # Grafana URL (Explore -> Loki)
make clean      # tear it down
```

`make verify` asserts:
- JSON services get `service` + `level` labels,
- the log4j/pipe raw formats get `level`,
- the CLF access log gets `status` and is **not** mislabelled with a bogus level.

## Notes

- Runs in its own namespace (`logging`) with unique release names, so it
  coexists with the 2.2 / 2.2.19 stacks (no ClusterRole collisions). Grafana is
  on NodePort **31301** (2.2.19 uses 31300).
- Assumes the cluster is already running **bankobs** (that's where the logs come
  from). This folder deploys only Loki + Promtail + Grafana.
- To parse one of the remaining unstructured formats, add a `match` block for its
  `app` with the right regex — the structure scales one service at a time.
