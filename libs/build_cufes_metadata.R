# build_cufes_metadata.R
# author the redefinition files of metadata/swfsc/cufes/ for ingest_swfsc_cufes.qmd.
#
# Source (since 2026-10-04, WS-1004Z): SWFSC's own CSV export of its CalCOFI
# database, `Cufes.csv` in the provider folder
# `{dir_data}/swfsc/ichthyo/` (Ed Weber added it on 2026-09-26, linked to
# `Cruise.csv` by `CruiseId`). Until then the ingest read NOAA CoastWatch ERDDAP
# `erdCalCOFIcufes`; the CSV holds every ERDDAP record except the 1,583 Ed
# removed at source (no start position, questions Q04), with identical values.
#
# fld_new is the lower snake_case of the source column, except the identifiers
# (CufesId -> cufes_uuid, CruiseId -> cruise_uuid, Ship -> ship_key) and the
# two timestamps (Start/Stop -> datetime_start_utc/datetime_end_utc). Every
# source column is kept, the cruise designation `Cruise` included (never drop a
# source cruise column as "derivable"). Units: wind speed in knots and pump speed
# in m3/min (Ed Weber, 2026-09-25, questions Q02).
#
# Re-runnable and idempotent. It writes ONLY the three redefinition files:
# questions.csv and dataset_meta.yml are hand-maintained and never rewritten here
# (the previous version of this script re-created questions.csv from scratch).

suppressMessages({library(readr); library(tibble); library(here); library(fs)})
dir_meta <- here("metadata/swfsc/cufes"); dir_create(dir_meta)

tbls <- tribble(
  ~tbl_old, ~tbl_new, ~tbl_description,
  "Cufes", "cufes",
  "One row per Continuous Underway Fish Egg Sampler (CUFES) sample, as exported by SWFSC (Cufes.csv): the sample's identifier, cruise and ship, start and stop time and position, underway temperature, salinity, wind and pump speed at each end, and the six egg counts.",
  "Cufes", "cufes_measurement",
  "Egg counts per CUFES sample in long form (measurement_type = <taxon>_eggs, units count) and the standardized concentration derived from them (<taxon>_eggs_per_m3, units count/m3).")
write_csv(tbls, file.path(dir_meta, "tbls_redefine.csv"), na = "")

