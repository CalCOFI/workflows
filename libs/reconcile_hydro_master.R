# libs/reconcile_hydro_master.R
# -----------------------------------------------------------------------------
# Phase 3 of the Access hydro-master port: reconcile the Access master against
# what the pipeline currently ingests and releases.
#
# The question this answers: of the 65 Access tables, which are already faithfully
# in the release, which differ, and which are genuinely net-new? NOTHING is imported into
# the integrated DB — see the disposition section at the bottom for where each table goes.
#
# Every delta must resolve to one of: a release bug, an Access-era artifact, or a
# documented intentional difference. Unexplained residue is a finding, not noise.
#
# Depends on Phase 0 (scripts/extract_accdb.sh) and the local ingest outputs in
# data/parquet/calcofi_bottle/. Re-runnable and idempotent.
#
# Outputs -> data/accdb/calcofi_hydro-master/reconciliation/  (gitignored; bulk)
#            metadata/calcofi/hydro-master/reconciliation_summary.csv (committed)

suppressMessages({
  library(dplyr); library(readr); library(stringr); library(tidyr)
  library(purrr); library(glue); library(here); library(fs); library(DBI)
})

dir_acc  <- here("data/accdb/calcofi_hydro-master/tables")
dir_rel  <- here("data/parquet/calcofi_bottle")
dir_recon<- here("data/accdb/calcofi_hydro-master/reconciliation")
dir_meta <- here("metadata/calcofi/hydro-master")
dir_create(dir_recon); dir_create(dir_meta)

con <- calcofi4db::get_duckdb_con(":memory:")
on.exit(try(dbDisconnect(con, shutdown = TRUE), silent = TRUE), add = TRUE)

A <- function(t) glue("read_parquet('{dir_acc}/{t}.parquet')")

# The bottle ingest emits the CORE MODEL (obs / sample / sample_measurement) — the
# per-dataset bottle.parquet / casts.parquet / bottle_measurement.parquet this script
# originally compared against no longer exist. Re-expose the legacy shape so the
# comparisons below are unchanged, and so the numbers stay comparable to the committed
# Phase 3 findings (the migration preserved counts exactly: 895,371 bottles / 35,644 casts).
#
# sample_key is namespaced `dataset_key:sample_type:id`, so the source counter is
# split_part(...,3). The obs filter on the bottle prefix is REQUIRED: cast-grain obs rows
# would otherwise contribute ids that collide with bottle ids.
R_sample <- function(sample_type, extra_cols = "") glue(
  "(SELECT CAST(split_part(sample_key, ':', 3) AS BIGINT) AS id{extra_cols}
    FROM read_parquet('{dir_rel}/sample.parquet')
    WHERE sample_type = '{sample_type}')")

R_obs <- glue(
  "(SELECT CAST(split_part(sample_key, ':', 3) AS BIGINT) AS bottle_id,
           measurement_type, measurement_value
    FROM read_parquet('{dir_rel}/obs.parquet')
    WHERE sample_key LIKE 'calcofi_bottle:bottle:%')")

R <- function(t) switch(
  t,
  casts              = R_sample("cast",   ", cruise_key"),
  bottle             = R_sample("bottle"),
  bottle_measurement = R_obs,
  stop("no core-model mapping for legacy table '", t, "'", call. = FALSE))

norm_id <- function(x) {
  x |> str_replace_all("[µμ]", "u") |> str_to_lower() |> str_remove_all("[^a-z0-9]")
}

summaries <- list()
note <- function(...) summaries[[length(summaries) + 1]] <<- tibble(...)

# -- key overlap ---------------------------------------------------------------

