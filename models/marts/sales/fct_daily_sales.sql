-- Migrated from legacy/informatica/m_LOAD_DAILY_SALES_SUMMARY.xml
-- Grain: one row per sales date, channel group, and product category

with

order_lines_usd as (

    select * from {{ ref('int_order_lines__usd') }}
    where order_status in ('COMPLETED', 'SHIPPED', 'RETURNED')
        and is_test = 0
        and quantity > 0

),

daily_sales as (

    select
        order_date as sales_date,
        channel_group,
        product_category,
        count(order_line_id) as order_line_count,
        sum(quantity) as units_sold,
        sum(line_gross_usd) as gross_sales_usd,
        sum(line_discount_usd) as discount_usd,
        sum(line_net_usd) as net_sales_usd,
        sum(line_cogs_usd) as cogs_usd

    from order_lines_usd
    group by
        order_date,
        channel_group,
        product_category

),

final as (

    select
        daily_sales.sales_date,
        daily_sales.channel_group,
        daily_sales.product_category,
        daily_sales.order_line_count,
        daily_sales.units_sold,
        daily_sales.gross_sales_usd,
        daily_sales.discount_usd,
        daily_sales.net_sales_usd,
        daily_sales.cogs_usd,
        daily_sales.net_sales_usd - daily_sales.cogs_usd as gross_margin_usd,
        case
            when daily_sales.net_sales_usd = 0 then 0
            else round(
                (daily_sales.net_sales_usd - daily_sales.cogs_usd)
                    / daily_sales.net_sales_usd,
                4
            )
        end as gross_margin_pct

    from daily_sales

)

select * from final
