# WS-H · Schema — `obs` deprecated for `obs_bio` + `obs_env`, DwC/NERC ids in the registries, the effort denominator on ERDDAP, `docs/db.qmd`

Three parts, three agents. **Plan:** umbrella § *Schema* (D-S1, D-S2, D-S3) — read it first; the numbers
there come from the staging release v2026.08.28.

## H1 · `obs` becomes a view over the bifurcated pair — Fable 5.1 · xhigh, Wave 1, calcofi4db 3.31.0 (after A0)

Read: `calcofi4db/R/explore.R` (`build_obs_bio()`/`build_obs_env()` ~l.77–125, `build_sample_root()`),
`release_database.qmd` chunk `browser_objects` and the `core_single` / `gcs_prefix = NA` / `supp_tbls`
lists, `build_release_catalog()` + `freeze_plan()` (the `release-objects` skill), `calcofi4r/R/database.R`
l.171–260 (views from the catalog) and `release_sources.R`, `calcofi4py/src/calcofi4py/release.py`
l.150–200, `db-query/lib/release.js` (`__TBL:` resolver), `test_release.qmd` (12 rows on `obs`),
`explore/sql/*.sql` (every template reads `value`, `root_id`, `hex7` — do not rename those).

1. `build_obs_bio()` / `build_obs_env()` add **`sample_key`, `measurement_prec`, `hex_id`** (keep `value`,
   `root_id`, `hex7`; `realm` is implied). Assert row parity with `obs` per realm and per dataset.
2. Promote both to **core** (`supplemental = FALSE`; in `core_single` and the `gcs_prefix = NA` list;
   ERD + default table list; `cc_get_db()` default). `sample_root` stays supplemental.
3. `catalog.json`: `obs` gains `deprecated: true`, `replaced_by: ["obs_bio", "obs_env"]`, `removed_in`
   (the next version); a top-level **`views`** map — `obs` → the UNION ALL SQL over `{{obs_bio}}` /
   `{{obs_env}}` table tokens (so a resolver substitutes its own `read_parquet(...)` per table):
   `SELECT obs_id, 'bio' AS realm, sample_key, grid_key, cruise_key, latitude, longitude, datetime,
   depth_min_m, depth_max_m, taxon_key, life_stage, measurement_type, value AS measurement_value,
   measurement_qual, measurement_prec, hex_id, dataset_key FROM {{obs_bio}} UNION ALL … FROM {{obs_env}}`.
4. Resolvers: `cc_get_db()` (R) and `cc_get_db()` (py) create every `views[]` entry **after** the tables,
   only when its source tables were included; `cc_release_sources()` / `release_sources()` error clearly
   when asked for a view as a table; db-query's `__TBL:obs__` expands the view SQL. Fixture catalogs
   (`catalog_canonical.json` in both packages, byte-identical) gain the `views` key; tests in all three.
5. `test_release.qmd`: every row that reads `obs` is duplicated to read the pair (and the view) so the
   contract covers both until `obs` is dropped; add one row asserting the view reproduces `obs` row counts.
6. `RELEASES.md # Unreleased`: "`obs_bio` and `obs_env` are the observation tables; `obs` is a view and
   will be dropped in the next release" — why (the effort denominator travels with every bio row; one
   variable is one fetch; the release stopped shipping 26 M rows twice), the column additions, the
   `**Consumers:**` migration line with the deadline. CLAUDE.md § core model table: update the rows.

Gate: staging release passes `test_release` with the pair core and `obs` present; `cc_get_db()` on the
staging catalog answers `SELECT count(*) FROM obs` = 26,261,931 through the view; the Explorer runs
unchanged (it never read `obs`).

## H2 · DwC / NERC ids in the registries + `docs/db.qmd` — Opus 5 · medium, Wave 2 (after H1's column names)

Read: umbrella § *Schema › DwC*; `metadata/measurement_type.csv` (200 types; columns listed in the WS-DG
brief), `metadata/field_dictionary.csv` (header `fld_new,type_new,units,category,fld_description,aliases,
measurement_type,is_identifier,notes` — only lat/lon mention DwC), `publish_ichthyo_to-obis.qmd`
l.190–215 (the P06 unit map) and l.480–515 (eMoF with `measurementTypeID = NA`), the OBIS manual pages
Ben linked (formatting, format_emof, darwin_core), De Pooter et al. 2017 (PMC5345125), `docs/db.qmd`
(headings: naming conventions · primary key conventions (stale: `YYMMKK`, `site_id sorted`, "avoid UUIDs")
· ingestion strategy · release versioning · metadata · publishing · relationships · spatial),
WS-B's key decisions, `metadata/dataset.csv` deprecation.

