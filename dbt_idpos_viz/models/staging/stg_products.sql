select
    product_id,
    manufacturer,
    department,
    brand,
    commodity_desc as category_name,
    sub_commodity_desc as sub_category_name
from {{ source('raw_data', 'PRODUCTS') }}