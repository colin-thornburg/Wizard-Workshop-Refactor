-- Migrated from legacy/informatica/m_LOAD_DAILY_SALES_SUMMARY.xml
-- Grain: one row per product

with

source as (

    select * from {{ source('shop', 'products') }}

),

final as (

    select
        product_id,
        sku,
        product_name,
        category,
        subcategory,
        list_price,
        unit_cost,
        is_active

    from source

)

select * from final
