# CalCOFI integrated database release v2026.04.06

**Release date:** 2026-04-06
*Documented with v2026.04.02 – v2026.04.08 (2026-04-02 … 2026-04-08).*

Invertebrates folded into ichthyo; spatial tables consolidated and uploaded to GCS; pipeline
optimised with VIEWs and GCS server-side copy (60+ min → ~4 min); `inverts` → `invert`,
`dic_measurement_summary` → `dic_summary`.

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
| `ctd_cast` | 6,065,096 |  |
| `ctd_measurement` | 236,782,294 | partitioned |
| `ctd_summary` | 104,828,768 | partitioned |
| `dataset` | 5 |  |
| `dic_measurement` | 16,391 |  |
| `dic_sample` | 4,391 |  |
| `dic_summary` | 15,786 |  |
| `grid` | 218 |  |
| `ichthyo` | 830,873 |  |
| `invert` | 23,830 |  |
| `invert_net` | 7,463 |  |
| `lookup` | 26 |  |
| `measurement_type` | 104 |  |
| `net` | 76,512 |  |
| `segment` | 60,413 |  |
| `ship` | 48 |  |
| `site` | 61,104 |  |
| `species` | 1,144 |  |
| `taxa_rank` | 41 |  |
| `taxon` | 3,348 |  |
| `tow` | 75,506 |  |

**29 tables, 361,200,542 rows, 0.00 GB.**

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.04.06")
```
```python
con = calcofi4py.cc_get_db("v2026.04.06")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.04.06/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