1. Registry columns, filled **only on an exact vocabulary match** (NERC vocab search
   `https://vocab.nerc.ac.uk/search_nvs/P01/?searchstr=…`; leave empty and list the rest):
   `measurement_type.csv` + `nerc_p01` (measurementTypeID URI) and `units_nerc_p06`; `field_dictionary.csv`
   + `dwc_term`; new `metadata/life_stage.csv` (`life_stage, dwc_lifeStage, nerc_s11`) covering every
   distinct `obs.life_stage`; `tow_type` values → a gear row set (`metadata/gear.csv`: code, name,
   `samplingProtocol` text, NERC L22 where exact). Set them through the registry helpers
   (`declare_measurement_fields()` extended, never bare `write_csv()`); `check_registry_na_strings()`.
2. `docs/db.qmd` rewrite to current practice: keys (`*_key` natural strings — `cruise_key` YYYY-MM-NODC
   by date span, `sample_key` namespaced; `*_uuid` = the provider's identifier carried as a column:
   `cruise_uuid`, `sample.source_uuid`, `station_uuid` when WS-B ships; `_source_*` stripped at freeze),
   the core family + supplemental tier + the browser-shaped pair (and `obs` as a view, H1), the
   registries (`metadata/*.csv` incl. the new ids; `dataset.csv` deprecated for the ingest YAML), coverage
   measured, the citation contract (A0), and a **"Darwin Core / OBIS ENV-DATA mapping"** section holding
   the umbrella's table with the ids now in the registries. Keep the Unicode and spatial sections.
3. `publish_ichthyo_to-obis.qmd`: fill `measurementTypeID` from the registry where present (no other
   change; the generic `publish_to-obis.qmd` is a follow-on plan — write its one-paragraph stub in
   `plans_todo/`).

Gate: `quarto render docs` passes; registry validators pass; a count of types with/without a P01 id
in the hand-back.

## H3 · The effort denominator reaches ERDDAP — Sonnet · high, Wave 2 (after H1)

Read: `publish_to-erddap.qmd` (`sql_obs()` l.260, `sql_sample()` l.276, the cfg build l.340–372,
`title_of()`/attributes l.533+), `libs/erddap_deploy.R`, the `publish_erddap_template.qmd`, CoastWatch's
`erdCalCOFIlrvcnt` / `erdCalCOFIlrvstg` variable lists as the target shape.

1. The `{dataset_key}` grain for bio datasets reads **`obs_bio`** (via the catalog, never a hand-built
   path): keep today's columns and add `tow_type`, `std_haul_factor`, `prop_sorted`, `volume_sampled_m3`,
   `density_per_10m2`, `density_per_1000m3`, `effort_class`, `units`, `qual_ok`, `scientific_name`; env
   datasets read `obs_env` (same columns, effort NULL). `_sample` grain unchanged.
2. Variable attributes in `datasets.xml`: `long_name`, `units`, `comment` with the density formulas
   (`calcofi4r::cc_density_sql()` wording), `flag_values`/`flag_meanings` on `measurement_qual` from
   `metadata/measurement_qual.csv`, `sdn_parameter_urn` when H2's `nerc_p01` exists.
3. Deploy is manual (the notebook says so): stage the new `datasets.xml`, verify one dataset's `.das`
   shows the effort columns, hand the splice to Ben.
4. `RELEASES.md # Unreleased` line under H1's heading; the ERDDAP row in `docs/db.qmd` § publishing.

Gate: `erddap.calcofi.io/erddap/tabledap/swfsc_ichthyo.das` (staging) lists `density_per_10m2`.

## H3 DONE (Sonnet) — workflows `ws-h3` @ c8f4049; docs `ws-h3` @ e9f0bba (worktree `../docs-ws-h3`)

