# CalCOFI integrated database release v2026.07.17

**Release date:** 2026-07-17

Serving-layer release, no row change: thinned CTD served as CF Profile NetCDF on ERDDAP, profiles
keyed by station occupation (`ord_occ`) rather than per scan; `tow_type` (net gear) promoted onto
the core `sample` table (calcofi4db 2.10.0); the station portal refresh repointed to
`CalCOFI/db-viz-station`.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `_spatial` | 3,373 |  |
| `_spatial_attr` | 40,298 |  |
| `cruise` | 691 |  |
| `dataset` | 13 |  |
| `dataset_taxon` | 1,781 |  |
| `grid` | 218 |  |
| `lookup` | 26 |  |
| `measurement_type` | 120 |  |
| `obs` | 17,705,061 | partitioned |
| `obs_attribute` | 452,682 |  |
| `region` | 4 |  |
| `sample` | 1,385,959 |  |
| `sample_measurement` | 555,623 |  |
| `ship` | 49 |  |
| `taxon` | 3,580 |  |
| `taxon_group` | 155 |  |
| `obs_ctd_full` | 216,427,608 | supplemental |

**17 tables, 236,577,241 rows, 2.04 GB.**

**Datasets (12):** `calcofi_bird_mammal_census`, `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_dic`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_zoodb`, `cce-lter_zooscan`, `pic_zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 19 pass / 0 fail / 4 skip (consumer-contract suite, 2026-07-17T10:57:18Z).

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.07.17")
```
```python
con = calcofi4py.cc_get_db("v2026.07.17")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.07.17/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
