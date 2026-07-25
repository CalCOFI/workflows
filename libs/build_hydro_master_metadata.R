# libs/build_hydro_master_metadata.R
# -----------------------------------------------------------------------------
# Phase 2 of the Access hydro-master port: harvest the self-documenting metadata
# layer out of the extracted Parquet into reviewable CSV registries.
#
# Depends on Phase 0 having run (scripts/extract_accdb.sh).
# Re-runnable and idempotent: every output is rewritten from source each time.
#
# DELIBERATELY DOES NOT WRITE INTO THE PRESCRIPTIVE REGISTRIES.
# metadata/field_dictionary.csv is prescriptive (canonical names new datasets
# conform to); the Access tables are descriptive of a 1949-era source schema
# (T_degC, Salnty, Cst_Cnt, ...). Injecting ~190 source-side names would corrupt
# it. Instead we emit a crosswalk for human review, and Phase 4/5 promotes
# whatever survives that review.
#
# Outputs
#   metadata/measurement_qual.csv                      repo-level controlled vocabulary
#   metadata/calcofi/hydro-master/
#     accdb_field_descriptions.csv   source-side field dictionary (merged)
#     accdb_field_crosswalk.csv      proposed source -> canonical mapping, for review
#     measurement_method.csv         method/accuracy/era provenance (1:many per measurement)
#     station_code.csv               Sta_Code semantics
#     ship_crosswalk.csv             Access ships vs the repo ship registry
#     change_log.csv                 280-row dated change log
#     questions.csv                  everything queued for data-manager review

suppressMessages({
  library(dplyr); library(readr); library(stringr); library(tidyr)
  library(purrr); library(glue); library(here); library(fs); library(DBI)
})

dir_pq   <- here("data/accdb/calcofi_hydro-master/tables")
dir_out  <- here("metadata/calcofi/hydro-master")
dir_create(dir_out)

con <- calcofi4db::get_duckdb_con(":memory:")
on.exit(try(dbDisconnect(con, shutdown = TRUE), silent = TRUE), add = TRUE)
rd <- function(tbl) dbGetQuery(con, glue(
  "SELECT * FROM read_parquet('{dir_pq}/{tbl}.parquet')")) |> as_tibble()

# normalize an identifier for fuzzy matching across naming conventions.
# transliterates the micro sign so Oxy_µmol/Kg meets oxy_umol_kg.
norm_id <- function(x) {
  x |>
    str_replace_all("[µμ]", "u") |>
    str_to_lower() |>
    str_remove_all("[^a-z0-9]")
}

questions <- list()
ask <- function(id, question, context, priority = "medium",
                related_table = "", related_field = "", who = "CalCOFI data manager") {
  questions[[length(questions) + 1]] <<- tibble(
    id = id, question = question, context = context, status = "open",
    priority = priority, answer = "", asked_date = Sys.Date(), answered_date = "",
    who = who, related_table = related_table, related_field = related_field)
  invisible(NULL)
}

# -- source-side field dictionary ---------------------------------------------
# two Access tables split the job: `0-Field Descriptions` documents the core
# tables (Bottle, Cast, ...), `0-Categories` the rest. Same shape; union them.
d_fdesc <- rd("0-Field_Descriptions") |>
  select(table_name = Table_Name, field_name = Field_Name,
         units = Units, values = Values, description = Description) |>
  mutate(source = "0-Field Descriptions")

d_cats <- rd("0-Categories") |>
  select(table_name = Table_Name, field_name = Field_Name,
         units = Units, values = Values, description = Description) |>
  mutate(source = "0-Categories")

d_fields <- bind_rows(d_fdesc, d_cats) |>
  filter(!is.na(field_name), field_name != "") |>
  mutate(across(where(is.character), \(x) na_if(str_trim(x), ""))) |>
  arrange(table_name, field_name) |>
  distinct(table_name, field_name, .keep_all = TRUE)

