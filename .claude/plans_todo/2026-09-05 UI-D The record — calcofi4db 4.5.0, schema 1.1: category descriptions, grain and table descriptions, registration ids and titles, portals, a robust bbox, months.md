# UI-D · The record — calcofi4db 4.5.0 / schema 1.1: category descriptions, grain and table descriptions, registration ids and titles, `portals[]`, a robust bbox, `coverage.months`

**Agent:** Opus 5 · high (upgrade to Fable 5.1 · high only if the robust-bbox rule needs designing rather than
implementing). **Wave 1**, worktrees: `calcofi4db` (branch `catalog-4.5.0`) and `workflows` (branch
`catalog-record-4.5`). **Needs:** nothing. **Renders nothing** — the integrator renders staging after the merge
(the calcofi4db worktree symlink rule, integrator notes). **Plan:** `.claude/plans/2026-09-05 CalCOFI.io UI refresh — emphasis, density and the dataset page, now that the catalog is live.md` § D-9, Decision 11; the site's fallbacks
that these fields retire are listed in UI-B. **Context:** calcofi4db 4.4.0 @ main (7ef3cb42): `R/catalog_datasets.R`
(`build_dataset_catalog()`, `check_dataset_catalog()`, `read_catalog_registries()`, `.erddap_grain()` at ~line 441,
`.dist_row()`, the registrations builder ~line 790–815, `reference[]` ~line 1020), `inst/schema/datasets.schema.json`
(schema 1.0; definitions `distribution`, `registration`, `coverage`, `category`), tests
`tests/testthat/test-catalog_datasets.R` with fixtures under `tests/testthat/fixtures/catalog/`; workflows
`metadata/{category,portal,distribution,dataset_status}.csv`, `release_database.qmd` step 3b writes `datasets.json`,
`test_release.qmd` chunk `dataset_catalog`. The record the site renders today is the staging v2026.09.05 one.

## Goal

Schema 1.1, additive: the facts the dataset pages want that only the pipeline knows, each read from a registry the
team already edits, validated, tested, and written into `datasets.json` at the next release — so the site can delete
its marked fallbacks.

## Read first

- `calcofi4db/R/catalog_datasets.R` end to end; `inst/schema/datasets.schema.json`; the tests and fixtures; `NEWS.md`
  (the house rule: every `DESCRIPTION` bump gets its NEWS entry in the same change); `CLAUDE.md` (testthat rules:
  one small fixture per rule, regression cases permanent).
- `workflows/metadata/category.csv` (has `description`), `portal.csv` (`portal, name, kind, url, …, notes`),
  `distribution.csv` (27 rows: kind, portal, id, title, url, status, superseded_by, notes…), `dataset_status.csv`.
- The catalog plan's Appendix A (the record, schema 1.0) and § D-9 of the UI plan.
- The site's parser rules in UI-B § Do 5 (derive the same identifiers at build so the two agree).

## Do

1. **Schema 1.1** (`datasets.schema.json`, `schema_version: "1.1"`; additive — every new property optional/nullable):
   `category.description`; `distributions[].grain_description` (ERDDAP rows); `distributions[].table_description` and
   `objects[].table_description` (from `metadata.json` `tables{}.description`); `registrations[].id`, `.title`;
   a top-level `portals[]` (`{portal, name, kind, url, description}` from `portal.csv`, `notes` → `description` trimmed
   to its first sentence); `coverage.bbox_robust` (`{lat_min, lat_max, lon_min, lon_max}` at the 2.5–97.5 percentile of
   the dataset's sampling positions from the release's `sample`/site coordinates — document the rule in the schema
   description); `coverage.months` (12 integers, observations by calendar month, summed from the per-station rows
   `build_coverage()` already computes for `coverage_stations.json`).
2. **Builders**: `.erddap_grain()` returns the grain **and** a one-sentence description (sampling events: one row per
   cast, tow or transect — when, where and how it was sampled; observations: one row per measurement, joined to its
   event; length/stage frequency: one row per size or stage class of a specimen; full resolution: the unthinned 1 m
   bins); `read_catalog_registries()` reads `category.description`, the portal columns, and new `distribution.csv`
   columns `reg_id`/`reg_title` (or reuse `id`/`title` — pick one and say so); the registrations builder fills
   `id`/`title` from the curated row when present, else derives from the URL with the same rules as the site (EDI
   `packageid=` / `scope.identifier.revision`, NCEI `id=`, OBIS `/dataset/{uuid}`, IPT `r=`, Zenodo DOI, CalOOS
   `#module-metadata/{uuid}`, CoastWatch `tabledap/{id}`); `build_coverage()` emits `months` and `bbox_robust`.
3. **Checks**: `check_dataset_catalog()` gains `registration_without_id` (warn) for `published` rows lacking an id,
   `grain_without_description` (blocking — the builder should never emit one), and a `bbox_implausible` warning when
   `bbox` and `bbox_robust` differ by more than 5° on any side (the ichthyoplankton will trip it — that is the
   point).
4. **Tests**: one synthetic fixture per rule — a distribution with each portal URL asserting the derived id; a
   coverage fixture with an outlier position asserting `bbox_robust`; a months fixture; a category fixture with the
   description; schema validation of a full record fixture at 1.1 and the trimmed live fixture still passing.
5. **workflows**: `distribution.csv` gains the id/title columns filled for the 27 rows (from the URLs; review the
   titles against the portal pages you can reach — EDI rate-limits after ~150 requests a day, so read the existing
   `distribution_observed.json` first); a question row in the SWFSC ichthyo questions CSV/Sheet for the sampling
   coordinates behind the 0–54° N bbox (label the next free Qn, field `coverage_bbox`, status `proposed`);
   `test_release.qmd`'s catalog chunk asserts schema 1.1 and the three new checks; `tar_invalidate()` what must
   re-run; `RELEASES.md` `# Unreleased` line.
6. **NEWS.md** 4.5.0 + `DESCRIPTION` bump in the same commit; `devtools::document()`.

## Gates

`devtools::test()` green (report the count); `validate_dataset_catalog()` on the 1.1 fixture; the trimmed live
fixture (swfsc_ichthyo + calcofi_dic) builds and validates; the derived ids for the nine known URLs match UI-B's
list exactly; no render, no release, no install (the integrator installs after merge).

## Do not

Render `release_database.qmd` or `test_release.qmd`; install the package system-wide; rename or remove a 1.0 field;
touch the EML / STAC / DwC builders; write anything to GCS or a Sheet; touch the landing repo.

## Hand back

Branch + sha per repo, the test count, the schema diff, the list of derived ids, the question row text, one
*Measured* line for the plan.
