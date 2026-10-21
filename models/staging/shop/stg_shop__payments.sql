-- Migrated from legacy/alteryx/Payment_Reconciliation.yxmd
-- Grain: one row per payment attempt

with

source as (

    select * from {{ source('shop', 'payments') }}

),

final as (

    select
        payment_id,
        order_id,
        trim(payment_method) as payment_method,
        upper(trim(payment_status)) as payment_status,
        amount,
        payment_date

    from source

)

select * from final
