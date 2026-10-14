# CalCOFI integrated database release v2026.10.13

**Release date:** 2026-10-13 · **promoted** (`latest.txt`)

## CalCOFI 2607 (2026-07-3322): the corrected preliminary CTD files

The CTD team re-published `20-2607SH_CTDPrelim.zip` on calcofi.org on 2026-10-12 (Ben Gire). The
Shared Drive copy the pipeline reads was replaced with it the next day. The bins and columns are the
same as before. Diffed per measurement type against the shards v2026.10.08 was cut from, **nothing
outside 2607 changed** (0 of 4,931 `obs` and 0 of 6,093 `obs_ctd_full` cruise × type cells). In 2607:

- **A new CTD quality code, 4**: a corrected chlorophyll-a or nitrate estimate that came out negative
  is now 0 instead of blank. It is registered in `metadata/measurement_qual.csv` as `set_to_zero`, and
  `qual_ok` keeps it: the zero is a real value and counts in averages, integrated chlorophyll and
  anomalies. This fills about 1,000–2,900 bins per estimate (`est_chlorophyll_a_*`,
  `est_nitrate_*`).
- **The nitrate and chlorophyll estimates were recalibrated by the provider**: nitrate by up to
  1.0 µM (`est_nitrate_sta_corr`), chlorophyll by up to 0.003 µg/L.
- **Sensor-2 oxygen** (`oxygen_umol_kg_2_*`) was recalibrated (up to 1.06 µmol/kg), and 2,213 of its
  values were blanked and flagged 9 on the early casts. **The averaged oxygen and temperature are
  unchanged**: the pipeline already used sensor 1 alone on casts 1–6 (`flag_overrides.csv`, from the
  provider's cruise note that the secondary temperature sensor was faulty; question Q37), and
  rebuilds every pair with `combine_sensor_pair_sql()`.
- **`btl_temperature` is new for 2607** (2,396 bins: the provider filled the file's `BTL_Temp`
  column). Two bottles' nutrients moved out of their 1 m bins.
- **Derived products:** `chl_integrated` changed on 72 casts (mean +0.01 mg/m², at most +0.75), and
  `chl_integrated_depth` deepened on 54 casts (mean +5 m, at most +132 m), because the zeros now count
  as good bins instead of ending the integral. The mixed-layer depths, `chl_max_depth`, `spiciness0`
  and `sigma_theta_ave` are unchanged.

## Anomalies for the derived CTD products, and a seasonal baseline

Rasmus Swalethorp asked for both (2026-10-06, 2026-10-07). The `climatology` table (calcofi4db
4.24.0) now carries:

- **Per-cast baselines** for the derived products in `sample_measurement`: the three mixed-layer
  depths (`mld_sigma_theta_002`, `mld_sigma_theta_0125`, `mld_temperature_02`), `chl_max_depth`,
  `chl_max` and `chl_integrated`. They use the same rules (station, cruise month, 1993–2013, at least
  5 cruises). Such a value has no depth, so its row's **`depth_bin` is NULL**. `relationships.json`
  declares that column as `nullable_key_columns`.
- **A seasonal baseline beside the monthly one**: new columns `quarter`, `season_mean`, `season_sd`,
  `season_n`, `season_n_cruises`, by the quarter of the cruise's month (Q1 Jan–Mar … Q4 Oct–Dec).
  They are set on every month of a quarter that has at least 5 cruises. Where only the season passes
  (mostly the northern lines 60–73.3), the row has a seasonal mean and a **NULL `clim_mean`**.

**`obs_env` / `obs_bio` `year` and `quarter` are the cruise's**, not the cast's calendar date. 2607's
inshore 93.3 casts were worked on 30 June and now fall in Q3 with the rest of the July cruise, the
same season their baseline is filed under.

**Consumers:** a row that exists is no longer always a monthly baseline. Test `clim_mean IS NOT NULL`
before subtracting. A per-bin join on `depth_bin = <n>` never matches a per-cast cell. Columns were
appended, never renamed.

## The US EEZ, territorial sea and contiguous zone are areas you can filter by

`sample_spatial` had no memberships for the three US maritime zones, because the NOAA limits they
were drawn from are lines (workflows#169). They are now polygons of the Pacific coast from the Marine
Regions Maritime Boundaries Geodatabase (Flanders Marine Institute; EEZ v12, 12 NM and 24 NM v4;
CC BY 4.0), so the Explorer's Area filter and Regions lens can use them. The layer ids and names are
unchanged: `200NM EEZ` (0–200 NM), `12NM Territorial Sea` (0–12 NM) and `24NM Contiguous Zone`, the
band from 12 to 24 NM. All three are named `Pacific Coast`.

## Seabird and marine mammal surveys of July 2021 and August 2022 now have their cruise

`farallon_bird-mammal` matches each survey to the CalCOFI cruise its observers rode by the stations
occupied the same day. The track was the ichthyoplankton tows alone, so the two surveys on cruises
without a tow, `CAC2021_7` (`2021-07-33P4`) and `CAC2022_8` (`2022-08-39C2`), had a NULL
`cruise_key` (workflows#74). The track now includes the CTD casts. `Fronts_0711`, a CCE-LTER process
cruise with no CalCOFI cruise, stays NULL. `CAC2021_7`'s 466 transects carry no observations in the
source (question Q11, also open for January 2021 and October 2022), so 2021-07-33P4 is a third
farallon cruise with effort and no sightings.

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
| `sample_spatial` | 1,387,517 |  |
| `ship` | 49 |  |
| `spatial` | 3,122 |  |
| `spatial_attribute` | 36,261 |  |
| `taxon` | 2,606 |  |
| `taxon_group` | 438 |  |
| `obs_ctd_full` | 281,888,334 | supplemental |
| `obs_mets_full` | 19,926,523 | supplemental |
| `sample_root` | 419,050 | supplemental |

**25 tables, 374,740,011 rows, 2.74 GB.**

**Datasets (19):** `calcofi_2022-edna`, `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_ctd-derived`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_iron`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 97 pass / 0 fail / 4 skip (consumer-contract suite, 2026-10-14T00:08:13Z).

**Software:** calcofi4db 4.24.0, calcofi4r 1.28.0.

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.10.13 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://calcofi.io/db-schema/?v=v2026.10.13

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
con <- calcofi4r::cc_get_db(version = "v2026.10.13")
```
```python
con = calcofi4py.cc_get_db("v2026.10.13")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.10.13/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
