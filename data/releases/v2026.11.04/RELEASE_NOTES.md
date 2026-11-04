# CalCOFI integrated database release v2026.11.04

**Release date:** 2026-11-04 · **promoted** (`latest.txt`)

## Hypoxic boundary depths, the nitracline, the pycnocline and N² join the CTD-derived products

`calcofi_ctd-derived` adds, per cast, the three **hypoxic boundary depths** of the CTD team's
definition (Rasmus Swalethorp, 2026-09-24): the shallowest depth at which the station-corrected
oxygen pair average falls to 2.4 mL/L (`hypoxic_depth_24`, the mild boundary), 1.4 mL/L
(`hypoxic_depth_14`, the hypoxic boundary) and 0.5 mL/L (`hypoxic_depth_05`, the severe
boundary, the core of the oxygen minimum zone), each interpolated between the 1 m bins that
bracket it; the oxygen minimum can sit mid-profile, so the depth is always the shallowest
crossing. These replace the 60 µmol/kg "OMZ depth" proposed on 2026-10-20. The **nitracline
depth** (`nitracline_depth`) is where nitrate reaches 1 µmol/L by the same rule, on the
bottle-fitted sensor estimate `est_nitrate_sta_corr`; `calcofi_bottle-derived` publishes the
same key from the bottle database's own nitrate at the bottle depths (the team's bottle-era
rule, D_NClineDepth.m: linear interpolation between the samples above and below). The
**pycnocline depth** (`pycnocline_depth`) is where the buoyancy frequency squared N² (TEOS-10
`gsw_Nsquared`, a 10 m running mean) is greatest between 10 and 200 m, with that maximum
(`buoyancy_n2_max`), after the team's F_PycnoclineDepth.m (Fiedler et al. 2013) modernised with
TEOS-10; N² itself is published at every CTD depth (`buoyancy_n2`) for the transect plotter. A
profile already past a threshold at its first bin counts only when that bin is within 20 m of
the surface; a cast that never crosses has no row. Every rule is a tested calcofi4db 4.32.0
function (`profile_threshold_depth()`, `ctd_hypoxic_depth()`, `ctd_n2()`, `ctd_pycnocline()`),
applied to final and preliminary-with-bottle casts after the provider's flags. Each per-cast
key but `hypoxic_depth_05` (too few 1993–2013 casts reach the 0.5 mL/L core on a station-month)
has a 1993–2013 baseline in `climatology`, so the Explorer and ctd-transects show its anomaly
like the mixed-layer depth's. The one choice that is ours, the 10 m running mean on N² in
place of the draft script's smoothing spline, is CTD-derived question Q11; the implemented
definitions are Q10.

**Consumers:** seven new measurement keys (`hypoxic_depth_24`, `hypoxic_depth_14`,
`hypoxic_depth_05`, `nitracline_depth`, `pycnocline_depth`, `buoyancy_n2_max` in
`sample_measurement`; `buoyancy_n2` in `obs_env`); `nitracline_depth` is published by two
datasets, filter on `dataset_key`.
## A new dataset, staged not released: `cce-lter_poc-pon-cce-region`, POC and PON on CCE-LTER Process cruises, 2006–2024

`ingest_cce-lter_poc-pon-cce-region.qmd` ingests the CCE-LTER EDI package `knb-lter-cce.104.13`
(Aluwihare, doi:10.6073/pasta/9feb1de01eb3795e7ea39a8b7ba325e6, CC0 1.0; CalCOFI/workflows#84):
3,216 samples (3,159 Niskin bottles and 57 underway surface samples) with 6,432 `obs` of `poc` and
`pon`, the types `cce-lter_poc-pon` registers. Process cruises follow water parcels rather than the
CalCOFI grid, so these samples carry no `cruise_key` and no `site_key`; each still gets a `grid_key`
from its position. The `cruise_key` integrity ratchet records that as the dataset's baseline (all
3,216 root samples, reached only in a private preview). It is **held out of the release**
(`in_release: false`) until the provider answers the questions on the 76 held-out rows (Q02–Q04) and
agrees to publication (consent Q06).

