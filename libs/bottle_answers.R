# Provider answers applied to the bottle database (ingest_calcofi_bottle.qmd, § Apply Provider Answers).
#
# Two registries under metadata/calcofi/bottle/ carry what the provider decided about rows of the
# source, so the decision is data, reviewable in a diff and restorable by deleting its row:
#
# - qual_overrides.csv   sets measurement_qual on every value of one measurement_type within a
#                        scope (a cruise_key, a cast_id or a bottle_id). The value is kept; the code
#                        (8 = suspect in the bottle vocabulary) is what cc_qual_ok_sql() / qual_ok
#                        exclude, so nothing derived from it (bottle-derived, climatology) uses it.
# - sample_exclusions.csv removes a cast (with its bottles, their measurements and the cast's
#                        conditions) or a single bottle from the ingest's outputs.
#
# Every row must touch at least one row of the source as staged: a row that matches nothing is a
# stale answer (or a typo) and stops the render. A qual override whose values an earlier step of the
# ingest already removed (the bounds, or the salinity beside an impossible temperature) is counted
# as removed upstream instead, from the table of removed rows the bounds step records.

BOTTLE_ANSWER_SCOPES <- c("cruise_key", "cast_id", "bottle_id")

.ba_read <- function(path, cols) {
  d <- readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()), na = "")
  miss <- setdiff(cols, names(d))
  if (length(miss)) stop(glue::glue("{basename(path)} lacks column(s): {paste(miss, collapse = ', ')}"))
  d[cols]
}

#' Read and validate qual_overrides.csv
#' @param path the CSV.
#' @return a tibble, one row per override.
read_qual_overrides <- function(path) {
  cols <- c("scope", "scope_value", "measurement_type", "qual", "reason",
            "question_label", "answered_by", "answered_date")
  d <- .ba_read(path, cols)
  stopifnot(
    "qual_overrides: scope must be cruise_key, cast_id or bottle_id" =
      all(d$scope %in% BOTTLE_ANSWER_SCOPES),
    "qual_overrides: scope_value, measurement_type and qual are required" =
      !anyNA(d$scope_value) && !anyNA(d$measurement_type) && !anyNA(d$qual),
    "qual_overrides: qual is a single-digit code" = all(grepl("^[0-9]$", d$qual)),
    "qual_overrides: a cast_id / bottle_id is an integer" =
      all(grepl("^[0-9]+$", d$scope_value[d$scope != "cruise_key"])),
    "qual_overrides: every row cites its question and date" =
      !anyNA(d$question_label) && !anyNA(d$answered_date),
    "qual_overrides: one row per scope x measurement_type" =
      !anyDuplicated(d[c("scope", "scope_value", "measurement_type")]))
  d
}

#' Read and validate sample_exclusions.csv
#' @param path the CSV.
#' @return a tibble, one row per excluded cast or bottle.
read_sample_exclusions <- function(path) {
  cols <- c("scope", "scope_value", "reason", "question_label", "answered_by", "answered_date")
  d <- .ba_read(path, cols)
  stopifnot(
    "sample_exclusions: scope must be cast_id or bottle_id" = all(d$scope %in% c("cast_id", "bottle_id")),
    "sample_exclusions: scope_value is an integer id" = all(grepl("^[0-9]+$", d$scope_value)),
    "sample_exclusions: every row cites its question and date" =
      !anyNA(d$question_label) && !anyNA(d$answered_date),
    "sample_exclusions: one row per id" = !anyDuplicated(d[c("scope", "scope_value")]))
  d
}

