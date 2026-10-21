---
name: dbt-sql-style
description: Summit Outfitters SQL style and model structure. Use whenever creating, editing or refactoring any .sql model or macro under models/ or macros/ in this project.
---

# dbt SQL style

## Model structure (always)

1. **Import CTEs first**, one per upstream: `name as (select * from {{ ref(...) }})`.
   Filters that define the model's scope can go in the import CTE.
2. **Logical CTEs** next, one transformation each, named for what they do (`order_totals`, `payment_summary`).
3. A **`final`** CTE with the explicit, ordered column list.
4. End with `select * from final`.

```sql
with

orders as (

    select * from {{ ref('stg_shop__orders') }}
    where order_status <> 'CANCELLED'

),

order_totals as (

    select
        order_id,
        sum(line_net_amount) as items_net_amount

    from {{ ref('int_order_lines__usd') }}
    group by order_id

),

final as (

    select
        orders.order_id,
        orders.customer_id,
        order_totals.items_net_amount

    from orders
    inner join order_totals
        on orders.order_id = order_totals.order_id

)

select * from final
```

## Formatting

- Lowercase SQL keywords and functions. 4-space indent. Trailing commas.
- One column per line. Always alias derived columns with `as`.
- Qualify columns with the CTE name whenever more than one CTE is in scope.
- Write join types in full (`inner join`, `left join`, `full outer join`). Put the `on` condition on its own line.
- `group by` uses column names, never ordinals.
- Start each model with a header comment: `-- Migrated from <legacy artifact>` and `-- Grain: one row per ...`.

## Naming

- Models: `stg_shop__<plural>`, `int_<entity>__<qualifier>`, `dim_<entity>`, `fct_<event/process>`.
- Columns: `snake_case`. Primary key = `<entity>_id`. Booleans `is_` / `has_`. Dates `_date`, timestamps `_at`.
- Money columns end in `_amount` (order currency) or `_usd` (converted).

## Layer rules

- **Staging:** `select` from exactly one `source()`. Rename, cast, `trim`/`upper`/`lower`, `nullif(x, '')`.
  No joins, no filters, no aggregations.
- **Intermediate:** joins and reusable business logic. Materialized as views.
- **Marts:** final business grain. Materialized as tables. `select *` only appears as `select * from final`
  and in import CTEs.

## Snowflake semantics to respect

- Money stays `number`/`decimal`. Never cast it to `float`. Use `round(x, 2)` exactly where legacy rounds.
  Per-line rounding before a sum is not the same as rounding the sum.
- `least()` / `greatest()` return NULL if any argument is NULL. `coalesce` the arguments first.
- Integer division is exact in Snowflake. Guard divide-by-zero with `case when den = 0 ...` or `div0()`.
- Prefer `case when` over nested `iff()` when there are more than two branches.
- Use `var('as_of_date')` for "today". Never `current_date` or `current_timestamp` in business logic.
