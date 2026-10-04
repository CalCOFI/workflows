# WS-R3 — the measurement body: the flagged stat, one method at a time, the duplicates dropped, quality as chips, ways tabbed, captions behind ⓘ (M1 M7 M8 M9 M11 M12 M13)

**Umbrella:** `.claude/plans/2026-09-15 CalCOFI.io faces round 2 — … agent-scaled.md` § D1, D2, D3, D8, § Verification R3.
**Spec:** `.claude/plans/2026-09-15 faces-round-2/mockup.template.html` sections `#f-m1`, `#f-m7`, `#f-m11`, `#f-m12` (markup and
their "why" paragraphs). **Agent:** `ws-sonnet-high`. **Repo:** CalCOFI.github.io (worktree `…/CalCOFI.github.io-ws-r3`, branch
`ws-r3`, from `round-2` after R1 merged). **Wave 2 · ≈ ¾ day.** R2 works on the face and the why section at the same time — you do
not touch `measurement_face.html`, `measurement_why.html`, `measurements.js`, or `how_rows()`.

## Read first (nothing else)
`_layouts/measurement.html` (whole), `_includes/measurement_ways.html`, `_includes/measurement_rows.html`,
`_plugins/measurements.rb` — `ways_rows()`, `quality_rows()`, the `flag_note`/stats builders (grep `flag_note`, `"stats"`),
`style.css`'s `.mm-*` block (grep `.mm-flagnote`, `.mm-qual`, `.mm-ways`), R1's include signatures (`info.html`, `ways_tabs.html`)
from its hand-back in the umbrella § Measured, `scripts/check_layout.py`'s measurement-page assertions.

## You own
`_layouts/measurement.html`, `_includes/measurement_ways.html` (retire: the layout includes `ways_tabs.html`),
`_includes/measurement_rows.html`, `_plugins/measurements.rb` — **`ways_rows()` and `quality_rows()` only**, `style.css` block
`/* ── round 2 · measurement body (WS-R3) */`, the measurement-page assertions you change in `scripts/check_layout.py`,
README.md § the measurements catalog (one paragraph).

## Do
1. **M1.** Remove `.mm-flagnote`. The stats band gains `flagged` (`totals.n_flagged`, class `mm-stat-flag` in `--warn`) with an ⓘ
   (`info.html`, body = the flag-note HTML the plugin already composes, verbatim); a key with `n_flagged == 0` shows `0` and no ⓘ.
2. **M7.** Remove the *What it is* section (`#what`: the repeated definition, the chain, the "Identity, never resemblance" note).
   Hand the chain to R2's What column ⓘ by leaving `f.chain` in `page.face` untouched (R2 reads it) — you only delete the section.
   The big structure cards (`.mmf-mols`) and the ChEBI credit stay, retitled *The structure* (they are the What section's figure).
3. **M8.** *How it is measured* becomes a `.tabset` (no `data-url-tab`), one tab per `f.how` row labelled `name` + a `.pill` of its
   years; the card keeps `instrument`, `principle` (+ source), `steps`, the `mmf-spec` strip host (R2's JS draws it; keep the id and
   `data-nm`), `precision`, the flag chip, the pin; **drop** the values/years/column chips (they are *Measured in*'s). One row → no
   tab row. Keep `id="how"` on the section (R2's "n methods ↓" targets it).
4. **M9.** Remove *Where in the water column* (`#mmf-col` and its note). *By depth* stays.
5. **M11.** `quality_rows()` adds a `chips` array: bounds (`bounds.lo … bounds.hi units`, title = the drop rule), observed
   (min of series' `qual_ok.observed.min` … max of `.max`, title = each series' min · median · max), flagged (`n_flagged`, class
   warn, title = the per-series flag columns), baseline (`climatology ✓` / `no climatology`, title = the baseline text). The layout
   draws the chip line then `<details class="ds-details"><summary>details</summary>` with today's `dl` inside.
6. **M12.** `ways_rows()` sets `group` per way (app · erddap · parquet · r · python · json — the rule in R1's include header); the
   layout includes `ways_tabs.html`; *This page as data* becomes the `json` way; the JSON-LD paragraph moves into an ⓘ on the
   *Ways in* heading; *Cite* stays as one line.
7. **M13.** Every `.mm-note` that captions a figure (the strip, By depth, By month, Related) becomes an ⓘ on its heading, text
   verbatim.
8. **D8.** Update the assertions you break; add: no `.mm-flagnote`; a `.mm-stat-flag`; no `#what`, no `#mmf-col`; `#how .tabset`
   with `f.how.size` panels (temperature 2, ph 1 → no tabrow); `.mm-qual .cc-chip` count 4; the ways tabset present. Measure the
   page height at 1280 px light for temperature before and after (shot-scraper `--width 1280` → image height) and report it.

## Gates (stop and report)
- A number you would have to type for the chip line.
- Any edit to files R2 owns; any change to `page.face`.

## Hand back (≤ 40 lines)
Branch + SHA; the `group` rule as coded; the chip line as rendered for temperature (text); check output for temperature, ph, nitrate
at 1470/375 both themes; shots of temperature (1470 light, 375 dark); one Measured line (height before/after, sections removed).
