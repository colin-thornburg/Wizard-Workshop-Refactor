with

source as (

    select * from {{ source('shop', 'customers') }}

),

renamed as (

    select
        customer_id,
        trim(first_name) as first_name,
        trim(last_name) as last_name,
        trim(first_name) || ' ' || trim(last_name) as customer_name,
        lower(trim(email)) as email,
        upper(trim(state)) as state,
        signup_date,
        coalesce(nullif(upper(trim(loyalty_tier)), ''), 'NONE') as loyalty_tier,
        coalesce(upper(trim(is_test_account)), 'N') = 'Y' as is_test_account

    from source

)

select * from renamed
