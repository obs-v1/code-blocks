# 2.2.13 — multi-tenancy (auth_enabled + X-Scope-OrgID)

One knob turns Loki multi-tenant: **`auth_enabled: true`**. With it on, every
push and every query **must** carry an `X-Scope-OrgID` header, and Loki keeps
each tenant's streams completely separate — same cluster, isolated data.

## Run

```bash
make            # deploy Loki (auth on) + prove isolation
make clean      # uninstall + delete the namespace
```

`make` deploys, then `verify.sh` pushes logs as **team-a** and **team-b** and
asserts:

```
  team-a sees (its own):   3   (> 0)
  team-b sees (its own):   2   (> 0)
  team-a sees team-b's:    0   (ISOLATED)
  team-b sees team-a's:    0   (ISOLATED)
  query with NO tenant:    HTTP 401   (auth required)
PASS — tenants are isolated by X-Scope-OrgID; an untenanted query is rejected.
```

## The point

- **`auth_enabled: true`** ([`values.yaml`](values.yaml)) is the whole switch.
  Loki has no user auth of its own — it trusts the `X-Scope-OrgID` header, which
  a gateway/proxy sets per authenticated tenant in production.
- A tenant can only ever see its own streams. `team-a` querying for `team-b`'s
  lines gets **0** — not an error, just nothing, because they're a different
  tenant's data.
- A query with **no** `X-Scope-OrgID` is rejected (`401`, "no org id") — proof
  that tenancy is enforced, not optional.
- Everything flows through the one **`loki-gateway`** URL (2.2.13's third idea) —
  push and query both, just with the tenant header.
