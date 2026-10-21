# Alteryx workflow (.yxmd) → dbt

`Nodes/Node` are tools (`GuiSettings Plugin`, `Properties/Configuration`). `Connections/Connection`
link `Origin ToolID` + `Connection` anchor to `Destination ToolID`. Follow the anchors: they decide the logic.

| Tool | dbt equivalent |
|---|---|
| Input Data (`File` = `odbc:...|||SELECT ...`) | Import CTE. **Keep the SQL `WHERE`**: it is a filter |
| Select | Column list / renames / casts |
| Formula (`FormulaField expression`) | Derived columns |
| Filter (`True` / `False` anchors) | `where` (check which anchor continues) |
| Summarize (`GroupBy`, `Sum`, `Count`, `Max`) | `group by` |
| Join: **J** (matched), **L** (left only), **R** (right only) anchors | Used anchors decide the join. J only = `inner join`. J + L = `left join`. J + L + R = `full outer join`. Build each branch's derived columns with `case` on which side matched |
| Union (by name) | `union all`, or one `full outer join` with `case` per branch |
| Sort | Not needed in a model, except for `qualify` ordering |
| Output Data | The mart |

Function map: `IIF(c,a,b)` → `case` · `IsNull(x)` → `x is null` · `Null()` → `null`
· `Uppercase(Trim(x))` → `upper(trim(x))` · `Round(x, 0.01)` → `round(x, 2)`
· `DateTimeDiff(a, b, "days")` → `datediff('day', b, a)` · `Abs(x)` → `abs(x)` · `DateTimeNow()` → audit column, drop it.
