-- Migrated from Talend job J_Product_Returns_Analysis
-- Grain: one row per product with at least one sold line on a valid, non-test order.

with

valid_returns as (

    select * from {{ ref('int_returns__usd') }}
    where is_valid_order
        and not is_test_customer

),

valid_lines as (

    select * from {{ ref('int_order_lines__usd') }}
    where is_valid_order
        and not is_test_customer

),

products as (

    select * from {{ ref('stg_shop__products') }}

),

line_returns as (

    select
        order_line_id,
        sum(return_qty) as line_return_qty,
        sum(refund_usd) as line_refund_usd

    from valid_returns
    group by order_line_id

),

top_reason as (

    select
        product_id,
        reason_code

    from valid_returns
    group by product_id, reason_code
    qualify row_number() over (
        partition by product_id
        order by sum(return_qty) desc, reason_code asc
    ) = 1

),

product_totals as (

    select
        products.product_id,
        products.sku,
        products.product_name,
        products.product_category as category,
        sum(valid_lines.quantity) as units_sold,
        -- TKT-4471: returned units capped at sold units per line; refunds are not capped
        sum(least(coalesce(line_returns.line_return_qty, 0), valid_lines.quantity)) as units_returned,
        sum(coalesce(line_returns.line_refund_usd, 0)) as refund_amount_usd

    from valid_lines
    inner join products
        on valid_lines.product_id = products.product_id
    left join line_returns
        on valid_lines.order_line_id = line_returns.order_line_id
    group by
        products.product_id,
        products.sku,
        products.product_name,
        products.product_category

),

rated as (

    select
        *,
        case
            when units_sold > 0 then round(units_returned / units_sold, 4)
            else 0
        end as return_rate

    from product_totals

),

final as (

    select
        rated.product_id,
        rated.sku,
        rated.product_name,
        rated.category,
        rated.units_sold,
        rated.units_returned,
        rated.return_rate,
        rated.refund_amount_usd,
        case
            when top_reason.reason_code is null then 'NONE'
            when top_reason.reason_code = 'DMG' then 'Damaged'
            when top_reason.reason_code = 'SIZE' then 'Wrong Size'
            when top_reason.reason_code = 'DESC' then 'Not As Described'
            when top_reason.reason_code = 'MIND' then 'Changed Mind'
            else 'Other'
        end as top_return_reason,
        case
            when rated.units_sold >= 10 and rated.return_rate >= 0.15 then 'HIGH'
            when rated.return_rate >= 0.08 then 'WATCH'
            else 'NORMAL'
        end as return_flag

    from rated
    left join top_reason
        on rated.product_id = top_reason.product_id

)

select * from final
