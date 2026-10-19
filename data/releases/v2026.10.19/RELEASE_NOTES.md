# CalCOFI integrated database release v2026.10.19

**Release date:** 2026-10-19 · **promoted** (`latest.txt`)

## Each measurement key has an authored short title

`measurements.json` gains `short_label` per key (calcofi.io issue #30, decision D13): the name a
measurement page head shows beside its picture, such as "Dissolved oxygen (ml/L)", while `label`
keeps the full name with its method notes. It is authored in a new `short_label` column of
`metadata/measurement_face.csv` and validated by calcofi4db 4.26.0: at most 48 characters, unique
across keys, no trailing punctuation. Until now calcofi.io cut `label` at its first comma or colon.
Keys that would have shared a title are told apart by where they were measured, for example
"Surface PAR (CTD cast)" and "Surface PAR (underway)". `dissolved_iron`, which had no row in the face
registry, now has one (`face_kind` none: dissolved iron is defined by the filter, a mix of Fe(II),
Fe(III) and organically bound iron, so there is no single thing to draw).

## The euphausiid dataset credits Mark D. Ohman as its PI

`cce-lter_euphausiids` listed Rasmus Swalethorp and Linsey Sala as PIs and Mark D. Ohman and Moira
Decima as creators. Mark D. Ohman's correction: PI Mark D. Ohman; creators Mark D. Ohman and Linsey
Sala. The calcofi_bottle description now says what its "Cast" file is (the rosette cast the bottles
came up on), since a reader took it for the CTD Cast Files dataset.

## A `#` inside a registry field is no longer cut off as a comment

The registry readers skipped comments with `readr::read_csv(comment = "#")`, which cuts every line at
its first `#`. The two `measurement_chem.csv` rows for chlorophyll-a's method product (pheophytin a,
on `chlorophyll_a` and `btl_chlorophyll_a`) cite a calcofi.org URL with a text fragment
(`#:~:text=…`), so they lost the fragment and their `note` ("what acid turns it into"). calcofi4db
4.26.0 skips only the leading block of `#` lines, and both rows now read whole.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `climatology` | 1,828,215 | partitioned |
| `cruise` | 845 |  |
| `dataset` | 19 |  |
| `dataset_taxon` | 1,940 |  |
| `fish` | 10,796 |  |
| `grid` | 225 |  |
| `grid_crosswalk` | 673 |  |
| `lookup` | 26 |  |
| `measurement_type` | 231 |  |
| `obs` | 33,326,406 | deprecated → `obs_bio`, `obs_env` (objects removed in next) |
| `obs_attribute` | 455,300 |  |
| `obs_bio` | 1,586,795 |  |
| `obs_env` | 31,739,611 | partitioned |
| `region` | 4 |  |
| `sample` | 1,467,016 |  |
| `sample_measurement` | 658,009 |  |
| `sample_spatial` | 1,994,263 |  |
| `ship` | 49 |  |
| `spatial` | 3,390 |  |
| `spatial_attribute` | 37,943 |  |
| `taxon` | 2,606 |  |
| `taxon_group` | 438 |  |
| `obs_ctd_full` | 281,888,334 | supplemental |
| `obs_mets_full` | 19,926,523 | supplemental |
| `sample_root` | 419,050 | supplemental |

**25 tables, 375,348,707 rows, 2.75 GB.**

**Datasets (19):** `calcofi_2022-edna`, `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_ctd-derived`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_iron`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 97 pass / 0 fail / 4 skip (consumer-contract suite, 2026-10-19T20:00:36Z).

**Software:** calcofi4db 4.26.0, calcofi4r 1.28.0.

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.10.19 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://doi.org/10.5281/zenodo.23484176

Cite the source datasets you use alongside the release:

- `calcofi_2022-edna` — Patin N, ODonnell G (2026). CalCOFI October 2022 Vertebrate eDNA. Version 1.2. Occurrence dataset. https://doi.org/10.15468/n52j6r
 · CC-BY-4.0
- `calcofi_bottle` — CalCOFI. (2023). CalCOFI Bottle Database 194903-202105. CalCOFI.org. · *license pending*
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
- `farallon_bird-mammal` — *citation pending* · custom (https://oceanview.pfeg.noaa.gov/CalCOFI/app/resources/docs/Data_Sharing_Agreement_FarallonInstitute.pdf)
- `sio_mesopelagic-fish` — Koslow, J. Anthony (2016). CalCOFI Trawl Data. In California Cooperative Oceanic Fisheries Investigations (CalCOFI): Acoustic and Trawl Data. UC San Diego Library Digital Collections. https://doi.org/10.6075/J0BZ64DH
 · CC-BY-4.0
- `sio_pic-zooplankton` — *citation pending* · *license pending*
- `swfsc_cufes` — *citation pending* · custom (https://coastwatch.pfeg.noaa.gov/erddap/tabledap/erdCalCOFIcufes.das)
- `swfsc_ichthyo` — NOAA Fisheries SWFSC. CalCOFI Ichthyoplankton Database. · *license pending*

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.10.19")
```
```python
con = calcofi4py.cc_get_db("v2026.10.19")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.10.19/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
