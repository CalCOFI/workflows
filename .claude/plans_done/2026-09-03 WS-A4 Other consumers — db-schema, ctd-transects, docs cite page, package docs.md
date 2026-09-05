# WS-A4 · Other consumers — db-schema, ctd-transects, `docs/cite.qmd`, package docs

**Agent:** Sonnet · high. **Wave 3** (after A0 + A2). Repos: `db-schema`, `ctd-transects`, `docs`,
`calcofi4r` / `calcofi4py` docs only.
**Plan:** umbrella § *WS-A › Other consumers*.

## Do

1. **db-schema** (`app.js` ~l.945–955 already renders `Cite:` and a license chip): add the DOI link, make
   the license chip link to `license_url` / the SPDX page, show `acknowledgement`, and a "How to cite this
   release" block from `catalog.json` `citation` (fall back silently on older catalogs).
2. **ctd-transects**: the figure footer / About names `calcofi_ctd-cast` with its citation and the
   release citation (read from the catalog it already resolves through).
3. **`docs/cite.qmd`** — the canonical "Data Sources & Attribution" page (Erin's 4): rendered from the
   promoted release's `dataset` table via `calcofi4r::cc_get_db()` (one row per dataset: citation,
   license, DOI, PIs, links, `source_accessed`), the release citation, `cc_cite()` examples in R and
   Python, and the front door (Q3). Add to `_quarto.yml` nav; link from `db.qmd` and `portals.qmd`
   (the two lines that mention citation today).
4. `docs/db.qmd`: the `dataset` table's new columns; `cruise_uuid` / `source_uuid` wording comes from WS-B.
5. **db-viz-station is Betty's** — do not edit; write the hand-back note: `datasets_meta.json` should
   pick up `doi`/`license_url`/`acknowledgement` from `scripts/build_datasets.sql`, and Pooh Venrick's
   request (one heading "Phytoplankton abundances by species" instead of per-parameter sub-headings).

## Gates

`quarto render` of docs passes; db-schema renders on v2026.08.25 (no new columns) and on a staging
catalog with them; screenshots both themes for any card that changes (`brand-contract` skill).

## Hand back

Commits per repo, the note for Betty, screenshots.
