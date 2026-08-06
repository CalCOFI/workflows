# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> General R/Quarto/plumber conventions live in the parent `../../CLAUDE.md`
> (2-space indent, snake_case, `|>`, roxygen2, `librarian::shelf()` outside
> packages, etc.). This file covers what is specific to the `workflows` repo.

## What this repo does

`CalCOFI/workflows` ingests source datasets (zooplankton, ichthyoplankton,
bottle, CTD, DIC, …) into a single integrated CalCOFI database and publishes the
result as Parquet on GCS and as versioned "frozen" DuckLake releases. The heavy
lifting lives in the sibling R package **`calcofi4db`** (`../calcofi4db`); the
notebooks here orchestrate it. `calcofi4r` (`../calcofi4r`) is the user-facing
read package.

Each dataset is one `ingest_{provider}_{dataset}.qmd` Quarto notebook.
`release_database.qmd` is the "caboose" that assembles, validates, freezes, and
uploads the combined release.

## Commands

The pipeline is the source of truth — prefer running notebooks through `targets`
(which renders the `.qmd` and tracks dependencies) over rendering by hand.

```r
# from the workflows/ directory
Rscript -e 'targets::tar_make()'                       # run full pipeline
Rscript -e 'targets::tar_make("ingest_calcofi_dic")'   # run one target
Rscript -e 'targets::tar_visnetwork()'                 # dependency graph
Rscript -e 'targets::tar_outdated()'                   # what would re-run
Rscript -e 'targets::tar_meta(fields = error)'         # inspect target errors
Rscript -e 'targets::tar_invalidate("ingest_swfsc_ichthyo")'  # force re-run a node
Rscript -e 'targets::tar_unblock_process()'            # clear a locked db process

# render a single notebook directly (bypasses dependency tracking)
quarto render ingest_calcofi_dic.qmd

# install/update the engine packages (sibling repos, not on CRAN)
Rscript -e 'remotes::install_github("calcofi/calcofi4db"); remotes::install_github("calcofi/calcofi4r")'

# regenerate the calcofi.io/workflows landing index after adding/removing a notebook
Rscript scripts/build_workflows_index.R
```

**Editing a `.qmd` does NOT make its target outdated — you must invalidate it.**
`build_targets_list()` builds each command as
`{ deps…; quarto::quarto_render("ingest_x.qmd"); "output/path" }`, so the filename
is a *literal inside the command* and the notebook's contents are not a tracked
dependency. `tar_outdated()` will not list a notebook you just rewrote, and
`tar_make()` reports "skipped". Always `tar_invalidate()` first, and confirm the
render actually happened (`_output/*.html` mtime, or the run log) before believing
a hash comparison — an unchanged output hash means "did not run" just as readily
as "ran and matched".

**`tar_make()` / `tar_invalidate()` take a tidyselect expression, not a string
variable.** `for (t in targets) tar_make(t)` makes tidyselect look for a *column*
named `t` and fails with ``Column `t` doesn't exist`` — for every target, so the
whole loop is a no-op that looks like a pass if you only check exit codes. Use
`tar_make(names = tidyselect::all_of(tgt))`.

**…and do not name that loop variable `t`.** `tidyselect::all_of(t)` resolves `t`
to **`base::t`**, the matrix-transpose function, and fails with ``Subscript must
be numeric or character, not a function`` — so the documented workaround breaks
in exactly the loop it is meant to fix. Same trap for `c`, `df`, `data`. Use
`tgt`. Verify the run actually happened (output mtime/size), because this error
surfaces *after* `tar_invalidate()` has already succeeded, which makes it look
like the target was reprocessed when nothing was rewritten.

There is no test suite or linter in this repo; correctness is enforced by the
`/validate-ingest` checks and the validation chunks inside `release_database.qmd`.
`release_database.qmd` promotes `latest.txt` only after `test_release.qmd`'s
consumer-contract query suite passes (it exercises the app/`calcofi4r` query
shapes against the frozen release, so a schema drift that would break a consumer
fails the release rather than the app).

## Deploy (release → consumers)

After a new release is frozen, uploaded, and promoted to `latest`, the read-only
consumers must be refreshed. They fall in two buckets:

**Shiny apps** live on the CalCOFI server (`ssh calcofi`). Source repos are cloned
to `/share/github/CalCOFI/{repo}`; `shiny-server` runs inside the **`rstudio`**
Docker container and serves them from `/srv/shiny-server/{app}`, which are symlinks
into those repos (e.g. `db-viz-hex → …/db-viz-hex/app`, `datacheck` +
`db-viz-cruise → …/apps/db-viz-cruise`). Deploy per app:

