with

transactions as (
    select * from {{ ref('stg_transactions') }}
),

demographics as (
    select * from {{ ref('stg_demographics') }}
),

household_sales as (
    select
        household_id,
        count(distinct basket_id) as total_baskets,
        sum(sales_amount) as total_spend,
        min(transaction_date) as first_purchase_date,
        max(transaction_date) as last_purchase_date
    from transactions
    group by household_id
),

final as (
    select
        s.*,
        d.age_desc,
        d.income_desc,
        d.household_size_desc
    from
        household_sales s
        left join demographics d
            on s.household_id = d.household_id
)

select * from final