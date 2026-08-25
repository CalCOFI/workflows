# CalCOFI integrated database release v2026.03.14

**Release date:** 2026-03-14
*Documented with v2026.03 – v2026.03.26 (2026-03 … 2026-03-26).*

First releases on the versioned GCS layout (`ducklake/releases/{version}/`), `relationships.json`
sidecar from v2026.03.14; bottle, CTD, DIC and ichthyo as per-dataset tables.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `bottle` | 895,371 |  |
| `bottle_measurement` | 11,135,600 |  |
| `cast_condition` | 235,513 |  |
| `casts` | 35,644 |  |
| `cruise` | 691 |  |
| `ctd_cast` | 6,001,231 |  |
| `ctd_measurement` | 234,105,572 | partitioned |
| `ctd_summary` | 103,482,233 | partitioned |
| `grid` | 218 |  |
| `ichthyo` | 830,873 |  |
| `lookup` | 26 |  |
| `measurement_type` | 100 |  |
| `net` | 76,512 |  |
| `segment` | 60,413 |  |
| `ship` | 48 |  |
| `site` | 61,104 |  |
| `species` | 1,144 |  |
| `taxa_rank` | 41 |  |
| `taxon` | 3,348 |  |
| `tow` | 75,506 |  |

**20 tables, 357,001,188 rows, 11.88 GB.**

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.03.14")
```
```python
con = calcofi4py.cc_get_db("v2026.03.14")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.03.14/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
