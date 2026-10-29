-- Migrated from legacy/stored_procedures/sp_load_customer_ltv.sql
-- Grain: one row per product

with

source as (

    select * from {{ source('shop', 'products') }}

),

final as (

    select
        product_id,
        nullif(trim(sku), '') as sku,
        nullif(trim(product_name), '') as product_name,
        upper(nullif(trim(category), '')) as category,
        upper(nullif(trim(subcategory), '')) as subcategory,
        list_price,
        unit_cost,
        is_active

    from source

)

select * from final
