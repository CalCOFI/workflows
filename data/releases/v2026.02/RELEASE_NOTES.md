# CalCOFI Database Release v2026.02

**Release Date**: 2026-02-05

## Tables Included

- bottle (   895,371 rows)
- bottle_measurement (11,135,600 rows)
- cast_condition (   235,513 rows)
- casts (    35,644 rows)
- cruise (       691 rows)
- grid (       218 rows)
- ichthyo (   830,873 rows)
- lookup (        26 rows)
- measurement_type (        47 rows)
- net (    76,512 rows)
- segment (    60,413 rows)
- ship (        48 rows)
- site (    61,104 rows)
- species (     1,144 rows)
- taxa_rank (        41 rows)
- taxon (     1,671 rows)
- tow (    75,506 rows)

## Total

- **Tables**: 17
- **Total Rows**: 13,410,422
- **Total Size**: 80.9 MB

## Data Sources

- `ingest_swfsc.noaa.gov_calcofi-db.qmd` - Ichthyo tables (cruise, ship, site, tow, net, species, ichthyo, grid, segment, lookup)
- `ingest_calcofi.org_bottle-database.qmd` - Bottle/cast tables (casts, bottle, bottle_measurement, cast_condition, measurement_type)

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
    'https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.02/parquet/ichthyo.parquet')
  LIMIT 10")
```

Or use calcofi4r:

```r
library(calcofi4r)
con <- cc_get_db(version = 'v2026.02')
```

