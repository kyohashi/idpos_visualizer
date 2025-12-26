library(DBI)
library(odbc)
library(dotenv)

#' Establish a secure connection to Snowflake
#'
#' Credentials are pulled from the .env file in the root directory.
#' The "Snowflake" driver name is resolved via system config.
#'
#' @return A DBI connection object
#' @export
get_snowflake_conn <- function() {
    # Load environment variables from .env
    load_dot_env(file = "../.env")

    # Connect using the optimized system driver
    dbConnect(
        odbc::odbc(),
        Driver    = "/usr/lib/snowflake/odbc/lib/libSnowflake.so", # Configured during Docker build
        Server    = Sys.getenv("SNOWFLAKE_SERVER_URL"),
        UID       = Sys.getenv("SNOWFLAKE_USER"),
        PWD       = Sys.getenv("SNOWFLAKE_PASSWORD"),
        Database  = Sys.getenv("SNOWFLAKE_DATABASE"),
        Warehouse = Sys.getenv("SNOWFLAKE_WAREHOUSE"),
        Schema    = "ANALYTICS_MARTS"
    )
}
