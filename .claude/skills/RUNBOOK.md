# Runbook: ingest (and publish) a new CalCOFI dataset

The canonical loop for adding a dataset to the integrated database. The five
skills chain in order; each updates the shared tracking artifacts so the loop is
self-documenting. Human judgment stays in the loop at every hand-off.

## Shared artifacts (single sources of truth)

| Artifact | Role |
|---|---|
| `metadata/field_dictionary.csv` | Canonical field names/types/units/aliases. **Prescriptive** — new datasets conform; consistency is linted against it. |
| `metadata/measurement_type.csv` | Canonical measurement vocabulary (raw measured quantities). The dictionary links to it; never duplicate it. |
| `metadata/dataset.csv` | Registry of datasets (citations, links, PIs, coverage). |
| `metadata/dataset_status.csv` | Pipeline-stage tracker — one row per dataset. Each skill writes its stage column. |
| `metadata/relationships_cross.csv` | Cross-dataset FKs (spanning ingests). Intra-dataset FKs live in each ingest's `relationships.json`. |
| `metadata/{provider}/{dataset}/questions.csv` | Follow-up questions for the data provider; rendered in the workflow, aggregated by `questions_email.qmd`. |

## The loop

```
/explore-dataset  →  /generate-metadata  →  /ingest-new  →  run notebook  →  /validate-ingest  →  release_database.qmd
```

### 1. `/explore-dataset {path|url}`
Profile structure, coverage, FK/canonical-field candidates (matched against
`field_dictionary.csv`), provider, ingest-vs-publish recommendation. **Seeds
`questions.csv`** from profiling gaps. → set `dataset_status.csv` `explore=done`,
`stage=explored`.

### 2. `/generate-metadata {provider} {dataset} [csv]`
Scaffold `tbls_redefine.csv` + `flds_redefine.csv`, **pre-filling `fld_new`/
`type_new`/`units`/`fld_description` from `field_dictionary.csv`** (the
dictionary wins — `lat_dec`→`latitude`, etc.). Flag unmatched columns as new
canonical (add a dictionary row) or raw measurements (→ `measurement_type.csv`).
Register the dataset in `dataset.csv`; run the hand-off completeness check;
append any ambiguity questions. → `metadata=done`, `stage=metadata`.

### 3. `/ingest-new {provider} {dataset}`
Scaffold `ingest_{provider}_{dataset}.qmd` from the template. Includes the
**Questions for Data Providers** section + `calcofi.questions_file` YAML key.
For records lacking a cast/cruise FK, use the calcofi4db helpers
`match_by_site_datetime()` then `match_nearest_by_depth()` (do **not** hand-write
the SQL — issue #47). Add `_targets.R` entry. If the dataset introduces a
cross-dataset FK, add a row to `relationships_cross.csv`. No manual edit of
`release_database.qmd` `rels_paths` is needed — it auto-discovers. →
`ingest=done`, `stage=ingested`.

### 3b. Emit core tables (`emit_core` block, Phase 3)

After building its per-dataset tables, each ingest projects them into the shared
**core** family (`sample` / `obs` / `obs_freq` / `sample_measurement`) via the
`calcofi4db` model helpers, then the per-dataset tables become compat VIEWs. The
canonical block (added before `write_parquet_outputs`):

```r
build_grid_reference(con)                       # idempotent shared grid
append_sample(con, "<this dataset's sample arm(s)>")          # namespaced sample_key
append_sample_measurement(con, "<event-effort SELECT or skip>")
append_obs(con, "<headline occurrence SELECT>")              # bio base rows -> 'abundance'
append_obs_freq(con, "<bin/count SELECT or skip>")           # e.g. body_length / stage
# per-dataset tables become VIEWs over the core (detail survives, bytes don't):
dbExecute(con, "CREATE OR REPLACE VIEW {ds}_measurement AS SELECT ... FROM obs WHERE dataset_key='...'")
```

`sample_key` is namespaced `dataset_key:sample_type:id`. `obs` carries the
occurrence headline (bio abundance = the count), `obs_freq` the (bin, count)
detail, `sample_measurement` event-level effort. Env CTD rows come from `ctd_thin`
(full scans → the supplemental `obs_ctd_full`). Until an ingest is migrated,
`release_database.qmd` (`core_tables` chunk) materializes its slice centrally and
`core_parity` asserts the counts match — so cut-over is per-ingest and safe.

### 4. Run the notebook, then `/validate-ingest {provider} {dataset} [--strict]`
PK/FK/null/range/duplicate checks, `summary` consistency, **`schema_lint`** (vs
the dictionary), **`questions`** (no open `blocker`), and metadata.json
completeness. Resolve errors; under `--strict` an open blocker question or a
lint error gates the release. → `validate=done`, `stage=validated`.

### 5. `release_database.qmd`
Auto-discovers `data/parquet/*/relationships.json` + outputs, merges
`relationships_cross.csv`, emits `relationships.json`, `relationships_all.csv`,
and `erd.mmd`, and checks every cross-FK target exists. Re-render to fold in the
new dataset. `latest.txt` is promoted only after `test_release.qmd`'s
consumer-contract query suite passes (so a schema drift that would break the apps
/ `calcofi4r` / `db-query` fails the release, not the consumer).

### 6. Deploy to consumers (after `latest` promoted)
Refresh the read-only consumers (full runbook in `CLAUDE.md` §Deploy):
- **Shiny apps** (`ssh calcofi`): `git -C /share/github/CalCOFI/{calcofi4r,db-viz-hex,apps} pull --ff-only`,
  rebuild each app's DuckDB in the `rstudio` container
  (`docker exec -d rstudio bash -lc 'cd …/db-viz-hex && Rscript prep_db.R'`;
  db-viz-cruise takes `prep_db.R TRUE` to force), then `touch <app>/restart.txt`.
  `prep_db.R` repoints `calcofi_latest.duckdb` at the new version itself.
- **Station portal**: `gh workflow run refresh.yml --ref main` (also release-dispatch + weekly).
- `calcofi.io/query`+`/schema` (GitHub Pages) and `calcofi4r` (reads `latest`) need no manual deploy.

### Publish (optional)
`/publish-template {dataset} {portal}` (obis | erddap | edi). Carries its own
questions section. → set the matching `publish_*` column in `dataset_status.csv`.

## Provider outreach
Render `questions_email.qmd` to produce one draft email per provider (grouped by
`pi_names`) covering all open questions. Review and send; record answers back in
each `questions.csv` (`status=answered`, fill `answer`/`answered_date`).

## Conventions (see CLAUDE.md)
snake_case; `*_key`/`*_id`/`*_uuid` identifiers; unit suffixes; tidy long-format
measurements (`measurement_type`/`measurement_value`/`measurement_qual`) that
project into the **core** family (`sample`/`obs`/`obs_freq`/`sample_measurement`,
namespaced `sample_key = dataset_key:sample_type:id`) via the `emit_core` block;
`cat()` not `message()` in chunks; individual `datatable()` calls (not
`preview_tables()` in a loop).
