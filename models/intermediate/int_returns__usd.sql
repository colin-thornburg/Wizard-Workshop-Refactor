-- Migrated from legacy/stored_procedures/sp_load_customer_ltv.sql
-- Extended for legacy/talend/J_Product_Returns_Analysis_0.1.item
-- Grain: one row per return

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
        order_lines.customer_id,
        order_lines.product_id,
        order_lines.order_date,
        returns.return_date,
        returns.return_qty,
        returns.reason_code,
        returns.refund_amount,
        coalesce(order_lines.usd_rate, 1) as usd_rate,
        round(returns.refund_amount * coalesce(order_lines.usd_rate, 1), 2) as refund_usd,
        coalesce(order_lines.is_valid_order, false) as is_valid_order,
        coalesce(order_lines.is_test_customer, false) as is_test_customer,
        coalesce(order_lines.has_known_customer, false) as has_known_customer,
        coalesce(order_lines.has_known_product, false) as has_known_product

    from returns
    left join order_lines
        on returns.order_line_id = order_lines.order_line_id

)

select * from final
