# WS-P1 · The pages — landing re-cut, generated dataset pages, JSON-LD, sitemap, `data.json`, refresh on dispatch

**Agent:** Opus 5 · high. **Wave 2**, `CalCOFI.github.io` worktree (+ the `gh_dispatch` row already added by
R0 in `workflows`). **Needs:** R0 merged (a real `datasets.json` on the staging or promoted release).
**Plan:** `.claude/plans/2026-09-05 CalCOFI.io as a dataset catalog — one record per dataset with every endpoint, the front door re-cut around Datasets, and the portal registrations.md` § D-2, D-3, D-4, D-5 (1–2), Decision 2–6; **the artifact is the spec**:
https://claude.ai/code/artifact/5fe1fa4e-c124-4525-a27a-a4a978abf2ba (its HTML is also in the session
scratchpad; the mock CSS uses the brand tokens by name).

## Goal

calcofi.io opens on the dataset grid; every dataset has a page at `/datasets/{dataset_key}/` with the Access
table, coverage, cite, provenance and JSON-LD; the machine files (`sitemap.xml`, `data.json`) ship; the site
refreshes itself on release dispatch.

## Read first

- `CalCOFI.github.io`: `README.md`, `_config.yml`, `index.html`, `_layouts/default.html`,
  `_includes/product_card.html`, `_data/products.yml`, `style.css`, `brand/v2/README.md` + `theme.css`
  (**use the tokens and classes; do not restyle**), `scripts/shots.py`, `scripts/check_brand.py`,
  `.github/workflows/pages.yml`.
- The record: `releases/{v}/datasets.json` (Appendix A) and `coverage.json` `years[]`; `grid.geojson`.
- `db-viz-station/.github/workflows/refresh.yml` (the dispatch-triggered rebuild pattern); the
  `brand-contract` skill in `workflows/.claude/skills/` (the new-product checklist).
- schema.org `Dataset` (Google's dataset structured-data guide); ODIS's checklist (`book.odis.org`); DCAT-US
  1.1 (`resources.data.gov/resources/dcat-us/`).

## Do

1. **Data in at build**: `scripts/fetch_release.sh` → `_data/datasets.json`, `_data/versions.json`,
   `_data/coverage_years.json` (git-ignored); `pages.yml` runs it; `.github/workflows/refresh.yml`
   (`workflow_dispatch` + weekly cron) rebuilds; local preview documented in README.
2. **`_plugins/datasets.rb`**: one page per record (`/datasets/{key}/index.html`, `{key}.json`,
   `{key}.jsonld`), `/datasets/index.html`, `/datasets/sitemap.xml`, `/data.json`, `/datasets/search.json`.
   Holdings from the record render as inventoried tiles/pages with a status chip.
3. **`products.yml` re-cut** per D-3's table: `sections:` = Datasets · Explore (two `group:` eyebrows) ·
   Access · Build · Students; `datasets:` per card (validated at build against the record ∪ holdings; an
   unknown key fails the build); the header/tab row keeps its counts.
4. **The landing page**: hero (pipeline line gains *datasets*, CTA *Browse the datasets*), the release strip,
   the category tiles (12, `cc-i-cat-*` icons: the home datasets in full; a dataset homed elsewhere that
   contributes variables here as a **muted row naming those variables** from `coverage.json` `variables[]`;
   the holdings as grey rows; **a last reference tile** — cruises, stations, the 19 spatial layers, bathymetry —
   from the record's `reference[]`, icon `lens-stations`), the filter row and
   client-side search over `search.json` (names, descriptions, variables, taxa — plain JS), then the product
   sections as today with `datasets:` chips on each card.
5. **The dataset page** per D-4 / the mockup: header chips, description, coverage stat row + years sparkline
   (inline SVG from `years[]`) + bbox over the grid (static SVG from `grid.geojson`), the Access table grouped
   by how (explore · query · code · download · services · archives & portals with status chips), cite (text
   / BibTeX built like `cc_cite()` — same wording), provenance, related, JSON-LD (`@id`, `identifier`,
   `isPartOf` the release node, `includedInDataCatalog`, `temporalCoverage`, `spatialCoverage` GeoShape box,
   `variableMeasured` with NERC `propertyID` where present, `distribution[]` DataDownload, `sameAs`,
   `version`, `dateModified`). The release itself gets `/datasets/release/` (`hasPart` the 16).
5b. **Respect `visibility`**: an `internal` dataset or holding gets no page, no sitemap entry, no `data.json`
   row. **Registration is encouraged, never required** (Decision 22): the Access table's footer and the
   download bundle carry *Register your use* (the Explorer's feedback pipeline, label `derived-product`) and
   *stay informed* (a form URL from `_config.yml`); nothing gates. Contact in JSON-LD/DCAT = `data@calcofi.io`
   (Decision 23; a `_config.yml` value, so it can change once).
6. **`scripts/check_jsonld.py`**: validate every generated page's JSON-LD (schema.org validator or
   `pyshacl` against the Google Dataset shape) and `data.json` against the DCAT-US schema; run in `pages.yml`.
7. `check_brand.py --required-only` covers `/datasets/` and one dataset page; `shots.py` captures the
   landing page and `swfsc_ichthyo` both themes; Lighthouse a11y ≥ 95 on both.

## Gates

A fresh clone builds with one command; every dataset page validates; `data.json` validates; 375 px layout
one column and no horizontal scroll; the brand check passes; the counts in the tab row equal the cards.

## Do not

Restyle brand tokens or classes; hand-author any dataset fact (the record is the only source); load
external images/scripts beyond the brand URLs; add a JS framework; touch other repos beyond the dispatch row.

## Hand back

The live preview URL (a Pages preview or the built `_site`), the validator outputs, the products.yml diff,
one *Measured* line.