What ships is registry content only: the `_source_datasets` of `poc` and `pon` also name
`cce-lter_poc-pon-cce-region`. The holding's catalog abstract, which had described a nitrate
stable-isotope dataset, is replaced by the EDI package's own (Q01).
## The bottle provider's answers of 1–3 November: salinity of 2021-05 and four 2020-07 bottles, nitrate of 1976-02, and cast 24415

Rasmus Swalethorp answered ten `calcofi_bottle` questions and two `calcofi_ctd-cast` ones in
comments on the provider question Sheet (1 and 3 November); each is recorded verbatim in
`questions.csv`. The ones that change data are rows of two new registries in
`metadata/calcofi/bottle/`, applied by `ingest_calcofi_bottle.qmd` § Apply Provider Answers
(`libs/bottle_answers.R`, tested), so every decision is visible in a diff and restored by
deleting its row. Measured against v2026.10.30:

- **Flagged 8 (suspect), values kept** (`qual_overrides.csv`; excluded by `cc_qual_ok_sql()` /
  `qual_ok`): every `salinity` of cruise 2021-05-3322, whose column holds sigma-theta (Q13;
  918 values), the salinity of two unflagged 2020-07-33P4 surface bottles 0.2–0.7 off the CTD
  (Q17; bottles 889874 and 890872), and every `nitrate` of 1976-02-31AX (Q14; 78 values, after
  the declared `valid_max` of 60 µmol/L had already removed six). 998 codes change; no value
  changes. The two 2020-07-33P4 50 m salinities of Q13 (bottles 891039 and 891075, beside
  temperatures of 99.0 and 56.9 °C) carry the flag in the registry but were already removed
  with their impossible temperatures.
- **Removed** (`sample_exclusions.csv`): bottle cast 24415 (1986-03-32NM, station 075.0 040.0),
  placed on land near Paso Robles (Q15): 1 cast and 17 bottles from `sample`, 247 `obs`,
  5 `sample_measurement` rows.
- **`calcofi_bottle-derived`** no longer withholds 2021-05-3322 by name: its flagged salinity
  keeps it out by the flag rule (Q03), as before; the two Q17 bottles and cast 24415 lose their
  spice and TEOS-10 sigma-theta (19 rows of each type).
- `metadata/measurement_qual.csv` documents bottle code 4 as a value zeroed at or below the
  detection limit, or negative (Q16); it stays a usable code.
- **The licence of `calcofi_bottle` is now CC-BY-4.0** (Q10), and `calcofi_bottle-derived`
  inherits it (its Q01).

## A new dataset, staged not released: `cce-lter_hplc-pigments-calcofi`, HPLC pigments on CalCOFI cruises, 2002–2023

