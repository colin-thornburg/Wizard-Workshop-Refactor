-- How many rows are identical, modified, added or removed?
-- Preview this in the Studio IDE. Healthy: one row, identical = 214.
--
-- The ref() calls are wrapped in an execute guard so that "dbt parse" succeeds
-- before dim_customer_ltv exists. Unguarded, the ref is captured at parse time
-- and every dbt command fails on a fresh clone of main.
{% if execute %}
{% set legacy = ref('legacy_customer_ltv') %}
{% set migrated = ref('dim_customer_ltv') %}
{% set compare_columns = [] %}
{% for col in adapter.get_columns_in_relation(legacy) %}
    {% if col.name | lower not in ['etl_load_ts', 'etl_batch_id'] %}
        {% do compare_columns.append(col.name | lower) %}
    {% endif %}
{% endfor %}

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
{% endif %}
