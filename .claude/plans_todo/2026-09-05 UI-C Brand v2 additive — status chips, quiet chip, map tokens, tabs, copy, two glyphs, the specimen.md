# UI-C · Brand v2, additive — status chips, the quiet chip, map tokens, `.cc-tabs`, `.cc-copy`, two glyphs, the specimen

**Agent:** Opus 5 · medium. **Wave 1**, worktrees: `CalCOFI.github.io` (branch `brand-v2-additions`) and
`explore` (branch `icons-ui`). **Needs:** nothing. **Plan:** `.claude/plans/2026-09-05 CalCOFI.io UI refresh — emphasis, density and the dataset page, now that the catalog is live.md` § D-8, Appendix B, Decision 12; **the artifact is
the spec**: https://claude.ai/code/artifact/b06dcb2e-f899-4c00-831e-7383a5f4e87e (the chip row under "Emphasis is a ladder", the map swatches, the tab row on the page mock, the
copy buttons, the contrast table at the bottom — computed live from the same values).

## Goal

Brand v2 gains, additively, everything the catalog refresh needs: five chip tints and classes, a quiet chip, map
tokens and the `.cc-map` part classes, the sticky tab row as `.cc-tabs`, a `.cc-copy` icon button, and two UI
glyphs in the sprite — documented in the README, shown in the specimen, every new pair ≥ 4.5 : 1 in both themes,
and **no existing token, class or rule changed**.

## Read first

- `CalCOFI.github.io/brand/v2/README.md` (the contract; "frozen once adopted — additive changes only"), `theme.css`,
  `index.html` (the specimen computes its contrast table from `theme.css`), `icons.css`, `icons/index.html`.
- `CalCOFI.github.io/style.css` § "section nav" — the `.section-tabs` rules that become `.cc-tabs` unchanged.
- `explore/scripts/build_icons.mjs` (the sprite generator; run as `node scripts/build_icons.mjs ../CalCOFI.github.io/brand/v2`),
  and the explore commit that added `cat-genomics` (aa8aa7f) for the shape of an additive glyph.
- `CalCOFI.github.io/scripts/check_brand.py` (`--url`).
- The plan's Appendix B (the values and their measured ratios).

## Do

1. `theme.css` — append, never edit: light and dark values for `--ok-bg #eef5e9/#1e3a22`, `--warn-bg #fff6dc/#3a2d0a`,
   `--na-bg #ececec/#25344f`, `--nogo-bg #fbe9e7/#4a1f1f`, `--accent-bg #e3eef6/#12314a`; `--cc-map-water #e6eef4/#0f1a2e`,
   `--cc-map-land #f5f0e6/#21375c`, `--cc-map-coast` and `--cc-map-grid` = `--muted` in both, `--cc-map-mark` = `--accent`
   in both (write the literal values, as the file does for every token). Classes: `.cc-chip-ok/-warn/-na/-nogo/-accent`
   (sans 700, 0.7 em, tracked 0.04 em, uppercase, tinted, `border-color: transparent`; text in `--cc-green` / `--warn` /
   `--muted` / `--cc-red` / `--accent`), `.cc-chip-quiet` (no border, no fill, `--muted`), `.cc-tabs` (+ `.cc-tabs a`,
   `.cc-tabs a.on`, `.cc-tabs .n` — the `.section-tabs` values verbatim), `.cc-copy` (a `.cc-icon-button` at 1.6 rem
   with the glyph at 0.95 rem), `.cc-map` + `.water .land .st .st-on .bbox .tk` (the artifact's rules). Same
   specificity discipline as the file: single-class selectors, tokens only.
2. `explore/scripts/build_icons.mjs`: add `ui-copy` (MDI *content-copy*) and `ui-external` (MDI *open-in-new*, Apache-2.0,
   as the toggle pair already is); regenerate `brand/v2/icons.css`, `icons/calcofi-icons.svg`, `icons/index.html`
   (49 → 51); the explore build must still pass (`tsc --noEmit && vite build`).
3. `brand/v2/index.html` (the specimen): a chip row (informational vs status vs quiet), the map swatches with a
   50 × 50 sample of `.cc-map`, a `.cc-tabs` row, a `.cc-copy` button beside a code line; the contrast table gains
   the Appendix B pairs and still prints its minimum — it must be ≥ 4.5 for text pairs (land/water is not text; list
   it separately, unrated).
4. `brand/v2/README.md`: the token table rows, a "Additions, 2026-09-05" section (what, why, the plan), the class
   list in the `theme.css` row; the v1 → v2 deltas table untouched.
5. `style.css` is **not** yours except one line: `.section-tabs` keeps working; UI-A/UI-B switch the landing page to
   `.cc-tabs`. Do not touch layouts or includes.

## Gates

- `git diff --stat brand/v2/theme.css` shows additions only: **zero deleted lines** (script it: `git diff -U0 brand/v2/theme.css | grep -c '^-[^-]'` == 0).
- `scripts/check_brand.py --url http://localhost:4000/brand/v2/` passes both themes after `scripts/build.sh serve`.
- The specimen's printed contrast minimum over text pairs ≥ 4.5; the new pairs listed with their ratios.
- `icons/index.html` shows 51 glyphs; the two new masks render in both themes.
- Lighthouse accessibility 100 on the specimen, both themes.

## Do not

Change any existing token value, class or rule (that is v3); touch `style.css`, layouts, includes, `datasets.rb`
(UI-A/UI-B's); touch `brand/v1/`; add a font or a dependency.

## Hand back

Branch + sha per repo, the `git diff -U0` deletion count (0), the specimen's contrast table output, the sprite count,
one *Measured* line for the plan.
