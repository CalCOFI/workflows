# CalCOFI integrated database release v2026.02

**Release date:** 2026-02-05

First frozen release: 17 tables, 13.4 M rows, 81 MB — ichthyo merged with bottle.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `bottle` | 895,371 |  |
| `bottle_measurement` | 11,135,600 |  |
| `cast_condition` | 235,513 |  |
| `casts` | 35,644 |  |
| `cruise` | 691 |  |
| `grid` | 218 |  |
| `ichthyo` | 830,873 |  |
| `lookup` | 26 |  |
| `measurement_type` | 47 |  |
| `net` | 76,512 |  |
| `segment` | 60,413 |  |
| `ship` | 48 |  |
| `site` | 61,104 |  |
| `species` | 1,144 |  |
| `taxa_rank` | 41 |  |
| `taxon` | 1,671 |  |
| `tow` | 75,506 |  |

**17 tables, 13,410,422 rows, 0.08 GB.**

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.02")
```
```python
con = calcofi4py.cc_get_db("v2026.02")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.02/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
