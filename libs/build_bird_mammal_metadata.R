# build_bird_mammal_metadata.R
# scaffold metadata/calcofi/bird_mammal_census/ for the #29/#30 ingest.
# Source: whales-seabirds-turtles/bird-mammal-census/ (CCE-LTER DataZoo 255, Sydeman).
# 4 tables: transect (effort) + observation (counts) + species + behavior lookups.
# fld_new conforms to metadata/field_dictionary.csv. re-runnable & idempotent.

suppressMessages({library(readr); library(tibble); library(dplyr); library(here); library(fs)})
dir_meta <- here("metadata/calcofi/bird_mammal_census")
dir_create(dir_meta)

tbls <- tribble(
  ~tbl_old, ~tbl_new, ~tbl_description,
  "transects",      "bird_mammal_transect",
  "One row per survey transect segment (effort): position, time, dimensions, and bottom depth. Bird/mammal counts join from bird_mammal_observation on gis_key.",
  "observations",   "bird_mammal_observation",
  "Bird and mammal counts per transect segment: one row per (transect, species, behavior). count is the measurement; species_code -> bird_mammal_species, behavior_code -> bird_mammal_behavior.",
  "allspecieslist", "bird_mammal_species",
  "Species lookup for the census: 4-letter species_code with common/scientific name, ITIS id, and bird/mammal/fish flags.",
  "behaviorcodes",  "bird_mammal_behavior",
  "Behavior-code lookup for the census observations."
)
write_csv(tbls, file.path(dir_meta, "tbls_redefine.csv"), na = "")

flds <- tribble(
  ~tbl_old, ~tbl_new, ~fld_old, ~fld_new, ~type_new, ~fld_description, ~units,
  # -- transect (effort) --
  "transects","bird_mammal_transect","GIS key","gis_key","VARCHAR","Transect-segment identifier; primary key. Joins observations.","",
  "transects","bird_mammal_transect","Cruise","cruise_label","VARCHAR","Source cruise label (e.g. CAC1987_05); cruise_key derived from it.","",
  "transects","bird_mammal_transect","Transect number","transect_number","INTEGER","Transect number within the cruise.","",
  "transects","bird_mammal_transect","Bin number","bin_number","INTEGER","Bin (segment) number within the transect.","",
  "transects","bird_mammal_transect","Date","date","DATE","Survey date.","",
  "transects","bird_mammal_transect","Time (sec)","time_sec","DOUBLE","Time of day in seconds (local); combined with date into datetime_start_utc.","s",
  "transects","bird_mammal_transect","Latitude Mid (º)","latitude","DOUBLE","Latitude of the transect-segment midpoint, WGS84.","decimal_degrees",
  "transects","bird_mammal_transect","Longitude Mid (º)","longitude","DOUBLE","Longitude of the transect-segment midpoint, WGS84.","decimal_degrees",
  "transects","bird_mammal_transect","Latitude Start (º)","latitude_start","DOUBLE","Latitude at segment start.","decimal_degrees",
  "transects","bird_mammal_transect","Longitude Start (º)","longitude_start","DOUBLE","Longitude at segment start.","decimal_degrees",
  "transects","bird_mammal_transect","Latitude Stop (º)","latitude_stop","DOUBLE","Latitude at segment stop.","decimal_degrees",
  "transects","bird_mammal_transect","Longitude Stop (º)","longitude_stop","DOUBLE","Longitude at segment stop.","decimal_degrees",
  "transects","bird_mammal_transect","Length (m)","length_m","DOUBLE","Transect-segment length.","m",
  "transects","bird_mammal_transect","Width (m)","width_m","DOUBLE","Transect strip width.","m",
  "transects","bird_mammal_transect","Area (m²)","area_m2","DOUBLE","Surveyed area of the segment.","m2",
  "transects","bird_mammal_transect","Depth (m)","bottom_depth_m","DOUBLE","Seafloor depth at the segment (negative = below sea level in source).","m",
  "transects","bird_mammal_transect","Julian date","julian_date","DOUBLE","Julian date.","",
  "transects","bird_mammal_transect","Julian day","julian_day","INTEGER","Julian day of year.","",
  "transects","bird_mammal_transect","SVY","svy","VARCHAR","Survey/cruise-program code (CalCOFI, NMFS, CPR).","",
  "transects","bird_mammal_transect","Season","season","VARCHAR","Season of the survey.","",
  # -- observation (counts) --
  "observations","bird_mammal_observation","GIS key","gis_key","VARCHAR","Transect-segment identifier; FK to bird_mammal_transect.","",
  "observations","bird_mammal_observation","Species","species_code","VARCHAR","Species code; FK to bird_mammal_species.","",
  "observations","bird_mammal_observation","Behavior","behavior_code","VARCHAR","Behavior code; FK to bird_mammal_behavior.","",
  "observations","bird_mammal_observation","Count","count","INTEGER","Number of individuals observed.","count",
  # -- species lookup --
  "allspecieslist","bird_mammal_species","Species","species_code","VARCHAR","Species code (4-letter); primary key.","",
  "allspecieslist","bird_mammal_species","Common Name","common_name","VARCHAR","Common (vernacular) name.","",
  "allspecieslist","bird_mammal_species","Latin Name","scientific_name","VARCHAR","Scientific (Latin) name.","",
  "allspecieslist","bird_mammal_species","ITIS","itis_id","INTEGER","ITIS Taxonomic Serial Number.","",
  "allspecieslist","bird_mammal_species","Bird","is_bird","BOOLEAN","TRUE if the taxon is a bird.","",
  "allspecieslist","bird_mammal_species","Mammal","is_mammal","BOOLEAN","TRUE if the taxon is a mammal.","",
  "allspecieslist","bird_mammal_species","Fish","is_fish","BOOLEAN","TRUE if the taxon is a fish.","",
  "allspecieslist","bird_mammal_species","LargeBird","is_large_bird","BOOLEAN","TRUE if classified as a large bird.","",
  "allspecieslist","bird_mammal_species","Unidentified","is_unidentified","BOOLEAN","TRUE if the record is unidentified to species.","",
  "allspecieslist","bird_mammal_species","Include","include_flag","BOOLEAN","Provider inclusion flag.","",
  "allspecieslist","bird_mammal_species","NMFS","nmfs_code","VARCHAR","NMFS species code (if any).","",
  "allspecieslist","bird_mammal_species","Comment","comment","VARCHAR","Free-text comment.","",
  # -- behavior lookup --
  "behaviorcodes","bird_mammal_behavior","ID","behavior_code","VARCHAR","Behavior code; primary key.","",
  "behaviorcodes","bird_mammal_behavior","Behavior","behavior","VARCHAR","Behavior name.","",
  "behaviorcodes","bird_mammal_behavior","Description","description","VARCHAR","Behavior description.","")
