with 

source as (
    select * from {{ source('raw_data', 'TRANSACTIONS') }}
),

renamed as (
    select
        household_key as household_id,
        basket_id,
        product_id,
        quantity,
        sales_value as sales_amount,
        store_id,
        cast(day as date) as transaction_date,
        week_no
    from source
)

select * from renamed