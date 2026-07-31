# libs/build_qc_reference.R
# -----------------------------------------------------------------------------
# Phase 5: export the QC-engine reference tables from the Access hydro-master
# extract into small, committed CSVs under metadata/calcofi/hydro-master/reference/.
#
# THESE DO NOT GO IN THE RELEASE. They are the QC engine's reference inputs — a
# climatology to compare against, station bottom depths, the standard-depth grid —
# not published science tables. `ctd-qaqc` imports them into its own database.
#
# They are committed as CSV (rather than read from the gitignored 163 MB accdb
# extract) because they are small, curated and reviewable, and because ctd-qaqc
# must be preppable on a server that has never run the Access extraction.
#
# Depends on Phase 0 (scripts/extract_accdb.sh). Re-runnable and idempotent.
#
# THE HARMONIC FORM WAS DETERMINED EMPIRICALLY, NOT ASSUMED.
# The providers have not confirmed the fitting procedure (question
# hydro_master_12), so candidate forms were scored against the very bottle data
# the coefficients were derived from (200,640 matched observations):
#
#   form                                      RMSE     vs mean-only
#   Mean                                      1.269         —
#   Mean + Ampl*sin(Freq*(doy - Phase))       0.949      +25.2%   <- this one
#   Mean + Ampl*cos(Freq*(doy - Phase))       2.113      -66.4%
#   Mean + Ampl*cos(Freq*doy - Phase_deg)     1.800      -41.8%
#   Mean + Ampl*sin(2pi*(doy - Phase)/365)    1.474      -16.1%
#
# Every cosine variant is WORSE than using the mean alone; the sine form with the
# fitted Freq (rad/day) and Phase (days) is decisively better. Two independent
# checks agree:
#   * physical — the seasonal signal is strongest at the surface (42% RMSE
#     reduction at 0 m) and decays monotonically to ~5% by 150-500 m, which is
#     what seasonal heating does. A wrong form would show no depth structure.
#   * statistical — residuals divided by StDev are near-standard-normal
#     (mean -0.06, sd 1.14), confirming StDev is the residual scale a z-score
#     needs.
#
# Recorded here rather than only in a commit message because any later change to
# the reconstruction has to clear the same bar.

suppressMessages({
  library(dplyr); library(readr); library(stringr); library(tidyr)
  library(purrr); library(glue); library(here); library(fs); library(DBI)
})

dir_acc <- here("data/accdb/calcofi_hydro-master/tables")
dir_out <- here("metadata/calcofi/hydro-master/reference")
dir_create(dir_out)

stopifnot(
  "Access extract not found — run scripts/extract_accdb.sh first" =
    dir.exists(dir_acc))

con <- calcofi4db::get_duckdb_con(":memory:")
on.exit(try(dbDisconnect(con, shutdown = TRUE), silent = TRUE), add = TRUE)
A <- function(t) glue("read_parquet('{dir_acc}/{t}.parquet')")

