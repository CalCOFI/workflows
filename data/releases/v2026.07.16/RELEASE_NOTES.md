# CalCOFI integrated database release v2026.07.16

**Release date:** 2026-07-16

## One taxonomy

Eight per-dataset taxon tables (`species`, `taxa_rank`, `phyto_taxon`, `zoodb_taxon`,
`zooscan_taxon`, `bird_mammal_species`, `bird_mammal_behavior`, `obs_freq`) are replaced by
`taxon` (`worms:`/`itis:` keys), `dataset_taxon` (per-dataset crosswalk) and `taxon_group`, and
`obs_freq` becomes `obs_attribute` (size/stage frequencies + behaviour). 22 → 17 tables.
**Consumers:** the consumer contract rekeyed from `species_id` to `taxon_key`.

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

**Validation:** 19 pass / 0 fail / 4 skip (consumer-contract suite, 2026-07-16T19:08:43Z).

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.07.16 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://calcofi.io/db-schema/?v=v2026.07.16

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
con <- calcofi4r::cc_get_db(version = "v2026.07.16")
```
```python
con = calcofi4py.cc_get_db("v2026.07.16")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.07.16/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
