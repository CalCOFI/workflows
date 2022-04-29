if (!require("librarian")){
  install.packages("librarian")
  library(librarian)
}
librarian::shelf(
  DBI, dbplyr, dplyr, here, RPostgres)

pass_txt <- "~/.db_pass"

stopifnot(file.exists(pass_txt))

con <- DBI::dbConnect(
  RPostgres::Postgres(),
  dbname   = "gis",
  host     = "postgis",
  port     = 5432,
  user     = "admin",
  password = readLines(pass_txt))


