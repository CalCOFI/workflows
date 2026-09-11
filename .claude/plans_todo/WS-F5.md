# WS-F5 — the documentation: the docs chapter and the skill pointer (D10)

**Umbrella:** `.claude/plans/2026-09-11 Species faces — a silhouette, a licensed photo, a size on a familiar scale and a sourced sentence for every species page, agent-scaled.md` § D1–D10 (what to describe), § D10 (where). **Spec:** the artifact https://claude.ai/code/artifact/34135a47-7597-41af-ad58-5328bde815dd — *The page head, composed* is the figure. **Agent:** `ws-sonnet-high`. **Repos:** CalCOFI/docs in a worktree `~/Github/CalCOFI/.worktrees/docs-ws-f5`, branch `ws-f5`; the skill in your workflows worktree, branch `ws-f5`. **Wave 1 · ≈ 0.5 day.**

## Read first
- The `docs-compendium` skill in workflows (`.claude/skills/docs-compendium/`): the chapter → area table (find the chapter that describes the species catalog — the one `2026-09-09 Landing follow-ups …` § D11 sent `calcofi.io/species/` to), how figures are numbered, captioned and referenced, how numbers come from `libs/pre-render.R`'s snapshot, the docx/pdf build (`render_book.yml`) and its gt/markdown trap.
- The umbrella's § D1–D10 and the mockup; `.claude/skills/taxon-reference/SKILL.md`.
- The landing README is NOT yours (WS-F2a and WS-F3 write its *Faces* subsections).

## You own
The one docs chapter (and `refs/*.bib` if you cite Matarese et al. 1989 or Moser 1996 — add BibTeX keys, never pasted text), the figure file under the book's figure folder, `.claude/skills/taxon-reference/SKILL.md` (a short *Species faces* heading).

## Do
1. **The chapter** — one paragraph after the species-catalog description: what a species page now shows (a silhouette on every page, a licensed photo where one passes the policy, a size on a familiar scale with the egg-to-larva lengths for fishes, one sentence from Wikipedia with the record's own numbers), where each comes from (PhyloPic; Wikimedia Commons, iNaturalist and GBIF; WoRMS, FishBase and SeaLifeBase; NOAA's Ichthyoplankton Information System), the policy in one sentence (Creative Commons and public-domain files, non-commercial ones labelled, every asset credited and linked), and that the sidecar is fetched weekly by the landing repo and never typed. State no count; if a count is wanted, it comes from the snapshot (say so in the hand-back rather than adding one).
2. **The figure** — the composed head of the Pacific sardine from the mockup (light theme; export it from the artifact at 2×), numbered `{#fig-species-face}`, captioned, referenced from the paragraph; note in the caption that it is the design mockup until the page ships (the integrator swaps in the live shot).
3. **Citations** — `matarese1989` and `moser1996` BibTeX entries if the paragraph names them.
4. **The skill** — under a *Species faces* heading in `taxon-reference/SKILL.md`: two lines — the fetcher and its policy live in `CalCOFI.github.io/scripts/fetch_species_media.py` (+ `fetch_species_sizes.R`), keyed by `taxon_key`; `n_present` beside `n_obs` in `taxa.json` 1.1 is why the page says *observations* vs *records*.
5. **Render** the chapter to html and run the book's docx/pdf checks per the skill; report the render time and any warning.

## Gates (stop and report)
- A render failure in any of the three formats.
- A number you would have to type.

## Hand back
Branch + commits in both repos; the rendered chapter's path and a screenshot of the paragraph + figure; the BibTeX keys added; the skill text; one *Measured* line for the umbrella.
