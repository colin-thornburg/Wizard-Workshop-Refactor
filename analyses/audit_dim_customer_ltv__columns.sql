-- Which columns differ between the legacy snapshot and the dbt mart?
-- Preview this in the Studio IDE. Healthy: every row shows has_difference = false.
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

{{ audit_helper.compare_which_relation_columns_differ(
    a_relation=legacy,
    b_relation=migrated,
    primary_key_columns=['customer_id'],
    columns=compare_columns
) }}
{%- else -%}
select 'dim_customer_ltv is not built yet. Run: dbt build --select +dim_customer_ltv' as audit_status
{%- endif %}
