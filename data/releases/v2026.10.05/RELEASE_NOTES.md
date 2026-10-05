# CalCOFI integrated database release v2026.10.05

**Release date:** 2026-10-05 · **promoted** (`latest.txt`)

## The grid is one cell per official station, and a key no longer names the same water

`grid` was 218 Voronoi cells of an idealized lattice (5, 10 and 20 station units in `+proj=calcofi`),
clipped by a coarse coastline and patched by hand: 48 sites lay more than 1 km off their line, 19
cells were in several pieces, and 13 cells held two to four of the official stations, which is
why the climatology moved to `site_key` in v2026.09 (CalCOFI/workflows#130, #86,
CalCOFI/db-viz-station#19). It is now **one cell per official station, beside the previous cells
it keeps**: 225 cells.

- **113 station cells**: the Voronoi tessellation of the official station positions
  (<https://calcofi.org/sampling-info/station-positions/>, the nine SCCOOS inshore stations
  included), confined to the 106 previous cells it replaces, so an outer station's cell stops
  where the previous grid stopped it (line 95.0 in the south, 20 nautical miles beyond line
  93.3). Every official station is the site of its own cell (`grid.geom_ctr`, on its line by
  construction) and no cell holds two.
- **112 kept cells**: the previous cells whose label lies more than 20 nautical miles outside the
  official pattern, with their own boundaries, pieces and keys. No `sample` row whose previous
  cell is kept changes key (0 of 455,930), and historical line 96.7 stays in the line-100 cells.
- Both end at the OpenStreetMap coastline (islets under 1 km² dropped, pulled back 300 m,
  simplified to 100 m) instead of Natural Earth's. The table's columns are unchanged.

Built by `calcofi4r::cc_grid_build()` (calcofi4r's `cc_grid`), with the rules and the evidence in
[`explore_grid_voronoi`](https://calcofi.io/workflows/explore_grid_voronoi.html).

- **Keys.** The form is unchanged (`st{station}-ln{line}`, `_hist` for a kept historical cell);
  a station cell is named for its station, decimals as listed (`st26.7-ln93.3`, `st27.7-ln90`,
  `st26.4-ln93.4`). 29 keys are new and 22 retire. **196 of the previous 218 keys survive as
  names; for the 112 kept cells the name is the same water, for 84 it is an official station's
  cell whose polygon changed**: `st30-ln90` was the cell of four stations and keeps 52% of its
  water.
- **New table `grid_crosswalk`** (`prev_grid_key`, `grid_key`, `overlap_km2`, `prev_frac`,
  `grid_frac`; primary key the pair; `grid_key` → `grid`): every overlapping pair of a previous
  and a current cell, with the overlap area (EPSG:3310) and its share of each. All 218 previous
  keys are in it. Shares are of the whole cell and are not rescaled: 180 previous cells sum to
  one within 1e-6 and 38 fall short by the part of the cell that is land under the finer
  coastline, at most 2.2%. Each kept cell is an identity row (82 of the 112 with a share of
  exactly one).
- **`sample.grid_key` / `obs.grid_key`.** 188,384 of v2026.10.01's 1,469,239 `sample` rows (12.8%)
  have a different `grid_key` in this release, per dataset in the table below; without the 3,255
  NULL keys DIC gains it is 12.6%. On v2026.10.01's positions alone the share was 12.7% (8.2% of
  rows before 1984, 17.2% from 1984), 5.4% to a cell that is not their previous cell renamed; all
  of them inside the official pattern: 34% of the rows in nearshore standard cells, 1% in offshore
  standard ones, none in a kept cell. No row that had a cell loses it, and 5 gain one (2
  `farallon_bird-mammal`, 1 `sio_pic-zooplankton`, 2 `swfsc_cufes`).
- **Assignment is deterministic.** `assign_grid_key()` took `LIMIT 1` with no order, so a position
  on an edge two cells share keyed to either; it is now the key that sorts first, and
  `calcofi4r::cc_grid_key()` is the same rule in R (identical on all 226,762 distinct `sample`
  positions and on every cell vertex).
- **New gates.** `check_grid_key_assignment()` recomputes the cell of every `sample` position and
  stops the release on a key that is not that cell. It is what catches an ingest staged against
  the previous grid: of v2026.10.01's keys, 185,761 name another cell of the new grid and 59,688
  of those are surviving names that pass the foreign-key check. `check_grid_crosswalk()` gates
  the crosswalk. At the re-stage `check_grid_key_assignment()` passes on the staged shards of all
  21 datasets: 0 of 1,479,442 `sample` rows carry a key that is not the cell of their position
  (the 409 `calcofi_phytoplankton` rows are unkeyed by design). It reads the `grid` shard the
  ingests write, which is `cc_grid` (225 of 225 cells equal at 1e-9), not a grid rebuilt from text,
  which puts 91 positions on a shared edge in the other cell.
- **Not single-piece everywhere.** 13 kept cells are in several pieces, as 10 of them already
  were (cells that span the Baja California peninsula): keeping them as they were is what keeps
  every historical key. One station cell, `st53-ln60`, carries 21 km² of Tomales Bay as a
  detached part: that water was in a replaced cell and opens to the sea only through a kept one.
- **Unchanged:** the climatology is keyed on `site_key` and no mean moves; `climatology.grid_key`
  (the station's modal cell) takes a new label on about one row in nine.

**Rows whose `grid_key` changed, per dataset** (`sample`, this release against v2026.10.01):

| dataset | rows (v2026.10.01) | from v2026.10.01's positions | this release |
|---|---:|---:|---:|
| `calcofi_bottle` | 931,015 | 89,194 (9.6%) | 89,194 (9.6%) |
| `swfsc_ichthyo` | 213,122 | 32,659 (15.3%) | 32,034 (15.0%) |
| `sio_pic-zooplankton` | 82,343 | 13,280 (16.1%) | 13,280 (16.1%) |
| `calcofi_mets` | 77,791 | 19,345 (24.9%) | 19,345 (24.9%) |
| `farallon_bird-mammal` | 64,421 | 10,777 (16.7%) | 10,777 (16.7%) |
| `swfsc_cufes` | 49,572 | 9,227 (18.6%) | 9,224 (18.6%) |
| `calcofi_ctd-cast` | 19,330 | 4,791 (24.8%) | 4,791 (24.8%) |
| `cce-lter_picoplankton-bacteria` | 16,017 | 3,375 (21.1%) | 3,375 (21.1%) |
| `cce-lter_euphausiids` | 7,482 | 1,954 (26.1%) | 1,954 (26.1%) |
| `calcofi_dic` | 3,261 | 768 (23.6%) | 3,258 (99.9%) |
| `calcofi_phyllosoma` | 1,859 | 712 (38.3%) | 712 (38.3%) |
| `cce-lter_zooscan` | 1,483 | 300 (20.2%) | 300 (20.2%) |
| `cdfw_dungeness-crab` | 526 | 51 (9.7%) | 51 (9.7%) |
| `cce-lter_zoodb` | 506 | 73 (14.4%) | 73 (14.4%) |
| `calcofi_phytoplankton` | 409 | 0 (ungridded) | 0 (0.0%) |
| `sio_mesopelagic-fish` | 102 | 16 (15.7%) | 16 (15.7%) |
| **all** | 1,469,239 | 186,522 (12.7%) | 188,384 (12.8%) |

"This release" is the count of `sample` rows whose `grid_key` differs from v2026.10.01's on the
same `sample_key` (NULL counts as a value). The middle column is v2026.10.01's own positions keyed
against the new grid (`explore_grid_voronoi`, gate 5). The two agree row for row on 13 of the 16
datasets (`calcofi_phytoplankton`, which has no grid key, included). The three that differ were
re-staged for another reason:

- `swfsc_ichthyo`: the 3,385 rows of the two 1982 cruises leave and 2,521 nets arrive, so the
  count falls on the rows that remain: 32,034 = 8,693 sites + 11,563 tows + 11,778 nets, none
  gaining or losing a key (the leaving rows held 634 of the 32,668 changes recomputed on the final
  grid).
- `swfsc_cufes`: compared on (time, position), because every `sample_key` is rebuilt; 9,224 of the
  9,227, and the other 3 left with the 1,583 samples SWFSC removed.
- `calcofi_dic`: 3,255 of its 3,261 rows had no `grid_key` and now have one (see "DIC: every
  sample with a position carries a `grid_key`"), and 3 of the 6 that had one change with the grid:
  3,258 differ, against 768 on positions alone.

Overall 188,384 against the 186,522 from positions: DIC's fill adds 2,490, and the ichthyo and
CUFES rows that left take away 625 and 3 (net +1,862). Without DIC's NULL fills it is 185,129
(12.6%).

**Consumers:** a `grid_key` stored from an earlier release (a URL, a cache, a per-cell statistic)
must be mapped through `grid_crosswalk`, not matched by name. `grid.station` and `grid.line` are
no longer whole numbers for some cells, and seven lines hold a single station (81.7, 81.8, 85.4,
86.8, 88.5, 91.7, 93.4: six SCCOOS stations and the rosette station 81.8 46.9), so a section
along line 93.3 no longer includes station 93.4 26.4 and code that rounds a line or matches it
within 0.5 picks up 93.4 with 93.3. `grid.geom_ctr` (`lon_ctr` / `lat_ctr` in `grid.geojson`) is
the station, not a centroid. `grid.geojson` grows from 7,474 to 31,660 vertices. `grid.geom` is
still a mix of polygons and multipolygons. `calcofi4r::cc_grid*` change with it (`sta_lin` /
`sta_pos` are doubles; `cc_grid_v1` is the previous grid).

## CTD cruise 2607: the bottle-corrected preliminary file brings corrected salinity, oxygen, chlorophyll and nitrate estimates, bottle values and per-cast products on all 72 casts

v2026.10.01 carried cruise 2026-07-3322 (2607SH) from the corrected *Preliminary CTD* file, with no
bottle merge. This release reads the *Preliminary CTD & Bottle* file: all 144 of the cruise's
`sample` rows go from `data_stage = preliminary_without_bottle` to `preliminary_with_bottle`, and
the cruise goes from 69,617 to 155,693 `obs` rows and from 1,464,396 to 2,356,899 `obs_ctd_full`
rows. What a user gains is the corrected series that file carries: the cruise-corrected,
station-corrected and bottle series arrive (86,138 `obs` and 897,033 `obs_ctd_full` rows added,
2,823 and 44,843 changed, 62 and 4,530 `est_nitrate_cruise_corr` values removed), and all 72 casts
carry the per-cast products (mixed-layer depth 10.1 to 55.1 m, median 16.8 m; `chl_max`,
`chl_max_depth`, `chl_integrated`, `chl_integrated_depth`). The sensor values already published are
unchanged: 3,724 temperature pairs matched on sample and depth differ by at most 0.0000 °C.

Against the cast's own bottles the corrections look sound: salinity agrees to a median 0.0041
(95th percentile 0.023) PSS-78 on the upcast, and station-corrected oxygen to a median 0.050 mL/L
(95th percentile 0.22). Nothing published is outside a physical range.

**Four gaps, recorded in the cruise's first-look checks, come with the provider's file:**

- **No near-surface nitrate estimate below 0 is published.** No `est_nitrate_*` value is 0 or
  negative (0 of 45,063 station-corrected values in the 1 m table), so where the estimate read
  below 0 the profile is missing: 28 of the 60 casts with station-corrected nitrate have no value
  above 10 m, 24 none above 30 m. The gap is depleted water (bottles at 0–30 m read a median 0.05
  µmol/L), not missing water; in a section it is a blank band over the nitracline offshore.
- **Station-corrected nitrate is absent on 12 of the 72 casts**, six of them consecutive on line 90
  (stations 110, 100, 90, 80, 70, 60); the cruise-corrected series is absent on 5.
- **Every pH value is flagged 8 (questionable) by the provider**: 3,724 thinned values go from no
  flag in v2026.10.01 to 8, and all 56,993 in the 1 m table; the values are unchanged.
- **Estimated chlorophyll has holes**: 125 interior 1 m bins are missing on 5 casts, and 5 casts
  that reach 199 m stop short of it; no value is 0 or below. `chl_integrated` sums only the bins
  present, so `chl_integrated_depth` is below 199 m on 23 casts, most of them shallow nearshore
  casts.

**Consumers:** `cc_qual_ok_sql()` now removes every 2607 pH value (all are flagged 8), where it
removed none in v2026.10.01; a nitrate or chlorophyll section of this cruise has the blank bands
described above.

## CTD casts: one copy per file, casts tested by their median position, two stations repaired, pigment floors (#131)

Five defects in `ingest_calcofi_ctd-cast.qmd` found by auditing v2026.10.01 against the provider's
`*_CTDBTL_*` files (CalCOFI/workflows#131).

- **One copy of each file (2204SH).** The archive holds the bottle-merged file twice, `db-csvs/`
  (May 2022) and `csvs-plots/` (February 2025 re-export: nutrients, `BTL_Temp`, 559 more `OxBuM`,
  corrected `Ox*uM_StaCorr`; times to the minute, SPAR/PAR to three figures). Both were read and,
  writing the time differently, both survived dedup: **2,941,303 duplicated keys** in `obs` +
  `obs_ctd_full`. Where a May 2022 scan fell on a whole minute the keys matched and the older copy
  won the tiebreak: 14 bottles lost nutrients, `BTL_Temp` and `OxBuM`, the **92 missing values**.
  Now the re-export alone is read (`CTD_COPY_PREFER`; seven other archives hold byte-identical
  copies and keep the shortest path, as dedup did). The re-export also drops 7 shallow bottles and
  moves one, which leave with the old copy.
- **Distance filter on the cast's median position.** A cast within 10 km of its station keeps every
  scan; a scan more than 0.05 deg from the median (a GPS glitch) keeps its values at the median
  position. A cast whose median fails keeps the old per-scan test. Restores 2404SH's 626 glitch
  scans (11 bottles) and GPS-glitched scans on 0801JD, 0711NH, 0310NH, 1507OC and 10 other cruises.
- **Stations.** 2204SH casts 094/095 write line 066.3 but sit on 063.3 (`CTD_STATION_OVERRIDE`,
  questions.csv Q43); 2504SH cast 045 is a real occupation 11.0 km off 083.3 039.4, kept at its
  true position (`CTD_OFF_STATION_KEEP`).
- **Pigment floors.** `btl_chlorophyll_a` -1 and `btl_phaeopigment` -5, the floors `calcofi_bottle`
  declares; near-zero negative readings return, -99 still falls.
- **Mis-filed upcasts (1604SH, 2105SH).** Direction comes from the Cast_ID; seven upcasts filed in
  the downcast file stop doubling (**75,310 duplicated keys**).
- **Ratchets.** A (cast, depth) read twice stops the render outside `CTD_DUP_SCAN_CRUISES`;
  `CTD_DUP_SCAN_MAX` holds the cruises still open (1501NH `dualTCO/` re-processing, 9510NH /
  9504NH extra casts reusing cast numbers, six with 1-177 scans: 1,951,755 keys) to their count;
  they are tracked in CalCOFI/workflows#134.

**Measured** (`diff_stage_vs_release()` per cruise on the 2026-10-04 re-stage against v2026.10.01;
`obs` 18,843,115 → 18,781,256 rows and `obs_ctd_full` 284,379,888 → 282,680,638; the diff ignores
`grid_key`):

| table | added | removed | changed | duplicated keys |
|---|---:|---:|---:|---:|
| `obs` | 107,725 | 169,584 | 15,706 | 282,256 → 122,662 |
| `obs_ctd_full` | 1,170,385 | 2,869,635 | 366,029 | 4,686,112 → 1,829,093 |

Duplicated keys in the two tables together go from 4,968,368 to 1,951,755. The rules were first run
on the source files of the 39 affected cruises by a mini-pipeline that reproduces v2026.10.01's
`obs` and `obs_ctd_full` row for row under the old rules (`obs` +21,587 / −169,369 / ~12,882;
`obs_ctd_full` +273,352 / −2,863,345 / ~321,217). It excluded two things, and, cell by cell
(cruise × type), every difference from the measurement is one of them:

- **Cruise 2607's new file** (2026-07-3322; see the section on it): `obs` +86,138 / −62 / ~2,823,
  `obs_ctd_full` +897,033 / −4,530 / ~44,843, and all 4,127 (`obs`) and 66,846 (`obs_ctd_full`)
  quality-code changes of the two tables.
- **The depth-constant guard** (next section): `obs` −153 / ~3, `obs_ctd_full` −1,760 / ~31, in
  eight cruise × series cells.

Prediction + 2607 + guard equals the measurement exactly for every added and removed count. The
changed counts are 2 (`obs`) and 62 (`obs_ctd_full`) lower than that sum, all `spar` and `par` on
2022-04-3322; that residual (0.02% of the changed values) is unexplained, and no row added or
removed differs. The duplicated keys fall by exactly what the mini-pipeline gave, 159,594 in `obs`
and 2,857,019 in `obs_ctd_full`; the 1,951,755 that remain are the keys `CTD_DUP_SCAN_MAX` holds
open. Bottle-grain `obs` rows (`btl_*`, `salinity_btl`, `oxygen_btl_*`) equal the prediction
cruise by cruise: 2022-04 +303 / −3,409, 2024-04 +127, 2025-04 +57, 2008-01 +840, 2007-11 +346,
2016-04 −364, 2021-05 −176.

`sample` goes 19,330 → 19,336 (six casts arrive, four on 2022-04-3322 and two on 2025-04-3322; none
leaves); 50 casts differ in position or time (21 of them on 2008-01-31JD); `grid_key` changes on
4,791 of the 19,330.

## CTD: derived series that hold one value at every depth are withheld

A series can be in bounds, unflagged and still not a profile. A census of every ctd-cast downcast
CSV (`libs/census_depth_constant_ctd.R` → `data/qc/ctd_depth_constant_census.csv`; a cast is judged
with at least 6 values over at least 50 m and is constant when its range is below 1e-9) found the
provider's `EstNO3_CruiseCorr` (`est_nitrate_cruise_corr`) is **one value over the whole cast on 441
of 5,066 judged casts (8.7%), across 20 of 76 cruises, and on every judged cast of seven**
(2304SH, 2504SH, 2301RL, 2307SR, 2105SH, 2411SR, 0810NH), while `EstNO3_StaCorr` on the same casts
varies (0 of 4,241). Mostly exact zeros, the rest a per-cast offset (Rasmus Swalethorp's
transect-plotter screenshot of line 93.3 showed vertical stripes). The same shape is in
`Ox1uM_CruiseCorr` (329 casts of 9,837, three cruises), `OxAveuM_StaCorr` (124 of 4,321, three
cruises) and a handful of casts in `EstChl_*` and the other `Ox*_StaCorr` columns (2-8 each);
`Salt*_Corr`, `Ox*_CruiseCorr` (other than `Ox1uM`) and `EstNO3_StaCorr` have none.

`ingest_calcofi_ctd-cast.qmd` now calls `calcofi4db::check_depth_constant_series()` (4.17.3) after
the accepted flags and overrides and before the sensor-pair averages, and **drops** those
(cast, series) values (dropped, not flagged); a sensor-pair average that rested on a withheld
sensor is rebuilt from the other. `questions.csv` Q42 asks the CTD team whether `EstNO3_CruiseCorr`
is a per-cast offset in these files and whether to withhold or recompute it.

**What the render dropped** (the ctd-cast render of 2026-10-04, `data/qc/ctd_depth_constant_dropped.csv`):
eight cruise × series cells on four cruises, every withheld value an exact 0. "Values withheld"
counts every depth of those casts, including values v2026.10.01 never held, so it exceeds what
leaves the release.

| cruise | series | casts | values withheld | removed from `obs_ctd_full` |
|---|---|---:|---:|---:|
| 2015-01-32NM | `est_chlorophyll_a_sta_corr` | 2 | 472 | 115 |
| 2018-10-33P4 | `est_chlorophyll_a_sta_corr` | 3 | 472 | 173 |
| 2018-10-33P4 | `est_nitrate_cruise_corr` | 3 | 536 | 111 |
| 2022-04-3322 | `est_chlorophyll_a_sta_corr` | 3 | 472 | 184 |
| 2022-04-3322 | `oxygen_umol_kg_1_sta_corr` | 4 | 229 | 229 |
| 2022-04-3322 | `oxygen_umol_kg_2_sta_corr` | 5 | 294 | 294 |
| 2022-04-3322 | `oxygen_umol_kg_ave_sta_corr` | 4 | 229 | 229 |
| 2025-04-3322 | `est_nitrate_cruise_corr` | 8 | 536 | 425 |

Against v2026.10.01 that is 1,760 `obs_ctd_full` rows removed (115 + 173 + 111 + 184 + 229 + 294 +
229 + 425) and 153 `obs` rows (16 + 24 + 22 + 27 + 6 + 58); 31 `obs_ctd_full` and 3 `obs` values
change, `oxygen_umol_kg_ave_sta_corr` on 2022-04-3322 rebuilt from the other sensor. The census
above counted 441 casts of `EstNO3_CruiseCorr` alone, across 20 cruises; the cells in the table
are the ones that first render withheld.

In total the corrected guard removes 800,651 `obs_ctd_full` values and 44,054 `obs` values and
changes 7,920 and 619 (the rebuilt averages); 532 and 77 values the first render withheld return.

**Why only 32, and the second test.** The chunk grouped by
`ctd_cast_uuid`, which hashes each scan's time, so a "cast" held one value except in
minute-resolution files, and the 32 cells were stretches of a cast inside one minute. It now
judges `(cruise_key, cast_key, cast_dir)`, one direction of one occupation, with two tests
(calcofi4db: `check_depth_constant_series()` with a composite `cast_col`, and the new
`check_zero_runs()`):

1. **whole cast constant**: >= 6 values over >= 50 m, range below 1e-9, every judged series;
2. **a run of exact zeros within a cast**: >= 6 consecutive zeros over >= 50 m (a step of
   <= 5 m inside a run), the run only, on the bottle-corrected oxygen and salinity. Not on
   estimated nitrate or chlorophyll: their zeros are the estimate clipped at zero where the
   quantity vanishes (nitrate's long zero runs start at the surface, 623 of 700, beside
   ~0.1 µM; chlorophyll's reach the 200 m end of its range below the chlorophyll layer, 1,259 of
   1,480, beside ~0.003 µg/L). Station-corrected oxygen ramps to 0 where its per-cast
   regression fails (2408SR cast 033: sensor 26 µmol/kg at 322 m, 0.0 from 322 to 517 m).

Measured on the re-render of 2026-10-04 (finished 21:33), as rows removed against the staging build
of that afternoon, which carried the 32-cell version. The prediction made from the wrangling
database matched exactly on six series and to within 82 rows on the other three (cruise 2204SH,
whose runs the earlier deletions had split in that database):

| series | test | casts (D + U) | cruises | `obs_ctd_full` | `obs` |
|---|---|---:|---:|---:|---:|
| `est_nitrate_cruise_corr` | whole cast | 864 | 21 | 365,573 | 28,917 |
| `oxygen_umol_kg_1_cruise_corr` | whole cast | 391 | 3 | 180,561 | (not canonical) |
| `est_chlorophyll_a_sta_corr` | whole cast | 8 | 3 | 1,596 | 144 |
| `oxygen_umol_kg_1_sta_corr` | both | 16 + 195 runs | 20 | 36,390 | (not canonical) |
| `oxygen_umol_kg_2_sta_corr` | both | 10 + 210 runs | 20 | 34,147 | (not canonical) |
| `oxygen_ml_l_1_sta_corr` | both | 6 + 40 runs | 19 | 13,099 | 979 |
| `oxygen_ml_l_2_sta_corr` | both | 7 + 48 runs | 16 | 13,407 | 1,189 |
| `oxygen_umol_kg_ave_sta_corr` | rebuilt from its sensors | | | 142,742 (+5,343 changed) | 11,681 (+357 changed) |
| `oxygen_ml_l_ave_sta_corr` | rebuilt from its sensors | | | 13,136 (+2,577 changed) | 1,144 (+262 changed) |

The averages are rebuilt from the sensors that remain, so they follow the sensors: an average
whose sensors are both withheld goes, one with a single sensor left becomes that sensor instead of
its mean with 0 (178 + 42 casts change, by up to 328 µmol/kg / 7.5 mL/L). Downcasts of
`est_nitrate_cruise_corr`: 435 against the census's 441 (the census counts 2105SH's two upcasts
filed in the downcast file and the duplicate copies of 0707, 1701). Every value either test
withholds outside `est_nitrate_cruise_corr` is an exact 0, so no real near-constant profile is
caught. Of the 1,051 values the 2026-10-04 render withheld on 2204SH and 1501NH, the 752 oxygen
values stay withheld (zero runs); the 299 `est_chlorophyll_a_sta_corr` zeros return. ctd-derived:
4 casts lose their four `chl_*` values (all-zero `est_chlorophyll_a_sta_corr`); `sigma_theta_ave`,
spice and the mixed-layer depths rest on temperature and salinity, which neither test touches.

## CTD derived products: the CTD team's mixed-layer depth and chlorophyll-maximum definitions

`calcofi_ctd-derived` now computes its per-cast products by the definitions Rasmus Swalethorp gave on
2026-09-23 (questions.csv Q01, Q02; adopted 2026-10-01; CalCOFI/workflows#101, #102). v2026.10.01
shipped interim choices, so **the headline mixed-layer depth changes on every cast that
has one, and `chl_max` and `chl_integrated` on nearly every one** (8,792 of 9,008 and 8,897 of
8,921 casts); the table below has every type.

- **Mixed-layer depth: a new headline key, `mld_sigma_theta_002`.** It is the depth at which
  sigma-theta is 0.02 kg m⁻³ greater than at 10 m, the CalCOFI legacy definition. The interim
  headline **`mld_sigma_theta_003` (Δσθ 0.03) is retired**: its registry row stays, marked
  `RETIRED` with `is_canonical = FALSE`, and no row carries it. The key is new rather than reused
  because the old name states its 0.03 threshold. A consumer that asked for
  `mld_sigma_theta_003` by name must switch; the Explorer reads its per-cast list from the registry
  and needs no change. `mld_sigma_theta_0125` and `mld_temperature_02` are unchanged, now described
  as alternatives to the headline. A cast that starts below 10 m, or never crosses the threshold,
  still has no value.
- **`chl_max_depth` / `chl_max`** (same keys) are the depth and value of the highest **3 m running
  mean** of `est_chlorophyll_a_sta_corr`. v2026.10.01 used a 5 m running median. `chl_max` is now
  the mean at that depth.
- **`chl_integrated`** (same key) is the **sum of the 1 m bins** over the top 200 m, or to the
  bottom on shallower casts. v2026.10.01 integrated with trapezoids, so values move slightly.
  `chl_integrated_depth` is unchanged.
- **Registry fix:** the nine `calcofi_ctd-derived` types (`spiciness0`, `sigma_theta_ave`, the MLD
  and chlorophyll types) listed `calcofi_ctd-cast` as their `_source_datasets`. They now name the
  dataset that publishes them, `calcofi_ctd-derived`.
- **`measurements.json` lists the per-cast types.** The mixed-layer depths, `chl_max_depth`,
  `chl_max`, `chl_integrated` and `chl_integrated_depth` each get an entry with `grain: "sample"`,
  so calcofi.io can give them a page. `counts.sample_measurement_rows` counts their rows.
- **Correction to v2026.10.01's notes:** that section listed `ctd_geostrophic` as a new table, but
  `release_database.qmd` did not publish it, and it is not in this release either. It is still
  computed and staged, pending questions Q03/Q04 (CalCOFI/workflows#103). `datasets.json` no longer
  lists it among the dataset's tables.

**Per-type change against v2026.10.01** (`diff_stage_vs_release()` on the 2026-10-04 re-stage; casts
= casts with a value, changed = the same cast with a different value, largest change in the type's
unit):

| measurement_type | casts v2026.10.01 | casts now | changed | largest change |
|---|---:|---:|---|---:|
| `mld_sigma_theta_002` (new; vs `mld_sigma_theta_003`) | 0 (9,078 had `_003`) | 9,180 | all 9,078 casts that had a `_003` differ from it (median 0.73 m) | 79.0 m |
| `mld_sigma_theta_003` (retired) | 9,078 | 0 | — | — |
| `chl_max_depth` | 9,008 | 9,083 | 5,649 | 88 m |
| `chl_max` | 9,008 | 9,083 | 8,792 | 35.0 |
| `chl_integrated` | 8,921 | 9,000 | 8,897 | 24.7 |
| `chl_integrated_depth` | 8,921 | 9,000 | 8 | 64 m |
| `mld_sigma_theta_0125` | 8,921 | 8,997 | 12 | 27.0 m |
| `mld_temperature_02` | 9,419 | 9,423 | 12 | 19.8 m |

Casts gain a value (79 `chl_integrated` and `chl_integrated_depth`, 75 `chl_max` and
`chl_max_depth`, 76 `mld_sigma_theta_0125`, 4 `mld_temperature_02`, 9,180 `mld_sigma_theta_002`);
no value of those types is removed or blanked. The `obs` series `sigma_theta_ave` goes 663,106 →
668,279 rows (+5,550, −377, none changed) and `spiciness0` 663,077 → 668,250 (+5,550, −377, 19
changed by at most 1.7e-5).

## CTD casts: two provider questions on bottle values after 2021-05

`calcofi_bottle` ends 2021-05-13, where the provider's bottle database ends; later bottle values
reach the release only as the `btl_*` types on `calcofi_ctd-cast`, from preliminary CTD + bottle
files and with no quality code (the source files carry no flag column for any bottle value).
Two `proposed` questions go to the provider (`metadata/calcofi/ctd-cast/questions.csv` Q40, Q41):
whether `btl_*` values are equivalent to the bottle database for 2021 onward, and whether a bottle
database later than 2021-05 is available or scheduled. No data changes.

## Ichthyoplankton: cruises 198202JD and 198212JD leave (swfsc_ichthyo_09)

SWFSC (Ed Weber, 2026-09-25) moved cruises **198202JD** and **198212JD** (`1982-02-31JD`,
`1982-12-31JD`) back to its staging schema: they were sorted for anchovy only, so every other taxon
read as a zero catch. The 2026-09-26 source export no longer contains them, so the re-stage drops
them: 1,128 `site` (61,104 → 59,976), 1,112 `tow` (75,506 → 74,394) and 1,145 `net` `sample` rows; 1,100 `obs` rows (all `abundance`:
1,055 on 1982-02, 45 on 1982-12); 1,054 `stage` and 1,308 `body_length` `obs_attribute` rows; and
1,145 each of `std_haul_factor`, `prop_sorted` and `volume_sampled` `sample_measurement` rows.
`swfsc_ichthyo` `obs` goes 482,250 → 481,150 on these cruises alone (487,616 with the nets added
in the next section). All of these counts equal the 2026-10-04 re-stage's. The ingest now asserts both cruises are absent from
what it loads. **Zero handling is unchanged:** a tow with no row for a taxon is a true zero and stays
in the denominator (the provider: "the others are true zeros and have valid positive zooplankton
volumes"). Both cruises leave `cruise`. One consequence reaches another dataset (see "Euphausiids: 40 tows of
February 1982 have no `cruise_key`").

## Ichthyoplankton: the source is SWFSC's 2026-09-26 export; v2026.09.11 to v2026.10.01 carried the 2026-09-04 ingest

From v2026.09.11 to v2026.10.01 every release shipped the `swfsc_ichthyo` shard staged on
2026-09-04, and its `grid` from 2026-06-07. Each provider export after that changed the source's
shape (first `ShipLookup.ShipIces`, then the 2026-09-26 export's TitleCase tables), the ingest's
integrity check stopped the notebook, and the halt was silent: the render exited 0 and the
pipeline recorded the ingest as built. The check now fails the render (calcofi4db, development
version), and the ingest reads the 2026-09-26 export. What changes for a user, measured against
v2026.10.01:

- **The two 1982 staging cruises leave**, exactly as in the section above (1,128 sites, 1,112
  tows, 1,145 nets; 1,100 `obs`; 1,054 egg `stage` and 1,308 `body_length` rows).
- **2,521 nets are added** to existing tows (2,470 port-side nets of bongo tows, 48 starboard, 3
  unsided; on 47 cruises 1977-12 to 2013-04, 1,229 of them in 1977-12 to 1978-08), with their effort (2,521 each of
  `volume_sampled`, `std_haul_factor`, `prop_sorted`; 23 more of each plankton biomass) and their
  catch: 6,469 `obs` rows (297 egg, 5,767 larva, 405 invertebrate; 6,491 before the pairs below are
  summed), 765 `body_length` and 10 larva `stage` rows. No site or tow is added: the nets lie on
  2,494 existing tows.
- **32 larval counts are corrected** by the provider (e.g. one net's northern anchovy 178 → 225),
  2 `body_length` and 8 larva `stage` counts change, and 1 larva `stage` row is added on an existing
  net.
- **629 larval `stage` rows leave** (tally 29,498, on 69 cruises 1984-01 to 2019-04): the export
  replaced `larvaesize` + `larvaestage` with one `LarvaeMeasured` table, and these (net, species)
  pairs have measured larvae but none with a stage. Asked: `swfsc_ichthyo_18`. 974 measured rows
  (tally 2,320, lengths only) name no larva count row and cannot be placed: flagged, not released
  (`swfsc_ichthyo_17`).
- **Egg stages 12-15 leave** (`swfsc_ichthyo_02`; Ben Best, 2026-10-01): v2026.10.01 published 790
  egg `stage` rows (2,029 eggs) on a scale that ends at 11; the 2026-09-26 export holds 669 (1,756
  eggs), now screened out and listed in `data/flagged/egg_stage_12_15_screened.csv`. They are not
  only Dover and Rex sole: 1,238 of the eggs are northern anchovy and 400 Pacific sardine at stage
  12 (asked: `swfsc_ichthyo_22`). Egg abundance totals are unchanged.
- **Counts are summed by AphiaID** (`swfsc_ichthyo_04`/`_05`/`_13`; "aggregate by AphiaID", Bill's
  taxonomy stands): 31 species codes share 13 `taxon_key`s (e.g. 683 *Sebastes* and 3023 *S.
  crocotulus*; 788 *S. leptorhynchus* and 792 *S. californiensis*, which the source gives one
  AphiaID). Where two of them were counted in one net their rows are now one: 25 such pairs (22 of
  them on the new nets), so `obs` has no duplicated (sample, taxon, life stage) any more
  (v2026.10.01 had 3). The final count is 482,250 − 1,100 + 6,491 − 25 = 487,616. Every code keeps
  its own `dataset_taxon` row and verbatim name; **no `taxon_key` changes**. `ds_source_json` now
  holds the AphiaID the source gave: 11 codes whose AphiaID WoRMS has superseded (e.g.
  *Myctophum lychnobium* 272723 → key `worms:1888085` *Dasyscopelus lychnobius*) used to show the
  accepted id there.
- **`depth_max_m` of every ichthyo tow and net is `Net.NetDepth`**, the maximum possible depth of
  the net, nominal (`swfsc_ichthyo_08`/`_19`): 61,625 of 74,394 tows and 65,128 of 77,888 nets
  (Manta surface tows have none); `obs_bio`'s fallback depth for ichthyo follows. Where the sea
  floor is shallower the net did not reach it: 210 stations; the release counts these apart from
  depth errors, with their own ratchet (210).
- **New: `fish`**, SWFSC's Fish table (fish grown past the larval stage): 10,796 rows, 18,789 fish
  on 7,179 nets, 240 species codes, keyed (`sample_key`, `species_id`) with `taxon_key`. Not in
  `obs` until its life stage and overlap with the larval count are known (`swfsc_ichthyo_20`).
- **New: `ship_ices`** on `ship` and `cruise`, beside `ship_nodc` (`swfsc_ichthyo_14`). Keys are
  unchanged (`cruise_key` stays YYYY-MM-NODC); the codes differ for one ship, FROSTI (NODC OIFS,
  ICES 18DN).
- `swfsc_ichthyo` `obs` goes 482,250 → 487,616; `obs_attribute` `body_length` 241,871 → 241,328,
  `stage` 128,107 → 125,766; `sample` 213,122 → 212,258; `cruise` 691 → 694 rows (the two 1982
  cruises leave; 1998-03, 1998-05 and 1998-06 JD and 2017-07 and 2018-07 Lasker arrive without
  stations: they are CUFES-only cruises, `Cufes.CruiseId` names them).
- **`grid` is the rebuilt 225-cell grid** (identical to `calcofi4r::cc_grid` 1.25.0, see the grid
  section above): with it 8,693 ichthyo sites (11,563 tows, 11,778 nets) change `grid_key`; none
  gains or loses one. 2,084 sites off the grid (ETP and elsewhere, `swfsc_ichthyo_07`) are kept
  with a NULL `grid_key`.
- **Zero catches are true zeros** (`swfsc_ichthyo_09`): 6,302 of 74,394 tows caught nothing and stay
  as samples with their effort; every one with a net has a positive volume. Net effort is SWFSC's
  own (the standard haul factor is not recomputed) and none is missing.
- **Measured at the 2026-10-04 re-stage** (`swfsc_ichthyo` re-staged from the 2026-09-26 export;
  the figures a reply to SWFSC can quote). The counts above agree with the stage, except the
  6,491 → 6,469 new-net `obs` rows, which the summed pairs explain. `sample` 213,122 → 212,258
  (`net` 76,512 → 77,888: 2,521 added to 2,494 existing tows on 47 cruises 1977-12-31JD to
  2013-04-3322, 1,145 leaving with the 1982 cruises; 0 sites or tows added). No `taxon_key`
  changes. `body_length` 241,871 → 241,328 (+765, −1,308, 2 changed); `stage` 128,107 → 125,766
  (larva +11, −629 with a tally of 29,498, 8 changed; egg −1,723 = 1,054 on the 1982 cruises + 669
  at stages 12–15, tally 1,756 eggs, none left at stage 12 or above); `sample_measurement`
  320,110 → 324,284. 9 of the 6,302 zero-catch tows have no net record, and every net of the
  others has a positive `volume_sampled` (as do all 77,888 nets). The 2,084 off-grid sites (2,720
  tows, 2,720 nets) all have a position. `fish` carries a `taxon_key` on every row. `grid_key`
  changes on 8,693 sites, 11,563 tows and 11,778 nets (32,034), none gained or lost; 1998-03,
  1998-05, 1998-06 JD, 2017-07 and 2018-07 arrive in `cruise` (694 rows).
- **Not ingested**: `Cufes` (another change repoints `ingest_swfsc_cufes.qmd` at it),
  `SpeciesItisLookup`, `SpeciesWormsLookup` (used to check the keys,
  `data/flagged/species_worms_lookup_check.csv`), `PreservativeLookup`, and `Station`
  arrival/departure times, bottom depth and bucket temperature.

## CUFES: the source is SWFSC's own export, and eggs per m³ are published

`swfsc_cufes` was read from NOAA CoastWatch ERDDAP (`erdCalCOFIcufes`). It now reads `Cufes.csv`
from SWFSC's CSV export of its CalCOFI database (2026-09-26, Ed Weber), where each sample carries
its `CufesId` and the `CruiseId` of its cruise. Record by record, the export holds 47,989 of
ERDDAP's 49,572 samples. Where both have a sample, its times and egg counts are identical, and its
positions and environment differ by no more than float rounding (≤ 1.5e-5). Both run from
1996-03-15 to 2022-04-27. Measured against v2026.10.01:

- **1,583 samples leave** (9,016 `abundance` rows; 18,218 eggs, 15,252 of them "other fish").
  1,563 have no position at either end, and SWFSC removed them at source (`swfsc_cufes_04`).
  They include all of cruises 1998-09, 1999-08 and 2000-01 New Horizon. The other 20 have a stop
  position only, and v2026.10.01 placed them there (asked: `swfsc_cufes_09`). Every remaining
  sample has a position.
- **A new measurement type, `egg_concentration`** (count/m³; 275,081 rows on all 47,989 samples,
  one per egg count, same taxon and `life_stage = egg`). It is Ed Weber's standardization
  (`swfsc_cufes_01`): eggs/m³ = (count / minutes sampled) / mean pump speed, with minutes =
  stop − start and the pump speed in m³/min (`swfsc_cufes_02`). It is computed only where the
  minutes and both pump speeds are positive, which every sample of this export is. The raw
  counts still publish as `abundance` (count), unchanged. One sample's stop pump speed reads
  40 m³/min (others 0.27–1.07), which makes its concentration about 30 times too low. It is
  published as shipped and asked about (`swfsc_cufes_10`).
- **Every sample has a `cruise_key`**, taken from the provider's `CruiseId` through
  `cruise.cruise_uuid`. Before, 5,053 had none, and 6,212 keys change: 5,049 are filled (on
  2017-07 and 2018-07 Lasker, 1998-03/05/06 and 1997-03 Jordan, and others). 1,163 move to the
  cruise SWFSC designates: 743 from 1998-02-31JD to 1998-03-31JD, and 420 from 1996-04-31JD to
  1996-03-31JD. The date-span rule (`resolve_cruise_key()`, span then the source's `Cruise`)
  gives the same key on all 47,989.
- **`sample_key` is built from `CufesId`** (`swfsc_cufes:underway:<CufesId>`, previously the
  ERDDAP row number), and `CufesId` is released as `sample.source_uuid`, as ichthyo's UUIDs are.
  Every CUFES `sample_key` changes.
- `grid_key`: 9,224 samples change cell. All of them come from the rebuilt 225-cell grid (section
  above), none from the new source. 754 samples (9,048 `obs` rows) lie outside the grid, against
  2,319 in v2026.10.01, most of which had no position at all.
- `swfsc_cufes` `sample` goes 49,572 → 47,989. `obs` goes 284,097 → 550,162 (`abundance`
  275,081 + `egg_concentration` 275,081). Taxa are unchanged: the six keys, now checked against
  SWFSC's `Species.csv` AphiaIDs. The underway temperature, salinity, wind and pump speed are
  still not published, as before.

Measured at the 2026-10-04 re-stage, comparing on datetime and position because every `sample_key`
changes (136 datetimes repeat, the position separates them): all 47,989 samples pair one to one
with v2026.10.01's on the same datetime and a position within 1e-4 degree, and none is added.
The 275,081 `abundance` rows that remain equal their v2026.10.01 values (0 changed); 206,893 of the
275,081 `egg_concentration` rows are 0, from zero counts, and the largest is 870.5 eggs m⁻³. Of
the 9,224 samples that change cell, 2 had none before.

## Three cetacean datasets: sightings, sonobuoy and eDNA (licence pending; provider asked)

`sio_cetacean-sightings`, `sio_cetacean-sonobuoy` and `sio_cetacean-edna` ship for the first time,
staged from CalCOFI/marmam-app at commit `7bc0e18` (CalCOFI/workflows#117). They ship **without a
settled licence or citation**: nothing is invented, the gap is recorded and the provider is asked
(`questions.csv` Q01/Q02 of each; sightings carries the EDI knb-lter-cce.262.2 terms and citation as
`custom`, sonobuoy and eDNA say `license: unknown` with an empty citation). `funding` is blank on all
three: the ONR award marmam-app names (N00014-22-1-2719, FY22) cannot have funded 2004-2012 data, and
the provider is asked what did.

- **`sio_cetacean-sightings`**: visual line-transect sightings and effort, quarterly cruises 2004-2022
  (effort through 2021, so 2022 sightings have no effort to normalise against, Q07). Staged shard: 8,087
  `sample` (1,980 `transect` effort segments + 6,107 `sighting`), 6,097 `obs` (`group_size`, one per
  counted sighting; the 10 sightings with a Best of 0 or blank keep their sample and publish no obs),
  1,980 `sample_measurement` (`transect_length`) and 19,086 `obs_attribute` rows (effort status, group
  size min/max, calf count). **Behaviour is held back**: the codes are bare numbers with no codebook, in
  the same `behavior` type that `farallon_bird-mammal` fills with words, so the 10,108 behaviour rows
  the staged shard carried are not published until the lab supplies the codebook (Q03). 67 cruises,
  all with a `cruise_key`. It leaves the catalog's holdings and enters as a released dataset.
- **`sio_cetacean-sonobuoy`**: hourly presence of blue, fin and humpback whale calls in sonobuoy
  recordings, 2004-2012. Staged shard: 4,206 `sample` (962 `deployment` + 3,244 `scan`, one analysed
  hour), 9,270 `obs` (`acoustic_presence`, 1,978 of them 1) and 2,229 `obs_attribute` (`call_type`);
  35 cruises, every hour with a `cruise_key`. The hydrophone depth is not recorded, so depth is NULL
  on every sample and obs, **not 0 m**. The 154 hours scanned only "adhoc" keep their sample and publish
  no presence value.
- **`sio_cetacean-edna`**: NCOG seawater eDNA screened for seven cetaceans, 2014-2016. Staged shard: 133
  `sample` (`water`, one per sample, each timed by its CalCOFI bottle cast) and 497 `obs`
  (`edna_presence`, 71 sequenced samples x 7 species, 15 detections). The 62 samples listed as "not
  sequenced, PCR negative" did not amplify: they stay as samples with **no** `edna_presence` rows, not
  zeros, until the provider says what a PCR negative means (Q04). `parent_sample_key` is NULL (every
  sample is a root).

What else changes for consumers:

- **`sample_type` gains `sighting`, `deployment`, `scan` (and `water`, `filter` with the eDNA datasets).**
- **`measurement_type` gains `acoustic_presence`, `calf_count`, `call_type`, `edna_presence`,
  `effort_status`, `group_size`, `group_size_max`, `group_size_min` and `transect_length`.**
  `behavior`'s `_source_datasets` names only `farallon_bird-mammal`: `sio_cetacean-sightings` publishes no behaviour row until its codebook arrives (Q03). `edna_presence` is emitted differently by the two eDNA datasets (see the `calcofi_2022-edna` section).
- **Counts pool across observer teams**: `sio_cetacean-sightings` and `farallon_bird-mammal` count
  cetaceans on the same cruises with independent observers, so summing the two counts some animals
  twice (both descriptions say so).
- `check_taxon_registries()` skips `taxon_override.csv` rows only for datasets held out of a release
  (`exclude = ds_excluded`, calcofi4db 4.17.2); these datasets are no longer among them.

Measured at the 2026-10-04 re-stage: `sio_cetacean-sightings` 8,087 `sample` (6,107 `sighting`, 1,980
`transect`), 6,097 `obs`, 19,086 `obs_attribute` (`calf_count` 3,159, `effort_status` 5,755,
`group_size_max` 5,091, `group_size_min` 5,081; no `behavior`) and 1,980 `sample_measurement`;
`sio_cetacean-sonobuoy` 4,206 `sample` (962 `deployment`, 3,244 `scan`), 9,270 `obs` (1,978 present),
2,229 `obs_attribute`, with depth NULL on every sample and `obs`; `sio_cetacean-edna` 133 `sample`
and 497 `obs` (15 detections).

## A new dataset: `calcofi_2022-edna`, vertebrate eDNA from the October 2022 cruise (detections only)

`ingest_calcofi_2022-edna.qmd` ingests the GBIF/OBIS Darwin Core Archive "CalCOFI October 2022
Vertebrate eDNA" (Patin and O'Donnell, version 1.2, doi:10.15468/n52j6r, CC BY 4.0; linked to Patin
et al. 2026): 47 water filters (`sample_type = 'filter'`, one per `parentEventID`) from CalCOFI/GEMCAP
stations on cruise 2022-10-33UD, 2022-10-13 to 2022-10-18, each run through a mitochondrial D-loop
assay (cetaceans) and/or a 12S rRNA MiFish assay (fish). Staged shard: 47 `sample`, 148 `obs`
(74 `edna_presence`, 51 `edna_reads_dloop`, 23 `edna_reads_12s`; 19 taxa) and 482
`sample_measurement` (co-collected nutrients, chlorophyll fluorescence, oxygen in mg/L, DNA
concentration, and the per-assay raw and filtered read totals).

**Detections only.** The source archive holds positive detections only, so the dataset publishes
`edna_presence = 1` and the read counts, and **the absence of a row is not a non-detection** here
(unlike `sio_cetacean-edna`, where 0 means not detected in a sequenced sample). Whether filters or
assay runs with no detection were omitted is asked of the provider (Q08, `high`, no longer a
blocker). Reads are a semi-quantitative signal of PCR-amplified DNA, not abundance, and are not
comparable between assays. Not yet linked: `site_key` and `parent_sample_key` are NULL on every
filter (CalCOFI/workflows#125). The shared `measurement_type` registry gains `edna_reads_dloop`,
`edna_reads_12s`, `edna_reads_raw_*`, `edna_reads_filtered_*`, `oxygen_mg_l` and
`dna_concentration`. `chl_fluor`, which `calcofi_mets` shares, gets a floor of its own (see the
section on it below).

Measured at the 2026-10-04 re-stage: 47 `sample` (`grid_key` and `cruise_key` on all 47, `site_key`
on none), 148 `obs` (74 `edna_presence`, all 1; 51 `edna_reads_dloop`; 23 `edna_reads_12s`) and 482
`sample_measurement` over 12 types.

## A new dataset: `cce-lter_iron`, dissolved iron on CalCOFI cruises, 2002–2004

`ingest_cce-lter_iron.qmd` ingests the CCE-LTER EDI package `knb-lter-cce.21.3` (Barbeau,
doi:10.6073/pasta/63c4e57f87861db3acaf80d1dec103e1), fetched and md5-pinned by
`libs/download_iron.R` (CalCOFI/workflows#82). With no cast or bottle number in the source, it
mints its own `sample` arm (170 surface pole samples, Nov 2002 – Jul 2004, keyed
`cce-lter_iron:bottle:{study_name}-{index_number}` from the source's own unique pair, not row
position) and publishes 170 `obs` rows in the env realm of one new measurement type,
`dissolved_iron` (nmol/L; the file header says "nM/L", confirmation pending, Q04).

**Held out, on purpose.** `chl_response_to_fe` (the iron-addition bioassay response) is **not**
released until the provider answers Q01 (is it a unitless treatment:control ratio, a concentration
or a code? its EML scale is `nominal`); Q01 stays `open` with priority `blocker`. `total_iron` is
not registered because the revision has no real value (170 of 170 rows are the `-999` sentinel).
Neither has a row in `measurement_type`, so neither appears in the measurements catalog.

The source's undocumented `-999` sentinel becomes NULL (Q06), and `Datetime PST` is read as a fixed
UTC−8 offset pending the provider's answer to Q02. The license is the package's own free-text
rights statement (`custom`), not a CC grant. Open provider questions: Q01, Q04 (units, detection
limit, whether the 0.05 nmol/L floor is one), Q07 (operational definition of "dissolved",
contamination control).

Re-staged 2026-10-04 from the restored source file: 170 `sample` and 170 `obs` (`dissolved_iron`,
0.05 to 8.2 nmol/L), all keyed to a cell of the new grid.

## DIC: every sample with a position carries a `grid_key`

In v2026.10.01 `sample.grid_key` was NULL on 3,255 of 3,261 `calcofi_dic` rows. The sample arm took
`grid_key` only from the matched `calcofi_bottle` cast, and 3,255 DIC samples match no cast, though
every one carries a latitude, longitude and datetime. The ingest now assigns `grid_key` from each
sample's own position (`assign_grid_key()` against the `swfsc_ichthyo` grid) and keeps a matched
cast's key where there is one: 3,262 of 3,262 resolve (0 outside the grid). Measured at the
2026-10-04 re-stage: `sample.grid_key` NULL 3,255 → 0; of the 6 samples that already had a key, 3
change with the rebuilt grid and 3 do not; `check_grid_key_assignment()` finds 0 wrong. 3 `obs` rows
of a cast-matched sample carry the cast's key and differ from their sample's.
`calcofi_phytoplankton` stays NULL by design: it is region-pooled. The `obs` and `cruise_key` changes
that go with this are in the next section.

## DIC: the values on samples that match no bottle cast are published (Ben, 2026-10-04)

Until v2026.10.01 the DIC `obs` arm joined `casts`, so a DIC sample that matches no bottle cast
published a `sample` row and no observation: 3,255 of the 3,261 minted DIC samples, about 12,700 of the
16,391 non-missing DIC / total alkalinity / CTD temperature / salinity source values. They are now
published, **wherever the source gives the sample a depth**, on the sample's own
`calcofi_dic:bottle:<md5>` key with the source's own depth, the `grid_key` of its position, and a
`cruise_key` where the SWFSC reference resolves one (below). **These values are not linked to a bottle
cast**: the source names no cast (`calcofi_dic_01`, open), so `parent_sample_key` is NULL and the
sample is its own root. The 3,708 values of a matched cast are all still published (937 / 835 / 1,028
/ 908), with one change of key: **61 of them, on six Niskins, move from their `calcofi_bottle:bottle:` key
to a minted DIC key** (555915 at 13 m: 13 values; 588517, 654186, 655848 and 657308 at 10 m: 11
each; 891715 at 51 m: 4; and one more DIC sample is minted, 3,262 in all: 7 on a matched cast,
3,255 matching none). DIC rows at station 106.7 100.0, 1984-01-19 match two casts (22605 and 22606) that tie
on date; `match_by_site_datetime()` has no tie-break, and the re-staged bottle shard resolved the tie
to cast 22605, which holds no bottle within 1 m of the DIC depth, where v2026.10.01 had 22606 (bottle
555915 at 13 m, and the five other Niskins above). The matching count (1,086 rows) is unchanged. Tie-break: calcofi4db issue to file.

`obs` (`calcofi_dic`) against v2026.10.01 at the 2026-10-04 re-stage, net of the 61 values that
change key (the totals do not depend on how the matching resolves):

| measurement_type | v2026.10.01 | net added | this release |
|------------------|------------:|----------:|-------------:|
| `dic`            |       1,028 |     3,208 |        4,236 |
| `alkalinity`     |         937 |     3,126 |        4,063 |
| `ctdtemp_its90`  |         835 |     3,174 |        4,009 |
| `salinity_pss78` |         908 |     3,173 |        4,081 |
| total            |       3,708 |    12,681 |       16,389 |

3,647 values keep their key and value, the 61 leave a cast's key and arrive on minted keys, and
12,681 are new; compared without the sample key, 0 values are removed and 12,681 added. No value,
depth or quality code changes.

The 12,681 sit on 3,254 samples. One unmatched sample has no source depth (`Depth` = -999: expocode
33RL20210116, station 080.0 090.0, 2021-01-20) and stays a `sample` row with no observations (its DIC
2007.2 and TA 2208.4 umol/kg are the 2 source values left out). Values the provider flags WOCE 3 / 4 / 9
are published with their flag as for the cast-matched ones (141 of the 12,681: alkalinity 65, dic 71,
salinity 5); `qual_ok` / `cc_qual_ok_sql()` exclude them. All 12,681 are within the declared bounds
(`dic` 0..5000, `alkalinity` 0..5000, `ctdtemp_its90` -2..40, `salinity_pss78` 0..45); depths span
0..3,542 m (`check_depth_bounds()` clean).

`cruise_key` on the 3,255 samples that match no cast: 2,920 resolved (NULL → key), 335 left NULL, from
the sample's ship (EXPOCODE NODC prefix, else `Ship_Name`) and date by `resolve_cruise_key()`; the
EXPOCODE start month is not used as the designation (`calcofi_dic_07`, open). The 335 are 8 EXPOCODEs
for which the reference holds no cruise of that ship and month (NOAA Ship Sally Ride 240 samples,
McArthur 51, Oceanus 41, David Starr Jordan 3), the same on the 2026-09-26 ichthyo export as before it. `site_key` is the source's own station on all of them.

**Limitations.** 3,218 of the 3,254 published samples carry a date on the 1st (1,926) or the 20th
(1,292) of a month, an apparent month-precision stand-in: use their year and month, not their day. The
values are not deduplicated against `calcofi_bottle`'s own `dic_rep1` / `alkalinity_rep1` (separate
measurement types, `calcofi_dic_08` / `_09`); some may be the same Niskins (not verified).

## Bottle: salinity quality codes above 9 become blank (calcofi_bottle_01)

The provider (Rasmus Swalethorp, 2026-09-18) answered that a quality code above 9 is impossible
(codes were dragged down a spreadsheet by accident) and to turn every such code into a blank. In
the source `194903-202105_Bottle.csv` that is **880 rows, all `salinity`, all cruise 2021-05-3322**
(880 distinct bottles; codes 10 to 344: 52 in 10–17, 593 in 18–253 and 235 in 254–344); no other quality column holds a code above 9. In
`obs_env` those 880 `measurement_qual` values go from the code to NULL; the salinity values and the
row count are unchanged. A blank is not a verdict on the value: `calcofi_bottle_13` (that cruise reads
24.2–27.1 PSU where its neighbours read 32.8–34.5) is still open, and `cc_qual_ok_sql()` excludes only
codes 8 and 9, so a filtered query returns the same 880 rows before and after. Measured at the 2026-10-04
re-stage: the 880 `salinity` `measurement_qual` values go from the code to NULL, and nothing else
changes: `obs` is 11,135,581 rows on both sides (11,134,701 unchanged, 880 with only the code
changed) across 26 types, `sample_measurement` (268,876 rows across 15 types) is identical, and
the stage holds no code above 9.

## Phytoplankton: repeated rows dropped (workflows#124)

Two sets of source rows carried the same species code twice in one sample, so a summed abundance
(a total, a mean) doubled while a presence count did not. The ingest now drops the second row where
the two hold **the same value**: 4,251 `phytoplankton_abundance` rows leave `obs` / `obs_bio`
(159,804 → 155,553; the 409 `region_pool` samples are unchanged).
- **Cruises 0704, 1202, 1203:** 1,496 codes x 4 regions each are duplicated (4,488 pairs); 4,198 pairs
  are identical and 4,198 rows go. 1202 and 1203 sit in both the 1996–2012 and the 2012–2018 workbook,
  and the 2007 sheet has two columns both labelled "CalCOFI 0704".
- **Code 178:** the same row twice in 53 samples (1902–2211); 53 rows go.
- **290 pairs stay.** Their two rows hold different values (288 on 0704, one each on 1202 SE and
  1203 Alley) and we cannot tell which is right until the provider answers `calcofi_phytoplankton_06`
  (Q06). They are listed, with both values and their source sheets, in
  `metadata/calcofi/phytoplankton/duplicate_pairs_differing.csv`; the ingest asserts that
  `(phyto_sample_id, species_code)` is unique outside that list. A consumer summing abundance still
  double-counts those 290 (code, sample) cells.

Measured at the 2026-10-04 re-stage: `phytoplankton_abundance` 159,804 → 155,553 rows (−4,251).
Compared as a multiset of (sample, value), the stage lacks exactly 4,251 release rows and adds
none; 65 of the 409 `region_pool` samples lose rows, and the 409 samples are unchanged in every
column.

## Phytoplankton: named codes stop falling into "not identified further"; one rule for unknown species

**53 codes with real names keyed only their functional-group class.** The ingest's WoRMS cache
(`metadata/calcofi/phytoplankton/taxon_worms.csv`) had no AphiaID for 75 of the source's 384 defined
species codes. Those fell through to the six `ds_common_name` rows in `metadata/taxon_override.csv`
and keyed their class (Bacillariophyceae, Dinophyceae, Coccolithophyceae, Dictyochophyceae). That
is right for the source's own unidentified classes ("indistinguished pennate diatoms", "pennate
sp. 6"). For 53 real names it was a failed lookup, so "Diatoms, not identified further" and its
siblings silently absorbed named taxa. Among them were both *Pseudo-nitzschia* size classes (codes
94 and 400: cells counted in 405 and 234 source samples, 1996–2022), *Calcidiscus leptoporus* (223)
and *Ditylum brightwellii* (43). The lookups failed for four reasons:

- **Source spelling slips:** *Rhisosolenia*, *brightwelli*, *obtusidiens*, *Lithodesmum*, *octanarius*, …
- **Qualifiers the name cleaner turned into an empty query:** "slim" / "robust Pseudo-nitzschia spp.".
- **Open nomenclature queried verbatim:** "Hemiaulus 1".
- **Accepted species the WoRMS name services never return:** *Calcidiscus leptoporus*
  (worms:235923) and *Rhabdosphaera clavigera* (worms:235972).

**One rule for what the source names.** `species` stays verbatim (it is the name a consumer
displays); `name_query` is what is looked up:

- **Clear spelling slips** are fixed in the query only. The species keys its accepted WoRMS record
  (16 codes).
- **An unknown species of a named genus keys that genus.** This covers "sp. 1" / "sp. a", "spp.",
  size classes, spores, "complex", "cf." determinations, a species WoRMS does not hold (*Prorocentrum
  cinctum*), and species of one genus counted together ("Ceratium kofoidii + C. boehmii"). A known
  species with a "var." / "spore" / "minute form" suffix keeps its species key.
- **The genus keyed is the accepted one.** Where WoRMS files the source's species under another
  accepted genus, the genus codes key that genus, so a hierarchy rollup agrees with the species
  items: the six "Ceratium spp." codes key *Tripos* (worms:494057), as the 19 *Ceratium* species
  already did. `species` still reads "Ceratium spp.".
- **Older rows are brought into line too.** The rule also applies to the older "cf." and combined
  rows, which keyed a species ("Chaetoceros cf. subtilis" keyed *C. subtilis*; "Actinoptychus
  adriaticus + A. vulgaris" keyed *A. adriaticus*). Those species items now fold into their genus.
- **Species of two genera counted together key their lowest common ancestor** in WoRMS's
  classification, not the class: "Dactyliosolen phuketensis + Guinardia striata" keys Rhizosoleniaceae
  (worms:149068), "indistinguished Gyrosigma spp. + Pleurosigma spp." keys Pleurosigmataceae
  (worms:149032), and "Mastogloia woodiana + pennate a" keys Bacillariophyceae (worms:148899), the
  common ancestor of a named *Mastogloia* and an unidentified pennate. `questions.csv` Q09 asks the provider.
- **Same spelling, wrong author.** Five cached rows keyed a later, unaccepted name spelled like the
  source's, not the accepted species. They now key the accepted record:
  - *Chaetoceros debilis* (codes 367 and 521): Leegaard 1920 (worms:961758) → Cleve 1894 (worms:149219).
  - *Chaetoceros peruvianus* (34): Gran 1908 (worms:961865) → Brightwell 1856 (worms:178185).
  - *Coscinodiscus perforatus* (501): Cleve & Möller 1878 (worms:962307) → Ehrenberg 1844 (worms:149272).
  - "*Rhizosolenia hebetata* f. *hebetata*" (390) had keyed *R. hebetata* (Hensen) Margalef, a
    synonym of *R. semispina*, so it merged with f. *semispina* (code 62). It now keys its own form
    (worms:163347).
- **A dinoflagellate keyed to a diatom.** "Prorocentrum compressum" (code 102) keyed worms:978142,
  a diatom variety (*Pyxidicula compressa* var. *compressa*), because WoRMS files that name
  as a synonym of a diatom. It now keys *Prorocentrum* (worms:109566), like the other "Prorocentrum
  sp." codes. Four cached ranks that said "Species" for varieties and a form were corrected.

**Result.** By the resolution order applied to the committed registries:

- 118 codes change `taxon_key`: 54 leave their class (53 for a genus or species, 1 for a family),
  56 move from a species to its genus, 1 from a species to a family, 1 from a species to the class,
  1 from the source's genus to the accepted genus (*Ceratium* → *Tripos*), and 5 move to the
  accepted record of the same name. No other code moves.
- 17 codes stay at class level: 16 unidentified classes and the one two-genus entry whose common
  ancestor is the class. The ingest allowlists them one code at a time and stops if any other
  code reaches only a class.
- Distinct worms `taxon_key`s in `dataset_taxon` go from 299 to 296 (plus 10 dataset-local keys,
  unchanged); 295 of them have observations, because code 258 (*Peridiniella catenata*,
  worms:110156) is defined in the source and has no row.
- **`obs` has one row per source measurement**: 155,553 after the repeated rows above (159,804
  before). Only `taxon_key` moves, on 48,633 rows (the 118 codes; 5,925 of them with cells
  counted); the stage is consistent with that, though the moved rows cannot be separated by value
  from the 4,251 dropped.
- **Consumers must sum.** Several codes now share one `taxon_key` within the same sample (30
  keys do: *Oxytoxum* 10 codes, Bacillariophyceae 9, *Dinophysis* 8, *Nitzschia* 8,
  *Prorocentrum* 8, *Chaetoceros* 7, *Protoperidinium* 6, *Tripos* 6). A consumer that counts
  rows per taxon rather than summing `value` per sample double-counts. `obs.obs_id` stays unique,
  so no gate fails.
- The release's `dataset_taxon.ds_scientific_name` still holds the WoRMS name, not the source's own
  spelling; the verbatim name is in the ingest's `taxon_worms.csv` (`species`).

**Two phytoplankton common names.** WoRMS, GBIF, ITIS and NCBI Taxonomy were checked for every
phytoplankton taxon. Beyond the classes, only two species have an English name, and both are WoRMS's
single English vernacular: *Noctiluca scintillans* "sea sparkle" (worms:109921) and *Pyrocystis
fusiformis* "ocean night light" (worms:110328). They are added to `metadata/taxon_common.csv`.

## Euphausiids: 40 tows of February 1982 have no `cruise_key`, because the ichthyoplankton reference no longer holds cruise 198202JD

`cce-lter_euphausiids` resolves its cruise keys against the cruise reference that `swfsc_ichthyo`
supplies. SWFSC moved cruise 198202JD (`1982-02-31JD`) back to its staging schema (see "Ichthyoplankton:
cruises 198202JD and 198212JD leave"), the 2026-09-26 export holds no row for it, and **40
`cce-lter_euphausiids` `tow` samples of February 1982 that carried `1982-02-31JD` now have no
`cruise_key`** (NULL `cruise_key` on the dataset 420 → 460). The cruise took place: the tows' values,
positions and dates are unchanged, and the dataset's 100,505 `obs` rows are identical to
v2026.10.01's. Apart from `grid_key` (1,954 rows, see the grid section), these 40 keys are the only
change to the dataset's `sample`. The release ratchet on NULL `cruise_key` for this dataset is
raised by those 40 in `release_database.qmd` and returns to 420 when SWFSC restores the cruise row
(`swfsc_ichthyo` Q23, which asks whether the Cruise table can keep a row for a cruise whose
ichthyoplankton data are staged).

**Consumers:** a join of `cce-lter_euphausiids` to `cruise` on `cruise_key` loses these 40 tows.

## `chl_fluor` floors at −1 µg/L, so the 102 near-zero readings of `calcofi_mets` stay published

`chl_fluor` is shared with `calcofi_mets`, so a bound declared for it applies there too. It now
declares `valid_min = -1` µg/L, the floor `calcofi_bottle` declares for chlorophyll-a. A floor of 0
would have removed 102 calibrated-fluorescence values from `calcofi_mets` (minimum −0.112, median
−0.03 µg/L): they are real near-zero readings, not sentinels. Measured at the 2026-10-04 re-stage:
with the floor at −1 the 102 negative `chl_fluor` readings (−0.112 to −0.00025) are published, and
`calcofi_mets` `obs` (511,395 rows) and `obs_mets_full` (19,926,523 rows) are identical to
v2026.10.01's.

## `sample` and `sample_root` carry `hex7`, so a per-sample value can be drawn in hexagons

A value held per sampling event in `sample_measurement` (a cast's mixed-layer depth, a net's volume
filtered) had no H3 cell: the cell lived only on observations (`obs_bio.hex7`, `obs_env.hex7`), and a
per-sample value has no observation row to borrow one from. The Explorer's Hexagons lens could not
draw the seven per-cast `calcofi_ctd-derived` types for that reason.

- **`sample.hex7` and `sample_root.hex7` (new column, `UBIGINT`, last on each table).** The H3 cell
  at resolution 7 of the event's own position, `NULL` where the position is missing or not finite.
  `sample_root.hex7` is its root's `sample.hex7`, copied. The change touches no other column: on a
  dry run over v2026.10.01 every other value of both tables is unchanged, row for row.
- **One definition with the observations.** `hex7` is the resolution-7 **parent of the
  resolution-10 cell** of the position, built from the same SQL as `obs.hex_id` and
  `obs_bio.hex7` / `obs_env.hex7`. It is not the resolution-7 cell the position falls in: H3 cells
  do not nest exactly, and the two differ for 101,770 of 1,463,329 positioned samples (7.0 %).
- **By how much** (dry run on v2026.10.01): 1,463,329 of 1,469,239 `sample` rows and 415,628 of
  421,538 `sample_root` rows get a cell. The rest have no place: 5,761 samples with no position
  (`calcofi_mets` 4,039, `swfsc_cufes` 1,563, `cce-lter_zoodb` 155, `cdfw_dungeness-crab` 4) and 149
  `calcofi_mets` samples holding one coordinate without the other. Of the 652,879
  `sample_measurement` values, 652,871 now reach a hexagon through `sample`; through `sample_root`
  alone 332,152 do, because 320,719 values sit on non-root samples (ichthyoplankton nets, crab
  subsamples). `sample` grows 25.9 → 27.7 MB (+6.7 %), `sample_root` 10.5 → 11.5 MB (+9.0 %).
- **A sample's cell is not always its observations' cell, and that is correct.** `sample` holds one
  position per event; a CTD observation holds its own scan's position, and a DIC draw its own. Where
  the ship drifts across a cell edge during a cast, some scans are in the neighbouring hexagon:
  1,012,956 of 33,139,449 observations (3.1 %), on 925 of 9,674 `calcofi_ctd-cast` casts, 893 of the
  9,275 casts with `calcofi_ctd-derived` profiles and 235 of 789 `calcofi_dic` samples. None of the
  other 13 datasets differs, and no observation that sits at exactly its sample's position
  (17,341,531 of them) is in another cell.
- **Gate.** `check_sample_hex7()` (`release_database.qmd`, chunk `browser_objects`) fails the
  release unless a cell is present exactly where the position is finite, is at resolution 7, is
  equal on `sample` and `sample_root` for every root, and equals the cell of every observation at
  the same position. Observations in another cell than their sample are reported. Four
  `test_release.qmd` contract rows assert the same on the published objects.

**Consumers:** additive, nothing to change. To place a per-sample value, join `sample_measurement`
to `sample` on `sample_key` and read `hex7` (`sample_root` reaches root samples only). Coarser
hexagons are `calcofi4db::h3_parent_sql(hex7, res)`, plain bit arithmetic that needs no extension.
Join an observation to its sample on `sample_key`, never on the cell.

## Correction: the `obs` objects still ship; #92 tracks their removal

The v2026.09.10 notes below say its cut was the last to ship the `obs` table's objects and that
"the next release drops the `obs` objects and the twin". That did not happen: v2026.10.01 still
exported the 16 `obs` partition objects and `obs.parquet`, and **this release does too**. They go
only when every reader has moved to `obs_bio` + `obs_env` or the `obs` catalog view
(issue [#92](https://github.com/CalCOFI/workflows/issues/92), open; seven readers break with no
change). Until the release that drops them says so here, read `obs_bio` / `obs_env` or the view,
not the table's objects.

## calcofi.io measurement pages: face, why and method rows for the keys that had none

The landing site draws each `/measurements/` page from `measurements.json`, which carries the five
face registries (`metadata/measurement_{face,why,method,chem,scale}.csv`). In v2026.10.01 three
published keys had no face (`oxygen_ml_l_ave_cruise_corr`, `sigma_theta_ave`, `spiciness0`), four no
why (those and `uws_flow`) and three no method. They now have rows, so their pages publish all three
sections: `oxygen_ml_l_ave_cruise_corr` reuses the dissolved-oxygen rows (face, chemistry, why),
`sigma_theta_ave` stands in for `sigma_theta`, and `spiciness0` and `uws_flow` get their own why rows.
Rows are also written for the per-cast mixed-layer-depth and chlorophyll types of
`calcofi_ctd-derived` (`mld_sigma_theta_002`, `mld_sigma_theta_0125`, `mld_temperature_02`, `chl_max`,
`chl_max_depth`, `chl_integrated`, `chl_integrated_depth`; the headline mixed-layer depth states the
provider's 0.02 kg m⁻³ from 10 m criterion, and the retired `mld_sigma_theta_003` has none). Because the
catalog now lists per-cast types (the CTD derived products section above), these keys get a `/measurements/` page that says each is
one value per cast. Rows for the eDNA types (`edna_presence`, `edna_reads_*`) and `group_size` /
`acoustic_presence` are written too, but those are `obs_bio` keys, which the catalog does not list, so
they render nowhere yet. No data changes.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `climatology` | 821,390 | partitioned |
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

**25 tables, 373,474,855 rows, 2.73 GB.**

**Datasets (22):** `calcofi_2022-edna`, `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_ctd-derived`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_iron`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_cetacean-edna`, `sio_cetacean-sightings`, `sio_cetacean-sonobuoy`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 92 pass / 0 fail / 4 skip (consumer-contract suite, 2026-10-05T18:58:44Z).

**Software:** calcofi4db 4.21.0, calcofi4r 1.25.0.

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.10.05 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://calcofi.io/db-schema/?v=v2026.10.05

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
con <- calcofi4r::cc_get_db(version = "v2026.10.05")
```
```python
con = calcofi4py.cc_get_db("v2026.10.05")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.10.05/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
