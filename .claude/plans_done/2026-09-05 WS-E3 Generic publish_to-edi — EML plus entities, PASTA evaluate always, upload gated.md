# WS-E3 · Generic `publish_to-edi.qmd` — EML + entities, PASTA evaluate always, upload gated

**Agent:** Sonnet · high. **Wave 3**, `workflows` worktree. **Needs:** E1 (the EML). **Plan:** `.claude/plans/2026-09-05 CalCOFI.io as a dataset catalog — one record per dataset with every endpoint, the front door re-cut around Datasets, and the portal registrations.md` § D-6 (EDI — what a scope is; Decision 24) and D-8. Scope **`edi`**, one package per integrated dataset, a CalCOFI
EDI account (Erin's, Ben as editor via the EML `access` element); evaluate against EDI's **staging** environment
(`env = "staging"`) on every run, production only under the flag. NCEI is a separate thread — never assume EDI
forwards there.

## Goal

An EDI data package per dataset per release — the release's `eml/{key}.xml` plus the dataset's core tables as
entities with an `attributeList` — evaluated by PASTA on every run and uploaded only under
`CALCOFI_PUBLISH_EDI=true`.

## Read first

- `EDIutils` (`evaluate_data_package()`, `create_data_package()`, `update_data_package()`, credentials via
  env vars); EDI's data-package best practices; `publish_to-netcdf.qmd` for the generic loop shape.
- `releases/{v}/eml/{key}.xml` (E1) and `metadata.json` `columns{}`; `calcofi4r::cc_release_sources()`
  for the objects to export.

## Do

1. `publish_to-edi.qmd` (`calcofi:` block, in `_targets.R`, files only): per dataset (`visibility: public` only),
   export the core tables
   for that `dataset_key` as CSV (`obs_bio`/`obs_env` rows for the dataset, `sample`, `sample_measurement`,
   `obs_attribute`, `dataset_taxon`), add `dataTable` entities with `attributeList` from `metadata.json` into
   the EML (E1's `build_eml()` already emits them when given the entities), run `evaluate_data_package()`,
   write the report; upload (`create`/`update` by package id in a `metadata/edi_packages.csv`) only under the
   flag; a manifest like E2's (`package_id, revision, content_hash, uploaded_utc`).
2. The plan table up front (datasets, entities, evaluate result); `registrations[]` reads the manifest.
3. `docs/portals.qmd` § EDI gains the procedure; `RELEASES.md # Unreleased`.

## Gates

PASTA *evaluate* returns no errors for `calcofi_bottle` and `swfsc_ichthyo` in the staging scope; the
notebook renders end to end with the flag off.

## Do not

Upload without the flag; choose the scope (Ben, Open question 5); duplicate metadata outside the EML.

## Hand back

The evaluate reports, the manifest, the package-id registry, one *Measured* line.
