with

source as (

    select * from {{ source('shop', 'products') }}

),

renamed as (

    select
        product_id,
        sku,
        product_name,
        category as product_category,
        subcategory as product_subcategory,
        list_price,
        unit_cost as unit_cost_usd,
        is_active

    from source

)

select * from renamed
