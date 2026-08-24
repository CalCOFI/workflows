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

**A target's `output:` must be a single file that target alone writes — never a
directory.** Every target is `format = "file"`, so `targets` hashes whatever path
the command returns. Claim a directory and *anything* later written underneath it
moves that hash, leaving the target outdated forever.

`release_database` declared `data/releases` and was in exactly that state.
`test_release` writes `data/releases/{version}/test_results.json` — as a **side
effect**, not as its declared output, so no comparison of the `output:` fields
could have related the two. On v2026.08.08 the release's own files landed
16:46–17:06 and `test_results.json` at 17:08:47, so the target went stale the
instant the pipeline finished and every later `tar_make()` on it *or anything
downstream* re-ran a ~40 min freeze and a multi-GB re-upload of an
already-promoted release. Nothing was wrong with the data; the pipeline just
could not tell it was done. The directory was also the accumulator of every
release ever cut, so pruning an old local release invalidated the current one.

It now declares `data/releases/_release_stamp.json`, written last by the
`cleanup` chunk: version + `n_tables`/`n_rows` + an md5 of the frozen
`catalog.json`. **Deterministic on purpose** — no wall clock — so a re-run over
unchanged inputs reproduces it byte-for-byte and leaves `test_release` skipped
rather than cascading. `calcofi4db:::check_nested_outputs()` fails
`build_targets_list()` on any directory `output:` (and on statically nested
ones), so this cannot come back silently.

The general rule: **when a target looks permanently outdated, ask what else
writes inside its declared output** before assuming its inputs changed.

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

**…and `tidyselect::all_of(tgt)` does NOT work from inside an `Rscript`.**
`targets` evaluates `names` in its own environment, not the caller's, so a loop
that works when pasted into an interactive console fails from a script with
``object 'tgt' not found`` — instantly, for every target. Ten "runs" completed in
11 seconds and every notebook was untouched. **Substitute the value into the
call** rather than passing the variable:

```r
for (tgt in tgts)
  eval(bquote(targets::tar_make(names = tidyselect::all_of(.(tgt)))))
```

The failure mode is the same each time and is what makes this family of bugs
expensive: the loop reports success and rewrites nothing. Always confirm against
`_output/*.html` mtimes, never against exit codes or a hash comparison.

**…and `tar_invalidate()` errors on a target that has never run.** It operates on
recorded metadata, so a target with no `tar_meta()` entry — one that was
invalidated but whose run then failed, which is exactly the state a re-run is
trying to recover from — fails with ``Element `x` doesn't exist`` and takes the
whole loop down before anything builds. Filter the invalidate list, never the
make list:

```r
known <- targets::tar_meta()$name
for (tgt in intersect(tgts, known))
  eval(bquote(targets::tar_invalidate(names = tidyselect::all_of(.(tgt)))))
eval(bquote(targets::tar_make(names = tidyselect::all_of(.(tgts)))))  # all of them
```

There is no test suite or linter in this repo; correctness is enforced by the
`/validate-ingest` checks and the validation chunks inside `release_database.qmd`.
`release_database.qmd` promotes `latest.txt` only after `test_release.qmd`'s
consumer-contract query suite passes (it exercises the app/`calcofi4r` query
shapes against the frozen release, so a schema drift that would break a consumer
fails the release rather than the app).

## Deploy (release → consumers)

The per-app procedure — the Shiny apps on the CalCOFI server (`git pull`,
`prep_db.R` inside the `rstudio` container, `restart.txt`) and the static
consumers that redeploy themselves — lives in the **`deploy-consumers`** skill,
which loads on demand instead of sitting in every session's context.

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

**No current holdouts.** `cdfw_dungeness-crab` was the only one and entered the
release on 2026-08-14, once CDFW confirmed permission, a CC BY 4.0 licence and a
citation (its Q01). Worth reading that notebook's diff as the worked example of
what "entering the release" costs beyond the flag itself: the two staged
measurement types moved into the shared registry (and the notebook's
`stopifnot()` had to flip from "must not already be there" to "must be there"),
the asserted `coverage_*` keys were deleted so coverage is measured, and
`publish_to_gcs` flipped. The flag is one line; the change is not.

