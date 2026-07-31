-- Is the cast where it says it is?
--
-- Adapted from the Access master's `TQ - BottomDepth_Vs_AvgBottomDepth`, which
-- flagged casts whose bottom depth differed from the station's average by more
-- than 500 m. THE SEMANTICS DIFFER and that matters: the original compared the
-- ship's ECHOSOUNDER reading to the station average, catching both a bad sounder
-- and a mispositioned cast. CTD casts have no reported bottom depth, so this
-- compares GEBCO bathymetry AT THE RECORDED POSITION to the station average —
-- which tests position plausibility only. A cast logged at the wrong station, or
-- with a corrupted fix, lands in water of the wrong depth; a bad sounder reading
-- is invisible to this form.
--
-- The +/-500 m threshold is carried over from the Access original deliberately,
-- so results stay comparable to three decades of prior review. Measured on the
-- current data: median |difference| is 17 m, 90th percentile 76 m, 99th 190 m —
-- so 500 m is a genuine outlier, not a routine one. 6 casts exceed it.
--
-- Only the 75 current standard stations have an average depth on file, so casts
-- at other sites are not evaluated rather than being assumed fine.
--
-- params: {{tolerance_m}}
SELECT
  s.sample_key                                                  AS subject_key,
  'seafloor at the recorded position is ' || round(f.seafloor_depth_m, 1) ||
    ' m but station ' || s.site_key || ' averages ' ||
    round(st.avg_bottom_depth_m, 1) || ' m (' ||
    round(f.seafloor_depth_m - st.avg_bottom_depth_m, 1) || ' m off)'
                                                                AS detail,
  s.cruise_key, s.site_key,
  round(s.longitude, 4)                                         AS longitude,
  round(s.latitude, 4)                                          AS latitude,
  round(f.seafloor_depth_m, 1)                                  AS seafloor_depth_m,
  round(st.avg_bottom_depth_m, 1)                               AS station_avg_depth_m,
  round(f.seafloor_depth_m - st.avg_bottom_depth_m, 1)          AS difference_m
FROM sample s
JOIN sample_seafloor f USING (sample_key)
JOIN station st ON s.site_key = st.site_key
WHERE s.dataset_key = 'calcofi_ctd-cast'
  AND s.sample_type = 'cast'
  AND abs(f.seafloor_depth_m - st.avg_bottom_depth_m) > {{tolerance_m}}
