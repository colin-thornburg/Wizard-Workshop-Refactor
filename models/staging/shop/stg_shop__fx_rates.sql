with

source as (

    select * from {{ source('shop', 'fx_rates') }}

),

renamed as (

    select
        upper(trim(currency_code)) as currency_code,
        rate_month,
        usd_per_unit

    from source

)

select * from renamed
