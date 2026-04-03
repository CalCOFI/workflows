# CalCOFI Database Release v2026.04.03

**Release Date**: 2026-04-03

## Tables Included

- casts (     35,644 rows)
- bottle (    895,371 rows)
- bottle_measurement ( 11,135,600 rows)
- cast_condition (    235,513 rows)
- measurement_type (        104 rows)
- dataset (          5 rows)
- ctd_cast (  6,065,096 rows)
- ctd_measurement (236,782,294 rows)
- ctd_summary (104,828,768 rows)
- dic_sample (      4,391 rows)
- dic_measurement (     16,391 rows)
- dic_measurement_summary (     15,786 rows)
- _spatial_attr (     40,298 rows)
- _spatial (      3,373 rows)
- cruise (        691 rows)
- grid (        218 rows)
- ichthyo (    830,873 rows)
- lookup (         26 rows)
- net (     76,512 rows)
- segment (     60,413 rows)
- ship (         48 rows)
- site (     61,104 rows)
- species (      1,144 rows)
- taxa_rank (         41 rows)
- taxon (      3,348 rows)
- tow (     75,506 rows)
- invert_count (      9,628 rows)
- invert_size (      4,574 rows)
- cruise_summary (        691 rows)

## Total

- **Tables**: 29
- **Total Rows**: 361,183,451

## Data Sources

- `ingest_swfsc_ichthyo.qmd` - Ichthyo tables (cruise, ship, site, tow, net, species, ichthyo, grid, segment, lookup, taxon, taxa_rank)
- `ingest_calcofi_bottle.qmd` - Bottle/cast tables (casts, bottle, bottle_measurement, cast_condition, measurement_type)
- `ingest_calcofi_ctd-cast.qmd` - CTD tables (ctd_cast, ctd_measurement, ctd_summary, measurement_type)
- `ingest_calcofi_dic.qmd` - DIC/alkalinity tables (dic_sample, dic_measurement, dic_measurement_summary, dataset)

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
    'https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.04.03/parquet/ichthyo.parquet')
  LIMIT 10")
```

Or use calcofi4r:

```r
library(calcofi4r)
con <- cc_get_db(version = 'v2026.04.03')
```

