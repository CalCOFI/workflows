# WS-MF5 — the measurement page: the face row, the sentence and its alternatives, What / How / Why (D1–D7)

**Umbrella:** `.claude/plans/2026-09-11 Measurement faces — what it is, how it is taken and why it matters on every measurement page, agent-scaled.md` § D1–D7, § Verification MF5. **Spec:** the artifact https://claude.ai/code/artifact/aefb4449-c780-4da9-8216-3cbe91530e03 — every section; the eleven cast keys show every state. **Agent:** `ws-opus-medium`. **Repo:** CalCOFI.github.io (`~/Github/CalCOFI/.worktrees/CalCOFI.github.io-ws-mf5`, branch `ws-mf5`). **Wave 1 · ≈ 1.5 days.**

## Read first
- The umbrella's D1–D7 and Appendix A (both JSON shapes). `.claude/plans/2026-09-11 measurement-faces-probe/` `template.html` — the reference implementation: `head()`, `whatGlyph`, `whatFig`, `chain`, `howCards`, `howCol2`, `scaleChart`, `anomalyBands`, `anomalySpark`, `bjerrum`, `ionBar`, `phStrip`, `beaufortMini`, `hairFigure`, `sentence`, `whyAlts` and the CSS; `data.json` as the fixture (it carries both halves for eleven keys; split it into a 1.1-shaped `measurements.json` excerpt and a `measurements_media.json` for local builds).
- The site: `_plugins/measurements.rb`, `_layouts/measurement.html`, `_includes/measurement_*.html`, `assets/measurements.js`, `style.css` `.mm-*` block; the datasets catalog's collapsed block (`_includes/catalog_grid.html` "not yet in the database", `.ds-details` / `.ds-holdings-det` in `style.css`) — the why's alternatives use that idiom; `assets/section.js` (the pin's look); `scripts/check_jsonld.py`, `scripts/check_layout.py`, `_data/shots.yml`; `brand/v2/theme.css` (frozen; site tokens in `style.css`).

## Before you start
Create the worktree from CalCOFI.github.io `main` **only after the species-faces PR (branch `species-faces`, integrator
session "workflows-e5") has merged** — it edits `style.css`, `scripts/check_layout.py`, `scripts/fetch_release.sh`, `README.md`
and `index.html`, which this brief also touches. In those shared files append your own marked section and never rewrite
theirs; rebase on `main` before opening the PR. Expect after that merge: `/* ── faces (WS-F3) */` and `/* ── index glyphs (WS-F4) */`
in style.css and `// ── faces` / `// ── index glyphs` in assets/species.js — add yours after them.

**Met 2026-09-11:** species-faces merged to main as `3a49931` (PR #20), after ws-mcat (#21, `5faa8c2`). `style.css` ends with
`/* ── faces (WS-F3) */` then `/* ── index glyphs (WS-F4) */`; `scripts/check_layout.py` has the species assertions near the end —
append after both.

## You own
`_plugins/measurements.rb`, `_layouts/measurement.html`, `_includes/measurement_face.html` (new), `_includes/measurement_why.html` (new), `assets/measurements.js` (a `// ── faces (WS-MF5)` section), `style.css` (a `/* ── faces (WS-MF5) */` block), `scripts/check_jsonld.py`, `scripts/check_layout.py`, `_data/shots.yml`, `README.md` § the measurements catalog → *Faces*.

## Do
1. **measurements.rb** — merge `site.data.measurements_media` by key (nil-safe); compose the sentence server-side (NERC definition's first sentence · the record sentence from the key's numbers and its `spark_band` · the rank-1 why with its citation links) and the alternatives list; a page without a face renders as today.
2. **The face row** under the stats band: What (the structure SVG inline, the formula line, NERC's definition clamped; the ion bar, the carbon trio, the scale strip, the organism or the stands-in chip per `face.kind`) · How (platform glyphs, the first series' instrument, the wavelength chip, the pin link) · Why (the spark band, its trend or high, the first GOOS question); then the sentence and `<details class="ds-details">` "other ways to say why · n", closed on load.
3. **Three sections after *Measured in***: *What* (the big face + the chain), *How* (a card per series + *Where in the water column*; chlorophyll's acid figure), *Why* (the familiar scale with its flags, the anomaly small multiples with ONI shading and the deeper-bands note, the EOV card). Draw from one inline `<script type="application/json" id="mm-face">`.
4. **JSON-LD** — the `DefinedTerm` gains `image` (the structure as a data-URI SVG or its bucket URL) and `sameAs` (ChEBI, CAS, WoRMS) — never a stand-in's borrowed ids.
5. **Checks** — `check_layout.py` at 1470/375 both themes on the seven pages of § Verification MF5: face kind present, details closed, no horizontal scroll, no overlapping scale labels; `check_jsonld.py` asserts `image`/`sameAs` where a structure exists and none on stand-ins; reshoot.

## Gates (stop and report)
- A number you would have to type: it belongs in the record or the media JSON.
- A page without media differs from `main`'s build.

## Hand back
Branch + SHAs; screenshots of the seven pages (1470/375, both themes); the check outputs; one JSON-LD sample; one *Measured* line.