```bash
ssh calcofi                                            # documented in ../server/README.md
# 1. pull source (and calcofi4r, since prep_db.R does devtools::load_all("../calcofi4r"))
git -C /share/github/CalCOFI/calcofi4r  pull --ff-only
git -C /share/github/CalCOFI/db-viz-hex pull --ff-only
git -C /share/github/CalCOFI/apps       pull --ff-only
# 2. rebuild each app's local DuckDB from the new release — MUST run in the
#    rstudio container (it has R + the pkg deps + network to the public GCS bucket)
docker exec -d rstudio bash -lc 'cd /share/github/CalCOFI/db-viz-hex        && Rscript prep_db.R'
docker exec -d rstudio bash -lc 'cd /share/github/CalCOFI/apps/db-viz-cruise && Rscript prep_db.R TRUE'  # TRUE = force rebuild (else skips if db exists)
# 3. restart the app(s) — touch restart.txt in the served app dir
touch /share/github/CalCOFI/db-viz-hex/app/restart.txt
touch /share/github/CalCOFI/apps/db-viz-cruise/restart.txt
```

Notes: `prep_db.R` is heavy (downloads the release parquet + materializes H3 /
join tables), so background it with `docker exec -d` and tail the log. Apps that
read the release **at runtime** (e.g. `apps/cruises`) have no `prep_db.R` and need
only `git pull` + `restart.txt`. Ports 5432-forward warnings from `ssh calcofi`
are harmless.

**Static / hosted consumers** redeploy themselves on push or on release dispatch:
the **station portal** (`db-viz-station`; the archived 2026 UCSB student capstone
`2026-ucsb-station-data-portal` was forked here) rebuilds its coverage
JSON from the DB via GitHub Actions — `gh workflow run refresh.yml --ref main -R CalCOFI/db-viz-station`
(also runs weekly + on release dispatch); **`calcofi.io/query`** and
**`calcofi.io/schema`** are GitHub Pages and rebuild on push. `calcofi4r` reads
`latest` directly, so it needs no deploy — but keep `calcofi4r/R/match.R`
byte-identical with `db-query/lib/match.js` (verified in CI).

## Architecture

### Data flow

```
Google Drive ──rclone──> GCS (gs://calcofi-files/) ──targets──> ingest_*.qmd
   └─ source CSVs                                                    │
                                     write_parquet_outputs()         │
                                   + build_metadata_json()   <────────┘
                                   + sync_to_gcs()
                                                     │
   $CALCOFI_STAGE_DIR/parquet/{provider}_{dataset}/  ┘   <- bulk .parquet
       data/parquet/{provider}_{dataset}/*.json          <- sidecars, in git
       (+ gs://calcofi-db/parquet/… mirror of both)
                                                     │
                          release_database.qmd ──────┘
                          (assemble in-memory from the parquet shards,
                           validate → freeze → upload)
                                                     ▼
                              Parquet + frozen release
                              (gs://calcofi-db/ducklake/releases/{version}/)
```

::: There is **no Working DuckLake**, and no ingest calls `finalize_ingest()`.
Both appear in `README_PLAN.qmd` as design intent and were documented here as if
built; verified 2026-07-30 — `gs://calcofi-db/ducklake/working/` holds **zero
objects**, `grep -l finalize_ingest ingest_*.qmd` matches **nothing**, and
`release_database.qmd`'s `con_wdl` is `get_duckdb_con(":memory:")` (the `wdl` in
the name is vestigial). All 16 data ingests use the
`write_parquet_outputs()` + `build_metadata_json()` + `sync_to_gcs()` trio above.
Do not "migrate the laggards onto `finalize_ingest()`" — there are no laggards,
and that function expresses neither the content-hash upload dedup nor the `_new`
delta sidecars that the trio does. :::

### YAML-driven pipeline (no per-dataset `_targets.R` edits)

`_targets.R` calls `calcofi4db::build_targets_list()`, which parses the
`calcofi:` YAML front-matter block of **every** `*.qmd` in the directory to
discover targets and wire up dependencies. To add a dataset to the pipeline you
add the notebook with a `calcofi:` block (`target_name`, `dependency`, `output`,
`provider`, `dataset`, `dataset_meta`, `tables_owned`, …) — you do **not**
hand-edit the targets list. Use the `exclude =` argument in `_targets.R` to drop
a target temporarily.

