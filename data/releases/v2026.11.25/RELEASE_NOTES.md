# CalCOFI integrated database release v2026.11.25

**Release date:** 2026-11-25 · **promoted** (`latest.txt`)

## Every dataset now says in plain words what it is, how it was collected and whether it continues

The record a release publishes for each dataset (`datasets.json`, now schema 1.2) gains a
`display` block: a plain name ("Fish Egg and Larva Counts" beside "Ichthyoplankton"), one line each
on how the samples were collected and how they were analysed and by whom, a collection method
(net tow, ship's pump, CTD sensors, water samples, underway sensors, visual survey, derived),
whether collection is `ongoing` or `ended`, a short description for a list, the notes a reader
needs before using the data, method references, and notes on individual columns. The record also
gains `browse`, the eleven groups calcofi.io/datasets shows as tiles, and
`attribution.associated_parties`, so a data provider or curator named beside the creators reaches a
page and not only EML.

These words were drafted by Betty Huang for calcofi.io on 18 to 21 November from each dataset's own
description and the CalOOS CalCOFI list, and were kept in the website's repository. They now live
with the rest of each dataset's metadata: the plain name, method and group in the ingest notebook,
the sentences in the dataset's `dataset_meta.yml` (where its provider can correct them through the
Sheet), and the vocabularies in `metadata/collection_method.csv`, `metadata/browse_group.csv` and
`metadata/browse_realm.csv`. Nothing in the data tables changes.

