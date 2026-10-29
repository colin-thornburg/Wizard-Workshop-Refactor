-- Migrated from legacy/stored_procedures/sp_load_customer_ltv.sql
-- Grain: one row per return

with

source_returns as (

    select * from {{ source('shop', 'returns') }}

),

final as (

    select
        return_id,
        order_line_id,
        return_date,
        return_qty,
        upper(nullif(trim(reason_code), '')) as reason_code,
        refund_amount

    from source_returns

)

select * from final
