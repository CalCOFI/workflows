# Dry-run diff for dropping the 2607 rows of metadata/calcofi/ctd-cast/flag_overrides.csv (2026-10-20).
# Run 1_emulate.R, 2_derived.R, 3_diff.R in order from the workflows checkout. CC_DIFF_DIR is a scratch
# directory holding the provider zip unzipped to $CC_DIFF_DIR/z2607/x/
# (gs://calcofi-files-public/_sync/calcofi/ctd-cast/download/20-2607SH_CTDPrelim.zip). The release side
# is read from v2026.10.19 over https. 1_emulate.R first reproduces the released 2607 obs_ctd_full with
# the override ON (0 value and 0 qual mismatches over 2,364,714 rows), then rebuilds it with the override
# OFF; 2_derived.R does the same for ctd-derived (sigma_theta_ave, spiciness0, MLDs); 3_diff.R prints the
# per-series rows changed / filled / removed and the largest change. calcofi4db is loaded with
# devtools::load_all(), never installed.
# Emulate the ctd-cast ingest's treatment of cruise 2026-07-3322 (2607SH) with the sensor-2
# override ON (what v2026.10.19 shipped) and OFF (the fix), straight from the provider's file
# (gs://calcofi-files-public/_sync/calcofi/ctd-cast/download/20-2607SH_CTDPrelim.zip, 2026-10-13).
# Step 1 validates the ON emulation against the released obs_ctd_full; step 2 diffs ON vs OFF.
suppressMessages({
  devtools::load_all("../calcofi4db", quiet = TRUE)
  library(DBI); library(dplyr); library(tidyr); library(glue); library(readr)
})
S   <- Sys.getenv("CC_DIFF_DIR")
WT  <- here::here()
REL <- "https://storage.googleapis.com/calcofi-db/ducklake/tables/obs_ctd_full/cruise_key=2026-07-3322/a448cf22d900d35123328c28/data_0.parquet"

con <- dbConnect(duckdb::duckdb())
dbExecute(con, "INSTALL httpfs; LOAD httpfs")

# --- registry ---------------------------------------------------------------
reg <- read_measurement_type(file.path(WT, "metadata/measurement_type.csv")) |>
  filter(grepl("calcofi_ctd-cast", `_source_datasets`), !is.na(`_source_column`), `_source_column` != "")
ov  <- read_csv(file.path(WT, "metadata/calcofi/ctd-cast/flag_overrides.csv"), show_col_types = FALSE,
                col_types = cols(.default = "c"), na = "")
stopifnot(nrow(ov) == 24, all(ov$cruise_key == "2026-07-3322"))

# --- source: both directions, clean names like the ingest -------------------
rd <- function(dir) {
  f <- glue("{S}/z2607/x/20-2607_CTDBTL_001-072{dir}.csv")
  d <- readr::read_csv(f, show_col_types = FALSE, col_types = cols(.default = "c"), na = c("", "NA"))
  names(d) <- janitor::make_clean_names(names(d))
  d$cast_dir <- dir
  d
}
raw <- bind_rows(rd("D"), rd("U"))
cat("source scans:", nrow(raw), "\n")
raw$cast_key <- raw$cast_id               # 2607_001d
raw$depth_m  <- as.numeric(raw$depth)
raw$cast_n   <- as.integer(substr(raw$cast_key, 6, 8))

# --- the registry's pivot: value + qual per series ---------------------------
# qual fallback exactly as the ingest (COALESCE(provider flag, sensor flag))
qual_fallback <- c(
  temp_ave_q = NA, salt_ave_corr_q = NA, salt1_corr_q = "salt1q", salt2_corr_q = "salt2q",
  ox1_sta_corr_q = "ox1q", ox2_sta_corr_q = "ox2q", ox1_cruise_corr_q = "ox1q", ox2_cruise_corr_q = "ox2q",
  ox_ave_sta_corr_q = NA, ox1u_mq = "ox1q", ox2u_mq = "ox2q", ox1u_m_sta_corr_q = "ox1q", ox2u_m_sta_corr_q = "ox2q",
  ox1u_m_cruise_corr_q = "ox1q", ox2u_m_cruise_corr_q = "ox2q", ox_aveu_m_sta_corr_q = NA,
  est_chl_sta_corr_q = "fluor_q", est_chl_cruise_corr_q = "fluor_q", est_no3_sta_corr_q = "isusq",
  est_no3_cruise_corr_q = "isusq", batq = NA, dyn_ht_q = NA, svaq = NA,
  po_t1q = "temp1q", po_t2q = "temp2q", ox_sat1q = "ox1q", ox_sat2q = "ox2q")
