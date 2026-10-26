-- Migrated from legacy/alteryx/Payment_Reconciliation.yxmd
-- Grain: one row per payment event

with

source as (

    select * from {{ source('shop', 'payments') }}

),

final as (

    select
        payment_id,
        order_id,
        upper(nullif(trim(payment_method), '')) as payment_method,
        upper(nullif(trim(payment_status), '')) as payment_status,
        amount,
        payment_date

    from source

)

select * from final