flds <- tribble(
  ~tbl_old, ~tbl_new, ~fld_old, ~fld_new, ~type_new, ~fld_description, ~units,
  "Cufes", "cufes", "CufesId",            "cufes_uuid",           "UUID",      "SWFSC's identifier for the CUFES sample; keys sample_key and is released as sample.source_uuid.", "",
  "Cufes", "cufes", "CruiseId",           "cruise_uuid",          "UUID",      "SWFSC's identifier for the cruise, FK to cruise.cruise_uuid (Cruise.csv); resolves cruise_key.", "",
  "Cufes", "cufes", "Cruise",             "cruise",               "VARCHAR",   "SWFSC's cruise designation (YYYYMM) as shipped; cross-checked against cruise_key.", "",
  "Cufes", "cufes", "Ship",               "ship_key",             "VARCHAR",   "SWFSC ship code, FK to ship.ship_key.", "",
  "Cufes", "cufes", "SampleNumber",       "sample_number",        "INTEGER",   "CUFES sample number within the cruise.", "",
  "Cufes", "cufes", "Start",              "datetime_start_utc",   "TIMESTAMP", "Sample start date-time (UTC); the event timestamp.", "",
  "Cufes", "cufes", "StartLatitude",      "start_latitude",       "DOUBLE",    "Latitude where the sample started, WGS84.", "decimal_degrees",
  "Cufes", "cufes", "StartLongitude",     "start_longitude",      "DOUBLE",    "Longitude where the sample started, WGS84.", "decimal_degrees",
  "Cufes", "cufes", "StartTemperature",   "start_temperature",    "DOUBLE",    "Sea surface temperature at sample start.", "degC",
  "Cufes", "cufes", "StartSalinity",      "start_salinity",       "DOUBLE",    "Sea surface salinity at sample start.", "PSS-78",
  "Cufes", "cufes", "StartWindSpeed",     "start_wind_speed",     "DOUBLE",    "Wind speed at sample start (knots; Ed Weber, questions Q02).", "knots",
  "Cufes", "cufes", "StartWindDirection", "start_wind_direction", "DOUBLE",    "Wind direction at sample start.", "degrees",
  "Cufes", "cufes", "StartPumpSpeed",     "start_pump_speed",     "DOUBLE",    "CUFES pump speed at sample start (m3/min; Ed Weber, questions Q02).", "m3/min",
  "Cufes", "cufes", "Stop",               "datetime_end_utc",     "TIMESTAMP", "Sample stop date-time (UTC).", "",
  "Cufes", "cufes", "StopLatitude",       "stop_latitude",        "DOUBLE",    "Latitude where the sample stopped, WGS84.", "decimal_degrees",
  "Cufes", "cufes", "StopLongitude",      "stop_longitude",       "DOUBLE",    "Longitude where the sample stopped, WGS84.", "decimal_degrees",
  "Cufes", "cufes", "StopTemperature",    "stop_temperature",     "DOUBLE",    "Sea surface temperature at sample stop.", "degC",
  "Cufes", "cufes", "StopSalinity",       "stop_salinity",        "DOUBLE",    "Sea surface salinity at sample stop.", "PSS-78",
  "Cufes", "cufes", "StopWindSpeed",      "stop_wind_speed",      "DOUBLE",    "Wind speed at sample stop (knots; Ed Weber, questions Q02).", "knots",
  "Cufes", "cufes", "StopWindDirection",  "stop_wind_direction",  "DOUBLE",    "Wind direction at sample stop.", "degrees",
  "Cufes", "cufes", "StopPumpSpeed",      "stop_pump_speed",      "DOUBLE",    "CUFES pump speed at sample stop (m3/min; Ed Weber, questions Q02).", "m3/min",
  # egg counts: raw counts, not standardized (Ed Weber, questions Q01); pivoted into cufes_measurement
  "Cufes", "cufes", "SardineEggs",        "sardine_eggs",         "INTEGER",   "Pacific sardine (Sardinops sagax) egg count.", "count",
  "Cufes", "cufes", "AnchovyEggs",        "anchovy_eggs",         "INTEGER",   "Northern anchovy (Engraulis mordax) egg count.", "count",
  "Cufes", "cufes", "JackMackerelEggs",   "jack_mackerel_eggs",   "INTEGER",   "Jack mackerel (Trachurus symmetricus) egg count.", "count",
  "Cufes", "cufes", "HakeEggs",           "hake_eggs",            "INTEGER",   "Pacific hake (Merluccius productus) egg count.", "count",
  "Cufes", "cufes", "SquidEggs",          "squid_eggs",           "INTEGER",   "Squid egg count.", "count",
  "Cufes", "cufes", "OtherFishEggs",      "other_fish_eggs",      "INTEGER",   "Other fish egg count.", "count")
write_csv(flds, file.path(dir_meta, "flds_redefine.csv"), na = "")

derived <- tribble(
  ~table, ~column, ~name_long, ~units, ~description_md,
  "cufes", "latitude",          "Latitude",            "decimal_degrees", "Sample position: the midpoint of the start and stop positions, else whichever end has both coordinates.",
  "cufes", "longitude",         "Longitude",           "decimal_degrees", "Sample position: the midpoint of the start and stop positions, else whichever end has both coordinates.",
  "cufes", "position_source",   "Position Source",     "",                "Which ends of the segment gave the position: `midpoint`, `start` or `stop`.",
  "cufes", "duration_min",      "Minutes Sampled",     "min",             "Stop minus start, in minutes.",
  "cufes", "pump_speed_mean",   "Mean Pump Speed",     "m3/min",          "Mean of the start and stop pump speeds.",
  "cufes", "volume_pumped_m3",  "Volume Pumped",       "m3",              "duration_min x pump_speed_mean: the water the sample filtered.",
  "cufes", "cruise_key",        "Cruise Key",          "",                "CalCOFI cruise natural key (YYYY-MM-NODC) of the cruise SWFSC's CruiseId names.",
  "cufes", "cruise_key_method", "Cruise Key Method",   "",                "How cruise_key was resolved: `cruise_uuid` (the provider's CruiseId), else resolve_cruise_key()'s `span` / `source` / `month`.",
  "cufes", "geom",              "Geometry",            "",                "Sample position as a point geometry (WGS84).",
  "cufes", "grid_key",          "Grid Key",            "",                "CalCOFI grid cell holding the sample position (assign_grid_key()).",
  "cufes_measurement", "cufes_measurement_id", "CUFES Measurement ID", "", "Sequential primary key.",
  "cufes_measurement", "cufes_uuid",           "CUFES UUID",           "", "FK to cufes.")
write_csv(derived, file.path(dir_meta, "metadata_derived.csv"), na = "")

cat("wrote cufes redefinitions:", nrow(tbls), "tbls,", nrow(flds), "flds,", nrow(derived), "derived\n")
