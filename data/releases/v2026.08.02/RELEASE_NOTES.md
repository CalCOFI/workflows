# CalCOFI integrated database release v2026.08.02

**Release date:** 2026-08-02

## A full rebuild on the core-only model

Every dataset's core projection SQL moved out of calcofi4db into the ingest notebook that owns it
(calcofi4db 3.2.0 deleted the `switch(dataset_key, …)` arms — the release had re-derived the core
from its own inline copy and the two copies drifted, each divergence a silent data error).
`obs_mets_full` and `taxon` are catalogued; spatial tables renamed. `obs` 18.7 M → 20.1 M.

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

**18 tables, 255,037,035 rows, 2.19 GB.**

**Datasets (15):** `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 19 pass / 0 fail / 4 skip (consumer-contract suite, 2026-08-02T16:51:59Z).

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.08.02")
```
```python
con = calcofi4py.cc_get_db("v2026.08.02")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.08.02/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
