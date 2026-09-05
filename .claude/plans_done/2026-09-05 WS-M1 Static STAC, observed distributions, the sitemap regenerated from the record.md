# WS-M1 · Static STAC (+ stac-browser), `observe_distributions()`, the sitemap regenerated from the record

**Agent:** Opus 5 · medium. **Wave 2**, `calcofi4db` + `workflows` + `CalCOFI.github.io` (only `stac/`)
worktrees. **Needs:** R0. **Integrator order:** after E1; this is **calcofi4db 4.3.0**. **Plan:** `.claude/plans/2026-09-05 CalCOFI.io as a dataset catalog — one record per dataset with every endpoint, the front door re-cut around Datasets, and the portal registrations.md` § D-5
(3), D-10, Decisions 6, 15.

## Goal

A static STAC catalog of the datasets and the spatial layers on GCS with a browser at `calcofi.io/stac/`;
the external copies of every dataset observed weekly; the ODIS sitemap generated from the record with
superseded and retired records left out.

## Read first

- STAC 1.0 spec + the `table`, `scientific` extensions; `stac-validator`; `radiantearth/stac-browser`
  build for a static root; DuckDB's `stac` community extension (a nice check: read our catalog as a table).
- `releases/{v}/catalog.json` (`objects[]`), `datasets.json`, `spatial_layers.json` (19 layers, PMTiles).
- `update_datasets-sitemap.qmd` (the current external sitemap; keep its EDI/ERDDAP fetch helpers),
  `workflows/datasets/*.csv`; EDI PASTA `listDataPackageRevisions`; `api.obis.org/v3/dataset/{id}`
  (`updated`); ERDDAP `allDatasets`.
- `metadata/distribution.csv` (R0's shape: `status`, `superseded_by`, `observed_utc`).

## Do

1. `R/stac.R`: `build_stac(record, catalog, spatial_layers, out_dir)` → `catalog.json` →
   `collections/{key}/collection.json` (extent from bbox + years; licence; providers; keywords;
   `table:columns` from `metadata.json` for the dataset's tables; `sci:doi`/`sci:citation`) → one Item per
   release `items/{key}/{version}.json` (bbox polygon, start/end datetime, assets: parquet objects
   `application/x-parquet` roles data, netCDF `application/x-netcdf`, ERDDAP `text/html` overview, ISO XML
   metadata); the 19 spatial layers as collections with PMTiles/GeoJSON assets. Written by
   `release_database.qmd` to `gs://calcofi-db/stac/`; validated by `stac-validator` in `test_release.qmd`.
2. `stac-browser` built once (root = the GCS catalog URL) into `CalCOFI.github.io/stac/` with the brand
   head block (favicon, theme colours where the app allows).
3. `R/distribution.R`: `observe_distributions(distribution, holdings, portal)` — one observer per
   `portal.csv` `observe_method`: `edi-pasta` (newest revision + pubDate), `doi` (resolves), `obis-api`
   (`updated`), `ncbi-esummary`, `zenodo-api`, `erddap-das` (`date_modified`, `time_coverage_end`), `caloos` /
   `http` (ranged GET); covers the integrated datasets' distributions **and the holdings' links** (plan
   § D-11); writes `metadata/distribution_observed.json` (`key, url, status, observed_utc, revision,
   updated, note`); nothing is deleted from the registry. A change since the last observation becomes a
   `proposed` `questions.csv` row (`observed_change`) for the dataset's provider, so it reaches the Sheet.
   `.github/workflows/observe.yml` in `workflows` runs it weekly and on `workflow_dispatch`, committing the
   observed file.
4. `update_datasets-sitemap.qmd` rewritten: `datasets/sitemap.xml` = the calcofi.io dataset pages
   (`lastmod` = max(release_date, sidecar edited_date)) + every `current` external record; runs on release
   dispatch and weekly (a small GitHub Action in `workflows`, or the existing cron host). A test asserts no
   `superseded|retired` URL and every URL 2xx.
5. Tests: STAC fixtures validate; `observe_distributions()` on saved responses (no network); the sitemap
   builder excludes a superseded fixture row. `NEWS.md` 4.3.0; `RELEASES.md # Unreleased`.

## Gates

`stac-validator` passes on root, every collection and item; `stac-browser` opens the catalog from
`calcofi.io/stac/`; the sitemap validates (sitemaps.org XSD) and lists 16 + holdings pages first.

## Do not

Make STAC the UI the catalog depends on; write ISO XML (ERDDAP already does); re-point ODISCat yourself (M2
does, with Ben).

## Hand back

The STAC root URL, the browser URL, the observed-distribution table, the sitemap, one *Measured* line.
