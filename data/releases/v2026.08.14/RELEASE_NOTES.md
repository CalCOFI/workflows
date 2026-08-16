# CalCOFI Database Release v2026.08.14

**Release Date**: 2026-08-14

## Tables Included

- measurement_type (        200 rows)
- dataset (         16 rows)
- region (          4 rows)
- spatial_attribute (    148,461 rows)
- spatial (     13,206 rows)
- grid (        218 rows)
- cruise (        691 rows)
- ship (         49 rows)
- lookup (         26 rows)
- sample (  1,466,254 rows)
- obs ( 25,624,046 rows)
- obs_attribute (    452,789 rows)
- sample_measurement (    589,603 rows)
- taxon (      2,125 rows)
- dataset_taxon (      1,910 rows)
- taxon_group (        151 rows)
- obs_ctd_full (259,309,891 rows)
- obs_mets_full ( 19,927,416 rows)

## Total

- **Tables**: 18
- **Total Rows**: 307,537,056

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
    'https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.08.14/parquet/ichthyo.parquet')
  LIMIT 10")
```

Or use calcofi4r:

```r
library(calcofi4r)
con <- cc_get_db(version = 'v2026.08.14')
```

