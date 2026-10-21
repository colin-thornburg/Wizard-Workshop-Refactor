-- Migrated from legacy/stored_procedures/sp_load_customer_ltv.sql
-- Grain: one row per customer

with

source as (

    select * from {{ source('shop', 'customers') }}

),

final as (

    select
        customer_id,
        trim(first_name) as first_name,
        trim(last_name) as last_name,
        lower(trim(email)) as email,
        upper(trim(state)) as state,
        signup_date,
        upper(trim(loyalty_tier)) as loyalty_tier,
        upper(trim(is_test_account)) as is_test_account

    from source

)

select * from final
