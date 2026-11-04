# CTD flag inheritance (ingest_calcofi_ctd-cast.qmd, § Inherit Flags Into Sigma-Theta).
#
# A provider's quality flag outranks everything we derive (CLAUDE.md, measurement-bounds skill):
# a value computed from a temperature or salinity the provider flags 8 (questionable) or 9 (bad)
# is not good because its own flag column is blank. The 2026 processing software flags
# SigThetaTS1Q / SigThetaTS2Q less often than the Temp / Salt flags they derive from (2607 casts
# 1U, 5D, 6U: Temp2Q 9, SigThetaTS2Q blank; 4,947 such bins on 22 cruises in v2026.10.19), and
# sigma_theta_ave and the mixed-layer depths read only the sigma flags.
#
# inherit_sensor_flags() writes the sensor's 8/9 onto the derived series wherever the derived row
# has no 8/9 of its own (the provider's own 8/9 is kept; any other code is replaced), counting
# 9 over 8 when both sensors are flagged ('9' sorts above '8', so max() of the text codes is enough
# and a 'nan' code is never cast). count_uninherited_flags() is the assertion: derived rows
# whose sensor is flagged 8/9 and which are not.

# SQL fragment: a quality code as '8' / '9' text with a trailing '.0' removed
.ctd_q_norm <- function(col) glue::glue("regexp_replace(CAST({col} AS VARCHAR), '\\.0+$', '')")

#' Write a sensor's 8/9 flag onto the series derived from it
#'
#' @param con DuckDB connection holding `tbl` (`ctd_cast_uuid`, `depth_m`, `measurement_type`,
#'   `measurement_qual`).
#' @param derived the derived `measurement_type`, e.g. `"sigma_theta_2"`.
#' @param from the `measurement_type`s it is computed from, e.g. `c("temperature_2", "salinity_2")`.
#' @param tbl the long measurement table.
#' @return the number of `derived` rows newly flagged.
inherit_sensor_flags <- function(con, derived, from, tbl = "ctd_measurement") {
  stopifnot(is.character(derived), length(derived) == 1, is.character(from), length(from) >= 1)
  q    <- .ctd_q_norm("measurement_qual")
  from_sql <- paste0("'", from, "'", collapse = ", ")
  src <- glue::glue("
    SELECT ctd_cast_uuid, depth_m, max({q}) AS code
    FROM {tbl}
    WHERE measurement_type IN ({from_sql}) AND {q} IN ('8', '9')
    GROUP BY ctd_cast_uuid, depth_m")
  own_flagged <- glue::glue("COALESCE({.ctd_q_norm('m.measurement_qual')} IN ('8', '9'), FALSE)")
  n <- DBI::dbGetQuery(con, glue::glue("
    SELECT count(*) AS n FROM {tbl} m JOIN ({src}) f
      ON m.ctd_cast_uuid = f.ctd_cast_uuid AND m.depth_m = f.depth_m
    WHERE m.measurement_type = '{derived}' AND NOT {own_flagged}"))$n
  DBI::dbExecute(con, glue::glue("
    UPDATE {tbl} m SET measurement_qual = f.code
    FROM ({src}) f
    WHERE m.measurement_type = '{derived}' AND m.ctd_cast_uuid = f.ctd_cast_uuid
      AND m.depth_m = f.depth_m AND NOT {own_flagged}"))
  as.integer(n)
}

#' Derived rows whose sensor is flagged 8/9 and which are not (must be 0)
#' @inheritParams inherit_sensor_flags
count_uninherited_flags <- function(con, derived, from, tbl = "ctd_measurement") {
  q <- .ctd_q_norm("measurement_qual")
  from_sql <- paste0("'", from, "'", collapse = ", ")
  own_flagged <- glue::glue("COALESCE({.ctd_q_norm('m.measurement_qual')} IN ('8', '9'), FALSE)")
  as.integer(DBI::dbGetQuery(con, glue::glue("
    SELECT count(*) AS n FROM {tbl} m
    WHERE m.measurement_type = '{derived}' AND NOT {own_flagged}
      AND EXISTS (SELECT 1 FROM {tbl} f
                  WHERE f.ctd_cast_uuid = m.ctd_cast_uuid AND f.depth_m = m.depth_m
                    AND f.measurement_type IN ({from_sql}) AND {.ctd_q_norm('f.measurement_qual')} IN ('8', '9'))"))$n)
}
