# WS-R4 — the front door: one search with results in the panel, the row without formats, one licence chip, variables on homed rows; the dataset page's keyword leaves and Access tabs (D1 D2 D3 D4 D5 S1 S2)

**Umbrella:** `.claude/plans/2026-09-15 CalCOFI.io faces round 2 — … agent-scaled.md` § D2, D3, D5 (revised), D8, **D9**, § Verification R4; Q1 and Q2 are answered there.
**Spec:** `.claude/plans/2026-09-15 faces-round-2/mockup.template.html` sections `#f-d1` (the `.ds-row` grid, the `rows()` JS that
builds it, `.lic-anat`) and `#f-s1`; `mock_datasets.json` is the sixteen rows' licence/coverage excerpt. **Agent:** `ws-sonnet-high`.
**Repo:** CalCOFI.github.io (worktree `…/CalCOFI.github.io-ws-r4`, branch `ws-r4`, from `round-2` after R1 merged). **Wave 2 · ≈ 1 day.**

## Read first (nothing else)
`_includes/catalog_grid.html` (whole), `_plugins/datasets.rb` lines 560–640 (facets, `formats_phrase`, the row fields) and the
`keywords`/`access` builders (grep `"keywords"`, `"access"`, `pair`), `_layouts/dataset.html` lines 291–330 (the head chips) and
383–430 (Overview: keywords) and 519–570 (Access), `assets/catalog.js` (the search + filter: does a hit inside a closed `<details>`
open it? the holdings block already does — reuse that path), `style.css` `.ds-row*`, `.ds-chip-lic`, `.ds-fmt`, `.ds-contrib-*`,
`scripts/check_layout.py`'s `grid`/`ladder`/`filter` assertions and `DATA_SECTION_BASE`, R1's `licence_chip.html` and
`result_row.html` signatures, `assets/door-search.js` (whole — its `rowsFrom()` already normalises the three records to the
result-row shape), `index.html` lines 326–352 (the door search) and the Species/Measurements tab panels that follow.

## You own
`_includes/catalog_grid.html`, `_includes/catalog_filters.html` (the Search input goes), `_plugins/datasets.rb` (row fields,
licence fields, the expander lists, keyword leaves, access groups as tabs), `_layouts/dataset.html`, `assets/catalog.js` (the query
source moves to `#door-q`), `assets/door-search.js` (results into the panel), `index.html` § the door search and the two index
panels, `style.css` block `/* ── round 2 · front door (WS-R4) */`, `DATA_SECTION_BASE`, the row and search assertions in
`scripts/check_layout.py`, README.md § the catalog's layout rules and § the door search (one paragraph each).

## Do
1. **D1.** Remove `.ds-fmt` from the homed row; keep `data-fmt` on the `<li>` (the Format filter still works) and `formats_phrase`
   for the dataset page if it uses it (grep).
2. **D2.** The row's last column is `{% include licence_chip.html license=d.license license_url=d.license_url name=d.license_name %}`
   (add `license_url`/`license_name` to the row fields from `attribution`). The `data-lic` facet keeps the raw id. The dataset head
   (`dataset.html` line ~312) uses the same include in place of the plain chip. A homed row with no licence shows the dimmed
   "unstated" chip — same glyph, same colour (Ben, Q2).
3. **D3.** Row fields gain `n_var`, `n_taxa`, and the first eight names: variables from `coverage.variables[].name` (env) or taxa
   from `coverage.taxa[]` sorted by `n_obs` desc, `scientific_name` italic (bio); the row draws
   `<details class="ds-vars"><summary>n variables ▸</summary>` (or `n taxa`) with the chips and, when more than eight, a quiet
   "… all n on the dataset page" chip linking `#coverage`. The names stay in the DOM so the search box matches them; a search hit
   inside a closed expander opens it (the holdings path in `catalog.js`).
4. **The row grid.** `.ds-row { display: grid; grid-template-columns: minmax(0,1.25fr) auto minmax(0,1.9fr) auto }` — name ·
   provider · (years · spark · obs · expander) · licence — as the mockup's `.ds-row`; two columns under 720 px with the meta
   spanning. Contributing rows and holdings keep their markup (the emphasis ladder assertions).
5. **S1.** `keywords` on the dataset page render the leaf (the text after the last `>`, title-cased as the record has it) with
   `title` = the full path; `data.json`/JSON-LD keep the full strings (touch nothing there).
6. **S2.** `#access` becomes a `.tabset` (no `data-url-tab`): one tab per `page.access[]` group labelled `g.title` with a `.pill`
   of its row count; each panel is the group's blocks exactly as today (the `pair` left/right wrapper is dropped — a tab panel is
   one group). The `ds-tabs` sub-nav's "Access n" is unchanged. The policy line and the access-foot paragraph stay under the tabset.
7. **D4 + D5, one search (umbrella D9).** Remove the catalog's `#ds-q` field from `catalog_filters.html`; the selects share the
   freed width (`.ds-filters` grid: measure the select widths at 1470 before/after). `#door-search` becomes full width of the
   container. `catalog.js` reads its query from `#door-q` (and from `?q=` on load) instead of `#ds-q`, unchanged otherwise, so the
   `filter` assertion still passes. `door-search.js` keeps its listbox for keyboard users (Enter opens the first hit) **and** renders
   the query's hits into the open tab's panel: Datasets → nothing new (the grid filters); Species → a `#door-species-results` list of
   `.cc-result` rows (R1's `result_row.html` markup, built in JS from `rowsFrom()`'s `{n, c, it, m, u}`, up to 50 by observations,
   an "all n in /species/?q=…" link last) replacing the panel's door paragraph while a query is non-empty; Measurements → the same
   into `#door-measurements-results`. Switching tabs re-renders for the current query; clearing the box restores the panels. `?q=`
   rides the URL. The sardine/nitrate placeholders stay.
8. **D8.** Measure the front door's data section height at 1470 light before and after; set `DATA_SECTION_BASE`; add: no `.ds-fmt`
   in `.ds-row-dataset`; every `.ds-row-dataset` has a `.cc-chip-lic` whose text is never "custom"; `.ds-vars` on every homed row
   with `n_var > 0 or n_taxa > 0`; `#access .tabset .tabpanel` count = groups; exactly one `input[type=search]` inside `#datasets`;
   `?q=sardine&tab=species` renders ≥ 1 `.cc-result` in the Species panel; `?q=krill` filters the grid to the euphausiid rows. Run the
   default paths + `/datasets/calcofi_bottle/` + `/datasets/cce-lter_euphausiids/` at 1470/375 both themes. Shots: `/` (`#datasets`,
   and once with `?q=sardine&tab=species`) and `/datasets/calcofi_bottle/` (1470 light).

## Gates (stop and report)
- A licence name the record lacks and `metadata/license.csv` does not carry (report the id; never invent a name).

## Hand back (≤ 40 lines)
Branch + SHA; the row fields added (one line); `DATA_SECTION_BASE` before/after; the filter selects' widths before/after; the licence chip per dataset as rendered (16 lines,
key → text); check output; the three shots; one Measured line.
