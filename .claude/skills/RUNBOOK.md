# Runbook: ingest (and publish) a new CalCOFI dataset

The canonical loop for adding a dataset to the integrated database. The five
skills chain in order; each updates the shared tracking artifacts so the loop is
self-documenting. Human judgment stays in the loop at every hand-off.

## Shared artifacts (single sources of truth)

| Artifact | Role |
|---|---|
| `metadata/field_dictionary.csv` | Canonical field names/types/units/aliases. **Prescriptive** — new datasets conform; consistency is linted against it. |
| `metadata/measurement_type.csv` | Canonical measurement vocabulary (raw measured quantities). The dictionary links to it; never duplicate it. Read via `calcofi4db::read_measurement_type()`, append via `register_measurement_types()` — a bare `write_csv()` defaults to `na = "NA"` and ships literal `"NA"` to the release. |
| `metadata/dataset.csv` | **DEPRECATED** — superseded by each ingest's `calcofi.dataset_meta` YAML block, read via `ingest_yaml_to_dataset_df(read_ingest_yaml())`. The CSV drifted and orphaned obs rows. |
| `metadata/provider.csv` | Registry of curating organizations (`provider` -> display label, name, url). Any provider an ingest declares must be registered; the landing-index build errors otherwise. |
| `metadata/dataset_status.csv` | Pipeline-stage tracker — one row per dataset. Each skill writes its stage column. |
| `metadata/relationships_cross.csv` | Cross-dataset FKs (spanning ingests). Intra-dataset FKs live in each ingest's `relationships.json`. |
| `metadata/{provider}/{dataset}/questions.csv` | Follow-up questions for the data provider; rendered in the workflow by `calcofi4db::questions_datatable()`, aggregated by `questions_email.qmd`. Read it with `calcofi4db::read_questions()` — never a bare `read_csv()`. `label` (`Q15`, dataset-scoped) is what prose cites; `id` (`{provider}_{dataset}_15`) is the durable key. `status`: `open` \| `proposed` \| `answered` \| `wontfix`; `priority`: `blocker` \| `high` \| `normal` \| `low`. |

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
Register the dataset via its `calcofi:` YAML block (`dataset_meta`, `tables_owned`) — `metadata/dataset.csv` is deprecated; run the hand-off completeness check;
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

### 3b. Emit core tables (`emit_core` block) — **not optional**

This is the step that makes an ingest useful. After building its per-dataset
tables, each ingest projects them into the shared **core** family (`sample` /
`obs` / `obs_attribute` / `sample_measurement` + the taxa refs), then the
per-dataset tables become compat VIEWs. The core is what `release_database.qmd`
publishes and what every consumer reads; per-dataset tables are an intermediate.

**The projection SQL lives in the notebook, not in `calcofi4db`.** Every helper
takes an arbitrary `SELECT`, so a new dataset needs no package change. Canonical
block (before `write_parquet_outputs`):

```r
build_grid_reference(con)                       # idempotent shared grid
append_sample(con, "<this dataset's sample arm(s)>")          # namespaced sample_key
append_sample_measurement(con, "<event-effort SELECT or skip>")
append_obs(con, "<headline occurrence SELECT>")              # bio base rows -> 'abundance'
append_obs_attribute(con, "<bin/count SELECT or skip>")      # e.g. body_length / stage / behavior
# per-dataset tables become VIEWs over the core (detail survives, bytes don't):
dbExecute(con, "ALTER TABLE {ds}_measurement RENAME TO {ds}_measurement_src")
dbExecute(con, "CREATE OR REPLACE VIEW {ds}_measurement AS SELECT ... FROM obs WHERE dataset_key='...'")
```

Column contracts are **positional** — each helper wraps your SELECT in
`AS src(...)` — so emit columns in the order given by the helper's roxygen.

`sample_key` is namespaced `dataset_key:sample_type:id`. `obs` carries the
occurrence headline (bio abundance = the count, organism in `taxon_key` — never
baked into `measurement_type`), `obs_attribute` the (bin, count) or categorical
detail, `sample_measurement` event-level effort. Env CTD rows come from `ctd_thin`
(full scans → the supplemental `obs_ctd_full`).

**There is no arm to add.** `calcofi4db` once held a `switch(dataset_key, …)` per
core table — ~600 lines of dataset-specific SQL in a general-purpose module —
plus `emit_core_tables()` / `build_sample_reference()` / `create_compat_views()`
over them. All deleted in calcofi4db 3.0.0. The package keeps only generic
shapes; each dataset's projection lives in the notebook that owns it. Not for
tidiness: `release_database.qmd` kept a second copy of every arm, and the two
drifted into four silent data errors before anyone compared them. The release is
now a pure union of shards, and its `core_parity` chunk asserts shard counts, so
cut-over stays safe.

**Fetch the taxon lineage.** After `build_taxon_reference()` /
`build_dataset_taxon()`, a taxon has a key and a name and — unless a lineage
hierarchy is in the connection — nothing else. Call
`ensure_taxon_lineage(con, mt_taxon, tx_over, cache_csv = here("metadata/taxon_lineage.csv"))`
*before* the builders, or hierarchy rollups silently return nothing for your
dataset and no error is raised anywhere.

**Publish the core only.** `tbls_out = core_output_tables(con, extra =
c("measurement_type", "dataset"))` — no per-dataset source table reaches parquet.
The sources are archived already, so a copy is redundant and consumers must not have
to choose between two representations. Where a source column matters but has no core
home, give it one (the Dungeness sorting log's sorted/unsorted became zero-valued
`obs` vs no `obs`) rather than publishing the source table to carry it.

**Document what you publish.** The notebook needs an ERD of the CORE
(`core_relationships()`), not just the source shape, plus a source→core mapping
table that also names what is deliberately not published.

Assert the projection rather than eyeballing it: source-vs-`obs` row counts and
value totals, `obs.sample_key` → `sample`, `obs.taxon_key` → **`taxon`** (resolving,
not merely non-NULL), `obs.measurement_type` → `measurement_type`, and
sub-occurrence counts reconciling to the headline. Also prune any `.parquet` for a
table that has become a VIEW, or stale files linger in the output dir.

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
`pi_names` from each ingest's `calcofi.dataset_meta` YAML). It covers both
`open` questions and `proposed` ones — the latter carry a `proposed_answer` and
ask the provider to **confirm a solution** rather than handing over a problem,
which is what you should aim for before sending: pre-answer everything the repo
can already settle. Review and send; record answers back in each
`questions.csv` (`status=answered`, fill `answer`/`answered_date`).

## Conventions (see CLAUDE.md)
snake_case; `*_key`/`*_id`/`*_uuid` identifiers; unit suffixes; tidy long-format
measurements (`measurement_type`/`measurement_value`/`measurement_qual`) that
project into the **core** family (`sample`/`obs`/`obs_attribute`/`sample_measurement`,
namespaced `sample_key = dataset_key:sample_type:id`) via the `emit_core` block;
`cat()` not `message()` in chunks; individual `datatable()` calls (not
`preview_tables()` in a loop).
