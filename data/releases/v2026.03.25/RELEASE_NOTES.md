# CalCOFI integrated database release v2026.03.25

**Release date:** 2026-03-25
*Documented with v2026.03 – v2026.03.26 (2026-03 … 2026-03-26).*

First releases on the versioned GCS layout (`ducklake/releases/{version}/`), `relationships.json`
sidecar from v2026.03.14; bottle, CTD, DIC and ichthyo as per-dataset tables.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `bottle` | 895,371 |  |
| `bottle_measurement` | 11,135,600 |  |
| `cast_condition` | 235,513 |  |
| `cruise` | 691 |  |
| `ctd_measurement` | 236,782,294 | partitioned |
| `ctd_summary` | 104,828,768 | partitioned |
| `dataset` | 4 |  |
| `dic_measurement` | 16,391 |  |
| `dic_measurement_summary` | 15,786 |  |
| `ichthyo` | 830,873 |  |
| `lookup` | 26 |  |
| `measurement_type` | 104 |  |
| `net` | 76,512 |  |
| `ship` | 48 |  |
| `species` | 1,144 |  |
| `taxa_rank` | 41 |  |
| `taxon` | 3,348 |  |
| `tow` | 75,506 |  |

**18 tables, 354,898,020 rows, 11.81 GB.**

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.03.25")
```
```python
con = calcofi4py.cc_get_db("v2026.03.25")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.03.25/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
