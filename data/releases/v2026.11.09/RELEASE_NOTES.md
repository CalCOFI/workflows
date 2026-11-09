# CalCOFI integrated database release v2026.11.09

**Release date:** 2026-11-09 · **promoted** (`latest.txt`)

## Fall cruise 2611 grows from 11 to 36 casts: lines 93.3, 90 and 86.7, with 83.3 begun

The ship re-issued `20-2611_CTDCast.zip` on 2026-11-08 (Ben Gire, CalCOFI technicians) with
casts 1–36, 31 October to 7 November, covering lines 93.3, 90 and 86.7 and the first station of
83.3, against the 11 casts of v2026.11.05. Cruise `2026-11-33P4` goes from 24,986 to 80,945
headline observations (`obs_env`, now 37 measurement types) and from 347,634 to 1,133,895 in
`obs_ctd_full`; `calcofi_ctd-derived` gains the same casts' `sigma_theta_ave`, `spiciness0` and
`buoyancy_n2` (2,016,414 to 2,021,751 rows). The tier is still `preliminary_with_bottle`, with no
nutrients yet. No other cruise changed: every other cruise × measurement type of `calcofi_ctd-cast`
and `calcofi_ctd-derived` has the same row count, sum and flags as v2026.11.05.

The re-issue also revises casts 1–11, as the corrections are refitted over more bottles: corrected
salinity moves by at most 0.0009, the averaged station-corrected oxygen by at most 0.02 mL/L, and
the cruise-corrected chlorophyll estimate by up to 0.23 µg/L. `dynamic_height` and
`specific_volume_anomaly` arrive for casts 1–11, which had shipped without them. On cast 7's
upcast the ship has flagged the primary temperature, salinity and oxygen sensors 9 from 1–24 m, so
the averaged oxygen there rests on the secondary sensor alone and rises by up to 64 µmol/kg.

Two gaps come from the source and are left as they are: dynamic height and its flag are blank on
every upcast in this file (the technicians will address the cause later), so `dynamic_height` is
downcast only for this cruise; and cast 36 (83.3 51) has bottle salts only, so it carries no
station-corrected oxygen or chlorophyll.

## Two held datasets reach their private previews: CCE-LTER size-fractionated chlorophyll and NOAA's CTD casts

