CREATE TEMP TABLE o AS SELECT dataset_key, measurement_type, site_key, cruise_key, year, month(datetime)::TINYINT AS month, depth_bin, value, depth_min_m
 FROM read_parquet('/Users/bbest/_big/calcofi/releases/v2026.09.10/parquet/obs_env/**/*.parquet', hive_partitioning=true)
 WHERE measurement_type IN ('temperature','oxygen_umol_kg','nitrate','chlorophyll_a','salinity','phosphate','silicate','synechococcus') AND qual_ok AND value IS NOT NULL AND NOT isnan(value);
CREATE TEMP TABLE c AS SELECT * FROM read_parquet('/Users/bbest/_big/calcofi/releases/v2026.09.10/parquet/climatology/**/*.parquet', hive_partitioning=true)
 WHERE measurement_type IN ('temperature','oxygen_umol_kg','nitrate','chlorophyll_a','salinity','phosphate','silicate','synechococcus');
CREATE TEMP TABLE bands AS SELECT * FROM (VALUES ('temperature',0,50),('salinity',0,50),('chlorophyll_a',0,50),('oxygen_umol_kg',200,300),('nitrate',200,300),('phosphate',200,300),('silicate',200,300),('synechococcus',0,50)) t(mt, d0, d1);
CREATE TEMP TABLE a AS
 SELECT o.measurement_type, o.year, o.cruise_key, o.value - c.clim_mean AS anom
 FROM o JOIN bands b ON o.measurement_type = b.mt AND o.depth_min_m >= b.d0 AND o.depth_min_m < b.d1
 JOIN c USING (dataset_key, measurement_type, site_key, month, depth_bin);
-- per cruise mean first, then per year mean of cruise means
CREATE TEMP TABLE yr AS
 SELECT measurement_type, year, round(avg(cm), 3) AS anom, count(*) AS n_cruises, sum(n) AS n_values FROM (
   SELECT measurement_type, year, cruise_key, avg(anom) cm, count(*) n FROM a GROUP BY ALL) GROUP BY ALL;
COPY (SELECT * FROM yr ORDER BY measurement_type, year) TO 'anom.csv' (HEADER);
SELECT measurement_type, arg_max(year, anom) warmest, arg_min(year, anom) coolest FROM yr WHERE n_cruises >= 2 GROUP BY ALL;
