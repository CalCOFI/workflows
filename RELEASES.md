# CalCOFI integrated database — release notes

What changed between releases and why. One section per release, newest first; the
`# Unreleased` section collects changes since the last release and becomes the next release's
section when `release_database.qmd` runs. Each release's `RELEASE_NOTES.md` on GCS is the
section below plus a generated appendix (tables, rows, datasets, validation gates, package
versions). Conventions: see `CLAUDE.md` § "RELEASES.md is not optional".

# Unreleased

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

# v2026.08.25 (2026-08-25)

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

# v2026.08.14 (2026-08-14)

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

# v2026.08.11 (2026-08-11)

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

# v2026.08.10 (2026-08-10)

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

# v2026.08.08 (2026-08-08)

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

# v2026.08.07 (2026-08-07)

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

# v2026.08.04 – v2026.08.06 (2026-08-04 … 2026-08-06)

Three closely spaced releases while consumer deployment became part of the pipeline: consumers
sync automatically on promotion, `deploy_consumers` is a real target that reports which release
each consumer is *actually* serving (the h3t API held its old database file open across a symlink
flip), ERDDAP deploys from `publish_to-erddap.qmd`, and the public release index is regenerated on
promotion. Spatial layers gained attributes (`spatial` 3,373 → 13,206 features; `spatial_attribute`
40k → 148k). v2026.08.05 dropped 17,187 duplicate/invalid `sample` rows. Four WoRMS/taxonomic-status
gates added (28 → 32).

# v2026.08.03 (2026-08-03)

## All released geometry is tagged EPSG:4326

`ST_Point()` tags `OGC:CRS84` while `ST_Read()` over GeoJSON tags `EPSG:4326`; DuckDB refuses
`ST_Intersects` across the two, so a `sample` → `spatial` join errored outright. Geometry is
normalised immediately before the freeze — and exported locally, because most tables are uploaded
by GCS server-side copy and never pass through the connection (the check passed while the published
`grid.parquet` stayed `OGC:CRS84`). `_spatial`/`_spatial_attr` become `spatial`/`spatial_attribute`
with a real `spatial_key`. Five spatial gates added (23 → 28). Partitioned uploads use `rsync`, so a
retry resumes; full-scan parquet is clustered by cast. Rows unchanged; 2.19 → 2.16 GB.

# v2026.08.02 (2026-08-02)

## A full rebuild on the core-only model

Every dataset's core projection SQL moved out of calcofi4db into the ingest notebook that owns it
(calcofi4db 3.2.0 deleted the `switch(dataset_key, …)` arms — the release had re-derived the core
from its own inline copy and the two copies drifted, each divergence a silent data error).
`obs_mets_full` and `taxon` are catalogued; spatial tables renamed. `obs` 18.7 M → 20.1 M.

# v2026.07.30 (2026-07-30)

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

# v2026.07.17 (2026-07-17)

Serving-layer release, no row change: thinned CTD served as CF Profile NetCDF on ERDDAP, profiles
keyed by station occupation (`ord_occ`) rather than per scan; `tow_type` (net gear) promoted onto
the core `sample` table (calcofi4db 2.10.0); the station portal refresh repointed to
`CalCOFI/db-viz-station`.

# v2026.07.16 (2026-07-16)

## One taxonomy

Eight per-dataset taxon tables (`species`, `taxa_rank`, `phyto_taxon`, `zoodb_taxon`,
`zooscan_taxon`, `bird_mammal_species`, `bird_mammal_behavior`, `obs_freq`) are replaced by
`taxon` (`worms:`/`itis:` keys), `dataset_taxon` (per-dataset crosswalk) and `taxon_group`, and
`obs_freq` becomes `obs_attribute` (size/stage frequencies + behaviour). 22 → 17 tables.
**Consumers:** the consumer contract rekeyed from `species_id` to `taxon_key`.

# v2026.07.15 (2026-07-15)

## The consolidated core model

The ~40 per-dataset triples (`{dataset}_sample` / `_measurement` / `_summary`) collapse into
`sample` (one row per sampling event, adjacency list via `parent_sample_key`), `obs` (one scalar
per row, `realm` env|bio), `sample_measurement` (event-level effort) and the supplemental
`obs_ctd_full` (full-resolution CTD scans, ~216 M rows, opt-in). Per-dataset tables survive as
compat views. Namespaced `sample_key` = `dataset_key:sample_type:id`; `hex_id` (H3 res 10) on
`obs`. `obs_ctd_full` complete for the first time.

# v2026.06.26 (2026-06-26)

CCE-LTER ZooDB holoplankton and ZooScan PRPOOS ingested with reproducible acquisition scripts;
`measurement_type` → dataset membership derived rather than asserted.

# v2026.06.07 – v2026.06.08 (2026-06-07 … 2026-06-08)

Phytoplankton (Venrick, region-pooled) added; 44 tables; full ingest + release re-run with
refreshed outputs, DB and PMTiles.

# v2026.05.14 – v2026.05.20 (2026-05-14 … 2026-05-20)

`ctd_thin` introduced as the headline CTD series (one direction, canonical types, 10 m grid +
inflections + bottle depths); schema browser site and the `test_release` → promote pipeline with
`test_results.json`; ERD and `metadata.json` sidecars from v2026.05.19.

# v2026.04.02 – v2026.04.08 (2026-04-02 … 2026-04-08)

Invertebrates folded into ichthyo; spatial tables consolidated and uploaded to GCS; pipeline
optimised with VIEWs and GCS server-side copy (60+ min → ~4 min); `inverts` → `invert`,
`dic_measurement_summary` → `dic_summary`.

# v2026.03 – v2026.03.26 (2026-03 … 2026-03-26)

First releases on the versioned GCS layout (`ducklake/releases/{version}/`), `relationships.json`
sidecar from v2026.03.14; bottle, CTD, DIC and ichthyo as per-dataset tables.

# v2026.02 (2026-02-05)

First frozen release: 17 tables, 13.4 M rows, 81 MB — ichthyo merged with bottle.