### `in_release: false` — stage an ingest without releasing it

An ingest that is not ready for consumers can set `in_release: false` in its
`calcofi:` block. It still runs in the pipeline and writes its **full**
`data/parquet/{provider}_{dataset}/` outputs (tables, `manifest.json`,
`relationships.json`, `metadata.json`), but every release-side discovery step in
`release_database.qmd` skips it: the table registry, the core shard union, the
`dataset` reference table, the ERD, and the merged `relationships.json` /
`metadata.json`. Use it while blocker questions are open or before the dataset
has an `emit_core_tables()` arm.

The flag is **opt-out** — no key means "in the release", so existing notebooks
are unaffected. `calcofi4db::release_excluded_datasets()` is the single source of
truth; `build_release_table_registry()`, `core_shard_paths()`/`assemble_core()`
and `read_ingest_yaml(in_release_only = TRUE)` all consult it.

Two things do **not** follow automatically, so handle them in the notebook:
- **New measurement types.** `metadata/measurement_type.csv` is loaded wholesale
  into the release, so appending there would add types with no observations.
  Stage them in `metadata/{provider}/{dataset}/measurement_type_new.csv` and
  union in-memory (see `ingest_cdfw_dungeness-crab.qmd`).
- **GCS uploads.** `sync_to_gcs()` targets world-readable buckets. If publication
  permission is itself unsettled, gate the calls behind a local flag rather than
  relying on `in_release: false`, which only governs the release.

Current holdout: `cdfw_dungeness-crab`.

### Coverage is measured, never asserted

**Do not add `coverage_temporal` / `coverage_spatial` to a `dataset_meta`
block.** `calcofi4db::observed_coverage()` measures both from the assembled core
in `release_database.qmd`'s `dataset_coverage` chunk, writes them into the
release `dataset` table and into `metadata.json` as
`coverage_temporal_observed` / `coverage_spatial_observed` / `coverage_bbox`,
and `scripts/build_workflows_index.R` puts them on the calcofi.io/workflows
cards.

A hand-written extent is authored once while the data grows underneath it. At
`v2026.08.06` seven of fifteen were wrong: `cce-lter_zoodb` claimed data through
2021-05 that ends 2015-04, `calcofi_phyllosoma` stopped a year short of its own
rows, `calcofi_bottle` was a month late at the start, and three said `"present"`
while stalling in 2019, 2022 and 2023. `ingest_calcofi_ctd-cast.qmd` had already
been hand-corrected twice and was stale again.

**Two exceptions remain, and both carry a comment saying why.**
`calcofi_phytoplankton` is region-pooled — real coordinates, zero datetimes — so
it asserts `coverage_temporal` only and measures the spatial half like everyone
else. `cdfw_dungeness-crab` is `in_release: false`, so the release never sees it
to measure; delete both its keys when it enters the release. If you add a third,
the bar is "the data provably cannot answer", not "I know the answer".

The measurement is honest about what it finds, which means it surfaces
coordinate bugs the prose hid — `calcofi_mets` measures `125.8°W–124.9°E` (a
dropped minus sign) and `swfsc_ichthyo` reaches latitude `0.0` (null island).
Fix those at the source; do not paper over them by re-asserting a tidy bbox.

### Parquet shards → frozen release

**An ingest's output lives in two places, and the split is deliberate.** The
bulk `.parquet` stages **outside the repo** at `$CALCOFI_STAGE_DIR` (see
`calcofi4db::cc_stage_dir()`, default `~/_big/calcofi`) on its way to
`gs://calcofi-db/`; the JSON sidecars — `manifest.json`, `metadata.json`,
`relationships.json` — stay in `data/parquet/{provider}_{dataset}/` **and are
tracked in git**, because they are the reviewable schema/provenance record the
release reads.

In each notebook: `dir_parquet` is the repo sidecar dir, `dir_stage` is the
staging dir. `write_parquet_outputs(output_dir = dir_parquet)` routes bytes to
the stage by default — you do not pass `parquet_dir` unless you want them
colocated. Anything that touches an actual `.parquet` file (a `file.path(...,
"x.parquet")`, a `dir_ls(glob = "*.parquet")`, a hive-partition directory) must
use `dir_stage`; anything naming a `*.json` uses `dir_parquet`.

