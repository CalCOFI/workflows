-- Density must not decrease with depth. A sigma-theta inversion is either a real
-- (rare, shallow, transient) feature or — far more often — a spike, a mis-ordered
-- scan, or a salinity glitch propagating into the derived density.
--
-- A CTD-specific test with no counterpart in the bottle-era Access master, whose
-- checks are all range- and linkage-based at bottle grain.
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
  cruise_key, depth_above, depth_min_m, sigma_above, sigma,
  round(sigma_above - sigma, 4)                                AS inversion_magnitude
FROM p
WHERE sigma_above IS NOT NULL
  AND sigma_above - sigma > {{threshold}}
