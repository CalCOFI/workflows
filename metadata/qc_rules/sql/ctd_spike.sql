-- Single-scan spike against a locally smooth profile.
--
-- Runs against obs_ctd_full — the full-resolution scans — because a spike is by
-- definition a single-scan excursion and ctd_thin has already discarded most
-- scans. Cruise-scoped: obs_ctd_full is 212M rows, hive-partitioned by cruise_key,
-- so one cruise prunes to ~2M rows and returns in well under a second, while an
-- unscoped run would scan the lot.
--
-- NEIGHBOUR AGREEMENT IS THE WHOLE TRICK. The naive test — value differs from the
-- midpoint of its neighbours — also fires on every steep-but-smooth gradient, and
-- a CTD profile through a thermocline is nothing but steep smooth gradients. So a
-- point qualifies only if it deviates from the neighbour midpoint by more than
-- {{spike_threshold}} WHILE the neighbours agree with each other within
-- {{neighbour_tol}}: the profile is locally smooth and this one scan is not.
--
-- Measured on cruise 2023-11-33P4, temperature, 54,365 scans:
--   naive |v - (a+b)/2| > 0.5           92 scans
--   + neighbours agree within 0.5       19 scans   <- 73 were real gradients
--   thresholds at 2.0                    3 scans
--
-- params: {{cruise_key}} {{measurement_type}} {{spike_threshold}} {{neighbour_tol}}
WITH x AS (
  SELECT
    sample_key, cruise_key, depth_min_m, datetime,
    measurement_value                                              AS v,
    LAG(measurement_value)  OVER (PARTITION BY sample_key ORDER BY depth_min_m) AS v_above,
    LEAD(measurement_value) OVER (PARTITION BY sample_key ORDER BY depth_min_m) AS v_below
  FROM obs_ctd_full
  WHERE cruise_key       = '{{cruise_key}}'
    AND measurement_type = '{{measurement_type}}'
    AND measurement_value IS NOT NULL
)
SELECT
  sample_key                                                       AS subject_key,
  '{{measurement_type}} spike at ' || round(depth_min_m, 1) || ' m: ' ||
    round(v, 3) || ' between ' || round(v_above, 3) || ' and ' ||
    round(v_below, 3)                                              AS detail,
  cruise_key, depth_min_m, datetime,
  round(v, 4)                                                      AS value,
  round(v_above, 4)                                                AS value_above,
  round(v_below, 4)                                                AS value_below,
  round(abs(v - (v_above + v_below) / 2), 4)                       AS excursion,
  round(abs(v_above - v_below), 4)                                 AS neighbour_gap
FROM x
WHERE v_above IS NOT NULL AND v_below IS NOT NULL
  AND abs(v - (v_above + v_below) / 2) > {{spike_threshold}}
  AND abs(v_above - v_below)           < {{neighbour_tol}}