Previously all 24 GB sat inside the git working tree, which forced a blanket
`parquet` ignore rule in `data/.gitignore` — and that rule swept the sidecars
out of version control as collateral, so **nothing** under `data/parquet/` was
tracked. The rule is now `parquet/**/*.parquet`, a guard against a misconfigured
run rather than the primary mechanism.

- Each ingest notebook ends with **three** calls, and every one of the 16 data
  ingests does it the same way:
  1. `write_parquet_outputs()` — parquet to `$CALCOFI_STAGE_DIR/parquet/{provider}_{dataset}/`,
     `manifest.json` to the repo sidecar dir, and **content-hashes each table so
     an unchanged partition is not re-uploaded** (the manifest is the dedup
     ledger, so it is read from the sidecar dir, not from beside the bytes);
  2. `build_metadata_json()` — the `metadata.json` sidecar (and it now reports its
     own documentation gaps via `scan_metadata_gaps()`);
  3. `sync_to_gcs(local_dir = dir_stage, sidecar_dir = dir_parquet)` — mirrors
     **both** roots to one `gcs_prefix`, skipping unchanged objects. Sidecars are
     exempt from `delete_stale`: they are not under `local_dir`, so an unguarded
     `--delete-unmatched-destination-objects` would delete the release's whole
     schema record on every sync.

  An ingest that *modifies* a shared dependency table (`calcofi.modifies:`) also
  exports a `{table}_new.parquet` **delta sidecar** — the rows it adds, keyed on the
  PK — which `build_release_table_registry()` picks up and which is deliberately
  **not** in the manifest.
- `release_database.qmd` **auto-discovers** `data/parquet/*/relationships.json`
  and outputs (no manual `rels_paths` edits), merges `relationships_cross.csv`,
  assembles the core from those shards into an **in-memory** DuckDB, validates
  PK/FK/null/range, then freezes and uploads a versioned release under
  `gs://calcofi-db/ducklake/releases/{version}/`. Read-only consumers use
  `calcofi4r::cc_get_db()` against the frozen release.

### Consolidated core model (`obs` / `sample` / …)

Per `design_env-bio-consolidation.md`, the ~40 per-dataset triples collapse into a
small **core** family that every consumer reads (built by the `calcofi4db` model
engine, `R/model.R`):

**The projection into these tables lives in the ingest notebook that owns the
dataset**, in its "Emit Core Tables" section — never in `calcofi4db`. The package
holds only *generic shapes* (`append_*()`, `sample_arm_self()`,
`compat_event_sql()`, `compat_measurement_sql()`, `ns_key()`,
`ensure_measurement_taxon()`, `prune_taxon_shard()`); a notebook declares against
them. The ~600 lines of `switch(dataset_key, …)` arms that used to live in
`R/model.R` were deleted in calcofi4db 3.0.0, along with `emit_core_tables()`,
`build_sample_reference()` and `create_compat_views()`. Do not reintroduce them:
the release re-derived the core from its own inline copy of those arms, the two
copies drifted, and each divergence was a silent data error (euphausiids
flattened 37 species to one family key, bird_mammal merged every unresolved
species into one row per transect, phytoplankton emitted zero observations, cufes
and phyllosoma lost their taxa). Copy the pattern from any migrated notebook.

| core table | grain | built by |
|---|---|---|
| `sample` | one row per physical sampling event (site/tow/net/cast/bottle/underway/transect/region_pool); adjacency list via `parent_sample_key` + `root_sample_key` | `append_sample()` (+ `sample_arm_self()` for the single-level case) |
| `obs` | occurrence-headline long table (`realm` env\|bio, one scalar/row); bio taxon via `taxon_key` (global, `worms:`/`itis:`); env CTD via `ctd_thin` | `append_obs()` |
| `obs_attribute` | sub-occurrence attribution — length/stage frequency (`bin_value`/`bin_label`/`count`) **+ categorical behavior** (was `obs_freq`) | `append_obs_attribute()` |
| `sample_measurement` | event-level effort (net `volume_sampled`/`std_haul_factor`/… ; bottle cast conditions) | `append_sample_measurement()` |
| `obs_ctd_full` | **supplemental** full-resolution CTD scans (~216M rows; hosted + catalog-flagged, excluded from ERD/default list; `cc_get_db(supplemental=TRUE)`) | `append_obs(obs_tbl="obs_ctd_full")` |

