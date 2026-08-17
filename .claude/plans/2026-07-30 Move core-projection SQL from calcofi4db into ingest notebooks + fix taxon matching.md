# Move core-projection SQL out of `calcofi4db` into the ingest notebooks, then fix taxon matching

Consolidated handoff, folding in the 2026-07-29/30 core-cut-over session.
Everything under **Remaining** is unfinished; **Context** records what shipped so a
fresh session does not redo it; **Per-dataset migration specs** is the load-bearing
section — it carries the grain rules that were only ever encoded in code that is
about to be deleted.

**The command to kick off with:**

> Continue the plan in `libs/plans/2026-07-30 Move core-projection SQL from
> calcofi4db into ingest notebooks + fix taxon matching.md`. Start with Task A
> (finish the migration, 8 datasets), then B (delete the arms), then C (taxon
> lineage). Read "Per-dataset migration specs" before touching any notebook.

---

## Why

`calcofi4db/R/model.R` carried **~604 lines of dataset-specific SQL across 6
functions in 2 files** — a `switch(dataset_key, …)` per core table. Reading two
migrated notebooks made that switch look mandatory, so a new ingest
(`cdfw_dungeness-crab`) was written without emitting the core at all. The user's
verdict: *"The dataset-specific SQL in model.R is odeous to me"* — migrate all of
it into the notebook that owns each dataset.

**The projection SQL was never required to live in the package.** Every `append_*`
helper takes an arbitrary `SELECT`. `emit_core_tables()` is only a convenience
wrapper. `RUNBOOK.md` §3b documented the per-notebook pattern all along.

There is a second, independent reason the switch had to go, discovered the hard
way: **a projection that exists twice drifts.** The release re-derived the core
from per-dataset tables using its *own* inline copy of every arm, and by the time
anyone compared them the two had separated in four places, each a silent data
error (see *What duplication cost us*). The release is now a pure union of shards
precisely so there is only one copy to keep correct.

---

## UPDATE 2026-07-30 (evening session) — Tasks A, B, C done

**Task A — all 16 datasets now own their projection.** The 8 that still called
`emit_core_tables()` were migrated; verification is against the baseline hashes
below. Also fixed three *already-migrated* notebooks that were broken or
hand-rolling: `swfsc_cufes` and `cdfw_dungeness-crab` staged
`metadata/measurement_taxon.csv` with a bare `dbWriteTable()`, which has **no
`taxon_key` column** — cufes' `mx.taxon_key` was a binder error waiting to happen
(the commit message had flagged it "edited, unverified"), and dungeness
hand-rolled `'worms:' || worms_id`, the exact ITIS-mis-keying trap gotcha 2 warns
about. Both now use `ensure_measurement_taxon()`. `cce-lter_euphausiids` staged
the crosswalk and never used it — removed, with a note on why decomposing
euphausiids through it is the family-flattening bug.

**Task B — the arms are gone.** `calcofi4db` 3.0.0 deletes
`build_sample_reference()` (18 arms), `.obs_arm_sql()` (14), `.obs_attribute_arm_sql()`
(3), `.sample_measurement_arm_sql()` (2), `.compat_specs()` (16),
`emit_core_tables()`, `create_compat_views()`, `.build_taxa_slices()`,
`.ensure_dataset_taxon()`, `.has_tables()`. `R/model.R`: 1299 -> ~590 lines.
Two generic shapes were promoted to exported so notebooks can declare against
them: **`compat_event_sql()`** (was `.compat_event_sql`; `.compat_specs` was just
16 calls to it) and **`prune_taxon_shard()`** (the load-bearing half of
`.build_taxa_slices` — and it is NOT a no-op: ichthyo builds 3412 taxon rows and
keeps 1687).

**`.taxon_norm_sources()` was deliberately NOT deleted** — the one item of Task B
left. It is not an output projection but the *vocabulary normalizer* feeding all
three exported taxa builders; removing it means every taxa-building notebook (10
of them, 6 already verified byte-identical) must hand-construct a 19-column
normalized frame, and re-verify, in the same change. Worth doing, but as its own
change with its own verification pass — not folded into this one.

**Verification (Task A).** Every migrated dataset's core tables are byte-identical
to the pre-migration baseline — `write_parquet_outputs()` content-hashes each
table, so an unchanged hash *plus a confirmed render* is the proof:

| dataset | identical |
|---|---|
| `pic_zooplankton` | `sample` 99,530 (83,530 site_key, 1,521 order_occ) |
| `swfsc_ichthyo` | `sample` 213,122 (61,104/75,506/76,512) · `obs` 459,286 · `obs_attribute` 241,871+128,107 · `sample_measurement` 320,110 · `dataset_taxon` 1,167 · grid/cruise/ship/lookup |
| `calcofi_bottle` | `sample` 35,644+895,371 · `obs` 11,037,615 · `sample_measurement` 268,876 — **99.93% cruise_key, 33,363 bottom_depth**, so the chunk-order constraint holds |
| `calcofi_dic` | `sample` 3,261 · `obs` 3,708 (3,683 deduped onto bottle) |
| `calcofi_mets` | `sample` · `obs` |
| `calcofi_phyllosoma` | `sample` 1,859 · `obs` 1,818 · `obs_attribute` 366, stages 1-11 |
| `calcofi_phytoplankton` | `sample` 409 · `obs` 159,804, 100% taxon-resolved, 0 grid_key |
| `calcofi_bird_mammal_census` | `sample` 60,715 · `obs` 66,272 · `obs_attribute` 82,338 |
| `swfsc_cufes` / `cce-lter_euphausiids` / `cce-lter_zoodb` / `cce-lter_zooscan` / `ucsd_sio_mesopelagic-fish` | `sample` · `obs` · `dataset_taxon` |

Manifest diffs that are NOT this change, and will show up in any comparison
against the 2026-07-30 11:24 baseline: `dataset` (rebuilt from ingest YAML, which
moved), `measurement_type` (a concurrent session committed
`metadata/measurement_type.csv` at 16:53), and `calcofi_mets`'
`mets_measurement`->`obs_mets_full` (commit 2097047). `taxon` changes everywhere
by design — that is Task C.

**Task C — the lineage gap is closed.** `calcofi4db` 3.1.0 adds
`fetch_taxon_lineage()` + `ensure_taxon_lineage()`, wired into all 10
taxa-building notebooks. Cache: `metadata/taxon_lineage.csv`, 21,420 rows for
1,815 WoRMS + 92 ITIS ids (1 unresolved), so re-runs are offline and free. It
also fills `kingdom`/`phylum`/`class`/`order_taxon`/`family`, which **no** dataset
populated, ichthyo included. `parent_taxon_key` is now a *carried* column rather
than `paste0("worms:", parent_worms_id)` at the end — that paste minted
`worms:<tsn>` for ITIS-keyed seabirds, a key resolving to nothing.
`ncbi_id`/`inat_id` stay declared-but-NULL (no source supplies them; dropping the
columns would shift the release schema under consumers). The
`cdfw_dungeness-crab` caveat now asserts the **fix** (0 taxa without lineage, and
*M. magister* reachable from Decapoda) instead of the gap.

Each taxa shard now carries its own taxa **plus their lineage ancestors**, which
have to be rows of their own or `parent_taxon_key` chains dead-end: phyllosoma
1->13, cufes 6->33, zooscan 23->42, phytoplankton 26->65, zoodb 33->75,
mesopelagic-fish 90->212, dungeness 3->17, bird_mammal 128->249. Ichthyo goes
1687->1686: it already had lineage, and swapping the local `spp.duckdb` chain for
the authoritative WoRMS one replaced 4 intermediate nodes (`Synodontinae`,
`Bathysauroidei`, `Ipnopinae`, `Lestidiinae`) with 3 others. `dataset_taxon` is
unchanged everywhere, so no observed taxon moved.

**Two bugs found in this work, both now pinned by tests:**
1. **`fetch_taxon_lineage()` returned the whole shared cache**, not the requested
   ids — putting every dataset's lineage into every shard (`calcofi_phyllosoma`:
   1 taxon -> 2,101). It looked correct on `swfsc_ichthyo` *only* because that
   notebook prunes afterwards. Fixed in 3.1.1; the cache is still written whole,
   but the return is scoped.
2. **`prune_taxon_shard()` is not a no-op** — ichthyo builds 3,412 taxon rows and
   keeps 1,687. Deleting it along with `.build_taxa_slices()` would have doubled
   that shard silently.

`cdfw_dungeness-crab`'s `nullable` contract needed updating in the same change
(3 taxon rows -> 17, plus `parent_taxon_key` NULL on the one lineage root). That
is the contract working: it hard-fails on any undeclared NULL rather than
summarising a FAILED validation as "all expected".

**Two `targets` traps cost this session real time — now in `CLAUDE.md`:**
1. **Editing a `.qmd` does not invalidate its target.** The filename is a literal
   inside the command, so contents are untracked. `tar_outdated()` omits it and
   `tar_make()` says "skipped".
2. **`tar_make(t)` with a loop variable silently no-ops.** Both `tar_make()` and
   `tar_invalidate()` take tidyselect, so a variable named `t` triggers
   ``Column `t` doesn't exist`` for every element. Use
   `tar_make(names = tidyselect::all_of(nm))`, and give `tar_invalidate()` its own
   `try()` — it errors when the target is already invalidated.

Together these produced a convincing false pass: six datasets read "ALL SAME"
against the baseline while the loop had aborted before running any of them.
**An unchanged output hash means "did not run" exactly as readily as "ran and
matched"** — confirm the render happened (`_output/*.html` mtime, or a per-target
OK/FAILED line) before trusting a no-op comparison.

**Task D — the three provider renames are DONE** (2026-07-31), user-confirmed as a
clean break on `dataset_key` plus a full GCS move:

| from | to |
|---|---|
| `ingest_calcofi_bird_mammal_census.qmd` / `calcofi_bird_mammal_census` | `ingest_farallon_bird-mammal.qmd` / `farallon_bird-mammal` |
| `ingest_pic_zooplankton.qmd` / `pic_zooplankton` | `ingest_sio_pic-zooplankton.qmd` / `sio_pic-zooplankton` |
| `ingest_ucsd_sio_mesopelagic-fish.qmd` / `ucsd_sio_mesopelagic-fish` | `ingest_sio_mesopelagic-fish.qmd` / `sio_mesopelagic-fish` |

Covered: notebooks + `calcofi:` YAML (`target_name`/`provider`/`dataset`/
`workflow_url`/`questions_file`/`output`), `metadata/{provider}/{dataset}/` dirs,
`data/parquet/` + `data/wrangling/`, `measurement_type.csv` `_source_datasets`,
`taxon_override.csv`, `dataset_status.csv`, `field_dictionary.csv`,
`libs/*.R`, `publish_to-netcdf.qmd`, `publish_to-erddap.qmd`,
`release_database.qmd`, and calcofi4db 3.2.0 (`.taxon_norm_sources()`,
`merge_taxon_shards()` priority vector, tests). All three re-ran with **row counts
identical** to pre-rename (60,715/66,272/82,338; 99,530; 102/1,393) and
`dataset_key` restamped. Stale `_output/` renders pruned, `workflows.yml`
regenerated.

- **GCS**: 6 old prefixes deleted only after verifying every object exists under
  the new name; `build_storage_index.R` re-ran so all 6 new prefixes have their
  browsable `index.html`.
- **GDrive**: only `ucsd_sio/` -> `sio/` needed moving. The other two source
  folders are **not** provider-named (`whales-seabirds-turtles/bird-mammal-census/`
  and `calcofi/zooplankton/`), so they stayed put — worth knowing before assuming
  a rename implies a Drive move. The `ucsd_sio 2` sync-conflict duplicate was left
  alone.
- **Gotcha**: a blind repo-wide `pic_zooplankton` -> `sio_pic-zooplankton` sweep
  runs over the already-renamed `target_name`, yielding
  `ingest_sio_sio_pic-zooplankton` and `tar_manifest()` erroring with "is not a
  valid symbol name". Do the YAML edits *after* the sweep, or exclude them.
- **Consumers still to update before the release is promoted** (swept; everything
  else is clean): `apps/db-viz-cruise/global.R` (colour + label maps, 4 lines) and
  `README.md`; `db-viz-station/public/app.js` (6), `metadata/crosswalk_datasets.csv`
  (5), `crosswalk_variables.csv` (25), `crosswalk_report.qmd` (2). The
  `db-viz-station/public/data/*.json` + `crosswalk_report.html` hits are CI-owned
  (`refresh.yml`) — do not hand-edit; they regenerate.
- **Side effect**: editing `metadata/measurement_type.csv` invalidates the
  `corrections_csv` file target, so **all 16 ingests are now outdated** in
  `targets`. Harmless for the release (it loads the CSV wholesale, not the
  per-ingest parquet copies), but a `tar_make()` will re-run everything.

Still open from this plan: **Task E** (publish core only), **Task F**
(`cdfw_dungeness-crab` Q01/Q05), **Task G** (consumer follow-ups), and the
`.taxon_norm_sources()` refactor above. Nothing is committed.

---

## Status at handoff

- **v2026.07.30 is released.** The consolidated core ships: ingests write
  `sample`/`obs`/`obs_attribute`/`sample_measurement` + taxa refs as parquet
  shards; `release_database.qmd` unions them.
