# build_euphausiids_metadata.R
# scaffold metadata/cce-lter/euphausiids/ for the #26 ingest pilot.
# fld_new pre-filled from metadata/field_dictionary.csv (Latitude->latitude,
# Ship->ship_name, TowBegin->datetime_utc, ...). re-runnable & idempotent.

suppressMessages({library(readr); library(tibble); library(dplyr); library(here); library(fs)})
today    <- "2026-06-07"
dir_meta <- here("metadata/cce-lter/euphausiids")
dir_create(dir_meta)

# -- tbls_redefine -------------------------------------------------------------
tbls <- tribble(
  ~tbl_old, ~tbl_new, ~tbl_description,
  "data", "euphausiids_tow",
  "One row per euphausiid net tow: position, time, and cruise/ship/site keys. The Abundance measurement is pivoted into euphausiids_measurement. Source: CCE-LTER euphausiid abundance time series (data.csv)."
)
write_csv(tbls, file.path(dir_meta, "tbls_redefine.csv"), na = "")

# -- flds_redefine (fld_new from field_dictionary canonical names) -------------
flds <- tribble(
  ~tbl_old, ~tbl_new, ~fld_old, ~fld_new, ~type_old, ~type_new, ~order_old, ~order_new, ~fld_description, ~units, ~notes, ~mutation,
  "data","euphausiids_tow","RowNumber","tow_id","numeric","INTEGER",1,1,
    "Source row identifier; primary key (one row = one euphausiid tow).","","stable source counter used as PK","",
  "data","euphausiids_tow","Cruise","cruise_orig","character","VARCHAR",2,2,
    "Original cruise label as provided (e.g. 'CALCOFI 5511B', 'CALCOFI 1504'); cruise_key is derived from this with ship + date.","","mixed formats — see questions","",
  "data","euphausiids_tow","Ship","ship_name","character","VARCHAR",3,3,
    "Vessel name as provided; resolved to ship_key against the NODC ship registry.","","needs normalization: case, 'R/V ' prefix, double spaces — see questions","",
  "data","euphausiids_tow","Date","date","Date","DATE",4,4,
    "Tow date (redundant with datetime_utc from TowBegin; retained for QA).","","",
    "",
  "data","euphausiids_tow","Line","line","character","DOUBLE",5,5,
    "Alongshore component of the CalCOFI coordinate system.","","source stored as text","TRY_CAST(Line AS DOUBLE)",
  "data","euphausiids_tow","Station","station","character","DOUBLE",6,6,
    "Offshore component of the CalCOFI coordinate system.","","source stored as text","TRY_CAST(Station AS DOUBLE)",
  "data","euphausiids_tow","Region","region","character","VARCHAR",7,7,
    "Region label; constant 'All Regions' in this extract.","","single-valued — candidate to drop","",
  "data","euphausiids_tow","TowBegin","datetime_start_utc","character","TIMESTAMP",8,8,
    "Tow start date-time (UTC); canonical event timestamp.","","UTC vs local unconfirmed — see questions","CAST(TowBegin AS TIMESTAMP)",
  "data","euphausiids_tow","TowEnd","datetime_end_utc","timestamp","TIMESTAMP",9,9,
    "Tow end date-time (UTC).","","one row has year 2371 (typo), nulled at ingest — see questions","",
  "data","euphausiids_tow","Latitude","latitude","numeric","DOUBLE",10,10,
    "Latitude in decimal degrees, WGS84 (EPSG:4326).","decimal_degrees","one garbage value (lat 87.25) — see questions","",
  "data","euphausiids_tow","Longitude","longitude","numeric","DOUBLE",11,11,
    "Longitude in decimal degrees, WGS84 (EPSG:4326).","decimal_degrees","~15 rows positive (sign error), should be negative — see questions","",
  "data","euphausiids_tow","Abundance","abundance","numeric","DOUBLE",12,12,
    "Euphausiid abundance (units TBD — see questions); pivoted into euphausiids_measurement as measurement_type 'euphausiid_abundance'.","","raw measurement; pivoted to long format","")
write_csv(flds, file.path(dir_meta, "flds_redefine.csv"), na = "")

# -- metadata_derived (columns/tables created in the notebook, not in source) --
derived <- tribble(
  ~table_new, ~field_new, ~field_type, ~field_description, ~derivation,
  "euphausiids_tow","cruise_key","VARCHAR","Cruise natural key (YYYY-MM-NODC); FK to cruise.","derive_cruise_key_on_casts() / match cruise_orig + ship + date to cruise",
  "euphausiids_tow","ship_key","VARCHAR","NODC ship key; FK to ship.","resolve normalized ship_name via ship + metadata/ship_renames.csv",
  "euphausiids_tow","site_key","VARCHAR","CalCOFI station key 'LLL.L SSS.S'.","printf('%05.1f %05.1f', line, station)",
  "euphausiids_tow","geom","GEOMETRY","Point geometry (WGS84) from longitude/latitude.","add_point_geom(lon_col='longitude', lat_col='latitude')",
  "euphausiids_tow","grid_key","VARCHAR","CalCOFI grid cell; FK to grid.","assign_grid_key()",
  "euphausiids_measurement","euphausiids_measurement_id","INTEGER","Sequential primary key.","row_number()",
  "euphausiids_measurement","tow_id","INTEGER","FK to euphausiids_tow.","from euphausiids_tow",
  "euphausiids_measurement","measurement_type","VARCHAR","Measurement type; FK to measurement_type ('euphausiid_abundance').","constant",
  "euphausiids_measurement","measurement_value","DOUBLE","Abundance value (units per measurement_type).","from Abundance")