**Attribution corrected against the CalOOS CalCOFI list** (workflows#282): citations for the bottle,
CTD cast, CUFES and ichthyoplankton datasets; a licence where none was stated (`CC-BY-4.0` for
`calcofi_ctd-cast`, `calcofi_ctd-derived` and `calcofi_mets`; `CC0-1.0` for `swfsc_ichthyo` and
`swfsc_cufes`, which replaces `custom` on the latter); creators and contacts for the bottle and CTD
datasets, CUFES, ichthyoplankton, the mesopelagic fish and the Dungeness crab megalopae; and two
corrected email addresses. These came from the list and not yet from each provider, so the
question on each stays open and the dataset's page says so. The Farallon seabird and marine mammal
dataset gets a drafted citation, also with an open question.

Two short names change: `calcofi_dic` is "Dissolved Inorganic Carbon" (was "Carbonate Chemistry /
DIC") and `calcofi_mets` is "Underway Meteorology (METS)" (was "Underway Meteorological (METS)").

**Consumers:** `datasets.json` `schema_version` is `1.2`. The change is additive: `display` on every
dataset (each key null where nothing is declared), `browse` at the top level, and
`associated_parties` inside `attribution`. A reader that matches on `dataset_name_short` for
`calcofi_dic` or `calcofi_mets` sees the new text.

## Fall cruise 2611: the three series left out on casts 37–53 are now in

The CalCOFI technicians posted a corrected `20-2611_CTDCast.zip` late on 2026-11-18 (Ben Gire),
with the column names the ship's Seabird processing had mangled put right. v2026.11.18 left
`dynamic_height`, `potential_temperature_2` and `specific_volume_anomaly` off casts 37–53 at the
provider's request; this release carries all three on all 53 casts. Cruise `2026-11-33P4` goes
from 113,983 to 116,337 headline observations (`obs_env`): `dynamic_height` and
`specific_volume_anomaly` each go from 2,703 rows on 36 casts to 3,880 on 53. `obs_ctd_full`
goes from 1,614,109 to 1,646,545 rows for the cruise, where `potential_temperature_2` now also
covers every cast. No value published in v2026.11.18 for the cruise changed (compared row by
row on cast, measurement and depth). The tier is still `preliminary_with_bottle`, with no
nutrients yet.

## `sio_cetacean-sightings` (held): the fourth preview reads the lab's 2026-11-18 delivery

No public table changes. The ingest reads the Scripps Whale Acoustics Lab's repository at commit
`44019d2` (Michaela Alksne, 2026-11-18): 5,425 on-effort sightings on 3,431 segments over 78
cruises (5,090 and 3,241 before), with sightings an earlier timestamp-format problem had dropped
restored (CC2009-11 and CC2010-07 among them; Q25). Times are converted to UTC with the lab's own
per-cruise `UTC_offset_h` (−8 PST, −7 PDT; Q04), which replaces `cruise_utc_offset.csv`: 305
sightings and 161 segments on 8 cruises move by one hour. One behaviour codebook now covers every
year, and the two behaviours the CountCOFI app wrote as text are codes (Q31); four values stay
outside it, unpublished. 5,318 sightings are placed at the animal (4,996 before) and 107 stay at
the ship. The lab's visual observation protocol (PDF) joins the archived sources. Seven provider
questions are answered; the publish decision, licence and citation (Q15, Q01, Q02) wait on the PIs,
and three new questions (Q32–Q34) cover the November daylight-saving offsets, pre-2016 secondary
behaviour codes and four restored sightings. The held dataset's NULL-`cruise_key` ratchet goes from
64 to 80 segments: the restored effort on the two cruises the crosswalk cannot yet key (CC2023-03,
CC2024-07).

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
| `isopycnal` | 709,787 |  |
| `lookup` | 26 |  |
| `measurement_type` | 304 |  |
| `obs` | 36,024,277 | deprecated → `obs_bio`, `obs_env` (objects removed in next) |
| `obs_attribute` | 455,300 |  |
| `obs_bio` | 1,586,795 |  |
| `obs_env` | 34,437,482 | partitioned |
| `region` | 4 |  |
| `sample` | 1,467,488 |  |
| `sample_measurement` | 715,412 |  |
| `sample_spatial` | 2,296,579 |  |
| `ship` | 49 |  |
| `spatial` | 3,395 |  |
| `spatial_attribute` | 37,968 |  |
| `taxon` | 2,606 |  |
| `taxon_group` | 438 |  |
| `obs_ctd_full` | 286,046,006 | supplemental |
| `obs_mets_full` | 19,926,523 | supplemental |
| `sample_root` | 419,547 | supplemental |

**27 tables, 386,215,174 rows, 2.89 GB.**

**Datasets (20):** `calcofi_2022-edna`, `calcofi_bottle`, `calcofi_bottle-derived`, `calcofi_ctd-cast`, `calcofi_ctd-derived`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_iron`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 195 pass / 0 fail / 4 skip (consumer-contract suite, 2026-11-25T15:33:04Z).

**Software:** calcofi4db 4.42.0, calcofi4r 1.34.0.

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.11.25 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://doi.org/10.5281/zenodo.24541941

Cite the source datasets you use alongside the release:

- `calcofi_2022-edna` — Patin N, ODonnell G (2026). CalCOFI October 2022 Vertebrate eDNA. Version 1.0. Occurrence dataset. https://ipt-obis.gbif.us/resource?r=calcofi_october2022_edna&v=1.0 https://doi.org/10.15468/n52j6r
 · CC-BY-4.0
- `calcofi_bottle` — Scripps Institution of Oceanography, UC San Diego, 2026. CalCOFI Hydrographic CTD Bottle Data. https://calcofi.org/data/oceanographic-data/bottle-database/ · CC-BY-4.0
- `calcofi_bottle-derived` — CalCOFI. (2026). CalCOFI Bottle Derived Hydrographic Products (from the CalCOFI Bottle Database 194903-202105). CalCOFI.io. https://calcofi.io/workflows/ingest_calcofi_bottle-derived.html · CC-BY-4.0
- `calcofi_ctd-cast` — Scripps Institution of Oceanography, UC San Diego, 2026. CalCOFI Hydrographic CTD Cast Profile Data. https://calcofi.org/data/oceanographic-data/ctd-cast-files/ · CC-BY-4.0
- `calcofi_ctd-derived` — CalCOFI. (2026). CalCOFI CTD Derived Hydrographic Products (from the CalCOFI CTD Cast Files). CalCOFI.io. https://calcofi.io/workflows/ingest_calcofi_ctd-derived.html · CC-BY-4.0
- `calcofi_dic` — Keeling, C.D.; Lueker, T.J.; Emanuele, G.; Dickson, A.G.; Martz, T.R.; Wolfe, W.H.; Mau, A. (2025). Discrete profile dissolved inorganic carbon, total alkalinity, water temperature and salinity measurements for CalCOFI (NCEI Accession 0301029). NOAA NCEI. https://doi.org/10.25921/3w9f-jd72 · CC-BY-4.0
- `calcofi_mets` — CalCOFI. Underway (METS) TSG/Meteorology Data. CalCOFI.org. · CC-BY-4.0
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
- `farallon_bird-mammal` — Sydeman, W. J., Veit, R. R., & Hyrenbach, K. D. (2025). CalCOFI Farallon Institute Seabirds [Dataset]. Farallon Institute. NOAA ERDDAP. https://oceanview.pfeg.noaa.gov/erddap/tabledap/CAC_FI_SBAS_tr.html · CC-BY-4.0 (https://oceanview.pfeg.noaa.gov/CalCOFI/app/resources/docs/Data_Sharing_Agreement_FarallonInstitute.pdf)
- `sio_mesopelagic-fish` — Koslow, J. Anthony (2016). CalCOFI Trawl Data. In California Cooperative Oceanic Fisheries Investigations (CalCOFI): Acoustic and Trawl Data. UC San Diego Library Digital Collections. https://doi.org/10.6075/J0BZ64DH
 · CC-BY-4.0
- `sio_pic-zooplankton` — *citation pending* · *license pending*
- `swfsc_cufes` — Southwest Fisheries Science Center, 2026: Continuous Underway Fish-Egg Sampler (CUFES) Database. NOAA National Centers for Environmental Information, https://www.fisheries.noaa.gov/inport/item/20692. · CC0-1.0
- `swfsc_ichthyo` — Southwest Fisheries Science Center, 2026: CalCOFI Database. NOAA National Centers for Environmental Information, https://www.fisheries.noaa.gov/inport/item/20691. · CC0-1.0

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.11.25")
```
```python
con = calcofi4py.cc_get_db("v2026.11.25")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.11.25/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
