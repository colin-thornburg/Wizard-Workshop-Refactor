-- Migrated from legacy/talend/J_Product_Returns_Analysis_0.1.item
-- Grain: one row per product sold on an eligible order

with

returns as (

    select * from {{ ref('stg_shop__returns') }}

),

order_lines as (

    select * from {{ ref('stg_shop__order_lines') }}

),

orders as (

    select * from {{ ref('stg_shop__orders') }}
    where order_status in ('COMPLETED', 'SHIPPED', 'RETURNED')

),

customers as (

    select * from {{ ref('stg_shop__customers') }}
    where coalesce(is_test_account, 'N') <> 'Y'

),

products as (

    select * from {{ ref('stg_shop__products') }}

),

fx_rates as (

    select * from {{ ref('stg_shop__fx_rates') }}

),

eligible_returns as (

    select
        returns.order_line_id,
        order_lines.product_id,
        upper(trim(returns.reason_code)) as reason_code,
        returns.return_qty,
        round(
            returns.refund_amount * coalesce(fx_rates.usd_per_unit, 1),
            2
        ) as refund_usd

    from returns
    inner join order_lines
        on returns.order_line_id = order_lines.order_line_id
    inner join orders
        on order_lines.order_id = orders.order_id
    inner join customers
        on orders.customer_id = customers.customer_id
    left join fx_rates
        on orders.currency_code = fx_rates.currency_code
        and date_trunc('month', orders.order_date) = fx_rates.rate_month

),

line_returns as (

    select
        order_line_id,
        product_id,
        sum(return_qty) as line_return_qty,
        sum(refund_usd) as line_refund_usd

    from eligible_returns
    group by
        order_line_id,
        product_id

),

return_reasons as (

    select
        product_id,
        reason_code,
        sum(return_qty) as reason_qty

    from eligible_returns
    group by
        product_id,
        reason_code

),

top_return_reasons as (

    select
        product_id,
        reason_code

    from return_reasons
    qualify row_number() over (
        partition by product_id
        order by
            reason_qty desc,
            reason_code asc
    ) = 1

),

eligible_sales_lines as (

    select
        products.product_id,
        products.sku,
        products.product_name,
        products.category,
        order_lines.quantity,
        case
            when line_returns.line_return_qty is null then 0
            else least(line_returns.line_return_qty, order_lines.quantity)
        end as capped_returned_qty,
        coalesce(line_returns.line_refund_usd, 0) as line_refund_usd

    from order_lines
    inner join orders
        on order_lines.order_id = orders.order_id
    inner join customers
        on orders.customer_id = customers.customer_id
    inner join products
        on order_lines.product_id = products.product_id
    left join line_returns
        on order_lines.order_line_id = line_returns.order_line_id

),

product_returns as (

    select
        product_id,
        sku,
        product_name,
        category,
        sum(quantity) as units_sold,
        sum(capped_returned_qty) as units_returned,
        round(sum(line_refund_usd), 2) as refund_amount_usd

    from eligible_sales_lines
    group by
        product_id,
        sku,
        product_name,
        category

),

calculated as (

    select
        product_returns.product_id,
        product_returns.sku,
        product_returns.product_name,
        product_returns.category,
        product_returns.units_sold,
        product_returns.units_returned,
        case
            when product_returns.units_sold > 0
                then round(
                    product_returns.units_returned / product_returns.units_sold,
                    4
                )
            else 0.0000
        end as return_rate,
        product_returns.refund_amount_usd,
        top_return_reasons.reason_code

    from product_returns
    left join top_return_reasons
        on product_returns.product_id = top_return_reasons.product_id

),

final as (

    select
        calculated.product_id,
        calculated.sku,
        calculated.product_name,
        calculated.category,
        calculated.units_sold,
        calculated.units_returned,
        calculated.return_rate,
        calculated.refund_amount_usd,
        case
            when calculated.reason_code is null then 'NONE'
            when calculated.reason_code = 'DMG' then 'Damaged'
            when calculated.reason_code = 'SIZE' then 'Wrong Size'
            when calculated.reason_code = 'DESC' then 'Not As Described'
            when calculated.reason_code = 'MIND' then 'Changed Mind'
            else 'Other'
        end as top_return_reason,
        case
            when calculated.units_sold >= 10
                and calculated.return_rate >= 0.15 then 'HIGH'
            when calculated.return_rate >= 0.08 then 'WATCH'
            else 'NORMAL'
        end as return_flag

    from calculated

)

select * from final
