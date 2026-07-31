-- Values outside the declared plausible physical range.
-- Ranges live in metadata/measurement_type.csv (valid_min / valid_max), moved
-- there from an inline tribble so they are reviewable and reusable. Generous by
-- design: this catches impossible values, it does not police oceanography.
SELECT
  o.sample_key                                                 AS subject_key,
  o.measurement_type || ' = ' || o.measurement_value ||
    ' outside [' || m.valid_min || ', ' || m.valid_max || ']'  AS detail,
  o.cruise_key, o.measurement_type, o.depth_min_m,
  o.measurement_value, m.valid_min, m.valid_max
FROM obs o
JOIN measurement_type m USING (measurement_type)
WHERE o.dataset_key = 'calcofi_ctd-cast'
  AND m.valid_min IS NOT NULL
  AND (o.measurement_value < m.valid_min OR o.measurement_value > m.valid_max)
