-- Migrated from legacy/stored_procedures/sp_load_customer_ltv.sql
-- Grain: one row per order line

with

order_lines as (

    select * from {{ ref('stg_shop__order_lines') }}

),

orders as (

    select * from {{ ref('stg_shop__orders') }}

),

customers as (

    select * from {{ ref('stg_shop__customers') }}

),

products as (

    select * from {{ ref('stg_shop__products') }}

),

fx_rates as (

    select * from {{ ref('stg_shop__fx_rates') }}

),

joined as (

    select
        order_lines.order_line_id,
        orders.order_id,
        orders.customer_id,
        order_lines.product_id,
        orders.order_date,
        orders.order_status,
        orders.channel,
        orders.currency_code,
        order_lines.quantity,
        order_lines.unit_price,
        order_lines.discount_pct,
        order_lines.quantity * order_lines.unit_price as line_gross_amount,
        round(
            order_lines.quantity * order_lines.unit_price * order_lines.discount_pct,
            2
        ) as line_discount_amount,
        coalesce(fx_rates.usd_per_unit, 1) as usd_rate,
        orders.order_status in ('COMPLETED', 'SHIPPED', 'RETURNED') as is_valid_order,
        coalesce(customers.is_test_account, false) as is_test_customer,
        products.product_id is not null as has_known_product

    from order_lines
    inner join orders
        on order_lines.order_id = orders.order_id
    left join customers
        on orders.customer_id = customers.customer_id
    left join products
        on order_lines.product_id = products.product_id
    left join fx_rates
        on orders.currency_code = fx_rates.currency_code
        and date_trunc('month', orders.order_date) = fx_rates.rate_month

),

calculated as (

    select
        joined.*,
        joined.line_gross_amount - joined.line_discount_amount as line_net_amount,
        round(joined.line_gross_amount * joined.usd_rate, 2) as line_gross_usd,
        round(joined.line_discount_amount * joined.usd_rate, 2) as line_discount_usd,
        round(
            (joined.line_gross_amount - joined.line_discount_amount) * joined.usd_rate,
            2
        ) as line_net_usd

    from joined

),

final as (

    select
        order_line_id,
        order_id,
        customer_id,
        product_id,
        order_date,
        order_status,
        channel,
        currency_code,
        quantity,
        unit_price,
        discount_pct,
        line_gross_amount,
        line_discount_amount,
        line_net_amount,
        usd_rate,
        line_gross_usd,
        line_discount_usd,
        line_net_usd,
        is_valid_order,
        is_test_customer,
        has_known_product

    from calculated

)

select * from final
