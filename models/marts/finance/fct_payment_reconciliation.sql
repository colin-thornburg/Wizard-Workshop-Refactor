-- Migrated from Alteryx workflow Payment_Reconciliation.yxmd
-- Grain: one row per non-cancelled order, plus one row per order_id that has payments but no
-- non-cancelled order (UNMATCHED_PAYMENT). Test accounts are intentionally included (Finance).

with

orders as (

    select * from {{ ref('stg_shop__orders') }}
    where order_status <> 'CANCELLED'

),

order_lines as (

    select * from {{ ref('int_order_lines__usd') }}

),

payments as (

    select * from {{ ref('stg_shop__payments') }}

),

order_totals as (

    select
        order_id,
        sum(line_net_amount) as items_net_amount

    from order_lines
    group by order_id

),

orders_expected as (

    select
        orders.order_id,
        orders.customer_id,
        orders.order_date,
        orders.order_status,
        orders.currency_code,
        round(order_totals.items_net_amount + orders.shipping_cost, 2) as expected_amount

    from orders
    inner join order_totals
        on orders.order_id = order_totals.order_id

),

payment_summary as (

    select
        order_id,
        sum(case when payment_status = 'CAPTURED' then amount else 0 end) as captured_amount,
        sum(case when payment_status = 'CAPTURED' then 1 else 0 end) as captured_payment_count,
        sum(case when payment_status = 'FAILED' then 1 else 0 end) as failed_payment_count,
        max(case when payment_status = 'CAPTURED' then payment_date end) as last_captured_date

    from payments
    group by order_id

),

joined as (

    select
        coalesce(orders_expected.order_id, payment_summary.order_id) as order_id,
        orders_expected.customer_id,
        orders_expected.order_date,
        orders_expected.order_status,
        orders_expected.currency_code,
        orders_expected.expected_amount,
        coalesce(payment_summary.captured_amount, 0) as captured_amount,
        coalesce(payment_summary.captured_payment_count, 0) as captured_payment_count,
        coalesce(payment_summary.failed_payment_count, 0) as failed_payment_count,
        payment_summary.last_captured_date,
        orders_expected.order_id is null as is_unmatched_payment

    from orders_expected
    full outer join payment_summary
        on orders_expected.order_id = payment_summary.order_id

),

final as (

    select
        order_id,
        customer_id,
        order_date,
        order_status,
        currency_code,
        expected_amount,
        captured_amount,
        case
            when is_unmatched_payment then captured_amount
            else round(captured_amount - expected_amount, 2)
        end as variance_amount,
        captured_payment_count,
        failed_payment_count,
        last_captured_date,
        {{ dbt.datediff('order_date', 'last_captured_date', 'day') }} as days_to_payment,
        case
            when is_unmatched_payment then 'UNMATCHED_PAYMENT'
            when captured_payment_count = 0 then 'NO_PAYMENT'
            when abs(captured_amount - expected_amount) <= 0.01 then 'MATCHED'
            when captured_amount < expected_amount then 'UNDERPAID'
            else 'OVERPAID'
        end as reconciliation_status

    from joined

)

select * from final
