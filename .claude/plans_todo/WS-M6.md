# WS-M6 — the Explorer reads the labels and links the page (D10, optional)

**Umbrella:** `.claude/plans/2026-09-10 Measurements catalog — the environment's Species: one page per measurement, the catalog's three indexes on the front door, agent-scaled.md` § F8, D10. **Agent:** `ws-sonnet-high`. **Repo:** CalCOFI/explore, worktree `../.worktrees/explore-ws-m6`, branch `ws-m6`. **Wave 3 · ≈ 2 h.** Needs a promoted (or staged) release whose `coverage.json` `variables[]` carries `label` (WS-M2) and the measurements catalog live (WS-M3/M4).

## Read first
- `explore/src/variables.ts` (`UNIFIED`, `setUnified()`, the comment saying the labels belong in the registry), `src/App.tsx` where `setUnified` is called from `coverage.json` (D14), `src/picker.tsx` (the variable picker's item shape), `src/help.tsx` (the welcome doors: "Browse n variables"), `src/cite.ts`/`sources.tsx` (how a dataset link is built), `scripts/smoke_release.mjs`, memory `feedback_explorer_verify_gotchas`.

## You own
`src/variables.ts`, `src/App.tsx` (the `setUnified` call site only), `src/picker.tsx` or `src/help.tsx` (one link), README (one line).

## Do
1. `setUnified()` takes labels from `coverage.json` `variables[].label` when present (fallback: `UNIFIED`'s label, then the key humanised); the picker shows the registry's label.
2. The variable picker (or the sentence's variable chip menu) gains *About this measurement ↗* → `https://calcofi.io/measurements/{key}/` for keys the catalog carries (probe `/measurements/search.json` once, cached; no link when absent).
3. The welcome door's count stays the picker's count; no change unless it disagrees with the catalog by more than the non-canonical series — report if so.
4. `npm run build`; `scripts/smoke_release.mjs` against the staged release; verify in Chrome per the gotchas memory (no HMR edits during verify).

## Gates (stop and report)
- A label from the registry that changes a URL parameter or a key (labels are display only); `smoke_release.mjs` red.

## Hand back
The diff summary; the smoke result; a screenshot of the picker with a registry label and the About link; branch + commits; one *Measured* line.
