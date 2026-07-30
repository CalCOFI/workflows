# Move core-projection SQL out of `calcofi4db` into the ingest notebooks, then fix taxon matching

Handoff from the 2026-07-30 session. Everything under **Remaining** is unfinished;
the context section records what shipped so a fresh session does not redo it.

**The command to kick off with:**

> Continue the plan in `libs/plans/2026-07-30 Move core-projection SQL from
> calcofi4db into ingest notebooks + fix taxon matching.md`. Start with Task A
> (finish the migration), then B (delete the arms), then C (taxon lineage).

---

## Why

`calcofi4db/R/model.R` carried **~604 lines of dataset-specific SQL across 6
functions in 2 files** — a `switch(dataset_key, …)` per core table. Reading two
migrated notebooks made that switch look mandatory, so a new ingest
(`cdfw_dungeness-crab`) was written without emitting the core at all. The user's
verdict: *"The dataset-specific SQL in model.R is odeous to me"* — migrate all of
it into the notebook that owns each dataset, big-bang, re-rendering everything
including the 62 GB `ctd-cast`.

**The projection SQL was never required to live in the package.** Every `append_*`
helper takes an arbitrary `SELECT`. `emit_core_tables()` is only a convenience
wrapper. `RUNBOOK.md` §3b documented the per-notebook pattern all along.

---

## Context — what shipped 2026-07-30 (do not redo)

### The unlock: generic shape builders are now exported

The arms were mostly *declarative calls to private helpers*, which is **why**
projections had to live in the package — you cannot declare a projection from a
notebook if the vocabulary for declaring one is private. Now exported:

| function | version | what it gives a notebook |
|---|---|---|
| `sample_arm_self()` | 2.20.0 | the one-event-table `sample` shape (9 of 18 arms were a single call to it) |
| `compat_measurement_sql()` | 2.20.0 | the compat VIEW over `obs` |
| `ns_key()` | 2.20.0 | namespaced `dataset_key:sample_type:id` |
| `ensure_measurement_taxon()` | 2.21.0 | stages `_measurement_taxon` **with the derived `taxon_key`** |

A migrated notebook now reads:

```r
ds_key <- "cce-lter_zooscan"
mt_taxon <- read_csv(here("metadata/measurement_taxon.csv"),
                     col_types = cols(worms_id = "i", itis_id = "i",
                                      bin_value = "d", .default = "c")) |>
  filter(dataset_key == ds_key)          # MUST filter — see gotchas
n_taxon    <- build_taxon_reference(con, mt_taxon, tx_over)
n_ds_taxon <- build_dataset_taxon(con,   mt_taxon, tx_over)
append_sample(con, sample_arm_self(ds_key, "zooscan_sample", "sample_id", "tow",
  dt_col = "station_date", site_expr = "site_key",
  depth_min = "min_depth_m", depth_max = "max_depth_m"))
append_obs(con, glue("SELECT 'bio', '{ds_key}', … "))
```

### Migrated + verified byte-identical (6 of 15)

Verification method: `write_parquet_outputs()` content-hashes each table, so an
unchanged projection reports **"Reused — unchanged"** and does not rewrite the
parquet. That is proof, not inspection.

| dataset | sample | obs | other | verdict |
|---|---|---|---|---|
| `cce-lter_zoodb` | 506 | 18,276 | taxon 33 | Reused (taxon baseline clobbered, see gotchas) |
| `cce-lter_zooscan` | 1,483 | 126,692 | taxon 23 | **all Reused** |
| `ucsd_sio_mesopelagic-fish` | 102 | 1,393 | taxon 90 | **all Reused** |
| `cce-lter_euphausiids` | 7,482 | 100,477 | taxon 38 | **all Reused** |
| `cce-lter_picoplankton-bacteria` | 16,017 | 60,802 | — (env, no taxa) | **all Reused** |
| `cdfw_dungeness-crab` | 2,321 | 1,456 | new ingest | n/a (new) |

`swfsc_cufes` is **edited but not yet verified** — it failed on the missing
`taxon_key`, which 2.21.0 fixes; re-run it first.

`calcofi_ctd-cast` was **rendering when the session ended** (chunk 108/129, in
`emit_core`). Its 59 GB source read completed and it **created the previously
missing 1.47 GB checkpoint DB**, so subsequent runs are cheap. Check
`data/parquet/calcofi_ctd-cast/manifest.json` and the log at
`…/scratchpad/ctd_render.log` before assuming anything.

### Baseline hashes — use these

`…/scratchpad/baseline/data_hash_baseline.json` holds **95 table hashes across 16
datasets**, captured *before* migration. If that scratchpad is gone, re-capture
from the last release before migrating anything further.

### Other work that shipped (unrelated to the migration but in the same commits)

- **`measurement_type.csv` NA-string corruption fixed** (calcofi4db 2.19.0). Nine
  ingests wrote it without `na = ""`, so empty cells round-tripped to the literal
  string `"NA"` — invisible to `read_csv()` but **not** to DuckDB
  `read_csv_auto`, which shipped `"NA"` into the release for 161 `_qual_column`
  rows, 192 `_prec_column`, plus `units`/`is_canonical`/`grain`. Now:
  `read_measurement_type()` (strict read + validation), `register_measurement_types()`
  (append-only, `na = ""`), `check_registry_na_strings()`.
