# libs/measure_variable_crosswalk.R
# -----------------------------------------------------------------------------
# WS-M1, "Measurements catalog" plan (2026-09-10), D3: which raw
# `measurement_type` series become one crosswalk `variable`.
#
# D3's rule: a `variable` is assigned only where
#   (i)   the NERC P01 concept is identical,
#   (ii)  the units are the same or a declared conversion,
#   (iii) the series come from the same kind of sample
#         (cast profile · underway · replicate · mean), and
#   (iv)  the two are NOT plausibly the same physical samples.
#
# This script MEASURES the crosswalk on the promoted release rather than
# asserting it: it lists every NERC P01 concept shared by more than one
# dataset among the release's environmental series (coverage.json
# `variables[realm == "env"]`, joined to `metadata/measurement_type.csv`),
# evaluates all four criteria per pair, and prints an evidence table with a
# verdict and, for a pair that fails, the question id it was filed under.
#
# Criterion (iv) is the one that needs real evidence rather than a column
# comparison: is a series plausibly the SAME physical bottle/cast as the
# other, so that assigning one `variable` would double-count it? For the
# `btl_*` family (the CTD files' own embedded bottle table, e.g.
# `btl_temperature`, `btl_nitrate`) this is measured directly below — casts of
# `calcofi_bottle` and `calcofi_ctd-cast` matched by `site_key` + `datetime`
# within one hour, 1993-2021 (the same site_key + datetime logic
# `calcofi4db::match_by_site_datetime()` uses for a dataset lacking a cast FK,
# reimplemented here at hour resolution because that helper's own
# `window_days` argument compares by calendar DATE, coarser than "within one
# hour"). For the DIC dataset's `ctdtemp_its90` / `salinity_pss78`, the
# provenance is documented in `ingest_calcofi_dic.qmd` (they are the source
# file's own `CTDTEMP_ITS90` / `Salinity_PSS78` columns — the ship's CTD
# reading for that cast, reported by the DIC provider, not independently
# measured) rather than re-derived here.
#
# Re-runnable and read-only: it writes nothing (metadata/variable.csv is
# built separately, see the WS-M1 hand-back), and stops with an error — per
# the plan's Gate — if it finds a pair that passes all four criteria and is
# NOT one of the five already-unified pairs (temperature, salinity,
# oxygen_ml_l, oxygen_umol_kg, sigma_theta).

librarian::shelf(dplyr, tidyr, jsonlite, here, glue, DBI, duckdb, quiet = TRUE)

