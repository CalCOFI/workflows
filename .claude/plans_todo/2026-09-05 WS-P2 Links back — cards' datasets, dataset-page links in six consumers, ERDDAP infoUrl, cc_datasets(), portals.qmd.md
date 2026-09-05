# WS-P2 · Links back — cards' `datasets:`, dataset-page links in six consumers, ERDDAP `infoUrl`, `cc_datasets()`, `docs/portals.qmd`

**Agent:** Sonnet · high. **Wave 3**, worktrees in `db-schema`, `db-query`, `explore`, `db-viz-station`,
`db-viz-hex`, `ctd-transects`, `calcofi4r`, `calcofi4py`, `docs`, `erddap`/`workflows`. **Needs:** R0 (the
record), P1 (the page URLs). **Plan:** `.claude/plans/2026-09-05 CalCOFI.io as a dataset catalog — one record per dataset with every endpoint, the front door re-cut around Datasets, and the portal registrations.md` § D-6, D-7, Phase 2; § D-5 (4, 4b) for the ERDDAP globals.

## Goal

Every place a dataset is named links to its page, the two packages can list the datasets, ERDDAP's own
metadata points at the pages, and the portals chapter tells the story the record now carries.

## Read first

- The record (`datasets.json`) and the page URL pattern `https://calcofi.io/datasets/{dataset_key}/`.
- `db-schema/app.js` (`renderDatasets`), `db-query/_queries/datasets/`, `explore/src/sources.tsx` +
  `cite.ts`, `db-viz-station/public/app.js` (the station panel's dataset rows), `db-viz-hex` (the
  download bundle's `CITATION.md` and the About), `ctd-transects` (footer).
- `calcofi4r/R/release.R` (`cc_catalog()`, `cc_cite()`), `calcofi4py/src/calcofi4py/release.py`
  (`cite()`); their fixture-parity tests.
- `docs/portals.qmd`, `docs/data/portal_comparison.csv`, `docs/diagrams/portals_flow.mmd`; the plan's
  Appendix C and § D-6; `metadata/portal.csv` (R0).
- `workflows/publish_to-erddap.qmd` (E1's `erddap_globals()` if merged; else set `infoUrl` directly).

## Do

1. `products.yml` `datasets:` for every card (P1 added the validation; fill the lists — the plan's D-2 has
   the assignments); the section re-cut is P1's.
2. A "dataset page ↗" link where each consumer names a dataset (db-schema Datasets tab, db-query Datasets
   category description, Explorer Sources line/modal, Station Explorer panel, Hexagon Explorer About + bundle
   `CITATION.md`, CTD Transects footer). One commit per repo, brand-conformant, no layout changes.
3. `calcofi4r::cc_datasets(version = "latest")` and `calcofi4py.cc_datasets()` — read `datasets.json`
   into a data frame (one row per dataset, distributions/registrations as list columns); `cc_cite()` output
   gains the page URL line. Byte-identical fixture between the two. `NEWS.md` 1.19.0 / `CHANGELOG.md` 0.7.0.
4. `docs/portals.qmd` rewritten: the capability table generated from `metadata/portal.csv` (EDI, NCEI,
   OBIS, ERDDAP, CalOOS, IOOS, Zenodo, ODIS, Google Dataset Search, data.gov); a per-dataset registration
   table read live from `datasets.json`; the *CalCOFI.io Tools* section replaced by the catalog; the flow
   diagram gains the catalog node. `docs/data-access.qmd` and `index.qmd` link the catalog.
5. `publish_to-erddap.qmd`: `infoUrl` = the dataset page; `creator_*`/`license`/`keywords` from the record.

## Gates

Each repo builds/tests as before; the brand check passes on every touched product; the docs render.

## Do not

Change any app's layout; add a dataset fact outside the record; rename a section of the docs book.

## Hand back

The list of commits per repo, the `cc_datasets()` fixture, the rendered portals chapter URL, one *Measured* line.
