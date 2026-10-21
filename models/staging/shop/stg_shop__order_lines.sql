with

source as (

    select * from {{ source('shop', 'order_lines') }}

),

renamed as (

    select
        order_line_id,
        order_id,
        product_id,
        quantity,
        unit_price,
        discount_pct

    from source

)

select * from renamed