### `cruise_key` is the cruise's designated month, resolved by date span

`cruise_key` is `YYYY-MM-NODC`, and the `YYYY-MM` is the month SWFSC *designates*
for the whole cruise — never the month a cast or tow happened to fall in. A
CalCOFI cruise routinely straddles a calendar boundary (5508BD ran 7 Aug – 25 Sep
1955; 184 of the 664 bottle cruises span two months), and the neighbouring month
is usually a **real** cruise of the same ship, so keying by event month moved
casts onto the wrong cruise with no FK ever failing: v2026.08.14 released 664
source bottle cruises as 799 keys and 5,941 of 35,644 casts on a key their own
source disagrees with. Seven more ingests had the same `format(date, '%Y-%m')`
rule (cufes, pic-zooplankton, euphausiids, zoodb, zooscan, phyllosoma,
picoplankton).

Since calcofi4db 3.20.0 the ichthyo ingest stamps each reference cruise's observed
`date_min`/`date_max` (`add_cruise_date_span()`, from its own tows; the `cruise`
shard carries them) and every other ingest keys events with
`resolve_cruise_key()` — **span containment first** (same ship, ± 3 days; no two
cruises of one ship overlap), then the **source's own designation** where it has
one (`cruise_ym_col`: bottle's `Cruise` = YYYYMM, zooscan's year/month), then the
event month as a last resort, recorded in `cruise_key_method`.
`derive_cruise_key_on_casts()` delegates to it. Two rules that fell out:
- **The reference wins when sources disagree.** Ichthyo designates the 9 Feb –
  29 Mar 1984 Jordan cruise 8403; the bottle database says 8402. Every dataset
  joins to the reference, so agreeing with it is what makes the join mean anything
  — the bottle notebook reports these disagreements rather than "fixing" them.
- **Do not drop a source cruise column as "derivable".** The bottle ingest deleted
  `Cruise` and re-derived it as `STRFTIME(datetime, '%Y%m')` in `casts_derived`
  for years; that was the bug.

A `cruise` reference without spans makes `resolve_cruise_key()` **error**, so an
ingest run against a stale ichthyo shard fails instead of quietly regressing to
the month rule.

### Depth is a coordinate; bound it as one

`check_measurement_bounds()` bounds a **value**. v2026.08.14 shipped a CTD cast
with scans at 14,671 m over a 101 m seafloor: the 17,964 dbar `pressure` was
deleted by its bound and the depth derived from it was not, because
`drop_out_of_bounds()` cannot see a coordinate column. (The cast was JRW's
fluorometer test dip from `20-0010NH_CTDFinalQC/db-csvs/orig/`, a superseded
export the tier classifier matched by substring; it now excludes `orig*` and
`uncorrected/` folders — but **not** every subfolder: `20-1104SH`'s
`separate_runs/` holds six casts that exist nowhere else.)

`release_database.qmd`'s `depth_coverage` chunk (calcofi4db ≥ 3.20.0):
- `check_depth_bounds()` — NaN, negative, or beyond **`CC_DEPTH_MAX_M` (6,500 m,
  the `pressure` ceiling)** on `sample`, `obs` and the supplementals **fails the
  release**.
- `add_sample_seafloor()` stamps `seafloor_depth_m` (bilinear GEBCO 2025,
  positive down, land 0, NA outside the raster) on `sample` — the raster is the
  local master at `$CALCOFI_GEBCO_TIF`; consumers get the column, not the raster.
- `check_depth_vs_seafloor()` — each root sample's deepest attributed depth
  against the deepest GEBCO cell within one cell of its position **+ 10 m** is a
  **report and a ratchet** (`DEPTH_SEAFLOOR_OVER_MAX`, only ever down), never a
  delete: 695 of 412,640 root samples fail it and all but the CTD cast are within
  1.2 km, on slopes and canyons with minute-rounded 1949–1975 positions. The
  measurement is fine; the place is imprecise. That is a `questions.csv` row for
  the owning ingest, filed from `/validate-ingest`'s D3 section.

### Quality flags reach consumers only if consumers apply them

