# Dry-run diff for dropping the 2607 rows of metadata/calcofi/ctd-cast/flag_overrides.csv (2026-10-20).
# Run 1_emulate.R, 2_derived.R, 3_diff.R in order from the workflows checkout. CC_DIFF_DIR is a scratch
# directory holding the provider zip unzipped to $CC_DIFF_DIR/z2607/x/
# (gs://calcofi-files-public/_sync/calcofi/ctd-cast/download/20-2607SH_CTDPrelim.zip). The release side
# is read from v2026.10.19 over https. 1_emulate.R first reproduces the released 2607 obs_ctd_full with
# the override ON (0 value and 0 qual mismatches over 2,364,714 rows), then rebuilds it with the override
# OFF; 2_derived.R does the same for ctd-derived (sigma_theta_ave, spiciness0, MLDs); 3_diff.R prints the
# per-series rows changed / filled / removed and the largest change. calcofi4db is loaded with
# devtools::load_all(), never installed.
# derived products of ctd-derived on 2607SH casts, from the emulated ctd-cast ON/OFF series
suppressMessages({
  devtools::load_all("../calcofi4db", quiet = TRUE)
  library(DBI); library(dplyr); library(tidyr); library(glue); library(readr)
})
S   <- Sys.getenv("CC_DIFF_DIR")
WT  <- here::here()
B   <- "https://storage.googleapis.com/calcofi-db/ducklake/tables"
em  <- readRDS(file.path(S, "emul_2607.rds"))
con <- dbConnect(duckdb::duckdb()); dbExecute(con, "INSTALL httpfs; LOAD httpfs")

# scan positions (derived uses them for spice)
rd <- function(dir) {
  f <- glue("{S}/z2607/x/20-2607_CTDBTL_001-072{dir}.csv")
  d <- readr::read_csv(f, show_col_types = FALSE, col_types = cols(.default = "c"), na = c("", "NA"))
  names(d) <- janitor::make_clean_names(names(d))
  tibble(sample_key = paste0("calcofi_ctd-cast:cast:", d$cast_id), depth_m = as.numeric(d$depth),
         latitude = as.numeric(d$lat_dec), longitude = as.numeric(d$lon_dec))
}
pos <- bind_rows(rd("D"), rd("U")) |> group_by(sample_key, depth_m) |>
  summarize(latitude = first(latitude), longitude = first(longitude), .groups = "drop")

types <- c("pressure", "temperature_ave", "salinity_ave_corr", "sigma_theta_1", "sigma_theta_2")
pivot <- function(l) {
  l |> filter(measurement_type %in% types) |>
    mutate(qual = as.character(qual)) |>
    group_by(sample_key, depth_m, measurement_type) |>
    summarize(value = mean(value), qual = {q <- qual[!is.na(qual)]; if (any(sub("\\.0+$", "", q) %in% c("8", "9"))) q[sub("\\.0+$", "", q) %in% c("8", "9")][1] else if (length(q)) q[1] else NA_character_},
              .groups = "drop") |>
    pivot_wider(names_from = measurement_type, values_from = c(value, qual), names_sep = "..")
}
products <- function(l) {
  d <- pivot(l) |> left_join(pos, by = c("sample_key", "depth_m")) |> arrange(sample_key, depth_m)
  g <- function(n) if (n %in% names(d)) d[[n]] else rep(NA, nrow(d))
  d <- tibble(sample_key = d$sample_key, depth_m = d$depth_m, latitude = d$latitude, longitude = d$longitude,
              pressure = g("value..pressure"), temperature_ave = g("value..temperature_ave"),
              salinity_ave_corr = g("value..salinity_ave_corr"), sigma_theta_1 = g("value..sigma_theta_1"),
              sigma_theta_2 = g("value..sigma_theta_2"), q_t = g("qual..temperature_ave"), q_s = g("qual..salinity_ave_corr"),
              q_s1 = g("qual..sigma_theta_1"), q_s2 = g("qual..sigma_theta_2"))
  d$pr <- dplyr::coalesce(d$pressure, d$depth_m)
  d$sigma_theta_ave <- ctd_sigma_theta_ave(d$sigma_theta_1, d$sigma_theta_2, d$q_s1, d$q_s2)
  d$spiciness0 <- ctd_spice(d$temperature_ave, d$salinity_ave_corr, d$pr, d$longitude, d$latitude, d$q_t, d$q_s)
  bins <- d |> select(sample_key, depth_m, sigma_theta_ave, spiciness0)
  cast <- d |> group_by(sample_key) |> group_modify(function(x, k) {
    bind_rows(
      ctd_mld(x$depth_m, x$temperature_ave, x$q_t, criterion = "temperature", threshold = 0.2, ref_depth = 10) |>
        transmute(measurement_type = "mld_temperature_02", value = mld_m),
      ctd_mld(x$depth_m, x$sigma_theta_ave, criterion = "sigma_theta", threshold = 0.02, ref_depth = 10) |>
        transmute(measurement_type = "mld_sigma_theta_002", value = mld_m),
      ctd_mld(x$depth_m, x$sigma_theta_ave, criterion = "sigma_theta", threshold = 0.125, ref_depth = 10) |>
        transmute(measurement_type = "mld_sigma_theta_0125", value = mld_m))
  }) |> ungroup() |> filter(!is.na(value))
  list(bins = bins, cast = cast)
}
if (file.exists(file.path(S, "derived_2607.rds"))) { dd <- readRDS(file.path(S, "derived_2607.rds")); on <- dd$on; off <- dd$off } else {
on  <- products(em$on); off <- products(em$off)
saveRDS(list(on = on, off = off), file.path(S, "derived_2607.rds")) }

# released: thinned obs_env at the published depths, and per-cast sample_measurement
rel_obs <- bind_rows(lapply(c("sigma_theta_ave/3506733e7b1534135fe48135", "spiciness0/395b5f090089e5b934951d1f",
                              "temperature_ave/51546595f143885426517d1b"), function(p) {
  dbGetQuery(con, glue("SELECT sample_key, depth_min_m AS depth_m, measurement_type, value
    FROM read_parquet('{B}/obs_env/measurement_type={p}/data_0.parquet') WHERE cruise_key = '2026-07-3322'"))
})) |> as_tibble()
rel_cast <- dbGetQuery(con, glue("SELECT sample_key, measurement_type, measurement_value AS value
    FROM read_parquet('{B}/sample_measurement/8dbf143a044d5d40c81d8e77/sample_measurement.parquet')
    WHERE sample_key LIKE 'calcofi_ctd-cast:cast:2607_%' AND measurement_type LIKE 'mld%'")) |> as_tibble()
saveRDS(list(rel_obs = rel_obs, rel_cast = rel_cast), file.path(S, "released_2607_derived.rds"))
cat("released thinned rows:", nrow(rel_obs), " per-cast rows:", nrow(rel_cast), "\n")
print(count(rel_obs, measurement_type)); print(count(rel_cast, measurement_type))
