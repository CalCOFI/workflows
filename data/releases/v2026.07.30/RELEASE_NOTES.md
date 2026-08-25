# CalCOFI integrated database release v2026.07.30

**Release date:** 2026-07-30

## Four new datasets, the CTD QA/QC engine, and generic publishing

- **Datasets 12 → 15:** CCE-LTER euphausiids, CCE-LTER picoplankton/bacteria, SIO mesopelagic
  fish, and the METS underway series (`obs_mets_full`, 19.9 M rows). CDFW Dungeness crab is
  ingested but held out of the release behind a new `in_release: false` flag pending permission.
- **CTD QA/QC engine:** a declarative rule registry (`metadata/qc_rules/`), climatology-anomaly,
  seafloor-bathymetry and full-resolution profile rules, a Findings report with an input-fingerprint
  fast path, and a generated QA/QC protocol document.
- **Publishing:** one dataset-agnostic `publish_to-netcdf` + `publish_to-erddap` for every
  dataset; whole-dataset CF NetCDF to `calcofi-files-public`; `storage.calcofi.io` browsing.
- **Registries:** the hydro-master Access database reconciled against the release; a
  write-round-trip bug that let nine ingests corrupt `measurement_type.csv` with literal `"NA"`
  fixed; `-99` sentinels stripped from CTD; `data_stage` on `sample`; one question registry
  convention (`questions.csv`, `read_questions()`).

**Packages:** calcofi4db 2.11.0 → 3.4.0; calcofi4r 1.4.0–1.4.3 (non-blocking usage analytics).

## Contents (generated)

| table | rows | |
|---|---:|---|
| `_spatial` | 3,373 |  |
| `_spatial_attr` | 40,298 |  |
| `cruise` | 691 |  |
| `dataset` | 15 |  |
| `dataset_taxon` | 1,908 |  |
| `grid` | 218 |  |
| `lookup` | 26 |  |
| `measurement_type` | 198 |  |
| `obs` | 18,718,710 | partitioned |
| `obs_attribute` | 452,682 |  |
| `region` | 4 |  |
| `sample` | 1,477,204 |  |
| `sample_measurement` | 588,986 |  |
| `ship` | 49 |  |
| `taxon_group` | 155 |  |
| `obs_ctd_full` | 212,444,287 | supplemental |

**16 tables, 233,728,804 rows, 1.79 GB.**

**Datasets (15):** `calcofi_bird_mammal_census`, `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `pic_zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`, `ucsd_sio_mesopelagic-fish`

**Validation:** 19 pass / 0 fail / 4 skip (consumer-contract suite, 2026-07-30T04:38:51Z).

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.07.30")
```
```python
con = calcofi4py.cc_get_db("v2026.07.30")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.07.30/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
