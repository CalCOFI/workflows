# CalCOFI integrated database release v2026.11.14

**Release date:** 2026-11-14 · **promoted** (`latest.txt`)

## Conditions on density surfaces: a new `isopycnal` table and its baseline in `climatology`

Rasmus Swalethorp asked (2026-11-12 and -13) for conditions and their anomalies on sigma-theta
surfaces at the 1 m resolution: below the mixed layer an anomaly at a fixed depth is mostly the
pycnocline moving up or down, and on a density surface that displacement is the surface's depth,
while what is left in temperature, salinity, oxygen or nitrate is a change in the water itself. The
new core table **`isopycnal`** holds, for every CTD down cast and each of his 18 surfaces (24.0 to
27.0 kg/m³ by 0.2, plus 25.5 and 26.5, near the cores of the California Current and Undercurrent),
the depth of the shallowest crossing and the temperature, salinity, oxygen, estimated nitrate and
spice there, one row per cast × surface × type. Every cast and surface keeps its depth row with a
`status`, so a surface that outcrops (`at_surface`) or is never reached (`not_reached`) is not
mistaken for a missing cast. The types are `iso_*` (`iso_depth_m`, `iso_temperature_ave`, …), never
an `obs` series. The table is built at release by `calcofi4db::build_isopycnal()`, which calls
`calcofi4r::cc_isopycnal()`, the one implementation of the rule, on the assembled `obs_ctd_full`.

Its baseline is in the one **`climatology`**, by the depth bins' rules (station, the cruise's month
and season, 1993–2013, at least 5 cruises; every cast's value enters the mean): cells with
`depth_bin` NULL and the surface in a new column **`sigma_theta`**, appended last and NULL on every
other row. No existing row changed, and no reader of a depth bin or a per-cast cell can meet a
surface cell, since only the `iso_*` types carry one (gated in the release and its tests).
`calcofi4r::cc_isopycnal_anomaly()` (1.34.0) subtracts it when it is the baseline asked for.

**Consumers:** `climatology` has one more column (`sigma_theta`) and six more measurement types;
its key is now `dataset_key, site_key, month, depth_bin, measurement_type, sigma_theta`.

## A CTD cast holds one value per depth again: 46,447 doubled cast-depths in 11 cruises resolved

v2026.11.09 and v2026.11.12 carried 46,447 cast-depths in 11 cruises of `calcofi_ctd-cast` with two
rows for one measurement type, in `obs_ctd_full` and in the thinned series of `obs_env` (ctd-cast
question Q47, CalCOFI/workflows#134). The doubling was inside the source archives, and each case is
now read by Rasmus Swalethorp's answer (2026-11-13):

- **2015-01 (1501NH), 43,253 cast-depths of 112 casts.** calcofi.org's archive keeps the
  dual-sensor casts in `db_csv/dualTCO/`, the single-sensor casts in `db_csv/singleTCO/`, and their
  union in a top-level file whose times are written to the minute, so the two copies of a
  dual-sensor cast were never matched. The ingest reads every cast of `dualTCO/` and, from
  `singleTCO/`, the casts `dualTCO/` lacks; the top-level file is not read. The values are the
  same, except 113 PAR bins where the top-level file wrote three significant figures (largest
  change 2.0 µE/m²/s at 1,540), and the dual-sensor casts' times now carry their seconds.
- **1995-04 (9504NH) and 1995-10 (9510NH), 807 and 2,189 cast-depths.** The extra shallow casts in
  `RalfCasts/` (4) and `GoerickeExtraCasts/` (8), about two hours after the regular cast at the same
  station, were filed under the regular cast's number and merged into its sample. They stay, each a
  cast with its own key: the cast number takes a `b` before the direction letter
  (`calcofi_ctd-cast:cast:9504_010bd`), so 1995-04 has 130 casts and 1995-10 has 148 (122 and 132
  before). Their comparison with the regular cast at the same depths went to the provider.
- **A depth bin written twice within one cast** (2020-07 cast 004d, 177 bins; 2003-02 095u, 11;
  2002-04 013u, 4; 1995-07 064u, 2; one bin each in 1997-12, 2005-01, 2006-04 and 2023-07) is now
  averaged by the provider's flags: a value flagged 8 or 9 never enters an average with a good one.

Against v2026.11.12, every other cruise is unchanged, row for row. In the 11 cruises `obs_ctd_full`
loses 1,829,778 rows (the repeated copies) and gains 81,178 (the extra casts' bins under their own
keys), and `obs_env`'s CTD series loses 124,689 and gains 12,622. `ingest_calcofi_ctd-cast.qmd` now
stops on any repeated (sample, depth, type) in either table, in place of the per-cruise allowance it
had carried since v2026.10.01, and `test_release.qmd` checks `obs_env` for it.

**Consumers:** 24 new CTD `sample_key`s (12 extra casts, each direction) in 1995-04 and 1995-10.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `climatology` | 1,992,777 | partitioned |
| `cruise` | 869 |  |
| `dataset` | 20 |  |
| `dataset_taxon` | 1,940 |  |
| `fish` | 10,796 |  |
| `grid` | 225 |  |
| `grid_crosswalk` | 673 |  |
| `ichthyo_net` | 77,888 |  |
| `isopycnal` | 708,647 |  |
| `lookup` | 26 |  |
| `measurement_type` | 304 |  |
| `obs` | 35,985,408 | deprecated → `obs_bio`, `obs_env` (objects removed in next) |
| `obs_attribute` | 455,300 |  |
| `obs_bio` | 1,586,795 |  |
| `obs_env` | 34,398,613 | partitioned |
| `region` | 4 |  |
| `sample` | 1,467,454 |  |
| `sample_measurement` | 715,238 |  |
| `sample_spatial` | 2,296,337 |  |
| `ship` | 49 |  |
| `spatial` | 3,395 |  |
| `spatial_attribute` | 37,968 |  |
| `taxon` | 2,606 |  |
| `taxon_group` | 438 |  |
| `obs_ctd_full` | 285,533,356 | supplemental |
| `obs_mets_full` | 19,926,523 | supplemental |
| `sample_root` | 419,513 | supplemental |

**27 tables, 385,623,162 rows, 2.89 GB.**

**Datasets (20):** `calcofi_2022-edna`, `calcofi_bottle`, `calcofi_bottle-derived`, `calcofi_ctd-cast`, `calcofi_ctd-derived`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_iron`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 195 pass / 0 fail / 4 skip (consumer-contract suite, 2026-11-14T15:53:14Z).

**Software:** calcofi4db 4.39.0, calcofi4r 1.34.0.

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.11.14 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://doi.org/10.5281/zenodo.24223907

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
con <- calcofi4r::cc_get_db(version = "v2026.11.14")
```
```python
con = calcofi4py.cc_get_db("v2026.11.14")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.11.14/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
