# CalCOFI integrated database release v2026.07.15

**Release date:** 2026-07-15

## The consolidated core model

The ~40 per-dataset triples (`{dataset}_sample` / `_measurement` / `_summary`) collapse into
`sample` (one row per sampling event, adjacency list via `parent_sample_key`), `obs` (one scalar
per row, `realm` env|bio), `sample_measurement` (event-level effort) and the supplemental
`obs_ctd_full` (full-resolution CTD scans, ~216 M rows, opt-in). Per-dataset tables survive as
compat views. Namespaced `sample_key` = `dataset_key:sample_type:id`; `hex_id` (H3 res 10) on
`obs`. `obs_ctd_full` complete for the first time.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `_spatial` | 3,373 |  |
| `_spatial_attr` | 40,298 |  |
| `bird_mammal_behavior` | 4 |  |
| `bird_mammal_species` | 200 |  |
| `cruise` | 691 |  |
| `dataset` | 7 |  |
| `grid` | 218 |  |
| `lookup` | 26 |  |
| `measurement_type` | 106 |  |
| `obs` | 17,582,015 | partitioned |
| `obs_ctd_full` | 216,427,608 | partitioned |
| `obs_freq` | 369,978 |  |
| `phyto_taxon` | 399 |  |
| `region` | 4 |  |
| `sample` | 1,385,959 |  |
| `sample_measurement` | 555,623 |  |
| `ship` | 48 |  |
| `species` | 1,167 |  |
| `taxa_rank` | 41 |  |
| `taxon` | 3,385 |  |
| `zoodb_taxon` | 33 |  |
| `zooscan_taxon` | 23 |  |

**22 tables, 236,371,206 rows, 5.74 GB.**

**Datasets (12):** `calcofi_bird_mammal_census`, `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_dic`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_zoodb`, `cce-lter_zooscan`, `pic_zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.07.15")
```
```python
con = calcofi4py.cc_get_db("v2026.07.15")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.07.15/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
