# CalCOFI integrated database release v2026.06.07

**Release date:** 2026-06-07
*Documented with v2026.06.07 – v2026.06.08 (2026-06-07 … 2026-06-08).*

Phytoplankton (Venrick, region-pooled) added; 44 tables; full ingest + release re-run with
refreshed outputs, DB and PMTiles.

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
| `ctd_summary` | 108,390,249 | partitioned |
| `ctd_thin` | 5,551,551 | partitioned |
| `dataset` | 5 |  |
| `dic_measurement` | 16,391 |  |
| `dic_sample` | 4,391 |  |
| `dic_summary` | 15,786 |  |
| `grid` | 218 |  |
| `ichthyo` | 852,228 |  |
| `invert` | 9,223 |  |
| `lookup` | 26 |  |
| `measurement_type` | 105 |  |
| `net` | 76,512 |  |
| `segment` | 60,413 |  |
| `ship` | 48 |  |
| `site` | 61,104 |  |
| `species` | 1,167 |  |
| `taxa_rank` | 41 |  |
| `taxon` | 3,385 |  |
| `tow` | 75,506 |  |

**28 tables, 133,015,544 rows, 3.72 GB.**

**Datasets (4):** `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_dic`, `swfsc_ichthyo`

**Validation:** 9 pass / 0 fail / 4 skip (consumer-contract suite, 2026-06-07T09:20:08Z).

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.06.07")
```
```python
con = calcofi4py.cc_get_db("v2026.06.07")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.06.07/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
