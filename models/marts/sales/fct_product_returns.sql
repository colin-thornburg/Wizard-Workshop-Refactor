-- Migrated from legacy/talend/J_Product_Returns_Analysis_0.1.item
-- Grain: one row per known product with qualifying sales

with

order_lines as (

    select * from {{ ref('int_order_lines__usd') }}
    where is_valid_order
        and not is_test_customer
        and has_known_customer
        and has_known_product

),

returns as (

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

    from returns
    group by
        order_line_id,
        product_id

),

returns_by_reason as (

    select
        product_id,
        reason_code,
        sum(return_qty) as reason_qty

    from returns
    group by
        product_id,
        reason_code

),

ranked_reasons as (

    select
        product_id,
        reason_code,
        row_number() over (
            partition by product_id
            order by reason_qty desc, reason_code asc
        ) as reason_rank

    from returns_by_reason

),

top_reasons as (

    select
        product_id,
        reason_code

    from ranked_reasons
    where reason_rank = 1

),

sales_with_returns as (

    select
        order_lines.product_id,
        order_lines.sku,
        order_lines.product_name,
        order_lines.product_category as category,
        order_lines.quantity,
        case
            when returns_by_line.line_return_qty is null then 0
            else least(returns_by_line.line_return_qty, order_lines.quantity)
        end as capped_returned_qty,
        coalesce(returns_by_line.line_refund_usd, 0) as line_refund_usd

    from order_lines
    left join returns_by_line
        on order_lines.order_line_id = returns_by_line.order_line_id

),

product_aggregates as (

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
        product_aggregates.*,
        case
            when product_aggregates.units_sold > 0
                then round(product_aggregates.units_returned / product_aggregates.units_sold, 4)
            else 0.0000
        end as return_rate

    from product_aggregates

),

final as (

    select
        product_metrics.product_id,
        product_metrics.sku,
        product_metrics.product_name,
        product_metrics.category,
        product_metrics.units_sold,
        product_metrics.units_returned,
        product_metrics.return_rate,
        round(product_metrics.refund_amount_usd, 2) as refund_amount_usd,
        case
            when top_reasons.reason_code is null then 'NONE'
            when top_reasons.reason_code = 'DMG' then 'Damaged'
            when top_reasons.reason_code = 'SIZE' then 'Wrong Size'
            when top_reasons.reason_code = 'DESC' then 'Not As Described'
            when top_reasons.reason_code = 'MIND' then 'Changed Mind'
            else 'Other'
        end as top_return_reason,
        case
            when product_metrics.units_sold >= 10 and product_metrics.return_rate >= 0.15 then 'HIGH'
            when product_metrics.return_rate >= 0.08 then 'WATCH'
            else 'NORMAL'
        end as return_flag

    from product_metrics
    left join top_reasons
        on product_metrics.product_id = top_reasons.product_id

)

select * from final
