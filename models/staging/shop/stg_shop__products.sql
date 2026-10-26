-- Migrated from legacy/stored_procedures/sp_load_customer_ltv.sql
-- Grain: one row per product

with

source as (

    select * from {{ source('shop', 'products') }}

),

final as (

    select
        product_id,
        trim(sku) as sku,
        trim(product_name) as product_name,
        trim(category) as category,
        trim(subcategory) as subcategory,
        list_price,
        unit_cost,
        is_active

    from source

)

select * from final
