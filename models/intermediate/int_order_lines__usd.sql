-- Migrated from legacy/stored_procedures/sp_load_customer_ltv.sql
-- Extended for legacy/informatica/m_LOAD_DAILY_SALES_SUMMARY.xml
-- Extended for legacy/talend/J_Product_Returns_Analysis_0.1.item
-- Extended for legacy/alteryx/Payment_Reconciliation.yxmd
-- Grain: one row per order line

with

order_lines as (

    select * from {{ ref('stg_shop__order_lines') }}

),

orders as (

    select * from {{ ref('int_orders__enriched') }}

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
        order_lines.order_id,
        orders.customer_id,
        order_lines.product_id,
        products.sku,
        products.product_name,
        products.category as product_category,
        products.unit_cost,
        orders.order_date,
        orders.order_status,
        orders.channel,
        orders.currency_code,
        orders.rate_month,
        orders.shipping_cost,
        order_lines.quantity,
        order_lines.unit_price,
        order_lines.discount_pct,
        coalesce(fx_rates.usd_per_unit, 1) as usd_rate,
        order_lines.quantity * order_lines.unit_price as line_gross_amount,
        round(order_lines.quantity * order_lines.unit_price * order_lines.discount_pct, 2) as line_discount_amount,
        coalesce(orders.is_valid_order, false) as is_valid_order,
        coalesce(orders.is_test_customer, false) as is_test_customer,
        coalesce(orders.has_known_customer, false) as has_known_customer,
        products.product_id is not null as has_known_product

    from order_lines
    left join orders
        on order_lines.order_id = orders.order_id
    left join products
        on order_lines.product_id = products.product_id
    left join fx_rates
        on orders.currency_code = fx_rates.currency_code
        and orders.rate_month = fx_rates.rate_month

),

calculated as (

    select
        joined.*,
        joined.line_gross_amount - joined.line_discount_amount as line_net_amount,
        round(joined.line_gross_amount * joined.usd_rate, 2) as line_gross_usd,
        round(joined.line_discount_amount * joined.usd_rate, 2) as line_discount_usd,
        round((joined.line_gross_amount - joined.line_discount_amount) * joined.usd_rate, 2) as line_net_usd,
        joined.quantity * coalesce(joined.unit_cost, 0) as line_cogs_usd

    from joined

),

final as (

    select
        order_line_id,
        order_id,
        customer_id,
        product_id,
        sku,
        product_name,
        product_category,
        unit_cost,
        order_date,
        order_status,
        channel,
        currency_code,
        rate_month,
        shipping_cost,
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
        line_cogs_usd,
        is_valid_order,
        is_test_customer,
        has_known_customer,
        has_known_product

    from calculated

)

select * from final