- **`in_release: false`** (2.18.0) — run an ingest without it entering the release.
  `release_excluded_datasets()` is the single source of truth.
- **`metadata/provider.csv`** — provider registry replacing a hardcoded label
  vector that yielded `NA` and published a literal `.na.character` heading.
  `scripts/build_workflows_index.R` now **errors** on an unregistered provider.
- **`dfw` → `cdfw`** rename (files, metadata dir, dataset_key, GDrive folder).
- **Skills rewritten**: `ingest-new.md` (emit-core is mandatory step 10, with the
  positional column contracts, the integer-id trap, required assertions, publish
  core-only, prune retired parquet), `RUNBOOK.md` §3b ("not optional"),
  `validate-ingest.md` (nullable-case reconciliation).

---

## Remaining

### Task A — finish the migration (9 datasets)

Re-verify each against the baseline hashes. Order is cheapest-first; the last
three are the genuinely bespoke ones.

1. **`swfsc_cufes`** — edited, unverified. Just re-run (2.21.0 fixes it).
2. **`calcofi_phyllosoma`** — simple `sample_arm_self`, plus an
   `obs_attribute` arm (stage-frequency bins, `target='attribute'`).
3. **`calcofi_bird_mammal_census`** — `obs` **aggregates** (`SUM(o.count)` with a
   `GROUP BY`, collapsing behaviours), plus an `obs_attribute` behaviour arm.
   Coordinate with Task D (rename to `farallon_bird-mammal`).
4. **`pic_zooplankton`** — `sample` only, no measurements. Simplest.
5. **`calcofi_phytoplankton`** — region-pooled grain, no `grid_key`/`datetime`;
   publishes an extra `region` table.
6. **`calcofi_dic`** — depends on `casts`/`bottle` from `calcofi_bottle` via
   `load_prior_tables()`. This is **fine and by design** — that is what the
   `dependency:` frontmatter and the DAG are for.
7. **`swfsc_ichthyo`** — 3 chained `sample` arms (site → tow → net), an
   `obs_attribute` arm (`body_length`), and a `sample_measurement` arm. Also
   publishes shared refs `grid`/`cruise`/`ship`/`lookup` — see Task E.
8. **`calcofi_bottle`** — `cast` (root) + `bottle` (leaf) pair, plus a
   `sample_measurement` arm (`cast_condition`).
9. **`calcofi_mets`** — thinned-table pattern (`mets_thin`), and it publishes
   `mets_measurement` — see Task E.

### Task B — delete the arms and retire the wrapper

Only after Task A verifies. Remove from `calcofi4db`:

| function | file | lines | arms |
|---|---|---|---|
| `build_sample_reference()` | `R/model.R` | 404-595 | 18 |
| `.obs_arm_sql()` | `R/model.R` | 703-879 | 14 |
| `.obs_attribute_arm_sql()` | `R/model.R` | 884-924 | 3 |
| `.sample_measurement_arm_sql()` | `R/model.R` | 926-948 | 2 |
| `.compat_specs()` | `R/model.R` | 1070-1130 | 16 |
| `.taxon_norm_sources()` | `R/taxa.R` | 144-259 | 5 |

Then retire `emit_core_tables()` and `create_compat_views()`.

**Check before deleting:** `release_database.qmd`'s `core_tables` /
`core_parity` chunks, and `build_sample_reference()` is referenced by
`build_grid_reference()`'s docs and possibly `publish_*` notebooks. The user was
explicit: *"emit core tables per dataset; do not wrangle odd source parquet tables
into core at end with release_database.qmd"* — the release must end up a **pure
union of shards** with no per-dataset logic.

`.taxon_norm_sources()` is the awkward one: it keys off per-dataset **table names**
(`species`, `phyto_taxon`, `zoodb_taxon`, …). Each notebook should pass its own
vocabulary explicitly instead.

### Task C — fix the taxon lineage gap (the taxa-matching problem)

**Taxa resolved through `metadata/measurement_taxon.csv` get no `rank`, no
`parent_taxon_key`, no classification** — only `worms_id` + `scientific_name`. So
hierarchy rollups silently return nothing: a query for "all Decapoda" does not find
the *M. magister* records.

| dataset | taxa | rank | parent |
|---|---|---|---|
| `swfsc_ichthyo` | 1687 | 1687 | 1686 |
| `cce-lter_euphausiids` | 38 | **0** | **0** |
| `swfsc_cufes` | 6 | **0** | **0** |
| `cdfw_dungeness-crab` | 3 | **0** | **0** |
| `calcofi_phyllosoma` | 1 | **0** | **0** |

Only ichthyo has lineage, from its own `species` table. `merge_taxon_shards()`
coalesces by priority, but a non-fish taxon appears in no shard that has lineage,
so it stays bare in the release too.

