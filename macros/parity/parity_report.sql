{#
    Scoreboard for the whole migration. Run:

        dbt run-operation parity_report

    For each legacy workflow it reports whether the dbt mart exists, row counts on both sides,
    and how many records differ. Does not fail; use the legacy_parity test for gating.
#}
{% macro parity_report() %}

    {%- set checks = [
        {'workflow': 'Stored proc  SP_LOAD_CUSTOMER_LTV',        'model': 'dim_customer_ltv',           'legacy': 'legacy_customer_ltv'},
        {'workflow': 'Informatica  m_LOAD_DAILY_SALES_SUMMARY',  'model': 'fct_daily_sales',            'legacy': 'legacy_daily_sales_summary'},
        {'workflow': 'Talend       J_Product_Returns_Analysis',  'model': 'fct_product_returns',        'legacy': 'legacy_product_returns_summary'},
        {'workflow': 'Alteryx      Payment_Reconciliation',      'model': 'fct_payment_reconciliation', 'legacy': 'legacy_payment_reconciliation'},
    ] -%}

    {%- if not execute -%}{{ return('') }}{%- endif -%}

    {%- set lines = [] -%}
    {%- set passed = [] -%}
    {%- do lines.append('') -%}
    {%- do lines.append('LEGACY PARITY REPORT') -%}
    {%- do lines.append('-' * 108) -%}
    {%- do lines.append('%-42s %-28s %8s %8s %8s %8s  %s' | format('legacy workflow', 'dbt model', 'legacy', 'dbt', 'missing', 'extra', 'status')) -%}
    {%- do lines.append('-' * 108) -%}

    {%- for check in checks -%}
        {%- set ns = namespace(model_node=none, legacy_node=none) -%}
        {%- for node in graph.nodes.values() -%}
            {%- if node.resource_type == 'model' and node.name == check.model -%}{%- set ns.model_node = node -%}{%- endif -%}
            {%- if node.resource_type == 'seed' and node.name == check.legacy -%}{%- set ns.legacy_node = node -%}{%- endif -%}
        {%- endfor -%}

        {%- set legacy_rel = none -%}
        {%- if ns.legacy_node is not none -%}
            {%- set legacy_rel = adapter.get_relation(database=ns.legacy_node.database, schema=ns.legacy_node.schema, identifier=ns.legacy_node.alias) -%}
        {%- endif -%}
        {%- set model_rel = none -%}
        {%- if ns.model_node is not none -%}
            {%- set model_rel = adapter.get_relation(database=ns.model_node.database, schema=ns.model_node.schema, identifier=ns.model_node.alias) -%}
        {%- endif -%}

        {%- if legacy_rel is none -%}
            {%- do lines.append('%-42s %-28s %8s %8s %8s %8s  %s' | format(check.workflow, check.model, '-', '-', '-', '-', 'LEGACY SEED NOT LOADED (run dbt seed)')) -%}
        {%- elif ns.model_node is none -%}
            {%- do lines.append('%-42s %-28s %8s %8s %8s %8s  %s' | format(check.workflow, check.model, '-', '-', '-', '-', 'NOT MIGRATED')) -%}
        {%- elif model_rel is none -%}
            {%- do lines.append('%-42s %-28s %8s %8s %8s %8s  %s' | format(check.workflow, check.model, '-', '-', '-', '-', 'NOT BUILT')) -%}
        {%- else -%}
            {%- set sql -%}
                with diffs as ({{ legacy_parity_sql(model_rel, legacy_rel) }})
                select
                    (select count(*) from {{ legacy_rel }}) as legacy_rows,
                    (select count(*) from {{ model_rel }}) as dbt_rows,
                    (select count(*) from diffs where parity_diff = 'missing_in_dbt') as missing_rows,
                    (select count(*) from diffs where parity_diff = 'extra_in_dbt') as extra_rows
            {%- endset -%}
            {%- set row = run_query(sql).rows[0] -%}
            {%- set ok = (row[2] | int == 0) and (row[3] | int == 0) and (row[0] | int == row[1] | int) -%}
            {%- if ok -%}{%- do passed.append(1) -%}{%- endif -%}
            {%- do lines.append('%-42s %-28s %8s %8s %8s %8s  %s' | format(check.workflow, check.model, row[0], row[1], row[2], row[3], 'PASS' if ok else 'FAIL')) -%}
        {%- endif -%}
    {%- endfor -%}

    {%- do lines.append('-' * 108) -%}
    {%- do lines.append('%d of %d legacy workflows at parity' | format(passed | length, checks | length)) -%}
    {%- do log(lines | join('\n'), info=true) -%}

{% endmacro %}
