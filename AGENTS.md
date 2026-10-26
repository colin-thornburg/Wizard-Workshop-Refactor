# AGENTS.md — Summit Outfitters analytics (dbt on Snowflake)

We are retiring four legacy ETL workflows and rebuilding them as dbt models. These rules
apply to every change in this repo. Skills in `.agents/skills/` hold the detail:
`dbt-sql-style`, `dbt-testing-standards`, `legacy-etl-migration`.

## Project layout

| Path | What lives there |
|---|---|
| `legacy/` | Legacy code to migrate. **Read-only reference. Never edit.** |
| `seeds/raw/` | Raw source data, loaded to `<schema>_raw`. Exposed as `source('shop', ...)`. |
| `seeds/legacy_targets/` | Snapshots of the legacy output tables. Golden data for parity. **Never edit.** |
| `models/staging/shop/` | `stg_shop__<entity>` — 1:1 with a source table. |
| `models/intermediate/` | `int_<entity>__<verb/qualifier>` — reusable joins and business logic. |
| `models/marts/<domain>/` | `dim_` / `fct_` models consumed by the business. |
| `tests/generic/legacy_parity.sql` | Parity test against a legacy snapshot. |
| `macros/parity/` | Parity SQL + `parity_report` scoreboard. |

## Legacy to dbt mapping

Legacy code reads `RAW.SHOP.<TABLE>`. In dbt, always use the source:

| Legacy table | dbt |
|---|---|
| `RAW.SHOP.CUSTOMERS` | `source('shop', 'customers')` |
| `RAW.SHOP.PRODUCTS` | `source('shop', 'products')` |
| `RAW.SHOP.ORDERS` | `source('shop', 'orders')` |
| `RAW.SHOP.ORDER_LINES` | `source('shop', 'order_lines')` |
| `RAW.SHOP.PAYMENTS` | `source('shop', 'payments')` |
| `RAW.SHOP.RETURNS` | `source('shop', 'returns')` |
| `RAW.SHOP.FX_RATES` | `source('shop', 'fx_rates')` |

Migration targets. Use exactly these model names and folders:

| Legacy workflow | Legacy target table | dbt mart | Legacy snapshot seed |
|---|---|---|---|
| `legacy/stored_procedures/sp_load_customer_ltv.sql` | `ANALYTICS.LEGACY.CUSTOMER_LTV` | `marts/customers/dim_customer_ltv` | `legacy_customer_ltv` |
| `legacy/informatica/m_LOAD_DAILY_SALES_SUMMARY.xml` | `ANALYTICS.LEGACY.DAILY_SALES_SUMMARY` | `marts/sales/fct_daily_sales` | `legacy_daily_sales_summary` |
| `legacy/talend/J_Product_Returns_Analysis_0.1.item` | `ANALYTICS.LEGACY.PRODUCT_RETURNS_SUMMARY` | `marts/sales/fct_product_returns` | `legacy_product_returns_summary` |
| `legacy/alteryx/Payment_Reconciliation.yxmd` | `ANALYTICS.LEGACY.PAYMENT_RECONCILIATION` | `marts/finance/fct_payment_reconciliation` | `legacy_payment_reconciliation` |

## Non-negotiables

1. **Layering:** sources → staging → intermediate → marts. Marts never read sources. Staging never joins.
2. **One staging model per source table.** Before creating one, list `models/staging/shop/` and read only the files the listing shows. Reuse; never duplicate.
3. **Always reuse the shared models in rule 6.** They carry no filters. Reuse any *other* intermediate model
   only when the rules match exactly: same filters, join types and defaults. The four legacy workflows do not
   all filter the same way.
4. **Preserve legacy behavior, including its quirks.** Same grain, same column names (lower snake_case),
   same column order as the legacy target. Drop legacy audit columns (`ETL_LOAD_TS`, `ETL_BATCH_ID`).
   If legacy logic looks wrong, keep it and flag it in the model's YAML description. Don't fix it silently.
5. **Money:** never cast to float. Keep `number`/`decimal` math and round where the legacy code rounds.
6. **Shared intermediate models: build once, reuse everywhere.**
   - `int_order_lines__usd`: one row per order line, **all lines, no filters**. It carries at least the ids,
     `order_date`, `order_status`, `channel`, `currency_code`, `quantity`, the local amounts
     (`line_gross_amount`, `line_discount_amount`, `line_net_amount`), `usd_rate`, the per-line rounded USD
     amounts (`line_gross_usd`, `line_discount_usd`, `line_net_usd`) and boolean flags `is_valid_order`,
     `is_test_customer`, `has_known_product`.
   - `is_valid_order` means `order_status` is `COMPLETED`, `SHIPPED`, or `RETURNED`. Workflows with a different status rule filter `order_status` in the mart.
   - `int_returns__usd`: one row per return, with `refund_usd` at the order-month rate and the same flags.
   - Marts aggregate from these. **Marts never join `fx_rates` or re-derive status/test-account logic.**
   - **Filters live in the mart, never in a shared model.** The legacy workflows filter differently
     (statuses, test accounts, zero quantities, unknown products). Shared models carry flags; each mart picks.
   - If the model you need is missing, create it. If it lacks a column you need, add the column.
     Then run `dbt build --select <shared model>+` so every existing mart re-proves parity.
7. **No hard-coded dates or schemas.** Use `var('as_of_date')` instead of `current_date`. Use `ref()`/`source()`.
8. **Never edit** `legacy/`, `seeds/`, `tests/generic/legacy_parity.sql` or `macros/parity/` to make a test pass.

## Definition of done for a migrated mart

- [ ] SQL follows `dbt-sql-style`; YAML follows `dbt-testing-standards`.
- [ ] Mart YAML has a `legacy_parity` test pointing at its snapshot seed.
- [ ] Reuse check: the summary names the existing staging and intermediate models reused, and why anything new was needed.
- [ ] `dbt build --select +<mart>+` passes, including `legacy_parity`.
- [ ] `dbt run-operation parity_report` is run, and its result is included in the summary.
- [ ] Short summary to the user: legacy step → dbt model mapping, plus any quirks preserved.

## Commands

```bash
dbt deps                              # once
dbt seed                              # load raw + legacy snapshots (once per environment)
dbt build --select +dim_customer_ltv  # build a mart, its parents and their tests
dbt run-operation parity_report       # scoreboard for all four migrations
```
