-- Down- and upcast disagree at the same depth.
--
-- The two directions sample the same water column minutes apart, so a large
-- difference means sensor lag, a thermal-mass artefact, fouling, or genuine
-- internal-wave motion. `ctd_thin` keeps ONE direction per physical cast, so this
-- signal is invisible in the headline table and only exists in obs_ctd_full.
--
-- Pairing is by stripping the trailing direction character from sample_key.
-- Note the trap: a naive replace(sample_key,'d','') also mangles the
-- 'calcofi_ctd-cast' prefix, so this uses left(..., length-1).
--
-- Depths are rounded to 1 m before matching: the two directions never sample the
-- exact same depth, and the source is already ~1 m bin-averaged.
--
-- Measured on 2023-11-33P4, temperature, 27,274 matched depths: median difference
-- 0.026 degC, 99th percentile 0.90, maximum 46.1 — so the tail is dramatic and
-- worth surfacing, while the bulk is tight.
--
-- params: {{cruise_key}} {{measurement_type}} {{threshold}}
WITH b AS (
  SELECT
    left(sample_key, length(sample_key) - 1)                       AS cast_base,
    right(sample_key, 1)                                           AS cast_dir,
    ANY_VALUE(cruise_key)                                          AS cruise_key,
    ROUND(depth_min_m)                                             AS depth_m,
    AVG(measurement_value)                                         AS v
  FROM obs_ctd_full
  WHERE cruise_key       = '{{cruise_key}}'
    AND measurement_type = '{{measurement_type}}'
    AND measurement_value IS NOT NULL
  GROUP BY 1, 2, 4
)
SELECT
  d.cast_base || 'd'                                               AS subject_key,
  '{{measurement_type}} differs by ' || round(abs(d.v - u.v), 3) ||
    ' between down- and upcast at ' || d.depth_m || ' m'           AS detail,
  d.cruise_key,
  d.depth_m                                                        AS depth_min_m,
  '{{measurement_type}}'                                           AS measurement_type,
  round(d.v, 4)                                                    AS value_down,
  round(u.v, 4)                                                    AS value_up,
  round(d.v - u.v, 4)                                              AS difference
FROM      (SELECT * FROM b WHERE cast_dir = 'd') d
JOIN      (SELECT * FROM b WHERE cast_dir = 'u') u USING (cast_base, depth_m)
WHERE abs(d.v - u.v) > {{threshold}}
