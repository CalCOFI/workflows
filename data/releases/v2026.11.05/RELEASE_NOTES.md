# CalCOFI integrated database release v2026.11.05

**Release date:** 2026-11-05 · **promoted** (`latest.txt`)

## The fall 2026 cruise reaches the database from the ship: CalCOFI 2611, lines 93.3 and 90, as posted

Rasmus Swalethorp posted `20-2611_CTDCast.zip` to the Shared Drive on 2026-11-04 from the fall
cruise (R/V Sally Ride, `2026-11-33P4`): the bottle-merged 1 m-binned files of the first 11
casts, line 93.3 from station 26.7 to 50 and line 90 from 60 to 80, occupied 31 October to
2 November, so the CTD team can show the new data at its media webinar on 11 November. The file is
a preliminary, bottle-merged drop (`data_stage = preliminary_with_bottle`: temperature, the
corrected salinity and oxygen pair averages, fluorescence-based chlorophyll, the bottle salinity
and oxygen; no nutrients and no corrected nitrate yet), and its name is the one calcofi.org uses
for raw-cast archives, which the ingest never unzips. `ingest_calcofi_ctd-cast.qmd` now classifies
a Shared-Drive-only archive by its contents (an archive whose members are `_CTD_` / `_CTDBTL_`
`NNN-NNN[DU].csv` files is a preliminary drop whatever its name; workflows#247) and reads a cruise
code without its ship suffix from the CSV's `Study` column (`2611SR`). The weekend update (lines
90 and 87) and the later processing stages replace or extend it the same way (ctd-cast Q51 asks
how they will be posted). The CTD-derived products that need only what the file carries (the
mixed-layer depths, the chlorophyll maximum and integral, sigma-theta and spiciness, the hypoxic
boundary depths, the pycnocline and N²) are computed for these casts; the nitracline waits on the
nutrients. 11 casts to 517 m, 24,986 observations of 35 measurement types in `obs_env`, 257 of
them carrying the provider's flag 9; `calcofi_ctd-cast` now holds 9,872 casts with observations
on 143 cruises, the latest at 2026-11-02 09:19 UTC.

## The all-zero cruise-corrected nitrate of 2301, 2304, 2307 and 2411 is flagged questionable

Rasmus Swalethorp decided ctd-cast Q48 (email 2026-11-04): where every value of a cruise's
cruise-corrected nitrate is 0, the deep ones included, the correction is clearly an error, so
`est_nitrate_cruise_corr` on `2023-01-33UD`, `2023-04-3322`, `2023-07-33P4` and `2024-11-33P4`
carries quality code 8 (questionable) from `metadata/calcofi/ctd-cast/flag_overrides.csv`, applied
at the ingest: kept, excluded by default (`qual_ok = FALSE`), and restored when those cruises are
reprocessed with Kraken. 246 rows on 26 casts in `obs_env` (15 / 147 / 55 / 29 by cruise), the
same rows that were released unflagged through v2026.11.04.
The partly-zero cruises 2105, 2111 and 2504 stay as published, and the 2000-10 / 2001-07
cruise-corrected chlorophyll stays in, unflagged (Q49). The station-corrected nitrate is unaffected.

## A new dataset, staged not released: `swfsc_ctd-noaa`, NOAA's additional CTD casts on CalCOFI cruises, 2002–2014

`ingest_swfsc_ctd-noaa.qmd` ingests the NOAA SWFSC ERDDAP table `erdCalCOFINOAAhydros`
(CalCOFI/workflows#84): 886 CTD casts with 27,791 `obs` of temperature, salinity and dissolved oxygen
at standard depths. The source says its oxygen and salinity are mostly uncalibrated, so the values are
filed under calcofi_ctd-cast's uncorrected sensor-1 types (`temperature_1`, `salinity_1`,
`oxygen_ml_l_1`). 349 casts are held out because they are the same casts CalCOFI already publishes
calibrated (a `calcofi_bottle` or `calcofi_ctd-cast` cast at the same station within 6 h; Q01). It is
**held out of the release** (`in_release: false`) pending the provider's answers on suspect values
(Q02) and the citation (Q04).

