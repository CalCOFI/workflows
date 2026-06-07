# build_phyllosoma_metadata.R
# scaffold metadata/calcofi/phyllosoma/ for the #33 ingest (lobster phyllosoma).
# Source: EDI knb-lter-cce.188.4 (single CSV). fld_new conforms to field_dictionary.
suppressMessages({library(readr); library(tibble); library(dplyr); library(here); library(fs)})
dir_meta <- here("metadata/calcofi/phyllosoma"); dir_create(dir_meta)

tbls <- tribble(
  ~tbl_old, ~tbl_new, ~tbl_description,
  "phyllosoma", "phyllosoma_tow",
  "One row per net tow with spiny lobster (Panulirus interruptus) phyllosoma larvae sampling: position, time, depth, volume filtered, aliquot. Counts by developmental stage are pivoted to phyllosoma_measurement.",
  "phyllosoma", "phyllosoma_measurement",
  "Phyllosoma larvae counts per tow in long form: measurement_type = total or developmental stage (1-11), measurement_value = count."
)
write_csv(tbls, file.path(dir_meta, "tbls_redefine.csv"), na = "")

flds <- tribble(
  ~tbl_old, ~tbl_new, ~fld_old, ~fld_new, ~type_new, ~fld_description, ~units,
  "phyllosoma","phyllosoma_tow","sorting_lab","sorting_lab","VARCHAR","Lab that sorted the sample.","",
  "phyllosoma","phyllosoma_tow","year_month_of_tow","cruise_orig","VARCHAR","Source cruise label (YYMM); cruise_key derived from it.","",
  "phyllosoma","phyllosoma_tow","tow_collection_day","date","DATE","Tow collection date.","",
  "phyllosoma","phyllosoma_tow","ship","ship_name","VARCHAR","Vessel name; resolved to ship_key.","",
  "phyllosoma","phyllosoma_tow","station_line","line","DOUBLE","CalCOFI alongshore line.","",
  "phyllosoma","phyllosoma_tow","station_number","station","DOUBLE","CalCOFI offshore station.","",
  "phyllosoma","phyllosoma_tow","latitude_o","latitude","DOUBLE","Latitude, WGS84.","decimal_degrees",
  "phyllosoma","phyllosoma_tow","longitude_o","longitude","DOUBLE","Longitude, WGS84.","decimal_degrees",
  "phyllosoma","phyllosoma_tow","max_tow_depth_m","max_tow_depth_m","DOUBLE","Maximum tow depth.","m",
  "phyllosoma","phyllosoma_tow","volume_water_filtered_ml_1000m3","volume_filtered","DOUBLE","Volume of water filtered (standardization factor).","ml/1000m3",
  "phyllosoma","phyllosoma_tow","aliquot_percent","aliquot_pct","DOUBLE","Aliquot percentage sorted.","percent",
  "phyllosoma","phyllosoma_tow","aliquot_adjustment_value","aliquot_adjustment","VARCHAR","Aliquot adjustment note/value.","",
  "phyllosoma","phyllosoma_tow","study_flag","study_flag","VARCHAR","Provider study flag.","",
  # stage-count columns (pivoted to phyllosoma_measurement)
  "phyllosoma","phyllosoma_measurement","total_phyllosoma","total_phyllosoma","INTEGER","Total phyllosoma count.","count",
  "phyllosoma","phyllosoma_measurement","stage_1","phyllosoma_stage_1","INTEGER","Stage 1 phyllosoma count.","count",
  "phyllosoma","phyllosoma_measurement","stage_2","phyllosoma_stage_2","INTEGER","Stage 2 phyllosoma count.","count",
  "phyllosoma","phyllosoma_measurement","stage_3","phyllosoma_stage_3","INTEGER","Stage 3 phyllosoma count.","count",
  "phyllosoma","phyllosoma_measurement","stage_4","phyllosoma_stage_4","INTEGER","Stage 4 phyllosoma count.","count",
  "phyllosoma","phyllosoma_measurement","stage_5","phyllosoma_stage_5","INTEGER","Stage 5 phyllosoma count.","count",
  "phyllosoma","phyllosoma_measurement","stage_6","phyllosoma_stage_6","INTEGER","Stage 6 phyllosoma count.","count",
  "phyllosoma","phyllosoma_measurement","stage_7","phyllosoma_stage_7","INTEGER","Stage 7 phyllosoma count.","count",
  "phyllosoma","phyllosoma_measurement","stage_8","phyllosoma_stage_8","INTEGER","Stage 8 phyllosoma count.","count",
  "phyllosoma","phyllosoma_measurement","stage_9","phyllosoma_stage_9","INTEGER","Stage 9 phyllosoma count.","count",
  "phyllosoma","phyllosoma_measurement","stage_10","phyllosoma_stage_10","INTEGER","Stage 10 phyllosoma count.","count",
  "phyllosoma","phyllosoma_measurement","stage_11","phyllosoma_stage_11","INTEGER","Stage 11 phyllosoma count.","count")
