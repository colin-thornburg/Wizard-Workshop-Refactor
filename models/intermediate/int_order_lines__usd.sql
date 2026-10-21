-- Migrated from legacy/informatica/m_LOAD_DAILY_SALES_SUMMARY.xml
-- Grain: one row per order line

with

orders as (

    select * from {{ ref('stg_shop__orders') }}

),

order_lines as (

    select * from {{ ref('stg_shop__order_lines') }}

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
        order_lines.order_id,
        orders.customer_id,
        order_lines.product_id,
        products.product_id as matched_product_id,
        orders.order_date,
        orders.order_status,
        orders.channel,
        orders.currency_code,
        orders.shipping_cost,
        order_lines.quantity,
        order_lines.unit_price,
        order_lines.discount_pct,
        customers.is_test_account,
        products.category,
        products.unit_cost,
        coalesce(fx_rates.usd_per_unit, 1) as usd_rate

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

normalized as (

    select
        joined.order_line_id,
        joined.order_id,
        joined.customer_id,
        joined.product_id,
        joined.order_date,
        joined.order_status,
        joined.channel,
        joined.currency_code,
        joined.shipping_cost,
        joined.quantity,
        joined.unit_price,
        joined.discount_pct,
        joined.unit_cost,
        joined.usd_rate,
        case
            when upper(trim(joined.channel)) in ('WEB', 'APP') then 'ONLINE'
            when upper(trim(joined.channel)) = 'STORE' then 'RETAIL'
            when upper(trim(joined.channel)) = 'MARKETPLACE' then 'MARKETPLACE'
            else 'OTHER'
        end as channel_group,
        coalesce(joined.category, 'UNKNOWN') as product_category,
        joined.order_status in ('COMPLETED', 'SHIPPED', 'RETURNED') as is_valid_order,
        coalesce(upper(trim(joined.is_test_account)), 'N') = 'Y' as is_test_customer,
        joined.matched_product_id is not null as has_known_product,
        joined.quantity * joined.unit_price as line_gross_amount,
        round(joined.quantity * joined.unit_price * joined.discount_pct, 2) as line_discount_amount

    from joined

),

calculated as (

    select
        normalized.order_line_id,
        normalized.order_id,
        normalized.customer_id,
        normalized.product_id,
        normalized.order_date,
        normalized.order_status,
        normalized.channel,
        normalized.currency_code,
        normalized.shipping_cost,
        normalized.quantity,
        normalized.unit_price,
        normalized.discount_pct,
        normalized.unit_cost,
        normalized.usd_rate,
        normalized.channel_group,
        normalized.product_category,
        normalized.is_valid_order,
        normalized.is_test_customer,
        normalized.has_known_product,
        normalized.line_gross_amount,
        normalized.line_discount_amount,
        normalized.line_gross_amount - normalized.line_discount_amount as line_net_amount

    from normalized

),

final as (

    select
        calculated.order_line_id,
        calculated.order_id,
        calculated.customer_id,
        calculated.product_id,
        calculated.order_date,
        calculated.order_status,
        calculated.channel_group,
        calculated.currency_code,
        calculated.quantity,
        calculated.unit_price,
        calculated.discount_pct,
        calculated.product_category,
        calculated.usd_rate,
        round(calculated.line_gross_amount * calculated.usd_rate, 2) as line_gross_usd,
        round(calculated.line_discount_amount * calculated.usd_rate, 2) as line_discount_usd,
        round(calculated.line_net_amount * calculated.usd_rate, 2) as line_net_usd,
        calculated.quantity * coalesce(calculated.unit_cost, 0) as line_cogs_usd,
        calculated.channel,
        calculated.shipping_cost,
        calculated.line_gross_amount,
        calculated.line_discount_amount,
        calculated.line_net_amount,
        calculated.is_valid_order,
        calculated.is_test_customer,
        calculated.has_known_product

    from calculated

)

select * from final
