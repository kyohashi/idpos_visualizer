library(shiny)
library(ggplot2)
library(dplyr)
library(DBI)
library(bslib)
library(scales)
library(plotly)
library(tidyr)

# -------------------------------------------------------------------------
# Setup & Helper Functions
# -------------------------------------------------------------------------
# Snowflake接続設定の読み込み
# ※ ディレクトリ構成が idpos_visualizer/app/app.R である前提
source("../R/connection.R")

# --- Simulation Helpers for Advanced Tabs (LDA/DLM) ---
# ※ EDA以外はまだSnowflakeにテーブルがないため、一時的にシミュレーションデータを使います

# LDA用ダミーデータ
generate_lda_data <- function() {
  topics <- c("Topic 1: Breakfast", "Topic 2: Healthy", "Topic 3: Party", "Topic 4: Quick Meal")
  
  terms <- data.frame(
    Topic = rep(topics, each=5),
    Product = c("Milk", "Cereal", "Coffee", "Eggs", "Toast",
                "Spinach", "Avocado", "Salmon", "Yogurt", "Nuts",
                "Chips", "Cola", "Beer", "Pizza", "Dips",
                "Frozen Pasta", "Sandwich", "Soup", "Salad", "Energy Drink"),
    Beta = runif(20, 0.4, 0.9)
  )
  
  customers <- paste0("HH_", 1001:1020)
  gamma <- expand.grid(Customer = customers, Topic = topics) %>%
    mutate(Gamma = runif(n()))
  
  list(terms = terms, customers = gamma)
}

# DLM用ダミーデータ
generate_dlm_data <- function() {
  dates <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by="day")
  n <- length(dates)
  trend <- cumsum(rnorm(n, 0, 2)) + 5000
  season <- sin(2*pi*(1:n)/7)*500
  lift <- rep(0, n); lift[sample(1:n, 20)] <- 2000
  
  data.frame(
    Date = dates,
    Observed = trend + season + lift + rnorm(n, 0, 200),
    Trend = trend,
    Seasonal = season,
    Lift = lift
  )
}

lda_res <- generate_lda_data()
dlm_res <- generate_dlm_data()

# -------------------------------------------------------------------------
# UI Definition
# -------------------------------------------------------------------------
theme <- bs_theme(
  bootswatch = "zephyr",
  primary = "#2c3e50",
  base_font = font_google("Inter"),
  "card-border-radius" = "8px"
)

ui <- page_navbar(
  title = "Retail 360 Analytics Platform",
  theme = theme,

  # ========================================================================
  # Tab 1: EDA (Actual Snowflake Data)
  # ========================================================================
  nav_panel(
    title = "EDA: Sales Overview",
    layout_sidebar(
      sidebar = sidebar(
        title = "Data Filters",
        width = 300,
        helpText("Querying directly from Snowflake MARTS."),
        
        dateRangeInput("date_range", "Date Range:", 
                       start = "2020-01-01", end = "2021-12-31"),
        
        selectInput("department", "Department:", choices = NULL, multiple = TRUE),
        
        hr(),
        actionButton("refresh", "Run Query", class = "btn-primary w-100", icon = icon("database"))
      ),
      
      # KPI Cards
      layout_column_wrap(
        width = 1/3,
        heights_equal = "row",
        value_box(title="Total Revenue", value=textOutput("kpi_sales"), showcase=icon("sack-dollar"), theme="primary"),
        value_box(title="Total Baskets", value=textOutput("kpi_baskets"), showcase=icon("cart-shopping"), theme="secondary"),
        value_box(title="Unique Households", value=textOutput("kpi_households"), showcase=icon("users"), theme="info")
      ),
      
      # Charts
      layout_column_wrap(
        width = 1/2,
        card(card_header("Weekly Sales Trend"), plotOutput("trend_plot", height = "300px")),
        card(card_header("Top 10 Categories"), plotOutput("cat_plot", height = "300px"))
      ),
      
      card(
        card_header("Customer Demographics (Joined with Staging)"),
        plotOutput("demo_plot", height = "400px"),
        card_footer("Visualizing aggregated sales by Age and Income group.")
      )
    )
  ),

  # ========================================================================
  # Tab 2: LDA (Customer Segmentation) - Prototype
  # ========================================================================
  nav_panel(
    title = "LDA: Shopper DNA",
    layout_sidebar(
      sidebar = sidebar(
        title = "LDA Controls",
        selectInput("lda_topic", "Select Topic:", choices = unique(lda_res$terms$Topic)),
        helpText("This module analyzes product co-occurrence to find hidden shopper segments.")
      ),
      layout_columns(
        card(card_header("Topic Definitions"), plotlyOutput("lda_term_plot", height="350px")),
        card(card_header("Customer Topic Probabilities"), plotlyOutput("lda_cust_plot", height="350px"))
      )
    )
  ),

  # ========================================================================
  # Tab 3: DLM (Causal Inference) - Prototype
  # ========================================================================
  nav_panel(
    title = "DLM: Causal Impact",
    layout_sidebar(
      sidebar = sidebar(
        title = "DLM Controls",
        checkboxGroupInput("dlm_show", "Components:", choices=c("Trend", "Seasonal", "Lift"), selected=c("Trend", "Lift")),
        helpText("Decomposing sales into baseline and incremental lift.")
      ),
      card(card_header("Structural Time Series Decomposition"), plotlyOutput("dlm_main_plot", height="400px"))
    )
  )
)