- **`calcofi4db` 2.21.0** on `main`. Generic shape builders exported.
- **8 of 16 datasets migrated** to notebook-owned projections: `ctd-cast`,
  `cce-lter_euphausiids`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`,
  `cce-lter_zooscan`, `cdfw_dungeness-crab`, `swfsc_cufes`,
  `ucsd_sio_mesopelagic-fish`.
- **8 still call `emit_core_tables()`** and so still depend on the arms:
  `calcofi_bird_mammal_census`, `calcofi_bottle`, `calcofi_dic`, `calcofi_mets`,
  `calcofi_phyllosoma`, `calcofi_phytoplankton`, `pic_zooplankton`,
  `swfsc_ichthyo`.
- `ingest_spatial` and `ingest_ices.dk_ship-ices` emit no core by design.

### Uncommitted at handoff

`_quarto.yml` + `explore_accdb_hydro-master.qmd` (mermaid PNG disabled — see
gotcha 9), `ingest_calcofi_ctd-cast.qmd`, `libs/calcofi_notes.md`, plus
`_output/` and `data/` churn. Commit or discard before starting.

---

## Context — what shipped (do not redo)

### The unlock: generic shape builders are exported

The arms were mostly *declarative calls to private helpers*, which is **why**
projections had to live in the package — you cannot declare a projection from a
notebook if the vocabulary for declaring one is private. Now exported:

| function | version | what it gives a notebook |
|---|---|---|
| `sample_arm_self()` | 2.20.0 | the one-event-table `sample` shape (9 of 18 arms were a single call to it) |
| `compat_measurement_sql()` | 2.20.0 | the compat VIEW over `obs` |
| `ns_key()` | 2.20.0 | namespaced `dataset_key:sample_type:id` |
| `ensure_measurement_taxon()` | 2.21.0 | stages `_measurement_taxon` **with the derived `taxon_key`** |

A migrated notebook reads:

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

### Core schema additions (2.14.0)

- **`sample.site_key`** and **`sample.order_occ`** — event-level and
  cross-dataset (`site_key` is on 13 of 18 source event tables; it is the
  source's own station id, where `grid_key` is the *derived* grid cell).
  `order_occ` spelling varies (`ord_occ`) and CTD stores it as text →
  `TRY_CAST(… AS INTEGER)`. `tow`/`net` inherit both from their parent site.
  Without these, `site`/`casts`/`ctd_cast` could not be rebuilt from the core.
- `sample.tow_type` (2.10.0) — net gear, for gear-appropriate CPUE.

### `sync_to_gcs()` transfers in parallel (2.15.0)

It used to spawn one `gcloud storage cp` **process per file** and one `rm` per
stale object, which serialised every upload — `obs_ctd_full` is 96 partitions,
and on a slow link that ran at ~1.3 MiB/s and dominated the ingest. Default is
now a single `gcloud storage rsync -r`, with `delete_stale` mapped onto
`--delete-unmatched-destination-objects`. Per-file path remains at
`parallel = FALSE`.

### Release side (all shipped)

- `assemble_core()` / `assemble_core_table()` / `merge_taxon_shards()` /
  `core_shard_paths()` in `calcofi4db/R/shards.R`.
- `core_parity` recast from per-dataset comparisons to **shard conservation**,
  global key uniqueness, and FK integrity across **every grain**.
- `dataset` built from `ingest_yaml_to_dataset_df(read_ingest_yaml())`;
  `metadata/dataset.csv` is **DEPRECATED**.
- The Phase-1 `v_obs_env`/`v_obs_bio`/`v_obs` chunk is **deleted**.

### Verification method

`write_parquet_outputs()` content-hashes each table, so an unchanged projection
reports **"Reused — unchanged"** and does not rewrite the parquet. That is proof,
not inspection. Baseline: `…/scratchpad/baseline/data_hash_baseline.json`
(95 tables × 16 datasets, captured pre-migration). If that scratchpad is gone,
re-capture from the last release before migrating anything further.

---

## What duplication cost us — four silent data errors

Worth reading before Task B, because these are the failure mode the migration
exists to prevent. Each was live in one copy of the projection and not the other.

1. **euphausiids flattened to family.** The BTEDB export resolves 37 species ×
   17 life stages. The *release* arm still decomposed via `_measurement_taxon` on
   `raw_measurement_type = 'euphausiid_abundance'`, collapsing all 37 to
   `worms:110513` (Euphausiidae) and nulling `life_stage`. `model.R` was correct.
   Now pinned by a regression test.
2. **bird_mammal merged distinct species.** Both copies grouped the `obs`
   headline by `taxon_key`. Only 156 of 207 observed `species_code`s resolve
   (44 are `include_flag = FALSE`, plus unidentified categories), so **every
   unresolved species on a transect summed into one NULL-taxon row.** Fix: group
   by `o.species_code` (taxon_key is functionally determined by it, so carrying
   both does not split the grain).
3. **phytoplankton emitted no observations.** The `obs` arm existed *only* in the
   release; `model.R` returned NULL, so the per-ingest projection produced 0 rows
   (now 159,804).
4. **cufes/phyllosoma lost their taxa.** `model.R` kept the raw
   `measurement_type` with `taxon_key` NULL; only the release decomposed via
   `_measurement_taxon` into taxon + canonical type + `life_stage`.

---

## Remaining

### Task A — finish the migration (8 datasets)

Re-verify each against the baseline hashes. Cheapest first; the last three are
genuinely bespoke. **Read the matching entry in "Per-dataset migration specs".**

1. **`pic_zooplankton`** — `sample` only, no measurements. Simplest.
2. **`calcofi_phyllosoma`** — `sample_arm_self` + an `obs_attribute` arm.
3. **`calcofi_phytoplankton`** — region-pooled; publishes an extra `region` table.
4. **`calcofi_bird_mammal_census`** — aggregating `obs` + behaviour
   `obs_attribute`. Coordinate with Task D (rename to `farallon_bird-mammal`).
5. **`calcofi_dic`** — depends on `casts`/`bottle` from `calcofi_bottle`.
6. **`calcofi_mets`** — thinned-table pattern; also Task E.
7. **`calcofi_bottle`** — cast+bottle pair, `sample_measurement`, and a
   **chunk-ordering constraint** (see specs).
8. **`swfsc_ichthyo`** — 3 chained `sample` arms, `obs_attribute`,
   `sample_measurement`, and it publishes the shared refs (Task E).

### Task B — delete the arms and retire the wrapper

Only after Task A verifies. Remove from `calcofi4db`:

| function | file | arms |
|---|---|---|
| `build_sample_reference()` | `R/model.R` | 18 |
| `.obs_arm_sql()` | `R/model.R` | 14 |
| `.obs_attribute_arm_sql()` | `R/model.R` | 3 |
| `.sample_measurement_arm_sql()` | `R/model.R` | 2 |
| `.compat_specs()` | `R/model.R` | 16 |
| `.taxon_norm_sources()` | `R/taxa.R` | 5 |

Then retire `emit_core_tables()` and `create_compat_views()`.

**Check before deleting:** `build_sample_reference()` is referenced by
`build_grid_reference()`'s docs and possibly `publish_*` notebooks.
`.taxon_norm_sources()` is the awkward one — it keys off per-dataset **table
names** (`species`, `phyto_taxon`, `zoodb_taxon`, …); each notebook should pass
its own vocabulary explicitly.

`create_compat_views()` currently also rebuilds `casts`/`bottle` (added for DIC,
see specs). Whatever replaces it must keep that capability or DIC breaks.

### Task C — fix the taxon lineage gap

**Taxa resolved through `metadata/measurement_taxon.csv` get no `rank`, no
`parent_taxon_key`, no classification** — only `worms_id` + `scientific_name`. So
hierarchy rollups silently return nothing: "all Decapoda" does not find the
*M. magister* records.

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
`worrms::wm_classification`), cache it, populate in `build_taxon_reference()`.

Also decide whether these columns should exist: **`ncbi_id` and `inat_id` are
populated by NO dataset**, and `family` by none *including* ichthyo.

`ingest_cdfw_dungeness-crab.qmd` asserts the gap's current size (3 taxa), so it
**fails when this is fixed** — remove the caveat in the same change.

### Task D — provider renames

Provider = the **curating organization**; not the hosting portal, not a
collection or lab within the org. All three pre-registered in
`metadata/provider.csv` with `status=deprecated` and the reason.

| from | to | why |
|---|---|---|
| `calcofi_bird_mammal_census` | `farallon_bird-mammal` | Farallon Institute (William Sydeman, PI) |
| `ucsd_sio_mesopelagic-fish` | `sio_mesopelagic-fish` | redundant prefix |
| `pic_zooplankton` | `sio_pic-zooplankton` | PIC is a *collection*; SIO is the org |

Each `dataset_key` ripples into: the migrated notebook block,
`taxon_override.csv`, the hardcoded `priority` vector in `merge_taxon_shards()`,
`metadata/{provider}/{dataset}/` dirs, `measurement_type.csv` `_source_datasets`,
`measurement_taxon.csv` `dataset_key`, `data/parquet/` dirs,
`scripts/build_workflows_index.R`, GCS `gs://calcofi-db/ingest/` +
`gs://calcofi-files-public/archive/` prefixes, and the GDrive source folders.
**Confirm with the user before moving GDrive/GCS objects.**