write_csv(d_fields, file.path(dir_out, "accdb_field_descriptions.csv"), na = "")
cat("accdb_field_descriptions.csv:", nrow(d_fields), "fields across",
    n_distinct(d_fields$table_name), "tables\n")

# -- crosswalk source fields -> canonical registries ---------------------------
d_dict <- read_csv(here("metadata/field_dictionary.csv"), show_col_types = FALSE)
d_mt   <- read_csv(here("metadata/measurement_type.csv"), show_col_types = FALSE)

lut_canon <- d_dict |>
  transmute(key = norm_id(fld_new), target = fld_new, match_type = "canonical_field")

lut_alias <- d_dict |>
  select(fld_new, aliases) |>
  filter(!is.na(aliases)) |>
  separate_longer_delim(aliases, ";") |>
  transmute(key = norm_id(str_trim(aliases)), target = fld_new, match_type = "alias") |>
  filter(key != "")

lut_meas <- d_mt |>
  filter(!is.na(`_source_column`), str_detect(coalesce(`_source_datasets`, ""), "calcofi_bottle")) |>
  transmute(key = norm_id(`_source_column`), target = measurement_type,
            match_type = "measurement_type")

lut <- bind_rows(lut_canon, lut_alias, lut_meas) |> distinct(key, .keep_all = TRUE)

d_crosswalk <- d_fields |>
  mutate(key = norm_id(field_name)) |>
  left_join(lut, by = "key") |>
  mutate(match_type = coalesce(match_type, "unmatched"),
         target     = coalesce(target, "")) |>
  select(table_name, field_name, match_type, canonical_target = target,
         units, description) |>
  arrange(match_type, table_name, field_name)

write_csv(d_crosswalk, file.path(dir_out, "accdb_field_crosswalk.csv"), na = "")
tally_cw <- count(d_crosswalk, match_type)
cat("accdb_field_crosswalk.csv:",
    paste(glue("{tally_cw$match_type}={tally_cw$n}"), collapse = ", "), "\n")

n_unmatched <- sum(d_crosswalk$match_type == "unmatched")
ask("hydro_master_01",
    glue("Which of the {n_unmatched} unmatched Access fields should be promoted to ",
         "canonical names in metadata/field_dictionary.csv?"),
    paste("accdb_field_crosswalk.csv maps every documented Access field against the",
          "canonical dictionary (by name, alias, or measurement_type _source_column).",
          "Unmatched fields are either genuinely new concepts worth adopting or",
          "1949-era source artifacts to leave behind. field_dictionary.csv is",
          "prescriptive, so nothing was auto-merged."),
    priority = "high", related_table = "field_dictionary")

# -- measurement_qual controlled vocabulary ------------------------------------
# documented in the Values column of the *q fields, verbatim:
#   "6= data OK but taken from CTD, 8= value is suspect, 9= missing data"
d_documented <- tribble(
  ~qual_code, ~label,          ~description,
  "6",        "ok_from_ctd",   "Data OK but taken from CTD",
  "8",        "suspect",       "Value is suspect",
  "9",        "missing",       "Missing data")

qual_cols <- c("T_qual", "S_qual", "P_qual", "O_qual", "SThtaq", "O2Satq")
prec_cols <- c("T_prec", "S_prec")

observed <- map_df(qual_cols, \(cl) dbGetQuery(con, glue(
  "SELECT '{cl}' AS column_name, \"{cl}\" AS qual_code, COUNT(*) AS n
   FROM read_parquet('{dir_pq}/Bottle_Q.parquet')
   WHERE \"{cl}\" IS NOT NULL GROUP BY 1, 2")) |> as_tibble()) |>
  mutate(code_int = suppressWarnings(as.integer(qual_code)))

