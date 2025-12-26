library(shiny)
library(ggplot2)
library(dplyr)
library(DBI)
library(bslib)
library(scales) # For currency formatting

# Load the connection utility
source("../R/connection.R")

# -------------------------------------------------------------------------
# UI Definition: Modern Dashboard Layout
# -------------------------------------------------------------------------
theme <- bs_theme(
  bootswatch = "zephyr",
  primary = "#2c3e50",
  base_font = font_google("Inter"),
  "card-border-radius" = "8px"
)

ui <- page_sidebar(
  theme = theme,
  title = "Retail 360 Dashboard",
  
  # Sidebar for filtering controls
  sidebar = sidebar(
    title = "Analysis Filters",
    width = 300,
    helpText("Analyze sales performance and customer demographics."),
    
    # Date range filter
    dateRangeInput("date_range", "Date Range:", 
                   start = "2020-01-01", end = "2021-12-31"),
    
    # Department filter (Dynamic)
    selectInput("department", "Department:", choices = NULL, multiple = TRUE),
    
    hr(),
    actionButton("refresh", "Apply Filters", class = "btn-primary w-100", icon = icon("rotate"))
  ),

  # Main Dashboard Layout
  layout_column_wrap(
    width = 1/3,
    heights_equal = "row",
    
    # KPI Cards (Value Boxes)
    value_box(
      title = "Total Revenue",
      value = textOutput("kpi_sales"),
      showcase = icon("sack-dollar"),
      theme = "primary"
    ),
    value_box(
      title = "Total Baskets",
      value = textOutput("kpi_baskets"),
      showcase = icon("cart-shopping"),
      theme = "secondary"
    ),
    value_box(
      title = "Unique Households",
      value = textOutput("kpi_households"),
      showcase = icon("users"),
      theme = "info"
    )
  ),
  
  layout_column_wrap(
    width = 1/2,
    
    # Left: Weekly Sales Trend
    card(
      card_header("Weekly Sales Trend"),
      plotOutput("trend_plot", height = "300px")
    ),
    
    # Right: Category Performance
    card(
      card_header("Top 10 Categories"),
      plotOutput("cat_plot", height = "300px")
    )
  ),
  
  # Bottom: Demographic Analysis (Cross-Schema Join)
  card(
    card_header("Customer Demographics (Age vs Income)"),
    plotOutput("demo_plot", height = "400px"),
    card_footer("Note: Visualizing sales distribution by joining Sales Mart with Demographic Staging data.")
  )
)

