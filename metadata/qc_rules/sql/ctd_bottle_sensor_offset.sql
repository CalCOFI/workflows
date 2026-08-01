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
-- THE THRESHOLDS ARE OURS AND ARE PROVISIONAL — question calcofi_ctd-cast_10 asks
-- CalCOFI to replace them with the tolerances they actually apply. They are set
-- roughly an order of magnitude above each pair's expected agreement, so they flag
-- disagreement rather than measure it:
--
--   temperature  0.5 degC     SBE 3plus initial accuracy is 0.001 degC and a
--                             reversing thermometer is ~0.01, so anything at 0.5
--                             is not calibration drift.
--   salinity     0.05 PSS-78  a Portosal salinometer resolves ~0.001; 0.05 is a
--                             bottle mis-fire, a mis-recorded depth, or a
--                             conductivity cell problem.
--   oxygen       0.3 mL/L     Winkler titration reproducibility is ~0.01-0.02
--                             mL/L; SBE 43 accuracy is ~2% of saturation, which
--                             near the surface is ~0.1 mL/L. 0.3 is beyond both.
--
-- WHAT A FLAG DOES NOT ESTABLISH: which side is wrong. A hit says the pair
-- disagrees, not that the sensor drifted — a bottle fired at the wrong depth, a
-- transcription error, or a sample analysed late all present identically here. The
-- pattern is the evidence: a whole cast or cruise offset one way is sensor or
-- calibration; scattered singletons are usually the bottle side.
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
