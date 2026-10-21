{#
    Builds a symmetric-difference query between a migrated dbt model and its legacy snapshot.

    - Columns come from the LEGACY relation (minus excluded audit columns), so the migrated model
      must expose every legacy column with the same name. A missing column fails loudly.
    - Numbers are rounded to `precision` and cast to a common decimal type; other columns are cast
      to the legacy column's type. That removes type noise (float vs number, timestamp vs date)
      while still catching any real value difference.
    - Returns one row per differing record, tagged `missing_in_dbt` or `extra_in_dbt`.
      Zero rows = parity. Pair this with a unique test on the primary key (EXCEPT is set-based).
#}
{% macro legacy_parity_sql(model_relation, legacy_relation, exclude_columns=none, precision=4) %}

    {%- set exclude = (exclude_columns if exclude_columns is not none else ['etl_load_ts', 'etl_batch_id']) | map('lower') | list -%}
    {%- set compare_columns = [] -%}
    {%- for col in adapter.get_columns_in_relation(legacy_relation) -%}
        {%- if col.name | lower not in exclude -%}
            {%- do compare_columns.append(col) -%}
        {%- endif -%}
    {%- endfor -%}

    {%- set select_list -%}
        {%- for col in compare_columns %}
        {% if col.is_number() -%}
            cast(round({{ col.name }}, {{ precision }}) as decimal(38, {{ precision }})) as {{ col.name }}
        {%- else -%}
            cast({{ col.name }} as {{ col.data_type }}) as {{ col.name }}
        {%- endif -%}
        {{ "," if not loop.last }}
        {%- endfor %}
    {%- endset %}

    with

    legacy as (
        select {{ select_list }}
        from {{ legacy_relation }}
    ),

    migrated as (
        select {{ select_list }}
        from {{ model_relation }}
    ),

    missing_in_dbt as (
        select * from legacy
        except
        select * from migrated
    ),

    extra_in_dbt as (
        select * from migrated
        except
        select * from legacy
    )

    select 'missing_in_dbt' as parity_diff, * from missing_in_dbt
    union all
    select 'extra_in_dbt' as parity_diff, * from extra_in_dbt

{% endmacro %}
