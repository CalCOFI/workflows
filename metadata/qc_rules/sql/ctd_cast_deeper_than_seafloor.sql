-- A cast cannot measure below the seafloor.
--
-- Compares each cast's deepest observation against GEBCO 2025 bathymetry sampled
-- at the cast position (materialized as sample_seafloor by ctd-qaqc's prep_db.R,
-- reusing the cropped raster apps/ctd-viz already maintains).
--
-- CTD casts carry NO reported bottom depth — bottom_depth exists in
-- sample_measurement for 33,363 BOTTLE casts but for 0 of 14,336 CTD casts — so a
-- bathymetry model is the only available reference here.
--
-- EXPECT THIS TO PASS, and value it anyway. Measured against the current data the
-- agreement is already excellent: median cast stops ~982 m ABOVE the seafloor,
-- the 99th percentile excess is +4 m and the maximum is +52 m. This is a
-- regression guard — a depth unit error, a sign flip, or a position corruption
-- would blow it up immediately, and none of those is otherwise detectable.
--
-- The tolerance absorbs GEBCO's own uncertainty: the raster is ~0.0042 deg
-- (~460 m) per cell, so a cast on a steep slope can legitimately read deeper than
-- the cell average. 88 casts exceed the seafloor by any amount; only 2 exceed it
-- by more than 50 m.
--
-- params: {{tolerance_m}}
WITH d AS (
  SELECT
    o.sample_key,
    MAX(o.depth_min_m)      AS max_measured_depth_m,
    ANY_VALUE(o.cruise_key) AS cruise_key
  FROM obs o
  WHERE o.dataset_key = 'calcofi_ctd-cast' AND o.depth_min_m IS NOT NULL
  GROUP BY 1
)
SELECT
  d.sample_key                                                  AS subject_key,
  'deepest measurement ' || round(d.max_measured_depth_m, 1) ||
    ' m is ' || round(d.max_measured_depth_m - f.seafloor_depth_m, 1) ||
    ' m below the GEBCO seafloor (' || round(f.seafloor_depth_m, 1) || ' m)'
                                                                AS detail,
  d.cruise_key, s.site_key,
  round(d.max_measured_depth_m, 1)                              AS max_measured_depth_m,
  round(f.seafloor_depth_m, 1)                                  AS seafloor_depth_m,
  round(d.max_measured_depth_m - f.seafloor_depth_m, 1)         AS excess_m
FROM d
JOIN sample_seafloor f USING (sample_key)
JOIN sample s          USING (sample_key)
WHERE d.max_measured_depth_m - f.seafloor_depth_m > {{tolerance_m}}