# full per-column diagnostic — kept OUT of the vocabulary file on purpose.
# S_qual alone has 253 distinct values; pooling them would drown a 3-code
# controlled vocabulary in what is almost certainly corruption.
write_csv(observed |> arrange(column_name, desc(n)) |> select(-code_int),
          file.path(dir_out, "qual_code_observed.csv"), na = "")

# the vocabulary proper: single-digit codes only. Anything >= 10 is treated as
# anomalous and reported separately rather than legitimized as a code.
d_qual <- observed |>
  filter(!is.na(code_int), code_int >= 0, code_int <= 9) |>
  group_by(qual_code) |>
  summarise(n_observed     = sum(n),
            source_columns = paste(sort(unique(column_name)), collapse = ";"),
            .groups = "drop") |>
  full_join(d_documented, by = "qual_code") |>
  mutate(
    is_documented  = qual_code %in% d_documented$qual_code,
    n_observed     = coalesce(n_observed, 0),
    label          = coalesce(label, "UNDOCUMENTED"),
    description    = coalesce(description,
                              "Observed in Bottle_Q but absent from the source documentation"),
    source_columns = coalesce(source_columns, ""),
    source         = "accdb 0-Field Descriptions / 0-Categories (Values column)") |>
  arrange(desc(is_documented), suppressWarnings(as.integer(qual_code)))

write_csv(d_qual, here("metadata/measurement_qual.csv"), na = "")
cat("measurement_qual.csv:", sum(d_qual$is_documented), "documented +",
    sum(!d_qual$is_documented), "observed-undocumented single-digit codes\n")

d_anom <- observed |> filter(is.na(code_int) | code_int > 9)
cat("qual_code_observed.csv:", nrow(observed), "column x code pairs;",
    nrow(d_anom), "anomalous (code > 9)\n")

undoc <- d_qual |> filter(!is_documented, n_observed > 0) |> arrange(desc(n_observed))
if (nrow(undoc) > 0) {
  ask("hydro_master_02",
      glue("What do the undocumented single-digit Bottle_Q quality codes mean? Observed: ",
           paste(glue("{undoc$qual_code} (n={format(undoc$n_observed, big.mark=',')})"),
                 collapse = ", "), "."),
      paste("The source documents only 6/8/9 ('data OK but taken from CTD' /",
            "'value is suspect' / 'missing data'), but T_qual uses 0-7 and P_qual uses",
            "3/5/7 as well. measurement_qual is currently passed through uninterpreted by",
            "the pipeline, so these need meanings before any value-level QC can trust the",
            "flag. Full per-column counts are in qual_code_observed.csv."),
      priority = "blocker", related_table = "Bottle_Q",
      related_field = paste(qual_cols, collapse = ";"))
}

n_sq <- observed |> filter(column_name == "S_qual") |> nrow()
n_sq_hi <- observed |> filter(column_name == "S_qual", code_int > 9) |> summarise(n = sum(n)) |> pull(n)
ask("hydro_master_02b",
    glue("S_qual holds {n_sq} distinct values, most outside any plausible flag vocabulary ",
         "(a dense 256-271 cluster, plus teens and 30s) across {format(n_sq_hi, big.mark=',')} ",
         "rows. Is this a bitmask, or a corrupted column?"),
    paste("Every other quality column is well behaved: O_qual has exactly 3 distinct",
          "values, SThtaq and O2Satq have 4, T_qual 10. S_qual having 253 is a different",
          "kind of thing. The 256-271 clustering (256 + a low nibble) looks like bit 8 of",
          "a bitmask being set, which would mean S_qual is not a single code at all.",
          "Until this is resolved, salinity quality cannot be interpreted and any ported",
          "salinity QC rule would be built on sand."),
    priority = "blocker", related_table = "Bottle_Q", related_field = "S_qual")

d_prec <- map_df(prec_cols, \(cl) dbGetQuery(con, glue(
  "SELECT '{cl}' AS column_name, \"{cl}\" AS prec_value, COUNT(*) AS n
   FROM read_parquet('{dir_pq}/Bottle_Q.parquet')
   WHERE \"{cl}\" IS NOT NULL GROUP BY 1, 2 ORDER BY n DESC")) |> as_tibble())

