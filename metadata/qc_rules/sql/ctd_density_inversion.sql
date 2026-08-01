-- Density must not decrease with depth. A sigma-theta inversion is either a real
-- (rare, shallow, transient) feature or — far more often — a spike, a mis-ordered
-- scan, or a salinity glitch propagating into the derived density.
--
-- A CTD-specific test with no counterpart in the bottle-era Access master, whose
-- checks are all range- and linkage-based at bottle grain.
--
-- THE 0.05 kg/m3 THRESHOLD IS OURS, not a CalCOFI or QARTOD standard, and it is
-- set from the observed distribution rather than from theory. Across the thinned
-- profiles the overwhelming majority of successive sigma-theta differences are
-- positive; of the negative ones, almost all are smaller than 0.01 kg/m3, which is
-- the scale of rounding and of the sensor's own resolution on a near-neutral
-- layer. 0.05 sits an order of magnitude above that floor, so it selects
-- inversions that no amount of rounding explains — 1,072 of 495,537 sigma-theta
-- observations, ~0.2%.
--
-- WHAT IT CANNOT SEE: this runs on ctd_thin, which retains roughly one sample per
-- 10 m. A genuine single-scan density inversion between retained depths is
-- invisible here; the profile rules on obs_ctd_full are where that would surface.
-- Nor does a pass mean the water column is stable — only that it is monotonic at
-- the depths retained.
--
-- params: {{threshold}}
WITH p AS (
  SELECT
    sample_key, cruise_key, depth_min_m,
    measurement_value AS sigma,
    LAG(measurement_value) OVER (
      PARTITION BY sample_key ORDER BY depth_min_m) AS sigma_above,
    LAG(depth_min_m) OVER (
      PARTITION BY sample_key ORDER BY depth_min_m) AS depth_above
  FROM obs
  WHERE dataset_key = 'calcofi_ctd-cast'
    AND measurement_type = 'sigma_theta_1'
    AND measurement_value IS NOT NULL
)
SELECT
  sample_key                                                   AS subject_key,
  'sigma-theta drops ' || round(sigma_above - sigma, 3) ||
    ' kg/m3 between ' || depth_above || ' and ' || depth_min_m || ' m' AS detail,
  cruise_key, depth_above, depth_min_m,
  'sigma_theta_1'                                              AS measurement_type,
  sigma_above, sigma,
  round(sigma_above - sigma, 4)                                AS inversion_magnitude
FROM p
WHERE sigma_above IS NOT NULL
  AND sigma_above - sigma > {{threshold}}