# -------------------------------------------------------------------------
# Server Logic
# -------------------------------------------------------------------------
server <- function(input, output, session) {
  
  # ========================================================================
  # 1. EDA Logic (Snowflake Connection)
  # ========================================================================
  
  # Populate Department Filter on Load
  observe({
    tryCatch({
      con <- get_snowflake_conn()
      query <- "SELECT DISTINCT DEPARTMENT FROM POS_DB.ANALYTICS_MARTS.FCT_SALES_SUMMARY WHERE DEPARTMENT IS NOT NULL ORDER BY 1"
      depts <- DBI::dbGetQuery(con, query)
      DBI::dbDisconnect(con)
      updateSelectInput(session, "department", choices = depts$DEPARTMENT)
    }, error = function(e) {
      showNotification("Could not connect to Snowflake to fetch departments.", type="error")
    })
  })
  
  # Execute Main Query
  dashboard_data <- eventReactive(input$refresh, {
    req(input$date_range)
    
    con <- get_snowflake_conn()
    showNotification("Querying Snowflake...", type = "message")
    
    # Where Clause Construction
    where_clauses <- list(
      sprintf("TRANSACTION_DATE BETWEEN '%s' AND '%s'", input$date_range[1], input$date_range[2])
    )
    if (!is.null(input$department)) {
      depts_str <- paste(sprintf("'%s'", input$department), collapse = ",")
      where_clauses <- c(where_clauses, sprintf("DEPARTMENT IN (%s)", depts_str))
    }
    where_sql <- paste(where_clauses, collapse = " AND ")
    
    # Queries (Same as before)
    kpi_sql <- sprintf("SELECT SUM(SALES_AMOUNT) as TOTAL_SALES, COUNT(DISTINCT BASKET_ID) as TOTAL_BASKETS, COUNT(DISTINCT HOUSEHOLD_ID) as UNIQUE_HH FROM POS_DB.ANALYTICS_MARTS.FCT_SALES_SUMMARY WHERE %s", where_sql)
    trend_sql <- sprintf("SELECT DATE_TRUNC('WEEK', TRANSACTION_DATE) as WEEK_START, SUM(SALES_AMOUNT) as SALES FROM POS_DB.ANALYTICS_MARTS.FCT_SALES_SUMMARY WHERE %s GROUP BY 1 ORDER BY 1", where_sql)
    cat_sql <- sprintf("SELECT CATEGORY_NAME, SUM(SALES_AMOUNT) as SALES FROM POS_DB.ANALYTICS_MARTS.FCT_SALES_SUMMARY WHERE %s GROUP BY 1 ORDER BY 2 DESC LIMIT 10", where_sql)
    demo_sql <- sprintf("SELECT d.AGE_DESC, d.INCOME_DESC, SUM(f.SALES_AMOUNT) as SALES FROM POS_DB.ANALYTICS_MARTS.FCT_SALES_SUMMARY f JOIN POS_DB.ANALYTICS_STAGING.STG_DEMOGRAPHICS d ON f.HOUSEHOLD_ID = d.HOUSEHOLD_ID WHERE %s GROUP BY 1, 2", where_sql)
    
    kpi <- DBI::dbGetQuery(con, kpi_sql)
    trend <- DBI::dbGetQuery(con, trend_sql)
    cats <- DBI::dbGetQuery(con, cat_sql)
    demo <- tryCatch({ DBI::dbGetQuery(con, demo_sql) }, error = function(e) { data.frame() })
    
    DBI::dbDisconnect(con)
    list(kpi=kpi, trend=trend, cats=cats, demo=demo)
  })
  
  # EDA Outputs
  output$kpi_sales <- renderText({ req(dashboard_data()); dollar(dashboard_data()$kpi$TOTAL_SALES) })
  output$kpi_baskets <- renderText({ req(dashboard_data()); comma(dashboard_data()$kpi$TOTAL_BASKETS) })
  output$kpi_households <- renderText({ req(dashboard_data()); comma(dashboard_data()$kpi$UNIQUE_HH) })
  
  output$trend_plot <- renderPlot({
    req(dashboard_data())
    ggplot(dashboard_data()$trend, aes(as.Date(WEEK_START), SALES)) +
      geom_area(fill="#3498db", alpha=0.4) + geom_line(color="#2980b9", linewidth=1) +
      theme_minimal() + scale_y_continuous(labels=label_dollar()) + labs(x=NULL, y=NULL)
  })
  
  output$cat_plot <- renderPlot({
    req(dashboard_data())
    ggplot(dashboard_data()$cats, aes(reorder(CATEGORY_NAME, SALES), SALES)) +
      geom_col(fill="#2c3e50") + coord_flip() +
      theme_minimal() + scale_y_continuous(labels=label_dollar()) + labs(x=NULL, y=NULL)
  })
  
  output$demo_plot <- renderPlot({
    req(dashboard_data())
    df <- dashboard_data()$demo
    if(nrow(df)==0) return(NULL)
    ggplot(df, aes(AGE_DESC, INCOME_DESC, fill=SALES)) +
      geom_tile(color="white") + scale_fill_viridis_c(option="cividis", labels=label_dollar()) +
      theme_minimal() + theme(axis.text.x=element_text(angle=45, hjust=1)) + labs(x="Age", y="Income")
  })
  
  # ========================================================================
  # 2. LDA Logic (Simulated)
  # ========================================================================
  output$lda_term_plot <- renderPlotly({
    p <- lda_res$terms %>% filter(Topic == input$lda_topic) %>%
      ggplot(aes(reorder(Product, Beta), Beta, fill=Beta)) + geom_col() + coord_flip() + theme_minimal() + labs(x="", y="Probability")
    ggplotly(p)
  })
  output$lda_cust_plot <- renderPlotly({
    p <- lda_res$customers %>% filter(Customer %in% head(unique(Customer), 10)) %>%
      ggplot(aes(Customer, Gamma, fill=Topic)) + geom_col(position="fill") + theme_minimal() + labs(x="", y="Share")
    ggplotly(p)
  })
  
  # ========================================================================
  # 3. DLM Logic (Simulated)
  # ========================================================================
  output$dlm_main_plot <- renderPlotly({
    df <- dlm_res %>% select(Date, Observed, all_of(input$dlm_show)) %>% pivot_longer(-Date)
    p <- ggplot(df, aes(Date, value, color=name)) + geom_line() + theme_minimal() + labs(color="Component")
    ggplotly(p)
  })
}

shinyApp(ui = ui, server = server)