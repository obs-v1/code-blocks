# business-kpis — a business dashboard for bankobserve360

RED / USE / Golden measure the *plumbing* — requests, CPU, pools. This one
measures the **business**: how many payments are flowing and how much money is
moving. It reads the bank's **own** counters, emitted by the **UPI service**
(the reference payment rail) — no extra instrumentation needed, the data is
already there.

| uid | Dashboard | Answers |
|-----|-----------|---------|
| `biz-payments` | **Business — UPI Payments** | Payments/min, ₹/min, success rate, ₹ transacted, avg ticket size, latency. |

## Load it

```bash
make apply   GRAFANA_URL=http://<node-ip>:13000 GRAFANA_AUTH=admin:admin
make destroy GRAFANA_URL=...
```

## Make it move

The panels only move while UPI payments are flowing. In the **bankobserve360**
repo:

```bash
make up-staged && make seed     # seed includes the VPA registry (valid payers/payees)
make load                       # continuous mixed traffic — includes UPI pay
# or a single end-to-end payment:  make smoke
```

## The metrics it reads (already emitted — no code change)

Business counters from `upi-service` (`services/payments/upi-service/main.go`),
all incremented when a payment **fully settles**:

| Metric | Meaning | Used for |
|--------|---------|----------|
| `upi_transaction_total` | payments completed | payments/min, count |
| `upi_daily_volume_total` | **cumulative ₹ moved** (`.Add(amount)`) | money flow, ₹ transacted, avg ticket |
| `upi_p99_latency_seconds` | payment latency histogram | p50/p95/p99 |
| `upi_transaction_success_total` | successful payments | (see note) |

Plus the shared HTTP counter, for attempts & failures (which the settle-only
counters above can't show):

- `http_server_requests_total{service="upi-service", path="/api/v1/upi/pay", status}`
  — **status** is `2xx` / `4xx` / `5xx`. Success rate = `2xx / all` on this route;
  the *attempted vs completed* panel plots this against `upi_transaction_total`,
  so the gap between the two lines is failed / blocked payments.

## Honest scope & notes

- **UPI only.** UPI is the one rail that publishes a rupee **metric**
  (`upi_daily_volume_total`). NEFT / RTGS / NACH put the amount in **trace
  spans** and Kafka events, not metrics — so they can show payment *counts*
  (via their HTTP counters) but not money throughput on a Grafana time series.
  Extending "₹ moved" to those rails needs a one-line counter added to each.
- **`upi_transaction_total` counts settled payments, not attempts** — it only
  increments on the success path. That's why success rate and the
  attempted-vs-completed panel use the HTTP route counter, which sees every
  attempt including the failures.
- **₹ shown as `currencyINR`.** If your Grafana build doesn't localise it, the
  number is still correct — only the ₹ prefix is cosmetic.
- On a cold load a panel can read "No data" until the first UPI payment lands.
