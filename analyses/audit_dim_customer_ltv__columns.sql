-- Which columns differ between the legacy snapshot and the dbt mart?
-- Preview this in the Studio IDE. Healthy: every row shows has_difference = false.
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

{{ audit_helper.compare_which_relation_columns_differ(
    a_relation=legacy,
    b_relation=migrated,
    primary_key_columns=['customer_id'],
    columns=compare_columns
) }}
{% endif %}
