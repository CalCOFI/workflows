# CalCOFI integrated database release v2026.10.21

**Release date:** 2026-10-21 · **promoted** (`latest.txt`)

## The October 2022 eDNA survey moves to its corrected v1.3, and every CTD source archive is kept

This release fixes v2026.10.20's two metadata defects, takes the provider's corrected eDNA archive
and closes the gap that let calcofi.org's 1995-98 CTD files disappear with no copy kept. The
sections below give each change; the bottle, ichthyoplankton, zooplankton and other datasets carry
the same rows as v2026.10.20. Cite this release, not v2026.10.20, for the measurement categories and
faces.

## eDNA: archive v1.3, the ASVs assigned to taxa, and the provider's answers

`calcofi_2022-edna` now reads `dwca-calcofi_october2022_edna-v1.3.zip` (IPT, published 2026-10-19),
in which Garret O'Donnell corrected the "Total number of OTUs or ASVs assigned to taxa": through v1.2
it was a summed read count, so it was held back (question Q04). It is published as two new types,
`edna_asvs_dloop` and `edna_asvs_12s`: the distinct sequences over a filter's libraries of each assay,
not the sum of the per-library values, because PCR replicates share sequences. A filter with one
library of an assay carries exactly the provider's number, which the ingest asserts. The occurrence
and DNA tables are unchanged from v1.2. The citation names Version 1.3; the dataset links the
bioinformatics scripts (github.com/CalCOFI/eDNA_patch) beside the paper. Questions Q04, Q06, Q07,
Q08 and Q10 are answered: the archive carries detections only, because edna2obis drops blanks and
filters with no detection, and it stays that way, as the provider publishes it.

## Every CTD archive the ingest reads is kept on GCS, and a failed download stops the render

calcofi.org listed FinalQC zips for nine cruises that returned 404, and the CTD ingest only warned;
v2026.10.20 recovered eight of them from our archived FinalDB copies. Two gaps let that happen. On
the Mac mini, where releases are cut, the downloads folder is not synced back to GCS, so a zip fetched
from calcofi.org existed on one machine. And a failed download was a `warning()`, which a rendered
notebook hides. Now `calcofi4db::archive_sources()` (4.29.0) keeps each archive the ingest reads,
once by content, at `gs://calcofi-files-public/archive/sources/calcofi/ctd-cast/{md5}/{file}`; a
corrected file re-published under the same name lands beside the old one. `metadata.json`
`sources[]` names each archive's `md5`, calcofi.org `url` and `archive` copy, so the sidecars record
which bytes a release read. Every failed download is listed in the render, and one that leaves its
cruise with no final or preliminary archive stops it unless a provider question names it.

The rebuild was diffed against v2026.10.20 before release (`diff_stage_vs_release()`): the headline
`obs` rows are identical, and `obs_ctd_full` differs by five values, the station-corrected nitrate
and four oxygen estimates of a single upcast scan (cast `0604_014u`, cruise 2006-04-32NM, 403 m),
which the rebuild no longer emits; no value or quality flag changed anywhere else. Its `obs_id`
sequence shifts by those five rows, which is why 22 cruise partitions have new signatures with the
same content. Why that one scan dropped is not yet known. The ingest recorded 295 source archives;
two of them, the raw-cast zips of 2208BH and 1203NH, are 196-byte error pages saved in October 2025
in place of the archive (the ingest does not read raw-cast zips, so no data are affected).

## Farallon's seabird data are CC BY 4.0, the PIC dataset links its collection, and eight questions are filed

`farallon_bird-mammal` was recorded under `custom` terms, pointing at the Farallon Institute's Data
Sharing Agreement (23 July 2025); the agreement releases the data under CC BY 4.0, so the licence
is now `CC-BY-4.0`, and the dataset carries the agreement's requested attribution statement as its
`acknowledgement`.


