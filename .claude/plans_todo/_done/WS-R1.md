# WS-R1 — the idioms: ⓘ, the tabset gate + ways include, the licence chip, the badges, the legend (D1, D2, D5, D6)

**Umbrella:** `.claude/plans/2026-09-15 CalCOFI.io faces round 2 — … agent-scaled.md` § D1, D2, D5 (as revised by Q2), D6, D9, § Verification R1.
**Spec:** `.claude/plans/2026-09-15 faces-round-2/mockup.template.html` — the CSS blocks `.cc-info`, `.tabset/.tabrow/.tabpanel`,
`.way`, `.src*`, `.legend1`, `.chip-lic*` (**revised:** one glyph, one colour — see step 4), `.cc-result` (the search result row, step 8), the `<symbol>`s `i-licence`, `i-copy`, and the JS under
"tabsets" and "one ⓘ open at a time". **Agent:** `ws-sonnet-high`. **Repo:** CalCOFI.github.io (worktree
`~/Github/CalCOFI/.worktrees/CalCOFI.github.io-ws-r1`, branch `ws-r1`, from `main`). **Wave 1 · ≈ ½ day.**

## Read first (nothing else)
`assets/tabs.js` (whole; the header comment is the contract), `style.css` lines 1–80 (the tokens) and its last 60 lines (the marked
blocks; append after them), `_layouts/default.html` (where scripts and includes load), `_includes/species_credit.html` (the include
style), `brand/v2/icons.css` (the icon class names; do not edit), `scripts/check_layout.py` header (how `--url` runs one page).

## You own
`_includes/info.html`, `_includes/ways_tabs.html`, `_includes/licence_chip.html`, `_includes/result_row.html`, `_includes/icons_round2.html` (all new),
`assets/info.js` (new), `assets/tabs.js`, `_layouts/default.html`, `style.css` block `/* ── round 2 · idioms (WS-R1) */`,
`_test/round2_idioms.html` (new), README.md § a new "Round 2 idioms" paragraph.

## Do
1. **`info.html`** — params `label` (the aria-label), `body` (HTML, captured by the caller with `{% capture %}`), optional
   `align="right"`. Markup exactly: `<details class="cc-info"><summary aria-label="{{ include.label | escape }}">i</summary><div class="cc-pop{% if include.align == 'right' %} cc-pop-r{% endif %}">{{ include.body }}</div></details>`.
   CSS from the mockup's `.cc-info` block, renamed `.cc-pop`; under 640 px the pop is `position: fixed; left: 8px; right: 8px;
   bottom: calc(8px + env(safe-area-inset-bottom, 0px)); top: auto; max-height: 60vh; overflow: auto`. **`info.js`**: one open at a
   time, click outside closes, Escape closes, `defer`-loaded from `default.html` on every page (2 KB, no dependency).
2. **`tabs.js`** — the `?tab=` memory applies only to a `.tabset[data-url-tab]` (today: the first tabset on the page). Verify two
   tabsets on one page switch independently and arrow keys stay inside their own tablist. Keep the front door byte-identical in
   behaviour (its tabset carries `data-url-tab`).
3. **`ways_tabs.html`** — param `ways` (the array `page.ways` gives today: `name`, `about`, `url`, `code`) plus `group` per way
   (R3/R5 add it in the plugins; until then derive it here: name begins "Explorer" or "db-query" → `app`; "ERDDAP" → `erddap`;
   "Parquet" → `parquet`; "R" → `r`; "Python" → `python`; "JSON" → `json`). Renders: the `app` ways as `.cc-btn` buttons (the
   first solid, the rest ghost) then a `.tabset` (no `data-url-tab`) with one tab per group present, in the order erddap · parquet
   · r · python · json, each panel the group's ways as the mockup's `.way` rows (URL elided from the middle with `text-overflow`,
   a copy button using `assets/copy.js`'s `data-copy`). A single group renders no tab row.
4. **`licence_chip.html`** — params `license`, `license_url`, `name` (optional, from the record's `license_name`), `size`
   (`sm` default). Rule (umbrella D5, **as Ben revised it**): **one glyph** (`#i-licence`, a small document-with-seal) on every chip
   and **one colour** — `--muted` ink on `--panel-2` with the `--border` edge — whatever the licence; only the text and the shade
   change: CC → "CC BY 4.0" / "CC0 · public domain" / `name`, `href` = the deed; `custom` → "provider terms ↗", `href` =
   `license_url`; empty → "unstated" at 60 % opacity with a dashed edge and `title` "the record carries no licence". Classes
   `.cc-chip.cc-chip-lic` + `.cc-lic-unstated` only. Never print the raw id; never a second glyph or a status colour.
5. **`icons_round2.html`** — two `<symbol>`s (`i-licence`, `i-copy`; the mockup's `i-cc`/`i-terms`/`i-unstated` are retired) in
   one `<svg width=0 height=0>`; included once at the top of `<body>` in `default.html`.
6. **CSS** — `.cc-src` + four colour variants (from the mockup's `.src*`), `.cc-legend1` (from `.legend1`), the tabset styles as
   the mockup draws them **only where the site's existing `.tabrow` differs** (check `style.css` for the front door's tabset first;
   extend, do not duplicate).
7. **`_test/round2_idioms.html`** — a page (layout default, `sitemap: false`, `robots: noindex`) rendering: an ⓘ open and one closed,
   two tabsets, the four licence chips (same glyph, same colour, the last dimmed), the four badges in a sentence, the legend, a ways
   tabset fed by a literal array, three result rows. Run
   `scripts/check_layout.py --url http://localhost:4000/_test/round2_idioms.html --widths 1470,375 --themes light,dark` (add a
   `scroll`-only mode if the default assertions do not apply to an arbitrary page) and `scripts/check_brand.py` on it.

8. **`result_row.html`** (umbrella D9) — the one row shape the front door's Species/Measurements panels (R4) and `/species/`'s
   Matches list (R5) both render: `<a class="cc-result" href="…"><b class="cc-result-n">{name}</b>{% if c %} <span class="cc-result-c">{qualifier}</span>{% endif %}<span class="cc-result-m tab">{rank or category} · {obs} obs · {n} datasets</span></a>`
   — params `n`, `c`, `it` (italic name), `m`, `u`; one line at 1470, two at 375, the name never truncated, the meta elided from the
   end. CSS in your block. The row is what `assets/door-search.js` `rowsFrom()` already normalises to (`{n, c, it, m, u}`) — say so
   in the include's comment so R4 can render it from JS with the same class names.

## Gates (stop and report)
- Any change to `brand/v2/*`, or a glyph that needs the icon pipeline — the sprite is inline, that is the whole point.
- A tabset on the front door that no longer restores `?tab=`.

## Hand back (≤ 40 lines)
Branch + SHA; the include signatures (one line each, `result_row.html` included); the tabs.js gate line; check outputs; two shots of the test page (1470 light,
375 dark); one Measured line.
