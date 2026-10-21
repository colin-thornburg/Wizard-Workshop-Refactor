-- One row per return event, converted to USD at the ORDER month rate (legacy CR-1188).

with

returns as (

    select * from {{ ref('stg_shop__returns') }}

),

order_lines as (

    select * from {{ ref('int_order_lines__usd') }}

),

final as (

    select
        returns.return_id,
        returns.order_line_id,
        order_lines.order_id,
        order_lines.product_id,
        order_lines.customer_id,
        order_lines.order_date,
        returns.return_date,
        returns.return_qty,
        returns.reason_code,
        returns.refund_amount,
        round(returns.refund_amount * order_lines.usd_rate, 2) as refund_usd,
        order_lines.is_valid_order,
        order_lines.is_test_customer

    from returns
    inner join order_lines
        on returns.order_line_id = order_lines.order_line_id

)

select * from final
