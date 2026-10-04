# CalCOFI integrated database — release notes

What changed between releases and why. One section per release, newest first; the
`# Unreleased` section collects changes since the last release and becomes the next release's
section when `release_database.qmd` runs. Each release's `RELEASE_NOTES.md` on GCS is the
section below plus a generated appendix (tables, rows, datasets, validation gates, package
versions). Conventions: see `CLAUDE.md` § "Release rules" and the `release-run` skill.

# Unreleased

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
- **`sample.grid_key` / `obs.grid_key`.** On v2026.10.01's positions 12.7% of `sample` rows change
  key (8.2% of rows before 1984, 17.2% from 1984), 5.4% to a cell that is not their previous cell
  renamed; all of them inside the official pattern: 34% of the rows in nearshore standard cells,
  1% in offshore standard ones, none in a kept cell. No row that had a cell loses it, and 5 gain
  one.
- **Assignment is deterministic.** `assign_grid_key()` took `LIMIT 1` with no order, so a position
  on an edge two cells share keyed to either; it is now the key that sorts first, and
  `calcofi4r::cc_grid_key()` is the same rule in R (identical on all 226,762 distinct `sample`
  positions and on every cell vertex).
- **New gates.** `check_grid_key_assignment()` recomputes the cell of every `sample` position and
  stops the release on a key that is not that cell. It is what catches an ingest staged against
  the previous grid: of v2026.10.01's keys, 185,761 name another cell of the new grid and 59,688
  of those are surviving names that pass the foreign-key check. `check_grid_crosswalk()` gates
  the crosswalk.
- **Not single-piece everywhere.** 13 kept cells are in several pieces, as 10 of them already
  were (cells that span the Baja California peninsula): keeping them as they were is what keeps
  every historical key. One station cell, `st53-ln60`, carries 21 km² of Tomales Bay as a
  detached part: that water was in a replaced cell and opens to the sea only through a kept one.
