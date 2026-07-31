-- Climatological anomaly: how far a value sits from what this station, at this
-- depth, at this time of year, normally reads.
--
-- This is the CalCOFI hydrographic master's own expected-value engine, ported.
-- HarmCoeffBottle holds a fitted annual harmonic per station x standard depth x
-- property (mean, amplitude, frequency, phase, and the residual standard
-- deviation), which turns "is this value plausible" from a fixed global range
-- into a local, seasonal question. Nothing in the pipeline did this before.
--
-- RECONSTRUCTION FORM — determined empirically, not assumed. The providers have
-- not confirmed the fitting procedure (question hydro_master_12), so candidate
-- forms were scored against the 200,640 bottle observations the coefficients were
-- derived from. `Mean + Ampl*sin(Freq*(doy - Phase))` cut RMSE 25.2% below using
-- the mean alone; every cosine variant did WORSE than the mean. See the header of
-- libs/build_qc_reference.R for the full table and the two independent checks
-- (seasonal signal decaying correctly with depth; residuals/StDev ~ N(0,1)).
--
-- DEPTH MATCHING is nearest-within-tolerance, not exact. ctd_thin retains the
-- actual scan nearest each ~10 m level rather than resampling to round numbers,
-- so observed depths look like 0.968, 10.03, 19.97 — an equality join would match
-- almost nothing. The tolerance is well under the 10 m spacing, so the nearest
-- standard depth is unambiguous; QUALIFY keeps exactly one match per observation.
--
-- Standard depths 75 m and 125 m are effectively unreachable: they are not
-- multiples of 10, so the thinning grid rarely puts a scan within tolerance. That
-- is a coverage limit of the grid, not a defect of this rule.
--
-- DEGENERATE CELLS ARE EXCLUDED. A few station x depth cells carry a StDev of
-- effectively zero, which makes z explode — one nitrite cell produced z = 3.5e12
-- before this guard, which is an artifact of dividing by ~0, not a finding. A
-- zero-variance climatology means too few observations in that cell, not a
-- perfect fit.
--
-- params: {{depth_tol}} {{z_threshold}} {{min_stdev}}
WITH o AS (
  SELECT
    o.sample_key, o.cruise_key, o.measurement_type,
    o.depth_min_m, o.measurement_value,
    s.site_key,
    CAST(strftime(o.datetime, '%j') AS DOUBLE) AS doy
  FROM obs o
  JOIN sample s USING (sample_key)
  WHERE o.dataset_key = 'calcofi_ctd-cast'
    AND o.measurement_value IS NOT NULL
    AND o.datetime IS NOT NULL
), m AS (
  SELECT
    o.*,
    c.depth_m AS std_depth_m,
    c.coef_mean, c.coef_ampl, c.coef_freq, c.coef_phase, c.coef_stdev
  FROM o
  JOIN climatology_harmonic c
    ON  o.site_key         = c.site_key
    AND o.measurement_type = c.measurement_type
    AND abs(o.depth_min_m - c.depth_m) <= {{depth_tol}}
  WHERE c.coef_stdev >= {{min_stdev}}
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY o.sample_key, o.measurement_type, o.depth_min_m
    ORDER BY abs(o.depth_min_m - c.depth_m)) = 1
), z AS (
  SELECT
    m.*,
    coef_mean + coef_ampl * sin(coef_freq * (doy - coef_phase)) AS expected,
    (measurement_value
       - (coef_mean + coef_ampl * sin(coef_freq * (doy - coef_phase))))
      / coef_stdev                                              AS z_score
  FROM m
)
SELECT
  sample_key                                                    AS subject_key,
  measurement_type || ' = ' || round(measurement_value, 3) ||
    ' at ' || round(depth_min_m, 1) || ' m is ' || round(z_score, 1) ||
    ' SD from the ' || site_key || ' climatology (expected ' ||
    round(expected, 3) || ')'                                   AS detail,
  cruise_key, site_key, measurement_type,
  depth_min_m, std_depth_m,
  round(measurement_value, 4) AS observed,
  round(expected, 4)          AS expected,
  round(coef_stdev, 4)        AS clim_stdev,
  round(z_score, 2)           AS z_score
FROM z
WHERE abs(z_score) > {{z_threshold}}
