-- Migrated from Informatica mapping m_LOAD_DAILY_SALES_SUMMARY
-- Grain: one row per sales_date x channel_group x product_category.

with

order_lines as (

    select * from {{ ref('int_order_lines__usd') }}
    where is_valid_order
        and not is_test_customer
        and quantity > 0

),

products as (

    select * from {{ ref('stg_shop__products') }}

),

lines_classified as (

    select
        order_lines.order_date as sales_date,
        case
            when order_lines.channel in ('WEB', 'APP') then 'ONLINE'
            when order_lines.channel = 'STORE' then 'RETAIL'
            when order_lines.channel = 'MARKETPLACE' then 'MARKETPLACE'
            else 'OTHER'
        end as channel_group,
        coalesce(products.product_category, 'UNKNOWN') as product_category,
        order_lines.order_line_id,
        order_lines.quantity,
        order_lines.line_gross_usd,
        order_lines.line_discount_usd,
        order_lines.line_net_usd,
        order_lines.quantity * coalesce(products.unit_cost_usd, 0) as line_cogs_usd

    from order_lines
    left join products
        on order_lines.product_id = products.product_id

),

aggregated as (

    select
        sales_date,
        channel_group,
        product_category,
        count(order_line_id) as order_line_count,
        sum(quantity) as units_sold,
        sum(line_gross_usd) as gross_sales_usd,
        sum(line_discount_usd) as discount_usd,
        sum(line_net_usd) as net_sales_usd,
        sum(line_cogs_usd) as cogs_usd

    from lines_classified
    group by sales_date, channel_group, product_category

),

final as (

    select
        sales_date,
        channel_group,
        product_category,
        order_line_count,
        units_sold,
        gross_sales_usd,
        discount_usd,
        net_sales_usd,
        cogs_usd,
        net_sales_usd - cogs_usd as gross_margin_usd,
        case
            when net_sales_usd = 0 then 0
            else round((net_sales_usd - cogs_usd) / net_sales_usd, 4)
        end as gross_margin_pct

    from aggregated

)

select * from final
