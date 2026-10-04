# WS-MF7 — picoplankton meet the species catalog: taxon_key on the FCM counts (D9, option a)

**Umbrella:** `.claude/plans/2026-09-11 Measurement faces — what it is, how it is taken and why it matters on every measurement page, agent-scaled.md` § F9, D9, § Verification MF7. **Agent:** `ws-opus-medium` (it changes what `taxa.json` counts: stop at the gate for Ben's yes before merge). **Repos:** workflows (`~/Github/CalCOFI/.worktrees/workflows-ws-mf7`, branch `ws-mf7`) and calcofi4db (`~/Github/CalCOFI/.worktrees/calcofi4db-ws-mf7`, branch `ws-mf7`). **Wave 1 · ≈ 0.5 day.**

## Read first
- The `taxon-reference` and `core-model` skills (the `append_dataset_taxon()` → `ensure_taxon_xref()` → … → `check_dataset_taxon()` chain; `obs_env` vs `obs_bio`; `check_taxon_ids()`).
- `ingest_cce-lter_picoplankton-bacteria.qmd` § Emit Core Tables (the four FCM types emitted as realm `env`, NULL `taxon_key`, and why); `calcofi4db/R/catalog_taxa.R` ~L270–291 (`build_taxa_catalog()` reads `obs_bio` only) and its tests (the WS-F1 fixture with `n_present`).
- NERC S25: P700A90Z → WoRMS 160572 (*Synechococcus*), P701A90Z → WoRMS 345515 (*Prochlorococcus*) (`measurement-faces-probe/nvs_probe.json`).

## You own
The picoplankton notebook's taxon declaration and Emit Core Tables lines; `R/catalog_taxa.R` and its tests; one `RELEASES.md` `# Unreleased` bullet.

## Do
1. In the notebook: `append_dataset_taxon()` for the two genera by WoRMS id; set `taxon_key` on the `synechococcus` / `prochlorococcus` `obs_env` rows (realm stays `env`; `picoeukaryotes` and `het_bacteria` stay NULL — no single taxon); `check_dataset_taxon()` green.
2. `build_taxa_catalog()`: also count `obs_env` rows with a non-NULL `taxon_key` (`n_obs`, `n_present`, `datasets[]`, years), so the two genera get species pages; a fixture test with one `obs_env` taxon row and one without; `taxa.schema.json` unchanged unless a field is needed (then additive, 1.2).
3. Render the notebook through targets (`tar_invalidate()` first; confirm by the `_output` html mtime — the pipeline-targets skill); confirm `measurements.json` for the four keys is unchanged against v2026.09.10.

## Gates (stop and report)
- **Before merge: Ben's yes on D9 (a)**, recorded in the umbrella.
- `check_taxon_ids()` or `check_obs_pair_parity()` red; any measurement page's numbers change.

## Hand back
Branches + SHAs; the two genera's `taxa.json` entries from a local build; tests run; one *Measured* line.
