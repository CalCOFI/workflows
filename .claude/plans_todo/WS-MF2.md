# WS-MF2 — the why: one pick and its alternatives for every key with a face (D5)

**Umbrella:** `.claude/plans/2026-09-11 Measurement faces — what it is, how it is taken and why it matters on every measurement page, agent-scaled.md` § D5, § Verification MF2. **Spec:** the artifact https://claude.ai/code/artifact/aefb4449-c780-4da9-8216-3cbe91530e03 — *The sentence · one pick, the rest one click away* and "other ways to say why" in the head. **Agent:** `ws-opus-medium`. **Repo:** workflows (`~/Github/CalCOFI/.worktrees/workflows-ws-mf2`, branch `ws-mf2`) + the BibTeX entries in docs (`~/Github/CalCOFI/.worktrees/docs-ws-mf2`, branch `ws-mf2`). **Wave 1 · ≈ 1 day.**

## Read first
- The umbrella's D5 (Ben: "You pick one and offer the rest under an expandable details/summary class like 'not yet in the database' in the datasets catalog") and F4 (GOOS: quote the question, never a paragraph).
- `.claude/plans/2026-09-11 measurement-faces-probe/` `build.py` (`why` per cast key and the `ALTS` block — the eleven worked examples), `eov/*.txt` (the GOOS questions, drivers and phenomena per EOV), `wp.json`.
- The `measurement_why.csv` header in Appendix A (MF1 creates the empty file; if it has not landed, create the same header).
- `../docs/refs/*.bib` (the key style), the `docs-compendium` skill (citations are BibTeX keys, never pasted text).

## You own
`metadata/measurement_why.csv` (the rows); new entries in `../docs/refs/*.bib` (only additions).

## Do
1. For every key with a face (the 52 with a concept + the 20 stand-ins, whose why is their `face_of`'s unless the stand-in has its own reason, as the ISUS estimate does): **rank 1**, one or two sentences, authored, about the health of the ocean or the California Current, with at least one citation you have **read the abstract of** and whose DOI resolves (`curl -sI https://doi.org/…` → 30x). Cover the concept, not the key: the seven oxygen keys share one pick.
2. Ranks 2…: a second authored line (cited, or labelled uncited by leaving `bibkeys` empty), the GOOS question(s) from the sheet (`kind = goos`, verbatim, with `goos_doc`), the Wikipedia article title for the fetcher to lead from (`kind = wikipedia`, `text` = the title, `source_url` the article), calcofi.org's own words where a methods page states why (`kind = calcofi`, one sentence, quoted, linked).
3. Write in the house voice (the mockup's picks are the model): plain words, no hedging stacks, no number the record does not hold, no "important" or "crucial".
4. Add each new BibTeX entry once, from the publisher's record (authors, year, title, journal, volume, pages, doi).

## Gates (stop and report)
- A claim you cannot tie to a citation you read: make it an uncited alternative, never the pick.
- A GOOS sheet whose question would need more than one sentence to make sense: link the sheet instead.

## Hand back
Branches + SHAs; the rank-1 text for the eleven cast keys side by side with the mockup's; the list of DOIs checked; one *Measured* line.
