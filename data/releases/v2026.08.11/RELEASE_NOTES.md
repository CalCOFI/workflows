# CalCOFI integrated database release v2026.08.11

**Release date:** 2026-08-11

## Ungridded observations are released

Observations whose position resolves no CalCOFI grid cell (transits, historical stations outside
the modern pattern) now reach `obs` with `grid_key` NULL, across all 14 ingests, and
`check_ungridded_obs()` reports them per dataset; each dataset carries a provider question asking
whether they are genuinely off-grid or coordinate errors.

## A position is a pair

CUFES samples were positioned at the segment *start* with the end coordinate resolved from a
different source; the sample position is now the segment midpoint and both coordinates come from
one source (calcofi4db 3.16.1 `append_obs()`). `obs_mets_full` gains the NaN-position guard that
`obs` already had (53 rows).

## The release refuses to re-cut the version consumers are reading

v2026.08.10 was republished under the same tag on 2026-08-11, failed `test_release`, and promotion
was correctly withheld — but `latest.txt` already pointed at the overwritten path, so consumers
read unverified data. `release_database.qmd` now stops if `release_version` equals the promoted
version unless `CALCOFI_ALLOW_REPUBLISH=true`.

**Packages:** calcofi4db 3.13.1 (NaN/Inf coordinates → NULL), 3.14.0 (line/station ↔ lon/lat).

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
| `obs_mets_full` | 19,927,416 | supplemental |

**18 tables, 323,912,311 rows, 2.11 GB.**

**Datasets (15):** `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 28 pass / 0 fail / 4 skip (consumer-contract suite, 2026-08-11T09:08:38Z).

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.08.11 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://calcofi.io/db-schema/?v=v2026.08.11

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
con <- calcofi4r::cc_get_db(version = "v2026.08.11")
```
```python
con = calcofi4py.cc_get_db("v2026.08.11")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.08.11/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
