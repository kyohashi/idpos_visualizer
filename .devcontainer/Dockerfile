# Base image with Python 3.11
FROM mcr.microsoft.com/devcontainers/python:3.11

# Install R and system libraries for data manipulation
RUN apt-get update && apt-get install -y --no-install-recommends \
    r-base r-base-dev libxml2-dev libssl-dev libcurl4-openssl-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install 'uv' for Python package management
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Pre-install 'renv' for R package management
RUN R -e "install.packages('renv', repos='http://cran.rstudio.com/')"

WORKDIR /workspaces/idpos_visualizer