- `sql_obs_pair(ds, root, realm)` (new, `publish_to-erddap.qmd`) replaces `sql_obs()` for the
  `{dataset_key}` grain when the release catalog carries `obs_bio`/`obs_env`: keeps every existing
  column and adds `tow_type`, `std_haul_factor`, `prop_sorted`, `volume_sampled_m3`,
  `density_per_10m2`, `density_per_1000m3`, `effort_class`, `units`, `qual_ok` — already computed
  onto the pair, no join to `sample_measurement`. A new `obs-pair` chunk decides `HAS_OBS_PAIR`
  through `calcofi4r::cc_release_sources(cc_release_catalog(RELEASE), "obs_bio"/"obs_env")` (never a
  hand-built path) and `cat()`s the decision; `sql_obs()`/the `obs` objects remain the fallback for a
  release predating D-S1 (`build_sql()`'s `grain == "obs"` branch dispatches on `HAS_OBS_PAIR`).
- **`realm_of(ds)`**: every released `dataset_key` has rows in exactly one of the pair — measured by
  rebuilding `obs_bio`/`obs_env` locally with the CURRENT `calcofi4db::build_obs_slim()` (3.31.0)
  from the read-only staging core (`obs`/`sample`/`sample_measurement`/`taxon`/`measurement_type`
  parquet) at `~/_big/calcofi/releases-staging/v2026.08.28/parquet/`, since the **committed staging
  objects there predate H1's `sample_key`/`measurement_prec`/`hex_id` columns** and could not be
  read by the new SQL as-is. 10 env datasets (`calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_dic`,
  `calcofi_mets`, `cce-lter_picoplankton-bacteria`), 10 bio (`calcofi_phyllosoma`,
  `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_zoodb`, `cce-lter_zooscan`,
  `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `swfsc_cufes`,
  `swfsc_ichthyo`) — 0 splits.
- **Row parity, both branches**: for every one of the 15 datasets, `sql_obs_pair()`'s row count
  equals `n_of(ds, "obs_bio")`/`n_of(ds, "obs_env")` and **exactly equals** the legacy `sql_obs()`
  row count over the rebuilt fixture's `obs` partitions (e.g. `swfsc_ichthyo` 482,250 both ways,
  `calcofi_bottle` 11,135,600 both ways) — both SQL paths execute error-free.
- **Live catalog check against the real promoted release**: `v2026.08.25` → `HAS_OBS_PAIR = FALSE`
  (`cc_release_sources()` throws `"table 'obs_bio' is not in the catalog for v2026.08.25"`, caught),
  confirming the fallback fires correctly in production today, not just against the local fixture.
- **`datasets.xml` attributes** (`.erddap_datavar_xml()` / `erddap_duckdb_dataset_xml()` extended
  with `flag_values`/`flag_meanings`/`sdn_parameter_urn` params): `measurement_qual` gets
  `flag_values`/`flag_meanings` from `metadata/measurement_qual.csv`'s `code_set`, matched by
  substring against `dataset_key` (only `bottle` → `calcofi_bottle` and `ctd` →
  `calcofi_ctd-cast` are registered today; the other 13 datasets get neither — verified). The
  density/`effort_class`/`qual_ok`/`scientific_name`/`units` columns get `long_name`/`units`/
  `comment` (comment wording paraphrases `calcofi4r::cc_density_sql()`'s and `cc_qual_ok_sql()`'s
  own roxygen). `sdn_parameter_urn` is wired generically, keyed by `measurement_type` name (lands
  only on a `_sample` grain's pivoted effort column, never the long `measurement_type`/
  `measurement_value` pair) — **measured 0 of 200 registered types carry `nerc_p01` today** (H2 has
  not landed); mechanism verified separately with a synthetic URN value, renders and parses clean.
- **H3 gate, satisfied via the generated XML rather than a live staging ERDDAP** (never rendered the
  notebook — no deploy): the `{dataset_key}` `dataVariable` list for `swfsc_ichthyo` includes
  `density_per_10m2`, `density_per_1000m3`, `effort_class`, `tow_type`, `std_haul_factor`,
  `prop_sorted`, `volume_sampled_m3`, `units`, `qual_ok`, `scientific_name` alongside every prior
  column; `calcofi_ctd-cast`/`calcofi_bottle` additionally carry `measurement_qual`
  `flag_values`/`flag_meanings`.
- **Investigated, NOT migrated (reported per "if not mechanical, stop and report")**:
  `libs/publish_netcdf.R` has no literal `obs` reference of its own — it is generic catalog
  plumbing (`cc_release_table()`/`cc_release_partitions()`/`cc_release_parquet()`) called with
  whatever table name a caller passes. `scripts/render_release_views.R` likewise has none — its
  table names come from `../server/postgis/init/50_release_views.sql` (a sibling repo outside this
  brief's scope and outside the `ws-sonnet-high.md` sibling-repo list); it still resolves `obs`
  fine this release since the deprecated objects ship. The actual `obs` reads RELEASES.md's H1
  section flagged live in **`publish_to-netcdf.qmd`** (`CREATE TABLE obs AS …` and
  `obs_parts <- cc_release_partitions("obs", RELEASE)`, keyed by `dataset_key` parsed off the
  partition path). Migrating it is **not mechanical**: `obs_bio` ships as one unpartitioned file and
  `obs_env` is partitioned by `measurement_type`, not `dataset_key`, so the "read this dataset's one
  partition" strategy the ~800-line notebook is built around (`obs_part_of`, `obs_ident_cols()`,
  the per-dataset CF profile builders) no longer holds for any env dataset — it would have to scan
  all 84 `obs_env` objects per dataset instead of one. Left as a dedicated follow-on; documented in
  `RELEASES.md`.
- `RELEASES.md` gained a `### ERDDAP gains the effort denominator (D-S3)` subsection under H1's
  heading; `docs/db.qmd` (own worktree, `docs-ws-h3`) gained a scoped ERDDAP paragraph under
  § Publishing to portals — a small, clearly-delimited addition so H2's broader rewrite of that
  file merges cleanly around it (no diff yet between `docs` `ws-h2` and `test` on `db.qmd` as of
  this hand-off).
- Tests run: full-file `knitr::purl()` + `parse()` (clean, twice, before and after the doc edits);
  standalone `Rscript` execution of the exact SQL/attribute-lookup code against the rebuilt local
  fixture (discover/realm classification, both `HAS_OBS_PAIR` branches' row counts, generated XML
  parsed with `xml2::read_xml()`); one live network call to the real promoted catalog. Notebook was
  never rendered.
