# CalCOFI integrated database release v2026.10.06

**Release date:** 2026-10-06 · **promoted** (`latest.txt`)

## The climatology is filed by the cruise's month, so a cruise that began in June has a July baseline

`climatology` grouped each observation by the calendar month it was taken, and every consumer
matched an anomaly the same way. A cruise sails for two to three weeks and often begins in the last
days of the month before its own: CalCOFI 2607 (`2026-07-3322`) worked line 93.3 from station 26.4
to 45 on 30 June and from 50 outward on 1–2 July, so ctd-transects drew no anomaly inshore of
station 50 ("no baseline for this month"), although 12–14 July cruises of 1993–2013 had sampled
each of those stations (Rasmus Swalethorp, 2026-10-06). The baseline itself was split the same way:
within 1993–2013, 9.9 % of CTD casts (35 cruises) and 9.3 % of bottle samples are dated in another
month than their cruise's (whole cruises designated April were worked mostly in March, and
1999-08-32NM has three samples dated January). Those values were missing from their own season's
baseline and stranded in a month few cruises sample, where most failed the five-cruise floor.

Now the month is the one `cruise_key` designates (`YYYY-MM-NODC`), and the window is tested on
the cruise's year; the event date is used only when the key does not parse
(`calcofi4db::build_climatology()` 4.22.0). Measured on v2026.10.05's `obs_env` for CTD
`temperature_ave`: 21,757 cells become 21,686 (1,385 gained, 1,456 lost, mostly March cells that
held the early days of April cruises); a third of the 20,301 shared cells gain cruises, and their
means move by 0.057 °C on average and by up to 1.75 °C. The share of post-2013 CTD temperature
values with a baseline rises from 83.6 % to 85.8 % (station-corrected chlorophyll 83.8 % → 85.5 %).

**Consumers:** match an anomaly on `substr(cruise_key, 6, 2)`, not `month(datetime)`.
ctd-transects, the Explorer's Sections lens, `calcofi4r::cc_anomaly()` (1.26.0) and the measurement
pages' anomaly series (`build_measurements_catalog()`) do.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `climatology` | 814,392 | partitioned |
| `cruise` | 845 |  |
| `dataset` | 22 |  |
| `dataset_taxon` | 1,982 |  |
| `fish` | 10,796 |  |
| `grid` | 225 |  |
| `grid_crosswalk` | 673 |  |
| `lookup` | 26 |  |
| `measurement_type` | 231 |  |
| `obs` | 33,340,002 | deprecated → `obs_bio`, `obs_env` (objects removed in next) |
| `obs_attribute` | 476,615 |  |
| `obs_bio` | 1,602,659 |  |
| `obs_env` | 31,737,343 | partitioned |
| `region` | 4 |  |
| `sample` | 1,479,442 |  |
| `sample_measurement` | 659,989 |  |
| `sample_spatial` | 945,262 |  |
| `ship` | 49 |  |
| `spatial` | 13,206 |  |
| `spatial_attribute` | 148,461 |  |
| `taxon` | 2,608 |  |
| `taxon_group` | 444 |  |
| `obs_ctd_full` | 281,880,519 | supplemental |
| `obs_mets_full` | 19,926,523 | supplemental |
| `sample_root` | 425,539 | supplemental |

**25 tables, 373,467,857 rows, 2.73 GB.**

**Datasets (22):** `calcofi_2022-edna`, `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_ctd-derived`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_iron`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_cetacean-edna`, `sio_cetacean-sightings`, `sio_cetacean-sonobuoy`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 92 pass / 0 fail / 4 skip (consumer-contract suite, 2026-10-06T13:48:45Z).

**Software:** calcofi4db 4.22.0, calcofi4r 1.26.0.

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.10.06 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://doi.org/10.5281/zenodo.23190178

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
- `sio_cetacean-edna` — *citation pending* · unknown
- `sio_cetacean-sightings` — CalCOFI - Scripps Institution of Oceanography and J. Hildebrand. 2017. Index of visual monitoring, location, species behavior, and identification of cetaceans from CalCOFI cruises in the California Current System, 2005-2015 (ongoing). ver 2. Environmental Data Initiative. https://doi.org/10.6073/pasta/9ee6ca9b4a316708ca3d17ddc92debfb · custom (https://portal.edirepository.org/nis/metadataviewer?packageid=knb-lter-cce.262.2)
- `sio_cetacean-sonobuoy` — *citation pending* · unknown
- `sio_mesopelagic-fish` — Koslow, J. Anthony (2016). CalCOFI Trawl Data. In California Cooperative Oceanic Fisheries Investigations (CalCOFI): Acoustic and Trawl Data. UC San Diego Library Digital Collections. https://doi.org/10.6075/J0BZ64DH
 · CC-BY-4.0
- `sio_pic-zooplankton` — *citation pending* · *license pending*
- `swfsc_cufes` — *citation pending* · custom (https://coastwatch.pfeg.noaa.gov/erddap/tabledap/erdCalCOFIcufes.das)
- `swfsc_ichthyo` — NOAA Fisheries SWFSC. CalCOFI Ichthyoplankton Database. · *license pending*

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.10.06")
```
```python
con = calcofi4py.cc_get_db("v2026.10.06")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.10.06/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
