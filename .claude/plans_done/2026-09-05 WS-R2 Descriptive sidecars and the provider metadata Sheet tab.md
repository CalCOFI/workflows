# WS-R2 · Descriptive sidecars (`dataset_meta.yml`) and the provider metadata Sheet tab

**Agent:** Sonnet · high. **Wave 1**, `workflows` worktree (+ one function in `calcofi4db`: the YAML merge —
coordinate with R0, who owns `ingest_yaml_to_dataset_df()`; hand R0 the diff rather than editing in
parallel). Needs Ben once for Google auth at `push --execute`. **Plan:** `.claude/plans/2026-09-05 CalCOFI.io as a dataset catalog — one record per dataset with every endpoint, the front door re-cut around Datasets, and the portal registrations.md` § D-9, Decision 14.

## Goal

The descriptive metadata lives in one file per dataset that a Sheet can round-trip, and each provider's
existing question Sheet gains a long-form `metadata` tab with the same push/pull discipline as the questions.

## Read first

- `scripts/sync_questions_sheets.R` (the whole thing: auth precedence, protected ranges, dry-run default,
  `--execute`, the pure functions and `scripts/test_sync_questions_sheets.R`); `metadata/questions_sheets.yml`.
- CLAUDE.md § "The question registry convention" and § "Attribution is a contract".
- The 16 `ingest_*.qmd` `calcofi.dataset_meta` blocks; `calcofi4db::read_ingest_yaml()` /
  `ingest_yaml_to_dataset_df()`; the sidecar field list in the plan § D-9 and the sheet-derived fields in
  D-9's last bullet (`creators[]`, `contact`, `keywords`, `keywords_gcmd`, `funding`,
  `associated_parties[]`, `quality_control_md`, `maintenance`, `methods_md`, `study_extent`,
  `sampling_description`, `abstract`, `acknowledgement`, `citation_main`, `citation_others`, `license`,
  `license_url`, `doi`, `pi_names`, `link_calcofi_org`, `link_data_source`).

## Do

0. **`metadata/dataset_meta_fields.csv`** first: `field, importance (required | recommended | optional), eml_path,
   guidance, editable`. Tiers from EDI's EML best practices + ezEML's required set (required: title, abstract,
   creators, contact, `license`, keywords, geographic + temporal coverage, methods, data entities; recommended:
   acknowledgement/funding, associated parties, quality control, maintenance, citation, DOI; optional: the rest).
   Borrow field names from `lkuiucsb/Excel-to-EML` where they fit. `visibility` (public | internal) is a field
   with a checkbox in the Sheet (Decision 25); `license` is editable (Decision 26).
1. **`scripts/migrate_dataset_meta.R`** (one-off): for each notebook, move the descriptive keys into
   `metadata/{provider}/{dataset}/dataset_meta.yml` (comments preserved as `# source:` lines), leaving the
   structural keys (`provider, dataset, dataset_name, dataset_name_short, category, tables, in_release`) in
   the notebook. `read_ingest_yaml()` merges the two; `build_workflows_index.R` errors if a descriptive key
   remains in a notebook. (Implement the merge as a small pure function + tests; give R0 the patch.)
2. **`scripts/sync_dataset_meta_sheets.R push|pull [provider] [--execute]`**: a `metadata` tab in each
   provider's existing Sheet, long form — `dataset_key · field · value · guidance · edited_by · edited_date`,
   one row per (dataset, field) **sorted by tier** (required first) with a coloured header band per tier — or
   three tabs side by side, `required · recommended · optional` — so a provider sees the ten things that matter
   before the twenty that help; `guidance` from a small `metadata/dataset_meta_fields.csv`
   (field, guidance, editable, eml_path); only `value/edited_by/edited_date` unprotected; measured fields
   (coverage, counts, `source_accessed`) pushed read-only as context rows. `pull` validates before writing:
   `license` ∈ `license.csv`, `contact` is an email or URL, `doi` bare and resolving (network behind the
   usual flag), `creators[]` parsed from `Name · Org · orcid · email` lines; writes only `value` + stamps.
3. Tests mirror `test_sync_questions_sheets.R`: pure functions, no network; a push→edit→pull round-trip on a
   fake sheet reproduces the sidecar byte-for-byte except the edited value and its stamp.
4. **The `holdings` tab** in the `calcofi` Sheet: every holding sidecar as a row (`dataset_key · name ·
   provider · category · status · priority · owner · next_step · gh_issue · observed`), with `status`,
   `priority`, `owner`, `next_step` editable and pulled back into the sidecars — the team's triage board (plan
   § D-11). Same script, one more tab kind.
5. Push the tabs for all providers (`--execute` with Ben's auth), with R1's proposals already in them if R1
   landed; verify one real round-trip (edit one value in the SWFSC tab by hand, pull, diff, revert).
5. CLAUDE.md: three sentences under § question registry (the tab, the editable set, the pull validation);
   `RELEASES.md # Unreleased`.

## Gates

Round-trip proven on a fake and on one real tab; `build_workflows_index.R` and a
`CALCOFI_SKIP_LINK_CHECK=1 Rscript -e 'calcofi4db::read_ingest_yaml()'` pass on every notebook after migration.

## Do not

Move a structural key; change any value while migrating (a byte-identical round-trip is the test); write
into the CalOOS working sheet; edit `ingest_yaml_to_dataset_df()` yourself (R0 owns it).

## Hand back

The sidecar field list as shipped, the migration diff summary (16 notebooks → 16 sidecars), the Sheet URLs
per provider, one *Measured* line.
