from datetime import datetime, timedelta

import numpy as np
import pandas as pd

# Set seed for reproducibility
np.random.seed(42)

# --- 1. hh_demographic.csv (100 Households) ---
households = range(1, 101)
age_groups = ["19-24", "25-34", "35-44", "45-54", "55-64", "65+"]
income_groups = [
    "Under 15K",
    "15-24K",
    "25-34K",
    "35-49K",
    "50-74K",
    "75-99K",
    "100-124K",
    "150-174K",
    "250K+",
]
hh_comp = [
    "1 Adult Kids",
    "2 Adults Kids",
    "2 Adults No Kids",
    "Single Female",
    "Single Male",
]
hh_sizes = ["1", "2", "3", "4", "5+"]

demo_df = pd.DataFrame(
    {
        "household_key": households,
        "AGE_DESC": np.random.choice(age_groups, 100),
        "MARITAL_STATUS_CODE": np.random.choice(["A", "B", "U"], 100),
        "INCOME_DESC": np.random.choice(
            income_groups, 100, p=[0.1, 0.1, 0.1, 0.2, 0.2, 0.1, 0.1, 0.05, 0.05]
        ),
        "HOMEOWNER_DESC": np.random.choice(["Homeowner", "Renter", "Unknown"], 100),
        "HH_COMP_DESC": np.random.choice(hh_comp, 100),
        "HOUSEHOLD_SIZE_DESC": np.random.choice(hh_sizes, 100),
        "KID_CATEGORY_DESC": np.random.choice(["None/Unknown", "1", "2", "3+"], 100),
    }
)

# --- 2. product.csv (50 Products) ---
departments = ["GROCERY", "DRUG GM", "PRODUCE", "MEAT-PCKGD", "PASTRY", "SEAFOOD-PCKGD"]
commodities = {
    "GROCERY": ["SOFT DRINKS", "CHEESE", "COOKIES/CONES", "BAKED BREAD/BUNS/ROLLS"],
    "DRUG GM": ["VITAMINS", "CIGARETTES", "DIAPERS & DISPOSABLES"],
    "PRODUCE": ["POTATOES", "SALAD MIX", "FRUIT - SHELF STABLE"],
    "MEAT-PCKGD": ["DINNER SAUSAGE", "LUNCHMEAT"],
    "PASTRY": ["BREAD", "CAKES"],
    "SEAFOOD-PCKGD": ["SEAFOOD - FROZEN"],
}

products = []
for i in range(1, 51):
    dept = np.random.choice(departments)
    comm = np.random.choice(commodities[dept])
    products.append(
        {
            "PRODUCT_ID": 1000 + i,
            "MANUFACTURER": np.random.randint(1, 100),
            "DEPARTMENT": dept,
            "BRAND": np.random.choice(["National", "Private"]),
            "COMMODITY_DESC": comm,
            "SUB_COMMODITY_DESC": "SUB_" + comm,
            "CURR_SIZE_OF_PRODUCT": str(np.random.randint(5, 50)) + " OZ",
        }
    )
product_df = pd.DataFrame(products)

# --- 3. transaction_data.csv (2000 Transactions) ---
# Time period: Full year of 2021
start_date = datetime(2021, 1, 1)
transactions = []

for i in range(2000):
    # Select household and product
    hh_idx = np.random.choice(demo_df.index)
    hh = demo_df.iloc[hh_idx]
    prod = product_df.sample(1).iloc[0]

    # Date generation with weekend bias
    days_offset = np.random.randint(0, 365)
    trans_date = start_date + timedelta(days=days_offset)
    is_weekend = trans_date.weekday() >= 5

    # Sales logic based on income and household size
    income_val = len(hh["INCOME_DESC"])  # Rough proxy for income height
    base_price = np.random.uniform(1.0, 10.0)

    # Pattern A: High income -> higher priced items
    if "100" in hh["INCOME_DESC"] or "250" in hh["INCOME_DESC"]:
        base_price *= 1.5

    # Pattern B: Households with kids -> higher quantity
    qty = np.random.randint(1, 3)
    if hh["KID_CATEGORY_DESC"] != "None/Unknown":
        qty += np.random.randint(1, 3)

    # Pattern C: Weekend spike multiplier
    if is_weekend:
        if np.random.rand() < 0.2:  # Increase transaction density on weekends
            qty += 1

    sales_value = round(base_price * qty, 2)

    transactions.append(
        {
            "HOUSEHOLD_KEY": hh["household_key"],
            "BASKET_ID": 30000000000 + i // 3,  # Groups items into baskets
            "DAY": trans_date.strftime("%Y-%m-%d"),
            "PRODUCT_ID": prod["PRODUCT_ID"],
            "QUANTITY": qty,
            "SALES_VALUE": sales_value,
            "STORE_ID": np.random.choice([300, 400, 500]),
            "RETAIL_DISC": round(sales_value * 0.1, 2) if np.random.rand() > 0.8 else 0,
            "TRANS_TIME": np.random.randint(800, 2200),
            "WEEK_NO": (days_offset // 7) + 1,
        }
    )

transaction_df = pd.DataFrame(transactions)

# --- Save to CSV ---
demo_df.to_csv("hh_demographic.csv", index=False)
product_df.to_csv("product.csv", index=False)
transaction_df.to_csv("transaction_data.csv", index=False)

print("Synthetic demo data generated successfully!")