# -------------------------------------------------------------------------
# Server Logic
# -------------------------------------------------------------------------
server <- function(input, output, session) {
  
  # 1. Initialize Metadata
  # Fetch available departments to populate the dropdown filter
  observe({
    con <- get_snowflake_conn()
    
    # Check distinct departments from the Mart
    query <- "SELECT DISTINCT DEPARTMENT FROM POS_DB.ANALYTICS_MARTS.FCT_SALES_SUMMARY WHERE DEPARTMENT IS NOT NULL ORDER BY 1"
    depts <- DBI::dbGetQuery(con, query)
    
    DBI::dbDisconnect(con)
    
    updateSelectInput(session, "department", choices = depts$DEPARTMENT)
  })

  # 2. Main Data Fetching (Reactive)
  # Executes SQL queries on Snowflake when 'refresh' is clicked
  dashboard_data <- eventReactive(input$refresh, {
    req(input$date_range)
    
    con <- get_snowflake_conn()
    showNotification("Querying Snowflake...", type = "message")
    
    # Build dynamic WHERE clause based on inputs
    where_clauses <- list(
      sprintf("TRANSACTION_DATE BETWEEN '%s' AND '%s'", input$date_range[1], input$date_range[2])
    )
    
    if (!is.null(input$department)) {
      # Escape single quotes and create a comma-separated list
      depts_str <- paste(sprintf("'%s'", input$department), collapse = ",")
      where_clauses <- c(where_clauses, sprintf("DEPARTMENT IN (%s)", depts_str))
    }
    
    where_sql <- paste(where_clauses, collapse = " AND ")

    # -- Query A: KPI Aggregates --
    kpi_sql <- sprintf(
      "SELECT 
         SUM(SALES_AMOUNT) as TOTAL_SALES, 
         COUNT(DISTINCT BASKET_ID) as TOTAL_BASKETS,
         COUNT(DISTINCT HOUSEHOLD_ID) as UNIQUE_HH
       FROM POS_DB.ANALYTICS_MARTS.FCT_SALES_SUMMARY 
       WHERE %s", 
      where_sql
    )
    
    # -- Query B: Weekly Trend --
    trend_sql <- sprintf(
      "SELECT 
         DATE_TRUNC('WEEK', TRANSACTION_DATE) as WEEK_START, 
         SUM(SALES_AMOUNT) as SALES 
       FROM POS_DB.ANALYTICS_MARTS.FCT_SALES_SUMMARY 
       WHERE %s 
       GROUP BY 1 
       ORDER BY 1", 
      where_sql
    )
    
    # -- Query C: Top Categories --
    cat_sql <- sprintf(
      "SELECT 
         CATEGORY_NAME, 
         SUM(SALES_AMOUNT) as SALES 
       FROM POS_DB.ANALYTICS_MARTS.FCT_SALES_SUMMARY 
       WHERE %s 
       GROUP BY 1 
       ORDER BY 2 DESC 
       LIMIT 10", 
      where_sql
    )
    
    # -- Query D: Demographics (Join with Staging) --
    # Joining FCT_SALES_SUMMARY (Mart) with STG_DEMOGRAPHICS (Staging View)
    # Note: Assuming 'POS_DB.ANALYTICS_STAGING' based on standard dbt profile patterns.
    # If the schema name differs, this part might need adjustment.
    demo_sql <- sprintf(
      "SELECT 
         d.AGE_DESC, 
         d.INCOME_DESC, 
         SUM(f.SALES_AMOUNT) as SALES
       FROM POS_DB.ANALYTICS_MARTS.FCT_SALES_SUMMARY f
       JOIN POS_DB.ANALYTICS_STAGING.STG_DEMOGRAPHICS d 
         ON f.HOUSEHOLD_ID = d.HOUSEHOLD_ID
       WHERE %s
       GROUP BY 1, 2", 
      where_sql
    )

    # Execute all queries
    kpi <- DBI::dbGetQuery(con, kpi_sql)
    trend <- DBI::dbGetQuery(con, trend_sql)
    cats <- DBI::dbGetQuery(con, cat_sql)
    
    # Handle potential schema name issues gracefully for demo query
    demo <- tryCatch({
      DBI::dbGetQuery(con, demo_sql)
    }, error = function(e) {
      showNotification("Demographic join failed. Check schema names.", type = "warning")
      return(data.frame(AGE_DESC = character(), INCOME_DESC = character(), SALES = numeric()))
    })
    
    DBI::dbDisconnect(con)
    
    list(kpi = kpi, trend = trend, cats = cats, demo = demo)
  })

  # 3. Rendering Outputs

  # KPI Value Boxes
  output$kpi_sales <- renderText({ 
    req(dashboard_data())
    dollar(dashboard_data()$kpi$TOTAL_SALES) 
  })
  
  output$kpi_baskets <- renderText({ 
    req(dashboard_data())
    comma(dashboard_data()$kpi$TOTAL_BASKETS) 
  })
  
  output$kpi_households <- renderText({ 
    req(dashboard_data())
    comma(dashboard_data()$kpi$UNIQUE_HH) 
  })

  # Trend Plot
  output$trend_plot <- renderPlot({
    req(dashboard_data())
    df <- dashboard_data()$trend
    
    ggplot(df, aes(x = as.Date(WEEK_START), y = SALES)) +
      geom_area(fill = "#3498db", alpha = 0.4) +
      geom_line(color = "#2980b9", linewidth = 1) +
      theme_minimal(base_size = 14) + 
      labs(x = NULL, y = NULL) +
      scale_y_continuous(labels = label_dollar())
  })
  
  # Category Plot
  output$cat_plot <- renderPlot({
    req(dashboard_data())
    df <- dashboard_data()$cats
    
    ggplot(df, aes(x = reorder(CATEGORY_NAME, SALES), y = SALES)) +
      geom_col(fill = "#2c3e50") + 
      coord_flip() +
      theme_minimal(base_size = 14) + 
      labs(x = NULL, y = NULL) +
      scale_y_continuous(labels = label_dollar())
  })
  
  # Demographic Heatmap
  output$demo_plot <- renderPlot({
    req(dashboard_data())
    df <- dashboard_data()$demo
    
    if(nrow(df) == 0) return(NULL)
    
    ggplot(df, aes(x = AGE_DESC, y = INCOME_DESC, fill = SALES)) +
      geom_tile(color = "white") +
      scale_fill_viridis_c(option = "cividis", labels = label_dollar()) +
      theme_minimal(base_size = 14) +
      labs(x = "Age Group", y = "Income Level", fill = "Sales") +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1),
        panel.grid = element_blank()
      )
  })
}

shinyApp(ui = ui, server = server)