with

source as (

    select * from {{ source('shop', 'returns') }}

),

renamed as (

    select
        return_id,
        order_line_id,
        return_date,
        return_qty,
        upper(trim(reason_code)) as reason_code,
        refund_amount

    from source

)

select * from renamed
