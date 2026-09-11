# CalCOFI integrated database release v2026.09.10

**Release date:** 2026-09-11 · **promoted** (`latest.txt`)

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

## Contents (generated)

| table | rows | |
|---|---:|---|
| `climatology` | 714,882 | partitioned |
| `cruise` | 842 |  |
| `dataset` | 16 |  |
| `dataset_taxon` | 1,917 |  |
| `grid` | 218 |  |
| `lookup` | 26 |  |
| `measurement_type` | 200 |  |
| `obs` | 30,691,260 | deprecated → `obs_bio`, `obs_env` (objects removed in next) |
| `obs_attribute` | 458,184 |  |
| `obs_bio` | 1,258,665 |  |
| `obs_env` | 29,432,595 | partitioned |
| `region` | 4 |  |
| `sample` | 1,469,151 |  |
| `sample_measurement` | 589,603 |  |
| `sample_spatial` | 929,632 |  |
| `ship` | 49 |  |
| `spatial` | 13,206 |  |
| `spatial_attribute` | 148,461 |  |
| `taxon` | 2,614 |  |
| `taxon_group` | 441 |  |
| `obs_ctd_full` | 270,575,116 | supplemental |
| `obs_mets_full` | 19,926,523 | supplemental |
| `sample_root` | 421,450 | supplemental |

**23 tables, 356,635,055 rows, 2.58 GB.**

**Datasets (16):** `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 87 pass / 0 fail / 4 skip (consumer-contract suite, 2026-09-10T22:37:26Z).

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.09.10 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://doi.org/10.5281/zenodo.22698724

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
con <- calcofi4r::cc_get_db(version = "v2026.09.10")
```
```python
con = calcofi4py.cc_get_db("v2026.09.10")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.09.10/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
