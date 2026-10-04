# WS-R5 — the species page and the two indexes: badges, one-line credits, notes behind ⓘ, ways tabbed, a name for the h1, a Matches list above the tree (P1 P2 P3 I1 I2)

**Umbrella:** `.claude/plans/2026-09-15 CalCOFI.io faces round 2 — … agent-scaled.md` § D1, D2, D3, D6, D8, **D9**, § Verification R5; Q5 is answered there (yes).
**Spec:** `.claude/plans/2026-09-15 faces-round-2/mockup.template.html` sections `#f-p1` and `#f-i1`. **Agent:** `ws-sonnet-high`.
**Repo:** CalCOFI.github.io (worktree `…/CalCOFI.github.io-ws-r5`, branch `ws-r5`, from `round-2` after R1 merged). **Wave 2 · ≈ ¾ day.**

## Read first (nothing else)
`_layouts/species.html` (whole), `_includes/species_face.html` (the sentence, legend and credits part), `_includes/species_ways.html`,
`_includes/species_credit.html`, `_plugins/species.rb` — the sentence, credits and ways builders (grep `"wp"`, `"credits"`, `ways`),
`_layouts/species_index.html` lines 1–60 and `_layouts/measurements_index.html` lines 1–60 (the heads), `style.css` `.sp-sent`,
`.sp-legend`, `.sp-credit`, `.sp-note`, `.sp-searchrow`, R1's include signatures (`info.html`, `ways_tabs.html`, `result_row.html`) and `.cc-src` classes, `assets/species.js` lines 300–355 (the tree search: `IDX`, `found`, `hits`, the `?q=` memory),
`scripts/check_layout.py`'s species assertions.

## You own
`_layouts/species.html`, `_includes/species_face.html`, `_includes/species_ways.html` (retire → `ways_tabs.html`),
`_plugins/species.rb` (sentence parts, credits, ways `group`), `_layouts/species_index.html` (+ `#sp-matches`), `assets/species.js` (the search also fills the list), `_layouts/measurements_index.html`,
`style.css` block `/* ── round 2 · species + indexes (WS-R5) */`, the species assertions you change in `scripts/check_layout.py`,
README.md § the species catalog (one paragraph).

## Do
1. **P1, the sentence.** Each part (`s.wp`, `s.rec`, `s.au`) keeps its span and class and ends in a badge: `cc-src-wp` (title =
   the article, licence, revision + date, and "Wikipedia has only the genus" where `wp_about_genus`), `cc-src-rec` (title = "the
   release record, measured at v…"), `cc-src-nerc`-style for the authority (title = the authority + id). Remove `.sp-legend` and
   the underline CSS.
2. **P1, the credits.** One `.sp-credit` line per picture, in this order and format: `Photo · {by} · {licence, linked} · {via}`
   and `Silhouette · {by} · {licence} · PhyloPic, drawn from <i>{shown}</i>` (the stand-in caption folds into the credit); the long
   form the sidecar carries (the "(c) … some rights reserved … uploaded by …" string) becomes the credit's `title`. The NC chip
   stays. The text credit (Wikipedia) is the badge's title, not a line.
3. **P2.** The `.sp-note` captions under *Observed in*'s strip and under the ladder become an ⓘ on their headings (text verbatim);
   the *Note from the crosswalk* section is removed and its text joins the ids line's ⓘ (one ⓘ after the `key` id, body = the
   crosswalk note; absent when `t.notes` is empty). The "no length on record" line stays.
4. **P3.** `species.rb` sets `group` per way (the rule in R1's include header); the layout includes `ways_tabs.html`; *This page
   as data* becomes the `json` way; the taxa.json paragraph moves into an ⓘ on the heading.
5. **I1, both index heads.** The h1 becomes the name (Q5 default: measurements "Everything measured in the water and the air above
   it"; species "Every organism CalCOFI has counted"); the eyebrow keeps `{release} · {qualifier}`; the lede stays (one paragraph)
   with an ⓘ at its end holding the definitions paragraph and the machine-readable line, verbatim; the stat band is unchanged and
   remains the only place the numbers appear (the existing "five counts equal the record" assertion must stay green).
6. **I2, the Matches list (umbrella D9).** Under `.sp-searchrow` add `<div id="sp-matches" hidden>`; in `species.js`, where the
   search computes `hits` (sorted by observations, the first 250), also render the first 50 as `.cc-result` rows (R1's
   `result_row.html` markup built in JS: name in italics for Species/Genus, common name, rank · obs · datasets, `href` the page) with a
   heading "n matches · the tree below is folded to them" and hide the list when the query is empty. The tree keeps its fold and
   `.sp-hit` highlight. `?q=` behaviour unchanged (the list renders on load from it).
7. **D8.** Update the species assertions you break; add: no `.sp-legend`; one `.sp-credit` per picture; the h1 of each index
   contains no digit; the ways tabset present; `/species/?q=sardin` shows `#sp-matches` with ≥ 2 `.cc-result` rows, the first a
   *Sardinops* by observations. Run `/species/`, `/species/worms-217452/`, `/species/worms-203974/` (a genus page:
   "Wikipedia has only the genus" wording), `/measurements/` at 1470/375 both themes. Shots: `/species/worms-217452/` and
   `/measurements/` (1470 light).

## Gates (stop and report)
- A credit field the sidecar does not carry (leave the part out; never write a licence).

## Hand back (≤ 40 lines)
Branch + SHA; the sentence and credit lines for worms-217452 as rendered (text); check output; the two shots; one Measured line.