`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1 && is.na(a))) b else a

RELEASE_VERSION <- "v2026.09.06"
COVERAGE_URL    <- glue("https://storage.googleapis.com/calcofi-db/ducklake/releases/{RELEASE_VERSION}/coverage.json")
SAMPLE_URL      <- glue("https://storage.googleapis.com/calcofi-db/ducklake/releases/{RELEASE_VERSION}/parquet/sample.parquet")
MEASUREMENT_TYPE_CSV <- here("metadata/measurement_type.csv")

# the five pairs D3 already confirms as unified (Explorer's UNIFIED, seeded
# into metadata/variable.csv by this workstream) — anything else that passes
# all four criteria is a stop-and-report, not a silent assignment
UNIFIED_VARIABLES <- c("temperature", "salinity", "oxygen_ml_l", "oxygen_umol_kg", "sigma_theta")

# -- 1. the release's environmental series --------------------------------------

cov <- fromJSON(COVERAGE_URL, simplifyVector = TRUE)
env <- cov$variables |> filter(realm == "env")
# glue() trims a template's trailing newline, so it is appended as a
# separate cat() argument rather than baked into the glue string throughout
# this script
cat(glue("coverage.json {RELEASE_VERSION}: {nrow(env)} env series, ",
        "{sum(env$n_obs)} obs_env rows"), "\n\n")

mt <- calcofi4db::read_measurement_type(MEASUREMENT_TYPE_CSV)

# only series actually released at the obs_env grain — a full-resolution-only
# sensor variant (e.g. `salinity_1`) never reaches coverage.json and is out
# of scope for a crosswalk page can point to
mt_env <- mt |> semi_join(env, by = "measurement_type")

# -- 2. every NERC P01 concept shared by more than one dataset ------------------

members <- mt_env |>
  filter(!is.na(nerc_p01)) |>
  separate_rows(`_source_datasets`, sep = ";") |>
  distinct(measurement_type, nerc_p01, units, variable, is_canonical, dataset_key = `_source_datasets`)

p01_groups <- members |>
  group_by(nerc_p01) |>
  filter(n_distinct(dataset_key) > 1) |>
  mutate(p01_code = sub("^.*/([^/]+)/$", "\\1", nerc_p01[1])) |>
  ungroup() |>
  arrange(p01_code, dataset_key, measurement_type)

cat(glue("{n_distinct(p01_groups$nerc_p01)} P01 concept(s) shared by more than one dataset ",
        "among the {n_distinct(mt_env$measurement_type)} released env series"), "\n\n")

# -- 3. criterion (iii): the kind of sample -------------------------------------
# a general rule, not a per-pair lookup: a `_rep<n>` suffix is an analytical
# replicate; calcofi_mets is entirely underway intake; calcofi_dic reports an
# analyzed mean per bottle; the bottle and CTD-cast datasets are both cast
# profiles (a Niskin fired on a CTD rosette on station).
sample_kind <- function(dataset_key, measurement_type) {
  case_when(
    grepl("_rep[0-9]+$", measurement_type)        ~ "replicate",
    dataset_key == "calcofi_mets"                  ~ "underway",
    dataset_key == "calcofi_dic"                   ~ "mean",
    dataset_key %in% c("calcofi_bottle", "calcofi_ctd-cast") ~ "cast profile",
    TRUE ~ NA_character_)
}
members <- members |> mutate(kind = sample_kind(dataset_key, measurement_type))

# -- 4. criterion (iv): measure the bottle <-> CTD `btl_*` overlap -------------
# every `calcofi_ctd-cast` row carrying a `btl_*` value is, by construction,
# reporting a Niskin bottle fired on that same cast — so the question is not
# "are these correlated" but "how often does the standalone bottle dataset's
# OWN cast-level event coincide with a calcofi_ctd-cast cast", which is direct
# evidence for "plausibly the same physical samples" if it does.
con <- dbConnect(duckdb(dbdir = ":memory:"))
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)
invisible(dbExecute(con, "INSTALL httpfs; LOAD httpfs;"))

overlap_sql <- glue("
  WITH b AS (
    SELECT sample_key, site_key, datetime FROM read_parquet('{SAMPLE_URL}')
    WHERE dataset_key = 'calcofi_bottle' AND sample_type = 'cast'
      AND datetime >= TIMESTAMP '1993-01-01' AND datetime < TIMESTAMP '2022-01-01'
  ),
  c AS (
    SELECT sample_key, site_key, datetime FROM read_parquet('{SAMPLE_URL}')
    WHERE dataset_key = 'calcofi_ctd-cast' AND sample_type = 'cast'
      AND datetime >= TIMESTAMP '1993-01-01' AND datetime < TIMESTAMP '2022-01-01'
  )
  SELECT
    (SELECT count(*) FROM b) AS n_bottle_casts,
    (SELECT count(*) FROM c) AS n_ctd_casts,
    count(*) FILTER (WHERE m.site_key IS NOT NULL) AS n_matched
  FROM b
  LEFT JOIN LATERAL (
    SELECT c.site_key FROM c
    WHERE c.site_key = b.site_key
      AND abs(epoch(c.datetime) - epoch(b.datetime)) <= 3600
    ORDER BY abs(epoch(c.datetime) - epoch(b.datetime)) LIMIT 1
  ) m ON true")
overlap <- dbGetQuery(con, overlap_sql)
overlap$pct_of_bottle <- round(100 * overlap$n_matched / overlap$n_bottle_casts, 1)
overlap$pct_of_ctd     <- round(100 * overlap$n_matched / overlap$n_ctd_casts, 1)

cat("bottle <-> CTD cast overlap (site_key + datetime within 1 hour, 1993-2021):\n")
cat(glue("  {overlap$n_matched} of {overlap$n_bottle_casts} calcofi_bottle casts ",
        "({overlap$pct_of_bottle}%) have a matching calcofi_ctd-cast cast"), "\n")
cat(glue("  {overlap$n_matched} of {overlap$n_ctd_casts} calcofi_ctd-cast casts ",
        "({overlap$pct_of_ctd}%) have a matching calcofi_bottle cast"), "\n\n")

# DIC's ctdtemp_its90 / salinity_pss78 are the source file's OWN CTD columns
# (ingest_calcofi_dic.qmd: `ctdtemp_its90 = CTDTEMP_ITS90`, `salinity_pss78 =
# Salinity_PSS78` — read straight from the provider's export), not a value
# this pipeline derives by joining to calcofi_ctd-cast. Documented here rather
# than measured, because there is nothing on the release to query for it.
dic_embeds_ctd <- c("ctdtemp_its90", "salinity_pss78")

