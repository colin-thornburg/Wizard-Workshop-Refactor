-- Migrated from legacy/stored_procedures/sp_load_customer_ltv.sql
-- Grain: one row per eligible customer

with

customer_rollup as (

    select * from {{ ref('int_customer_ltv__rollup') }}

),

customer_metrics as (

    select
        customer_rollup.customer_id,
        customer_rollup.customer_name,
        customer_rollup.email,
        customer_rollup.state,
        customer_rollup.loyalty_tier,
        customer_rollup.first_order_date,
        customer_rollup.last_order_date,
        customer_rollup.total_orders,
        customer_rollup.product_revenue_usd,
        customer_rollup.refunds_usd,
        customer_rollup.product_revenue_usd - customer_rollup.refunds_usd as net_revenue_usd,
        case
            when customer_rollup.total_orders = 0 then 0
            else round(customer_rollup.product_revenue_usd / customer_rollup.total_orders, 2)
        end as avg_order_value_usd,
        datediff(
            'day',
            customer_rollup.last_order_date,
            cast('{{ var("as_of_date") }}' as date)
        ) as days_since_last_order

    from customer_rollup

),

base_segments as (

    select
        customer_metrics.*,
        case
            when customer_metrics.total_orders = 0 then 'PROSPECT'
            when customer_metrics.net_revenue_usd >= 2000.00 then 'HIGH_VALUE'
            when customer_metrics.net_revenue_usd >= 500.00 then 'MID_VALUE'
            else 'LOW_VALUE'
        end as customer_segment

    from customer_metrics

),

at_risk_segments as (

    select
        base_segments.* exclude customer_segment,
        case
            when base_segments.days_since_last_order > 180
                and base_segments.customer_segment in ('HIGH_VALUE', 'MID_VALUE')
                then 'AT_RISK'
            else base_segments.customer_segment
        end as customer_segment

    from base_segments

),

final as (

    select
        at_risk_segments.customer_id,
        at_risk_segments.customer_name,
        at_risk_segments.email,
        at_risk_segments.state,
        at_risk_segments.loyalty_tier,
        at_risk_segments.first_order_date,
        at_risk_segments.last_order_date,
        at_risk_segments.total_orders,
        at_risk_segments.product_revenue_usd,
        at_risk_segments.refunds_usd,
        at_risk_segments.net_revenue_usd,
        at_risk_segments.avg_order_value_usd,
        at_risk_segments.days_since_last_order,
        case
            when at_risk_segments.loyalty_tier = 'PLATINUM'
                and at_risk_segments.total_orders > 0
                then 'VIP'
            else at_risk_segments.customer_segment
        end as customer_segment

    from at_risk_segments

)

select * from final
