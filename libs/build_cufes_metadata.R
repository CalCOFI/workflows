# build_cufes_metadata.R
# scaffold metadata/swfsc/cufes/ for the #35 ingest (underway CUFES fish eggs).
# Source: ERDDAP erdCalCOFIcufes (coastwatch.pfeg.noaa.gov). fld_new conforms to
# metadata/field_dictionary.csv. re-runnable & idempotent.

suppressMessages({library(readr); library(tibble); library(dplyr); library(here); library(fs)})
dir_meta <- here("metadata/swfsc/cufes"); dir_create(dir_meta)

tbls <- tribble(
  ~tbl_old, ~tbl_new, ~tbl_description,
  "erdCalCOFIcufes", "cufes_sample",
  "One row per Continuous Underway Fish Egg Sampler (CUFES) sample: position, time, and underway environmental conditions (temperature, salinity, wind, pump). Egg counts are pivoted to cufes_measurement.",
  "erdCalCOFIcufes", "cufes_measurement",
  "Fish/squid egg counts per CUFES sample in long form (measurement_type = taxon eggs, measurement_value = count)."
)
write_csv(tbls, file.path(dir_meta, "tbls_redefine.csv"), na = "")

flds <- tribble(
  ~tbl_old, ~tbl_new, ~fld_old, ~fld_new, ~type_new, ~fld_description, ~units,
  "erdCalCOFIcufes","cufes_sample","cruise","cruise_orig","VARCHAR","Source cruise label; cruise_key derived from it.","",
  "erdCalCOFIcufes","cufes_sample","ship","ship_name","VARCHAR","Vessel name; resolved to ship_key.","",
  "erdCalCOFIcufes","cufes_sample","ship_code","ship_code","VARCHAR","Source ship code.","",
  "erdCalCOFIcufes","cufes_sample","sample_number","sample_number","INTEGER","CUFES sample sequence number within the cruise.","",
  "erdCalCOFIcufes","cufes_sample","time","datetime_start_utc","TIMESTAMP","Sample start date-time (UTC); canonical event timestamp.","",
  "erdCalCOFIcufes","cufes_sample","latitude","latitude","DOUBLE","Sample start latitude, WGS84.","decimal_degrees",
  "erdCalCOFIcufes","cufes_sample","longitude","longitude","DOUBLE","Sample start longitude, WGS84.","decimal_degrees",
  "erdCalCOFIcufes","cufes_sample","start_temperature","start_temperature","DOUBLE","Sea surface temperature at sample start.","degC",
  "erdCalCOFIcufes","cufes_sample","start_salinity","start_salinity","DOUBLE","Sea surface salinity at sample start.","PSS-78",
  "erdCalCOFIcufes","cufes_sample","start_wind_speed","start_wind_speed","DOUBLE","Wind speed at sample start.","m/s",
  "erdCalCOFIcufes","cufes_sample","start_wind_direction","start_wind_direction","DOUBLE","Wind direction at sample start.","degrees",
  "erdCalCOFIcufes","cufes_sample","start_pump_speed","start_pump_speed","DOUBLE","CUFES pump speed at sample start.","",
  "erdCalCOFIcufes","cufes_sample","stop_time","datetime_end_utc","TIMESTAMP","Sample end date-time (UTC).","",
  "erdCalCOFIcufes","cufes_sample","stop_latitude","latitude_stop","DOUBLE","Sample end latitude.","decimal_degrees",
  "erdCalCOFIcufes","cufes_sample","stop_longitude","longitude_stop","DOUBLE","Sample end longitude.","decimal_degrees",
  "erdCalCOFIcufes","cufes_sample","stop_temperature","stop_temperature","DOUBLE","Sea surface temperature at sample end.","degC",
  "erdCalCOFIcufes","cufes_sample","stop_salinity","stop_salinity","DOUBLE","Sea surface salinity at sample end.","PSS-78",
  "erdCalCOFIcufes","cufes_sample","stop_wind_speed","stop_wind_speed","DOUBLE","Wind speed at sample end.","m/s",
  "erdCalCOFIcufes","cufes_sample","stop_wind_direction","stop_wind_direction","DOUBLE","Wind direction at sample end.","degrees",
  "erdCalCOFIcufes","cufes_sample","stop_pump_speed","stop_pump_speed","DOUBLE","CUFES pump speed at sample end.","",
  # egg-count columns (pivoted into cufes_measurement)
  "erdCalCOFIcufes","cufes_measurement","sardine_eggs","sardine_eggs","INTEGER","Sardine (Sardinops sagax) egg count.","count",
  "erdCalCOFIcufes","cufes_measurement","anchovy_eggs","anchovy_eggs","INTEGER","Northern anchovy (Engraulis mordax) egg count.","count",
  "erdCalCOFIcufes","cufes_measurement","jack_mackerel_eggs","jack_mackerel_eggs","INTEGER","Jack mackerel (Trachurus symmetricus) egg count.","count",
  "erdCalCOFIcufes","cufes_measurement","hake_eggs","hake_eggs","INTEGER","Pacific hake (Merluccius productus) egg count.","count",
  "erdCalCOFIcufes","cufes_measurement","squid_eggs","squid_eggs","INTEGER","Squid egg count.","count",
  "erdCalCOFIcufes","cufes_measurement","other_fish_eggs","other_fish_eggs","INTEGER","Other fish egg count.","count")
