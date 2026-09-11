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

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.07.15 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://calcofi.io/db-schema/?v=v2026.07.15

Cite the source datasets you use alongside the release:

- `calcofi_bird_mammal_census` — *citation pending* · *license pending*
- `calcofi_bottle` — CalCOFI. (2023). CalCOFI Bottle Database 194903-202105. CalCOFI.org. · *license pending*
- `calcofi_ctd-cast` — CalCOFI. (2023). CalCOFI CTD Cast Files. CalCOFI.org. · *license pending*
- `calcofi_dic` — Keeling, C.D.; Lueker, T.J.; Emanuele, G.; Dickson, A.G.; Martz, T.R.; Wolfe, W.H.; Mau, A. (2025). Discrete profile dissolved inorganic carbon, total alkalinity, water temperature and salinity measurements for CalCOFI (NCEI Accession 0301029). NOAA NCEI. https://doi.org/10.25921/3w9f-jd72 · CC BY 4.0
- `calcofi_phyllosoma` — *citation pending* · *license pending*
- `calcofi_phytoplankton` — *citation pending* · *license pending*
- `cce-lter_euphausiids` — *citation pending* · *license pending*
- `cce-lter_zoodb` — *citation pending* · *license pending*
- `cce-lter_zooscan` — *citation pending* · *license pending*
- `pic_zooplankton` — *citation pending* · *license pending*
- `swfsc_cufes` — *citation pending* · *license pending*
- `swfsc_ichthyo` — NOAA Fisheries SWFSC. CalCOFI Ichthyoplankton Database. · *license pending*

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.07.15")
```
```python
con = calcofi4py.cc_get_db("v2026.07.15")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.07.15/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