### Task E — publish core only, remaining cases

- **`calcofi_mets`** publishes `mets_measurement`, a real per-dataset source
  table. Give its content a core home or drop it — the source is archived.
- **`swfsc_ichthyo`** publishes `grid`, `cruise`, `ship`, `lookup`. These are
  *shared references*, not source tables, and other ingests borrow them via
  `load_prior_tables()` — so they need a home, maybe not ichthyo's. `grid` is
  already deterministic via `build_grid_reference()`.

### Task F — `cdfw_dungeness-crab` follow-ups

Held out by `in_release: false` **and** `publish_to_gcs <- FALSE`. Blocking:
**Q01** — no licence, no citation, publication permission unconfirmed. Christy
Juhasz (CDFW Marine Region) supplied the files; Laura Rogers-Bennett has retired.
Email draft to Erin Satterthwaite + Betty Huang in Gmail (thread
`19fafa7b20632486`) — **the user is sending it**.

When Q01 clears: flip `in_release: true`, flip `publish_to_gcs <- TRUE`, and move
`metadata/cdfw/dungeness-crab/measurement_type_new.csv` (`carapace_length`,
`settled_volume_ml`) into the shared registry **in the same change**.

Open: **Q05** — introduced `sample_type = 'subsample'` (new vocabulary) and
pointed `parent_sample_key` at the matched `swfsc_ichthyo` site occupation (a
deliberate cross-dataset edge). Both want review.

### Task G — consumer follow-ups from the cut-over

- **`publish_calcofi_to_erddap.qmd` will fail if run.** All five `parquet` paths
  point at per-dataset tables that no longer exist (one, `phyto_obs.parquet`, was
  already stale pre-cut-over). A callout in the notebook documents the core
  replacement for each row; deliberately not repointed, because that changes what
  is served to ERDDAP. `sample` carries time/lat/lon/depth directly, so one
  config row per `dataset_key` over `sample`/`obs` replaces the per-table list.
