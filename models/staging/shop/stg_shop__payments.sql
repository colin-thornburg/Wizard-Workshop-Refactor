with

source as (

    select * from {{ source('shop', 'payments') }}

),

renamed as (

    select
        payment_id,
        order_id,
        lower(trim(payment_method)) as payment_method,
        upper(trim(payment_status)) as payment_status,
        amount,
        payment_date

    from source

)

select * from renamed