write_csv(flds, file.path(dir_meta, "flds_redefine.csv"), na = "")

derived <- tribble(
  ~table, ~column, ~name_long, ~units, ~description_md,
  "cufes_sample","cruise_key","Cruise Key","","CalCOFI cruise natural key, derived from cruise_orig + ship + date.",
  "cufes_sample","ship_key","Ship Key","","NODC ship key; FK to ship.",
  "cufes_sample","geom","Geometry","","Sample-start point geometry (WGS84).",
  "cufes_sample","grid_key","Grid Key","","CalCOFI grid cell from spatial join.",
  "cufes_measurement","cufes_measurement_id","CUFES Measurement ID","","Sequential primary key.",
  "cufes_measurement","sample_id","Sample ID","","FK to cufes_sample.")
write_csv(derived, file.path(dir_meta, "metadata_derived.csv"), na = "")

q <- tribble(
  ~id, ~question, ~context, ~status, ~priority, ~answer, ~asked_date, ~answered_date, ~who, ~related_table, ~related_field,
  "swfsc_cufes_01","Are the egg counts raw per-sample totals or standardized (e.g. per m^3 / per area)?","Determines whether to register the measurement as count vs a density.","open","high","","","","Noelle Bowlin; Ed Weber","cufes_measurement","measurement_value",
  "swfsc_cufes_02","Confirm wind_speed units (m/s vs knots) and pump_speed units on the ERDDAP feed.","ERDDAP variable metadata to be confirmed against erdCalCOFIcufes .das.","open","normal","","","","Noelle Bowlin; Ed Weber","cufes_sample","start_wind_speed")
write_csv(q, file.path(dir_meta, "questions.csv"), na = "")

ds_path <- here("metadata/dataset.csv")
ds <- read_csv(ds_path, show_col_types = FALSE) |> filter(!(provider=="swfsc" & dataset=="cufes"))
ds_new <- tibble(
  provider="swfsc", dataset="cufes", dataset_name="CalCOFI Underway CUFES Fish Eggs",
  description="Continuous Underway Fish Egg Sampler (CUFES) egg counts (sardine, anchovy, jack mackerel, hake, squid, other) with underway environmental conditions, from CalCOFI cruises. Source: NOAA CoastWatch ERDDAP erdCalCOFIcufes.",
  citation_main="", citation_others="",
  link_calcofi_org="", link_data_source="https://coastwatch.pfeg.noaa.gov/erddap/tabledap/erdCalCOFIcufes.html",
  link_others="", tables="cufes_sample; cufes_measurement",
  coverage_temporal="1996/present", coverage_spatial="CalCOFI region (underway)",
  license="", pi_names="Noelle Bowlin")
write_csv(bind_rows(ds, ds_new), ds_path, na = "")
cat("wrote cufes metadata:", nrow(tbls), "tbls,", nrow(flds), "flds,", nrow(derived), "derived,", nrow(q), "questions\n")
