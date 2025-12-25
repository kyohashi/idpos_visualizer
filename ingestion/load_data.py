import os

import pandas as pd
import snowflake.connector
from dotenv import load_dotenv
from snowflake.connector.pandas_tools import write_pandas

# Load environment variables from .env file
load_dotenv()


def get_snowflake_connection():
    """
    Establish a connection to Snowflake using credentials from .env file.
    """
    return snowflake.connector.connect(
        user=os.getenv("SNOWFLAKE_USER"),
        password=os.getenv("SNOWFLAKE_PASSWORD"),
        account=os.getenv("SNOWFLAKE_ACCOUNT"),
        warehouse=os.getenv("SNOWFLAKE_WAREHOUSE"),
        database=os.getenv("SNOWFLAKE_DATABASE"),
        schema="RAW",
    )


def load_csv_to_snowflake(file_path: str, table_name: str):
    """
    Read a local CSV file and upload it to the Snowflake RAW schema.

    :param file_path: file path to the local CSV file
    :param table_name: target table name in Snowflake
    """
    conn = get_snowflake_connection()
    try:
        print(f"Starting ingestion for: {file_path} into table {table_name}")

        # Load the local CSV
        df = pd.read_csv(file_path)

        # Upload to Snowflake
        success, nchunks, nrows, _ = write_pandas(
            conn=conn,
            df=df,
            table_name=table_name,
            auto_create_table=True,
            overwrite=True,
        )

        if success:
            print(f"Successfully ingested {nrows} rows into {table_name}")
    except Exception as e:
        print(f"Error during ingestion: {e}")
    finally:
        conn.close()


if __name__ == "__main__":
    load_csv_to_snowflake("./data/transaction_data.csv", "TRANSACTIONS")
    load_csv_to_snowflake("./data/product.csv", "PRODUCTS")
    load_csv_to_snowflake("./data/hh_demographic.csv", "DEMOGRAPHICS")