Shared taxonomy refs (built by `calcofi4db/R/taxa.R`, replacing the ~7 per-dataset
taxon tables): **`taxon`** (one row per taxon, `taxon_key` = lowercase authority
prefix `worms:<id>` — or `itis:<id>` for birds/Aves — + `worms_id`/`itis_id`/
`gbif_id`/`ncbi_id`/`inat_id`, `parent_taxon_key`, lineage), **`dataset_taxon`**
(per-dataset vocabulary → `taxon_key` crosswalk; `obs` resolves `taxon_key` by
joining it on `(dataset_key, ds_taxa_code)`), **`taxon_group`** (groupings). Built
by `build_taxon_reference()` / `build_dataset_taxon()` / `build_taxon_group()`.
Coarse/composite taxa (cufes eggs, phyllosoma stages, euphausiid family, phyto
functional groups, seabirds/mammals) resolve to real WoRMS/ITIS ids via the
reviewable `metadata/measurement_taxon.csv` + `metadata/taxon_override.csv`.

**Lineage is not free — call `ensure_taxon_lineage()` before the builders.**
`build_taxon_reference()` takes `rank` / `parent_taxon_key` / classification from
a DwC-shaped hierarchy table named `taxon` in the connection. Exactly one ingest
built one (`swfsc_ichthyo`, via `build_taxon_hierarchy()`), so every other
dataset's taxa reached the release with a key and a name and **nothing else** —
0 ranks, 0 parents, no classification — and hierarchy rollups ("all Decapoda")
silently matched nothing with no error anywhere.
`ensure_taxon_lineage(con, mt_taxon, tx_over, cache_csv = here("metadata/taxon_lineage.csv"))`
fetches each taxon's WoRMS (or ITIS, for Aves) classification, caches it in
`metadata/taxon_lineage.csv` so re-runs cost no API calls, and stages it as that
same `taxon` table — plus the flattened `kingdom`/`phylum`/`class`/`order_taxon`/
`family`, which no dataset ever populated. Ancestors become `taxon` rows too, so
`parent_taxon_key` chains resolve; `prune_taxon_shard()` keeps the transitive
parent closure when trimming a shard. `ncbi_id`/`inat_id` stay declared-but-NULL:
no source supplies them, and dropping the columns would change the release schema
under consumers.

- **Namespaced keys**: every `sample_key` is `dataset_key:sample_type:id` (globally
  unique across datasets *and* event levels; makes the DIC→bottle dedup fall out).
  `obs.sample_key` FKs into `sample`; `grid_key`/`cruise_key` stay **denormalized**
  on `obs` so rollups `GROUP BY` them without a join.
- **`hex_id`** (H3, `UBIGINT`) is computed on `obs`/`obs_ctd_full` at
  `CC_H3_RES_MAX` (res 10); aggregate coarser via `h3_cell_to_parent(hex_id, res)`
  — no per-resolution columns. `geom` lives on `sample` (and refs), never on `obs`.
- **Phased migration**: Phase 2 (done) materializes the core centrally in
  `release_database.qmd` (chunks `core_tables` + `core_parity`) over the existing
  per-dataset tables, with hard parity assertions. Phase 3 cuts each ingest over to
  emit its slice via the `append_*` helpers, with the per-dataset tables surviving
  as compat VIEWs (see the `emit_core` pattern in `RUNBOOK.md`).
- **`build_grid_reference(con)`** materializes the shared `grid` deterministically
  from `calcofi4r::cc_grid` (promoted out of the ichthyo ingest; non-destructive).

### Metadata registries — single sources of truth (`metadata/`)

