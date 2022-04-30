# See [get generalized line stations · Issue #12 · CalCOFI/scripts](https://github.com/CalCOFI/scripts/issues/12)

source(here::here("data-raw/_common.R")) # dir_data, librarian::

# libraries ----
librarian::shelf(
  dplyr, glue, here, lubridate, mapview, purrr, readr, readxl,
  sf, stringr, tidyr)
options(readr.show_col_types = F)
mapviewOptions(fgb = F)

# binary paths
proj <- "/Users/bbest/homebrew/bin/proj" # on Ben's MacBookPro

# source paths
cast_csv             <- file.path(dir_data, "oceanographic-data/bottle-database/CalCOFI_Database_194903-202001_csv_22Sep2021/194903-202001_Cast.csv")
# source: Shonna Dovel <sdovel@ucsd.edu> 2022-03-17
stations_ccelter_xls <- file.path(dir_data, "CalCOFI-stations/CalCOFI station LatLong.xlsx")
# sourc: http://cce.lternet.edu/data/gmt-mapper
stations_cce_txt     <- file.path(dir_data, "CalCOFI-stations/CCE_Stations.txt")
stations_sccoos_txt  <- file.path(dir_data, "CalCOFI-stations/SCCOOS_Stations.txt")

# destination paths
# TODO: make study areas with convex hull around points or provide function to do so
study_geo           <- here("data-raw/study.geojson")
study_offshore_geo  <- here("data-raw/study_offshore.geojson")
study_nearshore_geo <- here("data-raw/study_nearshore.geojson")

# check paths
stopifnot(dir.exists(dir_data))
stopifnot(any(file.exists(cast_csv)))

# helper functions ----

# convert station ID to lon, lat using the proj library
lonlat_to_stationid <- function(lon, lat){

  system(glue("echo {lon} {lat} | {proj} +proj=calcofi +epsg=4326 -f '%05.1f'"), intern=T) %>%
    stringr::str_replace("\t", " ")
}
stationid_to_lonlat <- function(stationid){
  proj <- "/Users/bbest/homebrew/bin/proj" # on Ben's MacBookPro
  # https://proj.org/apps/proj.html
  # using 5th decimal place, a la CCE_Stations.txt
  #system(glue("echo {stationid} | {proj} +proj=calcofi +epsg=4326  -I -f '%.5f'"), intern=T) %>%
  system(glue("echo {stationid} | {proj} +proj=calcofi +epsg=4326  -I -d 5"), intern=T) %>%
    stringr::str_replace("\t", " ")
}
(a_staid  <- stations$Sta_ID[1]) # "001.0 168.0"
(a_lonlat <- stationid_to_lonlat(a_staid)) # 93.3	26.7
a_lon <- str_split(a_lonlat, " ", simplify=T)[1] %>% as.double()
a_lat <- str_split(a_lonlat, " ", simplify=T)[2] %>% as.double()
lonlat_to_stationid(a_lon, a_lat) # "1.00 168.00" -> "001.0 168.0"
# "1.0 168.0"

# stations from cast ----

# get unique station IDs from the casts
d_cast   <- read_csv(cast_csv)
stations <- d_cast %>%
  select(Sta_ID) %>%
  group_by(Sta_ID) %>%
  summarize() %>%
  mutate(
    is_cast     = TRUE,
    lonlat_proj = map_chr(Sta_ID, stationid_to_lonlat)) %>%
  separate(lonlat_proj, c("lon", "lat"), sep=" ", convert = T) %>%
  separate(
    Sta_ID, c("Sta_ID_line", "Sta_ID_station"), sep=" ", remove=F, convert=T) %>%
  mutate(
    offshore = ifelse(Sta_ID_station > 60, T, F)) %>%
  st_as_sf(
    coords = c("lon", "lat"), crs=4326, remove = F)
stations$Sta_ID

# mapview(stations)

# + CCE column ----
stations_cce <- read_tsv(stations_cce_txt, skip = 2) %>%
  mutate(
    is_cce = TRUE,
    Sta_ID = map2_chr(LonDec, LatDec, lonlat_to_stationid))
stopifnot(sum(!stations_cce$Sta_ID %in% stations$Sta_ID) == 0)
stations <- stations %>%
  left_join(
    stations_cce %>%
      select(Sta_ID, is_cce),
    by = "Sta_ID")

# + CCE-LTER column ----
stations_ccelter <- read_excel(stations_ccelter_xls) %>%
  mutate(
    is_ccelter = TRUE,
    Sta_ID       = glue("{sprintf('%05.1f', Line)} {sprintf('%05.1f', Sta)}"),
    lonlat_proj  = map_chr(Sta_ID, stationid_to_lonlat)) %>%
  separate(
    lonlat_proj, c("lon", "lat"), sep=" ", convert = T) %>%
  select(Sta_ID, is_ccelter, lon, lon_0 = `Lon Dec`, lat, lat_0 = `Lat Dec`)
# stations_ccelter %>% View()

stopifnot(sum(!stations_ccelter$Sta_ID %in% stations$Sta_ID) == 0)
stations <- stations %>%
  left_join(
    stations_ccelter %>%
      select(Sta_ID, is_ccelter),
    by = "Sta_ID")

# stations %>%
#   filter(is_ccelter | is_cce) %>%
#   select(is_ccelter, is_cce) %>%
#   st_drop_geometry() %>%
#   table(useNA = "ifany")
#
#            is_cce
# is_ccelter   TRUE
#       TRUE     66
#       <NA>     47
# So: 47 extra stations in CCE
#     that are missing in  CCE-LTER

# + SCCOOS column ----
stations_sccoos <- read_tsv(stations_sccoos_txt) %>%
  mutate(
    is_sccoos = TRUE,
    Sta_ID = map2_chr(LonDec, LatDec, lonlat_to_stationid))
stopifnot(sum(!stations_sccoos$Sta_ID %in% stations$Sta_ID) == 0)
stations <- stations %>%
  left_join(
    stations_sccoos %>%
      select(Sta_ID, is_sccoos),
    by = "Sta_ID")

# column order ----
stations <- stations %>%
  select(
    Sta_ID, Sta_ID_line, Sta_ID_station,
    lon, lat,
    offshore,
    is_cast, is_cce, is_ccelter, is_sccoos)
usethis::use_data(stations, overwrite = TRUE)
