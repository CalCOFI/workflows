# CalCOFI integrated database release v2026.08.05

**Release date:** 2026-08-05
*Documented with v2026.08.04 – v2026.08.06.*

Three closely spaced releases while consumer deployment became part of the pipeline: consumers
sync automatically on promotion, `deploy_consumers` is a real target that reports which release
each consumer is *actually* serving (the h3t API held its old database file open across a symlink
flip), ERDDAP deploys from `publish_to-erddap.qmd`, and the public release index is regenerated on
promotion. Spatial layers gained attributes (`spatial` 3,373 → 13,206 features; `spatial_attribute`
40k → 148k). v2026.08.05 dropped 17,187 duplicate/invalid `sample` rows. Four WoRMS/taxonomic-status
gates added (28 → 32).

## Contents (generated)

| table | rows | |
|---|---:|---|
| `cruise` | 691 |  |
| `dataset` | 15 |  |
| `dataset_taxon` | 1,907 |  |
| `grid` | 218 |  |
| `lookup` | 26 |  |
| `measurement_type` | 198 |  |
| `obs` | 20,088,748 | partitioned |
| `obs_attribute` | 452,682 |  |
| `region` | 4 |  |
| `sample` | 1,460,019 |  |
| `sample_measurement` | 588,986 |  |
| `ship` | 49 |  |
| `spatial` | 13,206 |  |
| `spatial_attribute` | 148,461 |  |
| `taxon` | 2,121 |  |
| `taxon_group` | 154 |  |
| `obs_ctd_full` | 212,444,287 | supplemental |
| `obs_mets_full` | 19,936,073 | supplemental |

**18 tables, 255,137,845 rows, 1.72 GB.**

**Datasets (15):** `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 27 pass / 1 fail / 4 skip (consumer-contract suite, 2026-08-05T22:01:13Z).

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.08.05 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://calcofi.io/db-schema/?v=v2026.08.05

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
con <- calcofi4r::cc_get_db(version = "v2026.08.05")
```
```python
con = calcofi4py.cc_get_db("v2026.08.05")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.08.05/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
