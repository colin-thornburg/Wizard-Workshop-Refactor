-- How many rows are identical, modified, added or removed?
-- Preview this in the Studio IDE. Healthy: one row, identical = 214.
--
-- dim_customer_ltv does not exist until Act 2, so it is looked up in the graph at run time
-- instead of with ref(). That keeps "dbt parse" working on a fresh clone of main, and avoids
-- dbt's "unable to infer all dependencies" error that a ref() inside an execute guard causes.
{%- set legacy = ref('legacy_customer_ltv') -%}
{%- set migrated = none -%}
{%- if execute -%}
    {%- set ns = namespace(node=none) -%}
    {%- for node in graph.nodes.values() -%}
        {%- if node.resource_type == 'model' and node.name == 'dim_customer_ltv' -%}{%- set ns.node = node -%}{%- endif -%}
    {%- endfor -%}
    {%- if ns.node is not none -%}
        {%- set migrated = adapter.get_relation(database=ns.node.database, schema=ns.node.schema, identifier=ns.node.alias) -%}
    {%- endif -%}
{%- endif %}

{% if migrated is not none -%}
{%- set compare_columns = [] -%}
{%- for col in adapter.get_columns_in_relation(legacy) -%}
    {%- if col.name | lower not in ['etl_load_ts', 'etl_batch_id'] -%}
        {%- do compare_columns.append(col.name | lower) -%}
    {%- endif -%}
{%- endfor -%}

with classified as (

    {{ audit_helper.compare_and_classify_relation_rows(
        a_relation=legacy,
        b_relation=migrated,
        primary_key_columns=['customer_id'],
        columns=compare_columns,
        sample_limit=5
    ) }}

)

select
    dbt_audit_row_status as row_status,
    max(dbt_audit_num_rows_in_status) as num_rows,
    min(customer_id) as example_customer_id
from classified
group by 1
order by 2 desc
{%- else -%}
select 'dim_customer_ltv is not built yet. Run: dbt build --select +dim_customer_ltv' as audit_status
{%- endif %}
