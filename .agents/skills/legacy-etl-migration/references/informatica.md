# Informatica PowerCenter XML → dbt

Read the `MAPPING` element. Follow `CONNECTOR` elements (FROMINSTANCE → TOINSTANCE) to get the flow order.
Each `TRANSFORMATION` has `TRANSFORMFIELD` ports (`PORTTYPE` = INPUT / OUTPUT / VARIABLE / LOOKUP)
and `TABLEATTRIBUTE` settings.

| Transformation | dbt equivalent |
|---|---|
| Source Qualifier: `User Defined Join`, `Source Filter`, `Sql Query` | Join and `where` in the import CTEs / staging selection |
| Lookup (connected) | `left join`. **No match returns NULL**, so look for `IIF(ISNULL(...))` defaults downstream |
| Expression (`v_` variable ports, `o_` output ports) | Columns in a CTE. Variable ports are intermediate calculations |
| Filter: `Filter Condition` | `where` |
| Aggregator: group-by ports + `SUM()` / `COUNT()` | `group by` |
| Router | Several `where` branches or `case` |
| Target definition (`TARGETFIELD` order) | Final column list and order |

Function map: `IIF(c,a,b)` → `case when c then a else b end` · `DECODE(x, v1, r1, ..., default)` → `case x when ...`
· `ISNULL(x)` → `x is null` · `LTRIM(RTRIM(x))` → `trim(x)` · `TRUNC(date,'MM')` → `date_trunc('month', date)`
· `SESSSTARTTIME` / `SYSDATE` → audit column, drop it.
