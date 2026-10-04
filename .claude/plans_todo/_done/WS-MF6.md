# WS-MF6 — docs chapter, landing README section, skill pointer, BibTeX (D10)

**Umbrella:** `.claude/plans/2026-09-11 Measurement faces — what it is, how it is taken and why it matters on every measurement page, agent-scaled.md` § D10, § Verification MF6. **Spec:** the artifact https://claude.ai/code/artifact/aefb4449-c780-4da9-8216-3cbe91530e03 — *The page head, composed* (the figure). **Agent:** `ws-sonnet-high`. **Repos:** docs (`~/Github/CalCOFI/.worktrees/docs-ws-mf6`, branch `ws-mf6`) and workflows (`~/Github/CalCOFI/.worktrees/workflows-ws-mf6`, branch `ws-mf6`). **Wave 1 · ≈ 0.5 day.**

## Read first
- The `docs-compendium` skill (prose authored, facts generated; every figure numbered, captioned and referenced; citations as BibTeX keys; the docx/pdf builds). `../docs/db.qmd` § *A face for every species page* (the model paragraph and figure) and `refs/*.bib`.
- The umbrella's D1–D8 (what to describe) and `.claude/skills/metadata-registries/SKILL.md`.

## You own
`../docs/db.qmd` (a new subsection *A face for every measurement page* after the species one), `../docs/images/` (the figure: the mockup's light head for nitrate, until the integrator swaps in the live shot), `../docs/refs/*.bib` (entries MF1 lists that MF2 has not added — coordinate by key, add each once); `.claude/skills/metadata-registries/SKILL.md` (a short *Measurement faces* pointer: the five registries, the exact-match rule for `nerc_l22`, the "source on every row" rule, the stands-in map).

## Do
1. One paragraph: the three questions, where each part comes from (NERC → ChEBI, the method registry and calcofi.org, the record's anomaly per band and the registries), the stands-in rule, the one-pick-and-the-rest rule; no number typed (surface any count through `libs/pre-render.R`'s snapshot or leave it out).
2. The figure `{#fig-measurement-face}` with caption and a cross-reference from the paragraph.
3. Render the book: html, docx and pdf; zero new warnings.

## Gates (stop and report)
- A number you want in the prose that the snapshot does not carry.
- The docx or pdf build fails.

## Hand back
Branches + SHAs; render times and sizes; the paragraph text; one *Measured* line.