- **`db-viz-hex`** read `tow_type` from the ichthyo ingest parquet; it is now in
  released `sample.tow_type`, so it can read the release instead.
- **Ingests do not pass `delete_stale`** to `sync_to_gcs()`, so a run uploads new
  shards *beside* retired objects. The 2026-07-29 sweep pruned all 16 datasets
  by hand; decide whether to flip the ingests to `delete_stale = TRUE`
  permanently (one flag each, now cheap) or keep sweeping.

---

## Per-dataset migration specs

**These are the grain rules. They exist in code that Task B deletes.** Carry each
into the notebook verbatim in behaviour, and assert it.

### `calcofi_bird_mammal_census`

- `obs`: one row per **(transect, `species_code`)**, `count` SUMmed across
  behaviours, `measurement_type = 'count'`, `life_stage` **NULL**.
  `GROUP BY tr.gis_key, tr.grid_key, tr.cruise_key, tr.latitude, tr.longitude,
  tr.datetime_start_utc, o.species_code, dt.taxon_key`.
  - **Group by `species_code`, NOT `taxon_key` alone** — see *What duplication
    cost us* #2. Assert: `MAX(n) FROM (SELECT sample_key, COUNT(*) n FROM obs
    WHERE taxon_key IS NULL GROUP BY 1) > 1`.
  - Behaviour must **not** ride on `life_stage`, or the same birds are counted
    once per behaviour code.
- `obs_attribute`: one row per source (transect, species, behaviour);
  `measurement_type = 'behavior'`, `bin_label` = `bird_mammal_behavior.description`,
  `bin_value` NULL. Assert attribution SUMs back to the headline.
- Reference values at v2026.07.30: `sample` 60,715; `obs` 66,272 (125 taxa,
  1,316 rows without `taxon_key`); `obs_attribute` 82,338 (4 labels).

### `calcofi_bottle`

- Two-level `sample`: `cast` (root) + `bottle` (leaf, `parent_sample_key` = cast).
- `obs`: `bottle_measurement` ⨝ `bottle` ⨝ `casts`, `realm='env'`, filtered
  `WHERE c.grid_key IS NOT NULL`.
- `sample_measurement`: `cast_condition` only — `condition_type` →
  `measurement_type`. **`cast_id` is DOUBLE there**, so
  `CAST(CAST(cast_id AS BIGINT) AS VARCHAR)` or the key becomes `…:cast:5.0`.
- **`bottom_depth` needs no arm of its own.** The ingest already pivots the
  source `Bottom_D` into `cast_condition` (33,363 rows) and **drops the column
  from `casts`**. An added `UNION ALL SELECT bottom_depth_m FROM casts` was both
  redundant and a binder error; it appeared to work only because a stale
  wrangling DB still had the column. Assert 33,363 and no duplication.
- **CHUNK ORDER CONSTRAINT.** `sample` carries `cruise_key`, so the
  Cross-Dataset Integration section (ship match + `derive_cruise_key`) must run
  **before** the projection. It used to run after the parquet write, with a
  `rewrite_casts_parquet` chunk patching the columns in afterwards; that chunk is
  deleted. Result: `cruise_key` on 894,781/895,371 bottles (99.93%). If the
  projection runs first, `cruise_key` is silently NULL throughout.
- Reference: `sample` 35,644 casts + 895,371 bottles; `obs` 11,037,615.

### `calcofi_dic`

- **Depends on `calcofi_bottle`'s shard.** Bottle no longer publishes
  `casts`/`bottle`, so DIC loads bottle's `sample.parquet` and rebuilds them:
  `cast_id`/`bottle_id` from `split_part(sample_key, ':', 3)`, the cast FK from
  `parent_sample_key`, `depth_m` from `depth_min_m`.
- **Load it under a different name.** DIC builds its *own* `sample` later; if
  bottle's shard is loaded as plain `sample` it gets replaced mid-render and the
  views break. Current code: `ALTER VIEW sample RENAME TO _bottle_sample`, then
  `create_compat_views(con, "calcofi_bottle", sample_tbl = "_bottle_sample")`.
  Task B must preserve this capability.
- `obs` dedups onto bottle: a DIC row sharing a physical Niskin points at
  `calcofi_bottle:bottle:<id>`; only non-shared Niskins mint a
  `calcofi_dic:bottle:<md5>` key. The md5 is
  `md5(concat_ws('|', expocode, datetime_start_utc, latitude, longitude, depth_m))`
  and **must match** between the `sample` and `obs` arms.
- Reference: `obs` 3,708; `sample` 3,262 (only 7 with `cruise_key` — expected,
  these are the rows that matched no cast; issue #47).

### `swfsc_ichthyo`

- Three chained `sample` arms: `site` (root; datetime = earliest tow time) →
  `tow` (`tow_type` = `tow_type_key`) → `net`. `tow`/`net` inherit
  `site_key`/`order_occ`/`grid_key`/`cruise_key` from the site.
- `obs`: base rows only — `WHERE i.measurement_type IS NULL` →
  `measurement_type='abundance'`, value = `tally`.
- `obs_attribute`: `WHERE i.measurement_type IN ('stage','size')`;
  `size` → `body_length`; `bin_label` from `lookup` where type is `stage`.
- `sample_measurement`: 5 net-effort types (`volume_sampled`,
  `std_haul_factor`, `prop_sorted`, `small_plankton_biomass`,
  `total_plankton_biomass`), `WHERE mv IS NOT NULL`.
- Reference: `sample` 61,104 site / 75,506 tow / 76,512 net; `obs` 459,286;
  `obs_attribute` 241,871 `body_length` + 128,107 `stage`.
- Compat VIEWs verified byte-identical on real data for `net` (76,512), `tow`
  (75,506) and `site` (61,104) — the adjacency list plus `sample_measurement`
  reconstructs them exactly for every column the core models.

### `calcofi_phyllosoma`

- `obs`: **only `total_phyllosoma`** (`_measurement_taxon` `target='obs'`).
- `obs_attribute`: the eleven `phyllosoma_stage_N` columns →
  `measurement_type='stage'`, `bin_value=N`, `WHERE m.measurement_value > 0`.
  Assert no `measurement_type LIKE 'phyllosoma_stage%'` reaches `obs`.
- Reference: `obs` 1,818 (all taxon-resolved); `obs_attribute` 366, bins 1–11.

### `swfsc_cufes`

- Taxon is baked into the type name (`sardine_eggs`, …). **INNER** join
  `_measurement_taxon` (`target='obs'`) → real `taxon_key` + `'abundance'` +
  `life_stage='egg'`. An unregistered raw type is dropped, so assert every
  `cufes_measurement.measurement_type` is in the registry.
- Reference: `obs` 270,593 across 6 species, all taxon-resolved.

### `calcofi_phytoplankton`

- Region-pooled: `sample_type='region_pool'`, **`grid_key` NULL and `datetime`
  NULL by design** — do not apply the usual `WHERE grid_key IS NOT NULL` filter
  or every row is dropped.
- Reference: `sample` 409; `obs` 159,804, all taxon-resolved, 0 with `grid_key`.

### `calcofi_ctd-cast`

- `sample` is one row per **physical cast** (`cast_key`), deduped — `ctd_cast` is
  per-**scan**. `obs` joins `ctd_thin` → `ctd_cast` to map scan → cast.
- `obs` carries the **thinned** series; the full scan set is the supplemental
  `obs_ctd_full`, built here (not in the release), gated by `BUILD_OBS_CTD_FULL`.
- Assert `obs` row count < `ctd_measurement` row count, or a regression silently
  40× the core.
- Reference: `sample` 14,336; `obs` 5,551,551; `obs_ctd_full` 216,427,608
  (4.9 GB, 96 `cruise_key` partitions).
- `ctd_wide` is **retired** — ERDDAP serves CTD via `EDDTableFromDatabase` over
  DuckDB views + a separate netCDF build. Its whole-file heap read was the
  original ERDDAP OOM.

### `cce-lter_euphausiids`

- **Do not** decompose via `_measurement_taxon` — resolve `taxon_key` through
  `dataset_taxon` on `m.taxon_id` and carry `m.life_stage` on the headline.
  Assert `COUNT(DISTINCT taxon_key) > 1` and that `worms:110513` (family) does
  **not** appear.
- Reference: `obs` 100,477; 37 species; 17 life stages.

### `pic_zooplankton`

- `sample` only — the source has effort/position, no measurements. Assert
  `core$obs` is NULL rather than letting a silent zero look like a bug.
- Reference: `sample` 99,530 (83,530 with `site_key`, 1,521 with `order_occ`).

### `calcofi_mets`

- `obs` fed by `mets_thin` (thinned), not the ~20M-row `mets_measurement`.
  `sample` restricted to samples `mets_thin` references, so the event dimension
  stays proportionate. Assert `n_obs < COUNT(*) FROM mets_measurement`.
- Underway seawater depth recorded as surface (hull-intake depth unknown,
  questions.csv `mets_25`).

---

## Release-side invariants

`release_database.qmd` must stay a **pure union of shards**. Traps found:

1. **Exclude core tables from the table registry.** It marks the *first* ingest
   supplying a table name as canonical — right for a genuinely shared reference
   like `grid`, catastrophic for a shard, because it keeps **one** dataset's
   `obs` and silently drops the other 14. `core_shard_tables` is filtered out of
   `reg_canon` and unioned explicitly.
2. **Renumber surrogate ids after the union.** Every ingest numbers `obs_id` /
   `obs_attribute_id` / `sample_measurement_id` from 1 within its own shard.
3. **Shard conservation is the assertion that matters.** Per-dataset row-count
   comparisons are meaningless once the per-dataset tables are gone; compare
   each shard's row count to the assembled total. That is what catches a dropped
   shard.
4. **Assert the measurement vocabulary at EVERY grain.** Only
   `obs.measurement_type` was checked, so `bottom_depth` — introduced at the
   `sample_measurement` grain — orphaned 33,363 rows unnoticed.
   `sample_measurement.measurement_type` and `obs_attribute.measurement_type`
   are now asserted too.
5. **Build `dataset` from the ingest YAML, never `metadata/dataset.csv`.** The
   CSV listed 13 of 15 datasets and orphaned 533,571 `obs` rows on
   `obs.dataset_key`. The YAML is derived from the same `calcofi:` blocks that
   define the pipeline, so it cannot go stale.
6. **`merge_taxon_shards()` coalesces by source priority** — the same taxon
   appears in several shards (Appendicularia in both zoodb and zooscan) and must
   collapse to one row. Its `priority` vector is hardcoded `dataset_key`s → Task D
   must update it.
7. **Diagnose FK failures without re-running the release.** Reproduce
   `assemble_core(con, root=".", supplemental=FALSE)` + the FK queries in a
   scratch script; ~2 min instead of ~20, and the release's `print()` of the
   offending vector does not survive into the quarto log.

---

## Gotchas that cost time — read before starting

1. **Filter `measurement_taxon.csv` to `dataset_key`.** `emit_core_tables()` did
   that internally. An unfiltered read leaks other datasets' taxa into the shard
   (zoodb got 44 instead of 33).
2. **Use `ensure_measurement_taxon()`**, don't write `_measurement_taxon` from the
   CSV directly — it derives `taxon_key` via `taxon_key_of()`, and a
   `'worms:' || worms_id` string built inline mis-keys ITIS-resolved taxa.
3. **Read `worms_id`/`itis_id` as integer.** As a double, `CAST(… AS VARCHAR)`
   gives `"440388.0"` — non-NULL, joins to nothing. Assert `obs.taxon_key`
   **resolves in `taxon`**, not merely that it is non-NULL.
4. **`append_*` column contracts are positional** (each wraps your SELECT in
   `AS src(...)`). Emit columns in the documented order.
5. **Migrate what exists, don't add what looks missing.** An
   `append_sample_measurement()` arm was invented for mesopelagic-fish from a
   stale status string; it never had one. Same class of error as the
   `bottom_depth` arm.
6. **Capture baselines before running anything.** A buggy intermediate run
   overwrites `manifest.json` and destroys the comparison.
7. **Don't summarise a FAILED validation as "all expected."**
   `validate_for_release()` flags every `_id`/`_key`/`_uuid` column as required,
   which is a heuristic, not a contract. Declare each nullable case with its
   count and reason and hard-fail on anything undeclared — that is what surfaced
   Task C.
8. **`libs/ingest.R` sets `overwrite <- TRUE`**, which deletes the wrangling DB.
   Fine for small datasets; for `ctd-cast` it restores from the checkpoint. A
   *stale* wrangling DB is also a hazard in the other direction: it made the
   bogus `bottom_depth` arm pass one full pipeline run before failing.
9. **`mermaid-format: png` stays disabled** in `_quarto.yml` (both this repo and
   `MarineSensitivity/workflows`). It routed every diagram through headless
   Chrome, which wedged **3h15m** at 0.2% CPU on a **60 KB** diagram that had
   rendered in ~2 min the run before, **ignored SIGTERM**, and needed `SIGKILL`.
   - The old diagnostic ("figures present = done; absent = graph too big") is
     **wrong** — figures were absent on a tiny graph with no `cc_erd()` at all.
   - `QUARTO_CHROMIUM_HEADLESS_MODE = "new"` fixes a *different* failure (Chrome
     ≥132 dropping legacy `--headless`) and does **not** prevent this.
   - This silently killed two `tar_make()` runs, both misdiagnosed as external
     kills by other Claude sessions, because the only symptom is a run that stops
     progressing.
10. **After any killed render, clear two things.** A stale
    `_targets/meta/process` lock (`targets::tar_unblock_process()`) **and** an
    orphaned `rmd.R` (`pgrep -f rmd.R`). The orphan holds a wrangling DuckDB
    open, so the next run contends with it over the same file. The *next* run's
    error message points at locking, not at the kill.
11. **Verify a push, don't trust the shell.** `git push … ; echo pushed` prints
    "pushed" on failure too. Compare `git rev-parse HEAD` to
    `git rev-parse origin/main`. `main` moved under this session twice.
12. **Exclude `index.html` from any GCS prune.** `gcloud storage rsync
    --delete-unmatched-destination-objects` classes it as unmatched and deletes
    it — it is the generated browsable listing page
    (`scripts/build_storage_index.R`) with no local counterpart. A dry run caught
    this across 8 datasets. Always `--dry-run` first and read the delete list.
13. **A background task reporting "exit 0" is not success.** Read the log. Also
    never launch a long render with `nohup … &` inside a background call: the
    tool returns when `nohup` forks, the harness stops tracking it, and a
    "completed" notification arrives while the render runs on for another hour.
