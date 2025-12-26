# app/app.R
library(shiny)
library(ggplot2)
library(dplyr)
library(DBI)

# Load the connection utility from the parent R directory
source("../R/connection.R")

ui <- fluidPage(
  theme = bslib::bs_theme(bootswatch = "flatly"),
  titlePanel("Snowflake Sales Dashboard"),
  
  sidebarLayout(
    sidebarPanel(
      helpText("Fetch live sales data directly from Snowflake."),
      numericInput("row_limit", "Number of categories to show:", value = 15, min = 5, max = 50),
      actionButton("load_data", "Load Data from Snowflake", class = "btn-primary"),
      hr(),
      verbatimTextOutput("data_status")
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel("Sales Analysis", plotOutput("salesPlot", height = "600px")),
        tabPanel("Raw Data Preview", tableOutput("tablePreview"))
      )
    )
  )
)

server <- function(input, output, session) {
  
  # Reactive event triggered by the button click
  sales_data <- eventReactive(input$load_data, {
    showNotification("Connecting to Snowflake...", type = "message")
    
    con <- get_snowflake_conn()
    
    # Querying the table identified in your worksheet
    query <- sprintf(
      "SELECT CATEGORY_NAME, SUM(SALES_AMOUNT) as TOTAL_SALES 
       FROM POS_DB.ANALYTICS_MARTS.FCT_SALES_SUMMARY 
       GROUP BY CATEGORY_NAME 
       ORDER BY TOTAL_SALES DESC 
       LIMIT %d", 
      input$row_limit
    )
    
    df <- DBI::dbGetQuery(con, query)
    DBI::dbDisconnect(con)
    
    return(df)
  })

  # Display data status
  output$data_status <- renderText({
    if (input$load_data == 0) return("Click the button to fetch data.")
    paste("Successfully loaded", nrow(sales_data()), "categories.")
  })

  # Render the bar chart
  output$salesPlot <- renderPlot({
    req(sales_data())
    
    ggplot(sales_data(), aes(x = reorder(CATEGORY_NAME, TOTAL_SALES), y = TOTAL_SALES)) +
      geom_col(fill = "#2c3e50") +
      coord_flip() +
      theme_minimal(base_size = 14) +
      labs(
        title = "Top Categories by Sales Amount",
        subtitle = "Live data from POS_DB.ANALYTICS_MARTS.FCT_SALES_SUMMARY",
        x = "Category Name",
        y = "Total Sales (Amount)"
      )
  })
  
  # Render the data table preview
  output$tablePreview <- renderTable({
    head(sales_data(), 20)
  })
}

shinyApp(ui = ui, server = server)