What ships is registry content only: the `_source_datasets` of `temperature_1`, `salinity_1` and
`oxygen_ml_l_1` now also name `swfsc_ctd-noaa`.
## A new dataset, staged not released: `cce-lter_chl-size-fractionated`, size-fractionated chlorophyll a, 1994–1996

`ingest_cce-lter_chl-size-fractionated.qmd` ingests the CCE-LTER EDI package `knb-lter-cce.249.3`
(Marine Life Research Group, M. Mullin; doi:10.6073/pasta/02183db3ad041992304d26757f1b25f9;
CalCOFI/workflows#84): 422 station occupations on 12 CalCOFI cruises, each a chlorophyll a value
integrated over 0–100 m, total and ≥ 8 µm. The source gives only the cruise and the station, with the
line rounded to a whole number (`087.0` for 86.7), so `station_crosswalk.csv` maps each to its
official station and the time and position come from that station's `calcofi_bottle` cast. It is
**held out of the release** (`in_release: false`) until the provider confirms that cast is the right
one (Q01).

What ships is registry content: `measurement_type` gains `chl_a_int_100m` and
`chl_a_gt8um_int_100m` (mg/m², `valid_min = 0`).
## Seasons are DJF/MAM/JJA/SON and a cruise's month is its median cast date

Through v2026.10.30 every anomaly, the Explorer's season filter and the seasonal baseline keyed
on the month the cruise's `cruise_key` designates (`YYYY-MM`) and on calendar quarters (Q1
Jan–Mar … Q4 Oct–Dec), so June sat in spring with April and a July cruise's 30 June stations
could only be kept together by the key. Rasmus Swalethorp asked (2026-10-16) that the quarters
match the seasons, winter being December–February, and that a cruise's month come from its dates
rather than its ID, which "was established prior to delays, and sometimes being based on the
month that the cruise started and other times which month was mostly covered"; Ben Best proposed
(2026-10-20) the meteorological seasons with **December counting toward the following year's
winter** and the **median cast date** of each cruise as its month, and Rasmus agreed
(2026-10-27). Both are in this release.

`cruise` gains `date_median` (the median datetime of the cruise's root samples), `month_median`,
`season` (`DJF`, `MAM`, `JJA`, `SON`) and `season_year` (the year of that date, plus one for
December, so Dec 2025 + Jan–Feb 2026 is winter 2026), written by
`calcofi4db::add_cruise_median_date()` (4.34.0). The `climatology` is built on `month_median`
(`build_climatology(cruise_tbl = "cruise")`), `obs_env` / `obs_bio` `year` and `quarter` are the
cruise's median year and season, and both append `cruise_month` and `season_year` after `hex7`.
A cruise with no dated sample keeps its key's month. Measured on v2026.10.30: of the 868 cruises
in `cruise` (847 with a dated sample), 59 centre on a month other than their key's (25 on the
month before, 34 on the month after; `1981-02-31JD` on 1 March, `2025-04-3322` on 31 March),
and 12 of those change season under DJF. For the CTD headline temperature (`temperature_ave`) the
monthly baseline keeps 21,684 of 21,690 cells (3 gained, 9 lost; 14,211 cells change their
cruise count, by 0.043 °C on average and 0.9 °C at most) and the share of post-2013 values with a
monthly normal moves from 85.8 % to 83.6 % (a cruise that centres on the month beside its key's
now looks up that month, which is thinner on some lines) while the seasonal normal covers 91.1 %
either way; for bottle `temperature` the monthly cells go from 11,232 to 11,511 (348 gained, 69
lost), the monthly coverage from 76.7 % to 77.0 % and the seasonal from 89.9 % to 91.0 %.