# a series named `btl_*` (or `salinity_btl` / `oxygen_btl_*`) under a NON-
# bottle dataset is, by the registry's own description ("Bottle
# temperature", "Bottle nitrate", ...), an embedded copy of the bottle
# dataset's own reporting for that cast. A `_1` / `_2` suffixed CTD series is
# a RAW, uncombined individual-sensor scan — it reads the water at the exact
# bottle-fired depth just as the embedded bottle table does, so it is
# "plausibly the same physical sample" for the same reason, not a distinct
# derived product; only the averaged/station-corrected form
# (`_ave_sta_corr` / `_ave_corr`) is not, because it is a regression product
# CALIBRATED AGAINST that cast's bottles (its own `derivation` column says
# so), not a second raw reading of them.
is_embedded_bottle <- function(dataset_key, measurement_type)
  dataset_key != "calcofi_bottle" &
  (grepl("^btl_", measurement_type) | measurement_type %in%
     c("salinity_btl", "oxygen_btl_ml_l", "oxygen_btl_umol_kg") |
     grepl("_[12]$", measurement_type))

# -- 5. evaluate the four criteria per P01 group and print the evidence table --
#
# a NON-canonical series (`is_canonical` FALSE — the bottle's pre-QC `r_*`
# forms) is out of scope for a `variable` crosswalk key entirely: D2 of the
# plan gives it no measurement page at all ("a series that is not canonical
# … gets no page … listed under its dataset as full_resolution_only[]"), so
# it can never UNIFY regardless of what the four lettered criteria say.

cat(sprintf("%-10s %-45s %-14s %-8s %-8s %-8s %-8s  %s\n",
           "P01", "series (dataset:type)", "kind", "(i)", "(ii)", "(iii)", "(iv)", "verdict"))
cat(strrep("-", 120), "\n")

beyond_appendix_b <- character()