`ingest_cce-lter_hplc-pigments-calcofi.qmd` ingests the CCE-LTER EDI package `knb-lter-cce.316.1`
(Goericke, Stukel, Dovel; doi:10.6073/pasta/99e2bad73df5fd4890237d31415820b8, CC0 1.0;
CalCOFI/workflows#84): 9,136 Niskin bottle samples with 154,459 `obs` of chlorophylls and carotenoids
(µg/L). Samples were analysed by the Goericke Lab (SIO) through 2014 and by Horn Point Laboratory
(UMCES) since, and the provider's own comparison finds some pigments not comparable between the two,
so each lab's values get their own types; which can be joined is left to a `variable` crosswalk. The
provider's per-sample QC flag is published as `measurement_qual`. It is **held out of the release**
(`in_release: false`) until the provider answers the questions on held-out rows (Q01, Q02, Q04) and
which QC flags a user should exclude (Q06). The catalog holding `cce-lter_hplc-pigments` (EDI 72,
Process cruises) is a different table and stays a holding.

What ships is registry content:

- `measurement_type` gains 44 types, `hplc_{pigment}_sio` and `hplc_{pigment}_umces` (µg/L,
  `valid_min = 0`; `metadata/cce-lter/hplc-pigments-calcofi/pigment_columns.csv` maps each source
  column).
- `measurement_qual` gains the code set `hplc-pigments-calcofi` (0 no flag, 1 TChl a ≤ 0,
  2 accessory-pigment ratio, 3 HPLC vs fluorometer mismatch). `calcofi4r`'s `CC_QUAL_EXCLUDE` does
  not list the dataset yet, so no flag is excluded by default until Q06 is answered.
- `ship_renames.csv` gains CCE-LTER's code `33SH` → NODC `3322` (Bell M. Shimada, 2021-05).

## A new dataset, staged not released: `cce-lter_toc`, total organic carbon on CalCOFI cruises, 2008–2017

`ingest_cce-lter_toc.qmd` ingests the CCE-LTER EDI package `knb-lter-cce.253.3` (Aluwihare,
doi:10.6073/pasta/ba2ce7e921448a75372109d9f2f5cab2, CC0 1.0), fetched and md5-pinned by
`libs/download_toc.R` (CalCOFI/workflows#84): 10,089 Niskin bottle samples with 10,147 `toc` obs
(µmol/L; a bottle analysed more than once keeps each analysis as its own obs). The source's
coefficient of variation is published as `measurement_prec` (standard deviation = TOC × CV / 100).
It is **held out of the release** (`in_release: false`) until the provider answers Q01: 13 values near
2,100 µmol/L, in the range of seawater inorganic carbon. Two exact duplicate rows are dropped and one
undated row is held out (Q05).

What does ship is one registry row: `measurement_type` gains `toc` (µmol/L, `valid_min = 0`,
`_prec_column` "TOC CV"; no upper bound).

Two bottles of the 2017-01 cast 37 sit 19 and 24 m below the GEBCO seafloor; they are published as
given and recorded as the dataset's held-out seafloor baseline (`DEPTH_SEAFLOOR_OVER_HELD`, Q06).
`libs/download_edi.R` now falls back to EDI's DataONE member node when PASTA refuses anonymous
access (every public call answered 403 "Public Access is not authorized" on 2026-11-04); the md5 pin
is checked on both routes.

## A new dataset, staged not released: `cce-lter_poc-pon`, particulate organic carbon and nitrogen on CalCOFI cruises, 2004–2023

`ingest_cce-lter_poc-pon.qmd` ingests the CCE-LTER EDI package `knb-lter-cce.54.10` (Goericke,
doi:10.6073/pasta/830ff22e75a9de5b493af48330e5fc4c, CC0 1.0), fetched and md5-pinned by
`libs/download_poc_pon.R` (CalCOFI/workflows#84): 17,397 Niskin bottle samples with 34,791 `obs` of
`poc` and `pon` (µmol/L). It is **held out of the release** (`in_release: false`) until the provider
confirms the proposed answers (bounds Q01, duplicated rows Q02, missing depths Q04). Four exact
duplicate rows are dropped and 12 rows held out (a bottle listed at two depths, and 10 with no depth).

What does ship is registry content:

- `measurement_type` gains `poc` and `pon` (µmol/L, `valid_min = 0`; no upper bound yet, Q01).
- `ship_renames.csv` gains CCE-LTER's code `32BH` → NODC `39C2` (Bold Horizon). CCE-LTER labels
  recent ships with CalCOFI's own codes (325S, 33SR, 33RL, 31OS, 32BH), so the notebook translates
  them to NODC by code before keying cruises; without that, 7,717 samples had no `cruise_key`.

## A private preview can include a held dataset

`release_database.qmd` can cut a candidate release into the private preview bucket
(`CALCOFI_RELEASE_BUCKET=calcofi-preview`, a staging-style run under `ducklake-preview/`) that
includes datasets every public release holds out (`CALCOFI_RELEASE_INCLUDE`), so a provider sees
their dataset on calcofi.io and in the Explorer behind a sign-in before agreeing to publish it. A
held dataset is refused for any public bucket. Public releases are unchanged; the first candidate
(2026-11-02) includes `sio_cetacean-sightings`, which stays `in_release: false` until the Scripps
Whale Acoustics Lab signs off.

The `cruise_key` integrity ratchet records that dataset's baseline, 66 effort segments with no
`cruise_key` (the cruise labels CC2023-03 and CC2024-07 resolve no reference cruise, sightings Q14;
one segment is misdated, Q07), reached only in that preview.

## IFCB phytoplankton from the CalCOFI CTD (2022-2026)

`sccoos_ifcb-ctd` is staged but held out of this release (`in_release: false`) until the provider confirms the license and citation (Q01, Q02); none of its rows is in the release yet. It holds 671 Imaging FlowCytobot samples (Surface and DCM bottles) from 10 cruises,
Aug 2022 - Jul 2026, summarized by Vivian (Lin) Hou. 103 taxa (102 keyed to WoRMS, plus
"unidentified cells", 37% of all images, as a dataset-local class; the provider's Hemiaulus is summed into Eucampia). `obs` carries `ifcb_abundance`
(images per ml) and `ifcb_biovolume` (um3 per ml) per sample and taxon (37,468 rows); `obs_attribute`
carries the four ESD size classes (29,658 rows); `sample_measurement` carries `ifcb_volume_analyzed`.
Four measurement types are registered. License CC0-1.0 and DOI 10.6075/J05Q4WFB come from the CalOOS
dataset sheet and are awaiting the provider's confirmation for the summary table (Q01).

## Kahru's satellite areas 2–6 are a region layer

A new boundary layer, **Kahru Satellite Areas** (`kahru_satellite_areas`, group *Satellite Regions*),
holds the areas Mati Kahru (SIO) averages satellite chlorophyll over (Kahru et al. 2012, *Deep-Sea
Research II*), for the State of the California Current report: north of line 80, area 3 is the coastal
band 0–100 km from shore and area 2 the transition, 100–300 km; south of it area 6 is coastal, 5 the
transition and 4 offshore. Area 1 (offshore, north) holds too few stations and is left out. Kahru's
station lists (via Rasmus Swalethorp, 2026-10-27) are `metadata/spatial/kahru_areas_stations.csv`, and
each area is the union of the `calcofi4r::cc_grid` cells of its stations, built by
`ingest_spatial.qmd` (`libs/kahru_areas.R`), so the five areas are rows of `spatial` and every sample
inside one has a `sample_spatial` membership.

Version 1 keeps **whole cells**: a line-80 cell is in the one area Kahru listed it in, and the cells
on the 100 km and 300 km borders are not halved, as Rasmus would like them to be when averaging. The
nine SCCOOS inshore stations are not on Kahru's lists, so their cells along the Southern California
coast are in no area.

In the Explorer the layer is in the Regions picker (`lens=region&layer=Kahru Satellite Areas`), and
the Area filter keeps one area: `area=in:Kahru Satellite Areas|Kahru area 5 (transition, south of
line 80)` (URL-encoded; the layer and region names are those of `spatial`).

## Contents (generated)

| table | rows | |
|---|---:|---|
| `climatology` | 1,922,877 | partitioned |
| `cruise` | 868 |  |
| `dataset` | 20 |  |
| `dataset_taxon` | 1,940 |  |
| `fish` | 10,796 |  |
| `grid` | 225 |  |
| `grid_crosswalk` | 673 |  |
| `ichthyo_net` | 77,888 |  |
| `lookup` | 26 |  |
| `measurement_type` | 292 |  |
| `obs` | 36,007,232 | deprecated → `obs_bio`, `obs_env` (objects removed in next) |
| `obs_attribute` | 455,300 |  |
| `obs_bio` | 1,586,795 |  |
| `obs_env` | 34,420,437 | partitioned |
| `region` | 4 |  |
| `sample` | 1,467,358 |  |
| `sample_measurement` | 714,785 |  |
| `sample_spatial` | 2,295,719 |  |
| `ship` | 49 |  |
| `spatial` | 3,395 |  |
| `spatial_attribute` | 37,968 |  |
| `taxon` | 2,606 |  |
| `taxon_group` | 438 |  |
| `obs_ctd_full` | 286,148,056 | supplemental |
| `obs_mets_full` | 19,926,523 | supplemental |
| `sample_root` | 419,417 | supplemental |

**26 tables, 385,501,687 rows, 3.20 GB.**

**Datasets (20):** `calcofi_2022-edna`, `calcofi_bottle`, `calcofi_bottle-derived`, `calcofi_ctd-cast`, `calcofi_ctd-derived`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_iron`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 100 pass / 0 fail / 4 skip (consumer-contract suite, 2026-11-04T22:20:08Z).

**Software:** calcofi4db 4.33.1, calcofi4r 1.29.0.

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.11.04 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://calcofi.io/db-schema/?v=v2026.11.04

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
con <- calcofi4r::cc_get_db(version = "v2026.11.04")
```
```python
con = calcofi4py.cc_get_db("v2026.11.04")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.11.04/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
