# Wizard Workshop: retire your legacy ETL with dbt Wizard

Summit Outfitters (a fictional outdoor retailer) runs four legacy pipelines that load Snowflake tables.
In this workshop, dbt Wizard migrates each one to tested, documented dbt models, and we **prove parity**
against what the legacy tools produced.

| # | Legacy tool | Artifact | Loads | dbt mart |
|---|---|---|---|---|
| 1 | Snowflake stored procedure | `legacy/stored_procedures/sp_load_customer_ltv.sql` | `CUSTOMER_LTV` | `dim_customer_ltv` |
| 2 | Informatica PowerCenter | `legacy/informatica/m_LOAD_DAILY_SALES_SUMMARY.xml` | `DAILY_SALES_SUMMARY` | `fct_daily_sales` |
| 3 | Talend | `legacy/talend/J_Product_Returns_Analysis_0.1.item` | `PRODUCT_RETURNS_SUMMARY` | `fct_product_returns` |
| 4 | Alteryx | `legacy/alteryx/Payment_Reconciliation.yxmd` | `PAYMENT_RECONCILIATION` | `fct_payment_reconciliation` |

## What's in the repo

- `seeds/raw/`: fake raw e-commerce data (customers, products, orders, lines, payments, returns, FX).
  The text values are deliberately messy.
- `seeds/legacy_targets/`: what each legacy tool wrote to its target table. This is the golden data for parity.
- `AGENTS.md` + `.agents/skills/`: our dbt standards. dbt Wizard loads them automatically.
- `tests/generic/legacy_parity.sql`: fails if a migrated mart differs from its legacy snapshot by even one value.
- `macros/parity/parity_report.sql`: `dbt run-operation parity_report` prints a 4-row scoreboard.

## Setup (dbt platform + Snowflake)

1. Connect this repo to a dbt platform project that has a Snowflake connection and a development environment.
2. Open the Studio IDE and run:
   ```bash
   dbt deps
   dbt seed
   dbt run-operation parity_report   # expect 0 of 4 at parity
   ```
3. Open **dbt Wizard** from the command palette and start migrating.

The raw data is loaded to `<your_schema>_raw`. Legacy snapshots go to `<your_schema>_legacy`.
