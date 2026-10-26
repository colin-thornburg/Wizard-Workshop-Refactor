-- Migrated from legacy/alteryx/Payment_Reconciliation.yxmd
-- Grain: one row per order id appearing in eligible orders or payment activity

with

order_lines as (

    select * from {{ ref('int_order_lines__usd') }}
    where order_status <> 'CANCELLED'

),

payments as (

    select * from {{ ref('stg_shop__payments') }}

),

order_amounts as (

    select
        order_id,
        customer_id,
        order_date,
        order_status,
        currency_code,
        shipping_cost,
        sum(line_net_amount) as items_net

    from order_lines
    group by
        order_id,
        customer_id,
        order_date,
        order_status,
        currency_code,
        shipping_cost

),

orders_with_expected_amount as (

    select
        order_id,
        customer_id,
        order_date,
        order_status,
        currency_code,
        round(items_net + shipping_cost, 2) as expected_amount

    from order_amounts

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

reconciled as (

    select
        coalesce(orders_with_expected_amount.order_id, payment_summary.order_id) as order_id,
        orders_with_expected_amount.customer_id,
        orders_with_expected_amount.order_date,
        orders_with_expected_amount.order_status,
        orders_with_expected_amount.currency_code,
        orders_with_expected_amount.expected_amount,
        coalesce(payment_summary.captured_amount, 0) as captured_amount,
        case
            when orders_with_expected_amount.order_id is null then payment_summary.captured_amount
            else round(coalesce(payment_summary.captured_amount, 0) - orders_with_expected_amount.expected_amount, 2)
        end as variance_amount,
        coalesce(payment_summary.captured_payment_count, 0) as captured_payment_count,
        coalesce(payment_summary.failed_payment_count, 0) as failed_payment_count,
        payment_summary.last_captured_date,
        case
            when payment_summary.last_captured_date is null then null
            else datediff('day', orders_with_expected_amount.order_date, payment_summary.last_captured_date)
        end as days_to_payment,
        orders_with_expected_amount.order_id is not null as has_order

    from orders_with_expected_amount
    full outer join payment_summary
        on orders_with_expected_amount.order_id = payment_summary.order_id

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
        variance_amount,
        captured_payment_count,
        failed_payment_count,
        last_captured_date,
        days_to_payment,
        case
            when not has_order then 'UNMATCHED_PAYMENT'
            when captured_payment_count = 0 then 'NO_PAYMENT'
            when abs(variance_amount) <= 0.01 then 'MATCHED'
            when variance_amount < 0 then 'UNDERPAID'
            else 'OVERPAID'
        end as reconciliation_status

    from reconciled

)

select * from final