ask("hydro_master_03",
    "Do T_prec / S_prec record decimal places of the reported value, and what are the out-of-range values?",
    glue("Modal values are small integers (1-5), consistent with decimal places, but ",
         "T_prec also has 33/34 and S_prec has 102/103. Distinct values: T_prec = ",
         paste(sort(unique(d_prec$prec_value[d_prec$column_name == 'T_prec'])), collapse = ","),
         "; S_prec = ",
         paste(sort(unique(d_prec$prec_value[d_prec$column_name == 'S_prec'])), collapse = ","), "."),
    priority = "medium", related_table = "Bottle_Q", related_field = "T_prec;S_prec")

n_p9 <- dbGetQuery(con, glue(
  "SELECT COUNT(*) n FROM read_parquet('{dir_pq}/Bottle_Q.parquet') WHERE P_qual = '9'"))$n
n_btl <- dbGetQuery(con, glue(
  "SELECT COUNT(*) n FROM read_parquet('{dir_pq}/Bottle_Q.parquet')"))$n
ask("hydro_master_04",
    glue("P_qual = 9 ('missing data') on {format(n_p9, big.mark=',')} of ",
         "{format(n_btl, big.mark=',')} bottles ({round(100*n_p9/n_btl)}%). Is phosphate ",
         "genuinely absent for those, or is 9 an unset default?"),
    paste("This decides whether a released null means 'not measured' or 'measured and",
          "rejected', which changes every downstream completeness statistic.",
          "NULL (no flag) is the modal state for the other quality columns, so a",
          "literal 9 may carry different intent."),
    priority = "high", related_table = "Bottle_Q", related_field = "P_qual")

ask("hydro_master_05",
    "Should a NULL quality flag be read as 'good', or as 'never assessed'?",
    paste("NULL is the modal value for T_qual, S_qual, O_qual, SThtaq and O2Satq",
          "(700k-885k rows each). The documented vocabulary has no 'good' code, so",
          "'good' is currently implicit in the absence of a flag. The pipeline needs",
          "this stated before it can interpret measurement_qual rather than pass it through."),
    priority = "high", related_table = "Bottle_Q")

# -- measurement method / accuracy provenance ---------------------------------
# NOTE: deliberately its own registry, not extra columns on measurement_type.csv.
# 0-Measurements is one-to-many per measurement (Temperature has 6 method eras,
# Chlorophyll and Phosphate 4 each) — flattening it onto measurement_type would
# silently discard the instrument history, which is the whole value here.
d_method <- rd("0-Measurements") |>
  transmute(
    measurement_name = Name,
    description      = Description,
    units            = Units,
    accuracy         = Accuracy,
    year_started     = str_sub(Year_started, 1, 10),
    year_ended       = str_sub(Year_ended, 1, 10),
    method           = Method) |>
  mutate(across(where(is.character), \(x) na_if(str_trim(x), ""))) |>
  arrange(measurement_name, year_started)

# explicit seed map, not fuzzy matching. The Access descriptions are 1949-era
# shorthand ("Sil", "PO4-P", "O2") that shares no substring with the canonical
# keys, so string similarity links nothing (verified: 0 matches) and any looser
# rule would mis-link silently. Ambiguous entries are left blank for review
# rather than guessed — see question hydro_master_06.
seed_mt <- tribble(
  ~description,                 ~measurement_type,
  "Temperature of the water",   "temperature",
  "Salinity",                   "salinity",
  "O2",                         "oxygen_ml_l",
  "PO4",                        "phosphate",
  "PO4-P",                      "phosphate",       # historic ug-at/L era
  "NO3",                        "nitrate",
  "NO2",                        "nitrite",
  "Sil",                        "silicate",
  "NH4",                        "ammonia",
  "Chl",                        "chlorophyll_a",
  "Phaeo",                      "phaeopigment",
  "Dissolved Inorganic Carbon", "dic",
  "Total Alkalinity",           "alkalinity")
  # deliberately unmapped: "Dry Temp"/"Wet Temp" (Weather, not bottle),
  # "Bottom Depth"/"Bottle Depth" (depth fields, not measurements),
  # "Primary Productivity" (maps to the c14_* family, which one is unclear),
  # bare "Temperature" (bathythermograph vs thermitow era, ambiguous)

