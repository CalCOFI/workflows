# libs/census_depth_constant_ctd.R
# -----------------------------------------------------------------------------
# Census of CTD derived/estimated series that hold ONE value at every depth.
#
# Why: the provider column EstNO3_CruiseCorr is a single value per cast over the full
# 0-520 m on every cast of 2504SH (line 93.3), 2204SH, 2307SR and the final 9809NH,
# while EstNO3_StaCorr on the same casts rises ~1 -> 40 uM as nitrate should
# (2026-10-01; Rasmus Swalethorp's screenshot of 2026-09-29 shows vertical stripes).
# A bound cannot catch it (the value is in range) and the provider sets no flag, so the
# test is on the SHAPE of the series. This script counts how widespread it is, per
# cruise x column, so the ingest drops exactly the series the census shows
# (ingest_calcofi_ctd-cast.qmd, section "Withhold Series That Do Not Vary With Depth").
#
# Rule (the same thresholds as calcofi4db::check_depth_constant_series()): a cast is
# JUDGED for a column when it has >= MIN_N finite non-sentinel values over a depth span
# >= MIN_SPAN_M; it is CONSTANT when max - min < TOL. -99 is the provider's missing
# marker and is not a value. Downcast ("D") files only: the upcast carries the same
# series. Per cruise only the most advanced data stage is read, as the ingest does
# (final > preliminary_with_bottle > preliminary_without_bottle).
#
# Read-only: scans the CSVs the ingest already unzipped, writes one CSV.
#   Rscript libs/census_depth_constant_ctd.R [dir_unzip] [out_csv]
# Output: data/qc/ctd_depth_constant_census.csv (na = "")

librarian::shelf(DBI, dplyr, duckdb, glue, here, janitor, purrr, readr, stringr, tibble,
                 quiet = T)

MIN_N      <- 6
MIN_SPAN_M <- 50
TOL        <- 1e-9
SENTINEL   <- -99

args      <- commandArgs(trailingOnly = TRUE)
dir_unzip <- path.expand(
  if (length(args) >= 1) args[[1]] else
    file.path(Sys.getenv("CALCOFI_STAGE_DIR", "~/_big/calcofi"), "ctd-cast", "unzip"))
out_csv   <- if (length(args) >= 2) args[[2]] else here("data/qc/ctd_depth_constant_census.csv")
stopifnot("unzip dir not found" = dir.exists(dir_unzip))

# series under test: estimated nitrate/chlorophyll and the bottle-corrected salinity and
# oxygen (the columns a bottle regression produces), never their Q flag columns
SERIES_RE <- "^(EstNO3|EstChl)_|^Salt[A-Za-z0-9]*_Corr$|^Ox[A-Za-z0-9]*_(Cruise|Sta)Corr$"

# files: every downcast db CSV, then the stage rule of the ingest's [d_csv] chunk
d_files <- tibble(path = list.files(dir_unzip, pattern = "_CTD(BTL)?_.*D\\.csv$",
                                    recursive = TRUE, full.names = TRUE)) |>
  mutate(
    rel        = str_remove(path, fixed(paste0(dir_unzip, "/"))),
    dir_zip    = str_extract(rel, "^[^/]+"),
    file_csv   = basename(path),
    cruise_key = str_extract(rel, "\\d{2}-(\\d{4}[A-Z0-9]{2,4})_", group = 1),
    data_stage = case_when(
      str_detect(rel, "Final.*db[_|-]csvs?/") &
        !str_detect(rel, regex("db[_|-]csvs?/(orig|uncorrected)[^/]*/", ignore_case = TRUE)) ~ "final",
      str_detect(dir_zip, "CTDFinalDB$") & rel == paste0(dir_zip, "/", file_csv)            ~ "final",
      str_detect(dir_zip, "Prelim") & str_detect(file_csv, "_CTDBTL_")                      ~ "preliminary_with_bottle",
      str_detect(dir_zip, "Prelim") & str_detect(file_csv, "_CTD_")                         ~ "preliminary_without_bottle")) |>
  filter(!is.na(data_stage), !is.na(cruise_key)) |>
  mutate(priority = match(data_stage,
    c("final", "preliminary_with_bottle", "preliminary_without_bottle"))) |>
  group_by(cruise_key) |> filter(priority == min(priority)) |> ungroup() |>
  arrange(cruise_key, nchar(rel)) |>
  distinct(cruise_key, file_csv, .keep_all = TRUE)   # the shortest path is the canonical copy
