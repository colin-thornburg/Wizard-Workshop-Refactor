-- Migrated from legacy/stored_procedures/sp_load_customer_ltv.sql
-- Extended for legacy/talend/J_Product_Returns_Analysis_0.1.item
-- Grain: one row per order

with

orders as (

    select * from {{ ref('stg_shop__orders') }}

),

customers as (

    select * from {{ ref('stg_shop__customers') }}

),

final as (

    select
        orders.order_id,
        orders.customer_id,
        orders.order_date,
        orders.order_status,
        orders.channel,
        orders.currency_code,
        date_trunc('month', orders.order_date) as rate_month,
        orders.shipping_cost,
        orders.promo_code,
        orders.order_status in ('COMPLETED', 'SHIPPED', 'RETURNED') as is_valid_order,
        coalesce(customers.is_test_account, false) as is_test_customer,
        customers.customer_id is not null as has_known_customer

    from orders
    left join customers
        on orders.customer_id = customers.customer_id

)

select * from final
