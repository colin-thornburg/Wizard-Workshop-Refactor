with

source as (

    select * from {{ source('shop', 'orders') }}

),

renamed as (

    select
        order_id,
        customer_id,
        order_date,
        upper(trim(status)) as order_status,
        nullif(upper(trim(channel)), '') as channel,
        upper(trim(currency_code)) as currency_code,
        shipping_cost,
        nullif(trim(promo_code), '') as promo_code

    from source

)

select * from renamed
