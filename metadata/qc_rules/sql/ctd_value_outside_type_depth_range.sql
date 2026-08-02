-- A value recorded outside the depth range over which its measurement type is
-- DEFINED. Not a range check on the value — a check that the type exists at all
-- at that depth.
--
-- Driven entirely by `valid_depth_min_m` / `valid_depth_max_m` in
-- metadata/measurement_type.csv, so it covers whatever the registry declares
-- rather than naming any type here. Today exactly one family declares a range:
--
--   est_chlorophyll_a_cruise_corr / _sta_corr : 0 - 200 m
--
-- CTD-CSV-Format.pdf states the fluorometer regression is applied to the 1 m
-- bin-averaged voltage over 0-200 m ONLY, so `EstChl_*` is undefined deeper by
-- CONSTRUCTION rather than by absence of data. That distinction had nowhere to
-- live until the registry gained the columns, and a completeness check reading a
-- null at 300 m would have called it missing data.
--
-- THIS RULE CURRENTLY REPORTS ZERO, AND THAT IS THE POINT. Measured against
-- obs_ctd_full on 2026-08-02:
--
--   est_chlorophyll_a_cruise_corr  1,993,043 values, max depth 200.0 m, 0 below
--   est_chlorophyll_a_sta_corr     2,243,906 values, max depth 200.0 m, 0 below
--
-- The data honours the documented restriction exactly, which is what licensed
-- writing 0/200 into the registry in the first place. Keeping the rule active is
-- what stops that silently ceasing to be true — the same standing-guard role
-- `ctd_sentinel_neg99` plays for the -99 sentinel.
--
-- For contrast, est_nitrate_* is 60% below 200 m and reaches 3,498 m, so it
-- declares no depth range and this rule correctly ignores it. The restriction is
-- specific to the chlorophyll regression, not to derived types in general.
--
-- Requires a `measurement_type` reference carrying the two columns, which means a
-- registry or release from v2026.08 on; against an older one the rule ERRORS
-- rather than passing, which is the correct failure.
--
-- Cruise-scoped like its `obs_ctd_full` peers: 212M rows is a sweep the app runs
-- one cruise at a time, not something to run inline.
--
-- params: {{cruise_key}}
SELECT
  o.sample_key                                                  AS subject_key,
  o.measurement_type || ' recorded at ' || round(o.depth_min_m, 1) ||
    ' m, outside the ' ||
    COALESCE(CAST(round(mt.valid_depth_min_m, 1) AS VARCHAR), '-inf') || ' to ' ||
    COALESCE(CAST(round(mt.valid_depth_max_m, 1) AS VARCHAR), 'inf') ||
    ' m range over which the type is defined'                   AS detail,
  o.cruise_key,
  o.depth_min_m,
  o.measurement_type,
  o.measurement_value
FROM obs_ctd_full o
JOIN measurement_type mt USING (measurement_type)
WHERE o.cruise_key = '{{cruise_key}}'
  AND o.measurement_value IS NOT NULL
  AND (   (mt.valid_depth_min_m IS NOT NULL AND o.depth_min_m < mt.valid_depth_min_m)
       OR (mt.valid_depth_max_m IS NOT NULL AND o.depth_min_m > mt.valid_depth_max_m))
ORDER BY o.depth_min_m DESC
