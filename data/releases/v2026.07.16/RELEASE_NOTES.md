# CalCOFI Database Release v2026.07.16

**Release Date**: 2026-07-16

## Tables Included

- dataset (         13 rows)
- measurement_type (        120 rows)
- region (          4 rows)
- _spatial_attr (     40,298 rows)
- _spatial (      3,373 rows)
- cruise (        691 rows)
- grid (        218 rows)
- lookup (         26 rows)
- ship (         49 rows)
- taxon (      3,580 rows)
- sample (  1,385,959 rows)
- obs ( 17,705,061 rows)
- obs_attribute (    452,682 rows)
- sample_measurement (    555,623 rows)
- obs_ctd_full (216,427,608 rows)
- dataset_taxon (      1,781 rows)
- taxon_group (        155 rows)

## Total

- **Tables**: 17
- **Total Rows**: 236,577,241

## Data Sources

- `ingest_swfsc_ichthyo.qmd` - Ichthyo tables (cruise, ship, site, tow, net, species, ichthyo, grid, segment, lookup, taxon, taxa_rank)
- `ingest_calcofi_bottle.qmd` - Bottle/cast tables (casts, bottle, bottle_measurement, cast_condition, measurement_type)
- `ingest_calcofi_ctd-cast.qmd` - CTD tables (ctd_cast, ctd_thin, ctd_summary, measurement_type; full ctd_measurement available as supplemental)
- `ingest_calcofi_dic.qmd` - DIC/alkalinity tables (dic_sample, dic_measurement, dic_summary, dataset)

## Cross-Dataset Integration

- **Ship matching**: Reconciled ship codes between bottle casts and swfsc ship reference
- **Cruise bridge**: Derived cruise_key (YYYY-MM-NODC) for bottle casts via ship matching + datetime
- **Taxonomy**: Standardized species with WoRMS AphiaID, ITIS TSN, GBIF backbone key
- **Taxon hierarchy**: Built taxon + taxa_rank tables from WoRMS/ITIS classification

## Access

Parquet files can be queried directly from GCS:

```r
library(duckdb)
con <- dbConnect(duckdb())
dbExecute(con, 'INSTALL httpfs; LOAD httpfs;')
dbGetQuery(con, "
  SELECT * FROM read_parquet(
    'https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.07.16/parquet/ichthyo.parquet')
  LIMIT 10")
```

Or use calcofi4r:

```r
library(calcofi4r)
con <- cc_get_db(version = 'v2026.07.16')
```