| File | Role |
|---|---|
| `field_dictionary.csv` | **Prescriptive** canonical field names/types/units/aliases. New datasets conform; consistency is linted against it. |
| `measurement_type.csv` | Canonical measurement vocabulary (raw measured quantities). `is_canonical` flags the headline types; `valid_min`/`valid_max` bound the value and `valid_depth_min_m`/`valid_depth_max_m` the **depth over which the type is defined** (`est_chlorophyll_a_*` is computed for 0–200 m alone, so a null below that is by construction, not missing data); `derivation` is free text saying how a *derived* type was produced (the `_cruise_corr` vs `_sta_corr` distinction is not something a consumer should have to guess). **Read it with `calcofi4db::read_measurement_type()` and append with `register_measurement_types()`, never with bare `read_csv`/`write_csv`** — see the round-trip trap below. |
| `provider.csv` | **Registry of curating organizations** — one row per `provider` slug with `provider_short` (display label), `provider_name`, `url`, `status`. Any provider an ingest declares MUST be here: `scripts/build_workflows_index.R` errors out otherwise. Replaced a hardcoded label vector in that script, which silently yielded `NA` and published a literal `.na.character` heading for unregistered orgs. |
| `dataset.csv` | **DEPRECATED** — superseded by each ingest's `calcofi.dataset_meta` YAML block via `ingest_yaml_to_dataset_df(read_ingest_yaml())`. The CSV drifted from the notebooks and orphaned `obs` rows. |
| `dataset_status.csv` | Pipeline-stage tracker, one row per dataset; each skill writes its stage column. |
| `relationships_cross.csv` | Cross-dataset FKs (intra-dataset FKs live in each ingest's `relationships.json`). |
| `measurement_taxon.csv` | Decomposes a taxon-bearing `measurement_type` name (`sardine_eggs`, `phyllosoma_stage_3`) into (taxon, canonical type, `life_stage`, `bin_value`, target grain). **Stage it with `ensure_measurement_taxon()`, never `dbWriteTable()`** — the CSV has no `taxon_key` column, so a raw write makes every `mx.taxon_key` reference a binder error, and hand-rolling `'worms:' \|\| worms_id` mis-keys ITIS-resolved taxa. Filter it to the emitting `dataset_key`. |
| `taxon_override.csv` | Manual id resolution for source taxa with no clean id (phyto functional groups, marine mammals), matched on a named source column. |
| `taxon_lineage.csv` | **Generated cache** of WoRMS/ITIS classification chains, one row per (requested taxon, ancestor-or-self). Written by `ensure_taxon_lineage()`; safe to delete (it refetches, slowly). Not hand-maintained. |
| `metadata/{provider}/{dataset}/` | Per-dataset `tbls_redefine.csv`, `flds_redefine.csv`, `questions.csv`, corrections, etc. |
| `metadata/{provider}/{dataset}/questions.csv` | **Provider-question registry** — 17 files, one per dataset. Read with `calcofi4db::read_questions()` and render with `questions_datatable()`; never a bare `read_csv()` + hand-written `factor(priority, …)` (see below). |

#### The question registry convention

Two identifiers, deliberately: **`id`** (`calcofi_ctd-cast_15`) is the durable
globally-unique key an issue or another dataset cites; **`label`** (`Q15`) is the
short display form, unique *within* the dataset, rendered first so "see Q15" in
prose resolves for a reader. (`calcofi/hydro-master` is the one registry whose
ids span two namespaces — `hydro_master_*` and `recon_*`, both cited by name in
`ctd-cast_qa-qc-protocol.qmd`, `ingest_calcofi_ctd-cast.qmd` and `libs/*.R` — so its recon
labels take an `R`: `QR01`. `label` is authored, not derived from `id`.)

`status` is **`open` | `proposed` | `answered` | `wontfix`** and `priority` is
**`blocker` | `high` | `normal` | `low`**. `proposed` is the one that matters:
it means *we have already built or reasoned an answer and want it confirmed* —
`proposed_answer` holds it, `questions_email.qmd` puts it in the draft marked
`[PROPOSED]`, and the provider approves a solution rather than being handed a
problem. Pre-answer everything the repo can settle before asking.

All 16 ingest notebooks used to read this file with their own `read_csv()` +
`arrange(factor(priority, …))` + `select(…)`, each listing different levels and
different columns — `ingest_calcofi_mets.qmd` ranked by a vector containing
`"blocker"` and `"asked"`, neither of which is a status, so anything outside its
list sorted silently to the bottom. Four spellings of "done" (`open`/`answered`/
`resolved`/`wontfix`) and two of "normal" accumulated across 136 questions.
`read_questions()` now holds the vocabulary and **errors** on anything outside
it; `questions_datatable()` is the one render.

### The ingest skills loop (`.claude/skills/`, see `RUNBOOK.md`)

```
/explore-dataset {path|url}  →  /generate-metadata {provider} {dataset}
   →  /ingest-new {provider} {dataset}  →  run the notebook
   →  /validate-ingest {provider} {dataset}  →  re-render release_database.qmd
```

Each skill updates the shared tracking artifacts above so the loop is
self-documenting; human review happens at every hand-off. Scaffolds come from
`.claude/skills/templates/`.

## Repo-specific conventions

- **`provider` = the organization curating the data.** Not the portal that hosts
  it, and not a collection or lab *within* the organization. CalCOFI program data
  is `calcofi` even when served from NCEI/EDI/ERDDAP; the portal goes in
  `link_data_source`. **Every provider must be registered in
  `metadata/provider.csv`** — it carries the display label and full org name, and
  `scripts/build_workflows_index.R` errors on an unregistered one rather than
  publishing a broken heading.
  - Two failure modes to avoid, both of which happened: an *agency abbreviation
    that isn't the agency* (`dfw` → `cdfw`, California Department of Fish and
    Wildlife), and *the collection standing in for the org* (`pic` → provider
    `sio` with dataset `pic-zooplankton`, since the Pelagic Invertebrate
    Collection is the dataset, SIO is the org). Likewise a redundant prefix:
    `ucsd_sio` → `sio`.
  - Where one org commissions and another performs the work, the provider is the
    one that holds and can license the data — `cdfw_dungeness-crab` was sorted at
    SIO but is CDFW's.