`sio_pic-zooplankton` names the Pelagic Invertebrate Collection's page as its data source, as
promised with the front-door review. Its question Q07 (preservative and net side) is answered by
Linsey Sala's Parent Net Event table and the net crosswalk (workflows#198). New questions: the
MOCNESS mouth area for gear M2 (Ed Weber, `swfsc_ichthyo`), cruise 1501NH's dual processing and reused
cast numbers (CTD team, `calcofi_ctd-cast`, workflows#134), and bottle cast 24415 of cruise
1986-03-32NM, whose position falls on land near Paso Robles (`calcofi_bottle`, a likely 1° longitude
typo; the position is published as given). Four more came out of measuring the bottle provider's
zero rule and the TEOS-10 sigma-theta: `est_nitrate_cruise_corr` is 0 on every row of cruises 2301,
2304, 2307 and 2411, which looks like a placeholder and gives anomalies of -4 to -12 µmol/L
(`calcofi_ctd-cast` Q48); the July baseline of `est_chlorophyll_a_cruise_corr` is dominated by
values above 20 µg/L from 2000-10 and 2001-07 (Q49); bottle nitrate's code 4 on 277 zeros of
2015-01 (`calcofi_bottle` Q16); and two surface salinities on 2020-07-33P4 (Q17). All four series
are published as given until the provider answers.

## The sixteen METS keys get their category back

v2026.10.20 shipped 16 `calcofi_mets` keys with a NULL category (its known issue). The ingest rebuilds
the `measurement_type` rows it owns and carried only the bounds and `derivation` across the rebuild;
it now carries every registry column, so a blank is filled from the registry and a value the
notebook sets still wins, and it stops if an owned row comes out with a blank where it went in with a
value. `metadata/measurement_type.csv` was never committed blank, so the next re-ingest writes it
unchanged. `sst_c`, `sss_psu`, `tsg1_temp_c`, `tsg1_salinity_psu`, `oxygen`, `uws_flow` and
`bottom_depth_m` return to Physical Oceanography, `par_surf` to Productivity & Pigments and `sw_ph`
to Carbonate System.

## TEOS-10 sigma-theta has a face of its own, and the face registries are checked at release

`sigma_theta_teos10` was registered as a stand-in for `sigma_theta`'s face while carrying its own
NERC P01 (SIGTPR03). A stand-in borrows the lender's chain, so calcofi.io's face check refused it at
the v2026.10.20 deploy, and the key has no face on calcofi.io until the next release. It now takes
`scale`, like `sigma_theta`. `release_database.qmd` runs `validate_measurement_faces()` with the
measurement type registry before it builds `measurements.json` and stops on any finding, including
the new `standsin_own_p01` rule (calcofi4db 4.28.1).

## Contents (generated)

| table | rows | |
|---|---:|---|
| `climatology` | 1,878,006 | partitioned |
| `cruise` | 869 |  |
| `dataset` | 20 |  |
| `dataset_taxon` | 1,940 |  |
| `fish` | 10,796 |  |
| `grid` | 225 |  |
| `grid_crosswalk` | 673 |  |
| `ichthyo_net` | 77,888 |  |
| `lookup` | 26 |  |
| `measurement_type` | 234 |  |
| `obs` | 35,358,143 | deprecated → `obs_bio`, `obs_env` (objects removed in next) |
| `obs_attribute` | 455,300 |  |
| `obs_bio` | 1,586,795 |  |
| `obs_env` | 33,771,348 | partitioned |
| `region` | 4 |  |
| `sample` | 1,467,375 |  |
| `sample_measurement` | 659,307 |  |
| `sample_spatial` | 1,996,331 |  |
| `ship` | 49 |  |
| `spatial` | 3,390 |  |
| `spatial_attribute` | 37,943 |  |
| `taxon` | 2,606 |  |
| `taxon_group` | 438 |  |
| `obs_ctd_full` | 286,148,056 | supplemental |
| `obs_mets_full` | 19,926,523 | supplemental |
| `sample_root` | 419,418 | supplemental |

**26 tables, 383,803,703 rows, 2.85 GB.**

**Datasets (20):** `calcofi_2022-edna`, `calcofi_bottle`, `calcofi_bottle-derived`, `calcofi_ctd-cast`, `calcofi_ctd-derived`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_iron`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 97 pass / 0 fail / 4 skip (consumer-contract suite, 2026-10-21T10:39:31Z).

**Software:** calcofi4db 4.29.0, calcofi4r 1.28.0.

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.10.21 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://calcofi.io/db-schema/?v=v2026.10.21

Cite the source datasets you use alongside the release:

- `calcofi_2022-edna` — Patin N, ODonnell G (2026). CalCOFI October 2022 Vertebrate eDNA. Version 1.3. Occurrence dataset. https://doi.org/10.15468/n52j6r
 · CC-BY-4.0
- `calcofi_bottle` — CalCOFI. (2023). CalCOFI Bottle Database 194903-202105. CalCOFI.org. · *license pending*
- `calcofi_bottle-derived` — CalCOFI. (2026). CalCOFI Bottle Derived Hydrographic Products (from the CalCOFI Bottle Database 194903-202105). CalCOFI.io. https://calcofi.io/workflows/ingest_calcofi_bottle-derived.html · *license pending*
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
con <- calcofi4r::cc_get_db(version = "v2026.10.21")
```
```python
con = calcofi4py.cc_get_db("v2026.10.21")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.10.21/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
