# ID-POS Visualizer: End-to-End Analysis Platform

This repository provides a complete data analysis platform for retail ID-POS data. It streamlines the entire data lifecycle: **Ingesting** raw CSV files into Snowflake using Python, **Transforming** data into analytical marts with dbt, and **Visualizing** insights via an interactive R Shiny dashboard.



## 🏗 System Architecture

The platform is divided into three main stages:
1.  **Ingestion (Python)**: Loads local CSV files (Transactions, Products, Demographics) into the Snowflake `RAW` schema.
2.  **Transformation (dbt)**: Converts raw data into `STAGING` views and final `MARTS` tables (e.g., `fct_sales_summary`).
3.  **Visualization (R Shiny)**: An interactive dashboard that connects to the analytical marts to provide business insights.

## 🛠 Prerequisites

* **Docker Desktop**
* **VS Code** with the **Dev Containers** extension
* A **Snowflake Account**

## 🏁 Getting Started

### 1. Clone and Initialize
```bash
git clone git@github.com:kyohashi/idpos_visualizer.git
cd idpos_visualizer
```
Open the folder in VS Code and click "Reopen in Container" when the prompt appears. This sets up the environment with R 4.5.0, Snowflake ODBC drivers, and all necessary extensions.

### 2. Environment Configuration
Create a `.env` file by copying `.env.example` in the root directory and populate it with your Snowflake credentials.

## 🚀 Execution Workflow
### Step 1: Infrastructure Setup
Execute the SQL script found in infrastructure/snowflake_setup.sql within a Snowflake Worksheet. This creates the required POS_DB database, POS_WH warehouse, and schemas (RAW, ANALYTICS).

## Step2: Data Requirements

To ensure the dbt models and Shiny app work correctly, your CSV files in the `data/` directory must contain the following specific columns. The ingestion script will normalize these to uppercase in Snowflake, and dbt will then map them to the analytical schema.

### Required CSV Files & Columns
| File Name | Required Source Columns |
| :--- | :--- |
| `transaction_data.csv` | `BASKET_ID`, `DAY`, `HOUSEHOLD_KEY`, `PRODUCT_ID`, `QUANTITY`, `SALES_VALUE` |
| `product.csv` | `PRODUCT_ID`, `DEPARTMENT`, `COMMODITY_DESC`, `CURR_SIZE_RES` |
| `hh_demographic.csv` | `HOUSEHOLD_KEY`, `AGE_DESC`, `MARITAL_STATUS_CODE`, `INCOME_DESC`, `HOMEOWNER_DESC`, `HH_COMP_DESC`, `HOUSEHOLD_SIZE_DESC` |

> **Important**: If your source columns differ from the defaults, edit the staging models in `dbt_idpos_viz/models/staging/` to map them correctly.

### Step 3: Data Ingestion
Ensure your CSV files are in the data/ directory, then run the Python ingestion script to upload your data to Snowflake's RAW schema:

```bash
uv run python ingestion/load_data.py
```
This script creates and populates the TRANSACTIONS, PRODUCTS, and DEMOGRAPHICS tables.

### Step 4: dbt Transformation
Navigate to the dbt project directory and build the analytical models:

```bash
cd dbt_idpos_viz
uv run --env-file ../.env dbt build --profiles-dir .
```
This creates the staging views and final analytical tables in the ANALYTICS_MARTS schema.

### Step 5: Launch the Shiny App
Start the interactive dashboard from your R console (Radian):

```R
# Run inside the Radian R console
renv::restore()
shiny::runApp("app", port = 8080)
```
Open the application via the VS Code popup or the PORTS tab (port 8080).

## 📁 Project Structure
-  `.devcontainer/`: Definitions for the Linux-based R 4.5.0 environment.
- `ingestion/`: Python scripts for loading data into Snowflake.
- `dbt_idpos_viz/`: dbt project containing SQL models for staging and marts.
- `R/`: Connection utilities using the libSnowflake.so ODBC driver.
- `app/`: Shiny application UI and Server logic.