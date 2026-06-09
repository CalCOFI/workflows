# Plan: Harden the dataset-ingestion skills/process, then pilot on euphausiids

## Context

We have a working skills pipeline (`explore-dataset` → `generate-metadata` → `ingest-new` →
`validate-ingest` → `publish-template`) in `.claude/skills/`, proven on DIC. We are now ready to
iterate through the remaining ~11 ingests (#26–#35) and ~10 publishes (#36–#45). Before cranking,
we want two dimensions tracked as first-class and the process tightened:

- **Schema** — normalize each input table to one overall schema and keep it consistent *across*
  datasets, with relationships captured. Today the "standard column mappings" are prose buried in
  `generate-metadata.md`, applied inconsistently (ichthyo ships `line`/`station`, DIC ships
  `station_id`), and cross-dataset FKs live as hand-edited YAML in `release_database.qmd` with a
  hardcoded `rels_paths` list.
- **Questions** — every `ingest_*`/`publish_*` workflow should carry follow-up questions for the
  data provider. Today there is no mechanism at all.

**Decisions made with the user:**
1. Scope = **harden the process, then pilot euphausiids (#26) end-to-end** so rough edges feed back
   before the remaining datasets.
2. Field dictionary is **prescriptive** — pick ideal canonical names and normalize existing datasets
   to conform (accepting re-ingest + re-release of ichthyo/bottle/ctd/dic and a downstream audit).
3. Provider questions surface as a **per-dataset `questions.csv` rendered inside each workflow**, and
   aggregate into a **draft email per provider** (no schema-site page, no GitHub mirror).

Outcome: a repeatable, self-tracking ingest loop where schema consistency is enforced by a linter
against a canonical dictionary, cross-dataset relationships are reviewable, every workflow records
open questions for providers, and recurring spatial-matching (#47) is a reused function rather than
re-written SQL.

## What we're building (prioritized)

**P0 — before the euphausiids pilot**
- A1. `metadata/field_dictionary.csv` — canonical, prescriptive field registry (single source of truth).
- A2. Schema-lint check in `validate-ingest` + dictionary pre-fill in `generate-metadata`.
- B1. Per-dataset `metadata/{provider}/{dataset}/questions.csv` + a `## Questions for Data Providers`
  section in the ingest template (and an ingest-YAML `questions_file` key).
- C1. `match_by_site_datetime()` + `match_nearest_by_depth()` in `calcofi4db` (resolves #47).
- C2. `metadata/dataset_status.csv` pipeline-stage tracker.

**P1 — harden release + normalize existing datasets**
- A3. `metadata/relationships_cross.csv` (migrate the `cross_fks` YAML); auto-discover `rels_paths`;
  emit a flat `relationships_all.csv` at release.
- A4. Normalize existing datasets' `flds_redefine.csv` to the dictionary; re-ingest; re-release.
- B2. Draft-email-per-provider generator (`questions_email.qmd` or a release chunk).
- C3. `.claude/skills/RUNBOOK.md` + skill chaining writes back into `dataset_status.csv`.

**P2 — publish side (during/after the ingest loop, not blocking the pilot)**
- B3. Questions section in the three publish templates.
- C4. Extract OBIS DwC helpers from `publish_ichthyo_to_obis.qmd` into `calcofi4db`; add NERC P01/P06
  + CF-standard-name crosswalk columns to `measurement_type.csv`.

## Design details

### A1. `metadata/field_dictionary.csv` (NEW, prescriptive)
One row per canonical field. Columns:
```
fld_new,type_new,units,category,fld_description,aliases,measurement_type,is_identifier,notes
```
- `category` ∈ `identifier|spatial|temporal|taxonomic|measurement|quality|descriptive` (drives lint rules).
- `aliases` — `;`-delimited known source names, used for pre-fill and to record the rewrites
  (e.g. `site_key` aliases `station_id;sta_key;stationid`; `line_key` aliases `line`).
- `is_identifier` — TRUE for `*_key/*_id/*_uuid/*_flag/*_qual` (skips the units requirement).
- `measurement_type` — optional link into `measurement_type.csv` (don't duplicate that vocabulary).

**Authoring method:** scan every existing `metadata/*/*/flds_redefine.csv`, list the distinct
`fld_new` names, and adjudicate one canonical per concept. Known decisions to encode:
- Keep `latitude`/`longitude` (already consistent everywhere; DwC-aligned), `double`, `decimal_degrees`.
- Keep `datetime_utc` (TIMESTAMP), `depth_m` (DOUBLE, `m`).
- `site_key` (VARCHAR) = combined `"LLL.L SSS.S"` join key → **rename DIC `station_id` → `site_key`**.
- `line_key`, `station_key` (numeric CalCOFI coordinate components) → **rename ichthyo `line`/`station`**
  if they are the components; confirm during authoring whether ichthyo also needs a derived `site_key`.
- `cruise_key`, `ship_key`, `species_id`, `grid_key`, plus summary trio `avg`/`stddev`/`n_obs`.
Full rewrite set is finalized by the scan; the plan does not pre-enumerate every column.

### A2. Wire the dictionary into the skills
- `generate-metadata.md`: replace the prose mappings block (lines ~107–116) with a step that loads
  `field_dictionary.csv`, explodes `aliases`, and pre-fills `fld_new/type_new/units/fld_description`
  for matched source columns; unmatched columns are flagged "NEW canonical?" for human review (and a
  reviewed-in addition grows the dictionary).
- `validate-ingest.md`: add a `schema_lint` check (extend `--checks`). Flags, as **warnings** (errors
  only under `--strict`): (a) a `fld_new` not in the dictionary and not an obvious identifier/measurement;
  (b) `type_new` mismatch vs dictionary; (c) `units` mismatch for shared canonical fields; (d) the same
  `fld_new` used with a different type/units than another dataset (the cross-dataset consistency catch).
  Report adds a "### Schema Lint" table.
- `explore-dataset.md`: read FK-candidate names from `field_dictionary.csv` instead of the hardcoded list.

### B1. Provider questions
`metadata/{provider}/{dataset}/questions.csv` columns:
```
id,question,context,status,priority,answer,asked_date,answered_date,who,related_table,related_field
```
- `status` ∈ `open|asked|answered|wontfix`; `priority` ∈ `blocker|high|normal`.
- Add `## Questions for Data Providers` chunk to `.claude/skills/templates/ingest_template.qmd`
  (after "Load Dataset Metadata", before "Validate") that reads the CSV and renders a `datatable()`.
- Add `calcofi: { questions_file: ... }` to the ingest YAML (mirrors the existing `tables_owned`/meta keys).
- Skills: `explore-dataset` seeds initial questions from profiling gaps (unmatched FKs, ambiguous units,
  taxonomy misses); `generate-metadata` appends a question when a measurement has no `measurement_type`
  match or a field can't be mapped; `ingest-new` includes the section + YAML key; `validate-ingest`
  warns (errors under `--strict`) if any `status=blocker` question is still `open`.

### C1. Spatial/temporal matching helpers in `calcofi4db` (resolves #47)
Extract the proven inline SQL from `ingest_calcofi_dic.qmd` (lines ~314–363) into `calcofi4db/R/spatial.R`:
- `match_by_site_datetime(con, data_tbl, ref_tbl, fk_col, ref_pk, key_col="site_key", datetime_col="datetime_utc", window_days=3, return_stats=TRUE)`
- `match_nearest_by_depth(con, data_tbl, ref_tbl, fk_col, ref_pk, parent_fk, axis_col="depth_m", tolerance=1.0, return_stats=TRUE)`
Both return matched/unmatched counts (feed a "match rate" line into the validation report). Refactor
`ingest_calcofi_dic.qmd` to call them as a regression check (match rate must hold). Datasets with
coordinates but no `site_key` use the existing `add_point_geom()` + `assign_grid_key()` path. Update
`ingest-new.md` and the template `TODO-cross-dataset`/`TODO-spatial` chunks to call these.

### C2. `metadata/dataset_status.csv` (NEW)
```
provider,dataset,gh_issue,priority,stage,explore,metadata,ingest,validate,publish_obis,publish_erddap,publish_edi,blockers,updated
```
`stage` = furthest stage reached (`todo|explored|metadata|ingested|validated|published`); per-stage
columns hold `done|wip|n/a` + date. Seed from issues #25–#45 (DIC = done). Each skill writes its
column on completion (C3), making the loop self-tracking.

### A3. Cross-dataset relationship registry
- `metadata/relationships_cross.csv` columns: `table,column,ref_table,ref_column,note` — migrate the
  8 rows of `cross_fks` YAML (release_database.qmd lines 11–19) verbatim, then delete the YAML block.
- In `release_database.qmd`: replace hardcoded `rels_paths` (lines 479–484) with
  `Sys.glob(here("data/parquet/*/relationships.json"))`; read cross-FKs from the CSV; after merging,
  also write a flat `relationships_all.csv` (`from_table,from_column,to_table,to_column,scope`) into the
  frozen release dir next to `relationships.json`/`erd.mmd`. Add a check that every cross-FK
  `ref_table.ref_column` exists in the assembled schema. Drop the now-obsolete "edit rels_paths"
  instruction from `ingest-new.md`.

### A4. Normalize existing datasets (prescriptive cleanup)
For each of `swfsc/ichthyo`, `calcofi/bottle`, `calcofi/ctd-cast`, `calcofi/dic`: update its
`flds_redefine.csv` so `fld_new` conforms to the dictionary (the rewrites from A1), re-run the ingest
notebook, run `validate-ingest` with `schema_lint`, then re-run `release_database.qmd` once as a batch.
**Downstream audit:** renamed columns (e.g. `station_id→site_key`) may be referenced by `calcofi4r`,
`int-app`, the schema site, and existing publishes — grep those repos for the old names and file
follow-ups; this is flagged, not silently assumed safe.

### B2. Draft-email-per-provider
A `questions_email.qmd` (or a chunk in the release workflow) that globs `metadata/*/*/questions.csv`,
joins to `metadata/dataset.csv` `pi_names`, filters `status ∈ {open,asked}`, and writes one Markdown
draft email per provider/PI for the user to review and send. No auto-send, no GitHub issues.

## Execution order

1. **Phase 0 — artifacts:** author `field_dictionary.csv`, `dataset_status.csv`, `relationships_cross.csv`.
2. **Phase 1 — skills/templates:** dictionary pre-fill (generate-metadata), `schema_lint` + questions
   checks (validate-ingest), dictionary-driven FK candidates (explore-dataset), questions section +
   YAML key + matching-helper calls in `ingest_template.qmd`, and `ingest-new.md` updates.
3. **Phase 2 — calcofi4db helpers:** `match_by_site_datetime()` + `match_nearest_by_depth()`; refactor
   `ingest_calcofi_dic.qmd` to call them (regression-check the match rate).
4. **Phase 3 — release wiring:** auto-discover `rels_paths`, read `relationships_cross.csv`, emit
   `relationships_all.csv`, add the cross-FK target check; delete the `cross_fks` YAML block.
5. **Phase 4 — normalize existing datasets (A4):** update flds_redefine, re-ingest the four datasets,
   re-release as one batch; run the downstream-name grep.
6. **Phase 5 — pilot euphausiids (#26):** run the full hardened chain end-to-end
   (`/explore-dataset` → `/generate-metadata` → `/ingest-new` → run notebook → `/validate-ingest`),
   conforming to the dictionary from the start and seeding `questions.csv`. Capture friction and fix
   the skills before moving to #27.
7. **Phase 6 — questions email (B2) + RUNBOOK (C3).**

## Critical files
- New data artifacts (plain CSV beside `metadata/measurement_type.csv`):
  `metadata/field_dictionary.csv`, `metadata/dataset_status.csv`, `metadata/relationships_cross.csv`,
  and per-dataset `metadata/{provider}/{dataset}/questions.csv`.
- Skills: `.claude/skills/{generate-metadata,validate-ingest,explore-dataset,ingest-new}.md`.
- Templates: `.claude/skills/templates/ingest_template.qmd` (questions section, matching-helper calls).
- `calcofi4db/R/spatial.R` (new `match_by_site_datetime`, `match_nearest_by_depth`).
- `release_database.qmd` (auto-discover rels, read relationships_cross.csv, emit relationships_all.csv,
  cross-FK target check; delete cross_fks YAML).
- `ingest_calcofi_dic.qmd` (refactor to the new match helpers — regression check).
- Existing `metadata/*/*/flds_redefine.csv` for the four datasets (Phase 4 normalization).
- `metadata/measurement_type.csv` (P2: NERC/CF crosswalk columns).

## Reused calcofi4db functions (no reinvention)
`read_csv_files`, `read_csv_metadata`, `ingest_dataset`, `build_relationships_json`,
`merge_relationships_json`, `build_metadata_json`, `merge_metadata_json`, `add_point_geom`,
`assign_grid_key`, `enforce_column_types`, `validate_for_release`, `read_calcofi_meta`/`read_ingest_yaml`,
`load_prior_tables`, `cc_erd`. New: the two `match_*` helpers; (P2) `build_dwca_*`/`build_eml`.

## Verification
- **Schema lint:** after Phase 1, run `/validate-ingest calcofi dic` — `schema_lint` must report zero
  type/unit mismatches and zero out-of-dictionary fields once DIC's flds_redefine is normalized.
- **Matching helpers:** re-render `ingest_calcofi_dic.qmd`; assert the DIC→casts match rate matches the
  prior run (the ~24.7% baseline noted in memory) — proves the extraction is behavior-preserving.
- **Cross-dataset relationships:** re-render `release_database.qmd`; confirm `relationships_all.csv` and
  `relationships.json` contain the 8 cross-FKs (now from CSV) plus all per-dataset FKs auto-discovered,
  and that the cross-FK target check passes.
- **Questions:** confirm each ingest notebook renders the `## Questions for Data Providers` section from
  its `questions.csv`, and `questions_email.qmd` produces one draft per provider grouped by PI.
- **Status tracker:** confirm each skill run advances the dataset's row in `dataset_status.csv`.
- **Pilot:** euphausiids ingests cleanly through the full chain, passes `validate-ingest` (incl.
  `schema_lint`), registers in `dataset.csv`/`dataset_status.csv`, and re-render of `release_database.qmd`
  picks up `data/parquet/edi_euphausiids` automatically (no manual `rels_paths` edit).

## Risks / notes
- **Prescriptive normalization re-releases 4 datasets** and can rename columns consumed by `calcofi4r`,
  `int-app`, the schema site, and existing ERDDAP/OBIS publishes — Phase 4 includes a cross-repo grep
  for old names; expect follow-up commits outside this repo.
- Keep `measurement_type.csv` as the canonical measurement vocabulary; the field dictionary references
  it via `measurement_type`, never duplicates it.
- `schema_lint` defaults to warnings so legitimate new canonical fields aren't blocked; the dictionary
  grows as datasets are ingested. `--strict` promotes them to errors for release gating.