**Consumers:** `quarter` on `climatology`, `obs_env` and `obs_bio` is redefined — 1 = DJF,
2 = MAM, 3 = JJA, 4 = SON (it was 1 = Jan–Mar … 4 = Oct–Dec) — and the `season_*` baseline is
pooled by these seasons; a December cruise's `quarter` is 1 and its `season_year` the year after.
Read a cruise's month from `cruise.month_median` (or `obs_env.cruise_month`), never from
`substr(cruise_key, 6, 2)`. New columns: `cruise.date_median`, `cruise.month_median`,
`cruise.season`, `cruise.season_year`; `obs_env` / `obs_bio` `cruise_month`, `season_year`. The
Explorer, ctd-transects and calcofi4r (`cc_climatology(season = TRUE)`, `cc_anomaly()`,
`cc_cast_anomaly()`) read the new columns from this release on and label the seasons Dec–Feb,
Mar–May, Jun–Aug, Sep–Nov. `test_release.qmd` asserts the `cruise` columns, that a December
cruise is DJF of the following year, that `obs_env`'s `quarter` / `cruise_month` / `season_year`
match its cruise, and that CalCOFI 2607 is still summer.
## July 2009 ship code corrected on the three CCE-LTER CalCOFI bottle datasets (held)

`cce-lter_toc` (621 samples), `cce-lter_poc-pon` (254) and `cce-lter_hplc-pigments-calcofi` (254)
carry the CalCOFI bottle database's cruise id for July 2009, `2009-07-14-C-31M4` (MCARTHUR, out of
service since 2003), and keyed those samples to a derived `2009-07-31M4` beside SWFSC's
`2009-07-33MH` (MCARTHUR II) at the same stations within 24 h, which check 11 of
`check_cruise_key_integrity()` stopped at the 2026-11-04 preview candidates. The registry row in
`metadata/cruise_ship_corrections.csv` that already corrects the bottle, picoplankton and DIC
datasets now lists these three, each ingest calls `correct_cruise_ship()` before keying cruises, and
the samples key to `2009-07-33MH` (toc Q08, poc-pon Q07, hplc Q08). All three stay
`in_release: false`; the correction reaches a release only through their private previews until
their consent questions are answered.

## `sio_cetacean-sightings` (held): every effort segment becomes a path and every sighting is placed at the animal

The second private preview of the Scripps Whale Acoustics Lab's visual sightings (Ben, 2026-11-06,
after the lab's review of the first on 2026-11-05) publishes what the first kept as midpoints and
ship positions. A new core table **`sample_track`** (calcofi4db 4.35.0) holds one row per sample
whose event is a path on the sea surface: each of the 3,165 on-effort segments as an
`effort_segment` (beginning, middle and end in position and time, the lab's `SegmentLength_km` as
`length_km`, a start-to-end `LINESTRING`; its `sample` row keeps the great-circle midpoint as its
point), and for each placed sighting a `sight_line` from the ship's position to the animal's. A
sighting's `sample` point is now the **animal's position**, placed by coordinate geometry
(`cogo_true_bearing()`, `cogo_destination()`) from the ship's position, the lab's angle off the bow
and side, and the radial distance (the binocular-reticle distance or the recorded distance,
whichever reproduces the lab's perpendicular distance): 4,150 of the 4,961 sightings are placed
and 811 stay at the ship's position (no bearing or no distance; `position_method`). Four
`obs_attribute` types join the group-size range and calves on every counted sighting:
`perp_distance` (m, the lab's own, withheld on the 13 sightings where it was computed from the
horizon distance, Q27), `radial_distance` (m), `sighting_angle` (degrees off the bow, the side in
`bin_label`) and `beaufort`; 35,098 attribute rows. The lab's three source files and the
inspection files (segments, placed sightings and sight lines as GeoJSON) are archived to
`gs://calcofi-files-private/archive/sio/cetacean-sightings/` and served beside the preview's
notebook as `src/`. Questions Q16–Q29 are added to the dataset's register (the lab doc of
2026-10-08, the horizon distance, the sightings far from their segment, and the publication of the
geometry). `release_database.qmd` assembles `sample_track` from the shards with the core, checks
its key against `sample`, and exports it with the default set; a public release has the table only
once a dataset with paths is released.

