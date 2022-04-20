librarian::shelf(
  DBI, dbplyr, dplyr, pool, RPostgres, shiny, stringr)

con <- DBI::dbConnect(
  RPostgres::Postgres(),
  dbname   = "gis",
  host     = "postgis",
  port     = 5432,
  user     = "admin",
  password = readLines("/share/.db_pass"))

DBI


