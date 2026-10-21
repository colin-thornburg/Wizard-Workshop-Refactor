{#
    Generic test: the model must match its legacy snapshot row-for-row.

    Usage (model-level, in the mart's YAML):

      data_tests:
        - legacy_parity:
            arguments:
              legacy_relation: ref('legacy_customer_ltv')
              # optional
              exclude_columns: ['etl_load_ts', 'etl_batch_id']
              precision: 4

    Fails with one row per differing record (parity_diff = missing_in_dbt | extra_in_dbt).
#}
{% test legacy_parity(model, legacy_relation, exclude_columns=none, precision=4) %}

    {%- if execute -%}
        {{ legacy_parity_sql(model, legacy_relation, exclude_columns, precision) }}
    {%- else -%}
        select 1 as parity_diff where 1 = 0
    {%- endif -%}

{% endtest %}
