-- Migrated from legacy/stored_procedures/sp_load_customer_ltv.sql
-- Grain: one row per non-test customer

with

customers as (

    select * from {{ ref('stg_shop__customers') }}
    where not is_test_account

),

orders as (

    select * from {{ ref('stg_shop__orders') }}
    where order_status in ('COMPLETED', 'SHIPPED', 'RETURNED')
        and order_date <= to_date('{{ var("as_of_date") }}')

),

order_lines as (

    select * from {{ ref('int_order_lines__usd') }}
    where is_valid_order
        and not is_test_customer
        and order_date <= to_date('{{ var("as_of_date") }}')

),

returns as (

    select * from {{ ref('int_returns__usd') }}
    where is_valid_order
        and not is_test_customer
        and order_date <= to_date('{{ var("as_of_date") }}')

),

order_stats as (

    select
        orders.customer_id,
        count(distinct orders.order_id) as total_orders,
        min(orders.order_date) as first_order_date,
        max(orders.order_date) as last_order_date

    from orders
    inner join customers
        on orders.customer_id = customers.customer_id
    group by orders.customer_id

),

revenue as (

    select
        order_lines.customer_id,
        sum(order_lines.line_net_usd) as product_revenue_usd

    from order_lines
    group by order_lines.customer_id

),

refunds as (

    select
        returns.customer_id,
        sum(returns.refund_usd) as refunds_usd

    from returns
    group by returns.customer_id

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

customer_metrics as (

    select
        customer_rollup.*,
        customer_rollup.product_revenue_usd - customer_rollup.refunds_usd as net_revenue_usd,
        case
            when customer_rollup.total_orders = 0 then 0
            else round(customer_rollup.product_revenue_usd / customer_rollup.total_orders, 2)
        end as avg_order_value_usd,
        datediff(
            'day',
            customer_rollup.last_order_date,
            to_date('{{ var("as_of_date") }}')
        ) as days_since_last_order

    from customer_rollup

),

segmented as (

    select
        customer_metrics.*,
        case
            when customer_metrics.loyalty_tier = 'PLATINUM'
                and customer_metrics.total_orders > 0
                then 'VIP'
            when customer_metrics.days_since_last_order > 180
                and customer_metrics.net_revenue_usd >= 500.00
                then 'AT_RISK'
            when customer_metrics.total_orders = 0 then 'PROSPECT'
            when customer_metrics.net_revenue_usd >= 2000.00 then 'HIGH_VALUE'
            when customer_metrics.net_revenue_usd >= 500.00 then 'MID_VALUE'
            else 'LOW_VALUE'
        end as customer_segment

    from customer_metrics

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
        customer_segment

    from segmented

)

select * from final