valid_mt <- unique(d_mt$measurement_type)
stopifnot(all(seed_mt$measurement_type[seed_mt$measurement_type != ""] %in% valid_mt))

d_method <- d_method |>
  left_join(seed_mt, by = "description") |>
  select(measurement_name, description, measurement_type, units, accuracy,
         year_started, year_ended, method)

write_csv(d_method, file.path(dir_out, "measurement_method.csv"), na = "")
n_linked <- sum(!is.na(d_method$measurement_type))
cat("measurement_method.csv:", nrow(d_method), "method-eras,", n_linked, "auto-linked to measurement_type\n")

ask("hydro_master_06",
    glue("Confirm the mapping from the {nrow(d_method)} 0-Measurements method-eras to ",
         "canonical measurement_type ({n_linked} auto-linked, {nrow(d_method) - n_linked} unresolved)."),
    paste("0-Measurements records instrument/method, stated accuracy, and start/end",
          "dates per measurement — provenance the repo has nowhere else. It is",
          "one-to-many (Temperature has 6 eras, e.g. reversing thermometer through",
          "1993-04-15 then CTD thermistor from 1993-08-11), so it is kept as its own",
          "registry rather than columns on measurement_type.csv. Auto-linking is by",
          "name text only and needs domain confirmation (e.g. 'Sil' -> silicate)."),
    priority = "high", related_table = "measurement_type")

# -- station codes -------------------------------------------------------------
d_stacode <- rd("0-Sta_Code")
names(d_stacode) <- make.unique(names(d_stacode))
write_csv(d_stacode, file.path(dir_out, "station_code.csv"), na = "")
cat("station_code.csv:", nrow(d_stacode), "codes\n")

ask("hydro_master_07",
    "Do the Sta_Code categories (ST, SCO, NRO, OCO, IMX, NST, MBR) still carry meaning in the released site model?",
    paste("Access uses Sta_Code to separate standard CalCOFI stations from SCCOOS,",
          "IMECOCAL, MBARI, not-regularly-occupied and non-standard stations, and the",
          "TR/TQ test queries filter on it. The release's site/grid model has no",
          "equivalent flag, so ported coverage checks have nothing to filter on."),
    priority = "medium", related_table = "site", related_field = "Sta_Code")

# -- ship crosswalk ------------------------------------------------------------
d_ships_accdb <- rd("0-Ships") |>
  transmute(accdb_ship_code = Ship_Code, accdb_ship = Ship,
            accdb_ship_name = Ship_Name, operator = Operator)
d_ship_renames <- read_csv(here("metadata/ship_renames.csv"), show_col_types = FALSE)

d_ship_cw <- d_ships_accdb |>
  mutate(key = norm_id(accdb_ship_code)) |>
  left_join(d_ship_renames |> transmute(key = norm_id(csv_code), repo_ship_name = csv_name,
                                        repo_code_new = csv_code_new),
            by = "key") |>
  mutate(in_repo_renames = !is.na(repo_ship_name)) |>
  select(-key) |>
  arrange(desc(in_repo_renames), accdb_ship_code)

write_csv(d_ship_cw, file.path(dir_out, "ship_crosswalk.csv"), na = "")
cat("ship_crosswalk.csv:", nrow(d_ship_cw), "Access ships,",
    sum(d_ship_cw$in_repo_renames), "matched to ship_renames.csv\n")

