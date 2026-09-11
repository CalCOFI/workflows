# CalCOFI integrated database release v2026.09.11

**Release date:** 2026-09-11 · **promoted** (`latest.txt`)

## CTD averages rebuilt from their sensors by the provider's flags

The CTD's canonical temperature, salinity and oxygen are the average of a sensor pair, and the
files ship that average pre-computed. It is no longer used where a sensor exists: the ingest
rebuilds every average (`temperature_ave`, `salinity_ave_corr`, `oxygen_ml_l_ave_sta_corr`,
`oxygen_umol_kg_ave_sta_corr`) with the rule Rasmus Swalethorp set on 2026-09-09
(`calcofi4db::combine_sensor_pair()`): a sensor flagged **8** (questionable) or **9** (bad) is
left out, a **1**/**2** selects the primary/secondary, otherwise the mean, one sensor alone when the
other is missing. The CTD team's accepted flags are applied to the sensors first. Until now the
averages were repaired by physical bounds alone, which let a flagged sensor into the mean whenever
its value was possible (1,425 temperature and 6,001 salinity averages in v2026.09.10) and could not
see failures with no flag at all: on 1998-07-32NM and 2024-01-33UD `SaltAve_Corr` was exactly half
of sensor 1 (≈ 17 PSU down to 1,041 m) and `TempAve` wrong by up to 10 °C, and on 17 casts of
2003-04-31JD `TempAve` read 35–40 °C at 1–2 m beside a sensor reading 12–14 °C.

Predicted against v2026.09.10 (dry run, 2026-09-11; the ingest's own counts replace these): temperature
34,923 averages changed, 238 filled, 1,434 removed (both sensors flagged); salinity 39,276 / 811 / 1,141;
oxygen (ml/L) 2,656,233 changed — where the second corrected sensor is empty the file's average differed
from sensor 1 by 0.1–0.4 ml/L — 1,135,319 filled, 5,866 removed; oxygen (µmol/kg) 4,274 changed and
3,529,141 filled where the file shipped no average. The corrected sensor series (`salinity_{1,2}_corr`,
`oxygen_*_{sta,cruise}_corr`, `est_*`) now carry their sensor's flag in `measurement_qual`, so a consumer
can apply the same rule; the per-sensor µmol/kg corrected oxygens gain the 0–700 bound, removing about
1,400 values up to 6.4 × 10¹⁰ from `obs_ctd_full`. What remains is single-sensor faults with no flag
(one 2007-11-32NM cast's only corrected salinity sensor reads ≈ 19 PSU from 61 to 509 m; a 36.2 °C bin
at 516 m on 9401_002d) — the CTD team's to flag.

## Bottle: nitrate, chlorophyll-a and phaeopigment bounds; two corrupt salinities removed

`nitrate` declares −1…60 µmol/L, which removes six values of 66–95 µmol/L on 1976-02-31AX that
sit beside 0.6–0.97 µmol/L phosphate in oxygenated water (a seventh, 56.0, is inside the real deep
tail that runs to 52 and stays until question `calcofi_bottle_14` is answered);
`chlorophyll_a` and `phaeopigment` declare floors of −1 and −5 and no ceiling. A bottle whose
temperature is impossible now loses its salinity too: the 9.50 and 21.06 PSU beside the 99.00 °C
and 56.87 °C bottles of 2020-07-33P4 (station 93.3/30), whose temperatures were already removed.

## Registry: `ammonia` is ammonium, and the underway series have categories

`ammonia` (the QC'd bottle series, source column `NH3uM`) carries NERC P01 `AMONZZXX`, the concept
its own pre-QC twin `r_ammonium` already carried, and its description now says ammonium — the
Berthelot method measures ammonium. The 52 `calcofi_mets` measurement types gain a `category`
(Meteorology & Sea State, Physical Oceanography, Productivity & Pigments or Carbonate System), so
their measurement pages stop reading "Measurement ·" with no category.

## `taxa.json` 1.1: `n_present` beside `n_obs`

`taxa.json` 1.1 adds `n_present` beside `n_obs`; `n_obs` counts rows, and CUFES, phytoplankton,
phyllosoma, crab and zoodb rows include zero counts, so the species pages will say *observations*
for `n_present` and *records* for `n_obs`.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `climatology` | 736,916 | partitioned |
| `cruise` | 842 |  |
| `dataset` | 16 |  |
| `dataset_taxon` | 1,917 |  |
| `grid` | 218 |  |
| `lookup` | 26 |  |
| `measurement_type` | 200 |  |
| `obs` | 31,096,758 | deprecated → `obs_bio`, `obs_env` (objects removed in next) |
| `obs_attribute` | 458,184 |  |
| `obs_bio` | 1,258,665 |  |
| `obs_env` | 29,838,093 | partitioned |
| `region` | 4 |  |
| `sample` | 1,469,151 |  |
| `sample_measurement` | 589,603 |  |
| `sample_spatial` | 929,632 |  |
| `ship` | 49 |  |
| `spatial` | 13,206 |  |
| `spatial_attribute` | 148,461 |  |
| `taxon` | 2,614 |  |
| `taxon_group` | 441 |  |
| `obs_ctd_full` | 275,231,999 | supplemental |
| `obs_mets_full` | 19,926,523 | supplemental |
| `sample_root` | 421,450 | supplemental |

**23 tables, 362,124,968 rows, 2.62 GB.**

**Datasets (16):** `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 87 pass / 0 fail / 4 skip (consumer-contract suite, 2026-09-11T20:47:01Z).

**Software:** calcofi4db 4.14.0, calcofi4r 1.24.2.

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.09.11 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://calcofi.io/db-schema/?v=v2026.09.11

Cite the source datasets you use alongside the release:

- `calcofi_bottle` — CalCOFI. (2023). CalCOFI Bottle Database 194903-202105. CalCOFI.org. · *license pending*
- `calcofi_ctd-cast` — CalCOFI. (2023). CalCOFI CTD Cast Files. CalCOFI.org. · *license pending*
- `calcofi_dic` — Keeling, C.D.; Lueker, T.J.; Emanuele, G.; Dickson, A.G.; Martz, T.R.; Wolfe, W.H.; Mau, A. (2025). Discrete profile dissolved inorganic carbon, total alkalinity, water temperature and salinity measurements for CalCOFI (NCEI Accession 0301029). NOAA NCEI. https://doi.org/10.25921/3w9f-jd72 · CC-BY-4.0
- `calcofi_mets` — CalCOFI. Underway (METS) TSG/Meteorology Data. CalCOFI.org. · *license pending*
- `calcofi_phyllosoma` — CalCOFI - Scripps Institution of Oceanography and T. Koslow. 2017. Data pertaining to lobster phyllosoma, Panulirus interruptus, collection methods, locations, identification and staging (1951-2008, months of July and August) ver 4. Environmental Data Initiative. https://doi.org/10.6073/pasta/9e38121ebb26f1b59b7b39b2eff844fa · custom (https://portal.edirepository.org/nis/metadataviewer?packageid=knb-lter-cce.188.4)
- `calcofi_phytoplankton` — CalCOFI - Scripps Institution of Oceanography, California Current Ecosystem LTER, and E. Venrick. 2023. Temporal and spatial changes of the abundance and species composition of phytoplankton in the California Current from samples collected aboard CalCOFI cruises from summer 1996 through 2022. ver 4. Environmental Data Initiative. https://doi.org/10.6073/pasta/60edabfbfd85c623fce05822befaa071 · CC0-1.0 (https://creativecommons.org/publicdomain/zero/1.0/)
- `cce-lter_euphausiids` — Ohman, M.D. 2022. California Current Ecosystem Euphausiid data, Brinton and Townsend Euphausiid Database (BTEDB) ver 1. Environmental Data Initiative. https://doi.org/10.6073/pasta/4a92a0044bcd1523a4f994ece874a57d · custom (https://portal.edirepository.org/nis/metadataviewer?packageid=knb-lter-cce.313.1)
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
con <- calcofi4r::cc_get_db(version = "v2026.09.11")
```
```python
con = calcofi4py.cc_get_db("v2026.09.11")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.09.11/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
