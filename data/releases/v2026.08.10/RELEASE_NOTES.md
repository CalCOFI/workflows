# CalCOFI integrated database release v2026.08.10

**Release date:** 2026-08-11

## Ten CTD cruises are back

v2026.08.08 lost every observation of ten cruises while keeping their casts, and no FK check could
see it: the CTD ingest extracted archives into a Google Drive folder, Drive evicted files to
cloud-only placeholders mid-sync, and `read_csv()` returned a 0-row tibble with no error — while
the Drive-minted ` 2.csv` conflict copies broke the cast-direction parse. `check_cruise_coverage()`
(calcofi4db 3.12.0) now fails a release on a cruise that leaves `obs` but keeps its casts; 142
cruises restored (`obs_ctd_full` +13.7 M rows).

## METS longitudes have their sign

The unsigned `Longitude_W` was released as positive (125.8 °W read as 124.9 °E in the measured
coverage); it is negated, answering mets_20. The orphan-cruise ratchet tightened 5 → 1.

## The pipeline stops invalidating itself

`release_database` had declared the whole `data/releases` directory as its output, so
`test_release` writing `test_results.json` beside it made the release permanently outdated and
every later `tar_make()` re-froze and re-uploaded an already-promoted release. It now declares a
deterministic `_release_stamp.json`; `check_nested_outputs()` refuses any directory output.

**Packages:** calcofi4db 3.12.0, 3.13.0; calcofi4r 1.6.0 (seafloor sampled along the transect
track, not at stations).

## Contents (generated)

| table | rows | |
|---|---:|---|
| `cruise` | 691 |  |
| `dataset` | 15 |  |
| `dataset_taxon` | 1,907 |  |
| `grid` | 218 |  |
| `lookup` | 26 |  |
| `measurement_type` | 198 |  |
| `obs` | 26,453,863 | partitioned |
| `obs_attribute` | 452,765 |  |
| `region` | 4 |  |
| `sample` | 1,465,189 |  |
| `sample_measurement` | 588,986 |  |
| `ship` | 49 |  |
| `spatial` | 13,206 |  |
| `spatial_attribute` | 148,461 |  |
| `taxon` | 2,121 |  |
| `taxon_group` | 154 |  |
| `obs_ctd_full` | 274,857,042 | supplemental |
| `obs_mets_full` | 19,927,469 | supplemental |

**18 tables, 323,912,364 rows, 2.11 GB.**

**Datasets (15):** `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 27 pass / 1 fail / 4 skip (consumer-contract suite, 2026-08-10T22:38:39Z).

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.08.10 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://calcofi.io/db-schema/?v=v2026.08.10

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
con <- calcofi4r::cc_get_db(version = "v2026.08.10")
```
```python
con = calcofi4py.cc_get_db("v2026.08.10")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.08.10/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