Fix: fetch rank + classification from WoRMS for crosswalk-resolved taxa
(`AphiaRecordByAphiaID` + `AphiaClassificationByAphiaID`, or
`worrms::wm_classification`), cache it, and populate in `build_taxon_reference()`.

Also decide whether these columns should exist at all: **`ncbi_id` and `inat_id`
are populated by NO dataset**, and `family` by none *including* ichthyo.

`ingest_cdfw_dungeness-crab.qmd` asserts the gap's current size (3 taxa), so it
**fails when this is fixed** — remove the caveat in the same change.

### Task D — provider renames

Provider = the **curating organization**; not the hosting portal, not a collection
or lab within the org. All three are pre-registered in `metadata/provider.csv` with
`status=deprecated` and the reason.

| from | to | why |
|---|---|---|
| `calcofi_bird_mammal_census` | `farallon_bird-mammal` | Farallon Institute (William Sydeman, PI + senior scientist) |
| `ucsd_sio_mesopelagic-fish` | `sio_mesopelagic-fish` | redundant prefix |
| `pic_zooplankton` | `sio_pic-zooplankton` | PIC is a *collection*; SIO is the org, `pic-zooplankton` the dataset |

Each `dataset_key` ripples into: the migrated notebook block, `taxon_override.csv`
rows, the hardcoded `priority` vector in `merge_taxon_shards()`,
`metadata/{provider}/{dataset}/` dirs, `measurement_type.csv` `_source_datasets`,
`measurement_taxon.csv` `dataset_key`, `data/parquet/` dirs,
`scripts/build_workflows_index.R` (drop the deprecated rows), GCS
`gs://calcofi-db/ingest/` + `gs://calcofi-files-public/archive/` prefixes, and the
GDrive source folders. **Confirm with the user before moving GDrive/GCS objects.**

### Task E — publish core only, remaining cases

Most ingests already do. Two genuine exceptions:

- **`calcofi_mets`** publishes `mets_measurement`, a real per-dataset source table.
  Give its content a core home or drop it — the source is archived.
- **`swfsc_ichthyo`** publishes `grid`, `cruise`, `ship`, `lookup`. These are
  *shared references*, not source tables, and other ingests borrow them via
  `load_prior_tables()` — so they need a home, just maybe not ichthyo's. `grid` is
  already buildable deterministically via `build_grid_reference()`.

### Task F — `cdfw_dungeness-crab` follow-ups

Held out of the release by `in_release: false` **and** `publish_to_gcs <- FALSE`.
The only thing blocking release is **Q01**: no licence, no citation, permission to
publish unconfirmed. Christy Juhasz (CDFW Marine Region) supplied the files;
Laura Rogers-Bennett has retired. An email draft to Erin Satterthwaite + Betty
Huang is in Gmail (thread `19fafa7b20632486`) — **the user is sending it**.

When Q01 clears: flip `in_release: true`, flip `publish_to_gcs <- TRUE`, and move
`metadata/cdfw/dungeness-crab/measurement_type_new.csv` (`carapace_length`,
`settled_volume_ml`) into the shared registry **in the same change**.

Also open: **Q05** — this ingest introduced `sample_type = 'subsample'` (new
vocabulary) and pointed `parent_sample_key` at the matched `swfsc_ichthyo` site
occupation (a deliberate cross-dataset edge). Both want review.

---

## Gotchas that cost time — read before starting

1. **Filter `measurement_taxon.csv` to `dataset_key`.** `emit_core_tables()` did
   that internally. An unfiltered read leaks other datasets' taxa into the shard
   (zoodb got 44 taxa instead of its own 33).
2. **Use `ensure_measurement_taxon()`**, don't write `_measurement_taxon` from the
   CSV directly — it derives `taxon_key` via `taxon_key_of()`, and a
   `'worms:' || worms_id` string built inline mis-keys ITIS-resolved taxa.
3. **Read `worms_id`/`itis_id` as integer.** As a double, `CAST(… AS VARCHAR)`
   gives `"440388.0"` — non-NULL, joins to nothing. Assert `obs.taxon_key`
   **resolves in `taxon`**, not merely that it is non-NULL.
4. **`append_*` column contracts are positional** (each wraps your SELECT in
   `AS src(...)`). Emit columns in the documented order.
5. **Migrate what exists, don't add what looks missing.** I invented an
   `append_sample_measurement()` arm for mesopelagic-fish from a stale status
   string; it never had one.
6. **Capture baselines before running anything.** A buggy intermediate run
   overwrites `manifest.json` and destroys the comparison.
7. **Don't summarise a FAILED validation as "all expected."**
   `validate_for_release()` flags every `_id`/`_key`/`_uuid` column as required,
   which is a heuristic, not a contract. Declare each nullable case with its count
   and reason and hard-fail on anything undeclared — that is what surfaced Task C.
8. **`libs/ingest.R` sets `overwrite <- TRUE`**, which deletes the wrangling DB.
   Fine for small datasets; for `ctd-cast` it now restores from the checkpoint.
9. **`mermaid-format: png` stays disabled.** It routed diagrams through headless
   Chrome, which hung for 3h15m on a 60 KB diagram.
