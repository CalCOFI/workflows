# release / I1_r1

Final answer: 14.364

**Bash**: Read README and list files
```bash
cat README.md; ls
```

**Bash**: List and describe tables
```bash
duckdb -readonly release.duckdb -c "show tables" ; for t in $(duckdb -readonly release.duckdb -csv -noheader -c "show tables"); do echo "== $t"; duckdb -readonly release.duckdb -c "describe $t"; done 2>&1 | head -400
```

**Bash**: Describe key tables in CSV
```bash
for t in obs_env obs_bio obs sample ichthyo_net cruise dataset measurement_type lookup sample_root taxon obs_attribute; do echo "== $t"; duckdb -readonly -csv release.duckdb -c "select column_name, column_type from (describe $t)"; done
```

**Bash**: Explore datasets, sardine taxon, temperature types, quality codes
```bash
cd /Users/bbest/_big/bench_ai_runs/2026-10-30_opus-5-5_high/release/I1_r1
duckdb -readonly release.duckdb -c "select dataset_key, dataset_name_short, tables from dataset" -c "select taxon_key, scientific_name, common_name from taxon where scientific_name ilike 'Sardinops%'" -c "select dataset_key, measurement_type, tow_type, life_stage, count(*) from obs_bio where taxon_key in (select taxon_key from taxon where scientific_name ilike 'Sardinops%') group by all order by all" -c "select measurement_type, description, units, provider, dataset from measurement_type where measurement_type ilike '%temp%'" -c "select * from lookup where lookup_type ilike '%qual%' or description ilike '%suspect%' limit 50"
```

**Bash**: Inspect bottle temperature and sardine larva records
```bash
cd /Users/bbest/_big/bench_ai_runs/2026-10-30_opus-5-5_high/release/I1_r1
duckdb -readonly release.duckdb -c "select measurement_qual, qual_ok, count(*) from obs_env where dataset_key='calcofi_bottle' and measurement_type='temperature' group by all order by all" -c "select * from obs_env where dataset_key='calcofi_bottle' and measurement_type='temperature' and year=2005 limit 3" -c "select * from obs_bio where dataset_key='swfsc_ichthyo' and tow_type='CB' and taxon_key='worms:217452' and life_stage='larva' and year=2005 limit 3" -c "select distinct lookup_type from lookup"
```

**Bash**: Compute matched occupations and mean 10 m temperature
```bash
cd /Users/bbest/_big/bench_ai_runs/2026-10-30_opus-5-5_high/release/I1_r1
duckdb -readonly release.duckdb -c "
create temp table occ as select distinct cruise_key, site_key from obs_bio where dataset_key='swfsc_ichthyo' and tow_type='CB' and taxon_key='worms:217452' and life_stage='larva' and value>0 and year between 2000 and 2009;
select count(*) from occ;
create temp table t10 as select cruise_key, site_key, value, measurement_qual, depth_min_m, sample_key from obs_env where dataset_key='calcofi_bottle' and measurement_type='temperature' and depth_min_m=10;
select count(*) n_occ_matched, sum(n) nrows, sum(case when n>1 then 1 else 0 end) multi from (select o.cruise_key,o.site_key,count(*) n from occ o join t10 t using(cruise_key,site_key) group by all);
select measurement_qual, count(*) from occ o join t10 t using(cruise_key,site_key) group by all;
select count(*) n, avg(v), avg(nr) from (select cruise_key, site_key, avg(value) v, count(*) nr from occ o join t10 t using(cruise_key,site_key) where coalesce(measurement_qual,'') not in ('8','9') and value is not null group by all);
"
```

**Bash**: Diagnose unmatched occupations
```bash
cd /Users/bbest/_big/bench_ai_runs/2026-10-30_opus-5-5_high/release/I1_r1
duckdb -readonly release.duckdb -c "
create temp table occ as select distinct cruise_key, site_key from obs_bio where dataset_key='swfsc_ichthyo' and tow_type='CB' and taxon_key='worms:217452' and life_stage='larva' and value>0 and year between 2000 and 2009;
create temp table b as select distinct cruise_key, site_key from obs_env where dataset_key='calcofi_bottle' and measurement_type='temperature';
select count(*) filter (where b.site_key is not null) with_any_bottle from occ left join b using(cruise_key,site_key);
select o.cruise_key, count(*) from occ o left join b using(cruise_key,site_key) where b.site_key is null group by all order by 1 limit 40;
select o.cruise_key,o.site_key, list(t.depth_min_m order by t.depth_min_m)[1:8] from occ o join b using(cruise_key,site_key) join obs_env t on t.dataset_key='calcofi_bottle' and t.measurement_type='temperature' and t.cruise_key=o.cruise_key and t.site_key=o.site_key group by all having count(*) filter (where t.depth_min_m=10)=0 limit 10;
"
```

**Bash**: Check unmatched occupation station IDs
```bash
cd /Users/bbest/_big/bench_ai_runs/2026-10-30_opus-5-5_high/release/I1_r1
duckdb -readonly release.duckdb -c "
create temp table occ as select distinct cruise_key, site_key from obs_bio where dataset_key='swfsc_ichthyo' and tow_type='CB' and taxon_key='worms:217452' and life_stage='larva' and value>0 and year between 2000 and 2009;
create temp table b as select distinct cruise_key, site_key from obs_env where dataset_key='calcofi_bottle' and measurement_type='temperature';
select o.cruise_key, list(o.site_key)[1:6] unmatched, (select count(distinct site_key) from b where b.cruise_key=o.cruise_key) n_btl_sites from occ o where not exists (select 1 from b where b.cruise_key=o.cruise_key and b.site_key=o.site_key) group by all order by 1;
"
```

