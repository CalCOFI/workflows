# CalCOFI Database Release v2026.03.14

**Release Date**: 2026-03-14

## Tables Included

- bottle (    895,371 rows)
- bottle_measurement ( 11,135,600 rows)
- cast_condition (    235,513 rows)
- casts (     35,644 rows)
- cruise (        691 rows)
- ctd_cast (  6,001,231 rows)
- ctd_measurement (234,105,572 rows)
- ctd_summary (103,482,233 rows)
- grid (        218 rows)
- ichthyo (    830,873 rows)
- lookup (         26 rows)
- measurement_type (        100 rows)
- net (     76,512 rows)
- segment (     60,413 rows)
- ship (         48 rows)
- site (     61,104 rows)
- species (      1,144 rows)
- taxa_rank (         41 rows)
- taxon (      3,348 rows)
- tow (     75,506 rows)

## Total

- **Tables**: 20
- **Total Rows**: 357,001,188
- **Total Size**: 11330.4 MB

## Data Sources

- `ingest_swfsc_ichthyo.qmd` - Ichthyo tables (cruise, ship, site, tow, net, species, ichthyo, grid, segment, lookup, taxon, taxa_rank)
- `ingest_calcofi_bottle.qmd` - Bottle/cast tables (casts, bottle, bottle_measurement, cast_condition, measurement_type)
- `ingest_calcofi_ctd-cast.qmd` - CTD tables (ctd_cast, ctd_measurement, ctd_summary, measurement_type)

## Cross-Dataset Integration

- **Ship matching**: Reconciled ship codes between bottle casts and swfsc ship reference
- **Cruise bridge**: Derived cruise_key (YYMMKK) for bottle casts via ship_key + datetime
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
    'https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.03.14/parquet/ichthyo.parquet')
  LIMIT 10")
```

Or use calcofi4r:

```r
library(calcofi4r)
con <- cc_get_db(version = 'v2026.03.14')
```

