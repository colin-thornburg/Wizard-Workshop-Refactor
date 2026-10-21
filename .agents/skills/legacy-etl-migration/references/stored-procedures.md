# Stored procedures → dbt

| Procedural pattern | dbt equivalent |
|---|---|
| `CREATE TEMPORARY TABLE tmp_x AS ...` | A CTE, or an `int_` model if another mart could reuse it |
| `TRUNCATE` + `INSERT INTO target` | The mart itself (`materialized: table`) |
| Sequential `UPDATE target SET col = ... WHERE ...` | One `case` expression. **Later UPDATEs win**, so their conditions go *first* in the `case` |
| `DECLARE v_x DEFAULT 2000` (thresholds) | Inline literal with a comment, or a `var()` if the business changes it |
| Procedure parameter (`P_AS_OF_DATE`) | `var('as_of_date')` |
| `COALESCE(x, 0)` after a `LEFT JOIN` | Keep it. It sets the value for rows with no match |
| Audit log inserts, `SQLROWCOUNT`, `EXCEPTION` blocks | Drop. dbt run results and tests replace them |
| Cursor / loop row-by-row logic | Set-based SQL (window functions, `qualify`) |

Checks:
- Does the procedure drive from a master table (customers) with `LEFT JOIN`s? Then rows with no activity still appear.
- Are values rounded per row inside a temp table, then summed later? Keep the same order.
