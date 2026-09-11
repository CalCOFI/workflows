-- per-band yearly anomaly vs the release climatology (1993–2013), qual_ok, mean per cruise then per year
CREATE TEMP TABLE o AS SELECT dataset_key, measurement_type, site_key, cruise_key, year, month(datetime)::TINYINT AS month, depth_bin, value, depth_min_m
 FROM read_parquet('/Users/bbest/_big/calcofi/releases/v2026.09.10/parquet/obs_env/**/*.parquet', hive_partitioning=true)
 WHERE measurement_type IN ('temperature','oxygen_umol_kg','nitrate','chlorophyll_a','salinity') AND qual_ok AND value IS NOT NULL AND NOT isnan(value);
CREATE TEMP TABLE c AS SELECT * FROM read_parquet('/Users/bbest/_big/calcofi/releases/v2026.09.10/parquet/climatology/**/*.parquet', hive_partitioning=true)
 WHERE measurement_type IN ('temperature','oxygen_umol_kg','nitrate','chlorophyll_a','salinity');
CREATE TEMP TABLE bands AS SELECT * FROM (VALUES ('0-10',0,10),('10-50',10,50),('50-100',50,100),('100-200',100,200),('200-500',200,500),('500-1000',500,1000),('1000-2000',1000,2000),('2000+',2000,100000)) t(band, d0, d1);
-- values per band in obs (all), and those with a climatology match
CREATE TEMP TABLE ob AS SELECT o.*, b.band FROM o JOIN bands b ON o.depth_min_m >= b.d0 AND o.depth_min_m < b.d1;
CREATE TEMP TABLE a AS SELECT ob.measurement_type, ob.band, ob.year, ob.cruise_key, ob.value - c.clim_mean AS anom
 FROM ob JOIN c USING (dataset_key, measurement_type, site_key, month, depth_bin);
COPY (SELECT measurement_type, band, count(*) n_obs FROM ob GROUP BY ALL ORDER BY 1,2) TO 'band_n.csv' (HEADER);
COPY (SELECT measurement_type, band, year, round(avg(cm),4) AS anom, count(*) AS n_cruises, sum(n) AS n_values FROM (
   SELECT measurement_type, band, year, cruise_key, avg(anom) cm, count(*) n FROM a GROUP BY ALL) GROUP BY ALL ORDER BY 1,2,3) TO 'anom_bands.csv' (HEADER);
SELECT measurement_type, band, count(*) AS n_years, sum(n_values) AS n_vals FROM read_csv('anom_bands.csv') GROUP BY ALL ORDER BY 1, min(year), 2;
