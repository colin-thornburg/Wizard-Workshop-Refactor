-- Migrated from legacy/alteryx/Payment_Reconciliation.yxmd
-- Grain: one row per order identifier in eligible orders or payment attempts

with

order_lines as (

    select * from {{ ref('int_order_lines__usd') }}
    where is_valid_order

),

payments as (

    select * from {{ ref('stg_shop__payments') }}

),

order_totals as (

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

expected_orders as (

    select
        order_id,
        customer_id,
        order_date,
        order_status,
        currency_code,
        round(items_net + shipping_cost, 2) as expected_amount

    from order_totals

),

payment_summary as (

    select
        order_id,
        sum(
            case
                when payment_status = 'CAPTURED' then amount
                else 0
            end
        ) as captured_amount,
        sum(
            case
                when payment_status = 'CAPTURED' then 1
                else 0
            end
        ) as captured_payment_count,
        sum(
            case
                when payment_status = 'FAILED' then 1
                else 0
            end
        ) as failed_payment_count,
        max(
            case
                when payment_status = 'CAPTURED' then payment_date
            end
        ) as last_captured_date

    from payments
    group by order_id

),

reconciled as (

    select
        coalesce(expected_orders.order_id, payment_summary.order_id) as order_id,
        expected_orders.customer_id,
        expected_orders.order_date,
        expected_orders.order_status,
        expected_orders.currency_code,
        expected_orders.expected_amount,
        coalesce(payment_summary.captured_amount, 0) as captured_amount,
        case
            when expected_orders.order_id is null then payment_summary.captured_amount
            else round(coalesce(payment_summary.captured_amount, 0) - expected_orders.expected_amount, 2)
        end as variance_amount,
        coalesce(payment_summary.captured_payment_count, 0) as captured_payment_count,
        coalesce(payment_summary.failed_payment_count, 0) as failed_payment_count,
        payment_summary.last_captured_date,
        case
            when payment_summary.last_captured_date is null then null
            else datediff('day', expected_orders.order_date, payment_summary.last_captured_date)
        end as days_to_payment,
        case
            when expected_orders.order_id is null then 'UNMATCHED_PAYMENT'
            when payment_summary.order_id is null
                or payment_summary.captured_payment_count = 0 then 'NO_PAYMENT'
            when abs(round(payment_summary.captured_amount - expected_orders.expected_amount, 2)) <= 0.01 then 'MATCHED'
            when round(payment_summary.captured_amount - expected_orders.expected_amount, 2) < 0 then 'UNDERPAID'
            else 'OVERPAID'
        end as reconciliation_status

    from expected_orders
    full outer join payment_summary
        on expected_orders.order_id = payment_summary.order_id

),

final as (

    select
        reconciled.order_id,
        reconciled.customer_id,
        reconciled.order_date,
        reconciled.order_status,
        reconciled.currency_code,
        reconciled.expected_amount,
        reconciled.captured_amount,
        reconciled.variance_amount,
        reconciled.captured_payment_count,
        reconciled.failed_payment_count,
        reconciled.last_captured_date,
        reconciled.days_to_payment,
        reconciled.reconciliation_status

    from reconciled

)

select * from final
