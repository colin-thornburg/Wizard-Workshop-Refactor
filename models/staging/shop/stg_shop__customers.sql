-- Migrated from legacy/stored_procedures/sp_load_customer_ltv.sql
-- Grain: one row per customer

with

source as (

    select * from {{ source('shop', 'customers') }}

),

final as (

    select
        customer_id,
        nullif(trim(first_name), '') as first_name,
        nullif(trim(last_name), '') as last_name,
        lower(nullif(trim(email), '')) as email,
        upper(nullif(trim(state), '')) as state,
        signup_date,
        upper(nullif(trim(loyalty_tier), '')) as loyalty_tier,
        coalesce(upper(trim(is_test_account)), 'N') = 'Y' as is_test_account

    from source

)

select * from final
