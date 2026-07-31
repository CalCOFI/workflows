-- Depth reversal within a single cast direction — a loop edit.
--
-- A downcast should descend monotonically IN TIME; when the ship heaves, the
-- package can rise and re-sample water it already passed through, which corrupts
-- the profile. Seasoft's bin-averaging normally removes these, so survivors are
-- worth seeing.
--
-- ORDERING IS BY datetime, NOT obs_id. This matters: obs_id does not follow scan
-- order (measured: 27,272 of 54,505 consecutive obs_id pairs have DECREASING
-- depth, i.e. ~50%, which is what you get from an unrelated sort). datetime is
-- genuinely per-scan — 55 distinct timestamps for 55 scans in one cast — so it is
-- the only recoverable scan sequence. Ordering by obs_id would report every cast
-- as a mass of reversals.
--
-- Direction comes from the sample_key suffix (…001d / …001u), which pairs
-- perfectly (70 down / 70 up on 2023-11-33P4).
--
-- Measured reversals per cruise: 2 (2023-11-33P4), 10 (1998-07-32NM),
-- 19 (2013-01-3322); largest single reversal 59 m.
--
-- params: {{cruise_key}} {{min_reversal_m}}
WITH x AS (
  SELECT
    sample_key, cruise_key, datetime, depth_min_m,
    right(sample_key, 1)                                           AS cast_dir,
    LAG(depth_min_m) OVER (PARTITION BY sample_key ORDER BY datetime, depth_min_m) AS depth_prev,
    LAG(datetime)    OVER (PARTITION BY sample_key ORDER BY datetime, depth_min_m) AS datetime_prev
  FROM obs_ctd_full
  WHERE cruise_key       = '{{cruise_key}}'
    AND measurement_type = 'temperature_ave'
    AND depth_min_m IS NOT NULL
)
SELECT
  sample_key                                                       AS subject_key,
  CASE cast_dir WHEN 'd' THEN 'downcast rose ' ELSE 'upcast sank ' END ||
    round(abs(depth_prev - depth_min_m), 1) || ' m (from ' ||
    round(depth_prev, 1) || ' to ' || round(depth_min_m, 1) || ' m)' AS detail,
  cruise_key, cast_dir, datetime_prev, datetime,
  round(depth_prev, 1)                                             AS depth_prev_m,
  round(depth_min_m, 1)                                            AS depth_m,
  round(abs(depth_prev - depth_min_m), 1)                          AS reversal_m
FROM x
WHERE depth_prev IS NOT NULL
  AND (   (cast_dir = 'd' AND depth_prev - depth_min_m > {{min_reversal_m}})
       OR (cast_dir = 'u' AND depth_min_m - depth_prev > {{min_reversal_m}}))