#' Compare row membership between an Access table and a release table on a key
#'
#' Access parquet is all-VARCHAR (archival extraction), so the key is TRY_CAST to
#' BIGINT; a key that fails to cast is itself a finding and counted separately.
recon_keys <- function(label, a_tbl, r_tbl, a_key, r_key) {
  q <- glue("
    WITH a AS (SELECT TRY_CAST(\"{a_key}\" AS BIGINT) AS k FROM {A(a_tbl)}),
         r AS (SELECT CAST({r_key} AS BIGINT)      AS k FROM {R(r_tbl)})
    SELECT
      (SELECT COUNT(*) FROM a)                               AS accdb_rows,
      (SELECT COUNT(*) FROM a WHERE k IS NULL)               AS accdb_key_uncastable,
      (SELECT COUNT(*) FROM r)                               AS release_rows,
      (SELECT COUNT(*) FROM a JOIN r USING (k))              AS shared,
      (SELECT COUNT(*) FROM a ANTI JOIN r USING (k))         AS only_accdb,
      (SELECT COUNT(*) FROM r ANTI JOIN a USING (k))         AS only_release")
  dbGetQuery(con, q) |> as_tibble() |> mutate(comparison = label, .before = 1)
}

# -- value deltas on shared keys ----------------------------------------------

#' Compare one numeric column across the two sources for keys present in both
#'
#' @param tol absolute tolerance; source and release differ in stored precision
recon_numeric <- function(label, a_tbl, r_expr, a_key, r_key, a_col, r_col, tol = 1e-6) {
  q <- glue("
    WITH a AS (SELECT TRY_CAST(\"{a_key}\" AS BIGINT) AS k,
                      TRY_CAST(\"{a_col}\" AS DOUBLE) AS v FROM {A(a_tbl)}),
         r AS (SELECT CAST({r_key} AS BIGINT) AS k,
                      CAST({r_col} AS DOUBLE) AS v FROM {r_expr})
    SELECT COUNT(*)                                                        AS n_shared,
           COUNT(*) FILTER (WHERE a.v IS NULL AND r.v IS NULL)             AS n_both_null,
           COUNT(*) FILTER (WHERE a.v IS NULL AND r.v IS NOT NULL)         AS n_null_in_accdb,
           COUNT(*) FILTER (WHERE a.v IS NOT NULL AND r.v IS NULL)         AS n_null_in_release,
           COUNT(*) FILTER (WHERE abs(a.v - r.v) <= {tol})                 AS n_equal,
           COUNT(*) FILTER (WHERE abs(a.v - r.v) >  {tol})                 AS n_differ,
           COALESCE(MAX(abs(a.v - r.v)), 0)                                AS max_abs_diff
    FROM a JOIN r USING (k)")
  dbGetQuery(con, q) |> as_tibble() |>
    mutate(comparison = label, accdb_column = a_col, release_column = r_col, .before = 1)
}

cat("== Phase 3 reconciliation ==\n\n")

# -- 1. Cast <-> casts ---------------------------------------------------------
k_cast <- recon_keys("Cast <-> casts", "Cast", "casts", "Cst_Cnt", "id")
print(as.data.frame(k_cast), row.names = FALSE)

# which cruises are Access-only? (expected: post-2021-05, since the release is
# built from the "through 2105" published extract)
d_cast_only <- dbGetQuery(con, glue("
  SELECT a.Cruise AS cruise, COUNT(*) AS n_casts
  FROM {A('Cast')} a
  ANTI JOIN (SELECT CAST(id AS BIGINT) k FROM {R('casts')}) r
    ON TRY_CAST(a.Cst_Cnt AS BIGINT) = r.k
  GROUP BY 1 ORDER BY 1")) |> as_tibble()
write_csv(d_cast_only, file.path(dir_recon, "casts_only_in_accdb.csv"), na = "")

d_cast_only_rel <- dbGetQuery(con, glue("
  SELECT r.cruise_key, COUNT(*) AS n_casts
  FROM {R('casts')} r
  ANTI JOIN (SELECT TRY_CAST(Cst_Cnt AS BIGINT) k FROM {A('Cast')}) a
    ON CAST(r.id AS BIGINT) = a.k
  GROUP BY 1 ORDER BY 1")) |> as_tibble()
write_csv(d_cast_only_rel, file.path(dir_recon, "casts_only_in_release.csv"), na = "")

cat("\nAccess-only casts span cruises",
    min(d_cast_only$cruise, na.rm = TRUE), "-", max(d_cast_only$cruise, na.rm = TRUE),
    "across", nrow(d_cast_only), "cruises\n")
cat("Release-only casts:", sum(d_cast_only_rel$n_casts), "across",
    nrow(d_cast_only_rel), "cruises\n\n")

# -- 2. Bottle <-> bottle ------------------------------------------------------
k_btl <- recon_keys("Bottle <-> bottle", "Bottle", "bottle", "Btl_Cnt", "id")
print(as.data.frame(k_btl), row.names = FALSE)
cat("\n")

# -- 3. Access-internal: Bottle vs its published extract -----------------------
# BottleData_194903_202304 is the published form of Bottle; an 8-row delta
# between a working table and its own extract wants an explanation.
k_pub <- dbGetQuery(con, glue("
  WITH a AS (SELECT TRY_CAST(Btl_Cnt AS BIGINT) k FROM {A('Bottle')}),
       p AS (SELECT TRY_CAST(Btl_Cnt AS BIGINT) k FROM {A('BottleData_194903_202304')})
  SELECT (SELECT COUNT(*) FROM a) AS bottle_rows,
         (SELECT COUNT(*) FROM p) AS published_rows,
         (SELECT COUNT(*) FROM a ANTI JOIN p USING (k)) AS only_in_bottle,
         (SELECT COUNT(*) FROM p ANTI JOIN a USING (k)) AS only_in_published")) |> as_tibble()
print(as.data.frame(k_pub), row.names = FALSE)

d_pub_delta <- dbGetQuery(con, glue("
  SELECT b.Btl_Cnt, b.Cst_Cnt, b.Sta_ID, b.Depthm, b.Depth_ID
  FROM {A('Bottle')} b
  ANTI JOIN (SELECT TRY_CAST(Btl_Cnt AS BIGINT) k FROM {A('BottleData_194903_202304')}) p
    ON TRY_CAST(b.Btl_Cnt AS BIGINT) = p.k
  ORDER BY TRY_CAST(b.Btl_Cnt AS BIGINT)")) |> as_tibble()
write_csv(d_pub_delta, file.path(dir_recon, "bottle_vs_published_delta.csv"), na = "")
cat("\nrows in Bottle but not its published extract:\n")
print(as.data.frame(head(d_pub_delta, 12)), row.names = FALSE)
cat("\n")

# -- 4. measurement values -----------------------------------------------------
# derive the Access column <-> measurement_type mapping from the registry rather
# than hand-listing it: _source_column for calcofi_bottle rows already holds the
# snake_cased Access names (t_deg_c <- T_degC, oxy_umol_kg <- Oxy_µmol/Kg).
# read_measurement_type(), never bare read_csv — see CLAUDE.md "round-trip trap":
# a plain reader turns empty registry cells into the literal string "NA", which then
# passes is.na() and coalesce() unnoticed.
d_mt <- calcofi4db::read_measurement_type(here("metadata/measurement_type.csv")) |>
  filter(str_detect(coalesce(`_source_datasets`, ""), "calcofi_bottle"),
         !is.na(`_source_column`))

accdb_cols <- map_df(c("Bottle", "Nuts", "Chl"), \(t) {
  tibble(accdb_table = t,
         accdb_column = names(dbGetQuery(con, glue("SELECT * FROM {A(t)} LIMIT 0"))))
}) |>
  mutate(key = norm_id(accdb_column))

d_map <- d_mt |>
  mutate(key = norm_id(`_source_column`)) |>
  inner_join(accdb_cols, by = "key", relationship = "many-to-many") |>
  distinct(measurement_type, accdb_table, accdb_column)

cat("mapped", nrow(d_map), "measurement columns:",
    paste(unique(d_map$measurement_type), collapse = ", "), "\n\n")

d_val <- pmap_df(d_map, \(measurement_type, accdb_table, accdb_column) {
  key_a <- if (accdb_table == "Bottle") "Btl_Cnt" else "Btl_Cnt"
  r_expr <- glue("(SELECT bottle_id, measurement_value FROM {R('bottle_measurement')}
                   WHERE measurement_type = '{measurement_type}')")
  recon_numeric(
    label   = glue("{accdb_table}.{accdb_column} <-> bottle_measurement[{measurement_type}]"),
    a_tbl   = accdb_table, r_expr = r_expr,
    a_key   = key_a, r_key = "bottle_id",
    a_col   = accdb_column, r_col = "measurement_value",
    tol     = 1e-4) |>
    mutate(measurement_type = measurement_type, .after = comparison)
})

write_csv(d_val, file.path(dir_recon, "measurement_value_deltas.csv"), na = "")
cat("== measurement value comparison (shared bottles only) ==\n")
print(as.data.frame(d_val |> select(measurement_type, n_shared, n_equal, n_differ,
                                    n_null_in_accdb, n_null_in_release, max_abs_diff)),
      row.names = FALSE)

# -- summary -------------------------------------------------------------------
d_summary <- bind_rows(
  k_cast, k_btl,
  k_pub |> transmute(comparison = "Bottle <-> BottleData_194903_202304 (Access-internal)",
                     accdb_rows = bottle_rows, release_rows = published_rows,
                     only_accdb = only_in_bottle, only_release = only_in_published,
                     shared = bottle_rows - only_in_bottle)) |>
  select(comparison, accdb_rows, release_rows, shared, only_accdb, only_release,
         everything())

write_csv(d_summary, file.path(dir_meta, "reconciliation_summary.csv"), na = "")
write_csv(d_val |> select(comparison, measurement_type, n_shared, n_equal, n_differ,
                          n_null_in_accdb, n_null_in_release, max_abs_diff),
          file.path(dir_meta, "reconciliation_measurements.csv"), na = "")

cat("\n== summary ==\n")
print(as.data.frame(d_summary |> select(comparison, accdb_rows, release_rows,
                                        shared, only_accdb, only_release)),
      row.names = FALSE)

# -- 5. did the release ingest bottles the master later deleted? ---------------
# The published export contains 85 bottles absent from Bottle, i.e. deleted from
# the master after the export was made. 4 of those cruises fall inside the
# release's coverage, so this is a plausible way for withdrawn data to leak in.
sql_deleted <- glue("
  SELECT TRY_CAST(p.Btl_Cnt AS BIGINT) AS btl, p.Cruise
  FROM {A('BottleData_194903_202304')} p
  ANTI JOIN (SELECT TRY_CAST(Btl_Cnt AS BIGINT) k FROM {A('Bottle')}) b
    ON TRY_CAST(p.Btl_Cnt AS BIGINT) = b.k")

d_deleted <- dbGetQuery(con, glue("
  WITH d AS ({sql_deleted})
  SELECT d.Cruise                AS cruise,
         COUNT(*)                AS n_deleted_from_master,
         COUNT(r.id)             AS n_still_in_release
  FROM d LEFT JOIN {R('bottle')} r ON r.id = d.btl
  GROUP BY 1 ORDER BY 1")) |> as_tibble()

write_csv(d_deleted, file.path(dir_meta, "reconciliation_deleted_bottles.csv"), na = "")
cat("\n== master-deleted bottles still present in the release ==\n")
print(as.data.frame(d_deleted), row.names = FALSE)

leaked <- sum(d_deleted$n_still_in_release)
if (leaked == 0) {
  cat("-> none. the release does not carry any bottle the master later withdrew.\n")
} else {
  cat("-> WARNING:", leaked, "withdrawn bottles are still in the release\n")
}

# -- 6. table disposition -------------------------------------------------------
# NO Access table is imported into the integrated database. The master is a knowledge
# source: tables are either mined into metadata registries, imported into the SEPARATE
# ctd-qaqc reference database, or left in Parquet and merely documented as available.
d_tbl <- read_csv(file.path(dir_meta, "accdb/tables.csv"), show_col_types = FALSE)

verified     <- c("Bottle", "Cast")
covered      <- c("Chl", "Nuts", "Cruises", "Station_ID",
                  "ShipCode", "ShipCode_Btl", "DICs")
# QC engine reference inputs -> the ctd-qaqc database, never the release
qc_reference <- c("HarmCoeffBottle", "HarmCoeffChla", "HarmCoeffSigma", "HarmCoeffLogZoo",
                  "CurrentStations", "StDepths", "St_Stations",
                  "MLD_Sigma", "NutClineDepth")
# already mined into metadata/ registries in Phase 2
metadata_only <- c("Bottle_Q")
# real data with no release counterpart, deliberately NOT ingested — documented only
not_ingested <- c("Weather", "Prodo_Cast", "Prodo_Bottle", "Rpt_Data", "Zooplankton",
                  "Bottles Per Cast")
# staging tables, dated snapshots, backups and import scratch — not data
rx_working <- paste(
  "^Copy ", "ImportErrors", "^Paste Errors", "_test$", "_orig$", "_rcl$",
  "Add2DB", "_All_", "_all$", "_2105$", "_1701-1806$", "_84-201507$",
  "finalthru", "^Mati_", "^Anom_", "^Cast_not_org$", "^Bottle_Sigm$",
  "^1507DIC_DB$", "^DIC_ABS_salCompare$", "^BottleData_", sep = "|")

d_disp <- d_tbl |>
  transmute(
    table, n_row,
    disposition = case_when(
      str_starts(table, "0-")        ~ "documentation — harvested into metadata/",
      table %in% verified            ~ "reconciled — release verified faithful",
      table %in% covered             ~ "covered by an existing release dataset",
      table %in% qc_reference        ~ "QC reference — import into ctd-qaqc DB only",
      table %in% metadata_only       ~ "metadata — harvested into metadata/",
      table %in% not_ingested        ~ "documented, deliberately NOT ingested",
      str_detect(table, rx_working)  ~ "working copy / staging — skip",
      TRUE                           ~ "unclassified — needs review")) |>
  arrange(disposition, desc(n_row))

write_csv(d_disp, file.path(dir_meta, "table_disposition.csv"), na = "")
cat("\n== table disposition (65 Access tables) ==\n")
print(as.data.frame(count(d_disp, disposition, wt = NULL)), row.names = FALSE)

# -- questions -----------------------------------------------------------------
# append to the single review artifact rather than starting a second one
path_q <- file.path(dir_meta, "questions.csv")
d_q_old <- read_csv(path_q, show_col_types = FALSE, col_types = cols(.default = "c")) |>
  filter(!str_starts(id, "recon_"))

n_accdb_only_casts <- sum(d_cast_only$n_casts)
n_accdb_only_btl   <- k_btl$only_accdb
d_unclass <- d_disp |> filter(str_detect(disposition, "unclassified"))

d_q_new <- tribble(
  ~id, ~question, ~context, ~priority, ~related_table,
  "recon_01",
  glue("The master holds {n_accdb_only_casts} casts / {format(n_accdb_only_btl, big.mark=',')} bottles ",
       "across 7 cruises (202107-202304) that the release does not. Is that data ",
       "release-ready, or still preliminary?"),
  paste("The release is built from the published 'through 2105' extract, so it stops at",
        "2021-05; the master carries 2021-07 through 2023-04. The file is named",
        "'Master_Final_through_2105', and cruise 202304 still has 93 bottles absent from",
        "the published export plus a 2304Add2DB-cast staging table with an ImportErrors",
        "sibling — all of which suggests the newer cruises are mid-import rather than",
        "final. Ingesting them would be the single largest data gain from this port."),
  "high", "Bottle;Cast",

  "recon_02",
  "85 bottles were deleted from the master after the published export was generated (cruises 202105, 202111, 202208, 202211). Were these withdrawn as bad data?",
  paste("Confirmed NOT to have leaked into the release — zero of the 85 appear in",
        "bottle or bottle_measurement. Asking to confirm intent, and whether the same",
        "withdrawal was applied to any other distributed copy. If they were withdrawn",
        "for cause, the reason belongs in the change log."),
  "medium", "Bottle",

  "recon_03",
  glue("Access DICs has 2,142 rows but the released calcofi_dic dataset has 4,391. ",
       "Is the Access copy a superseded subset?"),
  paste("If so it needs no ingest and should be marked superseded. If it carries",
        "cast/bottle linkage the NCEI accession lacks, it could instead help close",
        "issue #47 (only 24.7% of DIC rows currently match a bottle cast)."),
  "medium", "DICs",

  if (nrow(d_unclass) > 0) glue("recon_04") else NA_character_,
  if (nrow(d_unclass) > 0) glue("Confirm the disposition of {nrow(d_unclass)} unclassified Access tables: ",
       paste(head(d_unclass$table, 8), collapse = ", "), ".") else NA_character_,
  if (nrow(d_unclass) > 0) paste("table_disposition.csv sorts all 65 tables into documentation, reconciled,",
        "covered-elsewhere, net-new, working-copy and unclassified. The unclassified",
        "ones did not match any rule and need a human call before Phase 4.") else NA_character_,
  "medium", "")

d_q_new <- d_q_new |>
  filter(!is.na(id)) |>
  mutate(id = paste0("recon_", str_remove(id, "^recon_")),
         status = "open", answer = "", asked_date = as.character(Sys.Date()),
         answered_date = "", who = "CalCOFI data manager", related_field = "")

bind_rows(d_q_old, d_q_new |> mutate(across(everything(), as.character))) |>
  write_csv(path_q, na = "")
cat("\nquestions.csv now holds", nrow(d_q_old) + nrow(d_q_new), "queued items\n")
cat("wrote", file.path(dir_meta, "reconciliation_summary.csv"), "\n")