`obs.measurement_qual` is each dataset's **own** vocabulary, uninterpreted
(bottle 6 = ok-from-CTD, 8 = suspect, 9 = missing; CTD 1/2 = use primary/secondary
sensor, 8 = questionable, 9 = bad/missing; DIC WOCE 2 good, 3 questionable, 4 bad,
9 missing — `metadata/measurement_qual.csv`). In Aug 2026 Ralf Goericke reported a
2.18 ml/L oxygen spike at 1,144 m on station 080.0 160.0 in db-viz-station: bottle
198640 of cast 7644 (5508BD, 3 Sep 1955), flagged `O_qual = 8` in the source since
1955. Two gaps let it through:
- the registry mapped `o_qual` onto `oxygen_ml_l` and `oxygen_saturation` but not
  `oxygen_umol_kg` — the form the app plots — so the flag was dropped at ingest.
  Fixed for it and the six CTD unit-conversion siblings (`oxygen_umol_kg_1/2`,
  `oxygen_saturation_1/2`, `potential_temperature_1/2`). The `r_*` pre-QC types
  deliberately stay unflagged (bottle Q09): code 6 describes a substitution made
  *during* QC. The bottle ingest now writes `8`, not `8.0`, like the CTD ingest.
- **no consumer filtered on the column** — not the station portal, db-viz-hex,
  ctd-transects, ctd-viz's plots, calcofi4r's matchers, db-query, nor ERDDAP.
  One predicate now exists in each language — `calcofi4r::cc_qual_ok_sql()`,
  `calcofi4py.qual_ok_sql()`, db-query's `qualOkSQL()` — NULL-safe (an unflagged
  row is kept) and tolerant of `"8.0"`; the build SQL of every static consumer
  and `prep_db.R` of every Shiny one apply it. ERDDAP still exports the column as
  a plain string (no `flag_values`/`flag_meanings`) and the netCDFs cannot express
  it at all — both open.

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

**One exception remains, and it carries a comment saying why.**
`calcofi_phytoplankton` is region-pooled — real coordinates, zero datetimes — so
it asserts `coverage_temporal` only and measures the spatial half like everyone
else. (`cdfw_dungeness-crab` was the second; both its keys were deleted when it
entered the release on 2026-08-14, exactly as this section said to.) If you add
another, the bar is "the data provably cannot answer", not "I know the answer".

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

**The key authority and the id columns are different questions — call
`ensure_taxon_xref()` before the lineage fetch.** Birds key `itis:` because WoRMS
bird taxonomy lags (it still says *Oceanodroma*, *Puffinus*, *Phalacrocorax*), and
that rule is right. But nothing populated the `worms_id` **column** for them, so a
consumer joining on `worms_id` matched **zero rows for every seabird and marine
mammal** — 59,858 of the Farallon census's 64,956 `obs` rows, 92.2% of the
dataset, with no error anywhere.
`ensure_taxon_xref(con, mt_taxon, tx_over, cache_csv = here("metadata/taxon_xref.csv"))`
crosswalks TSN→AphiaID with `worrms::wm_record_by_external(type = "tsn")` — an
**exact id crosswalk, not a name match** (91 of the 92 Farallon bird TSNs resolve
through it) — backfills `itis_id` the other way via `wm_external()`, and falls
back to `wm_records_name()` on `clean_taxon_name()` output for taxa carrying
neither id. Three things to keep straight:
- **A key must be an *accepted* id; a cross-reference is whatever the authority
  links.** A deprecated ITIS TSN is re-keyed (`itis:174553` *Puffinus griseus* →
  `itis:1255050` *Ardenna grisea*) and the event lands in the append-only
  `taxon.notes`; the TSN `wm_external()` returns for an AphiaID is stored verbatim.
- **`clean_taxon_name()` output is the lookup query, never `ds_taxa_code`.** For
  `sio_mesopelagic-fish` the local code *is* the verbatim spreadsheet header
  (`Bathophilus sp.`) and is the join key from `obs` — rewriting it orphans every
  observation of that taxon.
- **`taxonomic_status` was fabricated.** It was the literal string `"accepted"`
  stamped by `ensure_taxon_lineage()` onto all 2,090 taxa, including 28 whose ITIS
  TSN is demonstrably deprecated. It is now fetched, and carries `status_checked` —
  read the two together, a status with no check date is not a fact.

