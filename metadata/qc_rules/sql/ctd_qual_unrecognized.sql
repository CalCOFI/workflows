-- Quality codes absent from the controlled vocabulary.
-- The vocabulary (metadata/measurement_qual.csv) was recovered from the CalCOFI
-- hydrographic master: 6 = data OK but taken from CTD, 8 = suspect, 9 = missing.
-- A code outside it means either an undocumented convention or corruption, and
-- must not be silently treated as "some flag".
--
-- A PASS HERE IS ALMOST EMPTY OF MEANING, and that is the finding. Only 8 of the
-- 27 published measurement types carry any flag at all (isus_v, ph, par,
-- transmissometer, fluorescence_v, sigma_theta_1, spar, pressure), covering 3,947
-- of 7.3M rows — 0.05%. The canonical temperature, salinity and oxygen types have
-- no quality column whatsoever, because the source flags attach to the component
-- sensors (Temp1Q, Salt1Q, Ox1Q, Ox2Q) while the canonical types are the averages
-- of them (question calcofi_ctd-cast_09). So this rule tests that the few flags
-- present use known codes; it cannot tell you whether a headline value is good.
--
-- It also does not judge the flag. Every one of the 3,052 rows flagged 9 =
-- "missing data" nevertheless carries a value, some of them impossible — a
-- contradiction this rule passes over, because 9 is in the vocabulary
-- (question calcofi_ctd-cast_13).
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
