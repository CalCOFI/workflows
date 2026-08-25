# CalCOFI integrated database release v2026.08.07

**Release date:** 2026-08-07

## The Wilkinson CTD archive and three data stages

JRW's Shared-Drive `_CTDFinalDB` archives are ingested alongside calcofi.org's, adding 45 gap
cruises; `data_stage` splits into `final`, `preliminary_with_bottle` and
`preliminary_without_bottle` (the sensor-only tier reaches the release with no salinity or oxygen
corrections). `obs_ctd_full` 212.4 M → 274.9 M rows; `obs` +6.2 M.

## Taxon authorities are cross-referenced and lineages completed

Birds key `itis:` because WoRMS bird taxonomy lags, but nothing populated `worms_id` for them, so
a consumer joining on `worms_id` matched zero rows for every seabird and marine mammal (92 % of the
Farallon census). `ensure_taxon_xref()` crosswalks TSN ↔ AphiaID by exact id; `taxonomic_status`
is fetched with `status_checked` instead of stamped "accepted"; ancestors are first-class taxa with
rank order from one vocabulary. Four new release gates cover it.

## Coverage is measured, never asserted

`coverage_temporal`/`coverage_spatial` were hand-written in each ingest and seven of fifteen were
wrong at v2026.08.06; `observed_coverage()` now measures both from the assembled core and the
measurement surfaces coordinate bugs the prose hid. Bulk parquet moved outside the repo to
`$CALCOFI_STAGE_DIR`; the JSON sidecars stay tracked in git.

**Packages:** calcofi4db 3.5.0–3.9.3; calcofi4r 1.5.0–1.5.4 (shared transect/climatology/anomaly
functions, summer-anomaly vignette).

## Contents (generated)

| table | rows | |
|---|---:|---|
| `cruise` | 691 |  |
| `dataset` | 15 |  |
| `dataset_taxon` | 1,907 |  |
| `grid` | 218 |  |
| `lookup` | 26 |  |
| `measurement_type` | 198 |  |
| `obs` | 26,266,514 | partitioned |
| `obs_attribute` | 452,682 |  |
| `region` | 4 |  |
| `sample` | 1,465,189 |  |
| `sample_measurement` | 588,986 |  |
| `ship` | 49 |  |
| `spatial` | 13,206 |  |
| `spatial_attribute` | 148,461 |  |
| `taxon` | 2,121 |  |
| `taxon_group` | 154 |  |
| `obs_ctd_full` | 274,857,168 | supplemental |
| `obs_mets_full` | 19,936,073 | supplemental |

**18 tables, 323,733,662 rows, 2.12 GB.**

**Datasets (15):** `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 28 pass / 0 fail / 4 skip (consumer-contract suite, 2026-08-07T13:41:56Z).

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.08.07")
```
```python
con = calcofi4py.cc_get_db("v2026.08.07")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.08.07/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