num <- function(x) suppressWarnings(as.numeric(x))
for (q in names(qual_fallback)) {
  fb <- qual_fallback[[q]]
  base <- if (q %in% names(raw)) num(raw[[q]]) else NA_real_
  raw[[q]] <- if (is.na(fb)) base else dplyr::coalesce(base, num(raw[[fb]]))
}

types <- reg$measurement_type
long <- bind_rows(lapply(seq_len(nrow(reg)), function(i) {
  sc <- reg$`_source_column`[i]; qc <- reg$`_qual_column`[i]
  if (!sc %in% names(raw)) return(NULL)
  tibble(sample_key = paste0("calcofi_ctd-cast:cast:", raw$cast_key), cast_dir = raw$cast_dir,
         cast_n = raw$cast_n, depth_m = raw$depth_m, measurement_type = reg$measurement_type[i],
         value = num(raw[[sc]]),
         qual = if (!is.na(qc) && qc != "" && qc %in% names(raw)) num(raw[[qc]]) else NA_real_,
         vmin = reg$valid_min[i], vmax = reg$valid_max[i])
})) |> filter(!is.na(value), value != -99)
# declared bounds (drop_out_of_bounds)
long <- long |> filter((is.na(vmin) | value >= vmin) & (is.na(vmax) | value <= vmax))
cat("long rows after sentinel + bounds:", nrow(long), "\n")

# --- apply the override (ON) or not (OFF) -----------------------------------
apply_ov <- function(l, on) {
  if (!on) return(l)
  hit <- rep(FALSE, nrow(l))
  for (i in seq_len(nrow(ov))) {
    hit <- hit | (l$measurement_type == ov$measurement_type[i] &
                  l$cast_n >= as.integer(ov$cast_min[i]) & l$cast_n <= as.integer(ov$cast_max[i]) &
                  (ov$cast_dir[i] == "*" | l$cast_dir == ov$cast_dir[i]))
  }
  l$qual[hit] <- as.numeric(ov$qual_code[1])
  l$hit <- hit
  l
}

# --- sensor pairs rebuilt by their flags (the ingest's combine_sensor_pairs) --
pair_rule <- tribble(
  ~ave, ~s1, ~s2,
  "temperature_ave", "temperature_1", "temperature_2",
  "salinity_ave_corr", "salinity_1_corr", "salinity_2_corr",
  "oxygen_ml_l_ave_sta_corr", "oxygen_ml_l_1_sta_corr", "oxygen_ml_l_2_sta_corr",
  "oxygen_ml_l_ave_cruise_corr", "oxygen_ml_l_1_cruise_corr", "oxygen_ml_l_2_cruise_corr",
  "oxygen_umol_kg_ave_sta_corr", "oxygen_umol_kg_1_sta_corr", "oxygen_umol_kg_2_sta_corr")
combined_sql <- combine_sensor_pair_sql("p.v1", "p.v2", "p.q1", "p.q2")
dbExecute(con, "CREATE OR REPLACE TABLE raw_has AS SELECT 1 AS x")