# -- station reference ---------------------------------------------------------
# Sta_ID is byte-identical to the core model's site_key ("076.7 049.0"), so this
# joins directly with no crosswalk.
d_sta <- dbGetQuery(con, glue("
  SELECT Sta_ID              AS site_key,
         CAST(Rpt_Line   AS DOUBLE) AS rpt_line,
         CAST(Rpt_Sta    AS DOUBLE) AS rpt_sta,
         CAST(Avg_Depth  AS DOUBLE) AS avg_bottom_depth_m,
         DBSta_ID           AS db_sta_id
  FROM {A('CurrentStations')} ORDER BY Sta_ID"))
write_csv(d_sta, file.path(dir_out, "station.csv"), na = "")
cat("station.csv           :", nrow(d_sta), "current standard stations\n")

# -- standard depth grid -------------------------------------------------------
d_dep <- dbGetQuery(con, glue(
  "SELECT CAST(StDepth AS DOUBLE) AS depth_m FROM {A('StDepths')} ORDER BY 1"))
write_csv(d_dep, file.path(dir_out, "standard_depth.csv"), na = "")
cat("standard_depth.csv    :", nrow(d_dep), "levels (",
    paste(range(d_dep$depth_m), collapse = " - "), "m )\n")

# -- station class codes -------------------------------------------------------
d_code <- dbGetQuery(con, glue("SELECT * FROM {A('0-Sta_Code')}"))
names(d_code) <- make.unique(names(d_code)) |> str_replace_all("[^A-Za-z0-9]+", "_") |> tolower()
write_csv(d_code, file.path(dir_out, "station_class.csv"), na = "")
cat("station_class.csv     :", nrow(d_code), "codes\n")

# -- harmonic climatology, pivoted long ---------------------------------------
# The Access table is 53 columns wide: one 5-column block per property. Long form
# is what a rule can actually join against.
props <- c("Temp", "Sal", "Sig", "O2", "O2Sat", "Chla", "NO3", "NO2", "PO4", "SiO3")

d_harm <- map_df(props, \(p) {
  dbGetQuery(con, glue("
    SELECT Sta_ID                       AS site_key,
           CAST(StDepth   AS DOUBLE)    AS depth_m,
           '{p}'                        AS property,
           CAST(\"{p}Mean\"  AS DOUBLE) AS coef_mean,
           CAST(\"{p}Ampl\"  AS DOUBLE) AS coef_ampl,
           CAST(\"{p}Freq\"  AS DOUBLE) AS coef_freq,
           CAST(\"{p}Phase\" AS DOUBLE) AS coef_phase,
           CAST(\"{p}StDev\" AS DOUBLE) AS coef_stdev
    FROM {A('HarmCoeffBottle')}
    WHERE \"{p}Mean\" IS NOT NULL")) })

# Map each fitted property onto the canonical measurement types it describes —
# but ONLY the properties where the reconstruction was actually validated.
#
# Every property was scored the same way as temperature (predict the bottle record
# the coefficients came from; compare RMSE to the mean-only null; check that
# residual/StDev is ~N(0,1) so it can serve as a z denominator):
#
#   property  RMSE gain   sd(z)      verdict
#   Temp        25.2%      1.14      use
#   SiO3        11.6%      1.12      use
#   NO3         10.3%      1.40      use
#   PO4          9.7%      1.26      use
#   O2           9.3%      1.29      use
#   Sig          2.4%      4.80      EXCLUDE
#   Sal          0.5%      6.73      EXCLUDE
#   NO2          5.0%      5.4e12    EXCLUDE
#   Chla         4.3%      1.2e11    EXCLUDE
#
# Salinity and sigma-theta are excluded on evidence, not taste: a seasonal
# harmonic explains almost none of their variance here (Southern California
# salinity is advection-driven, not seasonally heated), and the tabulated StDev is
# roughly 5-7x smaller than the actual residual — so it is measuring something
# other than residual spread. A z-score built on it would be wildly over-dispersed
# and would flag thousands of ordinary values.
#
# NO2 and Chla fail for a different reason: a handful of station x depth cells
# carry a near-zero StDev, which makes z explode (see min_stdev in the rule SQL).
# Their explanatory power is weak anyway, so they are left out rather than patched.
#
# The coefficients were fitted on BOTTLE data, so they apply at least as well to
# the bottle-reference types as to the CTD sensors — both are listed.
map_prop <- tribble(
  ~property, ~measurement_type,
  "Temp",    "temperature_ave",
  "Temp",    "btl_temperature",
  "O2",      "oxygen_ml_l_ave_sta_corr",
  "O2",      "oxygen_btl_ml_l",
  "NO3",     "btl_nitrate",
  "PO4",     "btl_phosphate",
  "SiO3",    "btl_silicate")
  # O2Sat has no canonical CTD counterpart carrying the same units — left unmapped
  # rather than forced onto oxygen_saturation_1/2, which are per-sensor.
  # Sal / Sig / NO2 / Chla: see the table above.

valid_mt <- calcofi4db::read_measurement_type(here("metadata/measurement_type.csv"))$measurement_type
unknown  <- setdiff(map_prop$measurement_type, valid_mt)
if (length(unknown)) stop("climatology maps to unregistered type(s): ",
                          paste(unknown, collapse = ", "), call. = FALSE)

d_clim <- d_harm |>
  inner_join(map_prop, by = "property", relationship = "many-to-many") |>
  select(site_key, depth_m, measurement_type, property,
         coef_mean, coef_ampl, coef_freq, coef_phase, coef_stdev) |>
  arrange(measurement_type, site_key, depth_m)

write_csv(d_clim, file.path(dir_out, "climatology_harmonic.csv"), na = "")
cat("climatology_harmonic.csv:", format(nrow(d_clim), big.mark = ","), "rows —",
    n_distinct(d_clim$site_key), "stations x", n_distinct(d_clim$depth_m), "depths x",
    n_distinct(d_clim$measurement_type), "measurement types\n")

# -- derived-product reference values -----------------------------------------
# Not used by a rule yet; kept so a reimplementation of the MLD / nutricline
# recipes can be validated against the Access-era numbers rather than trusted.
for (t in c("MLD_Sigma", "NutClineDepth")) {
  d <- dbGetQuery(con, glue("SELECT * FROM {A(t)}"))
  names(d) <- tolower(names(d)) |> str_replace_all("[^a-z0-9]+", "_")
  write_csv(d, file.path(dir_out, glue("{tolower(t)}.csv")), na = "")
  cat(sprintf("%-22s: %s rows\n", glue("{tolower(t)}.csv"), format(nrow(d), big.mark = ",")))
}

cat("\nwrote", length(dir_ls(dir_out)), "files ->", dir_out, "\n")
cat("total size:", round(sum(file_size(dir_ls(dir_out))) / 1024^2, 1), "MB\n")
