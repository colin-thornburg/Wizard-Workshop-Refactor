-- Migrated from legacy/stored_procedures/sp_load_customer_ltv.sql
-- Grain: one row per currency and rate month

with

source_fx_rates as (

    select * from {{ source('shop', 'fx_rates') }}

),

final as (

    select
        upper(nullif(trim(currency_code), '')) as currency_code,
        rate_month,
        usd_per_unit

    from source_fx_rates

)

select * from final
