# 3.2.10 — Alertmanager, proven from evidence

This is the hands-on for the back half of 3.2 — **routing** (3.2.5), **grouping**, **inhibition** and
**silences** (3.2.7). A **mock pager** (a tiny HTTP echo whose *logs are the pager history*) sits
behind Alertmanager, so you don't *believe* each mechanism works — you watch it in the logs.

You fire synthetic alerts at Alertmanager's API and read `kubectl logs deploy/mock-pager`:
each line is one notification, tagged with the receiver path it arrived on and how many alerts it
carried (`n=` shows grouping).

## Prerequisites
A kind cluster mapping host port **9093** (Alertmanager). This repo's
`student-practice/cluster/kind-config.yaml` maps it (`30993→9093`). Builds on the install from
**3.2.4** — same Alertmanager, now with a real routing tree + inhibition.

## Run it
```bash
make setup     # Alertmanager (routing tree + inhibition) + the mock pager

make route     # 3.2.5 — a page → PagerDuty AND Slack (continue:true); a ticket → Jira
make group     #         3 siblings (same alertname) arrive as ONE page
make inhibit   # 3.2.7 — ServiceDown mutes the downstream page in the same namespace
make silence   # 3.2.7 — a time-boxed silence (v2 API) suppresses a matching alert

make verify    # PASS/FAIL — proves all four from the pager logs
make destroy
```
Each scenario prints the pager history so you can point at the evidence.

## The config you're exercising
All in `alertmanager.yaml` — the file 3.2.5–3.2.7 are about:
- **`route`** — the tree: `severity="page"` → `pagerduty` (`continue: true`) → also `slack`; `severity="ticket"` → `jira`. `group_by`/`group_wait` do the batching.
- **`inhibit_rules`** — `alertname="ServiceDown"` mutes `severity="page"`, scoped by `equal: [namespace]`.
- **silences** — created at runtime via `POST /api/v2/silences` (`silence.sh`), always with an expiry.

## What's running
| File | Role |
|---|---|
| `mock-pager.yaml` | the pager — logs every webhook it receives, tagged by path (`/pagerduty`, `/slack`, `/jira`) |
| `alertmanager.yaml` | Alertmanager with the routing tree + inhibition, NodePort `:9093` |
| `fire.sh` / `silence.sh` | post a firing alert / create a silence via the v2 API |

The receivers are **webhooks to the mock pager**, not real Slack/PagerDuty — so the whole lab runs
offline and every notification is a line you can grep.

---
_Verified 2026-10-26 on kind (namespace `monitoring`): `make setup → verify` green — routing (page → PagerDuty + Slack, ticket → Jira), grouping (n=3), inhibition, and silences all proven from the mock-pager logs._
