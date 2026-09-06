# UI-A · The grid — the emphasis ladder, quiet holdings, masonry, the reference band, `variables[]` normalised

**Agent:** Opus 5 · high. **Wave 2**, `CalCOFI.github.io` worktree (branch `ui-grid`), from main **after UI-C is
merged**. **Needs:** UI-C (the chip classes, `.cc-tabs`, the map tokens). **Plan:** `.claude/plans/2026-09-05 CalCOFI.io UI refresh — emphasis, density and the dataset page, now that the catalog is live.md` § D-1, D-2, D-3, D-10,
Decisions 1–4, 13, 16; **the artifact is the spec**: https://claude.ai/code/artifact/b06dcb2e-f899-4c00-831e-7383a5f4e87e ("Emphasis is a ladder" — the four rungs rendered;
"The grid: today → proposed" — the two tiles and the 14-tile stacking schematic; the reference band mock).

## Goal

`/datasets/` and the landing page's first section read datasets first and holdings second, in a grid that is
content and not air: the four-rung ladder in tokens, holdings quiet and capped, contributions collapsed, one-line
dataset rows with a colour dot and a format phrase, masonry packing by a 40-line script, the reference tile as its
own band, and the plugin normalising `coverage.variables[]` before the next release changes its shape.

## Read first

- `_plugins/datasets.rb`: `tile_row`, `holding_row`, `categories`, `reference_tile`, `formats`, `years_bar`,
  `search_rows`, `variables_measured` (already handles string | Hash), the generator's `site.data["catalog"]`.
- `_includes/catalog_grid.html`, `_includes/catalog_filters.html`, `assets/catalog.js` (filters hide rows and tiles;
  the search index is `/datasets/search.json`), `index.html`, `_layouts/datasets.html`, `style.css` § "the dataset
  catalog", `README.md`.
- `brand/v2/README.md` + `theme.css` **after UI-C** (use the classes; do not restyle).
- The record: `_data/datasets.json` (staging v2026.09.05 through `scripts/fetch_release.sh`'s fallback): 16 datasets,
  17 holdings, 25 reference rows; `coverage.variables[]` are **strings** today and **objects** `{name, units, uri,
  category}` from the next release (calcofi4db main b4eb5062; schema `calcofi4db/inst/schema/datasets.schema.json`);
  `dataset_name_short` is null on the served holdings and authored in main; `color` per dataset is the Explorer's.
- `workflows/metadata/category.csv` (the descriptions the tile lede will show once the record carries them — do not
  type them into the site).
- Measured on 2026-09-05 (plan § Context): tile heights natural vs drawn; grid 4,910 px, masonry 4,320, reference out
  2,760; holdings `--fg` 700 + `--warn` chip vs datasets `--accent` 700.

## Do

1. **Plugin.** `normalize_variables(cov)` → `[{name, units, uri, category}]` from strings or hashes; used by the tile
   (count), `search_rows` (names) and exposed as `page.variables` for UI-B. Accept `schema_version` "1.x" (warn only
   when the major differs). `tile_row` gains `color`, `formats_phrase` ("parquet · netCDF · ERDDAP"), `n_variables`;
   contributions gain `n`; `holding_row` gains `name_full` and the tile lists at most 4 holdings with `more` (the rest
   still in the DOM inside a `<details>`, so search matches them). `reference_tile` becomes `reference_band` — tables
   · layers grouped by `group` in the record's order (Maritime Zones, Protected Areas, Administrative, Ecological,
   Energy & Industry) · rasters — rendered by a new `_includes/reference_band.html` **after** the grid on both pages;
   the tile leaves `catalog_grid.html`. Tile lede: `category.description` **only if the record has it** (it does not
   yet — render nothing, never a typed description).
2. **Includes / markup** per D-1: rung 1 rows — dot (`style="--dot: {{ d.color }}"`, a 9 px circle in the accent when
   null) · name (`--accent` 700) · one-line meta (provider chip · years · sparkline with a `<title>` · n obs · the
   format phrase in mono · licence chip when present); rung 2 — hollow dot in the dataset's colour, italic
   "contributes", `<details><summary>n variables</summary>chips</details>`, "· homed in …"; the separator
   "not yet in the database · n"; rung 3 — `dataset_name_short || dataset_name` clamped to one line (`title=` the
   full name), `.cc-chip-quiet` provider and stage, source ↗; rung 4 in the band. Stage chips: never `--warn`.
3. **CSS** (`style.css`, tokens only): the ladder; `.ds-row-holding .ds-row-name { color: var(--muted); font-weight: 400 }`
   with underline on hover; `.ds-grid { align-items: start }` as the no-JS state; `.ds-grid.is-masonry { grid-auto-rows:
   8px; row-gap: 0 }`; the band; 375 px stays one column; the landing page's `.section-tabs` → `.cc-tabs` (keep the
   old class as an alias for one release).
4. **`assets/masonry.js`** (≤ 40 lines, plain JS, `defer`): if `CSS.supports("grid-template-rows", "masonry")` set that
   and stop; else after `document.fonts.ready`, on `resize` (rAF-debounced) and on `ds:filtered` (dispatch it from
   `catalog.js` at the end of `apply()`), set `gridRowEnd = "span " + Math.ceil((h + 24) / 8)` per visible tile and add
   `is-masonry`. Reading order unchanged (DOM order); hidden tiles get no span.
5. **`scripts/check_layout.py`** (new; shot-scraper, modelled on `check_brand.py`): `--url` for `/datasets/` at 1470 and
   375 px, both themes: (a) max drawn/natural tile ratio ≤ 1.25 (measure natural by toggling `align-items: start` and
   clearing spans in page JS); (b) every `.ds-row-holding .ds-row-name` computed colour equals `--muted`; (c) no element
   in a holding row computes to `--warn`; (d) `document.documentElement.scrollWidth <= innerWidth`; (e) prints the grid
   height. Exit 1 on failure. UI-B extends it with the page assertions; UI-F wires it into CI.
6. Search and filters keep working: the free-text search matches holdings' full names and collapsed contribution
   chips; the facets' hidden-row logic unchanged; the reference band is untouched by filters.
7. `README.md`: the ladder, the script, the band, the check. NEWS is not a thing in this repo; the commit message says
   what changed and why.

## Gates

- `scripts/build.sh serve` from a fresh clone builds; `jekyll build` < 1 s.
- `check_layout.py --url http://localhost:4000/datasets/` green both themes; grid height at 1470 ≤ 4,400 px with the
  staging record (report the number and the per-tile ratios).
- `check_brand.py --url` on `/` and `/datasets/`; `check_jsonld.py _site` unchanged and green.
- Lighthouse accessibility 100 on `/` and `/datasets/`, both themes; 375 px one column, no horizontal scroll.
- A build against a record whose `variables[]` are objects renders (make a copy of `_data/datasets.json` with the
  CTD casts' variables converted to `{name, units: null, uri: null, category: null}` and build once from it).

## Do not

Touch `_layouts/dataset.html` or the Access includes (UI-B's); change `brand/v2/` (UI-C's); edit `_data/products.yml`
(UI-E's templates come through the integrator); type a dataset fact, a category description or a portal name; add
a framework or an external asset; change JSON-LD, sitemap, `data.json` or `search.json` shapes.

## Hand back

Branch + sha, the `check_layout.py` output (heights, ratios), Lighthouse scores, screenshots of `/datasets/` at 1470
and 375 in both themes, one *Measured* line for the plan.
