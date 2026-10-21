-- One row per order line with local and USD amounts plus order-level eligibility flags.
-- Money rules (shared by every legacy workflow):
--   discount is rounded to 2 dp per line before conversion; USD amounts are rounded per line;
--   FX is the order-month rate; USD (no FX row) converts at 1.

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

fx_rates as (

    select * from {{ ref('stg_shop__fx_rates') }}

),

line_amounts as (

    select
        order_lines.order_line_id,
        order_lines.order_id,
        order_lines.product_id,
        orders.customer_id,
        orders.order_date,
        orders.order_status,
        orders.channel,
        orders.currency_code,
        order_lines.quantity,
        order_lines.quantity * order_lines.unit_price as line_gross_amount,
        round(order_lines.quantity * order_lines.unit_price * order_lines.discount_pct, 2) as line_discount_amount,
        coalesce(fx_rates.usd_per_unit, 1) as usd_rate,
        orders.order_status in ('COMPLETED', 'SHIPPED', 'RETURNED') as is_valid_order,
        coalesce(customers.is_test_account, false) as is_test_customer

    from order_lines
    inner join orders
        on order_lines.order_id = orders.order_id
    left join customers
        on orders.customer_id = customers.customer_id
    left join fx_rates
        on orders.currency_code = fx_rates.currency_code
        and {{ dbt.date_trunc('month', 'orders.order_date') }} = fx_rates.rate_month

),

final as (

    select
        order_line_id,
        order_id,
        product_id,
        customer_id,
        order_date,
        order_status,
        channel,
        currency_code,
        quantity,
        line_gross_amount,
        line_discount_amount,
        line_gross_amount - line_discount_amount as line_net_amount,
        usd_rate,
        round(line_gross_amount * usd_rate, 2) as line_gross_usd,
        round(line_discount_amount * usd_rate, 2) as line_discount_usd,
        round((line_gross_amount - line_discount_amount) * usd_rate, 2) as line_net_usd,
        is_valid_order,
        is_test_customer

    from line_amounts

)

select * from final
