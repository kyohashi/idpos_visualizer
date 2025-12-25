select
    household_key as household_id,
    age_desc,
    marital_status_code,
    income_desc,
    homeowner_desc,
    hh_comp_desc,
    household_size_desc
from {{ source('raw_data', 'DEMOGRAPHICS') }}