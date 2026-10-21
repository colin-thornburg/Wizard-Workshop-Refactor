---
name: dbt-testing-standards
description: Summit Outfitters testing and documentation standards. Use whenever creating or changing a model, its YAML properties file, or tests in this project, including when migrating legacy ETL.
---

# Testing and documentation standards

## YAML files

- One properties file per folder, named `_<folder>__models.yml` (for example `_shop__models.yml`, `_sales__models.yml`).
- Every model has a `description`. Every column in a **mart** has a `description`.
- Use `data_tests:`, never `tests:`. Pass generic-test arguments under `arguments:`.

## Required tests

| Layer | Required |
|---|---|
| Staging | Primary key `unique` + `not_null`. `accepted_values` on normalized status or code columns. |
| Intermediate | Primary key `unique` + `not_null`. |
| Marts | Primary key `unique` + `not_null`, or `dbt_utils.unique_combination_of_columns` for composite grain. `accepted_values` on every derived category, status, segment or flag column. `relationships` on foreign keys to dimensions. |
| Migrated marts | Everything above **plus** `legacy_parity` against the legacy snapshot seed. |

## legacy_parity

```yaml
models:
  - name: fct_daily_sales
    description: ...
    data_tests:
      - dbt_utils.unique_combination_of_columns:
          arguments:
            combination_of_columns: ['sales_date', 'channel_group', 'product_category']
      - legacy_parity:
          arguments:
            legacy_relation: ref('legacy_daily_sales_summary')
```

- Compares every non-audit legacy column, by name. The mart must expose all of them.
- Numbers are rounded to 4 dp before comparing. Real differences still fail.
- A failure returns the differing rows, tagged `missing_in_dbt` / `extra_in_dbt`. To debug, run the
  compiled test SQL with `dbt show`, or query both relations for one key and compare column by column.
- **Never** weaken the test, add exclusions or edit the seed to make it pass. Fix the model.

## Example (mart column block)

```yaml
      - name: customer_segment
        description: CRM segment. Precedence VIP > PROSPECT > AT_RISK > HIGH_VALUE > MID_VALUE > LOW_VALUE.
        data_tests:
          - not_null
          - accepted_values:
              arguments:
                values: ['VIP', 'PROSPECT', 'AT_RISK', 'HIGH_VALUE', 'MID_VALUE', 'LOW_VALUE']
```
