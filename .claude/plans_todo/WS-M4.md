# WS-M4 — the figures: the timeline table, the matrix, the strips (D5, D6)

**Umbrella:** `.claude/plans/2026-09-10 Measurements catalog — the environment's Species: one page per measurement, the catalog's three indexes on the front door, agent-scaled.md` § D5, D6, § Verification M4. **Spec:** the artifact https://claude.ai/code/artifact/acc4f6c0-814e-46fe-a79a-a804edebe196 — the */measurements/* section (the timeline table, chips, matrix, datasets list, tooltips) and the *Temperature* section's strip, depth bars and month strip; the mock's own `<script>` is a reference implementation in plain JS you may port. **Agent:** `ws-opus-medium` (the same agent as WS-M3 may continue). **Repo:** CalCOFI/CalCOFI.github.io on branch `ws-m3`. **Wave 2 · ≈ 1.5 days.**

## Read first
- `assets/species.js` (the tree/matrix/icicle/strip code, `elide()`, the tooltip, the `?q=` handling, the `.sp-drawn` fix for the `[viewBox]` CSS trap, the pane-expand switches), `style.css` (`.sp-*`), `scripts/check_layout.py` (the species assertions), `_data/shots.yml`, the `dataviz` skill's non-negotiables (thin marks, legend for ≥ 2 series, text in text tokens, one sequential ramp, hover by default, reduced motion).
- The mock's JS: `drawTable()`, the matrix block, `strip()`, `depth()`, `months()`, `elide()`.

## You own
`assets/measurements.js` (new, plain JS, no library), `style.css` (`.mm-*`, additive), `scripts/check_layout.py`, `_data/shots.yml`, README (the switches).

## Do
1. **The index**: search (`?q=`, matches label · key · series · dataset · units · P01; live count), category chips (counts), the **timeline table** (one row per key grouped by category with the category's description; a bar per series on a 1949 → this-year axis from the record's `year_min/max`, decade ticks and labels in the header row; two series stack thin; hover tooltip: dataset · series · description · years · values · casts/fixes/samples · depths · column · flag · P01); columns units (title = full units) · datasets (dot + short name) · values (`fmtK`) · depth range ("surface" when max depth is 0); the **category × dataset matrix** (cell = number of keys with a series in that dataset, one accent ramp, hover lists them) and **the datasets** list (dot · name · category (omitted when equal to the name) · realm note for a bio dataset · series · years · values). Keyboard: chips are buttons with `aria-pressed`; the table is `role=table`; the tooltip is `role=tooltip`.
2. **The page**: the years strip (rows = series/datasets, one cell per year, opacity by √(n/max), legible row labels — the mock's geometry: label gutter 96, cell 8, row 22 in a 742-wide viewBox), the depth bars (eight bands, one thin bar per series, end labels kept inside the column with right padding), the month strip (12 cells per series, letters below); each drawn from the inline JSON WS-M3 emits; add the `.mm-drawn` class when drawn (the `[viewBox]` trap).
3. Elide every `.mm-url` from the middle (port `elide()`); re-run on resize and after fonts load.
4. `check_layout.py`: the assertions of § Verification M4 at 1470/375 in both themes; `shots.yml`: `measurements` and `measurement_page` captures; Lighthouse accessibility (report the score; 100 expected).
5. README: the `?q=` and chip parameters, what each figure reads.

## Gates (stop and report)
- `check_layout.py` red; the timeline wider than its scroll container at 375 without `overflow-x: auto`; a colour used as the only cue anywhere; a number typed.

## Hand back
The two pages' screenshots at both widths and themes; `check_layout.py` output; the Lighthouse score; the inline JSON size on the index (gzipped); branch + commits; one *Measured* line.
