# CalCOFI integrated database release v2026.06.08

**Release date:** 2026-06-07
*Documented with v2026.06.07 – v2026.06.08 (2026-06-07 … 2026-06-08).*

Phytoplankton (Venrick, region-pooled) added; 44 tables; full ingest + release re-run with
refreshed outputs, DB and PMTiles.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `_spatial` | 3,373 |  |
| `_spatial_attr` | 40,298 |  |
| `bird_mammal_behavior` | 4 |  |
| `bird_mammal_observation` | 82,418 |  |
| `bird_mammal_species` | 200 |  |
| `bird_mammal_transect` | 60,715 |  |
| `bottle` | 895,371 |  |
| `bottle_measurement` | 11,135,600 |  |
| `cast_condition` | 235,513 |  |
| `casts` | 35,644 |  |
| `cruise` | 691 |  |
| `cruise_summary` | 691 |  |
| `ctd_cast` | 5,550,014 |  |
| `ctd_summary` | 108,390,249 | partitioned |
| `ctd_thin` | 5,551,551 | partitioned |
| `cufes_measurement` | 284,097 |  |
| `cufes_sample` | 49,572 |  |
| `dataset` | 7 |  |
| `dic_measurement` | 16,391 |  |
| `dic_sample` | 4,391 |  |
| `dic_summary` | 15,786 |  |
| `euphausiids_measurement` | 10,150 |  |
| `euphausiids_summary` | 10,145 |  |
| `euphausiids_tow` | 10,150 |  |
| `grid` | 218 |  |
| `ichthyo` | 852,228 |  |
| `invert` | 9,223 |  |
| `lookup` | 26 |  |
| `measurement_type` | 106 |  |
| `net` | 76,512 |  |
| `phyllosoma_measurement` | 22,308 |  |
| `phyllosoma_tow` | 1,859 |  |
| `phyto_measurement` | 159,804 |  |
| `phyto_sample` | 409 |  |
| `phyto_taxon` | 399 |  |
| `region` | 4 |  |
| `segment` | 60,413 |  |
| `ship` | 48 |  |
| `site` | 61,104 |  |
| `species` | 1,167 |  |
| `taxa_rank` | 41 |  |
| `taxon` | 3,385 |  |
| `tow` | 75,506 |  |
| `zooplankton_tow` | 99,530 |  |

**44 tables, 133,807,311 rows, 3.73 GB.**

**Datasets (10):** `calcofi_bird_mammal_census`, `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_dic`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `pic_zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.06.08")
```
```python
con = calcofi4py.cc_get_db("v2026.06.08")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.06.08/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
