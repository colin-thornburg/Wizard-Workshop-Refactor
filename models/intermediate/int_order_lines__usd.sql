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

enriched_order_lines as (

    select
        order_lines.order_line_id,
        order_lines.order_id,
        orders.customer_id,
        order_lines.product_id,
        orders.order_date,
        orders.order_status,
        orders.channel,
        orders.currency_code,
        order_lines.quantity,
        order_lines.unit_price,
        order_lines.discount_pct,
        coalesce(fx_rates.usd_per_unit, 1) as usd_rate,
        coalesce(orders.is_valid_order, false) as is_valid_order,
        coalesce(orders.is_test_customer, false) as is_test_customer,
        products.product_id is not null as has_known_product

    from order_lines
    left join orders
        on order_lines.order_id = orders.order_id
    left join products
        on order_lines.product_id = products.product_id
    left join fx_rates
        on orders.currency_code = fx_rates.currency_code
        and date_trunc('month', orders.order_date) = fx_rates.rate_month

),

line_amounts_local as (

    select
        enriched_order_lines.*,
        quantity * unit_price as line_gross_amount,
        round(quantity * unit_price * discount_pct, 2) as line_discount_amount,
        (quantity * unit_price)
            - round(quantity * unit_price * discount_pct, 2) as line_net_amount

    from enriched_order_lines

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
        round(line_gross_amount * usd_rate, 2) as line_gross_usd,
        round(line_discount_amount * usd_rate, 2) as line_discount_usd,
        round(line_net_amount * usd_rate, 2) as line_net_usd,
        is_valid_order,
        is_test_customer,
        has_known_product

    from line_amounts_local

)

select * from final
