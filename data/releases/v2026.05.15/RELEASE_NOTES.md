# CalCOFI integrated database release v2026.05.15

**Release date:** 2026-05-14
*Documented with v2026.05.14 – v2026.05.20 (2026-05-14 … 2026-05-20).*

`ctd_thin` introduced as the headline CTD series (one direction, canonical types, 10 m grid +
inflections + bottle depths); schema browser site and the `test_release` → promote pipeline with
`test_results.json`; ERD and `metadata.json` sidecars from v2026.05.19.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `_spatial` | 3,373 |  |
| `_spatial_attr` | 40,298 |  |
| `bottle` | 895,371 |  |
| `bottle_measurement` | 11,135,600 |  |
| `cast_condition` | 235,513 |  |
| `casts` | 35,644 |  |
| `cruise` | 691 |  |
| `cruise_summary` | 691 |  |
| `ctd_cast` | 5,550,014 |  |
| `ctd_summary` | 108,396,787 | partitioned |
| `ctd_thin` | 5,551,571 | partitioned |
| `dataset` | 5 |  |
| `dic_measurement` | 16,391 |  |
| `dic_sample` | 4,391 |  |
| `dic_summary` | 15,786 |  |
| `grid` | 218 |  |
| `ichthyo` | 841,417 |  |
| `invert` | 11,815 |  |
| `lookup` | 26 |  |
| `measurement_type` | 104 |  |
| `net` | 76,512 |  |
| `segment` | 60,413 |  |
| `ship` | 48 |  |
| `site` | 61,104 |  |
| `species` | 1,150 |  |
| `taxa_rank` | 41 |  |
| `taxon` | 3,359 |  |
| `tow` | 75,506 |  |

**28 tables, 133,013,839 rows, 0.00 GB.**

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.05.15")
```
```python
con = calcofi4py.cc_get_db("v2026.05.15")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.05.15/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