- **Key-suffix convention (per `../docs/db.qmd`)**: `*_id` = **integer** key
  (surrogate/counter); `*_key` = **string** natural key; `*_seq` =
  auto-incrementing integer sequence. A character-valued identifier must use
  `_key`, never `_id` — e.g. `cruise_key`, `site_key`, `grid_key`, and
  `dataset_key` (= `provider_dataset`, the observation provenance stamp).
- **Identifiers**: `*_uuid` for source tables that mint UUIDs at sea (site, tow,
  net), `cruise_key` natural key `YYYY-MM-NODC`, `site_key`; source integer
  counters where stable (bottle `cast_id`/`bottle_id`); sequential `*_id` only
  for derived/pivoted tables without a source key. UUID-first where available.
- **Tidy long-format measurements**: `measurement_type` / `measurement_value` /
  `measurement_qual`. Historically each dataset built a triple (`{dataset}_sample`
  position/time/FK + `{dataset}_measurement` long values + `{dataset}_summary`
  replicate aggregate). These now **project into the core family** (`sample` /
  `obs` / `obs_attribute` / `sample_measurement`, see above): headline occurrences →
  `obs`, event-level effort → `sample_measurement`, sub-occurrence (bin/count +
  behavior) detail → `obs_attribute`. Per-dataset triple tables survive as compat VIEWs over the core.
- **Records lacking a cast/cruise FK**: use the `calcofi4db` helpers
  `match_by_site_datetime()` then `match_nearest_by_depth()` — do not hand-write
  the matching SQL.
- **Never `write_csv()` a shared registry without `na = ""`.** `readr`'s default is
  `na = "NA"`, so an empty cell round-trips to the two-character string `"NA"`.
  This is invisible from R — `read_csv()` reads `"NA"` straight back to `NA` — but
  DuckDB's `read_csv_auto` has a default `nullstr` of the empty string only, so the
  literal value reaches the release. It did: 161 rows of `_qual_column`, 192 of
  `_prec_column`, plus `units`, `is_canonical` and `grain` shipped as `"NA"`. Nine
  ingest notebooks had the bug; one didn't. Use
  `calcofi4db::read_measurement_type()` (strict read + validation) and
  `register_measurement_types()` (append-only, always `na = ""`); the generic guard
  is `check_registry_na_strings()`. A validator placed *after* a default `read_csv`
  can never catch this, which is why the strict read is part of the helper.
- **All released geometry is tagged `EPSG:4326`**, normalized in
  `release_database.qmd` immediately before the freeze — not left to whatever each
  ingest happened to mint. `ST_Point(lon, lat)` tags `OGC:CRS84` while `ST_Read()`
  over GeoJSON tags `EPSG:4326`; they label the same WGS 84 lon/lat, but **DuckDB
  refuses `ST_Intersects` across differing tags**, so a `sample`→`spatial` join
  errored outright until v2026.08.03. `ST_SetCRS` relabels without transforming.
  Two traps this walked into, both worth remembering:
  - **Normalizing in the connection is not enough.** Most tables are uploaded by a
    GCS server-side copy straight from the ingest bucket and never pass through
    `con_wdl`, so the check passed while the published `grid.parquet` stayed
    `OGC:CRS84`. Any CRS-normalized table must also be exported locally and marked
    `gcs_prefix = NA` so the uploader takes the local copy.
  - **A consumer that coerces one side to match the other will break on the next
    release.** Normalize *both* sides of a spatial join (`db-viz-hex/prep_db.R`).
