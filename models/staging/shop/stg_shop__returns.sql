-- Migrated from legacy/stored_procedures/sp_load_customer_ltv.sql
-- Grain: one row per return

with

source as (

    select * from {{ source('shop', 'returns') }}

),

final as (

    select
        return_id,
        order_line_id,
        return_date,
        return_qty,
        reason_code,
        refund_amount

    from source

)

select * from final
