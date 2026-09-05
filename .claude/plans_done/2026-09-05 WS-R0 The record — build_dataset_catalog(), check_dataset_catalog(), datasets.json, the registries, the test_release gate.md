# WS-R0 · The record — `build_dataset_catalog()`, `check_dataset_catalog()`, `datasets.json`, the registries, the `test_release` gate

**Agent:** Fable 5.1 · xhigh. **Wave 1**, own worktrees in `calcofi4db` + `workflows`. **Blocks:** everything
(P1, E1, M1 read the record; R1/R2 write the registries you define). **Integrator order:** first;
this is **calcofi4db 4.1.0**. **Plan:** `.claude/plans/2026-09-05 CalCOFI.io as a dataset catalog — one record per dataset with every endpoint, the front door re-cut around Datasets, and the portal registrations.md` § D-1, D-10, Appendix A.

## Goal

One generated record per `dataset_key`, `datasets.json`, written beside `catalog.json` at release and gated
like the citation contract — the single dataset list every product will read. Do not build pages, EML or
STAC here; define the record they read.

## Read first

- Appendix A of the plan (the record shape) and § D-1 (joins, distributions, registrations, holdings).
- `calcofi4db/R/wrangle.R` `ingest_yaml_to_dataset_df()` / `.dataset_entry()`; `R/coverage.R`
  (`observed_coverage()`, `build_coverage()`); `R/citation.R` (`check_dataset_citation()` — mirror its
  finding-table shape and its `CALCOFI_SKIP_LINK_CHECK` split); `R/release.R` (the catalog writer).
- `workflows/release_database.qmd` chunks `dataset_coverage`, `browser_objects` (where `coverage.json` is
  built), the `catalog.json` write and `sidecar_urls`; `test_release.qmd` (the consumer-contract suite and the
  `gh_dispatch` tribble).
- `workflows/metadata/{category,provider,license,dataset_status}.csv`; `scripts/build_workflows_index.R`
  (registry validation precedent, ranged-GET liveness probe — never HEAD).
- Live: `https://erddap.calcofi.io/erddap/tabledap/allDatasets.csv?datasetID,title`;
  `https://storage.googleapis.com/calcofi-files-public/netcdf/{key}/manifests.json` + `latest.txt`;
  `releases/v2026.09.04/{metadata,coverage,catalog}.json`.

## Do

