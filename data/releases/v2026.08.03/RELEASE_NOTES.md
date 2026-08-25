# CalCOFI integrated database release v2026.08.03

**Release date:** 2026-08-03

## All released geometry is tagged EPSG:4326

`ST_Point()` tags `OGC:CRS84` while `ST_Read()` over GeoJSON tags `EPSG:4326`; DuckDB refuses
`ST_Intersects` across the two, so a `sample` → `spatial` join errored outright. Geometry is
normalised immediately before the freeze — and exported locally, because most tables are uploaded
by GCS server-side copy and never pass through the connection (the check passed while the published
`grid.parquet` stayed `OGC:CRS84`). `_spatial`/`_spatial_attr` become `spatial`/`spatial_attribute`
with a real `spatial_key`. Five spatial gates added (23 → 28). Partitioned uploads use `rsync`, so a
retry resumes; full-scan parquet is clustered by cast. Rows unchanged; 2.19 → 2.16 GB.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `cruise` | 691 |  |
| `dataset` | 15 |  |
| `dataset_taxon` | 1,908 |  |
| `grid` | 218 |  |
| `lookup` | 26 |  |
| `measurement_type` | 198 |  |
| `obs` | 20,088,748 | partitioned |
| `obs_attribute` | 452,682 |  |
| `region` | 4 |  |
| `sample` | 1,477,206 |  |
| `sample_measurement` | 588,986 |  |
| `ship` | 49 |  |
| `spatial` | 3,373 |  |
| `spatial_attribute` | 40,298 |  |
| `taxon` | 2,118 |  |
| `taxon_group` | 155 |  |
| `obs_ctd_full` | 212,444,287 | supplemental |
| `obs_mets_full` | 19,936,073 | supplemental |

**18 tables, 255,037,035 rows, 2.16 GB.**

**Datasets (15):** `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 24 pass / 0 fail / 4 skip (consumer-contract suite, 2026-08-03T17:32:00Z).

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.08.03")
```
```python
con = calcofi4py.cc_get_db("v2026.08.03")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.08.03/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