`release_database.qmd`'s `taxon_authority_coverage` chunk gates this:
`check_taxon_ids()` **fails the release** on a dataset-local `taxon_key` that is
not in its explicit allowlist, so the 18 genuinely non-taxonomic classes (zooscan
eggs/multiples/nauplii/others, phyto "other"/"undefined code") are declared one
key at a time and a new unresolved taxon cannot hide among them.

**Lineage ancestors are first-class taxa, and rank ordering is not one dataset's
job.** Two gaps that looked unrelated turned out to share a cause — a taxon was
treated as second-class because of *how it entered the release* rather than what
it is:
- `rank_order` came from a `taxa_rank` table built by an inline vector inside
  `build_taxon_hierarchy()`, which only `swfsc_ichthyo` calls. It existed in that
  one connection and nowhere else, so **100% of ITIS-keyed taxa** and 252
  WoRMS-keyed ones released with the column NULL. It is now
  `calcofi4db::taxa_rank_reference()` — the single vocabulary, covering both
  authorities' rank sets (including `Section`/`Subsection`, which WoRMS nests
  *below* Infraorder for decapods, not between order and family as in botany).
- `.lineage_flat()` emitted one row per *requested* id, so an ancestor arrived
  with a key, a name, a rank and no classification — 430 of ichthyo's taxa at or
  below family rank had neither `family` nor `kingdom`, in both authorities
  alike. It now emits one row per distinct taxon, deriving each node's
  classification from its own ancestors-or-self. No API call: the chains already
  contain them.

When asserting coverage, **split by rank position**. `family` is legitimately
NULL above family rank (a phylum has no family) and `kingdom` is NULL for
`worms:1` Biota (rank Superdomain, above Kingdom). A blanket non-NULL assertion
is wrong and will be "fixed" by someone inventing data.

