-- THE classic CTD calibration check: sensor vs bottle reference at the same cast
-- and depth. The bottle side is a lab measurement (Winkler oxygen, Portosal
-- salinity, reversing-thermometer temperature) and is the closer thing to truth;
-- a persistent offset means sensor drift, a bad calibration coefficient, or a
-- mis-fired bottle.
--
-- This was impossible until the btl_* / *_btl types were made canonical — before
-- that the reference side was excluded from `obs` entirely.
--
-- Bottle values are NOT depth-thinned (retained_reason = 'bottle' in the ingest),
-- so the join is on exact depth: a bottle fires at discrete depths that the ~10 m
-- grid would otherwise discard.
--
-- params: {{bottle_type}} {{sensor_type}} {{threshold}} {{units}}
WITH b AS (
  SELECT sample_key, depth_min_m, measurement_value AS v_bottle
  FROM obs
  WHERE dataset_key = 'calcofi_ctd-cast' AND measurement_type = '{{bottle_type}}'
), s AS (
  SELECT sample_key, depth_min_m, measurement_value AS v_sensor
  FROM obs
  WHERE dataset_key = 'calcofi_ctd-cast' AND measurement_type = '{{sensor_type}}'
)
SELECT
  b.sample_key                                                 AS subject_key,
  '{{bottle_type}} vs {{sensor_type}} differ by ' ||
    round(abs(b.v_bottle - s.v_sensor), 3) || ' {{units}} at ' ||
    b.depth_min_m || ' m'                                      AS detail,
  o.cruise_key,
  b.depth_min_m,
  b.v_bottle,
  s.v_sensor,
  round(b.v_bottle - s.v_sensor, 4)                            AS offset_bottle_minus_sensor
FROM b
JOIN s USING (sample_key, depth_min_m)
JOIN (SELECT DISTINCT sample_key, cruise_key FROM obs
      WHERE dataset_key = 'calcofi_ctd-cast') o USING (sample_key)
WHERE abs(b.v_bottle - s.v_sensor) > {{threshold}}
