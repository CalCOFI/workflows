# packages ----
if (!require("librarian")){
  install.packages("librarian")
  library(librarian)
}
librarian::shelf(
  DBI, dbplyr, dplyr, here, RPostgres)

# paths ----
dir_gdrive <- switch(
  Sys.info()["nodename"],
  `bens-mbp.lan` =
    "/Users/bbest/My Drive/projects/calcofi",
  `Bens-MacBook-Pro.local` =
    "/Users/bbest/My Drive/projects/calcofi",
  `Cristinas-MacBook-Pro.local` =
    "/Volumes/GoogleDrive/.shortcut-targets-by-id/13pWB5x59WSBR0mr9jJjkx7rri9hlUsMv/calcofi")
stopifnot(dir.exists(dir_gdrive))

# database connect ----
db_pass_txt <- "~/.calcofi_db_pass.txt"
stopifnot(file.exists(db_pass_txt))

con <- DBI::dbConnect(
  RPostgres::Postgres(),
  dbname   = "gis",
  host     = "db.calcofi.io",
  port     = 5432,
  user     = "admin",
  password = readLines(db_pass_txt))