Ancestor ids are topped up by `ensure_taxon_lineage()`, not `ensure_taxon_xref()`
— the xref step must run *first* (so the lineage fetch asks about the accepted
id) and therefore only ever sees the dataset's own vocabulary. `.apply_xref()`
takes `rekey = FALSE` there: an ancestor's key comes from the chain it was
fetched in, so its ids may be filled but never replaced.

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
| `measurement_type.csv` | Canonical measurement vocabulary (raw measured quantities). `is_canonical` flags the headline types; `valid_min`/`valid_max` bound the value and `valid_depth_min_m`/`valid_depth_max_m` the **depth over which the type is defined** (`est_chlorophyll_a_*` is computed for 0–200 m alone, so a null below that is by construction, not missing data); `derivation` is free text saying how a *derived* type was produced (the `_cruise_corr` vs `_sta_corr` distinction is not something a consumer should have to guess). **Read it with `calcofi4db::read_measurement_type()` and append with `register_measurement_types()`, never with bare `read_csv`/`write_csv`** — see the round-trip trap below. Bounds are **enforced per dataset at ingest time**, see below. |
| `provider.csv` | **Registry of curating organizations** — one row per `provider` slug with `provider_short` (display label), `provider_name`, `url`, `status`. Any provider an ingest declares MUST be here: `scripts/build_workflows_index.R` errors out otherwise. Replaced a hardcoded label vector in that script, which silently yielded `NA` and published a literal `.na.character` heading for unregistered orgs. |
| `dataset.csv` | **DEPRECATED** — superseded by each ingest's `calcofi.dataset_meta` YAML block via `ingest_yaml_to_dataset_df(read_ingest_yaml())`. The CSV drifted from the notebooks and orphaned `obs` rows. |
| `dataset_status.csv` | Pipeline-stage tracker, one row per dataset; each skill writes its stage column. |
| `relationships_cross.csv` | Cross-dataset FKs (intra-dataset FKs live in each ingest's `relationships.json`). |
| `measurement_taxon.csv` | Decomposes a taxon-bearing `measurement_type` name (`sardine_eggs`, `phyllosoma_stage_3`) into (taxon, canonical type, `life_stage`, `bin_value`, target grain). **Stage it with `ensure_measurement_taxon()`, never `dbWriteTable()`** — the CSV has no `taxon_key` column, so a raw write makes every `mx.taxon_key` reference a binder error, and hand-rolling `'worms:' \|\| worms_id` mis-keys ITIS-resolved taxa. Filter it to the emitting `dataset_key`. |
| `taxon_override.csv` | Manual id resolution for source taxa with no clean id (phyto functional groups, marine mammals, "(species group)" codes), matched on the source column named in its own `match_column`. **Generic since calcofi4db 3.6.0** — every arm consults it, and a row naming an unknown `dataset_key` or a `match_column` the source does not expose now **errors**. Before that, `match_column` was never read anywhere in `R/` and only 2 of 7 arms consulted the file, so a row for any other dataset was parsed and silently dropped. |
| `taxon_lineage.csv` | **Generated cache** of WoRMS/ITIS classification chains, one row per (requested taxon, ancestor-or-self). Written by `ensure_taxon_lineage()`; safe to delete (it refetches, slowly). Not hand-maintained. |
| `taxon_xref.csv` | **Generated cache** of the WoRMS↔ITIS cross-reference, one row per (`query_type`, `query_value`). Written by `ensure_taxon_xref()`, which must run *before* `ensure_taxon_lineage()`. Fills `worms_id` on `itis:`-keyed taxa and `itis_id` on `worms:`-keyed ones, re-keys onto the authority-accepted id, and fetches the real `taxonomic_status` + `status_checked`. `notes` is append-only. Safe to delete; `scripts/warm_taxon_xref.R` repopulates it. |
| `metadata/{provider}/{dataset}/` | Per-dataset `tbls_redefine.csv`, `flds_redefine.csv`, `questions.csv`, corrections, etc. |
| `metadata/{provider}/{dataset}/questions.csv` | **Provider-question registry** — 17 files, one per dataset. Read with `calcofi4db::read_questions()` and render with `questions_datatable()`; never a bare `read_csv()` + hand-written `factor(priority, …)` (see below). |

#### Declared bounds are checked per dataset, at ingest time

**Every ingest that emits measurements calls
`calcofi4db::check_measurement_bounds()`, and every non-`ok` row is resolved
before the notebook is done.** The check is `calcofi4db` ≥ 3.10.0; it runs on the
per-dataset `{dataset}_measurement` (or on `obs` after the core is emitted) and
returns one row per measurement type with a `finding` string ready to paste into a
`questions.csv` `context` cell. `bounds_datatable()` renders it.

Two findings, and the second is the larger one:

- **`out_of_range`** — a bound is declared and the data breaks it. Nearly always
  an unconverted sentinel or a scaling error.
- **`undeclared`** — no bound, so nothing was checked. At v2026.08.07 this was
  **73 of 98 (dataset, type) pairs and 67% of all `obs` rows**; only
  `calcofi_ctd-cast` and one `calcofi_mets` type declared anything at all.

Resolve each one of two ways — "note it and move on" is not one of them:

1. **Declare the bound** with `declare_measurement_bounds()` (which sets bounds
   on types that already exist; `register_measurement_types()` only *appends*, so
   it cannot do this — that was the state of all 73). Bounds are
   deliberately **generous**: they catch the impossible, they do not police
   oceanography. If a bound would drop a value an oceanographer wants to see, the
   bound is wrong. **One-sided is fine and usually right** — `valid_min = 0` for a
   count, abundance or biomass is agreeable without knowing any ceiling, and it is
   what catches a negative sentinel.
2. **File a provider question** when the range is not ours to decide, with the
   `finding` as `context` and `status = proposed` carrying the bound you intend to
   apply. A value at exactly `-99`/`-999` is a sentinel until proven otherwise:
   raise it `high` rather than quietly declaring a bound that deletes it.

**Do not invent a bound to make the check quiet.** An `undeclared` type is a
visible finding; a wrong bound silently deletes real data. And do not set the
bound to the observed range — a bound describes what is physically possible, so it
must sit outside the data, or next season's legitimate record becomes a violation.

Enforcement is a **separate call**, `drop_out_of_bounds()`, so a bound must be
agreed before it can delete. It DELETEs rather than flags for the same reason the
`-99` sentinel is deleted: in a long-format table a row IS an assertion that a
value was measured, and there is no in-band way to mark one as not-a-value.

**Check the supplemental tables too, not just `obs`.** `obs_ctd_full` (~216M rows)
and `obs_mets_full` (~20M) are published, and checking `obs` alone certifies about
a third of the release. v2026.08.07 shipped an `obs_ctd_full` whose `ph` ran to
−2.98 — 5,963 values below the declared floor — *that the CTD ingest had already
removed from its own staged output*. The released bytes and the ingest's bytes
disagreed and nothing compared them, because every check looked at `obs`. Each
supplemental table derives from the same guarded per-dataset table as its `obs`,
so its owning ingest asserts `out_of_range == 0` on it rather than merely
reporting: a violation there means that derivation link has silently broken.
Cost is not a reason to skip it — 216M rows check in ~20 s, since the work is a
`GROUP BY` per type over one lazily-read column.

`release_database.qmd`'s `bounds_coverage` chunk is the **backstop, not the
mechanism**: it covers `obs` **and** every table in `supp_tbls`; `out_of_range`
fails the release outright, while `undeclared` is ratcheted by
`BOUNDS_UNDECLARED_MAX` (may only ever go down) so a *new* undeclared type fails
even though the backlog does not.

**Validate a proposed bound against every table the type appears in.** Two bounds
were declared here from `obs` alone and were immediately violated in
`obs_ctd_full` — `isus_v` at 0 (a −0.042 V sensor offset is normal, so the bound
was simply wrong and is now −1) and `dynamic_height` at ±50 (−2,884 dyn m is
genuinely impossible, so those 126 rows are correctly dropped). The observed range
in the headline table is not the observed range. Fix findings at the ingest — that is
the only place the provider can still be asked, and a release-time failure has
nowhere to put the answer. Raising the ratchet to make a release pass is how the
backlog reached 73.

The whole failure mode here is a constraint that *looks* enforced. `valid_min` was
emitted as a netCDF variable attribute and displayed on the schema site for months
while nothing compared a value to it, and `ranges` sat in `/validate-ingest`'s
`--checks` list with no section implementing it.

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

**A skill is a `<name>/SKILL.md` directory whose front-matter carries BOTH `name`
and `description` — anything else is an inert file.** All five of these lived as
bare `.claude/skills/<name>.md` with no `name:` key until 2026-08-10, so none of
them ever loaded and none of the slash commands above resolved, while this
section documented the loop as if it worked. Nothing errors in that state: a
directory with no `SKILL.md` and a stray `.md` beside one are both simply
skipped. `RUNBOOK.md` and `templates/` are deliberately neither — they are read
by path, so they stay as files.

## The CTD team's PostgreSQL database (working store, not the release)

Since 2026-08-19 a multi-user **PostgreSQL 18 + PostGIS + pg_duckdb** database `calcofi` runs on
the CalCOFI server for the CTD team's QA/QC (plan: `.claude/plans/2026-08-17 CTD team
PostgreSQL — …`). It is a *working* store beside the frozen releases, never a consumer of-record:

- Schema `ctd` holds the **entire db-CSV cast archive verbatim** — `ctd.file` / `ctd.scan`
  (10.8 M scans, all 82 source columns, `-99` sentinels included) are **immutable by trigger**;
  untypable source cells live verbatim in `ctd.scan_issue`; problems/fixes are rows in the
  `ctd.flag` ledger (IODE codes, RLS: writers propose, curators accept), presented through the
  generated `ctd.v_scan_qc` / `ctd.v_scan_clean`. DDL: `CalCOFI/server` `postgis/init/*.sql`;
  loader: `libs/pg_ctd.R` + `load_pg_ctd.qmd` (idempotent on `(archive, path)` — sha256 is NOT
  unique, JRW and calcofi.org ship byte-identical files).
- **This ingest repo must never depend on a live PG during a pipeline run.** The bridge is the
  nightly snapshot `gs://calcofi-db/qc/ctd/flag_accepted.parquet` (server cron
  `pg_flag_snapshot.sh`); when the team starts accepting flags, `ingest_calcofi_ctd-cast.qmd`
  applies that file as `measurement_qual` — read it, do not `cc_pg_connect()` from a notebook
  that `targets` runs.
- Access for humans: https://calcofi.io/docs/server-access.html (SSH tunnel; `calcofi4r::
  cc_pg_connect()` / `cc_pg_tunnel()` / `cc_pg_attach()`).

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
- **A link field must contain a link, and `build_workflows_index.R` now enforces
  it.** `link_calcofi_org` / `link_data_source` are rendered as an `href` — by the
  calcofi.io/workflows cards and, via the release `dataset` table, by
  db-viz-station. Two things fail the index build: a non-empty field that is not
  `http(s)` (`link_data_source` held the prose `"BTEDB (Bongo Tow Euphausiid
  Database) export"` and `"SIO Pelagic Invertebrate Collection DB (CSV export)"`),
  and a URL answering **404/410/451** (`swfsc_ichthyo` pointed at
  `/data/biology/ichthyoplankton/`, dead, for months). 5xx/timeout/DNS only
  **warn** — NOAA CoastWatch ERDDAP 503s under load, and failing a rebuild over
  someone else's busy server just teaches people to skip the check.
  - **Probe with a ranged GET, never HEAD.** EDI's `mapbrowse` answers `405` to
    HEAD and EDI hosts most of the bio datasets, so a HEAD-based check fails
    exactly the links that are fine. `curl::new_handle(range = "0-0")` answers
    200/206 everywhere and does not pull the 31 MB bottle zip.
  - If the source genuinely has no portal URL (a private collection DB export),
    leave the field **empty** and put the provenance in `description` — do not
    describe the source in a link field.
  - `CALCOFI_SKIP_LINK_CHECK=1` skips the network half (~3 s vs ~40 s); the shape
    check always runs.
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

    **This generalizes past CRS: anything `release_database.qmd` rebuilds in
    `con_wdl` must appear in BOTH `core_single` (so a local parquet exists) and the
    `gcs_prefix = NA` list (so the uploader takes it). One without the other either
    ships the ingest's copy or fails the upload.** `dataset` had neither through
    `v2026.08.11`: every ingest writes its own full `dataset` shard, so the registry
    handed the table a `gcs_prefix` and the release copied one arbitrary ingest's
    version — publishing 16 rows instead of 15 (`cdfw_dungeness-crab` was
    `in_release: false` then; it entered the release 2026-08-14, so the correct
    count is now 16 for a different reason), **no `dataset_key` column at all**,
    and the *asserted*
    `coverage_temporal`/`coverage_spatial` rather than the values
    `observed_coverage()` measures. Nothing caught it, because every check between
    the build and the freeze reads `con_wdl`, where the table was correct. The
    published bytes are the only thing worth asserting on.
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
- **Archives live on Drive; never unzip into it.** `dir_data` (Google Drive) is
  the durable home for source files, and it syncs a few hundred `.zip` fine. It
  does not survive their *contents*: `ingest_calcofi_ctd-cast.qmd` extracted 151
  archives into `dir_dl` — ~124,000 files, ~45 GB — and the Drive client never
  finished syncing them. Mid-sync it does two things that no plain directory
  does, and both are silent: it **evicts** a file to a cloud-only placeholder
  (full size to `list.files()`, `dataless` in `ls -lO`, and `read_csv()` returns
  a **0-row tibble with no error**), and it mints ` 2.csv` **conflict copies**
  holding the only materialized bytes. That combination cost release
  v2026.08.08 ten cruises, because `cast_dir` is read off the last character of
  the filename and `"…646D 2.csv"` resolved to `NA`.

  Since 2026-08-16 the notebook extracts to `cc_stage_path("ctd-cast", "unzip")`
  — outside Drive, outside the repo, disposable — and **fails the render if an
  extracted directory reappears in `dir_dl`**;
  `scripts/prune_ctd_extracts_from_drive.R` is what that error tells you to run
  (dry-run by default; it refuses to delete a directory holding any file its
  sibling archive cannot give back). Extraction completeness is checked against
  the archive's own member count, not `dir_exists()`, so an interrupted run
  re-extracts instead of reading as finished.

  The generalization: **an ingest's bulk inputs belong under `cc_stage_dir()`
  for the same reason its bulk outputs do.** Drive keeps the one artifact worth
  keeping — the archive — and everything derived from it is local scratch.
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
