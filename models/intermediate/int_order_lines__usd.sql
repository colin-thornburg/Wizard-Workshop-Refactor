-- Migrated from legacy/stored_procedures/sp_load_customer_ltv.sql
-- Grain: one row per order line

with

order_lines as (

    select * from {{ ref('stg_shop__order_lines') }}

),

orders as (

    select * from {{ ref('int_orders__customer_flags') }}

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
        round(order_lines.quantity * order_lines.unit_price * order_lines.discount_pct, 2) as line_discount_amount,
        coalesce(fx_rates.usd_per_unit, 1) as usd_rate,
        orders.is_valid_order,
        orders.is_test_customer,
        orders.has_known_customer,
        products.product_id is not null as has_known_product

    from order_lines
    inner join orders
        on order_lines.order_id = orders.order_id
    left join products
        on order_lines.product_id = products.product_id
    left join fx_rates
        on orders.currency_code = fx_rates.currency_code
        and date_trunc('month', orders.order_date) = fx_rates.rate_month

),

calculated as (

    select
        joined.*,
        joined.line_gross_amount - joined.line_discount_amount as line_net_amount

    from joined

),

final as (

    select
        calculated.order_line_id,
        calculated.order_id,
        calculated.customer_id,
        calculated.product_id,
        calculated.order_date,
        calculated.order_status,
        calculated.channel,
        calculated.currency_code,
        calculated.quantity,
        calculated.unit_price,
        calculated.discount_pct,
        calculated.line_gross_amount,
        calculated.line_discount_amount,
        calculated.line_net_amount,
        calculated.usd_rate,
        round(calculated.line_gross_amount * calculated.usd_rate, 2) as line_gross_usd,
        round(calculated.line_discount_amount * calculated.usd_rate, 2) as line_discount_usd,
        round(calculated.line_net_amount * calculated.usd_rate, 2) as line_net_usd,
        calculated.is_valid_order,
        calculated.is_test_customer,
        calculated.has_known_customer,
        calculated.has_known_product

    from calculated

)

select * from final