write_csv(flds, file.path(dir_meta, "flds_redefine.csv"), na = "")

derived <- tribble(
  ~table, ~column, ~name_long, ~units, ~description_md,
  "phyllosoma_tow","tow_id","Tow ID","","Sequential primary key (one row per tow).",
  "phyllosoma_tow","cruise_key","Cruise Key","","CalCOFI cruise natural key from cruise_orig + ship + date.",
  "phyllosoma_tow","ship_key","Ship Key","","NODC ship key; FK to ship.",
  "phyllosoma_tow","site_key","Site Key","","CalCOFI station key 'LLL.L SSS.S'.",
  "phyllosoma_tow","datetime_start_utc","Datetime UTC","","Tow date as timestamp (date only; no time in source).",
  "phyllosoma_tow","geom","Geometry","","Point geometry (WGS84).",
  "phyllosoma_tow","grid_key","Grid Key","","CalCOFI grid cell.",
  "phyllosoma_measurement","phyllosoma_measurement_id","Measurement ID","","Sequential primary key.",
  "phyllosoma_measurement","tow_id","Tow ID","","FK to phyllosoma_tow.")
write_csv(derived, file.path(dir_meta, "metadata_derived.csv"), na = "")

q <- tribble(
  ~id, ~question, ~context, ~status, ~priority, ~answer, ~asked_date, ~answered_date, ~who, ~related_table, ~related_field,
  "calcofi_phyllosoma_01","Are stage counts raw or standardized by Volume Water Filtered / Aliquot %?","Determines whether to standardize abundance; aliquot_pct + volume_filtered are provided for this.","open","high","","","","Koslow / EDI","phyllosoma_measurement","measurement_value",
  "calcofi_phyllosoma_02","Confirm the single species is Panulirus interruptus throughout (1951-2008).","Assigning species_id/taxon.","open","normal","","","","Koslow / EDI","phyllosoma_measurement","species_id")
write_csv(q, file.path(dir_meta, "questions.csv"), na = "")

ds_path <- here("metadata/dataset.csv")
ds <- read_csv(ds_path, show_col_types = FALSE) |> filter(!(provider=="calcofi" & dataset=="phyllosoma"))
ds_new <- tibble(
  provider="calcofi", dataset="phyllosoma", dataset_name="CalCOFI Lobster Phyllosoma",
  description="Spiny lobster (Panulirus interruptus) phyllosoma larvae counts by developmental stage from CalCOFI net tows, 1951-2008. Source: EDI knb-lter-cce.188.4 (Koslow).",
  citation_main="", citation_others="",
  link_calcofi_org="", link_data_source="https://portal.edirepository.org/nis/mapbrowse?packageid=knb-lter-cce.188.4",
  link_others="", tables="phyllosoma_tow; phyllosoma_measurement",
  coverage_temporal="1951/2008", coverage_spatial="CalCOFI region",
  license="", pi_names="J. Anthony Koslow")
write_csv(bind_rows(ds, ds_new), ds_path, na = "")
cat("wrote phyllosoma metadata:", nrow(tbls), "tbls,", nrow(flds), "flds,", nrow(derived), "derived,", nrow(q), "questions\n")
