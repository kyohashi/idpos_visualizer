library(shiny)
library(ggplot2)
library(dplyr)
library(DBI)
library(bslib)
library(scales)

# Load the connection utility
source("../R/connection.R")

# -------------------------------------------------------------------------
# UI Definition
# -------------------------------------------------------------------------
theme <- bs_theme(
  bootswatch = "zephyr",
  primary = "#2c3e50",
  "card-border-radius" = "8px"
)

ui <- page_sidebar(
  theme = theme,
  title = "Retail 360 Dashboard",
  
  sidebar = sidebar(
    title = "Analysis Filters",
    width = 300,
    dateRangeInput("date_range", "Date Range:", 
                   start = "2021-01-01", end = "2021-12-31"),
    selectInput("department", "Department:", choices = NULL, multiple = TRUE),
    hr(),
    # Changed class to highlight importance
    actionButton("refresh", "Apply Filters", class = "btn-primary w-100", icon = icon("rotate")),
    card_footer("Note: Click Refresh after changing filters.")
  ),

  layout_column_wrap(
    width = 1/3,
    heights_equal = "row",
    value_box(title = "Total Revenue", value = textOutput("kpi_sales"), showcase = icon("sack-dollar"), theme = "primary"),
    value_box(title = "Total Baskets", value = textOutput("kpi_baskets"), showcase = icon("cart-shopping"), theme = "secondary"),
    value_box(title = "Unique Households", value = textOutput("kpi_households"), showcase = icon("users"), theme = "info")
  ),
  
  layout_column_wrap(
    width = 1/2,
    card(card_header("Weekly Sales Trend"), plotOutput("trend_plot", height = "300px")),
    card(card_header("Top 10 Categories"), plotOutput("cat_plot", height = "300px"))
  ),
  
  card(
    card_header("Total Sales Distribution (Age vs Income)"),
    plotOutput("demo_plot", height = "400px")
  )
)