No public table changes. `cce-lter_chl-size-fractionated` (workflows#155) and `swfsc_ctd-noaa`
(workflows#154) are staged and held (`in_release: false`) until their providers decide from a
private preview, so this section describes what the preview candidates carry and what the
public release gains in validation. The depth-vs-seafloor ratchet (`DEPTH_SEAFLOOR_OVER_HELD`)
now carries a baseline for each: 13 of the 422 chlorophyll casts are 0–100 m integrations at
three stations whose GEBCO 2025 floor is 56–84 m (CCE-LTER question Q05, the provider's call
on whether the integration stopped at the bottom bottle), and eight of the 886 NOAA CTD casts
have a deepest standard depth 12–250 m below the GEBCO floor (SWFSC question Q06, Ed Weber:
position or filled depths). A public release that carried either dataset with more such casts
than its baseline would stop at `depth_coverage`; neither count can grow silently.

**Consumers:** nothing changes for a consumer of the public release; both datasets stay
absent from `catalog.json` until consent is recorded.

## `sio_cetacean-sightings` (held): the second preview candidate carries `sample_track` and the Farallon cut

No public table changes. The second private preview of the Scripps Whale Acoustics Lab's visual
sightings (root `ducklake-preview-sightings`) is cut from the sightings shard rendered on
2026-11-06 and from a Farallon shard rendered with the marine-mammal cut, passed to
`scripts/preview_candidate.sh` through `CALCOFI_CAND_OVERRIDE`, so the lab sees the two surveys as
they would stand together once theirs is released: the effort segments and the ship-to-animal
sight lines as `sample_track` paths, every placed sighting at the animal's position, the four
sighting attributes, the lab's source files beside the notebook, and no Farallon marine mammal on
a cruise the survey covered. Both rules are described under v2026.11.05 below (the entries were
written before that release was cut and were promoted with it, though neither reached its
tables): the public release still has no `sample_track` table and still carries every Farallon
marine mammal, and will until the lab's consent is recorded and the dataset is un-held. The
Explorer gained an Effort layer (`effort=on`, CalCOFI/explore#45) that draws the segments and
sight lines of a release that has `sample_track`, and stays disabled on one that does not.

**Consumers:** nothing changes for a consumer of the public release.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `climatology` | 1,921,596 | partitioned |
| `cruise` | 869 |  |
| `dataset` | 20 |  |
| `dataset_taxon` | 1,940 |  |
| `fish` | 10,796 |  |
| `grid` | 225 |  |
| `grid_crosswalk` | 673 |  |
| `ichthyo_net` | 77,888 |  |
| `lookup` | 26 |  |
| `measurement_type` | 298 |  |
| `obs` | 36,096,173 | deprecated → `obs_bio`, `obs_env` (objects removed in next) |
| `obs_attribute` | 455,300 |  |
| `obs_bio` | 1,586,795 |  |
| `obs_env` | 34,509,378 | partitioned |
| `region` | 4 |  |
| `sample` | 1,467,430 |  |
| `sample_measurement` | 715,139 |  |
| `sample_spatial` | 2,296,225 |  |
| `ship` | 49 |  |
| `spatial` | 3,395 |  |
| `spatial_attribute` | 37,968 |  |
| `taxon` | 2,606 |  |
| `taxon_group` | 438 |  |
| `obs_ctd_full` | 287,281,956 | supplemental |
| `obs_mets_full` | 19,926,523 | supplemental |
| `sample_root` | 419,489 | supplemental |

**26 tables, 386,813,199 rows, 3.09 GB.**

**Datasets (20):** `calcofi_2022-edna`, `calcofi_bottle`, `calcofi_bottle-derived`, `calcofi_ctd-cast`, `calcofi_ctd-derived`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_iron`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 106 pass / 0 fail / 4 skip (consumer-contract suite, 2026-11-09T12:53:21Z).

**Software:** calcofi4db 4.35.1, calcofi4r 1.31.0.

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.11.09 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://calcofi.io/db-schema/?v=v2026.11.09

Cite the source datasets you use alongside the release:

- `calcofi_2022-edna` — Patin N, ODonnell G (2026). CalCOFI October 2022 Vertebrate eDNA. Version 1.3. Occurrence dataset. https://doi.org/10.15468/n52j6r
 · CC-BY-4.0
- `calcofi_bottle` — CalCOFI. (2023). CalCOFI Bottle Database 194903-202105. CalCOFI.org. · CC-BY-4.0
- `calcofi_bottle-derived` — CalCOFI. (2026). CalCOFI Bottle Derived Hydrographic Products (from the CalCOFI Bottle Database 194903-202105). CalCOFI.io. https://calcofi.io/workflows/ingest_calcofi_bottle-derived.html · CC-BY-4.0
- `calcofi_ctd-cast` — CalCOFI. (2023). CalCOFI CTD Cast Files. CalCOFI.org. · *license pending*
- `calcofi_ctd-derived` — CalCOFI. (2026). CalCOFI CTD Derived Hydrographic Products (from the CalCOFI CTD Cast Files). CalCOFI.io. https://calcofi.io/workflows/ingest_calcofi_ctd-derived.html · *license pending*
- `calcofi_dic` — Keeling, C.D.; Lueker, T.J.; Emanuele, G.; Dickson, A.G.; Martz, T.R.; Wolfe, W.H.; Mau, A. (2025). Discrete profile dissolved inorganic carbon, total alkalinity, water temperature and salinity measurements for CalCOFI (NCEI Accession 0301029). NOAA NCEI. https://doi.org/10.25921/3w9f-jd72 · CC-BY-4.0
- `calcofi_mets` — CalCOFI. Underway (METS) TSG/Meteorology Data. CalCOFI.org. · *license pending*
- `calcofi_phyllosoma` — CalCOFI - Scripps Institution of Oceanography and T. Koslow. 2017. Data pertaining to lobster phyllosoma, Panulirus interruptus, collection methods, locations, identification and staging (1951-2008, months of July and August) ver 4. Environmental Data Initiative. https://doi.org/10.6073/pasta/9e38121ebb26f1b59b7b39b2eff844fa · custom (https://portal.edirepository.org/nis/metadataviewer?packageid=knb-lter-cce.188.4)
- `calcofi_phytoplankton` — CalCOFI - Scripps Institution of Oceanography, California Current Ecosystem LTER, and E. Venrick. 2023. Temporal and spatial changes of the abundance and species composition of phytoplankton in the California Current from samples collected aboard CalCOFI cruises from summer 1996 through 2022. ver 4. Environmental Data Initiative. https://doi.org/10.6073/pasta/60edabfbfd85c623fce05822befaa071 · CC0-1.0 (https://creativecommons.org/publicdomain/zero/1.0/)
- `cce-lter_euphausiids` — Ohman, M.D. 2022. California Current Ecosystem Euphausiid data, Brinton and Townsend Euphausiid Database (BTEDB) ver 1. Environmental Data Initiative. https://doi.org/10.6073/pasta/4a92a0044bcd1523a4f994ece874a57d · custom (https://portal.edirepository.org/nis/metadataviewer?packageid=knb-lter-cce.313.1)
- `cce-lter_iron` — California Current Ecosystem LTER, CalCOFI - Scripps Institution of Oceanography, and K. Barbeau. 2017. Measurements of dissolved inorganic concentrations of nutrient iron and of iron limitation at selected stations and depths from CalCOFI cruises in the California Current System, Nov. 2002 - July 2004 (completed) ver 3. Environmental Data Initiative. https://doi.org/10.6073/pasta/63c4e57f87861db3acaf80d1dec103e1.
 · custom (https://portal.edirepository.org/nis/mapbrowse?packageid=knb-lter-cce.21.3)
- `cce-lter_picoplankton-bacteria` — Landry, M. (2004-2023). Picoplankton and Bacteria Abundance (CalCOFI Cruise). CCE LTER. · *license pending*
- `cce-lter_zoodb` — *citation pending* · custom (https://oceaninformatics.ucsd.edu/zoodb/)
- `cce-lter_zooscan` — *citation pending* · custom (https://oceaninformatics.ucsd.edu/zooscandb/)
- `cdfw_dungeness-crab` — Rogers-Bennett, L.; Jones, E.; Klemmedson, A. (2026). CDFW Dungeness Crab Megalopae from archived CalCOFI plankton samples (1949-2014). California Department of Fish and Wildlife, published through CalCOFI / Scripps Institution of Oceanography.
 · CC-BY-4.0
- `farallon_bird-mammal` — *citation pending* · CC-BY-4.0 (https://oceanview.pfeg.noaa.gov/CalCOFI/app/resources/docs/Data_Sharing_Agreement_FarallonInstitute.pdf)
- `sio_mesopelagic-fish` — Koslow, J. Anthony (2016). CalCOFI Trawl Data. In California Cooperative Oceanic Fisheries Investigations (CalCOFI): Acoustic and Trawl Data. UC San Diego Library Digital Collections. https://doi.org/10.6075/J0BZ64DH
 · CC-BY-4.0
- `sio_pic-zooplankton` — *citation pending* · *license pending*
- `swfsc_cufes` — *citation pending* · custom (https://coastwatch.pfeg.noaa.gov/erddap/tabledap/erdCalCOFIcufes.das)
- `swfsc_ichthyo` — NOAA Fisheries SWFSC. CalCOFI Ichthyoplankton Database. · *license pending*

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.11.09")
```
```python
con = calcofi4py.cc_get_db("v2026.11.09")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.11.09/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
