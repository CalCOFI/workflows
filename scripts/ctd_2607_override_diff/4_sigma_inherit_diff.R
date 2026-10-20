suppressMessages({
  devtools::load_all(Sys.getenv("CALCOFI4DB", "../calcofi4db"), quiet = TRUE)
  library(DBI); library(dplyr); library(tidyr); library(glue); library(readr)
})
# Database-wide dry run of the sigma-theta flag inheritance (libs/ctd_flags.R) against v2026.10.19.
# Run after 0_extract_release.py and 1_emulate.R (CC_DIFF_DIR, CALCOFI4DB = the calcofi4db checkout).
# Needs, in $CC_DIFF_DIR: rel6.parquet (release obs_ctd_full: temperature_1/2, salinity_1/2, sigma_theta_1/2),
# rel_obs_env_sigma.parquet (obs_env sigma_theta_1 + sigma_theta_ave), rel_sample.parquet, rel_sm_mld.parquet
# (sample_measurement mld*), rel_clim_sigma.parquet (climatology of those) -- the COPY statements are in
# 0_extract_release.py -- and emul_2607.rds from 1_emulate.R (2607 with the override dropped).
S <- Sys.getenv("CC_DIFF_DIR")
dir.create(file.path(tempdir(), "duckdb"), showWarnings = FALSE)  # DuckDB spills here
con <- dbConnect(duckdb::duckdb()); dbExecute(con, "SET memory_limit='8GB'")
six <- c("temperature_1", "temperature_2", "salinity_1", "salinity_2", "sigma_theta_1", "sigma_theta_2")
full_tier <- c("final", "preliminary_with_bottle")

