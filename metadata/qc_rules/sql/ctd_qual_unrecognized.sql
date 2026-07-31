-- Quality codes absent from the controlled vocabulary.
-- The vocabulary (metadata/measurement_qual.csv) was recovered from the CalCOFI
-- hydrographic master: 6 = data OK but taken from CTD, 8 = suspect, 9 = missing.
-- A code outside it means either an undocumented convention or corruption, and
-- must not be silently treated as "some flag".
SELECT
  o.sample_key                                                 AS subject_key,
  'unrecognized quality code "' || o.measurement_qual || '" on '
    || o.measurement_type                                      AS detail,
  o.cruise_key, o.measurement_type, o.depth_min_m, o.measurement_qual
FROM obs o
LEFT JOIN measurement_qual q ON o.measurement_qual = q.qual_code
WHERE o.dataset_key = 'calcofi_ctd-cast'
  AND o.measurement_qual IS NOT NULL
  AND q.qual_code IS NULL
