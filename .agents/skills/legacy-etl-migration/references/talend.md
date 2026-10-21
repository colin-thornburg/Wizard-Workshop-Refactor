# Talend job (.item) → dbt

Each `node` is a component (`componentName`). `connection` elements link them. A FLOW link with
`lineStyle="8"` is a **lookup** into a tMap. `SUBJOB_OK` links set run order. Logic lives in tMap
`nodeData` (`inputTables`, `varTables`, `outputTables`) as **Java** expressions.

| Component | dbt equivalent |
|---|---|
| tSnowflakeInput / tDBInput (`QUERY`) | Import CTE on the matching staging model |
| tMap lookup input table with `innerJoin="true"` | `inner join`. Unmatched main rows are rejected (dropped) |
| tMap lookup input table with `innerJoin="false"` | `left join` + the null defaults written in the expressions |
| `expressionFilter` on a **lookup** table (`activateExpressionFilter="true"`) | Filter the lookup first. With an inner join, main rows whose lookup is filtered out are dropped too |
| tMap `varTables` | Intermediate columns (CTE) |
| tAggregateRow (`GROUPBYS`, `OPERATIONS`) | `group by` |
| tSortRow + tUniqRow (keep first) | `qualify row_number() over (partition by ... order by ...) = 1` |
| tReplicate | Two CTEs reading the same upstream |
| tHashOutput / tHashInput | A CTE (or `int_` model) shared by later steps |
| tFilterRow | `where` |

Java map: `a == null ? x : y` → `coalesce` / `case` · `StringHandling.UPCASE(s.trim())` → `upper(trim(s))`
· `Math.min(a,b)` → `least(a,b)` (coalesce NULLs first) · `BigDecimal.setScale(n, HALF_UP)` → `round(x, n)`
· `"X".equals(col)` → `col = 'X'` · `TalendDate.getCurrentDate()` → audit column, drop it.
