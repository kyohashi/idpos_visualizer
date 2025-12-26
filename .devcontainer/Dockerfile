# Base image with Python 3.11
FROM mcr.microsoft.com/devcontainers/python:3.11

# Install system dependencies for R and ODBC
RUN apt-get update && apt-get install -y --no-install-recommends \
    r-base r-base-dev \
    libxml2-dev libssl-dev libcurl4-openssl-dev \
    libpng-dev libjpeg-dev libcairo2-dev libxt-dev \
    unixodbc unixodbc-dev wget ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Snowflake ODBC Driver for aarch64 (Debian/Ubuntu)
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        SNOW_URL="linux/3.3.0/snowflake-odbc-3.3.0.x86_64.deb"; \
    else \
        SNOW_URL="linuxaarch64/3.3.0/snowflake-odbc-3.3.0.aarch64.deb"; \
    fi && \
    wget https://sfc-repo.snowflakecomputing.com/odbc/${SNOW_URL} -O snowflake-odbc.deb && \
    dpkg -i snowflake-odbc.deb || apt-get install -f -y && \
    rm snowflake-odbc.deb

# Verify the driver path during build
RUN find /usr/lib/snowflake/odbc/lib/ -name "*.so" && \
    ls /usr/lib/snowflake/odbc/lib/lib*Snowflake*.so
    
# Install 'uv' for Python package management
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Pre-install essential R packages for development and LSP
RUN uv pip install --system radian
RUN R -e "install.packages(c('renv', 'languageserver', 'remotes'), repos='https://cran.rstudio.com/')"
RUN R -e "remotes::install_github('nx10/httpgd')"

WORKDIR /workspaces/idpos_visualizer