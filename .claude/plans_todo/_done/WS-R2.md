# WS-R2 — the face drawn to scale: ramps per kind, the spark's axis, the history's own scale, the pin, the badges (M2 M3 M4 M5 M6 M10 M14)

**Umbrella:** `.claude/plans/2026-09-15 CalCOFI.io faces round 2 — … agent-scaled.md` § D3, D4, D6, D7, D8, § Verification R2.
**Spec:** `.claude/plans/2026-09-15 faces-round-2/mockup.template.html` — the JS functions `ramp()`, `spark()`, `history()`,
`ions()`, `beaufort()`, the `THERMAL`/`HALINE`/`PH` stops, the CSS `.chart*`, `.win`, `.mk`, `.hit`, `.hover`, `.tip`, and the
sections `#f-m2`, `#f-m6`, `#f-m5`, `#f-m10` (their "why" paragraphs state the rules). `mock_embed.json` beside it is the
temperature/nitrate/salinity/ph/wind/oxygen excerpt of the record you will draw from. **Agent:** `ws-opus-medium`.
**Repo:** CalCOFI.github.io (worktree `…/CalCOFI.github.io-ws-r2`, branch `ws-r2`, from `round-2` after R1 merged). **Wave 2 · ≈ 1 day.**

## Read first (nothing else)
`assets/measurements.js` (whole — you are rewriting `spark()`, `anomalyBands()`, `miniHTML()`, `ionsHTML()`, `beaufortHTML()` and
adding `RAMP_OF`, `ramp()`, the tip), `_includes/measurement_face.html`, `_includes/measurement_why.html`, `_plugins/measurements.rb`
lines 1060–1120 (`how_rows`) and the sentence/`why_alts` composers (grep `s-nerc`, `alts`), `style.css`'s `/* ── faces (WS-MF5) */`
block, `scripts/check_layout.py`'s `faces` assertions, `../explore/src/ramps.ts` lines 1–40 (copy the stops; cite the file in a
comment), R1's `_includes/info.html` signature and `.cc-src` classes (from its hand-back, in the umbrella § Measured).

## You own
`assets/measurements.js`, `_includes/measurement_face.html`, `_includes/measurement_why.html`, `_plugins/measurements.rb` —
**`how_rows()`, the sentence composer and `why_alts()` only** (R3 owns `ways_rows()` and `quality_rows()`), `style.css` block
`/* ── round 2 · face drawn to scale (WS-R2) */`, the `faces` assertions in `scripts/check_layout.py`, README.md § Faces (one paragraph).

## Do
1. **M3, the pin (first — it is two lines).** In `how_rows()`: `"link" => [Fmt.present(h["calcofi_org_url"]), Fmt.present(h["text_fragment"]) && "#:~:text=#{h['text_fragment']}"].compact.join`
   and `"page" => Fmt.present(h["source"]) || "Methods"`. Count the pages that now carry `a.mmf-pin` (expect 75 of 94 series →
   report the page count). Add "n methods ↓" (`href="#how"`) to the How column's key line when `f.how.size > 1`.
2. **M2 + M6, the What glyph per `face.kind`.** `RAMP_OF` is the Explorer's `defaultRamp()` **copied verbatim** — the regex
   rules and the stops from `../explore/src/ramps.ts` (cite the file and its commit in a comment): `/temp|theta/` thermal ·
   `/salin|salt/` haline · `/oxy/` **ice** · `/chl|fluor|phyto|algae|prochl|synech/` algae · `/sigma|dens/` dense ·
   `/nitr|phos|silic|ammon|nutri/` **tempo** · `/par\b|light|irrad|rad/` solar, tested against the key then the label; `ph` keeps
   `PH_RAMP`, wind keeps Beaufort (now cells shaded on `thermal`, the median and 95th outlined), anything unmatched the plain strip.
   Do not choose ramps yourself (Ben, Q3): R6 audits the Explorer's rules; if R6's hand-back changes a rule before you merge, copy
   the new one. `ramp(host, o)`: the gradient
   over `bounds` (declared; fall back to the observed min–max with a `title` saying so), the 5–95 window as an open frame in the
   page's ink, the axis ends, the registry marks as ticks with a short label (`label` truncated to ~12 chars) and the full label +
   `source` on hover. Composition → the ion bar from `F.composition`/`chem[]` (as `ionsHTML` builds it) **in the face row**, the
   molecules only in the What section. Organism and stands-in unchanged.
3. **M4, the spark.** 100 px; `top` = the spark band's own max |value| (ceil to 0.1); a left axis `+top / 0 / −top` in `.tick`;
   four year ticks; the trend line where `trend.per_decade` exists; ONI shading; one tooltip div `.mmf-tip` (append to body; the
   mockup's `tip`) reading `year · value units · n cruises · n values`; the line under it ends "· drawn to ±x units". Keep
   `preserveAspectRatio` default (never `none`).
4. **M10, the history.** Own scale per row by default: `top` per band as in 3, written at the left under the band label with the
   count; a radio pair "own scale per band | one shared scale" above the chart (the shared value = `anomaly.ymax`), no URL state;
   year axis; hover per bar; the legend one `.cc-legend1` line (above · below · strong El Niño · trend since 1984); the four-line
   mono legend and the "Deeper than the climatology" paragraph move into an ⓘ on the heading via R1's `info.html` (the paragraph
   text verbatim, the counts from `anomaly.deeper`). The scale chart keeps its axis; its mono caption also moves into an ⓘ.
5. **M5 + M14, the sentence.** The composer drops the `s-nerc` part (the What column carries the definition); each remaining part
   ends in `<span class="cc-src cc-src-rec" title="the release record, measured at v…">R</span>` / `cc-src-why` ("authored, cited:
   {bibkeys as labels}") — the citation links stay as they are in the `sup`. Retire `.mmf-legend` markup and the underline CSS
   (keep the `s-rec`/`s-why` classes on the spans). `why_alts()` gains the Wikipedia `f.wikipedia` extract as a `kind: wikipedia`
   alternative when it exists, and `measurement_why.html` no longer draws *Borrowed context*.
6. **D8.** Rewrite the `faces` assertions you break; add: a scale-kind page's What column has `svg.mmf-ramp linearGradient`; the
   spark has ≥ 3 `.tick`; temperature and nitrate have `a.mmf-pin[href*="calcofi.org"]`; the sentence has no `.s-nerc`; the history
   has a `±` label per row. Run on: temperature, salinity, nitrate, ph, wind_speed_ms, oxygen_umol_kg, dic, synechococcus, oxygen —
   1470 and 375, both themes. Shots: temperature and salinity only (1470 light, 375 dark).

## Gates (stop and report)
- A number you would have to type (a bound, a percentile, a mark) — it is in the record or it is not drawn.
- A ramp that is the only encoding of the window or a mark (they are always drawn in the page's ink too).
- `check_jsonld.py` changing its `ImageObject` count (26).

## Hand back (≤ 40 lines)
Branch + SHA; the `RAMP_OF` rules as copied (with the ramps.ts commit); pin count by page; the nine pages' check output; the two shots; one Measured line
(pin pages, ramp kinds drawn, spark `top` for the temperature spark band before/after).
