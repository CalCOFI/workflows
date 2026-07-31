-- Regression guard for the -99 sentinel fix (ingest_calcofi_ctd-cast.qmd).
-- -99 is this source's documented missing marker. It was stripped from
-- longitude/latitude only, so it flowed into released measurements as a real
-- reading (84,302 rows in v2026.07.17, incl. canonical oxygen). Expected: 0.
SELECT
  sample_key                                                   AS subject_key,
  measurement_type || ' = -99 at ' || depth_min_m || ' m'       AS detail,
  cruise_key, measurement_type, depth_min_m, measurement_value
FROM obs
WHERE dataset_key = 'calcofi_ctd-cast'
  AND measurement_value = -99