# -- change log ----------------------------------------------------------------
d_changes <- rd("0-Work_Done") |>
  transmute(date = str_sub(Date, 1, 10), note = Note, initials = Initial) |>
  filter(!is.na(note), note != "") |>
  arrange(date)

write_csv(d_changes, file.path(dir_out, "change_log.csv"), na = "")
cat("change_log.csv:", nrow(d_changes), "entries,",
    min(d_changes$date, na.rm = TRUE), "to", max(d_changes$date, na.rm = TRUE), "\n")

ask("hydro_master_08",
    "Which 0-Work Done corrections were applied only inside Access, and so are missing from the published CSVs the pipeline ingests?",
    paste("The 280-row change log records dated, initialled repairs (cruise renumbering,",
          "duplicate interpolated levels, station-date fixes). If any were applied to the",
          "Access master but never propagated to the distributed bottle CSVs, the release",
          "is carrying errors this database already fixed. Phase 3 reconciliation will",
          "surface candidates; this asks which are known."),
    priority = "high", related_table = "change_log")

# -- questions carried forward from Phase 1 ------------------------------------
ask("hydro_master_09",
    "TQ - StationNameChecker compares Rpt_Line > \"76.6\" as a STRING — port the bug or the intent?",
    paste("Access compares these as text, so line 100 sorts below line 76.6 and is",
          "excluded from the check. Porting faithfully reproduces a 20-year blind spot;",
          "porting the intent (numeric comparison) changes which rows the check returns",
          "and may surface a backlog of previously invisible failures."),
    priority = "high", related_table = "Cast", related_field = "Rpt_Line")

ask("hydro_master_10",
    "The QC-DIC_* checks are hardcoded to single cruises (e.g. Cruise = 201507). What is the intended scope when generalized?",
    paste("Five QC queries filter to one cruise, suggesting they were ad-hoc",
          "investigations rather than standing checks. Parameterizing them is trivial;",
          "knowing whether they should run over all cruises, or only where DIC exists,",
          "is not."),
    priority = "medium", related_table = "DICs")

ask("hydro_master_11",
    "Please supply the SQL for 'Anomalies ISL 0 IM' — Jackcess cannot extract it.",
    paste("It is the only one of 155 queries that fails extraction",
          "(IllegalStateException: Inconsistent join types for Cast and Bottle), because",
          "it mixes inner and outer joins on the same table pair. Anyone with Access can",
          "open it in SQL View and paste the text; everything else was recovered."),
    priority = "medium", related_table = "Cast")

ask("hydro_master_12",
    "What fitting procedure and reference period produced the HarmCoeff* harmonic coefficients?",
    paste("HarmCoeffBottle/Chla/Sigma/LogZoo give mean, amplitude, frequency, phase and",
          "stdev per station x depth — an expected-value climatology, and the basis for",
          "the anomaly and outlier checks. Phase 6 plans to recompute them from the",
          "release and assert agreement, which needs the original period, harmonics",
          "fitted, and any QC screening applied to the input."),
    priority = "medium", related_table = "HarmCoeffBottle")

ask("hydro_master_13",
    "Bottle has 909,076 rows but BottleData_194903_202304 has 909,068 — which 8 rows differ, and which table is authoritative?",
    paste("BottleData_194903_202304 looks like the published extract of Bottle. An 8-row",
          "delta between the working table and its published form should have an",
          "explanation; Phase 3 reconciliation will identify the rows."),
    priority = "medium", related_table = "Bottle")

# -- write questions -----------------------------------------------------------
d_questions <- bind_rows(questions)
write_csv(d_questions, file.path(dir_out, "questions.csv"), na = "")
cat("questions.csv:", nrow(d_questions), "queued (",
    paste(glue("{names(table(d_questions$priority))}={as.integer(table(d_questions$priority))}"),
          collapse = ", "), ")\n")