write_csv(derived, file.path(dir_meta, "metadata_derived.csv"), na = "")

# -- questions.csv (the provider-outreach deliverable) -------------------------
q <- tribble(
  ~id, ~question, ~context, ~status, ~priority, ~answer, ~asked_date, ~answered_date, ~who, ~related_table, ~related_field,
  "cce-lter_euphausiids_01",
  "What are the units and standardization of Abundance?",
  "Required to register the measurement type (e.g. individuals per 1000 m^3 standardized haul, or per m^2). Values range 0 to 53,489.5 with 60 zeros.",
  "open","blocker","","","","Rasmus Swalethorp; Linsey Sala","euphausiids_measurement","measurement_value",
  "cce-lter_euphausiids_02",
  "What taxonomic scope does each tow's Abundance represent - all euphausiid species combined, or a specific species/genus? Any life-stage restriction?",
  "No species column; needed to assign species_id/taxon and to publish to OBIS/EDI correctly.",
  "open","blocker","","","","Rasmus Swalethorp; Linsey Sala","euphausiids_tow","abundance",
  "cce-lter_euphausiids_03",
  "How should the Cruise label map to the CalCOFI cruise_key (YYYY-MM-NODC)?",
  "Labels are mixed: 'CALCOFI 5101', bare '7002', and prefixed 'CALCOFI BD5511B'; 253 distinct. Can you supply the NODC ship code or confirm YYMM parsing and the meaning of the BD prefix?",
  "open","high","","","","Rasmus Swalethorp; Linsey Sala","euphausiids_tow","cruise_orig",
  "cce-lter_euphausiids_04",
  "Can you confirm canonical vessel names for ship resolution?",
  "38 distinct names include duplicates differing only by case/prefix/spacing (e.g. 'New Horizon' vs 'NEW HORIZON', 'R/V BLACK  DOUGLAS' vs 'BLACK DOUGLAS'); we will normalize and resolve to the NODC ship_key.",
  "open","high","","","","Rasmus Swalethorp; Linsey Sala","euphausiids_tow","ship_name",
  "cce-lter_euphausiids_05",
  "About 15 tows have positive longitudes (+117 to +121) that look like sign errors, and one tow (RowNumber 10032, CALCOFI 1504) has lat 87.25 / lon -34.45 far outside the survey area. Flip sign / exclude?",
  "Affects spatial assignment and grid_key; we propose flipping obvious sign errors and dropping the 87.25 N point unless you can correct it.",
  "open","high","","","","Rasmus Swalethorp; Linsey Sala","euphausiids_tow","longitude",
  "cce-lter_euphausiids_06",
  "One tow has a TowEnd timestamp in year 2371 (out of range). What is the correct value?",
  "Likely a transcription error; we will null or correct it pending your answer.",
  "open","normal","","","","Rasmus Swalethorp; Linsey Sala","euphausiids_tow","tow_end_utc",
  "cce-lter_euphausiids_07",
  "Are TowBegin/TowEnd recorded in UTC or local (Pacific) time?",
  "datetime_utc is the cross-dataset match key to casts/cruises; a local-time assumption would bias matching.",
  "open","normal","","","","Rasmus Swalethorp; Linsey Sala","euphausiids_tow","datetime_utc",
  "cce-lter_euphausiids_08",
  "60 tows have Abundance exactly 0 - are these true absences (zero catch) or missing/not-recorded?",
  "Determines whether zeros are retained as real observations or treated as NA.",
  "open","normal","","","","Rasmus Swalethorp; Linsey Sala","euphausiids_measurement","measurement_value")
write_csv(q, file.path(dir_meta, "questions.csv"), na = "")

# -- register in metadata/dataset.csv (idempotent) -----------------------------
ds_path <- here("metadata/dataset.csv")
ds <- read_csv(ds_path, show_col_types = FALSE)
ds <- ds |> filter(!(provider == "cce-lter" & dataset == "euphausiids"))
ds_new <- tibble(
  provider          = "cce-lter",
  dataset           = "euphausiids",
  dataset_name      = "CCE-LTER Euphausiid Abundance",
  description       = "Euphausiid (krill) abundance from CalCOFI / CCE-LTER net tows, 1951-2019, one row per tow.",
  citation_main     = "",  # TBD — confirm with provider (question)
  citation_others   = "",
  link_calcofi_org  = "",
  link_data_source  = "https://portal.edirepository.org/ (EDI package TBD)",
  link_others       = "",
  tables            = "euphausiids_tow; euphausiids_measurement",
  coverage_temporal = "1951-01-17/2019-04-17",
  coverage_spatial  = "CalCOFI grid incl. Baja lines",
  license           = "",  # TBD
  pi_names          = "Rasmus Swalethorp; Linsey Sala")
ds <- bind_rows(ds, ds_new)
write_csv(ds, ds_path, na = "")

cat("wrote euphausiids metadata to", dir_meta, "\n")
cat("  tbls_redefine:", nrow(tbls), "| flds_redefine:", nrow(flds),
    "| derived:", nrow(derived), "| questions:", nrow(q), "\n")
cat("registered cce-lter/euphausiids in metadata/dataset.csv (", nrow(ds), "datasets)\n")
