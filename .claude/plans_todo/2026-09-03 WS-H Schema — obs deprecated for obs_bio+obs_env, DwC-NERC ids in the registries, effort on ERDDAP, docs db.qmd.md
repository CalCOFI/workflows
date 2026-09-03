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
