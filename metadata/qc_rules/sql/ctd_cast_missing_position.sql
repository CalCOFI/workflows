-- Casts with no usable position. The ingest backfills lon/lat by projecting
-- line/station through +proj=calcofi and asserts none remain, so a hit here means
-- that guard regressed or a new failure mode appeared upstream.
SELECT
  sample_key                                                   AS subject_key,
  'cast has NULL longitude or latitude'                        AS detail,
  cruise_key, site_key, datetime
FROM sample
WHERE dataset_key = 'calcofi_ctd-cast'
  AND sample_type = 'cast'
  AND (longitude IS NULL OR latitude IS NULL)
