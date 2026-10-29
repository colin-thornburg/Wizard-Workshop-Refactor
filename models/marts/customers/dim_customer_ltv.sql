-- Migrated from legacy/stored_procedures/sp_load_customer_ltv.sql
-- Grain: one row per non-test customer

with

customers as (

    select * from {{ ref('stg_shop__customers') }}
    where not is_test_account

),

valid_orders as (

    select * from {{ ref('int_orders__customer_flags') }}
    where is_valid_order
        and not is_test_customer
        and order_date <= cast('{{ var("as_of_date") }}' as date)

),

valid_line_revenue as (

    select * from {{ ref('int_order_lines__usd') }}
    where is_valid_order
        and not is_test_customer
        and order_date <= cast('{{ var("as_of_date") }}' as date)

),

valid_refunds as (

    select * from {{ ref('int_returns__usd') }}
    where is_valid_order
        and not is_test_customer
        and order_date <= cast('{{ var("as_of_date") }}' as date)

),

order_stats as (

    select
        customer_id,
        count(distinct order_id) as total_orders,
        min(order_date) as first_order_date,
        max(order_date) as last_order_date

    from valid_orders
    group by customer_id

),

revenue as (

    select
        customer_id,
        sum(line_net_usd) as product_revenue_usd

    from valid_line_revenue
    group by customer_id

),

refunds as (

    select
        customer_id,
        sum(refund_usd) as refunds_usd

    from valid_refunds
    group by customer_id

),

customer_rollup as (

    select
        customers.customer_id,
        customers.first_name || ' ' || customers.last_name as customer_name,
        customers.email,
        customers.state,
        coalesce(customers.loyalty_tier, 'NONE') as loyalty_tier,
        order_stats.first_order_date,
        order_stats.last_order_date,
        coalesce(order_stats.total_orders, 0) as total_orders,
        coalesce(revenue.product_revenue_usd, 0) as product_revenue_usd,
        coalesce(refunds.refunds_usd, 0) as refunds_usd

    from customers
    left join order_stats
        on customers.customer_id = order_stats.customer_id
    left join revenue
        on customers.customer_id = revenue.customer_id
    left join refunds
        on customers.customer_id = refunds.customer_id

),

derived_metrics as (

    select
        customer_rollup.*,
        product_revenue_usd - refunds_usd as net_revenue_usd,
        case
            when total_orders = 0 then 0
            else round(product_revenue_usd / total_orders, 2)
        end as avg_order_value_usd,
        datediff(
            'day',
            last_order_date,
            cast('{{ var("as_of_date") }}' as date)
        ) as days_since_last_order

    from customer_rollup

),

final as (

    select
        customer_id,
        customer_name,
        email,
        state,
        loyalty_tier,
        first_order_date,
        last_order_date,
        total_orders,
        product_revenue_usd,
        refunds_usd,
        net_revenue_usd,
        avg_order_value_usd,
        days_since_last_order,
        case
            when loyalty_tier = 'PLATINUM' and total_orders > 0 then 'VIP'
            when days_since_last_order > 180 and net_revenue_usd >= 500 then 'AT_RISK'
            when total_orders = 0 then 'PROSPECT'
            when net_revenue_usd >= 2000 then 'HIGH_VALUE'
            when net_revenue_usd >= 500 then 'MID_VALUE'
            else 'LOW_VALUE'
        end as customer_segment

    from derived_metrics

)

select * from final
