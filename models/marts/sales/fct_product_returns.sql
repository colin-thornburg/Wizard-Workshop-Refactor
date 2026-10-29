-- Migrated from legacy/talend/J_Product_Returns_Analysis_0.1.item
-- Grain: one row per product with at least one valid non-test sales line

with

sales_lines as (

    select * from {{ ref('int_order_lines__usd') }}
    where is_valid_order
        and not is_test_customer
        and has_known_customer
        and has_known_product

),

eligible_returns as (

    select * from {{ ref('int_returns__usd') }}
    where is_valid_order
        and not is_test_customer
        and has_known_customer

),

returns_by_line as (

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

returns_by_reason as (

    select
        product_id,
        reason_code,
        sum(return_qty) as reason_qty

    from eligible_returns
    group by
        product_id,
        reason_code

),

ranked_return_reasons as (

    select
        product_id,
        reason_code,
        reason_qty,
        row_number() over (
            partition by product_id
            order by reason_qty desc, reason_code asc
        ) as reason_rank

    from returns_by_reason

),

top_return_reasons as (

    select
        product_id,
        reason_code

    from ranked_return_reasons
    where reason_rank = 1

),

sales_with_returns as (

    select
        sales_lines.product_id,
        sales_lines.product_sku as sku,
        sales_lines.product_name,
        sales_lines.product_category as category,
        sales_lines.quantity,
        least(
            coalesce(returns_by_line.line_return_qty, 0),
            sales_lines.quantity
        ) as capped_returned_qty,
        coalesce(returns_by_line.line_refund_usd, 0) as line_refund_usd

    from sales_lines
    left join returns_by_line
        on sales_lines.order_line_id = returns_by_line.order_line_id

),

product_totals as (

    select
        product_id,
        sku,
        product_name,
        category,
        sum(quantity) as units_sold,
        sum(capped_returned_qty) as units_returned,
        sum(line_refund_usd) as refund_amount_usd

    from sales_with_returns
    group by
        product_id,
        sku,
        product_name,
        category

),

product_metrics as (

    select
        product_totals.product_id,
        product_totals.sku,
        product_totals.product_name,
        product_totals.category,
        product_totals.units_sold,
        product_totals.units_returned,
        case
            when product_totals.units_sold > 0
                then round(product_totals.units_returned / product_totals.units_sold, 4)
            else 0
        end as return_rate,
        round(product_totals.refund_amount_usd, 2) as refund_amount_usd,
        top_return_reasons.reason_code

    from product_totals
    left join top_return_reasons
        on product_totals.product_id = top_return_reasons.product_id

),

final as (

    select
        product_id,
        sku,
        product_name,
        category,
        units_sold,
        units_returned,
        return_rate,
        refund_amount_usd,
        case
            when reason_code is null then 'NONE'
            when reason_code = 'DMG' then 'Damaged'
            when reason_code = 'SIZE' then 'Wrong Size'
            when reason_code = 'DESC' then 'Not As Described'
            when reason_code = 'MIND' then 'Changed Mind'
            else 'Other'
        end as top_return_reason,
        case
            when units_sold >= 10 and return_rate >= 0.15 then 'HIGH'
            when return_rate >= 0.08 then 'WATCH'
            else 'NORMAL'
        end as return_flag

    from product_metrics

)

select * from final