write_csv(flds, file.path(dir_meta, "flds_redefine.csv"), na = "")

# derived columns/tables (schema: table,column,name_long,units,description_md)
derived <- tribble(
  ~table, ~column, ~name_long, ~units, ~description_md,
  "bird_mammal_transect","datetime_start_utc","Datetime UTC","","Survey date-time, built from date + time_sec (local tz unconfirmed; see questions).",
  "bird_mammal_transect","cruise_key","Cruise Key","","CalCOFI cruise natural key, best-effort from cruise_label + date (no ship column; see questions).",
  "bird_mammal_transect","grid_key","Grid Key","","CalCOFI grid-cell key from spatial join of the midpoint.",
  "bird_mammal_transect","geom","Geometry","","Midpoint geometry in WGS84 (EPSG:4326).",
  "bird_mammal_observation","observation_id","Observation ID","","Sequential primary key (one row per transect/species/behavior).")
write_csv(derived, file.path(dir_meta, "metadata_derived.csv"), na = "")

# questions for the provider (Sydeman / CCE-LTER)
q <- tribble(
  ~id, ~question, ~context, ~status, ~priority, ~answer, ~asked_date, ~answered_date, ~who, ~related_table, ~related_field,
  "calcofi_bmc_01","Is Time (sec) seconds-of-day in local (Pacific) time, and which timezone applies across the 1987-2021 record?","Needed to build datetime_start_utc correctly.","open","high","","","","Bill Sydeman; CCE-LTER IM","bird_mammal_transect","datetime_start_utc",
  "calcofi_bmc_02","How should the Cruise label (e.g. CAC1987_05) map to a CalCOFI cruise_key (YYYY-MM-NODC)? There is no ship column in the transect table.","Without a ship/NODC code, cruise_key can only be matched by year-month (ambiguous when multiple ships sailed). SVY distinguishes CalCOFI/NMFS/CPR programs.","open","high","","","","Bill Sydeman; CCE-LTER IM","bird_mammal_transect","cruise_key",
  "calcofi_bmc_03","Confirm the dataset provider/attribution for the CalCOFI DB (CalCOFI program vs CCE-LTER vs Farallon Institute).","Tentatively provider=calcofi; data curated via CCE-LTER DataZoo 255, PI Bill Sydeman (Farallon Institute).","open","normal","","","","Bill Sydeman; CCE-LTER IM","bird_mammal_transect","",
  "calcofi_bmc_04","Depth (m) values are negative (e.g. -3993). Is this bottom depth as negative elevation, and should we store positive-down?","Affects bottom_depth_m sign convention.","open","normal","","","","Bill Sydeman; CCE-LTER IM","bird_mammal_transect","bottom_depth_m")
write_csv(q, file.path(dir_meta, "questions.csv"), na = "")

# register in metadata/dataset.csv (idempotent)
ds_path <- here("metadata/dataset.csv")
ds <- read_csv(ds_path, show_col_types = FALSE) |>
  filter(!(provider == "calcofi" & dataset == "bird_mammal_census"))
ds_new <- tibble(
  provider="calcofi", dataset="bird_mammal_census",
  dataset_name="CalCOFI Bird & Mammal Census",
  description="Bird and mammal observations along CalCOFI (and NMFS, CPR) cruise transects, 1987-2021; transect effort + counts + species/behavior lookups. Curated via CCE-LTER DataZoo 255 (PI Bill Sydeman).",
  citation_main="", citation_others="",
  link_calcofi_org="", link_data_source="https://oceaninformatics.ucsd.edu/datazoo/catalogs/ccelter/datasets/255",
  link_others="http://dx.doi.org/10.6073/pasta/4ee1bd702acb11786277192a41626800",
  tables="bird_mammal_transect; bird_mammal_observation; bird_mammal_species; bird_mammal_behavior",
  coverage_temporal="1987/2021", coverage_spatial="CalCOFI region (CA Current)",
  license="", pi_names="Bill Sydeman")
write_csv(bind_rows(ds, ds_new), ds_path, na = "")

cat("wrote bird_mammal_census metadata:", nrow(tbls), "tbls,", nrow(flds), "flds,",
    nrow(derived), "derived,", nrow(q), "questions; registered in dataset.csv\n")