# -------------------------------------------------------------------------
# Server Logic
# -------------------------------------------------------------------------
server <- function(input, output, session) {
  
  # 1. Initialize Metadata on Start
  observe({
    con <- get_snowflake_conn()
    depts <- DBI::dbGetQuery(con, "SELECT DISTINCT DEPARTMENT FROM POS_DB.ANALYTICS_MARTS.FCT_SALES_SUMMARY WHERE DEPARTMENT IS NOT NULL ORDER BY 1")
    DBI::dbDisconnect(con)
    updateSelectInput(session, "department", choices = depts$DEPARTMENT)
  })

  # 2. Main Data Fetching (Use ignoreNULL = FALSE to load on startup)
  dashboard_data <- eventReactive(input$refresh, {
    req(input$date_range)
    
    con <- get_snowflake_conn()
    showNotification("Fetching latest data...", type = "message")
    
    # Build WHERE clause
    where_clauses <- list(sprintf("TRANSACTION_DATE BETWEEN '%s' AND '%s'", input$date_range[1], input$date_range[2]))
    if (!is.null(input$department)) {
      depts_str <- paste(sprintf("'%s'", input$department), collapse = ",")
      where_clauses <- c(where_clauses, sprintf("DEPARTMENT IN (%s)", depts_str))
    }
    where_sql <- paste(where_clauses, collapse = " AND ")

    # Queries
    kpi <- DBI::dbGetQuery(con, sprintf("SELECT SUM(SALES_AMOUNT) as TOTAL_SALES, COUNT(DISTINCT BASKET_ID) as TOTAL_BASKETS, COUNT(DISTINCT HOUSEHOLD_ID) as UNIQUE_HH FROM POS_DB.ANALYTICS_MARTS.FCT_SALES_SUMMARY WHERE %s", where_sql))
    trend <- DBI::dbGetQuery(con, sprintf("SELECT DATE_TRUNC('WEEK', TRANSACTION_DATE) as WEEK_START, SUM(SALES_AMOUNT) as SALES FROM POS_DB.ANALYTICS_MARTS.FCT_SALES_SUMMARY WHERE %s GROUP BY 1 ORDER BY 1", where_sql))
    cats <- DBI::dbGetQuery(con, sprintf("SELECT CATEGORY_NAME, SUM(SALES_AMOUNT) as SALES FROM POS_DB.ANALYTICS_MARTS.FCT_SALES_SUMMARY WHERE %s GROUP BY 1 ORDER BY 2 DESC LIMIT 10", where_sql))
    
    # Demo Query with Join
    demo <- DBI::dbGetQuery(con, sprintf(
      "SELECT d.AGE_DESC, d.INCOME_DESC, SUM(f.SALES_AMOUNT) as SALES
       FROM POS_DB.ANALYTICS_MARTS.FCT_SALES_SUMMARY f
       JOIN POS_DB.ANALYTICS_STAGING.STG_DEMOGRAPHICS d ON f.HOUSEHOLD_ID = d.HOUSEHOLD_ID
       WHERE %s GROUP BY 1, 2", where_sql
    ))
    
    DBI::dbDisconnect(con)
    list(kpi = kpi, trend = trend, cats = cats, demo = demo)
  }, ignoreNULL = FALSE) # <--- CRITICAL: Ensures data loads when app opens

  # 3. Render Outputs
  
  output$kpi_sales <- renderText({ dollar(dashboard_data()$kpi$TOTAL_SALES) })
  output$kpi_baskets <- renderText({ comma(dashboard_data()$kpi$TOTAL_BASKETS) })
  output$kpi_households <- renderText({ comma(dashboard_data()$kpi$UNIQUE_HH) })

  output$trend_plot <- renderPlot({
    req(dashboard_data())
    ggplot(dashboard_data()$trend, aes(x = as.Date(WEEK_START), y = SALES)) +
      geom_area(fill = "#3498db", alpha = 0.4) +
      geom_line(color = "#2980b9", linewidth = 1) +
      theme_minimal(base_size = 14) + scale_y_continuous(labels = label_dollar()) + labs(x = NULL, y = NULL)
  })
  
  # --- FIX: Category Plot Rendering ---
  output$cat_plot <- renderPlot({
    req(dashboard_data())
    df <- dashboard_data()$cats
    
    # Prevent empty plot error
    if(nrow(df) == 0) return(NULL)

    ggplot(df, aes(x = reorder(CATEGORY_NAME, SALES), y = SALES)) +
      geom_col(fill = "#2c3e50") + 
      coord_flip() +
      theme_minimal(base_size = 14) + 
      scale_y_continuous(labels = label_dollar()) +
      labs(x = NULL, y = "Total Sales")
  })
  
  # --- Demographic Heatmap (with fixed sorting) ---
  output$demo_plot <- renderPlot({
    req(dashboard_data())
    df <- dashboard_data()$demo
    if(nrow(df) == 0) return(NULL)
    
    # Standard sorting for Dunnhumby dataset
    income_order <- c("Under 15K", "15-24K", "25-34K", "35-49K", "50-74K", "75-99K", "100-124K", "125-149K", "150-174K", "175-199K", "200-249K", "250K+")
    age_order <- c("19-24", "25-34", "35-44", "45-54", "55-64", "65+")

    df <- df %>%
      mutate(
        INCOME_DESC = factor(INCOME_DESC, levels = income_order),
        AGE_DESC = factor(AGE_DESC, levels = age_order)
      ) %>%
      filter(!is.na(INCOME_DESC), !is.na(AGE_DESC))

    ggplot(df, aes(x = AGE_DESC, y = INCOME_DESC, fill = SALES)) +
      geom_tile(color = "white") +
      scale_fill_viridis_c(option = "cividis", labels = label_dollar()) +
      theme_minimal(base_size = 14) +
      labs(x = "Age Group", y = "Income Level", fill = "Sales") +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
  })
}

shinyApp(ui = ui, server = server)