# SQL: the bottle_ids a scope names
.ba_bottles_sql <- function(scope, value, bottle_tbl, cast_tbl) {
  switch(scope,
    bottle_id  = glue::glue("SELECT bottle_id FROM {bottle_tbl} WHERE bottle_id = {as.numeric(value)}"),
    cast_id    = glue::glue("SELECT bottle_id FROM {bottle_tbl} WHERE cast_id = {as.numeric(value)}"),
    cruise_key = glue::glue("SELECT b.bottle_id FROM {bottle_tbl} b JOIN {cast_tbl} c USING (cast_id)
                             WHERE c.cruise_key = '{value}'"))
}

#' Set measurement_qual from qual_overrides.csv
#'
#' @param con DuckDB connection holding `tbl` (`bottle_id`, `measurement_type`, `measurement_qual`),
#'   `bottle_tbl` (`bottle_id`, `cast_id`) and `cast_tbl` (`cast_id`, `cruise_key`).
#' @param ov the overrides, from [read_qual_overrides()].
#' @param removed_tbl optional table of rows an earlier step deleted (`bottle_id`,
#'   `measurement_type`), counted as `n_removed_upstream`.
#' @return `ov` with `n_matched` (values in scope), `n_changed` (whose code differed) and
#'   `n_removed_upstream`.
apply_qual_overrides <- function(con, ov, tbl = "bottle_measurement", bottle_tbl = "bottle",
                                 cast_tbl = "casts", removed_tbl = NULL) {
  q_norm <- "regexp_replace(CAST(measurement_qual AS VARCHAR), '\\.0+$', '')"
  ov$n_matched <- ov$n_changed <- ov$n_removed_upstream <- 0
  for (i in seq_len(nrow(ov))) {
    btl <- .ba_bottles_sql(ov$scope[i], ov$scope_value[i], bottle_tbl, cast_tbl)
    where <- glue::glue("measurement_type = '{ov$measurement_type[i]}' AND bottle_id IN ({btl})")
    ov$n_matched[i] <- DBI::dbGetQuery(con, glue::glue("SELECT COUNT(*) AS n FROM {tbl} WHERE {where}"))$n
    ov$n_changed[i] <- DBI::dbExecute(con, glue::glue("
      UPDATE {tbl} SET measurement_qual = '{ov$qual[i]}'
      WHERE {where} AND {q_norm} IS DISTINCT FROM '{ov$qual[i]}'"))
    if (!is.null(removed_tbl))
      ov$n_removed_upstream[i] <- DBI::dbGetQuery(con, glue::glue(
        "SELECT COUNT(*) AS n FROM {removed_tbl} WHERE {where}"))$n
  }
  ov
}

#' Remove the casts and bottles sample_exclusions.csv names
#'
#' Deletes, in order, the measurements of the bottles, the bottles, the cast conditions and the
#' casts (a bottle-scoped row removes the bottle and its measurements only).
#'
#' @param con DuckDB connection holding `meas_tbl`, `bottle_tbl`, `cond_tbl` (`cast_id`) and
#'   `cast_tbl`.
#' @param ex the exclusions, from [read_sample_exclusions()].
#' @return `ex` with `n_casts`, `n_bottles`, `n_measurements` and `n_conditions` removed.
apply_sample_exclusions <- function(con, ex, meas_tbl = "bottle_measurement", bottle_tbl = "bottle",
                                    cond_tbl = "cast_condition", cast_tbl = "casts") {
  ex$n_casts <- ex$n_bottles <- ex$n_measurements <- ex$n_conditions <- 0
  for (i in seq_len(nrow(ex))) {
    id <- as.numeric(ex$scope_value[i])
    btl <- .ba_bottles_sql(ex$scope[i], ex$scope_value[i], bottle_tbl, cast_tbl)
    ex$n_measurements[i] <- DBI::dbExecute(con, glue::glue(
      "DELETE FROM {meas_tbl} WHERE bottle_id IN ({btl})"))
    ex$n_bottles[i] <- DBI::dbExecute(con, glue::glue(
      "DELETE FROM {bottle_tbl} WHERE bottle_id IN ({btl})"))
    if (ex$scope[i] == "cast_id") {
      ex$n_conditions[i] <- DBI::dbExecute(con, glue::glue(
        "DELETE FROM {cond_tbl} WHERE CAST(cast_id AS BIGINT) = {id}"))
      ex$n_casts[i] <- DBI::dbExecute(con, glue::glue(
        "DELETE FROM {cast_tbl} WHERE cast_id = {id}"))
    }
  }
  ex
}