## Farallon's marine mammals are cut on the cruises the SIO cetacean survey covers, once that survey is released

`farallon_bird-mammal` (Farallon Institute's seabird and marine-mammal strip transects) and
`sio_cetacean-sightings` (the Scripps Whale Acoustics Lab's line-transect cetacean survey) ride the
same CalCOFI cruises with independent observer teams, so from the start of the SIO survey a
cetacean group can be logged by both and summing the two datasets counts it twice. Decided
2026-11-06 after the 2026-11-05 meeting with the lab: `ingest_farallon_bird-mammal.qmd` drops
Farallon's marine-mammal observations (species of ERDDAP `type` mammal) on the cruises where the
SIO survey has effort segments, **by whole cruise** (the distinct `cruise_key` of the survey's
`sample_track` paths). Farallon's birds, fish and turtles, its transects (`sample`) and its mammals
on every cruise the survey did not sail are kept. The rule is gated: it applies only when
`sio_cetacean-sightings` is `in_release: true`, so while that dataset is held this release's
Farallon rows are unchanged; `CALCOFI_FARALLON_CUT_COVERED=1` applies the cut for a review render
or a private preview candidate (`scripts/preview_candidate.sh` takes the re-rendered shard through
`CALCOFI_CAND_OVERRIDE`), and the notebook now depends on the sightings ingest. A render with the
flag against the sightings shard of 2026-11-06 (effort on 73 cruises, 2004-07-13 to 2025) cut
2,266 source observation rows on 35 cruises, which is 2,048 `obs` headline rows (69,661 → 67,613)
and 2,266 `obs_attribute` rows (87,813 → 85,547). It kept 3,410 mammal rows: 3,240 on the cruises
before the survey began and 170 on the five cruises since that the survey did not sail
(2005-04-31JD, 2010-04-31FN, 2011-04-3322, the 2011 Fronts cruise with no `cruise_key`, and
2012-08-32I1, the 2012 Fronts cruise). The notebook's table lists every Farallon cruise with marine
mammals that is covered or sailed since the survey began. Asserted at render time: non-mammal rows
are never cut, no mammal on an uncovered cruise is cut, no mammal remains on a covered cruise when
the cut applies, and the row count is unchanged when it does not. A render without the flag staged
`sample` / `obs` / `obs_attribute` with the same content hashes as before.

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
| `obs` | 36,034,877 | deprecated → `obs_bio`, `obs_env` (objects removed in next) |
| `obs_attribute` | 455,300 |  |
| `obs_bio` | 1,586,795 |  |
| `obs_env` | 34,448,082 | partitioned |
| `region` | 4 |  |
| `sample` | 1,467,380 |  |
| `sample_measurement` | 714,892 |  |
| `sample_spatial` | 2,295,877 |  |
| `ship` | 49 |  |
| `spatial` | 3,395 |  |
| `spatial_attribute` | 37,968 |  |
| `taxon` | 2,606 |  |
| `taxon_group` | 438 |  |
| `obs_ctd_full` | 286,495,695 | supplemental |
| `obs_mets_full` | 19,926,523 | supplemental |
| `sample_root` | 419,439 | supplemental |

**26 tables, 385,903,651 rows, 2.90 GB.**

**Datasets (20):** `calcofi_2022-edna`, `calcofi_bottle`, `calcofi_bottle-derived`, `calcofi_ctd-cast`, `calcofi_ctd-derived`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_iron`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 106 pass / 0 fail / 4 skip (consumer-contract suite, 2026-11-06T02:18:13Z).

**Software:** calcofi4db 4.34.0, calcofi4r 1.30.0.

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.11.05 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://doi.org/10.5281/zenodo.23993413

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
con <- calcofi4r::cc_get_db(version = "v2026.11.05")
```
```python
con = calcofi4py.cc_get_db("v2026.11.05")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.11.05/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