cat(glue("{nrow(d_files)} downcast files over {n_distinct(d_files$cruise_key)} cruises\n"))

con <- dbConnect(duckdb(dbdir = ":memory:"))
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

scan_file <- function(path, cruise_key, data_stage) {
  q <- \(x) paste0('"', x, '"')
  src <- glue("read_csv('{gsub(\"'\", \"''\", path)}', header = true, all_varchar = true,
                       ignore_errors = true, null_padding = true)")
  cols <- dbGetQuery(con, glue("SELECT column_name FROM (DESCRIBE SELECT * FROM {src})"))$column_name
  ser  <- cols[str_detect(cols, SERIES_RE) & !str_detect(cols, "Q$")]
  if (!length(ser) || !all(c("Cast_ID", "Depth") %in% cols)) return(NULL)
  dbGetQuery(con, glue("
    WITH r AS (SELECT Cast_ID AS cast_id, TRY_CAST(Depth AS DOUBLE) AS depth_m,
                      {paste(q(ser), collapse = ', ')} FROM {src}),
    v AS (
      SELECT cast_id, depth_m, series, TRY_CAST(value AS DOUBLE) AS value
      FROM (UNPIVOT r ON {paste(q(ser), collapse = ', ')} INTO NAME series VALUE value))
    SELECT cast_id, series, COUNT(*) AS n, MAX(depth_m) - MIN(depth_m) AS span_m,
           MIN(value) AS v_min, MAX(value) AS v_max
    FROM v
    WHERE value IS NOT NULL AND isfinite(value) AND value != {SENTINEL} AND depth_m IS NOT NULL
    GROUP BY 1, 2")) |>
    mutate(cruise_key = cruise_key, data_stage = data_stage, .before = 1)
}

d_cast <- pmap_dfr(d_files |> select(path, cruise_key, data_stage), scan_file)

# per cruise x column; a cast split across files is counted once per file (rare)
if (nzchar(Sys.getenv("CENSUS_CAST_RDS"))) saveRDS(d_cast, Sys.getenv("CENSUS_CAST_RDS"))
d_census <- d_cast |>
  mutate(judged   = n >= MIN_N & span_m >= MIN_SPAN_M,
         constant = judged & (v_max - v_min) < TOL) |>
  group_by(cruise_key, data_stage, column = series) |>
  summarize(
    n_casts_with_values = n(),
    n_judged            = sum(judged),
    n_constant          = sum(constant),
    pct_constant        = if_else(n_judged > 0, round(100 * n_constant / n_judged, 1), NA_real_),
    const_value_min     = if (any(constant)) min(v_min[constant]) else NA_real_,
    const_value_max     = if (any(constant)) max(v_min[constant]) else NA_real_,
    .groups = "drop") |>
  # clean_names() on the DISTINCT columns: on a long vector it numbers duplicates (_10401)
  left_join(tibble(column = unique(d_cast$series)) |>
              mutate(measurement_type = make_clean_names(column)), by = "column") |>
  relocate(measurement_type, .after = column) |>
  arrange(column, desc(n_constant), cruise_key)

dir.create(dirname(out_csv), showWarnings = FALSE, recursive = TRUE)
write_csv(d_census, out_csv, na = "")
cat(glue("wrote {out_csv}: {nrow(d_census)} cruise x column rows\n"))

# totals per column: how many casts are judged, how many are constant, over how many cruises
# NB: summarize() sees a column it just created, so the cruise counts read the census
# columns first (cr_*) and the sums are named last
d_tot <- d_census |>
  mutate(cr_judged = n_judged > 0, cr_any = n_constant > 0,
         cr_all = n_judged > 0 & n_constant == n_judged) |>
  group_by(column) |>
  summarize(
    n_cruises     = sum(cr_judged),
    n_cruises_any = sum(cr_any),
    n_cruises_all = sum(cr_all),
    n_casts_judged   = sum(n_judged),
    n_casts_constant = sum(n_constant),
    pct_constant     = round(100 * sum(n_constant) / sum(n_judged), 2),
    .groups = "drop") |>
  arrange(desc(n_casts_constant))
print(d_tot, n = Inf, width = Inf)