- **Unchanged:** the climatology is keyed on `site_key` and no mean moves; `climatology.grid_key`
  (the station's modal cell) takes a new label on about one row in nine.

**Rows whose `grid_key` changed, per dataset** (`sample`, this release against v2026.10.01):

<!-- GRID-KEY-DIFF: measured at re-stage. Replace the `this release` column, per dataset, with
     the count of `sample` rows whose `grid_key` differs from v2026.10.01's on the same
     `sample_key` (NULL counts as a value), and delete this comment. The `predicted` column is
     v2026.10.01's positions keyed against the new grid (explore_grid_voronoi.qmd, gate 5); a
     dataset whose measured count is far from it was not re-staged, or changed for another reason
     (calcofi_dic: its 3,255 NULL keys are also filled in this release, see below). -->

| dataset | rows (v2026.10.01) | predicted | this release |
|---|---:|---:|---:|
| `calcofi_bottle` | 931,015 | 89,194 (9.6%) | _to measure_ |
| `swfsc_ichthyo` | 213,122 | 32,659 (15.3%) | _to measure_ |
| `sio_pic-zooplankton` | 82,343 | 13,280 (16.1%) | _to measure_ |
| `calcofi_mets` | 77,791 | 19,345 (24.9%) | _to measure_ |
| `farallon_bird-mammal` | 64,421 | 10,777 (16.7%) | _to measure_ |
| `swfsc_cufes` | 49,572 | 9,227 (18.6%) | _to measure_ |
| `calcofi_ctd-cast` | 19,330 | 4,791 (24.8%) | _to measure_ |
| `cce-lter_picoplankton-bacteria` | 16,017 | 3,375 (21.1%) | _to measure_ |
| `cce-lter_euphausiids` | 7,482 | 1,954 (26.1%) | _to measure_ |
| `calcofi_dic` | 3,261 | 768 (23.6%) | _to measure_ |
| `calcofi_phyllosoma` | 1,859 | 712 (38.3%) | _to measure_ |
| `cce-lter_zooscan` | 1,483 | 300 (20.2%) | _to measure_ |
| `cdfw_dungeness-crab` | 526 | 51 (9.7%) | _to measure_ |
| `cce-lter_zoodb` | 506 | 73 (14.4%) | _to measure_ |
| `calcofi_phytoplankton` | 409 | 0 (ungridded) | _to measure_ |
| `sio_mesopelagic-fish` | 102 | 16 (15.7%) | _to measure_ |
| **all** | 1,469,239 | 186,522 (12.7%) | _to measure_ |

`calcofi_dic` is predicted from its positions against the previous grid's cell for the same
position; in v2026.10.01 3,255 of its 3,261 rows carry no `grid_key` at all (see "DIC: every
sample with a position carries a `grid_key`" below), so its measured count will be near 3,261.

**Consumers:** a `grid_key` stored from an earlier release (a URL, a cache, a per-cell statistic)
must be mapped through `grid_crosswalk`, not matched by name. `grid.station` and `grid.line` are
no longer whole numbers for some cells, and seven lines hold a single station (81.7, 81.8, 85.4,
86.8, 88.5, 91.7, 93.4: six SCCOOS stations and the rosette station 81.8 46.9), so a section
along line 93.3 no longer includes station 93.4 26.4 and code that rounds a line or matches it
within 0.5 picks up 93.4 with 93.3. `grid.geom_ctr` (`lon_ctr` / `lat_ctr` in `grid.geojson`) is
the station, not a centroid. `grid.geojson` grows from 7,474 to 31,660 vertices. `grid.geom` is
still a mix of polygons and multipolygons. `calcofi4r::cc_grid*` change with it (`sta_lin` /
`sta_pos` are doubles; `cc_grid_v1` is the previous grid).

## CTD derived products: the CTD team's mixed-layer depth and chlorophyll-maximum definitions

`calcofi_ctd-derived` now computes its per-cast products by the definitions Rasmus Swalethorp gave on
2026-09-23 (questions.csv Q01, Q02; adopted 2026-10-01; CalCOFI/workflows#101, #102). v2026.10.01
shipped interim choices, so **the value changes on every cast** that has one.

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

**Per-type change against v2026.10.01** (filled after the re-stage; rows changed, filled and removed,
and the largest change per `measurement_type`):

<!-- COORDINATOR: fill from the stage-vs-release diff after ingest_calcofi_ctd-derived is re-staged -->
| measurement_type | casts v2026.10.01 | casts now | changed | largest change |
|---|---|---|---|---|
| `mld_sigma_theta_002` (new; vs `mld_sigma_theta_003`) | TBD | TBD | TBD | TBD |
| `mld_sigma_theta_003` (retired) | TBD | 0 | — | — |
| `chl_max_depth` | TBD | TBD | TBD | TBD |
| `chl_max` | TBD | TBD | TBD | TBD |
| `chl_integrated` | TBD | TBD | TBD | TBD |

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
  9504NH extra casts reusing cast numbers, six with 1-177 scans: 1,951,755 keys) to their count.

**Predicted** (the changed rules re-run on the source files of the 39 affected cruises by a
mini-pipeline that reproduces v2026.10.01's `obs` and `obs_ctd_full` row for row under the old
rules; excludes #127's depth-constant drop and 2026-07's re-issued archive):

| table | added | removed | changed | duplicated keys |
|---|---|---|---|---|
| `obs` | 21,587 | 169,369 | 12,882 | 161,144 → 1,550 |
| `obs_ctd_full` | 273,352 | 2,863,345 | 321,217 | 2,864,642 → 7,623 |

2022-04 alone: `obs` +3,928 / −151,648 / ~12,882, `obs_ctd_full` +73,988 / −2,796,552 / ~321,217
(changed = the re-export's oxygen µmol/kg station-corrected, SPAR/PAR rounding, `EstChl_StaCorr`).
Bottle-grain `obs` rows (`btl_*`, `salinity_btl`, `oxygen_btl_*`): +303 / −3,409 in 2022-04,
+127 in 2024-04, +57 in 2025-04, +840 / +346 in 2008-01 / 2007-11, −364 / −176 in 2016-04 / 2021-05
(the doubled upcasts), +384 pigment values elsewhere. Per type and cruise:
`prediction_by_cruise_type.csv` in the #131 hand-off.

**Measured** (`diff_stage_vs_release()` after the re-stage): _to fill_.

## CTD: derived series that hold one value at every depth are withheld (not yet rendered)

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
(cast, series) values (dropped, not flagged). Consequence at the next ctd-cast render: the affected
casts lose `est_nitrate_cruise_corr` / `oxygen_*_cruise_corr` / `oxygen_*_sta_corr` rows in
`ctd_measurement` and downstream (`obs_ctd_full`, `ctd_summary`); a sensor-pair average that rested
on a withheld sensor is rebuilt from the other. `questions.csv` Q42 asks the CTD team whether
`EstNO3_CruiseCorr` is a per-cast offset in these files and whether to withhold or recompute it.

## CTD casts: two provider questions on bottle values after 2021-05

`calcofi_bottle` ends 2021-05-13, where the provider's bottle database ends; later bottle values
reach the release only as the `btl_*` types on `calcofi_ctd-cast`, from preliminary CTD + bottle
files and with no quality code (the source files carry no flag column for any bottle value).
Two `proposed` questions go to the provider (`metadata/calcofi/ctd-cast/questions.csv` Q40, Q41):
whether `btl_*` values are equivalent to the bottle database for 2021 onward, and whether a bottle
database later than 2021-05 is available or scheduled. No data changes.

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
`dna_concentration`; `chl_fluor` (shared with `calcofi_mets`) now declares `valid_min = -1` µg/L, the floor
`calcofi_bottle` declares for chlorophyll-a: a floor of 0 would have removed 102 calibrated-fluorescence
values from `calcofi_mets` (minimum −0.112, median −0.03 µg/L), which are real near-zero readings.

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

## Correction: the `obs` objects still ship; #92 tracks their removal

The v2026.09.10 notes below say its cut was the last to ship the `obs` table's objects and that
"the next release drops the `obs` objects and the twin". That did not happen: v2026.10.01 still
exported the 16 `obs` partition objects and `obs.parquet`, and **this release does too**. They go
only when every reader has moved to `obs_bio` + `obs_env` or the `obs` catalog view
(issue [#92](https://github.com/CalCOFI/workflows/issues/92), open; seven readers break with no
change). Until the release that drops them says so here, read `obs_bio` / `obs_env` or the view,
not the table's objects.

## DIC: every sample with a position carries a `grid_key`

In v2026.10.01 `sample.grid_key` was NULL on 3,255 of 3,261 `calcofi_dic` rows. The sample arm took
`grid_key` only from the matched `calcofi_bottle` cast, and 3,255 DIC samples match no cast, though
every one carries a latitude, longitude and datetime. The ingest now assigns `grid_key` from each
sample's own position (`assign_grid_key()` against the `swfsc_ichthyo` grid) and keeps a matched
cast's key where there is one: 3,261 of 3,261 resolve (0 outside the grid; of the 6 cast-matched
samples 5 agree with the position's cell). `sample.grid_key` changes NULL → key on 3,255 rows.
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
/ 908), with one change of key: **13 of them, on one Niskin, move from `calcofi_bottle:bottle:555915`
to a minted DIC key** (and one more DIC sample is minted, 3,262 in all: 7 on a matched cast, 3,255
matching none). DIC rows at station 106.7 100.0, 1984-01-19 match two casts (22605 and 22606) that tie
on date; `match_by_site_datetime()` has no tie-break, and the re-staged bottle shard resolved the tie
to cast 22605, which holds no bottle within 1 m of the DIC depth, where v2026.10.01 had 22606 (bottle
555915 at 13 m). The matching count (1,086 rows) is unchanged. Tie-break: calcofi4db issue to file.

Predicted `obs` (`calcofi_dic`, measured by running the notebook's own SQL on the source file against
the 2026-10-04 re-staged `calcofi_bottle` and `swfsc_ichthyo` shards; 0 values removed, the per-type
totals below do not depend on how the matching resolves):

| measurement_type | v2026.10.01 | added | predicted |
|------------------|------------:|------:|----------:|
| `dic`            |       1,028 | 3,208 |     4,236 |
| `alkalinity`     |         937 | 3,126 |     4,063 |
| `ctdtemp_its90`  |         835 | 3,174 |     4,009 |
| `salinity_pss78` |         908 | 3,173 |     4,081 |
| total            |       3,708 | 12,681 |   16,389 |

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

## Ichthyoplankton: cruises 198202JD and 198212JD leave (swfsc_ichthyo_09)

SWFSC (Ed Weber, 2026-09-25) moved cruises **198202JD** and **198212JD** (`1982-02-31JD`,
`1982-12-31JD`) back to its staging schema: they were sorted for anchovy only, so every other taxon
read as a zero catch. The 2026-09-26 source export no longer contains them, so the re-stage drops
them: 1,128 `site`, 1,112 `tow` and 1,145 `net` `sample` rows; 1,100 `obs` rows (all `abundance`:
1,055 on 1982-02, 45 on 1982-12); 1,054 `stage` and 1,308 `body_length` `obs_attribute` rows; and
1,145 each of `std_haul_factor`, `prop_sorted` and `volume_sampled` `sample_measurement` rows.
`swfsc_ichthyo` `obs` goes 482,250 → 481,150. The ingest now asserts both cruises are absent from
what it loads. **Zero handling is unchanged:** a tow with no row for a taxon is a true zero and stays
in the denominator (the provider: "the others are true zeros and have valid positive zooplankton
volumes"). `1982-02-31JD` stays in `cruise` as a derived row because 40 `cce-lter_euphausiids` samples
carry that key (derived-cruise count 151 → 152, the ratchet's ceiling); `1982-12-31JD` leaves it.

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
  catch: 6,491 `obs` rows (297 egg, 5,789 larva, 405 invertebrate), 765 `body_length` and 10 larva
  `stage` rows. No site or tow is added.
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
  AphiaID). Where two of them were counted in one net their rows are now one: 25 such pairs, so
  `obs` has no duplicated (sample, taxon, life stage) any more (v2026.10.01 had 3). Every code keeps
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

## Bottle: salinity quality codes above 9 become blank (calcofi_bottle_01)

The provider (Rasmus Swalethorp, 2026-09-18) answered that a quality code above 9 is impossible
(codes were dragged down a spreadsheet by accident) and to turn every such code into a blank. In
the source `194903-202105_Bottle.csv` that is **880 rows, all `salinity`, all cruise 2021-05-3322**
(44 stations; codes 10–17 and 254–344); no other quality column holds a code above 9. In
`obs_env` those 880 `measurement_qual` values go from the code to NULL; the salinity values and the
row count are unchanged. A blank is not a verdict on the value: `calcofi_bottle_13` (that cruise reads
24.2–27.1 PSU where its neighbours read 32.8–34.5) is still open, and `cc_qual_ok_sql()` excludes only
codes 8 and 9, so a filtered query returns the same 880 rows before and after.

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
- Distinct phytoplankton `taxon_key`s in the worms authority go from 299 to 296 (plus 10
  dataset-local keys, unchanged).
- **`obs` row count is unchanged** (159,804: one row per source measurement). Only `taxon_key`
  moves, on 48,633 rows (the 118 codes; 5,925 of them with cells counted).
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

# v2026.10.01

## CTD: the corrected 2607 file, provider flags on every series, cruise-corrected oxygen

**Five recent cruises regain their offshore stations.** The first 20-2607SH_CTDPrelim.zip wrote station numbers
of 100 and above with three digits, so 100/110/120 read as 000/010/020. The distance filter then
dropped every such cast as a position error: in v2026.09.11, 2026-07-3322 has 122 casts instead of
144, and lines 80, 83.3, 86.7, 90 and 93.3 stop at station 90. The provider fixed the file on
2026-09-14 (Kelsey Vogel). Only `Sta` and `Sta_ID` differ between the two files, not a single
measured value, so this release adds those 22 casts back: 11,372 rows per series, and no value
changes on any other cruise. The same truncation is in the still-current preliminary files for
**2507SR, 2511SR, 2601RL and 2604SH**, which the provider has not re-issued. The ingest repairs a
station to station + 100 only where the cast's own GPS position confirms it: within 10 km of
station + 100 and farther than that from the station as written. Applied to the old 2607 file,
that rule reproduces the provider's correction on all 56,993 rows. Every repaired cast is listed
in the ingest's report, and questions.csv Q39 asks for re-issued files. The ingest also **fails the
render** if any dropped cast still carries the signature, so a truncation cannot drop stations
quietly again. A zip
re-published under the same name also invalidates the ingest's fingerprint, its checkpoint and its
extraction now; before this, the corrected file would have read as "inputs unchanged"
(CalCOFI/workflows#104).

**Every CTD series carries the provider's own flag.** The CTD team's 2026 processing software writes
a quality code for each corrected, averaged and derived series (`SaltAve_CorrQ`, `OxAve_StaCorrQ`,
`EstChl_StaCorrQ`, `EstNO3_CruiseCorrQ`, `BATQ`, `PoT1Q`, `DynHtQ`, … 27 columns, first in the
corrected 2607 file). Each series' `measurement_qual` now comes from that column, falling back to
the sensor flag it inherited before for a file in the legacy layout, so no flag on a legacy cruise
moves. The two-sensor averages are still rebuilt by Rasmus Swalethorp's flag rule
(`combine_sensor_pair_sql()`); the provider's flag on its own average rides on ours, and a
cross-check table compares the two averages per file layout for the CTD team (#105).

**2607 casts 1–6: the faulty secondary temperature is flagged.** The provider's cruise notes say the
secondary temperature sensor was faulty on casts 1–6. It reads a median 11 °C from the primary, up to
42 °C, and nothing flagged it, so 1,775 of those casts' `temperature_ave` values averaged it in (up to
11.3 °C off). A new committed registry, `metadata/calcofi/ctd-cast/flag_overrides.csv` (one row per
cruise, cast range, direction and series, each with a reason, a source and a question), flags that
sensor 9 on those casts, together with every series the provider derives from it (secondary
salinity, sigma-theta, potential temperature and oxygen). It is applied after the provider's flags
and before any average, so `temperature_ave` there is the primary sensor alone; the ingest asserts
it. This is provisional until the CTD team flags at source (questions.csv Q37).

**`oxygen_ml_l_ave_cruise_corr`**, the cruise-corrected DO average, is new. It is built from
`Ox1_CruiseCorr` / `Ox2_CruiseCorr` by the same flag rule; the source ships no average of that
pair. It is canonical (in `obs` via `ctd_thin`) and bounded 0–15 ml/L like its station-corrected
sibling (#106).
## A new dataset: `calcofi_ctd-derived`, hydrographic products computed from the CTD casts

Rasmus Swalethorp asked for values derived from the CTD profiles beside the measured series,
to show how much upwelling, productivity and California Undercurrent there is on each cruise
(CalCOFI/workflows#98). `ingest_calcofi_ctd-derived.qmd` computes them from the full-resolution
1 m bins of `calcofi_ctd-cast` after the provider's 8/9 flags are dropped, with one tested
calcofi4db (≥ 4.16.0) function per rule. It publishes:
- **`obs`** (so `obs_env` and the `climatology`): `spiciness0` (TEOS-10 spice at 0 dbar) and
  `sigma_theta_ave` (the sensor pair combined by its flags), at the depths ctd-cast publishes;
- **`sample_measurement`**, on the ctd-cast cast:
  - mixed-layer depth by three criteria (`mld_sigma_theta_003`, `mld_sigma_theta_0125`,
    `mld_temperature_02`);
  - `chl_max_depth` / `chl_max`;
  - `chl_integrated` (0–200 m) / `chl_integrated_depth`;
- **`ctd_geostrophic`**, a new table: relative geostrophic velocity between adjacent stations of
  each line, referenced to 500 dbar, in 10 dbar bins (no anomaly: relative flow).

`preliminary_without_bottle` casts get only `mld_temperature_02`, since nothing salinity-based
applies. The defaults (10 m / Δσθ 0.03, 5 m median, 0–200 m, p_ref 500, 10 km minimum spacing,
down cast) are provisional until Rasmus answers the dataset's questions Q01–Q05. The dataset emits
no `sample`: every row keys to the ctd-cast cast, declared in `relationships_cross.csv`.

## Dataset metadata: the 16 CalOOS-sheet proposals reviewed into the record (#79, #96)

Each `dataset_meta.yml` proposal imported from the CalOOS sheet on 2026-09-05 was reviewed field by
field against its dataset (Betty Huang). What was accurate was merged, what wasn't was rejected
with a reason, and what was uncertain became a `proposed` question for the provider. The new
fields are abstracts, creators, associated parties, contacts, keywords, QC statements and
maintenance, which flow into every dataset page, citation and EML document.
- **DIC:** creators are now the seven authors of its NCEI citation, in order. The two PIs stay in
  `pi_names`.
- **Dungeness crab:** its data source is CDFW's CNRA Open Data page (Christy Juhasz, 2026-09-14).
- **`sio/pic-zooplankton`:** the proposal is rejected; it described the pending biovolume table
  (Q01).
- The proposal files are removed now that they are reviewed.

## Why each measurement matters: one cited pick, the alternatives beside it

`metadata/measurement_why.csv` now carries, for every measurement key with a face, one authored
rank-1 sentence about the health of the ocean or the California Current, each tied to a citation
whose DOI resolves, plus the alternatives a reader can open instead: a second authored line, the
GOOS Essential Ocean Variable's scientific question quoted verbatim from its specification sheet,
the Wikipedia article the page leads from, and calcofi.org's own words where a methods page states
why. The why covers the concept, not the key, so the fifteen oxygen keys share one pick and a
stand-in inherits the pick of the face it borrows, with its own reason ranked beneath it. The
BibTeX entries live in `../docs/refs/refs.bib`.

## `measurements.json` is schema 1.1: an anomaly per depth band, the face registries, `n_flagged`

The measurements catalog record gains three things, all additive — a 1.0 reader sees the record it
always saw. **`anomaly`**: for every key the release's `climatology` covers, the yearly departure
from that baseline in each depth band it is measured in (`obs_env` joined to `climatology` on
dataset_key, measurement_type, `site_key`, calendar month and 10 m bin), with a 1984–2021
least-squares trend per decade, the band's extremes, one symmetric `ymax` shared by the key's bands
and the bands that hold values but reach no baseline listed under `deeper[]` rather than dropped.
The mean is taken per cruise and then over cruises, and a year of fewer than two cruises stays in
the series but never steers a trend, an extreme or the scale. A unified key merges its series before
averaging, each series against the normal of its own `measurement_type`. **The five face
registries** `metadata/measurement_{face,chem,method,scale,why}.csv` ride on the key when they carry
a row for it; a `kind = computed` scale mark is recomputed at build from its own `how` (TEOS-10's
`gsw`) and never read as a typed number, and one this package cannot evaluate says so
(`computed_at_build: false`). **`n_flagged`** (`n_values − qual_ok_n`) is now on every series and
every key, and `observed{}` — the range a page quotes — is computed inside the declared bounds
**and** inside `qual_ok`: a provider's quality flag outranks a physical bound, so a flagged extreme
that happens to be inside the bounds is no longer advertised as the observed maximum. Measured on
v2026.09.11: 89 keys, 71 with an anomaly over 362 bands with a normal and 164 deeper bands named,
48,427 values that a provider flag keeps out of `observed{}`; the record grows 189 KB → 551 KB.

## The climatology goes to the bottom, not to 500 m

`build_climatology()`'s `depth_max_m` defaulted to 500 m — the depth the Explorer's Sections lens
draws to — and the cap travelled well beyond that lens: on v2026.09.10, 117,302 temperature,
105,689 salinity, 81,423 oxygen and 26,076 nitrate values below 500 m had no normal to depart from,
so no product could show a deep anomaly at all. The default is now no depth ceiling: the ≥ 5-cruise
rule the release already passes is the only rule that decides whether a cell is a baseline, and it
stops the table where the data thins. Measured on v2026.09.10 at `min_cruises = 5`: 714,882 →
734,410 rows (+19,528, +2.7 %), deepest bin 500 → 720 m, 8.98 → 9.27 MB of parquet. The change is
additive: no cell at or above 500 m is added, lost, or changed (the Explorer's own
`section_clim.sql` returns the identical 21,306 cells above 500 m and 533 new ones at 510–720 m),
so every existing anomaly reads exactly as before.

## Picoplankton counts move to Biology, with a taxon on every row

The CCE-LTER flow-cytometry counts are observations of organisms, so they are now `obs_bio`
rather than `obs_env` (measurement-faces plan D9; Ben, 2026-09-12). All 60,802 rows carry one
`measurement_type`, `picoplankton_abundance` (cells per ml), and the population counted moves
into `obs.taxon_key`: `worms:160572` *Synechococcus* (16,002 rows, 2004–2023) and
`worms:345515` *Prochlorococcus* (12,789), which therefore get species pages at
`/species/worms-160572/` and `/species/worms-345515/`. The flow cytometer's other two
populations are operational, not taxonomic — a size fraction and a trophic fraction — so they
keep their identity in a declared dataset-local key
(`cce-lter_picoplankton-bacteria:picoeukaryotes`, 16,009 rows; `…:het_bacteria`, 16,002), the
same mechanism ZooScan's eggs / multiples / nauplii / others use, and both are declared in
`check_taxon_ids()`'s allowlist.

Consequence for consumers: the four measurement keys `synechococcus`, `prochlorococcus`,
`picoeukaryotes` and `het_bacteria` **leave the measurements catalog** — 89 keys / 94 series on
v2026.09.11 become 85 / 90 — and `obs_env` loses those 60,802 rows (29,838,093 → 29,777,291).
Their `metadata/measurement_type.csv` rows are **not deleted**: a registry row is statused, never
removed, and they remain the vocabulary of the dataset's own
`picoplankton_bacteria_measurement` table, which is still served as a compat view carrying the
source's four column names.

# v2026.09.11

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

# v2026.09.10

## The `obs` objects ship for the last time

v2026.09.06 marked the `obs` table `deprecated`, `replaced_by: [obs_bio, obs_env]`, `removed_in:
next`, and this release still exports its 16 partition objects and the single-file `obs.parquet`
twin (401 MB per release beside the pair's 342 MB) because nothing in the notebook acted on the
mark. That is deliberate for this cut and final: **the next release drops the `obs` objects and the
twin.** `obs` stays as the catalog view over `obs_bio` + `obs_env` (`views.obs`), so
`cc_get_db()` (R and Python) and db-query's `__TBL:obs__` keep answering; a reader that resolves the
`obs` *table's* objects by hand — `cc_release_sources(catalog, "obs")`, the `single_file` twin,
`ducklake/releases/{v}/parquet/obs/` — must move to the pair or the view before then. The list of
those readers and their fixes is `.claude/plans/2026-09-10 plan_todo — drop the obs objects.md`.
The hive partitioning of `obs_env` by `measurement_type` stays: every browser reader takes the
object list from `catalog.json`, never a glob, and one variable is one ≤ 10 MB object.

## The baseline needs five cruises, and the corrected per-sensor CTD series reach `obs`

Rasmus Swalethorp's review of the transect plotter (2026-09-09) settles two things the release carries:

- **`climatology` keeps a cell only where ≥ 5 distinct cruises contribute** (was 3). Measured on
  v2026.09.06: 577,113 of 768,880 cells survive (75 %; 87 % of the CTD temperature cells, the losses
  concentrated in the thinly sampled offshore and pre-2004 inshore stations). `clim_n` and
  `n_cruises` stay on every row, so a consumer can show how many observations and cruises made the
  baseline it subtracts. The `calcofi_mets` cells (156, none ≥ 5) drop out entirely.
- **Ten CTD measurement types become canonical** and so reach `ctd_thin` → `obs` / `obs_env` (one
  hive object each): `salinity_1_corr`, `salinity_2_corr`, `oxygen_ml_l_{1,2}_sta_corr`,
  `oxygen_ml_l_{1,2}_cruise_corr`, `est_chlorophyll_a_{sta,cruise}_corr`,
  `est_nitrate_{sta,cruise}_corr`. Until now only the file's own averages (`salinity_ave_corr`,
  `oxygen_ml_l_ave_sta_corr`) and the uncorrected sensors were published, so no consumer could apply
  the rule Rasmus asked for — the mean of the two corrected sensors, one alone when the other is
  flagged 8/9, honouring the 1/2 sensor-choice flags — nor offer chlorophyll or nitrate from the
  bottle-fitted sensor estimates, nor choose between the station- and cruise-corrected fits. The
  thinned depth set is unchanged (it is derived from the temperature / average-salinity profiles),
  so these add rows at the depths already kept. Each keeps its own `measurement_qual`. None carries a
  `variable`, so the Explorer's pooled variables do not double-count a sensor beside its average.
  Sensor-only preliminary cruises stay temperature-only in the plotter (Rasmus: an uncalibrated or
  drifting sensor reads badly in an anomaly).

**Consumers:** `climatology` has fewer rows (a cell absent is an anomaly left blank, never 0);
`obs_env` gains ten `measurement_type` partitions; `metadata/measurement_type.csv` flags them
`is_canonical` and declares the oxygen ranges. `calcofi4db::combine_sensor_pair()` is the tested
form of the sensor rule for any consumer.

## The climatology and the sections key on the station, not the grid cell

`grid_key` is a point-in-polygon into the 218 grid cells, and the inshore cells of the core lines
are ~2,350 km² boxes holding 2–4 real stations, all occupied every cruise since 2004 (`st30-ln90` =
90.30 · 90.28 · 90.27.7 · 88.5/30.1, 3.7 CTD occupations per cruise; `st35-ln86.7` 3.2;
`st40-ln83.3` 2.9; `st25-ln93.3` 2.7). `climatology` was grained on the cell, so the inshore baseline
blended stations 15–30 km apart where the gradient is steepest; ctd-transects drew one of them
(1,595 of 9,637 CTD occupations, 16.6 %, never drew — 26 % on line 90 since 2004) and the
Explorer's Sections lens averaged them. Three products, three answers within 30 km of the coast.

Now (calcofi4db 4.8.0): `climatology` is grained on **`site_key`** (the real station, read from
`sample`), with `grid_key` kept on the row as the station's modal cell (709 of 9,705 stations
straddle a cell edge across their occupations); its primary key and its export sort key follow.
`site_key` itself has one spelling — `printf('%05.1f %05.1f', line, station)` — applied to every
ingest's sample arm by `append_sample()` and gated at release by `check_site_key_format()`:
v2026.09.06 shipped 28 CTD casts carrying the source's own `Sta_ID` forms (`93.3    26.4`,
`0093. 060.0`, `090.0 27.76`, `88.50 030.1`) beside the canonical form.

**Consumers:** `climatology` gains `site_key` (first after `dataset_key`) and keeps every other
column; a cell-level reader pools rows by `grid_key` weighted by `clim_n` (exactly the old value).
ctd-transects (PR `site-key`), the Explorer's Sections lens (PR `site-key`) and
`calcofi4r::cc_climatology()` (1.23.0) key on the station; inshore anomalies move by up to ~1 °C at
the surface. The 28 CTD `site_key` values change spelling (same station). Nothing else changes.

## Reference layers in `spatial_layers.json`

The boundary-layer sidecar gains three registry rows with `role = reference` (calcofi4db 4.8.0,
plan 2026-09-09): `osm_land` (the OpenStreetMap land polygons the Explorer draws over the sea floor
and the data, `_spatial/osm_land.pmtiles`), `gebco_gazetteer` (219 undersea feature names from the
IHO-IOC GEBCO Gazetteer, a `label` layer) and `esri_ocean_reference` (a `raster` row). Every layer
now carries `role`, `source_type` and `source_url`; a reference row's `n_features` / `bbox` come
from `reference_layers.json`, it has no names and no memberships, and it is not in the `spatial`
table — nothing else in the release changes.

## Every released key is declared, and every declared key is measured

The release has always declared its keys in `relationships.json` and drawn them in the ERD, but
it gated only a few: the core primary keys (`check_core_pk_unique()`, since v2026.08.25's 4,855
duplicate `sample_key`s) and the `cruise_key` edges (`check_cruise_key_integrity()`). The other
~50 declared foreign keys were true by construction and never measured, twelve of the 23 released
tables declared no primary key at all (`obs_bio`, `obs_env`, `sample_root`, `sample_spatial`,
`climatology`, `spatial`, `spatial_attribute`, `dataset`, `lookup`, `taxon_group`, the two
supplementals), and 28 of the 88 foreign-key rows named thirteen per-dataset tables the release
retired in 2026-07 (`casts`, `ctd_cast`, `zooplankton_tow`, …).

Now (calcofi4db 4.7.0): every released table declares a primary key — each measured unique on
v2026.09.06 before being declared — `relationships.json` carries only edges whose both ends ship
(the ingest-only rows stay in `relationships_all.csv` as `released = FALSE`), and a new
`integrity.json` sidecar beside `catalog.json` records, per key, rows / distinct / duplicates /
NULLs and rows / NULL / orphans, with `ok` overall. A duplicate or NULL primary key or any
foreign-key orphan stops the release (`release_database.qmd` `relationship_integrity`, after every
released table exists), and `test_release.qmd` refuses to promote a release without an all-ok
`integrity.json`. A NULL foreign key is a nullable edge (an env row's `taxon_key`, an ungridded
sample's `grid_key`), not an orphan. `metadata/release_tables.csv` describes `sample_root` and
`sample_spatial` at last (both were absent from `metadata.json`, so the schema browser could not
list them) and drops the retired `obs_freq` row.

Thirteen edges the release always had but never declared are declared now, each measured at 0
orphans first (`spatial_attribute` → `spatial`, `cruise` → `ship`, the supplementals' `cruise_key` /
`grid_key` / `dataset_key` / `measurement_type`, `sample_root`'s three, `sample_spatial.root_id`,
`obs_attribute.dataset_key`). One is deliberately **not**: `obs_mets_full.sample_key` → `sample`
resolves for 73,607 of its 2,168,850 distinct keys — `sample` holds the 77,795 underway events the
METS headline series keys to, while the full-resolution table mints one key per record that
never reaches `sample`. Declaring it would fail the release on 18,990,343 orphans; leaving it
undeclared hides a real gap, so it is recorded here and as a workflows issue for the METS ingest
until the supplemental's events either join `sample` or carry a documented per-record key.

**Consumers:** `relationships.json` lists fewer, truer edges (the 60 with both ends released, deduplicated, plus the thirteen above) and a primary key for every table; `integrity.json` is new and optional to read;
`metadata.json` gains `sample_root` and `sample_spatial`. Nothing in the parquet changes.

## A publisher re-run over a frozen release costs a hash comparison, not a rebuild

The four generic publishers now check before they build or upload, so they can sit in the
regular `targets` run without regenerating identical outputs (2026-09-06):

- `publish_to-netcdf.qmd`: a file whose `db_release` attribute names this release and that the
  published manifest already lists is returned, not rebuilt; `cc_netcdf_plan()` recognises a
  version already published with these bytes and `cc_netcdf_publish()` then writes nothing —
  before, every render rebuilt every file (the CTD supplemental is an hour and 3.6 GB) and
  re-wrote `manifests.json` with a new `generated_utc`.
- `publish_to-erddap.qmd`: the config header carries the release date, not the render date, so
  an unchanged config is unchanged; only datasets whose definition changed (or are new) are
  flagged for reload, where every one of 34 was flagged each run.
- `publish_to-obis.qmd`: an archive already built for this release is reused; the zip itself is
  now byte-stable (members stamped with the release date, calcofi4db 4.6.2) and the manifest's
  `generated_utc` moves only when the content hash does.
- `publish_to-edi.qmd`: a package already built for this release is reused; the export pins
  DuckDB's insertion order so the hashed CSVs are a function of the release objects.
- Every upload goes through `put_gcs_file(skip_unchanged = TRUE)` (calcofi4db 4.6.1): an object
  with the same MD5 is not sent again.

## Portal bundles are staged where a reviewer can see them

`publish_to-obis.qmd` and `publish_to-edi.qmd` (both first run against v2026.09.06) now copy what
they build to the public bucket at a deterministic address before any deposit —
`gs://calcofi-db/publish/dwca/{dataset_key}/{dataset_key}_{version}.zip` (+ manifest) and
`gs://calcofi-db/publish/edi/{dataset_key}/{dataset_key}_{version}/` — so a provider, and the
dataset page (*Archives & portals*, "built, not deposited"), can inspect a bundle before it goes to
the IPT or PASTA. The deposit itself stays a deliberate act (Decision 21; `CALCOFI_PUBLISH_EDI`).

## Dataset colours are re-spread so every dataset reads apart

The sixteen `dataset.color` values (each `ingest_*.qmd` front matter `dataset_meta.color`, carried by the `dataset` table
and `datasets.json`) were chosen one at a time as pastel tints. Measured on 2026-09-09 with a palette validator over all
pairs: the two closest biology datasets were ΔE 4.3 apart for normal vision and 1 under deuteranopia, fifteen sat
above the lightness band and thirteen under 3 : 1 on white. They are now one set found by search over OKLCH inside the
band the light and dark themes share (L 0.48–0.665, chroma ≥ 0.106), maximising the worst within-realm pair — biology
13.6 normal / 7 CVD, environment 14.7 / 8 — then the worst cross-realm pair (7.9), then assigned so that the
datasets that appear together (cufes and ichthyo, ZooDB and ZooScan, bottle and CTD …) are far apart; every colour is
≥ 3 : 1 on white and on navy. A dataset's name still travels beside its dot everywhere: twelve colours in one band cannot
all clear the validator's normal-vision floor (a packing bound), so colour stays a secondary cue by design.

**Consumers:** the landing page, the Explorer, db-viz-station and the docs read the release's colour and follow on
their next build; screenshots change; nothing is keyed on a hex.

| dataset | realm | today | revised | L · C · h (OKLCH) |
|---|---|---|---|---|
| `calcofi_bottle` | env | `#4dabf7` | `#718fdd` | 0.66 · 0.12 · 267° |
| `calcofi_ctd-cast` | env | `#3bc9db` | `#10a74a` | 0.64 · 0.18 · 149° |
| `calcofi_dic` | env | `#63e6be` | `#cf2407` | 0.55 · 0.21 · 32° |
| `calcofi_mets` | env | `#74c0fc` | `#5c5dad` | 0.52 · 0.12 · 281° |
| `calcofi_phytoplankton` | bio | `#12b886` | `#0b7454` | 0.50 · 0.10 · 165° |
| `cce-lter_picoplankton-bacteria` | bio | `#94d82d` | `#1f88cc` | 0.60 · 0.14 · 244° |
| `calcofi_phyllosoma` | bio | `#f783ac` | `#8c4f8e` | 0.52 · 0.12 · 326° |
| `cce-lter_zoodb` | bio | `#38d9a9` | `#17a490` | 0.65 · 0.11 · 180° |
| `cce-lter_zooscan` | bio | `#a9e34b` | `#885e08` | 0.51 · 0.10 · 77° |
| `cdfw_dungeness-crab` | bio | `#f76707` | `#f028c9` | 0.66 · 0.27 · 338° |
| `sio_pic-zooplankton` | bio | `#69db7c` | `#1551fd` | 0.53 · 0.26 · 264° |
| `cce-lter_euphausiids` | bio | `#b197fc` | `#9876fa` | 0.66 · 0.19 · 292° |
| `swfsc_cufes` | bio | `#ffd43b` | `#af8a11` | 0.65 · 0.13 · 89° |
| `swfsc_ichthyo` | bio | `#ffa94d` | `#d3115d` | 0.56 · 0.22 · 8° |
| `sio_mesopelagic-fish` | bio | `#5c7cfa` | `#a809d1` | 0.54 · 0.26 · 317° |
| `farallon_bird-mammal` | bio | `#ff8787` | `#d86d6f` | 0.66 · 0.13 · 20° |

## Every observed taxon has a record: `taxa.json`, the species catalog

The release has shipped the `taxon` table since v2026.07 and counted it on calcofi.io as "2,614
taxa". That is the size of a lookup table, not a number of organisms: 1,108 of its rows have no
observation at all — 904 are lineage ancestors (Biota, Animalia, Chordata …) and 204 are entries in
a dataset's vocabulary the sampling never met. The observed count on v2026.09.06 is **1,506**, and
**1,008** of those are identified to species; the remaining 498 stopped at genus, family, order or
class (*Sebastes* 18,187 rows, "Unidentified teleost" 72,797). Nothing published the lineage, the
per-year counts or the crosswalk, so no page could say which species a dataset holds.

New sidecar `taxa.json` beside `datasets.json` (calcofi4db 4.9.0 `build_taxa_catalog()`, schema
`taxa.schema.json` 1.0, ~2.4 MB). One entry per `taxon` row **with an observation at or below it** —
the 1,506 observed plus their 904 ancestors, 2,410 entries — each carrying its accepted name and
common name, rank and taxonomic status, the WoRMS · ITIS · GBIF · NCBI · iNaturalist ids, the
`parent_taxon_key` and the flattened lineage, its `taxon_group` memberships, `direct{}` (the
observations keyed to it) and `rollup{}` (it and every descendant: observations, taxa, species,
datasets, year span), and one block per dataset that observed it — observations, samples, years,
per-year counts, life stages — ending in `sources[]`, the `dataset_taxon` rows that resolve to it:
**what that dataset calls the taxon**, flagged `synonym`, `sp_to_genus` (a "… sp." name resolved to
its genus), `rekeyed`, `id_conflict` or `no_name` (a code only). Measured over v2026.09.06's 1,917
`dataset_taxon` rows: 1,704 use the accepted name, 120 carry only a code, 93 use a different name.

The two id flags say different things, and the difference matters on a page. A taxon is keyed by
exactly one authority; only a disagreement *there* is a re-key. **27 rows are `rekeyed`, all
Farallon** — an ITIS TSN the source gave that ITIS itself has deprecated, the row keyed to the
successor (`taxon.notes`: "itis:174550 deprecated in ITIS -> itis:1255048"). **27 are
`id_conflict`, all ichthyoplankton** — `worms:`-keyed taxa whose source ITIS hint differs from the
`itis_id` WoRMS publishes as its external link (`taxon.notes`: "2026-08-05: itis_id 622362 via
WoRMS external link"). Nothing was re-keyed in those 27: two authorities' crosswalks disagree, and
that is what the pill says. `datasets[]` lists
the ten datasets carrying taxa with their catalog colour and, per dataset, the vocabulary rows that
have no observation anywhere — the list a provider wants and no page had.

The record is generated and gated. `check_taxa_catalog()` re-measures every count against the
release's own `obs_bio`, requires every `parent_taxon_key` to resolve inside the record (a page with
a dangling breadcrumb is a 404), requires the roots' rollups to sum to `obs_bio`'s 1,257,902 keyed
rows, and requires unique page slugs and known datasets and flags; `release_database.qmd` step 3b′
stops the release on any failure and `test_release.qmd` refuses to promote without an all-pass
`taxa_catalog` gate. `taxa.json` joins `RELEASE_REQUIRED_OBJECTS`, so a release that does not carry
it cannot be promoted.

**Consumers:** additive — no existing object, table or column changes. calcofi.io/species/ is
generated from this file (one page per `taxon_key`, at `/species/{key with ':' written '-'}/`); the
landing page's Life tile and numbers band read its `counts`. A consumer that wants the crosswalk
reads `taxa[].datasets[].sources[]` instead of joining `dataset_taxon` by hand.

## Five bottle series declare their physical bounds, and eleven impossible values leave

`calcofi_bottle` declared no bound on any of its 26 series, so v2026.09.06 published a
99.00 °C and a 56.87 °C at 50 m (2020-07-33P4, station 93.3/30 — the same two bottles
read 9.50 and 21.06 PSU), six potential densities of 216–251 kg/m³ (2014-11-32NM,
2015-04-32NM) and one surface oxygen of −200.2 ml/L / −8,740.6 µmol/kg / −3,605 %
saturation (2020-07-33P4, station 90/30). `ingest_calcofi_bottle.qmd` § Declare and
Enforce Physical Bounds now declares `temperature` −2…40 °C and `sigma_theta` 15…35 kg/m³
(the CTD's own bounds for the same quantities) and `oxygen_ml_l` −0.5…15,
`oxygen_umol_kg` −20…700, `oxygen_saturation` −1…250 — the oxygen floors just below
zero so the four Winkler zeros of the line 83.3 oxygen minimum (−0.010 ml/L, 550–570 m,
1995–2002) stay — and `drop_out_of_bounds()` removes the eleven rows before `obs` is
emitted, as the CTD and METS ingests already do. This was not a DBF-era 9-fill: no
bottle series carries a −99 / 999 pattern, and the 1,739 temperatures at exactly 9 or
99 are 9.0 °C readings. Salinity declares nothing yet — cruise 2021-05-3322 reads
24.19–27.06 PSU in 918 bottles to 568 m across 39 stations (Q13, `high`), a whole
cruise the provider must rule on before any floor is set. **Consumers:** `obs_env` loses
11 `calcofi_bottle` rows; `measurement_type.valid_min` / `valid_max` are populated for
the five series and `check_measurement_bounds()` treats them as declared.

## A label per crosswalk key: `metadata/variable.csv`

`measurement_type.variable` has said which raw series measure the same thing since 4.6.0, but there
was nowhere to put a name for the key itself — only `description` on each member row, a column note
("DO average station-corrected"). New registry **`metadata/variable.csv`** (`variable, label,
description, units, nerc_p01, category, is_unified`; calcofi4db `read_variable()` /
`register_variables()` / `check_variable_registry()`, mirroring the `measurement_type.csv` helpers)
carries one row per key the release carries with `variable` set. Seeded with the five pairs the
Explorer's `UNIFIED` already carries — `temperature`, `salinity`, `oxygen_ml_l`, `oxygen_umol_kg`,
`sigma_theta` — checked against D3's crosswalk rule (identical NERC P01 · same units or a declared
conversion · same kind of sample · not plausibly the same physical samples) by the new, reproducible
`libs/measure_variable_crosswalk.R`: of the **15 NERC P01 concepts shared by more than one released
env series** (84 series, 5 datasets, v2026.09.06), only these four pass all four criteria outright.

`sigma_theta` is the fifth and, measured strictly, does not: the bottle's own computation carries
NERC P01 `SIGTEQ01` ("by computation from salinity and potential temperature") while the CTD's
carries `SIGTPR01` ("by CTD and computation …") — two different concepts for the same physical
quantity. `variable.csv`'s `sigma_theta` row therefore declares no `nerc_p01` rather than picking a
side, the same exact-match rule as everywhere else in these registries; `register_variables()` and
`check_variable_registry()` both refuse a row whose `nerc_p01` disagrees with a member series' own
value, so this could not have been filled in by mistake. Everything else the crosswalk touches stays
apart: the CTD's own embedded `btl_*` bottle table (nitrate, nitrite, phosphate, silicate, ammonium,
phaeopigment, depth, chlorophyll, temperature) shares a P01 with the bottle dataset's series but
fails criterion (iv) — **measured**, 5,061 of `calcofi_bottle`'s 8,352 casts 1993–2021 (60.6%) have a
matching `calcofi_ctd-cast` cast at the same `site_key` within one hour (5,061 of 16,431 CTD casts,
30.8%), plausibly the same physical bottles. The bottle's `alkalinity_rep1` / `dic_rep1` replicates
and DIC's `alkalinity` / `dic` means share a P01 too but fail criterion (iii) (replicate vs mean);
two `proposed` questions ask the DIC provider whether the bottle's replicate is one of the two
analyses averaged into the reported value (`calcofi_dic_08`, `calcofi_dic_09`). **Consumers:**
additive — a new registry file and three new calcofi4db functions; `coverage.json`'s `variables[]`
gains `label` from this registry at the next step (WS-M2).
## Six underway and CTD series declare their physical bounds; the 9,895 °C sea surface and the PAR fills leave

v2026.09.06 published a **sea-surface temperature of 9,895 °C** (`calcofi_mets` `sst_c`: three
readings of 9,231–9,895 °C on 2016-07-32I1), an intake flow of exactly −99 L/min beside 39
smaller negatives (`uws_flow`, 2016), fourteen negative bottom depths (`bottom_depth_m`, five
cruises 2020–2022), a thermosalinograph salinity of 45.6 PSU (`tsg1_salinity_psu`), and from the
CTD files a surface PAR (`spar`) running from −3.07 × 10¹⁷ to 2.01 × 10¹⁶ µE/m²/s — 31,623 values
on ten cruises 1995–2008, 6 % of the series — and an in-water PAR (`par`) with 34,233 values at
exactly 9999, a fill, plus 1,065 more above 5,000 and eight below −100 (24 cruises, 1994–2025).
None of the six series declared a bound, so nothing caught any of it; the measurements catalog
(below) surfaced them on 2026-09-10 and Ben ruled them a certain bug, not a question.
`ingest_calcofi_mets.qmd` now declares `sst_c` −2…40 °C, `tsg1_salinity_psu` 0…45 PSU and
`bottom_depth_m` 0…11,000 m (the registry's own bounds for the same quantities on other
series) and `uws_flow` ≥ 0; `ingest_calcofi_ctd-cast.qmd` declares `par` and `spar`
−100…5,000 µE/m²/s (the sun delivers ~2,500 at the top of the atmosphere; a dark reading sits
within a few units of zero). Both ingests already ran `drop_out_of_bounds()` against the
registry, so the values leave at the ingest and each now asserts nothing remains outside a
declared bound. Not bounded, and noted for the provider: `sss_psu` reads below 20 PSU on a
quarter of its rows (a flushed intake, not a sentinel), `rel_humidity_pct` reaches 120 %, and
the CTD's `beam_attenuation` / `transmissometer` carry calibration negatives. **Consumers:**
`obs_env` loses 3 + 40 + 14 + 2 `calcofi_mets` rows and 31,623 + 35,306 `calcofi_ctd-cast`
rows at the release grain (the full-resolution `obs_mets_full` / `obs_ctd_full` lose more; the
ingests report the count); `measurement_type.valid_min` / `valid_max` are populated for the
six series; the measurements catalog reports a series' observed range within its declared
bounds and counts what fell outside.

## Every released measurement has a record: `measurements.json`, the measurements catalog

The release writes one more sidecar beside `taxa.json`: **`measurements.json`**, the environment
half of the catalog (plan 2026-09-10 § D2/D4, Appendix A; `calcofi4db::build_measurements_catalog()`,
schema `measurements.schema.json` 1.0). One entry per measurement **key** `obs_env` carries — the
registry's `variable` where one is set, so the bottle's `temperature` and the CTD's
`temperature_ave` are one page, else the `measurement_type` — and under it one `series[]` per
`measurement_type` × dataset with that dataset's own source column and flag column, its values by
year, calendar month, eight depth bands and quality code, the observed min / 5th / median / 95th /
max, the registry's declared bounds and the NERC P01 / P06 ids. Measured on v2026.09.06: **79
measurements over 84 series in 5 datasets, 25,006,583 values** (Physical Oceanography 39 ·
Productivity & Pigments 14 · Nutrients & Chemistry 12 · Carbonate System 6 · Meteorology & Sea State
4 · Picoplankton & Bacteria 4), 167 KB; `counts.full_rows` adds the two full-resolution
supplementals for the 316,328,163 the front door's band counts. A registry row that never reaches
`obs_env` from a supplemental's own source table — a raw CTD sensor, a thermosalinograph past the
first — gets no page and is listed under its dataset in `full_resolution_only[]` with the table it
does live in (21 for the CTD files, 37 for METS, none elsewhere). `related[]` names the other keys
sharing a NERC P01 concept that are kept apart on purpose, with the reason — all 76 directed pairs
carry one (`same_bottles` 36 · `underway_vs_cast` 16 · `sensor_vs_mean` 8 · `pre_qc_twin` 6 ·
`replicate_vs_mean` 4 · `paired_sensors` 4 · `same_casts` 2): P01 identity says two series name the
same quantity, never
that they may be pooled — the CTD files' own `btl_*` bottle table is plausibly the same physical
bottles as the bottle dataset. **A series' `observed{}` is computed within its declared bounds** and
what falls outside is counted in `out_of_bounds{n, min, max}`, so a page shows the range a reader
would use while the breach stays visible: the bottle's `temperature` reads 1.44–31.14 °C with
`out_of_bounds` `{n: 2, min: 56.87, max: 99.00}`, its `sigma_theta` 16.996–28.139 kg/m³ with six
values of 216.6–250.8, METS `sst_c` 0.007–25.89 °C with three of 9,231–9,895, and CTD `par` /
`spar` 4,997 µE/m²/s with 35,306 and 31,623 outside — the rows the two bounds entries above drop at
the ingest, still present in v2026.09.06 and now stated rather than averaged into a page's range.
Thirteen series carry `sentinel_suspected` (a declared bound broken, or — where nothing is declared
— an extreme both past ±99 and 100× the series' own 5th/95th percentile, which is what catches the
bottle's `r_oxygen_umol_kg` at −8,740 and the CTD's `specific_volume_anomaly` at −63,921); 18 series
still declare no bound at all. The raw counts are untouched, so the arithmetic gate still equals
`obs_env`'s row count. Nothing on a
measurement page is authored: the label comes from
`metadata/variable.csv` and, absent a row, falls back to the canonical series' registry description
carrying a `no_label` flag. `measurements.json` joins `RELEASE_REQUIRED_OBJECTS` and a
`measurements_catalog` gate in `test_release.qmd` feeds the promote gate — schema valid, the counts
re-measured against this release's own `obs_env`, and the sum of `series[].n_values` over every key
equal to `obs_env`'s row count, which is what catches a series counted twice. **Consumers:**
calcofi.io reads it to generate `/measurements/` and one page per key (the landing page's
Measurements index); `coverage.json`'s `variables[]` gains a `label` field from
`metadata/variable.csv` — filled for the five unified keys, which the CalCOFI Explorer may read in
place of its hard-coded `UNIFIED` labels — and `valid_min` / `valid_max` from the registry so a ramp
or an axis can be clipped at first paint. Five of the 79 measurements carry an authored label; the
other 74 fall back to their canonical series' description with a `no_label` flag. No released table, column or row changes.

# v2026.09.06

## The dataset catalog record says what a page needs to say (schema 1.1)

`datasets.json` grew five fields, all additive, all read from a registry the team already edits
(calcofi4db 4.5.0; UI plan 2026-09-05 § D-9). Each of them retires a hand-typed map in
calcofi.io's own generator — a fact with two homes drifts:

- `category.description` — the one line a category tile shows. Already a column of
  `metadata/category.csv`, simply not carried.
- `distributions[].grain_description` — what an ERDDAP grain *means*. A page that says
  `length/stage frequency` and nothing else asks the reader to guess.
- `objects[].table_description` — the first sentence of what `metadata.json` already says the
  table is, so a parquet row names more than a table and a size.
- `registrations[].id` and `.title` — the identifier a portal knows the dataset by
  (`edi.109.4`, `gov.noaa.nodc:0301029`, an OBIS uuid) and what it calls it. Curated in
  `metadata/distribution.csv` where a row exists — **all 31 rows that name one already did**,
  and every one agrees with `derive_registration_id()`, which is the same rule the site used as
  its fallback. The one row with no id is a UC San Diego Library *search* URL, which names none.
- `portals[]` — every portal the record can mention, with what it is, from `metadata/portal.csv`.
- **CalCOFI's own ERDDAP has one id, `erddap`** (calcofi4db 4.6.0). The record used to carry it
  twice — `erddap` from `portal.csv` and the registrations, `erddap-calcofi` from the
  distribution registry's vocabulary — so `portals[]` listed the same portal under both and a
  consumer had to look either up. `distribution_portals()`, `classify_portal()` and the seven
  legacy-id rows of `metadata/distribution.csv` now say `erddap`; the old value is rejected by
  `read_distribution_registry()` rather than aliased. **Consumers:** a reader keyed on the
  literal `erddap-calcofi` (calcofi.io's `_plugins/datasets.rb` accepted both) finds only `erddap`.
- **`distributions[]` opens with the dataset's STAC collection** (`format: stac`,
  `{stac root}/collections/{dataset_key}/collection.json`; calcofi4db 4.6.0). The catalog
  `build_stac()` writes was on the bucket but nothing in the record pointed at it, so the dataset
  pages linked a site-side guess. Holdings, which have no collection, get no row.

## Coverage measures the season, and a second extent

- `coverage.months` — observations by calendar month, twelve counts per dataset. CalCOFI is a
  quarterly survey, so *which* quarters a dataset covers is coverage; a years sparkline cannot
  show it.
- `coverage.bbox_robust` — the 2.5–97.5 percentile of a dataset's own sampling positions, with
  `n_positions`. **Not a correction.** A second, measured number beside the asserted `bbox` so
  the two can be compared, which is what the new `bbox_implausible` warning does. It fires for
  `swfsc_ichthyo`: its record extent reads 0–54° N × 180–77° W from bad upstream coordinates
  while its sampled positions sit in the California Current. The bbox is the provider's to fix —
  **question Q16 to SWFSC** (`metadata/swfsc/ichthyo/questions.csv`, `proposed`, asking whether
  there are sentinel or mis-signed coordinates and a flag to filter on) — and until it is
  answered the release carries both numbers so a consumer can choose. Nothing is deleted:
  `check_measurement_bounds()` bounds a *value*, not a coordinate.

**Consumers:** nothing removed or renamed, so a reader on schema 1.0 is unaffected.
`test_release.qmd` now asserts `schema_version == "1.1"` and blocks on
`grain_without_description`; `registration_without_id` and `bbox_implausible` are reported as
warnings a human reads. calcofi.io deletes its five marked fallbacks when this release renders.

## Every biological dataset can now leave as a Darwin Core Archive

`publish_to-obis.qmd` (generic, `calcofi4db::dwc_*()`, ≥ 4.4.0) builds one archive per dataset
whose taxa resolve to WoRMS — Event core from `sample`'s adjacency list, Occurrence from
`obs_bio` + `taxon`, eMoF from `sample_measurement` + `obs_attribute` + `obs_env`, `meta.xml`
from the term map and `eml.xml` from the release's own `eml/{dataset_key}.xml`. It supersedes
`publish_ichthyo_to-obis.qmd`, which read the `swfsc_ichthyo` source tables directly and has
been unrunnable since the core consolidation retired them, and which is why nine other
biological datasets had no OBIS route at all. Ten archives build clean at v2026.09.05:
213,813 / 482,250 / 613,576 events / occurrences / eMoF for ichthyo, plus cufes, bird-mammal,
phytoplankton, zooscan, euphausiids, zoodb, phyllosoma, dungeness-crab and mesopelagic-fish.
Nothing is uploaded by the pipeline: the IPT copy is a deliberate manual act gated on the
archive manifest's `content_hash`.

The vocabulary ids the registries carry now reach a portal for the first time.
`measurement_type.nerc_p01` / `units_nerc_p06` become `measurementTypeID` / `measurementUnitID`
(241,871 of ichthyo's 613,576 eMoF rows carry a P01, all of them a P06 — the published 2026-03
archive carried none); `gear.csv` supplies a per-gear `samplingProtocol` sentence in place of one
hand-typed string; `life_stage.csv` supplies `lifeStage`, and its two "not a life stage" values
(`damaged`, `invert`) go to `occurrenceRemarks` instead. An id absent from a registry ships empty,
never invented.

**`occurrenceStatus` is measured, not assumed.** Six datasets record their zeros (cufes,
phytoplankton, zoodb, zooscan, phyllosoma, dungeness-crab) and those rows publish as `absent`.
Four are positive-only (ichthyo, euphausiids, bird-mammal, mesopelagic-fish): a surveyed-empty
sample simply has no row, so an absence could only be derived from `sample_root` minus the
positives — a claim about a sampling protocol, not about the data. None is derived; each is a
question for its provider.

**Gaps the export measured, and did not paper over.** 409 `calcofi_phytoplankton` region pools
carry no `datetime`, so 64,643 of its occurrences cannot index at OBIS; 155 `cce-lter_zoodb` tows
carry neither date nor coordinates (12,573 records); 1,563 `swfsc_cufes` underway samples carry no
coordinates (8,897 records); 123 `farallon_bird-mammal` occurrences have no WoRMS id; and 26,049
`obs_bio` rows across four datasets carry a dataset-local taxon key with no scientific name
(zooscan 23,380, phytoplankton 1,906, bird-mammal 762, mesopelagic-fish 1) and cannot be
Occurrences at all. Each is reported per dataset, never dropped silently.

## A generic EDI publisher turns the release EML into a data package, per dataset

`publish_to-edi.qmd` (plan § D-6/D-8, WS-E3) is the third generic publisher over the
frozen release, alongside `publish_to-netcdf.qmd` and `publish_to-erddap.qmd`: parameterised
by `dataset_key` (default the three program datasets with no existing archive —
`calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_mets`), it exports each core table's rows for
the dataset as a CSV `dataTable` entity, pairs them with the release's own `eml/{dataset_key}.xml`
(`calcofi4db::build_eml()`, entity `physical` rewritten from the release parquet object to the
exported CSV), and writes `data/edi/{dataset_key}/{dataset_key}_{version}/` plus a manifest
(`content_hash`, `package_id`, `evaluated_utc`, `uploaded_utc`). A shared vocabulary table with
no `dataset_key` column (`measurement_type`) is named whole as an `otherEntity` rather than
duplicated per dataset; a `supplemental` full-resolution table (`obs_ctd_full`, `obs_mets_full`
— hundreds of millions of rows, partitioned by `cruise_key` not `dataset_key`) is excluded and
the exclusion recorded in the EML's own `additionalMetadata`, never silently dropped.

**The non-interference rule from `publish_to-obis.qmd` applies here too**: a dataset whose own
`link_data_source` is itself an EDI/PASTA package, or whose record already carries a
`kind = "archive"` distribution on `portal %in% c("edi", "knb-lter-cce")`, is refused — reported,
not published — so a CCE-LTER-owned package (or any provider's own EDI record) is never
republished under a CalCOFI-owned one.

`EDIutils::evaluate_data_package()` runs against EDI's PASTA **staging** environment on every
render that has credentials (`EDI_KEY`, or `EDI_USER`/`EDI_PASS`); without them the notebook says
so and skips cleanly. `create_data_package()` / `update_data_package()` — which mint or revise a
real package — run only under `CALCOFI_PUBLISH_EDI=true`, against `env = "production"`, and
record the minted package id in the new `metadata/edi_packages.csv` registry. The pure
classification/entity-rewrite logic lives in `libs/edi_entities.R`
(`scripts/test_publish_edi.R`, no network).

## The release record now has a public rendering, one page per dataset

`datasets.json` (schema 1.0, `build_dataset_catalog()`) is no longer only a sidecar: calcofi.io
opens on the dataset grid it describes, and every dataset and holding has a page at
`https://calcofi.io/datasets/{dataset_key}/` with its coverage, every endpoint it can be reached
through, its registrations, its citation and schema.org JSON-LD. The machine surfaces ship with it —
`calcofi.io/data.json` (DCAT-US 1.1, harvestable by any CKAN), `calcofi.io/datasets/sitemap.xml`,
and `{dataset_key}.json` / `.jsonld` beside each page.

Nothing about a dataset is written in the landing repo: the pages are a rendering of the promoted
release, refreshed by `CalCOFI/CalCOFI.github.io` `refresh.yml` on the `gh_dispatch` row
`test_release.qmd` already carries, so they follow a promotion within minutes and can never describe
an unpromoted release. Until the next promoted release carries `datasets.json`, the site builds from
the 2026-09-05 staging record through a documented `DATASETS_RELEASE_URL` bridge.

**Consumers:** a record's `visibility: internal` is now load-bearing in public — such a dataset gets
no page, no sitemap entry, no `data.json` row and no search row. The two record gaps the pages found
are fixed in the same round (calcofi4db 4.2.x): ERDDAP titles no longer reach the record as a literal
`\u2014`, `coverage.variables[]` carry units and NERC P01 URIs, and `coverage.taxa[]` names the top
50 taxa so the catalog's search can match a taxon.

## Every dataset ships an EML 2.2 document: `eml/{dataset_key}.xml`

The release now writes **one EML 2.2 document per dataset** into `eml/` beside `datasets.json`
(`calcofi4db::build_eml()`, >= 4.2.0), generated from the record and the descriptive sidecar. It is
the metadata document every publisher shares: the Darwin Core archive's `eml.xml`, the EDI data
package, ERDDAP's globals and the dataset page's JSON-LD all derive from it, so those four cannot
disagree, because none of them is typed twice. Until now the only EML CalCOFI produced was
`publish_ichthyo_to-obis.qmd`'s, built from strings hand-typed inside that notebook — the one place
a provider cannot edit and the record cannot see — and only for `swfsc_ichthyo`.

Each document carries the title, short name and abstract from the record; the creators (the
sidecar's `creators[]`, else `pi_names` with the provider organization); the licence and its URL
from `metadata/license.csv`; the GCMD keywords under their thesaurus plus the category and the
observed variables; the **measured** geographic bounding box and year span, and the taxonomic
coverage `coverage.json` resolved (WoRMS / ITIS `taxonId` per taxon — 963 classifications for
`swfsc_ichthyo`); the methods, study extent and sampling description from the sidecar with
`metadata/gear.csv`'s `dwc_samplingProtocol` sentences for the dataset's `tow_type`s; a `dataTable`
per released table whose `attributeList` comes from `metadata.json`'s `columns{}` (label,
definition, unit, storage type) and whose `physical` block carries the content-addressed object's
bytes, SHA-256 and URL; and an `additionalMetadata` block with the release and dataset citations.

- **A release gate**: `check_eml()` runs `eml_validate()` against EML 2.2's XSDs (local, no network)
  plus the required-element checklist EDI's evaluate applies, and `assert_eml()` fails the release
  on any non-exempt error — `invalid_eml`, `no_title`, `no_abstract`, `no_creator`, `no_pub_date`,
  `no_license`, `no_geographic_coverage`, `no_temporal_coverage`, `no_data_table`. `eml/` joins
  `RELEASE_REQUIRED_OBJECTS`, so `promote_release()` refuses a release without it.
- **Nothing is invented.** An absent optional field is omitted; a missing required field is a
  finding, exempt only while an open/proposed `questions.csv` row on `related_table = dataset` names
  it — the same rule the citation contract uses. Two fallbacks are derivations from a registry, not
  values typed into code, and each is reported so it stays visible: an `organizationName`-only
  creator taken from `provider.csv` when the record names no person (4 of 16 datasets), and the
  CalCOFI role address `data@calcofi.io` as the contact when no provider address is on record
  (16 of 16 — `contact` is the emptiest field in the catalog and this is what it costs). A unit
  becomes an EML `standardUnit` only on an exact match; `count/10m2` and `count/1000m3` travel as
  `customUnit` carrying the release's own string rather than being coerced onto a near-neighbour.
- **Measured over the 16 records** (v2026.09.05 staging sidecars): 16/16 documents valid, 18 KB
  (`sio_pic-zooplankton`) to 366 KB (`swfsc_ichthyo`), 1.3 MB in all; 0 blocking findings; 6 `no_license` exempt
  on an open licence question (bottle Q10, ctd-cast Q28, mets Q29, picoplankton-bacteria Q06,
  pic-zooplankton Q08, ichthyo Q11); warnings `contact_role_address` x 16,
  `undocumented_attributes` x 16, `no_methods` x 14 (only ichthyo and the Dungeness crab have gear
  in `gear.csv`; no sidecar carries `methods_md` yet), `short_abstract` x 5 and
  `creator_from_provider` x 4, and `no_taxonomic_coverage` x 1 (`sio_pic-zooplankton`, whose taxa
  do not reach `coverage.json`). Every warning names a field a provider can fill in the Sheet.

## The release publishes a STAC catalog, and the sitemap follows the record

The release now also writes a static **SpatioTemporal Asset Catalog** (STAC 1.0.0) to
`gs://calcofi-db/stac/` — `calcofi4db::build_stac()` (≥ 4.3.0), a pure function of `datasets.json`,
`metadata.json` and `spatial_layers.json`: a root catalog, one collection per **public** dataset
(extent from the observed bbox and year span, `license`, `providers[]`, GCMD `keywords`,
`table:tables`, `sci:doi` / `sci:citation`), one **item per release** whose assets are that
dataset's parquet objects (`application/x-parquet`, `roles: [data]`, each with `table:columns` from
`metadata.json`, `file:size` and a sha256 `file:checksum`), its CF netCDF, its ERDDAP pages and its
ISO 19115 record, and one collection per spatial layer with its PMTiles. A `superseded` or
`retired` distribution is never published as an asset, and an `internal` dataset gets no collection.
`check_stac()` runs `stac-validator` when it is installed and always runs a structural check;
`test_release.qmd` fetches the published documents back off the bucket and re-checks them, so the
gate is on what is served, not on what was built. A staging run writes `stac-staging/`.
`stac-browser` at **calcofi.io/stac/** reads the root. **Consumers:** nothing changes for existing
readers — STAC is an addition beside `catalog.json`, and the pages keep reading `datasets.json`.

`datasets/sitemap.xml` (ODISCat record 3318) is now generated from the record too
(`build_datasets_sitemap()`): the calcofi.io dataset pages first — 16 datasets + 17 holdings — then
every `current`/`external` record at another portal, and **never** a `superseded` or `retired` one;
`lastmod` is the release date or the sidecar's own edit for a page, and what the portal itself said
for an external record. `observe_distributions()` asks each portal weekly by its `portal.csv`
`observe_method` and writes `metadata/distribution_observed.json` — 58 distributions at 2026-09-05
(32 curated rows + the holdings' links): 53 live, 4 EDI packages superseded by a newer revision, 1
unreachable. Nothing is ever deleted from `distribution.csv`, and an unanswered request is
`unreachable`, never `retired`.

## Every dataset has a record: `datasets.json` (the dataset catalog, Phase 0)

The release now writes **`datasets.json`** beside `catalog.json` — one generated record per
`dataset_key` (schema 1.0; `calcofi4db::build_dataset_catalog()`, ≥ 4.1.0) joining what the release
already measured (the `metadata.json` dataset block, `coverage.json` rolled up per dataset —
years, stations, variables, taxa, depth span, the env variables a dataset contributes to another
category — and the content-addressed `catalog.json` objects that belong to it) with the reviewable
registries and with what the live services answer at release time. Each record carries
`distributions[]` (every endpoint: parquet objects with bytes/sha256/since, the CF netCDF, the
ERDDAP ids that exist on erddap.calcofi.io, the ISO 19115 record, the ingest notebook, the
calcofi.org page, the source portal, and the curated mirrors/archives — CoastWatch, EDI, NCEI,
OBIS, the IPT — with `status` and `superseded_by`), `registrations[]` (per portal
`published | planned | n/a`; ERDDAP and OBIS measured, Zenodo from the release DOI), `status`
(stage, priority, issue, blockers, open questions) and `visibility` (`public | internal`). It also
lists `holdings[]` (datasets CalCOFI has but has not ingested, from a sidecar with
`status: planned | external | archived`) and `reference[]` (cruise, ship, grid, spatial, the 19
boundary layers, the GEBCO bathymetry). One `datasets/{dataset_key}.json` per dataset sits beside
it. Nothing on calcofi.io's dataset pages (Phase 1) is authored by hand: they read this file.

- **A release gate**: `check_dataset_catalog()` fails the release on a record without a name, a
  registered category and provider, a description, a bbox or a download; a missing citation is
  exempt only while a provider question covers it (the citation contract's rule); every listed URL
  must answer a one-byte ranged GET (behind `CALCOFI_SKIP_LINK_CHECK`); `datasets.json` joins
  `RELEASE_REQUIRED_OBJECTS`, so `promote_release()` refuses a release without it, and
  `test_release.qmd` checks the file against `datasets.schema.json`, counts it against
  `metadata.json` and re-runs the check before promoting. At v2026.09.04 the finding table is
  `no_citation` × 5 (zoodb, zooscan, farallon, pic-zooplankton, cufes — all exempt, questions open).
- **Three new registries** under `metadata/`: `distribution.csv` (27 curated endpoints —
  the OBIS dataset `0e223f55…` and its IPT resource `calcofi_ichthyo`, eight CoastWatch mirrors of
  the ichthyoplankton, the SIO hydrographic mirrors, EDI/NCEI/DataZoo records, and the seven legacy
  erddap.calcofi.io ids marked `superseded` with their successor), `portal.csv` (16 portals with
  `harvests_from_us` and `observe_method`) and the generated `holdings.csv`;
  `dataset_status.csv` gains `publish_ncei` and `publish_caloos`, and `publish_erddap` now says
  `done` for the 16 datasets erddap.calcofi.io serves.
- **Descriptive metadata leaves the notebooks** (plan § D-9): a dataset's citation, licence, DOI,
  links, contact, keywords, creators and narrative now live in
  `metadata/{provider}/{dataset}/dataset_meta.yml`, the file a provider edits through the
  `metadata` tab of their question Sheet; the notebook keeps the structural keys. `read_calcofi_meta()`
  merges the two, so the release `dataset` table and every consumer see exactly what they saw
  before; a descriptive key left in a notebook now fails the workflows index.
- `coverage.json` `datasets[]` gains `life_stages` per dataset (the dataset's own values).
- Imported the CalOOS working sheet (41 rows) via the new idempotent `scripts/import_caloos_sheet.R`: 24 rows
  matched to already-integrated datasets became `dataset_meta.proposed.yml` proposals (creators, contact,
  keywords, funding, associated parties, QC notes, maintenance) plus 5 new `distribution.csv` rows (3 CalOOS
  module ids, a DataZoo phytoplankton mirror, a NOAA seabird/mammal transect-effort source); 17 unmatched rows
  became new holding sidecars (`metadata/{provider}/{dataset}/dataset_meta.yml`), including the discovery that
  EDI package knb-lter-cce.104 is mislabeled in the sheet (titled "nitrate isotopes", actually POC/PON). Added
  providers `jcvi`, `calpoly`, `stanford`; added category *Genomics & eDNA* and widened *Nutrients & Chemistry*
  / *Phytoplankton*. Filled GCMD Science Keywords (`keywords_gcmd`, 2–5 each, verified against the live GCMD
  KMS export) for all 16 ingested datasets.
- Descriptive dataset metadata split out of the 16 ingest notebooks into per-dataset sidecars
  (`metadata/{provider}/{dataset}/dataset_meta.yml`), editable by providers in a new `metadata` tab of
  their Google Sheet; `scripts/migrate_dataset_meta.R` did the one-off move byte-identically (117 keys,
  comments preserved, the release `dataset` table unchanged before/after), `scripts/sync_dataset_meta_sheets.R`
  does the push/pull (a `holdings` tab in the `calcofi` Sheet is the triage board for the 17 holdings). Both sheet
  scripts now authenticate as the calcofi-admin service account only (`scripts/lib_google_auth.R`), never interactively.
- **sccoos gets a question/metadata Sheet, and two CalOOS-import findings are on record with providers.**
  `sync_dataset_meta_sheets.R push` can now create a provider's spreadsheet itself when none exists yet
  (sccoos: two holdings, no ingest, so the questions script had nothing of its own to push) — sccoos's
  `metadata` tab is live. Two findings from importing the CalOOS working sheet are open provider questions
  rather than asserted facts: CCE-LTER's `knb-lter-cce.104` accession names a POC/PON dataset, not the
  nitrate-isotope dataset the sheet describes (`cce-lter_poc-pon-cce-region` Q01); and the CC0 licence the
  sheet claims for four NOAA CoastWatch ERDDAP mirrors is not confirmed by their own `.das` `license`
  globals, which carry only the generic ERDDAP disclaimer (`swfsc_ichthyo` Q11, `swfsc_cufes` Q07,
  `calcofi_bottle` Q10, `sio_pic-zooplankton` Q08).
- **`climatology` re-exports byte-identically now** (calcofi4db 4.1.1). `clim_mean` / `clim_sd` came out
  of DuckDB's parallel `avg()` / `stddev_samp()` with last-bit differences (≤ 1.8e-16 relative) on every
  run, so 60 of 71 partitions re-uploaded and were stamped as changed at each re-cut even with no data
  change (v2026.09.04 vs its staging twin, and two staging runs on 2026-09-05). Both are now rounded to six
  decimal places — nine orders of magnitude above the noise, well below any instrument's resolution — so an
  unchanged climatology reuses its objects. Row counts, grouping and the 1993–2013 / ≥ 3-cruise definition are
  unchanged. **Consumers:** the next release's `climatology` values differ from v2026.09.04's beyond the 6th
  decimal only.

## ERDDAP's own globals now say what the record says (WS-P2)

`publish_to-erddap.qmd`'s generated `datasets.xml` no longer states a program-wide default for
things the record can answer per dataset. `infoUrl` is now the dataset's own
`https://calcofi.io/datasets/{dataset_key}/` page — built from the key, never a per-dataset URL
list — instead of `link_calcofi_org` (which many datasets do not carry) or the bare
`https://calcofi.org` fallback. `license` reads the dataset's own `dataset_meta.yml` `license` id
through `metadata/license.csv` (its full name, e.g. "Creative Commons Attribution 4.0
International") and states `not specified` rather than the previous blanket `CC-BY 4.0` default —
which had been asserting a licence for datasets (`calcofi_bottle` among them) whose own citation
questions are still open. New `creator_name` / `creator_type` / `creator_email` / `creator_url` /
`institution` / `keywords` globals resolve from the sidecar's `pi_names` / `contact` /
`keywords_gcmd`, falling back to the registered provider organization (`metadata/provider.csv`) —
never CalCOFI program-wide — and are omitted, not written as the literal string `"NA"`, when the
record states none. **Also fixed at the source (I-13):** `title_of()`'s dataset-block suffix
(" — observations", " — sampling events", …) used a real em dash, which erddap.calcofi.io's own
`allDatasets` metadata re-serializes as the six-character literal `"—"` — a plain hyphen
(" - ") reads the same and survives every consumer, so titles are now ASCII-safe at the source
instead of being decoded downstream (as `observe_distributions()`, calcofi4db ≥ 4.2.x, already
does for existing ERDDAP metadata). **Consumers:** erddap.calcofi.io's `datasets.xml` and its
served globals change on the next deploy; no table, column or row is affected.

# v2026.09.04

## `dataset_taxon` says what the source claimed; the bird rule reads the classification; common names have one written order

Three things about taxa change under consumers, all from the taxon crosswalk plan
(`.claude/plans/2026-09-02 Taxon crosswalk — …md`, Phase 1, calcofi4db 3.29.0). None of them
moves a key for a taxon released today — the Phase 1 gate staged the Farallon vocabulary through
the new path and reproduced its v2026.08.25 `dataset_taxon` slice 156/156 rows, key for key.

- **`dataset_taxon` gains one column, `ds_source_json`** — a JSON object of whatever ids and rank
  the *source* supplied for that local taxon (`{"itis_id":174715}`,
  `{"worms_id":217452,"itis_id":161729,"gbif_id":2415428}`; NULL where it supplied nothing).
  It sits beside `taxon.worms_id` / `itis_id`, which are what the *authority* says, so the two
  can be audited against each other (`json_extract(ds_source_json, '$.itis_id')`). Nothing is
  dropped or renamed. The column is populated as each taxon-bearing ingest re-runs; a shard that
  predates it carries NULL.
- **Birds key `itis:` because their class is Aves, not because a source flag said so.**
  The rule is now stated once, in `calcofi4db::taxon_key_of()`: `itis:<tsn>` exactly when the
  taxon's class (from the cached WoRMS/ITIS lineage) is Aves and an accepted TSN resolves,
  otherwise `worms:<aphia>`, otherwise a dataset-local key the release refuses. Before, only the
  Farallon census carried an `is_bird` column, so an Aves taxon reaching the release through any
  other dataset would have keyed `worms:` and one species could have carried two keys. Every
  released bird already satisfies the new rule (113 of 113 `itis:` vocabulary taxa are class Aves;
  no `worms:` vocabulary taxon is), so no key changes; a bird with no accepted TSN would now key
  `worms:` with a note in `taxon.notes` rather than silently.
- **`common_name` follows one written precedence, applied at the release:** a human choice in
  `metadata/taxon_common.csv` (now tagged `source = "manual"`, 44 rows) > the CalCOFI species
  list's own name (`swfsc_ichthyo`) > WoRMS when it offers exactly one English vernacular > any
  other dataset's own name, in `dataset_key` order > empty. Until now the order was whichever
  ingest's shard happened to win the merge. **Consumers:** measured against v2026.08.25 with the
  new `apply_taxon_common()`, **50 of 2,125 taxa change `common_name`** — 48 that had none gain
  the vernacular their dataset publishes (20 `cce-lter_zoodb` group labels such as "COPEPODA
  CALANOIDA CALANIDAE", 8 `cce-lter_zooscan` operational classes, 20 `calcofi_phytoplankton`
  functional-group labels including "other" — see the open question below), and two are renamed
  by the tie-break for two codes of one dataset sharing a key: the code whose name *is* the
  taxon's accepted name wins, then `ds_taxon_key`. So `itis:562561` *Pterodroma sandwichensis*
  becomes "Hawaiian Petrel" (Farallon HAPE) rather than the old trinomial's "Dark-Rumped Petrel"
  (DRPE), and `worms:275218` *Syngnathus californiensis* becomes "Kelp pipefish" (ichthyo 792)
  rather than "Bay pipefish" (ichthyo 788, *S. leptorhynchus*, which carries the kelp pipefish's
  AphiaID in the species list — swfsc/ichthyo Q13). `worms:126175` *Sebastes* keeps
  "Rockfishes" under the same rule (Phase 0's plain `ds_taxon_key` order would have made it
  "Sunset rockfish"). Per rank: 44 manual, 790 `swfsc_ichthyo`, 186 WoRMS single, 175 other
  datasets, 930 empty.
- **`taxon_group` comes from a registry.** `metadata/taxon_group.csv` declares
  `calcofi:seabirds` = every observed taxon of class Aves, `calcofi:marine_mammals` = class
  Mammalia, and the eight phytoplankton functional groups by `ds_common_name`. **Consumers:**
  `calcofi:marine_mammals` loses the two sea turtles (*Chelonia mydas* `worms:137206`,
  *Lepidochelys olivacea* `worms:220293`) that the Farallon arm's "not a bird" rule put there;
  `calcofi:seabirds` is unchanged (94).

Two findings from the Phase 1 measurement that this entry does *not* fix, because each changes
released keys and needs a decision:

- **Phytoplankton species identity is collapsed in every release since the ingest.** The source
  vocabulary carries an AphiaID for 309 of its 393 codes (294 distinct — *Coscinodiscus
  curvatulus*, *Prorocentrum micans*, …), but `metadata/taxon_override.csv`'s six functional-group
  rows match on `taxa` and an override replaces the id a row already has, so 171 codes key the
  class Bacillariophyceae `worms:148899`, 144 key Dinophyceae `worms:19542`, 53 Coccolithophyceae,
  4 Dictyochophyceae: **22 distinct `taxon_key`s for 393 codes**, and the functional-group
  `taxon_group` rows hold one taxon each. The fix is the override rows (match the nine idless
  codes on `species_code`, not the group on `taxa`) or the override rule (fill, never replace),
  and it belongs with the phytoplankton ingest's move to `append_dataset_taxon()` (Phase 3).
- Rank 4 of the common-name order publishes `calcofi_phytoplankton`'s functional-group label as
  a `common_name` ("other" for 8 taxa, "undefined (code not in source definitions; Q05)" for 9).
  The label is what that ingest put in `ds_common_name`; whether it should be there is the
  ingest's question, not the precedence's.

## Farallon bird and mammal observations now come from ERDDAP

The `farallon_bird-mammal` ingest reads NOAA's ERDDAP tables (`CAC_FI_SBAS_tr` / `_obs` / `_sp` on
oceanview.pfeg.noaa.gov; workflows PR #77) instead of the March-2022 CCE-LTER DataZoo 255 export —
download-first into `data/cache/`, archived beside the DataZoo files under
`gs://calcofi-files-public/archive/farallon/bird-mammal/erddap/`, the fetch time stamped in the
ingest's `metadata.json` `sources[]` (the first ingest to measure its own `source_accessed`). The
behavior-code lookup is not on ERDDAP and stays DataZoo-sourced. Measured 2026-09-03 against the
DataZoo build that v2026.08.25 released:

- **Rows.** The two sources are identical for 1987–2018 (60,715 shared transects; every
  observation row equal). ERDDAP adds 2019, 2020 and 2022 (3,216 transects, 6,020 observation
  rows) and 490 more transects for January 2021, and carries **no observations at all for 2021**
  although it lists 956 transects for `CAC2021_1` and `CAC2021_7` — DataZoo had 625 rows for
  `CAC2021_7`. Taken as served, not patched from DataZoo; asked as farallon Q11 (high). `sample`
  60,715 → 64,421; `obs` 66,344 → 69,661; `obs_attribute` 82,418 → 87,813. `cruise_key`
  resolves on 98.1 % of transects (was 98.8 %): `CAC2022_8` joins `CAC2021_7` and `Fronts_0711`
  as NULL because the ichthyo cruise reference has no August-2022 cruise.
- **The vocabulary is declared by the ingest and resolved by the package** — the first dataset on
  the taxon plan's generic path (D3): `append_dataset_taxon()` stages ERDDAP's `_sp` codes, with
  DataZoo's ITIS TSN per code (committed once as
  `metadata/farallon/bird-mammal/species_itis_datazoo.csv`) riding along as `ds_source_json`, the
  audit value rather than the key's source; `check_dataset_taxon()` gates the render (0
  findings). For the 154 codes both lists share **every `taxon_key` is unchanged**, and the 126
  `taxon` rows already released agree on all eight compared fields (ids, name, rank, class,
  parent, kingdom, family); ERDDAP's scientific names are newer for 48 codes (*Hydrobates*,
  *Ardenna*, *Urile*, …), which changes `dataset_taxon.ds_scientific_name` only. The 28
  "Unidentified …" classes resolve through `metadata/taxon_override.csv` rows (Aves `itis:174371`
  / Mammalia `worms:1837`) instead of a fallback hard-coded in calcofi4db's farallon arm, and the
  37 existing farallon override rows match on `ds_taxa_code`.
- **Three things the source forced.** `SBIG` appears twice in `_sp` ("Mew Gull", "Short-billed
  gull") and is staged once, as *Larus brachyrhynchus*. `MEGU` — 71 observations, absent from
  `_sp` — is the pre-2021 code for the same bird and now keys **`itis:1192602`** with `SBIG`
  rather than DataZoo's *Larus canus* `itis:176832` (WoRMS has no record for *L. brachyrhynchus*,
  so the key rests on ITIS alone; 53 `obs` rows change key; farallon Q10). Nine ERDDAP-only codes
  the observations use gain a key — `GUMU` `itis:177011` (270 `obs` rows), `UNLP` (91), `SCMU`
  `itis:1192605` (36), `LOTU` `worms:137205` (26), `TOSP` `itis:1255031` (16), `CHSP` as the ITIS
  subspecies `itis:1255264` (11), `NABO`, `MABO`, `UNMT` — so on the 65,855 `obs` rows both
  builds share `taxon_key` is NULL on 727 where it was NULL on 1,177 (450 gained, none lost); six
  are excluded as gear, fish or land birds (`CRAB FISH TUNA VEVE RAPT WIWA`) and 28 unreferenced
  ERDDAP-only codes wait for the provider's include flag (Q10). `CSLI` and `XAMU`, DataZoo rows no
  observation ever used, are gone (`CASL` and `GUMU`/`SCMU` carry those observations).
- **Consumers:** this dataset's `obs` gains 2019–2020 and 2022 and loses 2021; `dataset_taxon`
  156 → 164 rows, `ds_source_json` populated (123 rows carry a DataZoo TSN);
  `calcofi:seabirds` 94 → 99 taxa (`itis:176832` leaves, six enter). The transect-level columns
  ERDDAP lacks (start/stop positions, bottom depth, Julian date) never reached the core `sample`
  table, so nothing released loses a column.

Two of the 123 Farallon cruises reach the release as transects with no observation at all —
2021-01-33UD (490 transects) and 2022-10-33UD (260) — because ERDDAP serves their effort but none of
their sightings (Q11, high). They are allowed by name in `release_database.qmd`'s orphan-cruise ratchet
rather than dropped: the effort is real as published, and a sample with no observation row never enters
an Explorer denominator. The allowance falls to zero when Farallon Institute answers.

## Phytoplankton taxa are keyed to species again

v2026.08.25 released **22** distinct `taxon_key`s for the **393** `calcofi_phytoplankton` codes.
The source (Venrick's Definitions sheet, resolved to WoRMS in the ingest's `taxon_worms.csv`)
supplies an AphiaID for 309 of them — 294 distinct species, genera and varieties — and six
`metadata/taxon_override.csv` rows matched on the functional-group label (`taxa`: "diatom,
centric" → Bacillariophyceae, "dinoflagellate, thecate" → Dinophyceae, …) replaced the id of
*every* code in their group, so 302 species-resolved codes keyed their **class**. 124,586 of
159,804 phytoplankton observations (78 %) carried a class-level `taxon_key`, and nothing said so:
the override rows were doing exactly what they declared. "That was a seriously faulty ingest to
miss that" (Ben, 2026-09-04).

**The rule now (calcofi4db 3.33.0): an override never replaces an id the source supplied,
unless it names the row by the dataset's own code.** A registry row matched on a non-code column
(`ds_common_name`, `ds_scientific_name`; the arm's `taxa`) applies only where the source supplied
no `worms_id` / `itis_id`; a row matched on `ds_taxa_code` applies always. The functional group
is what `taxon_group` is for; the species keeps its key. `resolve_dataset_taxon()` reports how
many rows each override was *skipped* for, and `release_database.qmd` shows the same table
(`report_taxon_overrides()`) beside the authority-coverage gate, with `check_taxon_registries()`
now failing the release on a registry row naming a dataset nothing supplies.

Measured on a **rendered** `ingest_calcofi_phytoplankton.qmd` (2026-09-04, the migrated
notebook against calcofi4db 3.33.0): **393 codes → 309 distinct `taxon_key`s**, up from 22 —
299 `worms:` (the source's own AphiaIDs exactly as supplied and all WoRMS-accepted; the 6 class
keys for the 70 codes the source could not resolve; the 3 genus keys of the code-matched
override rows) + the 10 allow-listed local codes (Q05). **302 codes change key**, every one a
code the source had resolved; 91 are unchanged, and no code is added or lost. The ten override
rows matched 376 vocabulary rows, applied to 74 and were skipped for 302 — a skip is the rule
working, and it is now reported rather than silent. The `taxon` shard grows 50 → **542** rows
(287 vocabulary taxa + 195 lineage ancestors), `taxon_group`'s phytoplankton memberships 24 →
**311**, and of the 159,804 phytoplankton `obs` rows (0 with a NULL `taxon_key`) **124,586**
carry a different key than v2026.08.25 released.

One thing the collapse had been hiding: code 600 "*Actinocyclus*, uncertain species." was
resolved in `metadata/calcofi/phytoplankton/taxon_worms.csv` to AphiaID 196347 — *Actinocyclus*
Ehrenberg 1831, a **nudibranch** genus (Animalia / Mollusca / Gastropoda) — a homonym of the
centric diatom *Actinocyclus* C.G. Ehrenberg 1837 (148944, Chromista / Heterokontophyta /
Bacillariophyceae). Every diatom code keyed the same class, so a wrong genus was invisible. The
source file is fixed and the code keys `worms:148944` on its own; the code-matched override row
that stood in for the fix is dropped.

Two smaller rules landed with it:

- **A group label is never a `common_name`.** "other" (×9), "undefined (code not in source
  definitions; Q05)" (×9), "coccolithophore", "silicoflagellate" and ZooScan's "eggs",
  "multiples", "nauplii", "others" reached `taxon.common_name` through the "any other dataset's
  name" rank: a functional-group label is the `ds_common_name` of every code in the group.
  `apply_taxon_common()` refuses any `taxon_group.csv` label and the label of any dataset-local
  key — 24 taxa lose a name that was not one. The group's own name in `taxon_group` is unchanged.
- **A bird with no source id keys `itis:` through name → AphiaID → linked TSN.** The generic
  path now carries the TSN WoRMS links to a name-resolved AphiaID; Farallon's `GUMU`, `MABO` and
  `NABO` resolve without their override rows (`SCMU`, `TOSP`, `CHSP` still need theirs — WoRMS
  links no TSN). No released key changes.

**Consumers:** `dataset_taxon.taxon_key` changes for 302 of the 393 `calcofi_phytoplankton`
codes and, through it, `obs.taxon_key` / `obs_bio.taxon_key` on ~124,600 phytoplankton
observations (class key → species or genus key); `taxon` gains 482 rows (287 phytoplankton
vocabulary taxa + 195 ancestors); `taxon_group`'s phytoplankton memberships grow from 24 to
311 rows, so a consumer that grouped phytoplankton by class-level `taxon_key` should group by
`taxon_group` (the functional groups) or `taxon.class` instead; `taxon.common_name` becomes NULL
for the 24 taxa that carried a group or operational-class label.

## Every taxon-bearing ingest stages its own vocabulary

Until now, seven datasets' taxon vocabularies were read by a `switch()` arm inside `calcofi4db`
that knew each source table's name and column shape — `species`, `phyto_taxon`, `zoodb_taxon`,
`zooscan_taxon`, `euphausiids_taxon`, `mesopelagic_fish_taxon`, `bird_mammal_species`. That is
the pattern calcofi4db 3.0.0 deleted from the core projection, for the reason it deleted it: the
contract was implicit, so renaming or dropping a column in a notebook changed the taxonomy
**silently**. Dropping `itis_id` from the Farallon species table would have un-keyed every
seabird — 92 % of that dataset's observations — with no error anywhere.

The vocabulary is now **declared by the ingest that owns the dataset and resolved by the
package** (`append_dataset_taxon()` → `ensure_taxon_xref()` → `ensure_taxon_lineage()` →
`resolve_dataset_taxon()` → `build_taxon_reference()` / `build_taxon_group()` →
`check_dataset_taxon()`). The declaration is explicit and a deviation is a hard stop at ingest
time rather than an `NA` at release; the ids the source supplied ride along in
`dataset_taxon.ds_source_json`; the key authority is read from the **classification**, not from a
source flag. **calcofi4db 4.0.0 deletes the seven arms**, so there is one copy of each dataset's
taxonomy and adding a dataset touches zero lines of the package.

Each migrated ingest was rendered and its `dataset_taxon` slice compared, code for code, with the
one v2026.08.25 released:

| dataset | codes | `taxon_key` identical | changed | other difference |
|---|---|---|---|---|
| `swfsc_ichthyo` | 1,167 | 1,167 | 0 | — |
| `calcofi_phytoplankton` | 393 | 91 | **302** | the section above |
| `cce-lter_zoodb` | 33 | 33 | 0 | — |
| `cce-lter_zooscan` | 23 | 23 | 0 | — |
| `cce-lter_euphausiids` | 37 | 37 | 0 | one row leaves (below) |
| `sio_mesopelagic-fish` | 90 | 90 | 0 | — |
| `farallon_bird-mammal` | 164 | 164 | 0 | migrated earlier, re-checked |

`ds_scientific_name` and `ds_common_name` are unchanged on every shared code, no code is added or
lost, `check_dataset_taxon()` reports 0 findings for each, and each dataset's `obs.taxon_key` NULL
count is unchanged (0 for ichthyo, phytoplankton, zoodb, zooscan and euphausiids; 1 for
mesopelagic fish — `UnidentifiedFish`, as before).

Three things the migration settles rather than preserves:

- **A dataset's own codes decide which taxa key locally, one at a time.** ZooScan's four
  operational bioclasses (eggs, multiples, nauplii, others — Q03) and the ten phytoplankton codes
  the Definitions sheet never defines (Q05, plus the source's own "other") are declared in the
  notebook with a reason each, so a genuinely unresolved taxon fails the render instead of hiding
  among them. The release-time allowlist stays as the backstop.
- **`cce-lter_euphausiids:euphausiidae` (`worms:110671`) leaves `dataset_taxon`.** It was minted
  by the composite-measurement crosswalk from `metadata/measurement_taxon.csv`'s rows for the old
  single-`Abundance` export, and no observation ever referenced it — the BTEDB export is species-
  and life-stage-resolved and `obs` joins on the numeric `taxon_id`. A staged dataset's
  `measurement_taxon` rows are no longer read as a vocabulary, so the unreferenced row goes.
- **A functional-group label is what the source *calls* a row, so it is `ds_common_name`.**
  Phytoplankton's `taxa` column lands there, which is the column `taxon_group.csv` matches on and
  the column the six functional-group override rows now match on — the group is a group, not a key.

`swfsc_cufes`, `calcofi_phyllosoma` and `cdfw_dungeness-crab` are unaffected: their taxa live in
`measurement_type` names, and that path is untouched.

**Consumers:** additive except the phytoplankton re-keys described in the section above. No
column is added or removed, and no other dataset's `taxon_key` changes.

## Every dataset carries a checked citation and a registered license, and the release cites itself

Nothing validated attribution before this release: 8 of 16 datasets shipped `citation_main`
empty and 13 shipped `license` empty (the other 3 were the free text `"CC BY 4.0"`), nothing
compared any of it to the source, no consumer could tell when a source had been read, and the
integrated database itself had no citation. Attribution is now a contract checked like links
(`calcofi4db::check_dataset_citation()`, 3.30.0), enforced by the workflows index build and by
the `dataset_coverage` chunk of the release, with the network half behind the same
`CALCOFI_SKIP_LINK_CHECK` as the link probe:

- **Structural, always:** `citation_main` non-empty with a year and a locator (a DOI, a URL in
  the string, or `link_data_source`); `license` an active id in the new registry
  **`metadata/license.csv`** (`CC-BY-4.0`, `CC0-1.0`, `CC-BY-NC-4.0`, `CC-BY-SA-4.0`, `US-PD`,
  `custom` — which requires `license_url` — and `unknown`); `doi` bare. An error blocks unless
  the dataset's `questions.csv` holds an `open`/`proposed` row on `related_table = dataset`
  naming the field, so a gap is either fixed or on record with the provider — never silent.
- **Against the source's own authority:** EDI's cite service, an NCEI landing page's "Cite as",
  an ERDDAP `.das`, DataCite (`rightsList` SPDX id, doi.org content negotiation), a `HEAD` on
  every declared DOI. Fetches are cached in `metadata/{provider}/{dataset}/citation_authority.json`
  (7 written: phyllosoma, phytoplankton, euphausiids, dic, farallon, mesopelagic-fish, cufes);
  a difference is reported as `authority_drift` with both strings and **never written into the
  YAML** — the author's string is the record. Today: 4 datasets `ok`, 14 findings exempt under
  the `proposed` rows WS-A1 filed plus one new one (mets Q31: its citation has no year and
  calcofi.org states no publication date), 2 drift warnings (dic abbreviates the NCEI author
  names; mesopelagic-fish differs from DataCite's APA form in initials and `[Dataset]`).
- **`source_accessed` is measured, never asserted.** Each dataset's `source_accessed` (DATE) +
  `source_accessed_method` land on `dataset`: an ingest's own `stamp_source_access()` record
  (`download` / `file_mtime`, via `build_metadata_json(sources = )`) when it has one, else the
  last commit of its `manifest.json` sidecar (`sidecar_commit`). Measured now: 15 datasets
  2026-08-25 (the v2026.08.25 pipeline run, commit 3ee7479) and cdfw_dungeness-crab 2026-09-03
  (its examined-only re-run) — the date the ingest last ran, which is the honest bound until
  ingests stamp their downloads.
- **The release cites itself:** *CalCOFI (YYYY). CalCOFI Integrated Database, release
  vYYYY.MM.DD [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California
  Department of Fish and Wildlife. https://doi.org/…* — `catalog.json` gains `citation` and
  `concept_doi` (Zenodo `10.5281/zenodo.22281994`; the version `doi` is written in by
  `publish_release_notes()` once the GitHub release tag mints it, catalog re-uploaded, objects
  untouched, `versions.json` records carry `doi`), and every `RELEASE_NOTES.md` appendix gains a
  **How to cite** section: the release line, then each dataset's `citation_main` · license.
  `.zenodo.json` and `CITATION.cff` at the repo root (generated by
  `scripts/build_citation_files.R`: the three partners as creators, every dataset's PIs as
  contributors, CC-BY-4.0 for the record while the code stays MIT) replace Zenodo's auto-filled
  "initial Zenodo release" metadata at the next tag.

**Consumers:** additive only. `dataset` gains `doi`, `license_url`, `acknowledgement`, `contact`
(from the YAML; empty where unset), `source_accessed`, `source_accessed_method`; `license` values
are SPDX ids (`CC-BY-4.0`, not `CC BY 4.0`); `metadata.json` `datasets[]` carries the same keys
plus `citation_others` as an array; `catalog.json` gains `citation`, `concept_doi` (and `doi`
once minted). Nothing is renamed or dropped.

## Every dataset's citation, license and DOI now carries the evidence for it, or a filed question

Eight of sixteen datasets shipped `citation_main` empty and thirteen shipped `license` empty, with
nothing checked against the source. Filled from each dataset's own authority (EDI's cite service +
its EML `intellectualRights`, ERDDAP `.das` globals, NCEI/DataCite landing pages, the DataZoo/
zoodb/zooscan portal policy panels), never invented: **calcofi_phytoplankton** and
**calcofi_phyllosoma** gained their EDI citation + DOI + license (CC0-1.0 and `custom`
respectively — reading the actual EML `intellectualRights` matters: EDI packages are *not*
uniformly CC-BY-4.0, and assuming so would have mislabeled both); **cce-lter_euphausiids** gained
its EDI citation + DOI + `custom` license + an `acknowledgement` field (new key, additive) carrying
the EML's required credit text; **cce-lter_zoodb** and **cce-lter_zooscan** gained a `custom`
license from their portals' Data Use Policy panels and had the NSF credit prose that was sitting in
`citation_others` moved into the new `acknowledgement` field (`citation_others` is reserved for
*additional* citations, not credit prose); **farallon_bird-mammal** and **swfsc_cufes** gained a
`custom` license pointing at their ERDDAP `.das`/data-sharing-agreement source. `calcofi_dic`,
`sio_mesopelagic-fish` and `cdfw_dungeness-crab` had their free-text `"CC BY 4.0"` normalized to
the SPDX id `CC-BY-4.0`; `dic` and `mesopelagic-fish` also gained a bare `doi:` field pulled from
their existing citation strings.

Where the source states nothing, the field stays empty rather than guessing, and a `proposed`
`questions.csv` row carries the value we'd apply once confirmed: a formal citation for zoodb (Q10),
zooscan (Q06), farallon (Q09), cufes (Q06) and pic-zooplankton (Q08, plus its license); a license
for cce-lter_picoplankton-bacteria (Q06); a citation year/URL, `US-PD` license and `pi_names` for
swfsc_ichthyo (Q10–Q12, the citation proposal reflecting the CSV export we actually ingest, dated
2025-03-24); a `CC-BY-4.0` license and `pi_names` for calcofi_bottle (Q10–Q11), calcofi_ctd-cast
(Q28–Q29, naming both Rasmus Swalethorp and Benjamin Gire) and calcofi_mets (Q29–Q30) — calcofi.org
states no license for any of its three datasets. 14 `questions.csv` rows filed across 10 files, all
`status = proposed`, `related_table = dataset`.

New additive `dataset_meta` keys used here: `doi`, `license_url`, `acknowledgement` — the columns
themselves (`ingest_yaml_to_dataset_df()` / `.dataset_entry()`) and `calcofi4db::
check_dataset_citation()` are WS-A0's, not yet merged onto this branch, so that check was not run;
`Rscript scripts/build_workflows_index.R` passes with and without `CALCOFI_SKIP_LINK_CHECK=1`
(22 links, 22 OK). No `dataset_name` / `category` / `color` / `coverage_*` changed, and no ingest
was re-run — `release_database.qmd` reads this YAML directly.

## `obs_bio` and `obs_env` are the observation tables; `obs` is a view and will be dropped in the next release

Until now the release shipped every observation row twice: `obs` (26,261,931 rows, 401 MB in 16
objects partitioned by `dataset_key`, plus a 200 MB single-file twin) and the browser-shaped pair
`obs_bio` + `obs_env` (the same rows, 22 + 287 MB) — and the copy that carried the effort
denominator was the *supplemental* one. `obs` partitioned by `dataset_key` answered no consumer's
question: an app wants one variable (`obs_env` is one ≤ 10 MB object per `measurement_type`) or the
whole bio realm (`obs_bio` is one 26 MB file), and it wants the gear and effort of the row's own
sample beside the count, not a join to `sample_measurement` on every query. So the pair becomes the
physical store and `obs` becomes a view (pre-release plan D-S1, calcofi4db 3.31.0):

- **`obs_bio` / `obs_env` gain `sample_key`, `measurement_prec` and `hex_id`** (keeping `value`,
  `root_id`, `hex7`), so each is a strict superset of `obs` under a name mapping — `realm` is the
  table, `value` is `measurement_value`. Without `sample_key` a consumer could reach only the root
  sample and lost the net / bottle grain. Both are **core** tables now (in the ERD, in
  `cc_get_db()`'s default set); `sample_root` stays supplemental. Measured on the v2026.08.28 staging
  release: `obs_bio` 21.8 → 25.6 MB, `obs_env` 286.7 → 317.2 MB (84 objects).
- **`obs` still ships this once**, and `catalog.json` marks it `deprecated: true`,
  `replaced_by: ["obs_bio", "obs_env"]`, `removed_in: "next"`; the catalog's new top-level **`views`**
  map carries `obs` → the UNION ALL that reconstructs its 18 columns under their original names
  (`SELECT obs_id, 'bio' AS realm, … value AS measurement_value … FROM {{obs_bio}} UNION ALL … FROM
  {{obs_env}}`). `calcofi4r::cc_get_db()` (1.17.0), `calcofi4py.cc_get_db()` (0.6.0) and db-query's
  `__TBL:obs__` create `obs` from that view, so `FROM obs` keeps working; the deprecated objects are
  read only where the view's sources are not loaded.
- **The gate**: `release_database.qmd` fails unless the pair reproduces `obs` per `(realm,
  dataset_key)` — row count, distinct `obs_id`s, an order-independent signature of every non-depth
  column — with no non-NULL depth changed (`check_obs_pair_parity()`; 15 groups, all equal on the
  staging release); `test_release.qmd` runs every `obs` contract row three ways (the deprecated
  objects, the view, the pair) and asserts the view's row counts and column order equal `obs`'s.
- **One deliberate difference.** A bio row whose depth is NULL in `obs` carries its sample's span
  through the pair — the tow's `depth_min_m`–`depth_max_m` — so through the view 482,250
  `swfsc_ichthyo` rows (100 % of that dataset; every other dataset's NULLs stay NULL because no
  span exists on `sample` either) now have a depth where `obs` had none. A non-NULL depth is never
  changed.

**Consumers:** read `obs_bio` / `obs_env` directly (`value`, no `realm`; effort and densities inline)
before the **next release**, when the `obs` objects are dropped and only the view remains. Through
`cc_get_db()` `SELECT * FROM obs` now returns columns in the table's order (`dataset_key` third)
where the remote view over the hive partitions returned it last; a direct reader of
`releases/{v}/parquet/obs/…` or `obs.parquet` (ERDDAP deploy, netCDF publish, the PostgreSQL
`release.*` views) is unaffected this release and must move to the pair or the catalog view by the
next. Known direct readers of `obs` to migrate: db-query (8 files), `apps/` (7), db-viz-station (5),
ctd-transects (2), db-viz-hex (2), `libs/publish_netcdf.R`, `scripts/render_release_views.R`.

### ERDDAP gains the effort denominator (D-S3)

`publish_to-erddap.qmd`'s `{dataset_key}` grain (`sql_obs()`) read `obs` + `taxon` + `sample`: a bare
count, no effort, no density — the reason erddap.calcofi.io looked "woefully absent" next to
CoastWatch's `erdCalCOFIlrvcnt`/`erdCalCOFIlrvstg` (`volume_sampled`, `standard_haul_factor`,
`percent_sorted`, `larvae_10m2`, `larvae_1000m3`), whose effort sat on the separate, un-joinable
`{dataset_key}_sample` grain. It now reads `obs_bio` (bio datasets) or `obs_env` (env datasets) —
each `dataset_key` is cleanly one realm (measured on the H1-schema rebuild of staging v2026.08.28: no
dataset splits bio/env) — **through the release catalog**
(`calcofi4r::cc_release_sources(catalog, "obs_bio"/"obs_env")`, resolved via
`libs/publish_netcdf.R`'s `cc_release_catalog()`), never a hand-built `releases/{v}/parquet` path.
Every existing column is kept; `tow_type`, `std_haul_factor`, `prop_sorted`, `volume_sampled_m3`,
`density_per_10m2`, `density_per_1000m3`, `effort_class`, `units` and `qual_ok` are added, already
computed onto the pair at release time — no join to `sample_measurement` here.

- **Falls back cleanly when a release predates D-S1.** The promoted v2026.08.25 has no `obs_bio`/
  `obs_env` in its catalog, so `HAS_OBS_PAIR` is `FALSE` and the grain reads the deprecated `obs`
  objects as before (verified live against v2026.08.25's real catalog — `cc_release_sources()`
  correctly errors "not in the catalog" and the notebook `cat()`s the fallback rather than failing).
- **New `datasets.xml` attributes**: `long_name`/`units`/`comment` on the new columns (the density
  and `effort_class` comments paraphrase `calcofi4r::cc_density_sql()`'s own documentation);
  `flag_values`/`flag_meanings` on `measurement_qual`, matched from `metadata/measurement_qual.csv`'s
  `code_set` (today only `bottle` and `ctd` are registered — matched by substring against
  `dataset_key`, so `swfsc_ichthyo` and the rest correctly get none rather than an invented one);
  `sdn_parameter_urn` from a `nerc_p01` column in `metadata/measurement_type.csv`, keyed by
  measurement_type name so it only ever lands on a `_sample` grain's pivoted effort column (never on
  a long `measurement_type`/`measurement_value` pair, which mixes quantities) — **inert today** (H2
  has not landed `nerc_p01` yet), mechanism verified with a synthetic value.
- **Investigated and NOT migrated**: `libs/publish_netcdf.R` itself has no literal `obs` reference
  (it is generic release-catalog plumbing, called with whatever table name a caller passes); the
  actual `obs` reads RELEASES.md flagged live in `publish_to-netcdf.qmd` (`CREATE TABLE obs AS …` and
  `obs_parts <- cc_release_partitions("obs", RELEASE)`, keyed by `dataset_key` from the partition
  path). Migrating it is **not mechanical**: `obs_bio` is a single unpartitioned file and `obs_env`
  is partitioned by `measurement_type`, not `dataset_key`, so the "read this dataset's one partition"
  strategy the whole ~800-line notebook is built around no longer holds for any env dataset (it would
  have to scan all 84 `obs_env` objects per dataset instead of one). Left for a dedicated follow-on.
  `scripts/render_release_views.R` also has no literal `obs` reference — its table names come from
  `../server/postgis/init/50_release_views.sql` (a sibling repo outside this brief); today it still
  resolves `obs` fine since the deprecated objects ship this release.

## The boundary layers describe themselves (`spatial_layers.json`)

The release gains one sidecar beside `coverage.json`: the boundary-layer registry
(`metadata/spatial_layers.csv` — the 19 drawable layers, their PMTiles archives, default symbology
and provenance) joined with what only the release knows: each layer's feature count, bbox, its
distinct names (the Explorer's by-name palette) and how many root samples fall inside it
(`sample_spatial`). The CalCOFI Explorer's Layers card reads this instead of hard-coding the layer
list, so a row Erin adds to the registry reaches the app at the next release with no code change
(calcofi4db 3.28.0 `build_spatial_layers()`). Not a table: `catalog.json` and consumers of the
parquet are untouched.

## The seafloor stamp runs anywhere, and an unexplained NULL fails the release

`seafloor_depth_m` is sampled from GEBCO 2025, and until now that meant one laptop's local
933 MB tile (`CALCOFI_GEBCO_TIF`'s default) — a machine without it could not run the release at
all. The same grid is now published as a streamable Cloud-Optimized GeoTIFF
(`gs://calcofi-db/bathymetry/gebco_2025_sub_ice_n90_w180_e90_cog.tif`), and the `depth_coverage`
chunk falls back to it over `/vsicurl/` range reads when no local file is present
(calcofi4db 3.27.0 `sample_seafloor()` accepts URL sources).

With that, a NULL `seafloor_depth_m` stops being one undifferentiated count: every NULL is now
classified (`calcofi4db::check_seafloor_nulls()`) as *no coordinates*, *NaN coordinate*,
*outside the GEBCO source tile* (all three are the owning ingest's `questions.csv` material —
at v2026.08.25 they were 1,360 ichthyo positions east of −90° plus 71 METS rows with no
latitude), or *inside the tile and still NULL* — which can only be a regression in the sampling
itself and now **fails the release**. Consumers see no schema change.

Alongside (not release content, but the same D29 change): `gebco_2025_calcofi.tif`, the crop
`calcofi4r::cc_bathy()` serves, was re-cut from lon −127 → −116.8 × lat 29.3 → 38.4 to
**lon −165 → −100 × lat 15 → 56** (Int16 COG) so all 360,568 released positions that fell outside
it — 24.7 %, silently reading `NA` depth — now sample a real value; `cc_bathy_depth()` warns
about the remainder instead of keeping quiet (calcofi4r 1.16.0).

## One climatology for every anomaly

Two products drew the same section — line 90, July 2026, temperature — and disagreed by the whole
signal: [ctd-transects](https://calcofi.io/ctd-transects/) showed +1 to +3.9 °C through the upper
100 m, the [Explorer](https://calcofi.io/explore/?lens=section) looked like nothing. The ocean was
not the reason. Each product computed its own baseline: ctd-transects a 1993–2013 monthly mean at 5 m
over *one arbitrary cast per grid cell*; the Explorer a mean over **all calendar months** of whatever
year range the slider held — a map of the seasonal cycle (line 90 surface: January 15.2, July 18.3,
annual 16.8 °C), which hid 1–1.5 °C of the winter and spring warmth outright; and
`calcofi4r::cc_climatology()` a third copy. The Explorer also painted +2 °C **blue**: Plotly's built-in
`RdBu` runs blue → red, the reverse of the ColorBrewer scale its name suggests.

The release now ships **`climatology`** (`calcofi4db::build_climatology()` ≥ 3.26.0): a plain mean of
the env realm of `obs` per **dataset × station × calendar month × 10 m floor depth bin × measurement
type** over **1993–2013** (Rasmus Swalethorp's CCIEA window; both phases of the 1997–99 ENSO inside it,
ends before the 2014–16 heatwave; stamped on every row as `clim_yr_min`/`clim_yr_max`), kept only where
**≥ 3 distinct cruises** contribute (`n_cruises` — a floor in observations is met by one cruise's four
casts in a nearshore cell), with `clim_n` and `clim_sd`. Partitioned by `measurement_type` like
`obs_env`. Why 10 m and not 5: `obs` carries the *thinned* CTD series (10 m grid + inflection points),
so at 5 m the off-grid bins held a third of the casts, sampled exactly where the profile bends, and
their means sat visibly off their neighbours' (station 60, July: 14.27 °C between 15.39 and 15.04).
ctd-transects, the Explorer's Sections lens and `cc_climatology()` all subtract this table now; a cell
that is absent has no baseline and its anomaly is blank, never zero. Under it the three products agree:
July 2026 on line 90 is +1.3 to +1.4 °C in the upper 50 m and +0.6 °C at 200–500 m by every reading.

**Consumers:** additive — one new default table with FKs to `grid`, `dataset` and `measurement_type`;
`cc_climatology()` returns the table's cells (with `n_cruises`) when the release has one and bins depth
by 10 m floor bins (was 5 m rounded) — `cc_transect_section()` follows. Not yet fixed: both section
products key a station on `grid_key`, and nearshore cells hold 2–4 real stations (`st30-ln90` = 90.30,
90.28, 90.27.7, 88.5/30.1); `sample.site_key` is the station and the sections will move to it.

## `coverage.json` carries taxa and categories, and `measurement_type` says which category and variable a type belongs to

The explorer's organism list waited on a 22 MB download and its variables were grouped by a keyword rule
ported from the station app. `coverage.json` (`calcofi4db::build_coverage()` ≥ 3.25.0) now carries
`taxa[]` — one row per taxon of the bio realm with names, rank, class, `n_obs`, year span, life stages and
its datasets — and `variables[].category` / `.variable` from two new `metadata/measurement_type.csv`
columns: **`category`** (one of the twelve in the new **`metadata/category.csv`** registry, which
`build_workflows_index.R` now enforces on every ingest's `category:`) and **`variable`** (the
cross-dataset crosswalk: the bottle's `temperature` and the CTD's `temperature_ave` are one variable).
Both are set with `calcofi4db::declare_measurement_fields()`, never a bare `write_csv`.

**Consumers:** additive — `coverage.json` gains keys, `measurement_type` gains two nullable columns.

## The release now cuts browser-shaped objects, and effort travels with every bio observation

Four new tables and one sidecar, built at release time by calcofi4db 3.24.0 for the CalCOFI Explorer
(plan `2026-08-28 CalCOFI Explorer …`, D4/D8), and available to every consumer:

- **`obs_bio`** (supplemental, one ~22 MB object) — the bio realm of `obs`, slim, with `root_id`,
  `year`/`quarter`/`depth_bin`, `units`, `qual_ok` (`cc_qual_ok_sql()` evaluated at release), the gear
  and effort of the observation's own sample (`tow_type`, `std_haul_factor`, `prop_sorted`,
  `volume_sampled_m3`), and **two canonical densities derived once and named** —
  `density_per_10m2` (areal: `count × std_haul_factor / prop_sorted` for C1/CB/CV/PV tows, published
  per-m² × 10) and `density_per_1000m3` (volumetric: `count / prop_sorted / volume_sampled × 1000` for
  any tow with a volume, published per-1000 m³ as is) — plus `effort_class`
  (`count_with_effort` 482 k rows, 1 dataset · `raw_count_no_effort` 355 k, 5 datasets ·
  `density_as_published` 155 k · `other_unit` 263 k). Areal and volumetric are never converted into
  each other. The expression is `calcofi4r::cc_density_sql()` ≡ `calcofi4py.density_sql()` ≡ the
  explorer's `sql/density.sql`, fixture-pinned byte for byte. `hex7` is one `UBIGINT` H3 cell at res 7;
  coarser parents are bit arithmetic (`h3_parent_sql()`), so a browser needs no `h3` extension.
- **`obs_env`** (supplemental, hive-partitioned by `measurement_type`: 84 objects, ≤ 10 MB each, 287 MB
  in all) — the env realm with the same columns, so one variable is one fetch.
- **`sample_root`** (supplemental) — one row per root sampling event with a dense, deterministic
  integer `root_id`; the join key the three objects share, and the cruise tracks.
- **`sample_spatial`** (core) — exact per-root-sample polygon membership for every polygon layer of
  `spatial`, computed once, chunked per layer (≈1 M memberships over 15 polygon layers; the four
  maritime-limit/port layers are lines and points and hold nothing). Replaces the per-app spatial join
  that exhausted the 16 GB server.
- **`coverage.json`** — n obs and root samples by dataset, dataset × station × year, dataset × year and
  dataset × variable (181 KB): the explorer's first paint and Task 14's variable-based inventory.

`metadata/measurement_type.csv` gains **`denominator`** (`area` | `volume` | `none`) so the vocabulary
is registry-owned. The default view of a taxon is the denominator that covers the most datasets *with
effort* — never largest-n (`cc_default_stage()` / `cc_default_denominator()`): Pacific sardine opens as
larva · per 10 m² · swfsc_ichthyo (6,158 rows; 1,262 manta rows excluded, available per 1000 m³), not
one number averaged over 62,898 rows in three units.

**Missing effort is an ingest task, and is now filed** — `swfsc_cufes` Q05 (pump volume), `calcofi_phyllosoma`
Q05 (volume filtered, proposed), `sio_mesopelagic-fish` Q08 (VolFilt, proposed), `farallon_bird-mammal` Q08
(transect area → a per-km² denominator, proposed), `cdfw_dungeness-crab` Q13; until they land those rows are
`raw_count_no_effort` and the app says so. **Also found by the cut:** every `swfsc_ichthyo` tow/net sample
has `depth_max_m = NULL`, so a net tow cannot be drawn as the integrated span it is (`swfsc_ichthyo` Q08).

**Consumers:** `cc_get_db()` gets `sample_spatial` by default; `obs_bio`/`obs_env`/`sample_root` are
`supplemental = TRUE` (opt in). `test_release.qmd` gains seven contract rows over the new objects.

## The Dungeness crab dataset is the examined samples

`cdfw_dungeness-crab` published its 1949–2009 sorting log's full 2,011 rows as effort-only `sample`
rows — 216 examined (sorted, each with a zero-valued *M. magister* absence `obs`) and 1,795 never
looked at. An unexamined archived jar is a fact of the deposit's sorting-log inventory, not a sample
of this dataset, so the 1,795 unsorted rows are now dropped from the core entirely rather than
carried as "sample row, no `obs`" — that shape was indistinguishable from every other reason a
sample might carry no observation. `sample` drops from 2,321 to **526** events (310 sorted
2008–2014 time-series subsamples + the 216 examined sorting-log tows); `obs` (1,456) is unchanged,
since the sorting log's absence rows were already scoped to examined tows only.
`coverage_temporal_observed` moves from a 1949 start (the full log's span) to the true examined
span, **1984-05-17 to 2014-05-03**; `coverage_spatial_observed`'s westward extent tightens from
164.1°W to 132.25°W, since the sorting log's most extreme west/north rows were all unsorted.

The California Digital Collections / UCSD Library Research Data Curation program deposited this
dataset on 2026-08-27, ahead of a minted DOI. `link_data_source` carries a placeholder Library
search URL (`https://library.ucsd.edu/dc/search?q=CalCOFI+Dungeness+crab+megalopae`, answers 200)
with a YAML comment marking it as a placeholder; `metadata/cdfw/dungeness-crab/questions.csv` Q14
tracks the DOI/object-URL ask, with the swap to `citation_main` + `link_data_source` proposed for
when it mints. The deposit's README reportedly corrects the sorting log's one positive-longitude
row (Q08) — that row is one of the dropped unsorted rows regardless, so it does not affect what
ships here; the sign fix will be applied once the deposit zips are in hand.

**Consumers:** `sample` row count and the dataset's temporal/spatial coverage change as above; no
schema change.

## The bottle's reported (`r_*`) series are interpolated, and say so

The bottle's six pre-QC `r_*` measurement types (`r_ammonium`, `r_depth`, `r_dynamic_height`,
`r_oxygen_umol_kg`, `r_salinity_sva`, `r_temperature`) carried an empty `derivation` and
`is_canonical = TRUE`, so nothing on the released type itself said they were anything other than
another canonical series a consumer could compare or interpolate from. Rasmus Swalethorp (SIO CTD
data team) confirmed 2026-09-01 (`metadata/calcofi/bottle/questions.csv` Q09): the `r_*` columns
are values *already* interpolated to standard depths in decodr, pre-QC and unflagged by design —
"when we do any kinds of data interpolations ... we should not use already interpolated data points
from the bottle database." `measurement_type.csv` now records that as `derivation` on all six types
and flips `is_canonical` to `FALSE`; `release_database.qmd` gates the release on no `r_*` type ever
carrying a `variable` crosswalk entry (the mechanism a consumer would use to compare it across
datasets in the first place).

**Consumers:** `is_canonical` flips TRUE → FALSE on `r_ammonium`, `r_depth`, `r_dynamic_height`,
`r_oxygen_umol_kg`, `r_salinity_sva`, `r_temperature` — any query selecting the default/canonical
`measurement_type` set for `calcofi_bottle` stops returning these six; they remain in `obs` under
an explicit `measurement_type` filter, now documented as pre-QC and not for further interpolation.

## Accepted CTD QC flags have a bridge to the release (unrun this round)

`ingest_calcofi_ctd-cast.qmd` gains an `apply_accepted_flags` chunk: it downloads the CTD team's
nightly-snapshotted, curator-accepted flag ledger (`gs://calcofi-db/qc/ctd/flag_accepted.parquet`,
from the PostgreSQL `ctd.flag` table — see `CLAUDE.md` § *The CTD team's PostgreSQL database*),
joins each flag to the scan it names via `(archive, _source_file, cast_key, depth_m)`, and
overwrites `ctd_measurement.measurement_qual` for the match; `release_database.qmd` gains a
warn-only `qc_flags_pending` chunk reporting the gap between the snapshot and what the last CTD
ingest render applied. **This chunk ships unrun**: the snapshot is a 600-byte header-only parquet
(0 accepted flags, last modified 2026-08-19) — the CTD team has not accepted a flag through the
ledger yet, and the CTD ingest is not re-run this round (128 min; see the "Avoiding the CTD
ingest" plan). It takes effect at the next CTD ingest render.

## Rasmus's other CTD/bottle answers become registry facts

`metadata/calcofi/bottle/questions.csv` Q09 (R_* quality-code inheritance) is `answered` — R_*
stays unflagged, and the P_qual-vs-phosphate half is split into its own row (Q12, still open, for
Ben G). `metadata/calcofi/ctd-cast/questions.csv`: Q27 (Rathburn core-station casts) is `answered`
— continue to exclude; Q09 (sensor-selection codes 1/2) is `answered` on the codes' meaning
(matches `metadata/measurement_qual.csv`), leaving the averaged-canonical-type propagation policy
as unimplemented follow-on work, not a further provider question; two new rows record answers that
were emailed 2026-08-24 but never filed — Q30 (the `orig*`/`uncorrected/` exclusion and
`separate_runs/` retention, answered) and Q31 (the seafloor-vs-GEBCO "large discrepancy" threshold,
proposed at > 500 m or > 25% beyond the deepest neighbouring cell, per the ratchet in `CLAUDE.md`
§ *Depth is a coordinate*).

## `measurement_type` carries the controlled-vocabulary ids a portal export needs

A CalCOFI measurement has always said what it is in CalCOFI's own words — `nitrate`, `umol/L`.
Every export to a portal that speaks Darwin Core or OBIS ENV-DATA then had to guess the
corresponding controlled term, and `publish_ichthyo_to-obis.qmd` did not guess: it wrote
`measurementTypeID = NA_character_` on all three of its extended-measurement blocks, because
there was nowhere in the repo for the id to live. Now there is, and it is the same registry the
release publishes (pre-release plan decision D-S2; `calcofi4db::declare_measurement_fields()`
sets them, never a bare `write_csv()`).

- **`measurement_type` gains `nerc_p01` and `units_nerc_p06`** — full NERC concept URIs for
  OBIS/DwC eMoF's `measurementTypeID` (BODC Parameter Usage Vocabulary P01) and
  `measurementUnitID` (P06). **115 of 200 types carry a P01 id; 174 of 200 carry a P06 unit id**
  (resolved against the live NVS SPARQL endpoint, 2026-09-03, deprecated concepts excluded).
- **Empty means "no concept says exactly this", never "not looked at".** An id is written only
  on an *exact* vocabulary match: a concept every one of whose stated facets — quantity, matrix,
  phase, method — this registry or the dataset's documented protocol actually supplies. A generic
  concept is an exact match at coarser specificity (`TEMPPR01`, *Temperature of the water body*,
  for a QC'd bottle temperature); one that adds a facet nobody recorded is not, which is why PAR
  is empty (`IRRDUV01` pins it to a cosine-collector radiometer) and shortwave/longwave radiation
  are empty (P01 separates downwelling from upwelling; the mets registry says only "radiation").
  `nerc_uri_prefixes()` rejects a P06 URI pasted into the P01 column.
- **The 85 types with no P01 are mostly not gaps.** **29** are taxon-bearing abundance, biomass or
  size types, where P01 encodes the taxon *in the concept* and CalCOFI carries it in `taxon_key` —
  a per-type id there would be wrong, not missing. **8** are event-level effort and sub-occurrence
  attributes (`std_haul_factor`, `prop_sorted`, `volume_sampled`, the two displacement-volume
  biomasses, `settled_volume_ml`, `stage`, `behavior`) that BODC does not model as parameters.
  The remainder split three ways: **derived or raw-instrument series** the vocabulary does not
  describe (`dynamic_height`, `specific_volume_anomaly`, `r_salinity_sva`, the `pred_*` model
  outputs, the `est_*` corrected estimates, the `*_v` sensor voltages, `dic_valve`,
  `unknown_measurement_1`/`_2`); **quantities P01 simply lacks** (dynamic height, specific volume
  anomaly, and the `c14_*` production types whose mgC/m³/half-light-day time base P06 has no unit
  for); and **quantities under-documented at the source**, which is where the useful questions are —
  the transmissometer (wavelength and path length unrecorded), `atm_pressure_slc_mb` (P01's
  sea-level-corrected concepts all name a barometer), `wave_height` / `wave_period` (P01 has only
  *significant* height and WMO-coded period), `long_wave_rad` / `short_wave_rad` (up- or
  downwelling not recorded), `het_bacteria` and `picoeukaryotes` (the flow-cytometry gating is not
  recorded), and `bottom_depth` (P01's sea-floor depth concepts all name an echo sounder).
- **One finding worth a provider's eye.** `r_ammonium` and `btl_ammonium` take P01 `AMONZZXX`
  (ammonium, NH4+) because their source columns say ammonium; the QC'd `ammonia` is left **empty**,
  because its source column is the bottle database's `NH3uM`, "Micromoles Ammonia per liter of
  seawater", and P01 keeps ammonia (NH3) and ammonium (NH4+) as separate concepts. The three are
  the same measurement, so one of the two source labels is wrong — visible now instead of resolved
  by assumption. Relates to `calcofi_bottle` Q05.

## Two new vocabulary registries: `metadata/life_stage.csv` and `metadata/gear.csv`

Neither is released as a table; both are the reference an export reads, and both follow the same
exact-match rule.

- **`life_stage.csv`** covers all **23** distinct `obs.life_stage` values, with the DwC `lifeStage`
  label and the NERC S11 concept URI where one exists (**10 of 23**), plus `life_stage_parent` for
  a substage S11 does not carve (`furcilia F1`–`F7` roll up to `furcilia`, `calyptopis C1`–`C3` to
  `calyptopis`). Two values are recorded as **not life stages at all**: euphausiid `damaged`
  (specimens too damaged to stage — `occurrenceRemarks`) and ichthyo `invert` (a provenance flag
  for the merged SWFSC invertebrate counts). `phyllosoma` has no S11 concept. And the release
  ships both `larva` (ichthyo) and `larvae` (euphausiids) for the same concept — a normalization
  gap on the euphausiid vocabulary, now visible in the registry rather than in the data alone.
- **`gear.csv`** covers all **11** `sample.tow_type` codes with a `dwc_samplingProtocol` sentence
  and the NERC L22 device URI where one is exact (**4 of 11**): `C1` → *1-metre ring net*, whose
  L22 concept states the same 1-m diameter **and** 0.8 m² mouth area the SWFSC lookup does;
  `CB` and `DC` → the generic *Bongo net* (L22 is a device catalogue, so the 600 m `DC` protocol
  does not change the device); `MT` → *Manta net*. `CV` and `PV` (the CalVET / PairoVET vertical
  egg nets) have no L22 concept at all, and `OBLIQUE` on the crab dataset is a tow geometry with
  the gear unrecorded.

## `field_dictionary` says which Darwin Core term each canonical field publishes as

`dwc_term` holds the full DwC term URI for the **12 of 57** fields one term means exactly
(`decimalLatitude`, `decimalLongitude`, `locationID`, `footprintWKT`, `eventDate`,
`scientificName`, `vernacularName`, `lifeStage`, `organismQuantity`, `sampleSizeValue`,
`measurementType`, `measurementValue`); a field Darwin Core *splits* (`depth_m` →
`minimum`/`maximumDepthInMeters`) or has no term for stays empty, and `docs/db.qmd`'s new
"Darwin Core / OBIS ENV-DATA mapping" section carries the constructions no single term can
express — `scientificNameID` from `taxon_key`, the `eventID`/`parentEventID` hierarchy from
`sample_key`/`parent_sample_key`, `organismQuantityType` from the density denominator.

Fixed on the way: `libs/build_field_dictionary.R` calls itself re-runnable but had drifted four
rows behind the CSV (`seafloor_depth_m`, `date_min`, `date_max`, `cruise_key_method` were added by
hand), so running it would have silently deleted them. It is true again.

**Consumers:** additive only — two columns on the released `measurement_type` table, and two new
files under `metadata/` that no release table reads. Nothing is renamed or dropped.

## The provider's own identifiers are columns, and the cruise key is checked against the cruise

Ed Weber asked (2026-09-02) that the integrated database adopt NOAA's UUIDs. It carries them now
as typed columns beside the namespaced keys it joins on: `sample.source_uuid` — the SWFSC site,
tow or net UUID exactly as the export ships it (NULL for the 15 datasets that mint none);
`sample.station_uuid` + `station_uuid_method` — the SWFSC station occupation any event belongs to
(ichthyo's own site/tow/net rows: their own site, `self`; a foreign row parented directly to an
ichthyo site, e.g. the Dungeness crab's examined subsamples: `parent`; every other dataset's root
sample: matched on cruise + station + occupation order (`order_occ`), or on a unique occupation
within 24 h (`datetime`) — measured at v2026.08.25, 78.0% of 35,644 bottle casts and 80.3% of
19,242 CTD casts resolve; the rest are pre-1951 or cruises the export has no stations for);
`cruise.cruise_uuid` documented as the public join key to NOAA's database (it already shipped,
691/691 populated — only its `field_dictionary.csv` note was wrong).

The `cruise` reference is completed by the release (691 → 843 rows: 152 cruises the bottle, CTD,
METS and picoplankton sources designate that the SWFSC export has no stations for — 1949–1950 and
2016–2026 mostly — stamped `cruise_key_method = 'derived'` with the datasets that carry them,
`cruise.cruise_key_datasets`), so every `sample.cruise_key` now names a cruise; before this,
153,306 sample rows and 3.8M observations keyed cruises the reference lacked, and nothing failed.
The Bold Horizon July 2019 cruise had been released as `cruise_key = "2019-07-"` (the source ship
lookup has no NODC code for it, and the correction that patches it used to run *after* the cruise
key was minted; 2,255 rows in five datasets) and is now `2019-07-39C2`
(`metadata/swfsc/ichthyo/questions.csv` Q14).

`calcofi4db::check_cruise_key_integrity()` fails the release on a malformed `cruise_key`, a key
naming no `cruise` row, a NODC that is not the cruise's ship, a `date_ym` that disagrees with the
key, an ichthyo site whose `cruise_uuid` and `cruise_key` disagree, or an event more than 31 days
outside its cruise's span (seven `calcofi_ctd-cast` casts with 1997 and 2012 timestamps inside
1999 and 2013 archives are named exceptions — `metadata/calcofi/ctd-cast/questions.csv` Q32) — plus
three ratchets (derived-row count, span overlaps between two cruises of one ship, and the
per-dataset `NULL cruise_key` backlog, largest for `calcofi_dic`, whose unmatched Niskins carry no
cruise designation at all — `metadata/calcofi/dic/questions.csv` Q07). **Consumers:** additive —
`source_uuid` + `station_uuid` + `station_uuid_method` on `sample`, `cruise_key_method` +
`cruise_key_datasets` on `cruise`, 152 new `cruise` rows; `cruise_key` values change only for Bold
Horizon 2019-07.

# v2026.08.25

## `sample` is unique on its key — the 4,855-duplicate bug is fixed, and a gate now guards it

An earlier same-day cut of v2026.08.25 shipped `sample` with 1,472,100 rows for 1,467,245 distinct `sample_key`s — 3,345 bottles,
150 casts, 133 ichthyo sites and 13 underway samples appeared twice, identical except for a
`seafloor_depth_m` differing in the 11th decimal. The seafloor stamp (new in that release) collapsed
positions with `unique()` but joined them back with `merge()`, which compares coordinates as
15-significant-digit strings — two positions differing past that digit both matched every sample at
either. Nothing checked `sample` for uniqueness; the release only warned on `ship` and `cruise`.
76,320 `obs` rows (35,047 bottle, 31,057 CTD, 6,032 zooscan, 1,482 ichthyo, …) joined twice through
those samples, so any count or join keyed on `sample` over-counted them by exactly 2×.

- `sample` is unique on `sample_key` again (calcofi4db 3.23.3 maps positions back by exact index and
  errors on a duplicate), and `check_core_pk_unique()` **fails the release** on any core table that is
  not unique on its primary key.
- **Consumers:** anything built from v2026.08.25 (the cruise, hex and CTD apps' local databases, the
  station portal's derived JSON) over-counted those 4,855 samples until rebuilt on this release.

## Release tables are content-addressed, and written deterministically

Between v2026.08.14 and v2026.08.25 only 52 MB of the 2.09 GB release was byte-identical, and
tables whose row counts had not changed (`obs_mets_full`, `taxon`, `cruise`, `measurement_type`)
still differed byte-for-byte: the release writes carried no total order and ran multi-threaded.
Every released table is now written by one function with a unique `ORDER BY`, a single writer
thread and pinned parquet options, so the same rows always give the same bytes.

- **Schema:** the provenance columns (`_source_file`, `_source_row`, `_source_uuid`,
  `_ingested_at`) that `cruise`, `ship`, `lookup` and a few reference tables still carried are
  no longer in the release — `_ingested_at` changed on every ingest and would have made every
  table look changed. `lookup` and `spatial_attribute` are exported from the assembled
  database like every other table instead of being copied from the ingest bucket.
- **`catalog.json`** keeps `name`/`rows`/`partitioned`/`supplemental` and adds, per table,
  `content_hash`, `bytes` and `objects[]` — one entry per parquet object with its `path`,
  `bytes`, `sha256`, `content_hash` and `since` (the first release that shipped that content;
  for partitioned tables, per partition). Consumers that only read table names are unaffected.
- **Uploads:** an object whose content is unchanged since the previous release is reused (GCS
  server-side copy) rather than uploaded; a release's upload is now its delta.
- **Where the bytes live.** Each object is stored once, under
  `gs://calcofi-db/ducklake/tables/{table}/{content_hash}/{table}.parquet` (partitioned tables:
  `…/{table}/{col}={value}/{content_hash}/data_0.parquet`), and every release whose catalog
  points at it shares it. The familiar `releases/{version}/parquet/{table}.parquet` path is a
  real copy **only for the promoted version and the consolidated ones** (below); on
  `https://storage.calcofi.io/calcofi-db/…` a legacy path that has no copy redirects (302) to the
  canonical object while it exists. Resolve tables through `catalog.json` `objects[].path` —
  `calcofi4r::cc_release_sources()` (1.11.0), `calcofi4py.release_sources()` (0.4.0), and the
  same rule in db-query, db-viz-station, ctd-transects, db-viz-hex, the apps, ERDDAP's parquet
  sync and the PostgreSQL `release.*` views — rather than building the path by hand.

## Archive thinning: consolidated and retired versions

28 releases held 157 GB, most of it byte-identical tables re-uploaded under a new version
directory. `versions.json` now says which versions keep their parquet: `consolidated: true` for
v2026.04.08 (last per-dataset schema), v2026.05.14 (docs examples pin it), v2026.06.26,
v2026.07.17, v2026.08.14 and v2026.08.25, plus always the promoted version and the one before
it (`metadata/release_policy.yml`). Every other version keeps its `catalog.json`,
`metadata.json`, `relationships.json` and `RELEASE_NOTES.md` — the record stays complete — and
loses its `parquet/`; its entry carries `retired: {retired_utc, to, reason}` naming the nearest
kept version, `cc_get_db()` and `cc_get_db` (py) refuse it with that name, and its release page
says so. Pin a consolidated version for reproducibility; pin any other and plan to move.

## A quality flag now reaches every consumer, not just the database

Ralf Goericke reported a 2.18 ml/L oxygen spike at 1,144 m on station 080.0 160.0 in the
station data finder. The value is real and *was already flagged*: bottle 198640 of cast 7644
(cruise 5508BD, R/V Black Douglas, 3 Sep 1955) carries `O_qual = 8` (suspect) in the CalCOFI
Bottle Database. Two gaps let it through. The registry mapped `o_qual` onto `oxygen_ml_l` and
`oxygen_saturation` but not `oxygen_umol_kg` — the form the app plots — so the flag was dropped at
ingest; and no consumer filtered on `measurement_qual` at all.

- `oxygen_umol_kg` now carries `o_qual`; the CTD unit-conversion siblings (`oxygen_umol_kg_1/2`,
  `oxygen_saturation_1/2`, `potential_temperature_1/2`) carry their sensor's `ox1q`/`ox2q`/
  `temp1q`/`temp2q`. The bottle ingest writes `8`, not `8.0`, like the CTD ingest.
- The pre-QC `r_*` bottle types deliberately stay unflagged (Q09 to the provider): code 6 "OK but
  taken from CTD" describes a substitution made *during* QC and would mislabel ~36k rows.
- **Consumers:** one NULL-safe predicate per language — `calcofi4r::cc_qual_ok_sql()` (1.9.0),
  `calcofi4py.qual_ok_sql()` (0.3.7), db-query `qualOkSQL()` — applied in db-viz-station,
  db-viz-hex, ctd-transects, ctd-viz, db-query and the calcofi4r matchers/transects. On this
  release it excludes 35,587 bottle, 6,138 CTD and 51 DIC rows. Flagged values remain in the
  database with their codes; nothing is deleted.

## `cruise_key` is the cruise's designated month, resolved by date span

`YYYY-MM` in `cruise_key` was each cast's or tow's *own* calendar month. A CalCOFI cruise
routinely straddles a month boundary (5508BD ran 7 Aug – 25 Sep 1955; 184 of the 664 bottle
cruises span two months) and the neighbouring month is usually a real cruise of the same ship,
so the shorn-off casts landed on the wrong cruise with no FK ever failing: v2026.08.14 released 664
source bottle cruises as **799** keys, with 5,941 of 35,644 casts on a key their own source
disagrees with. Seven other ingests keyed tows the same way.

- The ichthyo ingest stamps every reference cruise's observed `date_min`/`date_max` (new columns on
  `cruise`); every other ingest resolves span containment first (same ship, ± 3 d — no two cruises
  of one ship overlap), then the source's own designation (bottle `Cruise` = YYYYMM), then the
  event month. Bottle: 799 → **657** keys; 5508BD is 34 casts and 5509BD 22, as in the source.
- The reference wins when sources disagree on a designation (ichthyo calls the 9 Feb – 29 Mar 1984
  Jordan cruise 8403, the bottle database 8402); the bottle notebook reports those cases.
- Second-order bug fixed on the way: the bottle CSV reader typed the all-digit `Cruise` column as
  DOUBLE (`'195508.0'`), which silently defeated the designation step on the first attempt.

## Depth is a coordinate, and it is now bounded

The previous release contained a CTD "cast" with scans at **14,671 m** over a 101 m seafloor — a
fluorometer test dip (`0010_001d`) from the `db-csvs/orig/` folder of the 2000-10 New Horizon
archive, which the tier classifier matched by substring. Its 17,964 dbar `pressure` value had been
deleted by the declared bound; the depth derived from it had not, because bounds apply to values,
not coordinates.

- `sample.seafloor_depth_m` (new column): bilinear GEBCO 2025 depth at every sample position
  (positive down, 0 on land, NULL outside the raster — 99.5 % of samples have one).
- Release gates: a depth beyond 6,500 m (the `pressure` ceiling) or NaN/negative fails the
  release (0 violations); samples deeper than the deepest GEBCO cell within one cell of their
  position + 10 m are reported and ratcheted (`DEPTH_SEAFLOOR_OVER_MAX = 694`, only ever down) —
  all but the test cast are 1949–1975 casts and tows on slopes and canyons with minute-rounded
  positions, so the measurement is fine and the place is imprecise. Never deleted.
- The CTD ingest excludes superseded `orig*`/`uncorrected/` exports (every cast in them is also in
  the top-level file, except that test dip) but keeps `separate_runs/` (20-1104SH's casts 031–036
  exist nowhere else).

## Two calcofi.org archives arrived with casts nobody can place

The 19-9604JD and 19-9608NH FinalQC archives, fetched from calcofi.org for the first time, carry
9,225 "RATHBURN CORE STN" scans with `-99` positions and the station *name* in the line/station
columns. They cannot enter `sample`/`obs`; the ingest now lists and drops them under a 0.2 %
ratchet instead of failing (Q27 asks whether coordinates exist). R's default 60 s download timeout,
which truncated every ~30 MB calcofi.org fetch at 15–25 MB, is now one hour.

**Packages:** calcofi4db 3.20.1, calcofi4r 1.9.0, calcofi4py 0.3.7. **Consumers rebuilt:**
db-viz-station, ctd-transects (both had a broken DuckDB installer step, `| sh` → `| bash`),
db-viz-hex, h3t API, db-viz-cruise, ERDDAP, db-query, ctd-qaqc, and ctd-viz — whose `prep_db.R`
had needed the retired `ctd_cast`/`ctd_thin`/`ctd_summary` parquet since the core consolidation
and had served a 2026-05-15 database for three releases; it now builds from `sample`/`obs`.
**Open:** ERDDAP `flag_values`/`flag_meanings` on `measurement_qual`; netCDF `*_qc` companions.

# v2026.08.14

## CDFW Dungeness crab megalopae enter the release

Held out since 2026-07-30 behind `in_release: false` while permission was open; CDFW confirmed
publication (CC BY 4.0, Laura Rogers-Bennett primary provider, CDFW citable custodian), so
`cdfw_dungeness-crab` is the 16th dataset — 310 sorted samples and a 2,011-sample sorting log,
with the sorters credited in the citation ("a record of looking, not just of finding"). Its two
staged measurement types moved into the shared registry; its 14 orphan cruises are exempted as an
inventory grain rather than allowed.

## Phytoplankton regions have real geometry, derived not invented

The four Venrick pooling regions are now polygons derived from the station-membership list
(`+proj=calcofi` places all 34 stations; convex hulls were measured and rejected), which resolves
phytoplankton Q01. Four taxa the join had missed now resolve.

## Vernacular names, dataset display metadata, and a readable promotion

- `common_name` reached the release only from a dataset's own vocabulary — 1,208 of 2,125 taxa
  (57 %) had none. WoRMS returns an unordered bag of vernaculars with no preferred flag, so names
  are chosen only when unambiguous (43 picked); *Dungeness crab* is the worked example.
- Dataset display metadata (name, short name, description, links) is authored once in each
  ingest's front-matter; `metadata/dataset.csv` is deprecated.
- Promotion (`latest.txt`) is now gated on a *readable* release: `check_release_complete()`
  requires `catalog.json`/`metadata.json`/`relationships.json`, and the pointer is read through
  the authenticated API rather than the CDN, after 2026-08-14 promoted a release with no catalog.
- The workflows index build fails on a dead or non-URL `link_data_source`; `swfsc_ichthyo` had
  pointed at a 404 for months.

**Rows:** `obs` 26.45 M → 25.62 M and `obs_ctd_full` 274.9 M → 259.3 M as the CTD archive moved
off Google Drive to local scratch and the extraction completeness check began comparing member
counts (a Drive placeholder reads as an empty file with no error). **Packages:** calcofi4db
3.15.0–3.19.0, calcofi4r 1.7.0 (a time-series gap is drawn as a gap, not a measured zero).

# v2026.08.11

## Ungridded observations are released

Observations whose position resolves no CalCOFI grid cell (transits, historical stations outside
the modern pattern) now reach `obs` with `grid_key` NULL, across all 14 ingests, and
`check_ungridded_obs()` reports them per dataset; each dataset carries a provider question asking
whether they are genuinely off-grid or coordinate errors.

## A position is a pair

CUFES samples were positioned at the segment *start* with the end coordinate resolved from a
different source; the sample position is now the segment midpoint and both coordinates come from
one source (calcofi4db 3.16.1 `append_obs()`). `obs_mets_full` gains the NaN-position guard that
`obs` already had (53 rows).

## The release refuses to re-cut the version consumers are reading

v2026.08.10 was republished under the same tag on 2026-08-11, failed `test_release`, and promotion
was correctly withheld — but `latest.txt` already pointed at the overwritten path, so consumers
read unverified data. `release_database.qmd` now stops if `release_version` equals the promoted
version unless `CALCOFI_ALLOW_REPUBLISH=true`.

**Packages:** calcofi4db 3.13.1 (NaN/Inf coordinates → NULL), 3.14.0 (line/station ↔ lon/lat).

# v2026.08.10

## Ten CTD cruises are back

v2026.08.08 lost every observation of ten cruises while keeping their casts, and no FK check could
see it: the CTD ingest extracted archives into a Google Drive folder, Drive evicted files to
cloud-only placeholders mid-sync, and `read_csv()` returned a 0-row tibble with no error — while
the Drive-minted ` 2.csv` conflict copies broke the cast-direction parse. `check_cruise_coverage()`
(calcofi4db 3.12.0) now fails a release on a cruise that leaves `obs` but keeps its casts; 142
cruises restored (`obs_ctd_full` +13.7 M rows).

## METS longitudes have their sign

The unsigned `Longitude_W` was released as positive (125.8 °W read as 124.9 °E in the measured
coverage); it is negated, answering mets_20. The orphan-cruise ratchet tightened 5 → 1.

## The pipeline stops invalidating itself

`release_database` had declared the whole `data/releases` directory as its output, so
`test_release` writing `test_results.json` beside it made the release permanently outdated and
every later `tar_make()` re-froze and re-uploaded an already-promoted release. It now declares a
deterministic `_release_stamp.json`; `check_nested_outputs()` refuses any directory output.

**Packages:** calcofi4db 3.12.0, 3.13.0; calcofi4r 1.6.0 (seafloor sampled along the transect
track, not at stations).

# v2026.08.08

## Declared bounds are enforced, and 31k impossible values leave

`valid_min`/`valid_max` in `metadata/measurement_type.csv` had been emitted as netCDF attributes
and shown on the schema site for months while nothing compared a value to them. v2026.08.07
shipped ~31k impossible CTD values (pH to −10, `oxygen_ml_l_1` to −79.5, `temperature_ave` to
−47.6) — the fallout of METS erasing curated bounds from the shared registry on its write-back.
`check_measurement_bounds()` now runs per dataset at ingest and across `obs` *and* the
supplemental tables at release; `out_of_range` fails the release, `undeclared` is ratcheted
(73 → 30 of 98 (dataset, type) pairs declared a bound at this release). Enforcement is a separate
`drop_out_of_bounds()` so a bound must be agreed before it deletes.

## Two-sensor averages are repaired, not averaged with −99

`TempAve` was averaged with the −99 missing marker when one sensor failed (Q21, cruise 2607SH);
each sensor is validated individually and the repair generalised to every two-sensor average.
Q22 records the surface-soak artifact.

**Rows:** `obs` 26.27 M → 25.39 M, `obs_ctd_full` 274.9 M → 261.1 M (the impossible values).
**Packages:** calcofi4db 3.10.0 (`declare_measurement_bounds()`), 3.11.0 (no directory outputs).

# v2026.08.07

## The Wilkinson CTD archive and three data stages

JRW's Shared-Drive `_CTDFinalDB` archives are ingested alongside calcofi.org's, adding 45 gap
cruises; `data_stage` splits into `final`, `preliminary_with_bottle` and
`preliminary_without_bottle` (the sensor-only tier reaches the release with no salinity or oxygen
corrections). `obs_ctd_full` 212.4 M → 274.9 M rows; `obs` +6.2 M.

## Taxon authorities are cross-referenced and lineages completed

Birds key `itis:` because WoRMS bird taxonomy lags, but nothing populated `worms_id` for them, so
a consumer joining on `worms_id` matched zero rows for every seabird and marine mammal (92 % of the
Farallon census). `ensure_taxon_xref()` crosswalks TSN ↔ AphiaID by exact id; `taxonomic_status`
is fetched with `status_checked` instead of stamped "accepted"; ancestors are first-class taxa with
rank order from one vocabulary. Four new release gates cover it.

## Coverage is measured, never asserted

`coverage_temporal`/`coverage_spatial` were hand-written in each ingest and seven of fifteen were
wrong at v2026.08.06; `observed_coverage()` now measures both from the assembled core and the
measurement surfaces coordinate bugs the prose hid. Bulk parquet moved outside the repo to
`$CALCOFI_STAGE_DIR`; the JSON sidecars stay tracked in git.

**Packages:** calcofi4db 3.5.0–3.9.3; calcofi4r 1.5.0–1.5.4 (shared transect/climatology/anomaly
functions, summer-anomaly vignette).

# v2026.08.04 – v2026.08.06

Three closely spaced releases while consumer deployment became part of the pipeline: consumers
sync automatically on promotion, `deploy_consumers` is a real target that reports which release
each consumer is *actually* serving (the h3t API held its old database file open across a symlink
flip), ERDDAP deploys from `publish_to-erddap.qmd`, and the public release index is regenerated on
promotion. Spatial layers gained attributes (`spatial` 3,373 → 13,206 features; `spatial_attribute`
40k → 148k). v2026.08.05 dropped 17,187 duplicate/invalid `sample` rows. Four WoRMS/taxonomic-status
gates added (28 → 32).

# v2026.08.03

## All released geometry is tagged EPSG:4326

`ST_Point()` tags `OGC:CRS84` while `ST_Read()` over GeoJSON tags `EPSG:4326`; DuckDB refuses
`ST_Intersects` across the two, so a `sample` → `spatial` join errored outright. Geometry is
normalised immediately before the freeze — and exported locally, because most tables are uploaded
by GCS server-side copy and never pass through the connection (the check passed while the published
`grid.parquet` stayed `OGC:CRS84`). `_spatial`/`_spatial_attr` become `spatial`/`spatial_attribute`
with a real `spatial_key`. Five spatial gates added (23 → 28). Partitioned uploads use `rsync`, so a
retry resumes; full-scan parquet is clustered by cast. Rows unchanged; 2.19 → 2.16 GB.

# v2026.08.02

## A full rebuild on the core-only model

Every dataset's core projection SQL moved out of calcofi4db into the ingest notebook that owns it
(calcofi4db 3.2.0 deleted the `switch(dataset_key, …)` arms — the release had re-derived the core
from its own inline copy and the two copies drifted, each divergence a silent data error).
`obs_mets_full` and `taxon` are catalogued; spatial tables renamed. `obs` 18.7 M → 20.1 M.

# v2026.07.30

## Four new datasets, the CTD QA/QC engine, and generic publishing

- **Datasets 12 → 15:** CCE-LTER euphausiids, CCE-LTER picoplankton/bacteria, SIO mesopelagic
  fish, and the METS underway series (`obs_mets_full`, 19.9 M rows). CDFW Dungeness crab is
  ingested but held out of the release behind a new `in_release: false` flag pending permission.
- **CTD QA/QC engine:** a declarative rule registry (`metadata/qc_rules/`), climatology-anomaly,
  seafloor-bathymetry and full-resolution profile rules, a Findings report with an input-fingerprint
  fast path, and a generated QA/QC protocol document.
- **Publishing:** one dataset-agnostic `publish_to-netcdf` + `publish_to-erddap` for every
  dataset; whole-dataset CF NetCDF to `calcofi-files-public`; `storage.calcofi.io` browsing.
- **Registries:** the hydro-master Access database reconciled against the release; a
  write-round-trip bug that let nine ingests corrupt `measurement_type.csv` with literal `"NA"`
  fixed; `-99` sentinels stripped from CTD; `data_stage` on `sample`; one question registry
  convention (`questions.csv`, `read_questions()`).

**Packages:** calcofi4db 2.11.0 → 3.4.0; calcofi4r 1.4.0–1.4.3 (non-blocking usage analytics).

# v2026.07.17

Serving-layer release, no row change: thinned CTD served as CF Profile NetCDF on ERDDAP, profiles
keyed by station occupation (`ord_occ`) rather than per scan; `tow_type` (net gear) promoted onto
the core `sample` table (calcofi4db 2.10.0); the station portal refresh repointed to
`CalCOFI/db-viz-station`.

# v2026.07.16

## One taxonomy

Eight per-dataset taxon tables (`species`, `taxa_rank`, `phyto_taxon`, `zoodb_taxon`,
`zooscan_taxon`, `bird_mammal_species`, `bird_mammal_behavior`, `obs_freq`) are replaced by
`taxon` (`worms:`/`itis:` keys), `dataset_taxon` (per-dataset crosswalk) and `taxon_group`, and
`obs_freq` becomes `obs_attribute` (size/stage frequencies + behaviour). 22 → 17 tables.
**Consumers:** the consumer contract rekeyed from `species_id` to `taxon_key`.

# v2026.07.15

## The consolidated core model

The ~40 per-dataset triples (`{dataset}_sample` / `_measurement` / `_summary`) collapse into
`sample` (one row per sampling event, adjacency list via `parent_sample_key`), `obs` (one scalar
per row, `realm` env|bio), `sample_measurement` (event-level effort) and the supplemental
`obs_ctd_full` (full-resolution CTD scans, ~216 M rows, opt-in). Per-dataset tables survive as
compat views. Namespaced `sample_key` = `dataset_key:sample_type:id`; `hex_id` (H3 res 10) on
`obs`. `obs_ctd_full` complete for the first time.

# v2026.06.26

CCE-LTER ZooDB holoplankton and ZooScan PRPOOS ingested with reproducible acquisition scripts;
`measurement_type` → dataset membership derived rather than asserted.

# v2026.06.07 – v2026.06.08

Phytoplankton (Venrick, region-pooled) added; 44 tables; full ingest + release re-run with
refreshed outputs, DB and PMTiles.

# v2026.05.14 – v2026.05.20

`ctd_thin` introduced as the headline CTD series (one direction, canonical types, 10 m grid +
inflections + bottle depths); schema browser site and the `test_release` → promote pipeline with
`test_results.json`; ERD and `metadata.json` sidecars from v2026.05.19.

# v2026.04.02 – v2026.04.08

Invertebrates folded into ichthyo; spatial tables consolidated and uploaded to GCS; pipeline
optimised with VIEWs and GCS server-side copy (60+ min → ~4 min); `inverts` → `invert`,
`dic_measurement_summary` → `dic_summary`.

# v2026.03.14 – v2026.03.25

First releases on the versioned GCS layout (`ducklake/releases/{version}/`), `relationships.json`
sidecar from v2026.03.14; bottle, CTD, DIC and ichthyo as per-dataset tables.

# v2026.02 (2026-02-05)

First frozen release: 17 tables, 13.4 M rows, 81 MB — ichthyo merged with bottle.
