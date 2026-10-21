-- Migrated from legacy/stored_procedures/sp_load_customer_ltv.sql
-- Grain: one row per currency and rate month

with

source as (

    select * from {{ source('shop', 'fx_rates') }}

),

final as (

    select
        currency_code,
        rate_month,
        usd_per_unit

    from source

)

select * from final
