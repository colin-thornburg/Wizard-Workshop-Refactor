-- Migrated from legacy/stored_procedures/sp_load_customer_ltv.sql
-- Grain: one row per eligible customer

with

customers as (

    select * from {{ ref('stg_shop__customers') }}
    where coalesce(is_test_account, 'N') <> 'Y'

),

orders as (

    select * from {{ ref('stg_shop__orders') }}
    where order_status in ('COMPLETED', 'SHIPPED', 'RETURNED')
        and order_date <= cast('{{ var("as_of_date") }}' as date)

),

order_lines as (

    select * from {{ ref('stg_shop__order_lines') }}

),

returns as (

    select * from {{ ref('stg_shop__returns') }}

),

fx_rates as (

    select * from {{ ref('stg_shop__fx_rates') }}

),

valid_orders as (

    select
        orders.order_id,
        orders.customer_id,
        orders.order_date,
        orders.currency_code,
        date_trunc('month', orders.order_date) as rate_month

    from orders
    inner join customers
        on orders.customer_id = customers.customer_id

),

line_revenue as (

    select
        order_lines.order_line_id,
        valid_orders.order_id,
        valid_orders.customer_id,
        coalesce(fx_rates.usd_per_unit, 1) as usd_rate,
        (order_lines.quantity * order_lines.unit_price)
            - round(
                order_lines.quantity * order_lines.unit_price * order_lines.discount_pct,
                2
            ) as line_net_local,
        round(
            (
                (order_lines.quantity * order_lines.unit_price)
                - round(
                    order_lines.quantity * order_lines.unit_price * order_lines.discount_pct,
                    2
                )
            ) * coalesce(fx_rates.usd_per_unit, 1),
            2
        ) as line_net_usd

    from order_lines
    inner join valid_orders
        on order_lines.order_id = valid_orders.order_id
    left join fx_rates
        on valid_orders.currency_code = fx_rates.currency_code
        and valid_orders.rate_month = fx_rates.rate_month

),

refunds_by_customer as (

    select
        line_revenue.customer_id,
        sum(round(returns.refund_amount * line_revenue.usd_rate, 2)) as refunds_usd

    from returns
    inner join line_revenue
        on returns.order_line_id = line_revenue.order_line_id
    group by line_revenue.customer_id

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

revenue_by_customer as (

    select
        customer_id,
        sum(line_net_usd) as product_revenue_usd

    from line_revenue
    group by customer_id

),

final as (

    select
        customers.customer_id,
        customers.first_name || ' ' || customers.last_name as customer_name,
        customers.email,
        customers.state,
        coalesce(nullif(customers.loyalty_tier, ''), 'NONE') as loyalty_tier,
        order_stats.first_order_date,
        order_stats.last_order_date,
        coalesce(order_stats.total_orders, 0) as total_orders,
        coalesce(revenue_by_customer.product_revenue_usd, 0) as product_revenue_usd,
        coalesce(refunds_by_customer.refunds_usd, 0) as refunds_usd

    from customers
    left join order_stats
        on customers.customer_id = order_stats.customer_id
    left join revenue_by_customer
        on customers.customer_id = revenue_by_customer.customer_id
    left join refunds_by_customer
        on customers.customer_id = refunds_by_customer.customer_id

)

select * from final
