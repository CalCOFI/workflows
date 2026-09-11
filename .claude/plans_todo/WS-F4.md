# WS-F4 — silhouettes in the species index tree and on the front door's Observed tile (D1)

**Umbrella:** `.claude/plans/2026-09-11 Species faces — a silhouette, a licensed photo, a size on a familiar scale and a sourced sentence for every species page, agent-scaled.md` § D1, § Verification F4. **Spec:** the artifact https://claude.ai/code/artifact/34135a47-7597-41af-ad58-5328bde815dd — the cast bar's pills (a 14 px silhouette before each name) are the idiom. **Agent:** `ws-sonnet-high`. **Repo:** CalCOFI/CalCOFI.github.io in a worktree `~/Github/CalCOFI/.worktrees/CalCOFI.github.io-ws-f4`, branch `ws-f4`. **Wave 1 · ≈ 0.5 day.**

## Read first
- The umbrella's § D1 and Appendix A (`silhouette.svg_inner`, `aspect`, `taxon_shown`); `.claude/plans/2026-09-11 species-faces-probe/taxa_media.sample.json` (copy to `_data/taxa_media.json` for local builds; it holds ten taxa only, so most tree rows will show nothing — that is the correct empty state).
- `_layouts/species_index.html` and `assets/species.js` (the tree: how rows are drawn from the inline JSON, folded to phylum, expanded on search), `_plugins/species.rb` (what the inline tree JSON carries per node — you add `sil` when the sidecar has one), `index.html` (the *What's observed* tile after WS-M0 — its life glyphs row and its height budget), `style.css`, `scripts/check_layout.py` (the tile height assertion).
- WS-F3 owns the page and its own sections of `assets/species.js` and `style.css`; you append your own `// ── index glyphs (WS-F4)` / `/* ── index glyphs (WS-F4) */` sections at the end and never edit above them.

## You own
`_layouts/species_index.html`, the tree node JSON in `_plugins/species.rb` (one added field), your appended sections of `assets/species.js` and `style.css`, `index.html` (the tile's glyph row only), `scripts/check_layout.py` (two assertions).

## Do
1. **The tree** — every phylum and class row (the folded levels) shows its taxon's silhouette before the name: 18 px tall, width from `aspect`, `fill: currentColor`, `aria-hidden` (the name is beside it); rows whose taxon has no silhouette show nothing and keep their height. The inline tree JSON carries `sil: { inner, vb, aspect }` only for nodes at those two ranks, so the payload grows by at most ~40 × 5 KB.
2. **The tile** — the *What's observed* tile's species row gains a strip of six silhouettes: the six classes with the most organism observations (from the counts the plugin already computes for the tree), each an `<a>` to the class's page with the class name as `aria-label`, 20 px tall, in the tile's text colour; the strip replaces nothing and must fit the tile's existing height budget (measure before and after).
3. **`check_layout.py`** — the tree's row height unchanged; the tile's height unchanged at 1470 and 375.

## Gates (stop and report)
- The tile grows taller than today's at either width.
- A class node whose `taxon_key` has no sidecar entry in the real `taxa_media.json` once WS-F2a lands (report the list; do not draw a placeholder).

## Hand back
Branch + commits; screenshots of `/species/` and `/` at 1470/375 both themes; the probe output; one *Measured* line for the umbrella.