- **`NaN` is not `NULL`, and it corrupts spatial queries — not just its own row.**
  A `NaN` coordinate survives `IS NOT NULL`, and `ST_Point(NaN, NaN)` returns a
  real non-NULL `GEOMETRY` that survives `geom IS NOT NULL` too. Worse, its
  presence makes `ST_Intersects` return **different counts at different thread
  counts**, dropping valid unrelated pairs: v2026.08.02 shipped 1,590 such rows and
  every spatial join over it silently under-counted by a different amount on every
  machine. `append_sample()` (calcofi4db ≥ 3.4.2) normalizes `NaN`/`Inf` to `NULL`
  before minting geometry, and `release_database.qmd` does the same at release time
  so a fix does not require re-running all 16 ingests. Test `isnan()`/`isinf()`
  explicitly; never trust `IS NOT NULL` for a coordinate.
- **DuckDB**: always open via `calcofi4db::get_duckdb_con()` (sets
  `storage_compatibility_version=latest` so CRS-tagged geometry round-trips);
  never strip the geometry column. Known bug: `UPDATE`/`CREATE INDEX` on a table
  with a CRS-tagged `GEOMETRY` column fails through ≥ v1.5.1 — drop/avoid mutating
  `geom`.
- **Notebook chunks**: use `cat()` not `message()`; one `datatable()` call per
  preview (not a loop helper); section headings suffixed with `----` in long
  chunks.
- **`mermaid-format: png` is DISABLED — leave it that way.** It is commented out
  in `_quarto.yml`, so `{mermaid}` blocks and `cc_erd()` render client-side via
  mermaid.js and **no browser is involved**. PNG bought zoomable lightbox
  diagrams and cost far more than it was worth: it routed every diagram through
  headless Chrome, which hangs *indefinitely and unpredictably*. `ingest_spatial`
  wedged **3h15m** at 0.2% CPU on a single **60 KB** diagram that had rendered in
  ~2 min on the previous run, ignored `SIGTERM`, and silently took down two
  `tar_make()` runs — which were first misdiagnosed as external kills, because
  the only symptom is a run that stops progressing. Do not re-enable it to get
  the lightbox back without asking.

  `Sys.setenv(QUARTO_CHROMIUM_HEADLESS_MODE = "new")` in `_targets.R` addresses a
  *different* Chrome failure (≥132 dropped legacy `--headless`) and does **not**
  prevent this hang. It is harmless to keep.

  **If you meet a hung render anyway** (an explore notebook that sets
  `mermaid-format: png` itself, say):
  - `pgrep -f "headless=new"` gives Quarto's Chrome, parented to its `deno`.
    **Check parentage before killing** — the user's real Chrome is a separate
    tree under PID 1. Then `kill -9`; SIGTERM is ignored. Quarto exits.
  - R chunks all run *before* the mermaid step, so parquet/GCS outputs survive;
    only the HTML is lost. Do not assume a hang means the data work was lost.
  - Every kill leaves a **stale targets lock and an orphaned `rmd.R`**. Clear
    both (`targets::tar_unblock_process()`, `pgrep -f rmd.R`) before re-running,
    or the next run contends with the orphan over the same wrangling DuckDB.
  - Presence of figures is *not* a reliable "render finished" signal, and absence
    is *not* reliably "graph too big": this hang produced no figures on a tiny
    graph. Keep `tables =` on `cc_erd()` regardless — diagramming every table in
    the connection (loaded `ship`/`cruise`/`grid` refs, wide tables) is slow and
    unreadable even without Chrome in the path.

## Layout

- `ingest_*.qmd` — one notebook per dataset (12 of them); `release_database.qmd`
  is the assembler/release step.
- `explore_*.qmd|.Rmd` — exploratory analyses, not part of the pipeline.
- `metadata/` — the registries above.
- `data/` — local working artifacts: `data/parquet/{dataset}/` ingest **sidecars**
  (`*.json`, tracked; the bulk parquet stages at `$CALCOFI_STAGE_DIR`),
  `calcofi_wrangling.duckdb`, caches. Source CSVs live on GCS/Drive, not in git.
- `scripts/` — `sync_gdrive_to_gcs.sh` (rclone), `build_workflows_index.R`,
  pipeline runners, benchmark generators.
- `_output/` — rendered Quarto HTML + Jekyll landing index, published at
  <https://calcofi.github.io/workflows/>.
- `README_PLAN.qmd` — full design doc (Primary Key Strategy, etc.).