for (p01 in unique(p01_groups$p01_code)) {
  # `kind` is added to `members` in step 3, AFTER p01_groups was built in step
  # 2, so it is joined in here; `is_canonical` is already on `p01_groups`
  # (present in `members` from the start) and must NOT be re-joined, or dplyr
  # suffixes it into `is_canonical.x`/`.y` and the canonical check below goes
  # silently blind (found while validating this script: every one of the four
  # confirmed UNIFY pairs came back "apart" until this was fixed)
  grp <- p01_groups |> filter(p01_code == p01) |>
    left_join(members |> select(measurement_type, dataset_key, kind),
              by = c("measurement_type", "dataset_key"))

  # criterion (i) is true by construction (grouped by identical P01 URI)
  units_ok <- function(u) {
    u <- unique(na.omit(u))
    length(u) <= 1 || setequal(u, c("PSS-78", "PSU"))
  }

  # evaluate every pair within the group (not just first-vs-rest), because a
  # 3+ dataset P01 group (temperature, salinity, chlorophyll_a) has more than
  # one relationship to state
  ds_pairs <- combn(unique(grp$dataset_key), 2, simplify = FALSE)
  for (pr in ds_pairs) {
    a <- grp |> filter(dataset_key == pr[1])
    b <- grp |> filter(dataset_key == pr[2])
    for (i in seq_len(nrow(a))) for (j in seq_len(nrow(b))) {
      ta <- a[i, ]; tb <- b[j, ]
      c_i   <- TRUE  # identical P01 (grouping invariant)
      c_ii  <- units_ok(c(ta$units, tb$units))
      c_iii <- !is.na(ta$kind) && !is.na(tb$kind) && ta$kind == tb$kind
      same_samples <-
        is_embedded_bottle(ta$dataset_key, ta$measurement_type) ||
        is_embedded_bottle(tb$dataset_key, tb$measurement_type) ||
        (ta$measurement_type %in% dic_embeds_ctd) || (tb$measurement_type %in% dic_embeds_ctd)
      c_iv  <- !same_samples
      both_canonical <- isTRUE(ta$is_canonical) && isTRUE(tb$is_canonical)

      verdict <- if (c_i && c_ii && c_iii && c_iv && both_canonical) "UNIFY" else "apart"
      variable_here <- unique(na.omit(c(ta$variable, tb$variable)))

      cat(sprintf("%-10s %-45s %-14s %-8s %-8s %-8s %-8s  %s\n",
                 p01, glue("{ta$dataset_key}:{ta$measurement_type} <-> {tb$dataset_key}:{tb$measurement_type}"),
                 glue("{ta$kind %||% 'NA'}/{tb$kind %||% 'NA'}"),
                 c_i, c_ii, c_iii, c_iv, verdict))

      if (verdict == "UNIFY" &&
          !(length(variable_here) == 1 && variable_here %in% UNIFIED_VARIABLES)) {
        beyond_appendix_b <- c(beyond_appendix_b,
          glue("{p01}: {ta$dataset_key}:{ta$measurement_type} <-> {tb$dataset_key}:{tb$measurement_type}"))
      }
    }
  }
}

cat("\n")
if (length(beyond_appendix_b)) {
  stop("D3 gate: pair(s) pass all four criteria and are NOT one of the five already-unified ",
       "variables (temperature, salinity, oxygen_ml_l, oxygen_umol_kg, sigma_theta) — stop and ",
       "report, do not assign:\n  ", paste(beyond_appendix_b, collapse = "\n  "), call. = FALSE)
} else {
  cat("No pair beyond the five already-unified variables passes all four criteria — matches ",
     "Appendix B of the 2026-09-10 plan.\n", sep = "")
}

# -- 6. sigma_theta: a pre-existing `variable` assignment that does NOT share --
#       an identical P01 (fails criterion (i) by strict reading)
sigma <- mt_env |> filter(variable == "sigma_theta") |> select(measurement_type, `_source_datasets`, nerc_p01, units)
cat("\nsigma_theta members (pre-existing `variable` assignment, checked against criterion i):\n")
print(as.data.frame(sigma))
if (n_distinct(na.omit(sigma$nerc_p01)) > 1) {
  cat("\n")
  cat(glue(
    "GATE: sigma_theta's member series carry DIFFERENT NERC P01 concepts ({paste(unique(na.omit(sigma$nerc_p01)), collapse = ' vs ')}) ",
    "— fails D3 criterion (i) by strict identical-P01 reading, even though the key is already unified (pre-existing, ",
    "not assigned by this script). metadata/variable.csv's sigma_theta row is written with an EMPTY nerc_p01 ",
    "(no single concept says exactly what both members are) rather than picking a side. Reported per the plan's Gate ",
    "'a nerc_p01 disagreement inside a unified key' — stop and report, not silently resolved here."), "\n")
}