# ---- states -----------------------------------------------------------------------------------
dbExecute(con, glue("CREATE TABLE m_pre AS SELECT cruise_key, sample_key, depth_min_m AS depth_m, measurement_type,
  measurement_value AS v, regexp_replace(CAST(measurement_qual AS VARCHAR), '\\.0+$', '') AS q
  FROM read_parquet('{S}/rel6.parquet')"))
em <- readRDS(file.path(S, "emul_2607.rds"))$off |> filter(measurement_type %in% six) |>
  transmute(cruise_key = "2026-07-3322", sample_key, depth_m, measurement_type, v = value,
            q = ifelse(is.na(qual), NA_character_, as.character(as.integer(qual))))
dbWriteTable(con, "em2607", as.data.frame(em))
dbExecute(con, "CREATE TABLE m_post AS
  SELECT * FROM m_pre WHERE cruise_key <> '2026-07-3322' UNION ALL SELECT * FROM em2607")
dbExecute(con, glue("CREATE TABLE smp AS SELECT sample_key, data_stage FROM read_parquet('{S}/rel_sample.parquet')"))

bins <- function(tbl, inherit) {
  fl <- function(ty, nm) glue("MAX(q) FILTER (WHERE measurement_type = '{ty}' AND q IN ('8','9')) AS {nm}")
  sq <- function(ty, nm) glue("AVG(v) FILTER (WHERE measurement_type = '{ty}') AS v{nm},
    COALESCE(MAX(q) FILTER (WHERE measurement_type = '{ty}' AND q IN ('8','9')),
             MAX(q) FILTER (WHERE measurement_type = '{ty}' AND q NOT IN ('nan',''))) AS q{nm}")
  dbExecute(con, glue("CREATE OR REPLACE TABLE b_{tbl} AS
    SELECT cruise_key, sample_key, depth_m, {sq('sigma_theta_1', 1)}, {sq('sigma_theta_2', 2)},
           {fl('temperature_1','t1')}, {fl('salinity_1','s1')}, {fl('temperature_2','t2')}, {fl('salinity_2','s2')}
    FROM m_{tbl} GROUP BY cruise_key, sample_key, depth_m"))
  if (inherit) {
    dbExecute(con, glue("UPDATE b_{tbl} SET
      q1 = CASE WHEN q1 IN ('8','9') THEN q1 WHEN greatest(t1, s1) IS NOT NULL THEN greatest(t1, s1) ELSE q1 END,
      q2 = CASE WHEN q2 IN ('8','9') THEN q2 WHEN greatest(t2, s2) IS NOT NULL THEN greatest(t2, s2) ELSE q2 END"))
  }
}
bins("pre", FALSE); bins("post", TRUE)
comb <- function(a) gsub("p\\.", paste0(a, "."), combine_sensor_pair_sql("p.v1", "p.v2", "p.q1", "p.q2"))
ct <- paste(sprintf("'%s'", full_tier), collapse = ",")
dbExecute(con, glue("CREATE OR REPLACE TABLE d AS
  SELECT COALESCE(a.cruise_key, b.cruise_key) AS cruise_key, COALESCE(a.sample_key, b.sample_key) AS sample_key,
         COALESCE(a.depth_m, b.depth_m) AS depth_m, s.data_stage,
         a.q1 AS q1_pre, b.q1 AS q1_post, a.q2 AS q2_pre, b.q2 AS q2_post,
         a.v1 AS v1_pre, a.v2 AS v2_pre, b.v1 AS v1_post, b.v2 AS v2_post,
         CASE WHEN s.data_stage IN ({ct}) THEN {comb('a')} END AS ave_pre,
         CASE WHEN s.data_stage IN ({ct}) THEN {comb('b')} END AS ave_post
  FROM b_pre a FULL OUTER JOIN b_post b USING (sample_key, depth_m)
  LEFT JOIN smp s ON s.sample_key = COALESCE(a.sample_key, b.sample_key)"))

# ---- validation: the pre state reproduces the release ---------------------------------------
dbExecute(con, glue("CREATE TABLE rel_env AS SELECT * FROM read_parquet('{S}/rel_obs_env_sigma.parquet')"))
cat("rel_obs_env columns:", paste(dbListFields(con, "rel_env"), collapse = ", "), "\n")
val <- dbGetQuery(con, "
  SELECT r.measurement_type, count(*) AS n_released,
         count(*) FILTER (WHERE d.sample_key IS NULL) AS no_bin,
         count(*) FILTER (WHERE r.measurement_type = 'sigma_theta_ave' AND (d.ave_pre IS NULL OR abs(d.ave_pre - r.value) > 1e-6)) AS ave_mismatch,
         count(*) FILTER (WHERE r.measurement_type = 'sigma_theta_1' AND (d.v1_pre IS NULL OR abs(d.v1_pre - r.value) > 1e-6)) AS s1_mismatch
  FROM rel_env r LEFT JOIN d ON d.sample_key = r.sample_key AND d.depth_m = r.depth_min_m GROUP BY ALL")
cat("VALIDATION (pre state vs released obs_env):\n"); print(val)

# ---- the diff, per series -----------------------------------------------------------------
pub <- "EXISTS (SELECT 1 FROM rel_env r WHERE r.sample_key = d.sample_key AND r.depth_min_m = d.depth_m AND r.measurement_type = '%s')"
grp <- function(extra = "") glue("CASE WHEN cruise_key = '2026-07-3322' THEN '2607 (override dropped + inheritance)' ELSE 'other cruises (inheritance only)' END AS scope")
ave <- dbGetQuery(con, glue("
  SELECT {grp()},
    count(*) FILTER (WHERE ave_pre IS NOT NULL AND ave_post IS NOT NULL AND abs(ave_pre - ave_post) > 1e-9) AS changed,
    count(*) FILTER (WHERE ave_pre IS NULL AND ave_post IS NOT NULL) AS filled,
    count(*) FILTER (WHERE ave_pre IS NOT NULL AND ave_post IS NULL) AS removed,
    max(abs(ave_pre - ave_post)) AS largest_abs_change,
    count(*) FILTER (WHERE (ave_pre IS NOT NULL OR ave_post IS NOT NULL) AND coalesce(ave_pre, -999) <> coalesce(ave_post, -999)
                       AND {sprintf(pub, 'sigma_theta_ave')}) AS at_published_depths,
    count(DISTINCT sample_key) FILTER (WHERE coalesce(ave_pre, -999) <> coalesce(ave_post, -999)) AS n_casts,
    count(DISTINCT cruise_key) FILTER (WHERE coalesce(ave_pre, -999) <> coalesce(ave_post, -999)) AS n_cruises
  FROM d GROUP BY ALL ORDER BY 1"))
cat("\nsigma_theta_ave (1 m bins, full tier):\n"); print(ave)
qd <- dbGetQuery(con, glue("
  SELECT s.series, {grp()},
    count(*) FILTER (WHERE s.q_pre IS DISTINCT FROM s.q_post AND s.v IS NOT NULL) AS qual_changed,
    count(*) FILTER (WHERE s.q_pre IS DISTINCT FROM s.q_post AND s.v IS NOT NULL AND s.q_post IN ('8','9') AND s.q_pre IS NOT NULL AND s.q_pre NOT IN ('8','9')) AS qual_replaced,
    count(*) FILTER (WHERE s.q_pre IS DISTINCT FROM s.q_post AND s.v IS NOT NULL AND s.published) AS at_published_depths,
    count(DISTINCT s.sample_key) FILTER (WHERE s.q_pre IS DISTINCT FROM s.q_post AND s.v IS NOT NULL) AS n_casts,
    count(DISTINCT s.cruise_key) FILTER (WHERE s.q_pre IS DISTINCT FROM s.q_post AND s.v IS NOT NULL) AS n_cruises
  FROM (SELECT 'sigma_theta_1' AS series, cruise_key, sample_key, q1_pre AS q_pre, q1_post AS q_post, coalesce(v1_pre, v1_post) AS v,
               {sprintf(pub, 'sigma_theta_1')} AS published FROM d
        UNION ALL
        SELECT 'sigma_theta_2', cruise_key, sample_key, q2_pre, q2_post, coalesce(v2_pre, v2_post), FALSE FROM d) s
  GROUP BY ALL ORDER BY 1, 2"))
cat("\nsigma_theta_1/2 flags (values never change; sigma_theta_2 is not published in obs):\n"); print(qd)
# values of sigma_theta_1/2 themselves must be identical between states
vchk <- dbGetQuery(con, "SELECT count(*) FILTER (WHERE abs(v1_pre - v1_post) > 1e-12 OR (v1_pre IS NULL) <> (v1_post IS NULL)) AS s1_value_diff,
  count(*) FILTER (WHERE abs(v2_pre - v2_post) > 1e-12 OR (v2_pre IS NULL) <> (v2_post IS NULL)) AS s2_value_diff FROM d WHERE cruise_key <> '2026-07-3322'")
cat("\nsigma values changed outside 2607:", paste(unlist(vchk), collapse = " / "), "\n")
top <- dbGetQuery(con, "
  SELECT cruise_key,
    count(*) FILTER (WHERE ave_pre IS NOT NULL AND ave_post IS NOT NULL AND abs(ave_pre - ave_post) > 1e-9) AS ave_changed,
    count(*) FILTER (WHERE ave_pre IS NOT NULL AND ave_post IS NULL) AS ave_removed,
    count(*) FILTER (WHERE ave_pre IS NULL AND ave_post IS NOT NULL) AS ave_filled,
    round(max(abs(ave_pre - ave_post)), 4) AS largest_abs_change,
    count(DISTINCT sample_key) FILTER (WHERE coalesce(ave_pre, -999) <> coalesce(ave_post, -999)) AS n_casts,
    count(*) FILTER (WHERE q1_pre IS DISTINCT FROM q1_post AND v1_pre IS NOT NULL) AS s1_qual,
    count(*) FILTER (WHERE q2_pre IS DISTINCT FROM q2_post AND v2_pre IS NOT NULL) AS s2_qual
  FROM d GROUP BY 1 HAVING ave_changed + ave_removed + ave_filled + s1_qual + s2_qual > 0 ORDER BY ave_changed + ave_removed DESC, s2_qual DESC")
cat("\nBy cruise (all that change):\n"); print(as.data.frame(top), row.names = FALSE)
write_csv(top, file.path(S, "inherit_by_cruise.csv")); write_csv(ave, file.path(S, "inherit_ave.csv")); write_csv(qd, file.path(S, "inherit_qual.csv"))

# ---- per-cast MLD ---------------------------------------------------------------------------
dbExecute(con, glue("CREATE TABLE sm AS SELECT * FROM read_parquet('{S}/rel_sm_mld.parquet')"))
aff <- dbGetQuery(con, "SELECT DISTINCT sample_key FROM d WHERE coalesce(ave_pre, -999) <> coalesce(ave_post, -999)")$sample_key
rel_sm <- dbGetQuery(con, "SELECT sample_key, measurement_type, measurement_value AS rel FROM sm WHERE measurement_type IN ('mld_sigma_theta_002','mld_sigma_theta_0125')")
mld_of <- function(depth, ave, thr) ctd_mld(depth, ave, criterion = "sigma_theta", threshold = thr, ref_depth = 10)$mld_m
aff_cast <- intersect(aff, rel_sm$sample_key)
cat("\ncasts with a changed sigma_theta_ave:", length(aff), "; of which carry a released MLD:", length(aff_cast), "\n")
dd <- dbGetQuery(con, glue("SELECT sample_key, depth_m, ave_pre, ave_post FROM d WHERE sample_key IN ({paste0(\"'\", aff_cast, \"'\", collapse = ',')}) ORDER BY sample_key, depth_m"))
mld <- dd |> group_by(sample_key) |> group_modify(function(x, k) tibble(
  measurement_type = c("mld_sigma_theta_002", "mld_sigma_theta_0125"),
  pre = c(mld_of(x$depth_m, x$ave_pre, 0.02), mld_of(x$depth_m, x$ave_pre, 0.125)),
  post = c(mld_of(x$depth_m, x$ave_post, 0.02), mld_of(x$depth_m, x$ave_post, 0.125)))) |> ungroup() |>
  left_join(rel_sm, by = c("sample_key", "measurement_type"))
cat("MLD validation (pre vs released) over affected casts: n", nrow(mld), " mismatches", sum(abs(mld$pre - mld$rel) > 1e-6, na.rm = TRUE),
    " NA-pattern mismatches", sum(is.na(mld$pre) != is.na(mld$rel)), "\n")
mld_tab <- mld |> mutate(kind = case_when(is.na(rel) & !is.na(post) ~ "filled", !is.na(rel) & is.na(post) ~ "removed",
                                          abs(post - rel) > 1e-9 ~ "changed", TRUE ~ "same")) |>
  group_by(scope = ifelse(grepl("cast:2607_", sample_key), "2607", "other cruises"), measurement_type) |>
  summarize(changed = sum(kind == "changed"), filled = sum(kind == "filled"), removed = sum(kind == "removed"),
    largest_abs_change_m = round(max(abs(post - rel), na.rm = TRUE), 3), n_casts = sum(kind != "same"), .groups = "drop")
cat("\nper-cast MLD, changed vs release:\n"); print(as.data.frame(mld_tab), row.names = FALSE)
write_csv(mld_tab, file.path(S, "inherit_mld.csv")); saveRDS(mld, file.path(S, "inherit_mld_cast.rds"))
cat("mld_temperature_02 and spiciness0 read only temperature_ave / salinity_ave_corr: unchanged by construction\n")

# ---- climatology -----------------------------------------------------------------------------
qual_sql <- calcofi4r::cc_qual_ok_sql("o")
dbExecute(con, glue("CREATE TABLE samp AS SELECT * FROM read_parquet('{S}/rel_sample.parquet')"))
dbExecute(con, "CREATE TABLE obs_pre AS SELECT *, 'env' AS realm FROM rel_env")
cols <- dbListFields(con, "rel_env")
# post: sigma_theta_ave value from the new average (row dropped where it vanishes); sigma_theta_1 qual from the inherited flag
dbExecute(con, glue("CREATE TABLE obs_post AS
  SELECT r.* EXCLUDE (value, measurement_qual),
         CASE r.measurement_type WHEN 'sigma_theta_ave' THEN d.ave_post ELSE r.value END AS value,
         CASE r.measurement_type WHEN 'sigma_theta_1' THEN d.q1_post ELSE r.measurement_qual END AS measurement_qual,
         'env' AS realm
  FROM rel_env r JOIN d ON d.sample_key = r.sample_key AND d.depth_m = r.depth_min_m
  WHERE NOT (r.measurement_type = 'sigma_theta_ave' AND d.ave_post IS NULL)"))
n_drop <- dbGetQuery(con, "SELECT (SELECT count(*) FROM obs_pre) - (SELECT count(*) FROM obs_post) AS n")$n
cat("obs_env rows lost in the post state (sigma_theta_ave removed or no bin):", n_drop, "\n")
dbExecute(con, "CREATE TABLE sm_pre AS SELECT * FROM sm WHERE measurement_type IN ('mld_sigma_theta_002','mld_sigma_theta_0125')")
dbWriteTable(con, "mld_post", mld |> filter(!is.na(post)) |> select(sample_key, measurement_type, post) |> as.data.frame())
dbExecute(con, "CREATE TABLE sm_post AS
  SELECT s.* EXCLUDE (measurement_value), coalesce(p.post, s.measurement_value) AS measurement_value FROM sm_pre s
  LEFT JOIN mld_post p USING (sample_key, measurement_type)")
# casts whose post MLD vanished
gone <- mld |> filter(is.na(post), !is.na(rel))
if (nrow(gone)) { dbWriteTable(con, "mld_gone", select(gone, sample_key, measurement_type) |> as.data.frame())
  dbExecute(con, "DELETE FROM sm_post WHERE (sample_key, measurement_type) IN (SELECT sample_key, measurement_type FROM mld_gone)") }
# sigma_theta_ave and the MLD rows enter obs/sample_measurement under the column names build_climatology reads
run_clim <- function(obs_t, sm_t, out) {
  dbExecute(con, glue("CREATE OR REPLACE VIEW obs AS SELECT * EXCLUDE (value), value AS measurement_value FROM {obs_t}"))
  dbExecute(con, "CREATE OR REPLACE VIEW sample AS SELECT * FROM samp")
  dbExecute(con, glue("CREATE OR REPLACE VIEW sample_measurement AS SELECT * FROM {sm_t}"))
  build_climatology(con, qual_ok_sql = qual_sql, min_cruises = 5L,
                    cast_types = c("mld_sigma_theta_002", "mld_sigma_theta_0125"), season = TRUE, tbl = out)
}
cat("sample_measurement columns:", paste(dbListFields(con, "sm"), collapse = ", "), "\n")
n1 <- run_clim("obs_pre", "sm_pre", "clim_pre"); n2 <- run_clim("obs_post", "sm_post", "clim_post")
cat("climatology rows pre/post:", n1, n2, "\n")
dbExecute(con, glue("CREATE TABLE clim_rel AS SELECT * FROM read_parquet('{S}/rel_clim_sigma.parquet')"))
v <- dbGetQuery(con, "
  SELECT count(*) AS n_released,
    count(*) FILTER (WHERE p.site_key IS NULL) AS missing_in_rebuild,
    count(*) FILTER (WHERE p.site_key IS NOT NULL AND (abs(coalesce(p.clim_mean,-999) - coalesce(r.clim_mean,-999)) > 1e-5 OR p.clim_n IS DISTINCT FROM r.clim_n
                      OR abs(coalesce(p.season_mean,-999) - coalesce(r.season_mean,-999)) > 1e-5)) AS mean_or_n_mismatch
  FROM clim_rel r LEFT JOIN clim_pre p ON p.dataset_key = r.dataset_key AND p.site_key = r.site_key AND p.month = r.month
       AND p.depth_bin IS NOT DISTINCT FROM r.depth_bin AND p.measurement_type = r.measurement_type
  WHERE r.measurement_type IN ('sigma_theta_1','sigma_theta_ave','mld_sigma_theta_002','mld_sigma_theta_0125')")
cat("\nCLIMATOLOGY validation (pre rebuild vs released):\n"); print(v)
cd <- dbGetQuery(con, "
  SELECT coalesce(a.measurement_type, b.measurement_type) AS measurement_type,
    count(*) FILTER (WHERE a.site_key IS NOT NULL AND b.site_key IS NOT NULL AND (abs(coalesce(a.clim_mean,-999) - coalesce(b.clim_mean,-999)) > 1e-6
                      OR a.clim_n IS DISTINCT FROM b.clim_n)) AS cells_monthly_changed,
    count(*) FILTER (WHERE a.site_key IS NOT NULL AND b.site_key IS NOT NULL AND abs(coalesce(a.season_mean,-999) - coalesce(b.season_mean,-999)) > 1e-6) AS cells_season_changed,
    count(*) FILTER (WHERE a.site_key IS NOT NULL AND b.site_key IS NULL) AS cells_removed,
    count(*) FILTER (WHERE a.site_key IS NULL AND b.site_key IS NOT NULL) AS cells_filled,
    round(max(abs(a.clim_mean - b.clim_mean)), 4) AS largest_clim_mean_shift,
    round(max(abs(a.season_mean - b.season_mean)), 4) AS largest_season_mean_shift
  FROM clim_pre a FULL OUTER JOIN clim_post b ON a.dataset_key = b.dataset_key AND a.site_key = b.site_key AND a.month = b.month
       AND a.depth_bin IS NOT DISTINCT FROM b.depth_bin AND a.measurement_type = b.measurement_type
  GROUP BY 1 ORDER BY 1")
cat("\nCLIMATOLOGY pre -> post:\n"); print(cd)
write_csv(cd, file.path(S, "inherit_climatology.csv"))
