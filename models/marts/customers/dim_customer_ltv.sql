-- Migrated from stored procedure ANALYTICS.LEGACY_ETL.SP_LOAD_CUSTOMER_LTV
-- Grain: one row per non-test customer (including customers with no orders).

{% set as_of_date = "cast('" ~ var('as_of_date') ~ "' as date)" %}

with

customers as (

    select * from {{ ref('stg_shop__customers') }}
    where not is_test_account

),

valid_orders as (

    select * from {{ ref('stg_shop__orders') }}
    where order_status in ('COMPLETED', 'SHIPPED', 'RETURNED')
        and order_date <= {{ as_of_date }}

),

valid_lines as (

    select * from {{ ref('int_order_lines__usd') }}
    where is_valid_order
        and not is_test_customer
        and order_date <= {{ as_of_date }}

),

valid_returns as (

    select * from {{ ref('int_returns__usd') }}
    where is_valid_order
        and not is_test_customer
        and order_date <= {{ as_of_date }}

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

    from valid_lines
    group by customer_id

),

refunds as (

    select
        customer_id,
        sum(refund_usd) as refunds_usd

    from valid_returns
    group by customer_id

),

customer_rollup as (

    select
        customers.customer_id,
        customers.customer_name,
        customers.email,
        customers.state,
        customers.loyalty_tier,
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

metrics as (

    select
        *,
        product_revenue_usd - refunds_usd as net_revenue_usd,
        case
            when total_orders = 0 then 0
            else round(product_revenue_usd / total_orders, 2)
        end as avg_order_value_usd,
        {{ dbt.datediff('last_order_date', as_of_date, 'day') }} as days_since_last_order

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
        -- legacy applied these as sequential UPDATEs; precedence: VIP > PROSPECT > AT_RISK > value tiers
        case
            when total_orders > 0 and loyalty_tier = 'PLATINUM' then 'VIP'
            when total_orders = 0 then 'PROSPECT'
            when days_since_last_order > 180 and net_revenue_usd >= 500 then 'AT_RISK'
            when net_revenue_usd >= 2000 then 'HIGH_VALUE'
            when net_revenue_usd >= 500 then 'MID_VALUE'
            else 'LOW_VALUE'
        end as customer_segment

    from metrics

)

select * from final
