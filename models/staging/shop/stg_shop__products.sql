-- Migrated from legacy/stored_procedures/sp_load_customer_ltv.sql
-- Extended for legacy/informatica/m_LOAD_DAILY_SALES_SUMMARY.xml
-- Grain: one row per product

with

source_products as (

    select * from {{ source('shop', 'products') }}

),

final as (

    select
        product_id,
        upper(nullif(trim(sku), '')) as sku,
        nullif(trim(product_name), '') as product_name,
        nullif(trim(category), '') as category,
        nullif(trim(subcategory), '') as subcategory,
        list_price,
        unit_cost,
        is_active

    from source_products

)

select * from final
