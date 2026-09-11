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

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.08.07 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://calcofi.io/db-schema/?v=v2026.08.07

Cite the source datasets you use alongside the release:

- `calcofi_bottle` — CalCOFI. (2023). CalCOFI Bottle Database 194903-202105. CalCOFI.org. · *license pending*
- `calcofi_ctd-cast` — CalCOFI. (2023). CalCOFI CTD Cast Files. CalCOFI.org. · *license pending*
- `calcofi_dic` — Keeling, C.D.; Lueker, T.J.; Emanuele, G.; Dickson, A.G.; Martz, T.R.; Wolfe, W.H.; Mau, A. (2025). Discrete profile dissolved inorganic carbon, total alkalinity, water temperature and salinity measurements for CalCOFI (NCEI Accession 0301029). NOAA NCEI. https://doi.org/10.25921/3w9f-jd72 · CC BY 4.0
- `calcofi_mets` — CalCOFI. Underway (METS) TSG/Meteorology Data. CalCOFI.org. · *license pending*
- `calcofi_phyllosoma` — *citation pending* · *license pending*
- `calcofi_phytoplankton` — *citation pending* · *license pending*
- `cce-lter_euphausiids` — *citation pending* · *license pending*
- `cce-lter_picoplankton-bacteria` — Landry, M. (2004-2023). Picoplankton and Bacteria Abundance (CalCOFI Cruise). CCE LTER. · *license pending*
- `cce-lter_zoodb` — *citation pending* · *license pending*
- `cce-lter_zooscan` — *citation pending* · *license pending*
- `farallon_bird-mammal` — *citation pending* · *license pending*
- `sio_mesopelagic-fish` — Koslow, J. Anthony (2016). CalCOFI Trawl Data. In California Cooperative Oceanic Fisheries Investigations (CalCOFI): Acoustic and Trawl Data. UC San Diego Library Digital Collections. https://doi.org/10.6075/J0BZ64DH
 · CC BY 4.0
- `sio_pic-zooplankton` — *citation pending* · *license pending*
- `swfsc_cufes` — *citation pending* · *license pending*
- `swfsc_ichthyo` — NOAA Fisheries SWFSC. CalCOFI Ichthyoplankton Database. · *license pending*

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.08.07")
```
```python
con = calcofi4py.cc_get_db("v2026.08.07")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.08.07/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
