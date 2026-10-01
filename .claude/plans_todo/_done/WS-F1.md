# WS-F1 — `n_present` beside `n_obs` in the taxa record (D9)

**Umbrella:** `.claude/plans/2026-09-11 Species faces — a silhouette, a licensed photo, a size on a familiar scale and a sourced sentence for every species page, agent-scaled.md` § Context (zero counts), § F8, § D9. **Agent:** `ws-opus-medium`. **Repos:** CalCOFI/calcofi4db in a worktree `~/Github/CalCOFI/.worktrees/calcofi4db-ws-f1`, branch `ws-f1`; the `RELEASES.md` line in your workflows worktree, branch `ws-f1`. **Wave 1 · ≈ 0.5 day.**

## Read first
- The umbrella's § Context (the measured zero shares: CUFES 75.5 %, phytoplankton 85.0 %, phyllosoma 82.9 %, crab 67.5 %, zoodb 42.5 %; ichthyo, euphausiids, birds/mammals, mesopelagic 0 %) and § D9.
- `calcofi4db/R/catalog_taxa.R` — `build_taxa_catalog()` (the taxon × dataset aggregation over `obs_bio`, shared with `build_coverage()`), `write_taxa_catalog()`, `validate_taxa_catalog()`, `check_taxa_catalog()`; `inst/schema/taxa.schema.json`; `tests/testthat/test-catalog_taxa.R` and its fixture; `NEWS.md` head; the `core-model` skill (what `value` means on `obs_bio`).
- `CalCOFI/CalCOFI.github.io/_plugins/species.rb` — read only, to see which fields the page consumes (`direct`, `rollup`, `datasets[]` `n_obs`).

## You own
`calcofi4db/R/catalog_taxa.R`, `inst/schema/taxa.schema.json`, `tests/testthat/test-catalog_taxa.R` (+ its fixture), `NEWS.md` (an entry under a new unreleased heading; do NOT bump `DESCRIPTION`); `workflows/RELEASES.md` under `# Unreleased` (your own `##` heading).

## Do
1. In the taxon × dataset aggregation add `n_present = sum(value > 0)` (a NULL or NaN value is not present) beside `n_obs`, and carry it through `datasets[]`, `direct` and `rollup` (descendants included, the same way `rollup.n_obs` is built). Keep the query shared with `build_coverage()` shared; do not fork it.
2. `taxa.schema.json`: `n_present` as an integer, required wherever `n_obs` is required; `schema_version` "1.1"; additive — nothing renamed, nothing removed.
3. The fixture gains a dataset whose rows include `value = 0` (three rows, one zero, is enough). Tests: `n_present < n_obs` for that dataset and `n_present == n_obs` for a positive-only one; `direct.n_present` and `rollup.n_present` computed as specified; `rollup.n_present` of a genus equals the sum over its species plus its own direct; `validate_taxa_catalog()` passes on the fixture output; the existing tests stay green.
4. `NEWS.md`: one bullet — "`build_taxa_catalog()`: `n_present` (rows with `value > 0`) beside `n_obs` in `datasets[]`, `direct` and `rollup`; `taxa.schema.json` 1.1" — under an unreleased heading; the integrator assigns the version.
5. `RELEASES.md` `# Unreleased`: "`taxa.json` 1.1 adds `n_present` beside `n_obs`; `n_obs` counts rows, and CUFES, phytoplankton, phyllosoma, crab and zoodb rows include zero counts, so the species pages will say *observations* for `n_present` and *records* for `n_obs`."
6. Measure on the cached release (`calcofi4r::cc_get_db()`): the zero share per dataset (the umbrella's query) and, for `worms:217452`, `n_obs` vs `n_present` per dataset; paste both into the hand-back.

## Gates (stop and report)
- `devtools::test()` red after your change.
- `validate_taxa_catalog()` rejects the fixture output.
- The aggregation needs a second pass over `obs_bio` (it should be one added expression in the existing `summarise`).

## Hand back
Branch + commits in both repos; the `devtools::test()` output; the schema diff; the measured zero shares and the sardine's per-dataset `n_obs` / `n_present`; the NEWS and RELEASES text; one *Measured* line for the umbrella.
