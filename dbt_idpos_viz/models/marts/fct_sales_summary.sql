with

transactions as (
    select * from {{ ref('stg_transactions') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

joined as (
    select
        t.basket_id,
        t.transaction_date,
        t.household_id,
        t.product_id,
        t.quantity,
        t.sales_amount,
        p.department,
        p.category_name,
        p.brand
    from
        transactions t
        left join products p
            on t.product_id = p.product_id
)

select * from joined