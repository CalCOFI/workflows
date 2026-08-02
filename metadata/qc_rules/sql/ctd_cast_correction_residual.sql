-- Does the published CORRECTED series still reproduce the bottle reference it was
-- fitted to? This is a different question from ctd_bottle_sensor_offset, which
-- flags one bottle-sensor pair at one depth. Here the unit is the CAST, and the
-- statistic is the mean residual over all its matched pairs.
--
-- WHY THE MEAN, AND WHY THIS IS NOT AN INVENTED THRESHOLD. The source documents
-- the correction scheme: `_StaCorr` fits a regression PER CAST from 1 m
-- bin-averaged sensor data against that cast's bottles, and salinity is offset
-- from bottle salinities below 350 m. Both are fitted to make the per-cast
-- residual vanish — so a cast where it has NOT vanished is a cast where the
-- correction did not take, which is a far stronger statement than "these two
-- disagree".
--
-- Measured over the whole archive (245 CTDBTL files, 85 cruises, the ingest
-- parquet of 2026-08-02), that is exactly what the data shows:
--
--   oxygen_btl_ml_l vs oxygen_ml_l_ave_sta_corr, 5,330 casts with >= 3 pairs
--     |mean residual| < 1e-4 mL/L : 83.1% of casts       <- fitted to zero
--     p50 2.7e-05 | p90 0.032 | p95 0.087 | p99 0.574
--   salinity_btl vs salinity_ave_corr below 350 m, 4,182 casts with >= 3 pairs
--     p50 0.0021 | p90 0.0087 | p95 0.0148 | p99 0.106
--
-- The oxygen distribution is bimodal: a spike at machine zero and a tail. The
-- threshold sits in the gap, not at a percentile chosen for taste. Salinity is
-- not zeroed to machine precision (the offset is a single constant fitted with
-- fliers omitted, and applied at all depths), but is an order of magnitude
-- tighter than the point-wise tolerance.
--
-- The MEAN is deliberate and was checked against the alternative: taking the
-- MEDIAN residual instead destroys the signal for oxygen (only 0.6% of casts fall
-- within 1e-4, against 83.1% for the mean), which confirms the fit zeroes the
-- mean over the bottles it used rather than a robust centre.
--
-- `residual_sd` IS THE CANDIDATE FOR `measurement_prec`. The core declares that
-- column and no dataset populates it; the per-cast residual standard deviation
-- is precisely the per-value uncertainty it exists to carry, and is what the
-- provider's own `YYMM_DBcoeff_###-###.csv` records as `Salt1_SD` /
-- `Ox1_StaCorrSD` (question calcofi_ctd-cast_15). It is REPORTED here and acted
-- on nowhere: until DBcoeff is ingested we cannot check our reconstruction
-- against theirs, and populating measurement_prec from an unvalidated
-- reconstruction would be worse than leaving it NULL.
--
-- WHAT A FLAG DOES NOT ESTABLISH: which side is wrong, same as the point-wise
-- rule. A cast whose bottles were all analysed late, or whose bottle depths were
-- mis-recorded, presents identically to one whose correction was never applied.
--
-- params: {{bottle_type}} {{sensor_type}} {{depth_min}} {{min_n}} {{threshold}} {{units}}
WITH pairs AS (
  SELECT b.sample_key,
         b.cruise_key,
         b.measurement_value - s.measurement_value AS residual
  FROM obs b
  JOIN obs s
    ON  s.sample_key   = b.sample_key
    AND s.depth_min_m  = b.depth_min_m
    AND s.dataset_key  = b.dataset_key
    AND s.measurement_type = '{{sensor_type}}'
  WHERE b.dataset_key      = 'calcofi_ctd-cast'
    AND b.measurement_type = '{{bottle_type}}'
    -- salinity is corrected from bottles BELOW 350 m only, so the check has to
    -- look where the fit looked; {{depth_min}} is 0 for the unrestricted pairs
    AND b.depth_min_m >= {{depth_min}}
), agg AS (
  SELECT sample_key, cruise_key,
         COUNT(*)                     AS n_pair,
         AVG(residual)                AS mean_residual,
         -- STDDEV_SAMP of a single row is NULL, which is why min_n is >= 3
         STDDEV_SAMP(residual)        AS residual_sd,
         MAX(ABS(residual))           AS max_abs_residual
  FROM pairs
  GROUP BY 1, 2
)
SELECT
  sample_key                                                    AS subject_key,
  'corrected {{sensor_type}} does not reproduce {{bottle_type}}: mean residual ' ||
    round(mean_residual, 4) || ' {{units}} over ' || n_pair ||
    ' bottle pairs (sd ' || round(COALESCE(residual_sd, 0), 4) || ')'
                                                                AS detail,
  cruise_key,
  -- the SENSOR type: that is the profile a reviewer needs on screen. No
  -- depth_min_m — the finding is a property of the cast, not of one scan, so the
  -- app opens the profile without ringing a depth.
  '{{sensor_type}}'                                             AS measurement_type,
  n_pair,
  round(mean_residual, 5)                                       AS mean_residual,
  round(residual_sd, 5)                                         AS residual_sd,
  round(max_abs_residual, 5)                                    AS max_abs_residual
FROM agg
WHERE n_pair >= {{min_n}}
  AND ABS(mean_residual) > {{threshold}}
ORDER BY ABS(mean_residual) DESC
