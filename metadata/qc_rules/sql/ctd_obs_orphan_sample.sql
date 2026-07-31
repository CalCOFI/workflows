-- Referential integrity: every obs must resolve to a sample.
-- Ported from the Access master's `TR -` family ("test for proper linkage
-- between tables"), rewritten against the core model.
SELECT
  o.sample_key                                                 AS subject_key,
  'obs row references a sample_key with no row in sample'      AS detail,
  o.cruise_key, o.measurement_type, o.depth_min_m
FROM obs o
LEFT JOIN sample s USING (sample_key)
WHERE o.dataset_key = 'calcofi_ctd-cast'
  AND s.sample_key IS NULL
