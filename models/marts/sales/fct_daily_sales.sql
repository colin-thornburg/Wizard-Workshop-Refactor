-- Migrated from legacy/informatica/m_LOAD_DAILY_SALES_SUMMARY.xml
-- Grain: one row per sales date, channel group, and product category

with

order_lines as (

    select * from {{ ref('int_order_lines__usd') }}
    where is_valid_order
        and not is_test_customer
        and quantity > 0

),

normalized as (

    select
        order_line_id,
        order_date as sales_date,
        case
            when channel in ('WEB', 'APP') then 'ONLINE'
            when channel = 'STORE' then 'RETAIL'
            when channel = 'MARKETPLACE' then 'MARKETPLACE'
            else 'OTHER'
        end as channel_group,
        coalesce(product_category, 'UNKNOWN') as product_category,
        quantity,
        line_gross_usd,
        line_discount_usd,
        line_net_usd,
        line_cogs_usd

    from order_lines

),

daily_sales as (

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

    from normalized
    group by
        sales_date,
        channel_group,
        product_category

),

margin as (

    select
        daily_sales.*,
        daily_sales.net_sales_usd - daily_sales.cogs_usd as gross_margin_usd

    from daily_sales

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
        gross_margin_usd,
        case
            when net_sales_usd = 0 then 0
            else round(gross_margin_usd / net_sales_usd, 4)
        end as gross_margin_pct

    from margin

)

select * from final
