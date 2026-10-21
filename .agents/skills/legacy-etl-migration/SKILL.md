---
name: legacy-etl-migration
description: Workflow for migrating legacy ETL (SQL stored procedures, Informatica PowerCenter XML, Talend .item jobs, Alteryx .yxmd workflows) into dbt models with legacy parity. Use whenever asked to migrate, convert, refactor or rebuild anything in legacy/.
---

# Legacy ETL → dbt migration

Follow these steps in order. Apply `dbt-sql-style` and `dbt-testing-standards` throughout.

## 1. Inventory the legacy logic (before writing SQL)

Read the whole artifact. Use the tool guide in `references/` (`stored-procedures.md`, `informatica.md`,
`talend.md`, `alteryx.md`). Then list for the user:

- **Sources** read, and the matching `source('shop', ...)` (see the AGENTS.md mapping).
- **Filters**, and where each one applies (source query, filter step, join type).
- **Joins / lookups**: join type, keys, and the **default** when there is no match.
- **Expressions**: every derived column, with its exact rounding and null handling.
- **Aggregations**: grain and measures.
- **Order-dependent logic**, such as sequential UPDATEs or variable ports, and the precedence it implies.
- **Target columns** in order. Exclude audit columns.
- **Quirks** that look like bugs. These are preserved, not fixed.

## 2. Plan the DAG

- Map each source to `stg_shop__<table>`. **Reuse existing staging models.** Create only the missing ones.
- Look in `models/intermediate/` for logic you can reuse. Reuse only if filters, joins and defaults match
  exactly. Otherwise filter in the mart, or create a new intermediate model.
- Put the mart where AGENTS.md says, with the name AGENTS.md gives.

## 3. Build

- Staging: light cleaning only (`trim`, `upper`, `nullif`, casts, renames).
- Intermediate: shared joins and money math.
- Mart: the legacy target's grain and columns, in the same order.
- Carry legacy rounding exactly: per-line `round(..., 2)` before sums when the legacy code does that.

## 4. Test and document

- Write the YAML per `dbt-testing-standards`, including `legacy_parity` → `ref('<legacy snapshot seed>')`.
- Mention preserved quirks in the model description.

## 5. Validate

```bash
dbt build --select +<mart>
```

If `legacy_parity` fails:

1. Look at a few failing keys in both relations and find the column that differs.
2. Trace that column back to the legacy rule you missed: filter, join default, rounding, precedence or null handling.
3. Fix the model and rebuild. Never touch the seed, the test or `legacy/`.

## 6. Report back (keep it short)

- A table mapping each legacy step to the dbt model or CTE that implements it.
- Quirks preserved.
- Test results, with `legacy_parity` PASS.
