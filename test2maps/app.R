library(shiny)
library(leaflet)

ui <- fluidPage(
  titlePanel("Test 2 Maps"),
  sidebarLayout(
    sidebarPanel(),
    mainPanel(
      tabsetPanel(
        type = "tabs",
        tabPanel(
          "Map 1", 
          leafletOutput("map1")),
        tabPanel(
          "Map 2", 
          leafletOutput("map2"))))))

server <- function(input, output) {

  output$map1 <- renderLeaflet({
    leaflet() %>% addTiles() %>% setView(-117.236, 32.880, 12)
  })
  
  output$map2 <- renderLeaflet({
    leaflet() %>% addProviderTiles(providers$Esri.OceanBasemap) %>% setView(0, 0, 3)
  })
}

shinyApp(ui = ui, server = server)
