-- Migrated from legacy/stored_procedures/sp_load_customer_ltv.sql
-- Grain: one row per order line

with

source as (

    select * from {{ source('shop', 'order_lines') }}

),

final as (

    select
        order_line_id,
        order_id,
        product_id,
        quantity,
        unit_price,
        discount_pct

    from source

)

select * from final