rebuild <- function(l) {
  # the source ships a sensor value on a scan -> rebuild; else keep the shipped average
  srcmap <- c(temperature_ave = "temp", salinity_ave_corr = "salt", oxygen_ml_l_ave_sta_corr = "ox",
              oxygen_ml_l_ave_cruise_corr = "ox", oxygen_umol_kg_ave_sta_corr = "oxu")
  out <- l |> filter(!measurement_type %in% pair_rule$ave)
  shipped <- l |> filter(measurement_type %in% pair_rule$ave)
  new <- list()
  for (k in seq_len(nrow(pair_rule))) {
    ave <- pair_rule$ave[k]; s1 <- pair_rule$s1[k]; s2 <- pair_rule$s2[k]
    # raw sensor presence (before sentinel/bounds): the registry's source columns
    c1 <- reg$`_source_column`[reg$measurement_type == s1]; c2 <- reg$`_source_column`[reg$measurement_type == s2]
    has <- tibble(sample_key = paste0("calcofi_ctd-cast:cast:", raw$cast_key), depth_m = raw$depth_m,
                  src_has_sensor = !is.na(raw[[c1]]) | !is.na(raw[[c2]]))
    p <- l |> filter(measurement_type %in% c(s1, s2, ave)) |>
      select(sample_key, depth_m, measurement_type, value, qual) |>
      pivot_wider(names_from = measurement_type, values_from = c(value, qual), names_sep = "..")
    nm <- function(pre, ty) { cn <- paste0(pre, "..", ty); if (cn %in% names(p)) p[[cn]] else rep(NA_real_, nrow(p)) }
    pp <- tibble(sample_key = p$sample_key, depth_m = p$depth_m, v1 = nm("value", s1), q1 = nm("qual", s1),
                 v2 = nm("value", s2), q2 = nm("qual", s2), v_src = nm("value", ave), q_src = nm("qual", ave)) |>
      left_join(has |> group_by(sample_key, depth_m) |> summarize(src_has_sensor = any(src_has_sensor), .groups = "drop"),
                by = c("sample_key", "depth_m"))
    dbWriteTable(con, "p", as.data.frame(pp), overwrite = TRUE)
    r <- dbGetQuery(con, glue("SELECT p.sample_key, p.depth_m, p.q_src,
        CASE WHEN coalesce(p.src_has_sensor, FALSE) THEN {combined_sql} ELSE p.v_src END AS v_new FROM p"))
    new[[ave]] <- r |> filter(!is.na(v_new)) |>
      transmute(sample_key, depth_m, measurement_type = ave, value = v_new, qual = q_src,
                cast_dir = toupper(substr(sample_key, nchar(sample_key), nchar(sample_key))),
                cast_n = as.integer(substr(sample_key, nchar(sample_key) - 3, nchar(sample_key) - 1)))
  }
  bind_rows(out, bind_rows(new))
}

on  <- rebuild(apply_ov(long, TRUE))
off <- rebuild(apply_ov(long, FALSE))
saveRDS(list(on = on, off = off), file.path(S, "emul_2607.rds"))

# --- 1. validate ON against the released obs_ctd_full ------------------------
rel <- dbGetQuery(con, glue("
  SELECT sample_key, depth_min_m AS depth_m, measurement_type, measurement_value AS value,
         measurement_qual AS qual FROM read_parquet('{REL}')
  WHERE dataset_key = 'calcofi_ctd-cast'")) |> as_tibble()
cat("released rows:", nrow(rel), " emulated ON rows:", nrow(on), "\n")
cmp <- function(a, b, by = c("sample_key", "depth_m", "measurement_type")) {
  # a and b may repeat a key (two scans in a bin); compare group means / max qual
  agg <- function(x) x |> group_by(across(all_of(by))) |>
    summarize(value = mean(value), qual = suppressWarnings(max(as.numeric(qual), na.rm = TRUE)), n = n(), .groups = "drop") |>
    mutate(qual = ifelse(is.infinite(qual), NA, qual))
  full_join(agg(a), agg(b), by = by, suffix = c(".a", ".b"))
}
v <- cmp(on |> filter(measurement_type %in% rel$measurement_type), rel |> mutate(qual = suppressWarnings(as.numeric(qual))))
only_emul <- v |> filter(is.na(n.b)); only_rel <- v |> filter(is.na(n.a))
both <- v |> filter(!is.na(n.a), !is.na(n.b))
cat(glue("VALIDATION (ON vs release): both {nrow(both)}, only emulated {nrow(only_emul)}, only released {nrow(only_rel)}; ",
         "value mismatches (>1e-9): {sum(abs(both$value.a - both$value.b) > 1e-9, na.rm = TRUE)}; ",
         "qual mismatches: {sum(!(both$qual.a %in% both$qual.b[both$qual.a == both$qual.b] | (is.na(both$qual.a) & is.na(both$qual.b))))}"), "\n")
qm <- both |> filter(!((is.na(qual.a) & is.na(qual.b)) | (!is.na(qual.a) & !is.na(qual.b) & qual.a == qual.b)))
cat("qual mismatches by type:\n"); print(count(qm, measurement_type))
cat("only-emulated by type:\n"); print(count(only_emul, measurement_type))
cat("only-released by type:\n"); print(count(only_rel, measurement_type))
saveRDS(list(val = v), file.path(S, "emul_validation.rds"))
