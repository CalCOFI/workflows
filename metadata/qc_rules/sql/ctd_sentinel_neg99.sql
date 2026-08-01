-- Regression guard for the -99 sentinel fix (ingest_calcofi_ctd-cast.qmd).
-- -99 is this source's documented missing marker. It was stripped from
-- longitude/latitude only, so it flowed into released measurements as a real
-- reading (84,302 rows in v2026.07.17, incl. canonical oxygen). Expected: 0.
--
-- MATCHED EXACTLY (= -99), not by tolerance: every observed case was exactly
-- -99.00, and an exact test cannot swallow a real reading that merely rounds near
-- it. Two types are genuinely signed (dynamic_height, specific_volume_anomaly), so
-- a real -99 there would be reported rather than assumed away.
--
-- ONLY -99 IS CHECKED. Other conventional markers (-999, -9.99) are not searched
-- for here, and -9.99e-29 is handled separately as a pseudo-NA in the ingest. A
-- pass means this sentinel is gone, not that the source carries no others.
SELECT
  sample_key                                                   AS subject_key,
  measurement_type || ' = -99 at ' || depth_min_m || ' m'       AS detail,
  cruise_key, measurement_type, depth_min_m, measurement_value
FROM obs
WHERE dataset_key = 'calcofi_ctd-cast'
  AND measurement_value = -99
