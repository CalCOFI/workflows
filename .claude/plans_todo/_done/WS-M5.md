# WS-M5 — the documentation (D10)

**Umbrella:** `.claude/plans/2026-09-10 Measurements catalog — the environment's Species: one page per measurement, the catalog's three indexes on the front door, agent-scaled.md` § D1, D3, D10. **Agent:** `ws-sonnet-high`. **Repos:** CalCOFI/docs (worktree `../.worktrees/docs-ws-m5`, branch `ws-m5`) and CalCOFI/workflows (`~/Github/CalCOFI/.worktrees/workflows-ws-m5`, branch `ws-m5`, the two skills only). **Wave 2 · ≈ ½ day.** Needs WS-M1 (the words, `variable.csv`) and WS-M2 (the record) merged or on their branches.

## Read first
- `CLAUDE.md` § The documentation is the compendium; the `docs-compendium` skill (which chapter governs which area; prose authored, facts generated through `libs/pre-render.R`; figure/table labels; the docx/pdf render check — the gt/Word trap in memory `feedback_docs_book_gt_word_export`); `docs/db.qmd` § Taxonomy (the shape to mirror), § Metadata registries, § Quality flags; `docs/metadata.qmd`; `docs/explore.qmd`; `docs/glossary.qmd` (the *species* entry); `.claude/skills/core-model/SKILL.md`, `metadata-registries/SKILL.md`; the landing README § The species catalog (for the cross-link wording).

## You own
`docs/db.qmd` (§ Measurements, new, after § Taxonomy), `docs/metadata.qmd` (the `variable.csv` row), `docs/explore.qmd` (one sentence), `docs/glossary.qmd` (three entries), `docs/libs/pre-render.R` (snapshot `measurements.json` `counts` and `variable.csv`), the two skills' sections in workflows.

## Do
1. **`db.qmd` § Measurements**: the key rule (one page per `variable ∥ measurement_type`), the crosswalk rule (D3's four criteria, stated as enforced by `check_variable_registry()` and the record's arithmetic gate), what the record is and where (`build_measurements_catalog()`, `measurements.json`, `calcofi.io/measurements/`), the counts from the snapshot (measurements · series · datasets — never typed), one table (`tbl-` labelled and referenced) of the unified keys with their series, and the two facts the catalog surfaces (a series without a NERC concept says so; a bound is declared or questioned, never inferred).
2. `metadata.qmd`: `variable.csv` in the registry list with its helpers.
3. `explore.qmd`: "the measurements catalog is the index; the Explorer is the map", beside the species sentence.
4. `glossary.qmd`: *measurement*, *series*, *value* (D1), cross-linked to *species* and *taxon*.
5. The skills: `core-model` notes the record beside `taxa.json`; `metadata-registries` lists `variable.csv` with the never-bare-`write_csv()` rule and the crosswalk rule in one line each (rules here, the story in the plan).
6. Render the touched chapters; run `check_links.R`; build docx + pdf of `db.qmd` (the gt/Word trap).

## Gates (stop and report)
- A number that would have to be typed because the snapshot lacks it (add it to `pre-render.R` instead; if that needs the record and none exists yet, say so); a render error in docx/pdf.

## Hand back
The rendered chapter list with timings; `check_links.R` result; the docx/pdf result; the glossary entries; branches + commits; one *Measured* line.
