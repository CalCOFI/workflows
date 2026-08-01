-- Values outside the declared plausible physical range.
-- Ranges live in metadata/measurement_type.csv (valid_min / valid_max), moved
-- there from an inline tribble so they are reviewable and reusable. Generous by
-- design: this catches impossible values, it does not police oceanography.
--
-- COVERAGE IS PARTIAL AND A PASS MUST NOT BE READ AS "ALL VALUES ARE SANE".
-- 18 of the 27 measurement types in the published CTD obs carry a declared range;
-- the other 9 are never evaluated by this rule — beam_attenuation, btl_depth,
-- dynamic_height, fluorescence_v, isus_v, par, spar, specific_volume_anomaly,
-- transmissometer. Most are raw sensor voltages or derived quantities with no
-- agreed physical bound, which is why they have none rather than an oversight.
-- The rule reports one row per violating value, so a single bad cruise dominates
-- the count: read it alongside the per-type and per-cruise breakdowns, not as a
-- single number.
--
-- The ranges are OURS, not CalCOFI's, and question calcofi_ctd-cast_02 asks the
-- providers to confirm or replace them. Nothing is dropped on the strength of
-- them.
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
