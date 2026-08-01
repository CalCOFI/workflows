-- Quality codes absent from the controlled vocabulary.
--
-- THE VOCABULARY IS DATASET-SCOPED, and getting that wrong was a real error here.
-- It was first recovered from the CalCOFI hydrographic master (the BOTTLE
-- database: 6 = data OK but taken from CTD, 8 = suspect, 9 = missing), and the
-- CTD files use a DIFFERENT set — documented all along in CTD-CSV-Format.pdf,
-- which ships inside every source zip:
--
--   0 or blank  good data ("if no data code is displayed then sensors were
--               operating normally")
--   1           USE PRIMARY sensor data      <- a sensor-selection instruction,
--   2           USE SECONDARY sensor data       NOT a quality grade
--   8           data questionable
--   9           bad OR missing sensor data
--
-- Two consequences worth stating. Codes 1 and 2 do not rank a value at all — they
-- say which half of a dual-sensor pair to believe, so treating them as "mildly
-- good" is a category error. And 9 means bad *or* missing, so a row flagged 9 that
-- carries a number is bad data rather than the contradiction it first looks like.
--
-- `measurement_qual.csv` therefore carries a `code_set` column, and this rule
-- filters to the CTD set. Joining the whole file would let a bottle-only code
-- mask a genuinely unrecognized CTD one.
--
-- A code outside the set means either an undocumented convention or corruption,
-- and must not be silently treated as "some flag".
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
LEFT JOIN (SELECT * FROM measurement_qual WHERE code_set = 'ctd') q
       ON o.measurement_qual = q.qual_code
WHERE o.dataset_key = 'calcofi_ctd-cast'
  AND o.measurement_qual IS NOT NULL
  AND q.qual_code IS NULL