1. **Registries** (shapes are the contract R1 fills; create with headers + the rows you can measure):
   `metadata/holdings.csv` (`key,name,category,provider,status,link,doi,module,lead_name,lead_email,
   lead_affiliation,priority_caloos,gh_issue,notes`); `metadata/distribution.csv` (`dataset_key,kind,portal,
   id,url,title,status,superseded_by,observed_utc,notes` — `kind ∈ download|service|mirror|source|archive`,
   `portal ∈ erddap-calcofi|erddap-noaa|edi|ncei|obis|ipt|caloos|datazoo|ucsd-library|zenodo|ncbi|calcofi.org|
   other`, `status ∈ current|superseded|retired|external|planned`); `metadata/portal.csv` (the portals.qmd
   capability table + `harvests_from_us`); `dataset_status.csv` + `publish_ncei`, `publish_caloos`.
   Validate `category`/`provider`/`license` against their registries; an unknown value errors. **A holding is
   a dataset without a release** (plan § D-11): it has a `dataset_key` and a sidecar with `status:
   planned | external | archived`; `holdings.csv` is *generated* from those sidecars by the record builder
   (`holdings[]` in `datasets.json` carries the same identity/attribution/links blocks, no release blocks);
   `portal.csv` gains `observe_method`. Every sidecar carries `visibility: public | internal` (default
   `public`); an `internal` dataset or holding is in the record but flagged so every public surface skips it
   (plan § D-11, Decision 25). The record also carries **`reference[]`** — the cruise reference, the station
   grid, the 19 spatial layers and the GEBCO bathymetry — from `catalog.json`, `spatial_layers.json` and
   `bathymetry/gebco_2025.json` (Decision 20). Contributions (a dataset's variables in another category) come
   from `coverage.json` `variables[].category` ≠ the dataset's own `category`, **env realm only** — a shared
   count type (`abundance`) never makes a bio dataset a contributor (plan § D-3).
2. **`build_dataset_catalog(con, meta, coverage, catalog, registries, version)`** → the Appendix A record:
   the metadata block; coverage roll-up (`years[]`, `n_stations` from `stations[]`, `n_variables`,
   `n_taxa`, depth range, `variables[]`, `life_stages[]`); `objects[]` = the dataset's partitions + owned
   tables with `bytes/sha256/since`; `since_version` from `versions.json`'s sidecars; **measured
   distributions** — ERDDAP ids by `dataset_key` prefix (legacy ids from `distribution.csv`), netCDF
   `canonical_url`+`sha256`+`bytes`+`cf_scope`, parquet objects, the ingest notebook, `link_data_source`
   classified by host, `link_calcofi_org`, plus the curated rows of `distribution.csv`; `registrations[]`
   from `dataset_status.csv` (`published|planned|n/a` + issue/url); `status` + `questions_open` (count
   `open|proposed` in the dataset's `questions.csv`); `holdings[]` from the registry. `null`, never `""`.
3. **`check_dataset_catalog(record)`** → finding table (`dataset_key, finding, detail`): `missing_name`,
   `unregistered_category`, `unregistered_provider`, `missing_description`, `missing_bbox`,
   `no_download`, `no_citation` (exempt while an open/proposed `questions.csv` row on `related_table =
   dataset` covers it — reuse `check_dataset_citation()`'s exemption), `url_dead` (ranged GET; 404/410/451
   error, 5xx warn; behind `CALCOFI_SKIP_LINK_CHECK`). Errors fail the release.
4. **Wire it**: `release_database.qmd` writes `datasets.json` (+ `{key}.json` per dataset under
   `datasets/`) after `build_coverage()`; `RELEASE_REQUIRED_OBJECTS` gains it; `test_release.qmd` gains a
   schema check (JSON schema file in `calcofi4db/inst/schema/datasets.schema.json`), `n(datasets) ==
   n(metadata.json datasets)`, and a dead-URL check; `sidecar_urls` lists it. Add the dispatch row for
   `CalCOFI/CalCOFI.github.io` `refresh.yml` to `gh_dispatch` (P1 creates the workflow; a missing workflow
   is a warning, not a failure).
5. **Tests** (`tests/testthat/test-catalog_datasets.R`): fixtures = calcofi4r's `v2026.09.04` catalog + a
   trimmed `metadata.json`/`coverage.json` (two datasets: `swfsc_ichthyo`, `calcofi_dic`); assert the two
   records exactly (snapshot), one red test per finding, the schema validates the fixture, no network.
6. `NEWS.md` 4.1.0; `RELEASES.md # Unreleased` ("Every dataset has a record: datasets.json"); CLAUDE.md
   two sentences under § Metadata registries (the three new files).

## Gates

`devtools::test()` green; a **staging** render of `release_database.qmd` (`CALCOFI_RELEASE_PREFIX=ducklake-staging/releases`,
`CALCOFI_TABLES_PREFIX=ducklake-staging/tables`) writes a `datasets.json` whose 16 records validate; the
finding table on the live release is exactly: `no_citation` × 5 (all exempt), `url_dead` × 0.

## Do not

Hand-author any dataset fact in the landing repo; invent a contact, licence or keyword; delete a registry row
(status it); build pages, EML, STAC, DwC here; bump calcofi4db past 4.1.0.

## Hand back

The record for `swfsc_ichthyo` as JSON, the finding table, the registry column lists, the `RELEASES.md`
text, one *Measured* line.
