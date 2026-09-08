---
name: pipeline-targets
description: "Running the workflows targets pipeline safely — single-file target outputs, invalidating a rendered .qmd, the tidyselect/Rscript loop traps, tar_invalidate on never-run targets, in_release: false, the no-Working-DuckLake fact, staging bulk inputs under cc_stage_dir() (never unzip into Drive), get_duckdb_con(), the mermaid-png Chrome hang, and the CTD team's PostgreSQL boundary. Load before running or debugging tar_make(), adding a target, or when a target looks permanently outdated."
---

# Running the pipeline

> Moved verbatim out of `CLAUDE.md` on 2026-09-08 so the rules stay in every session's context and the mechanics and incidents behind them load only when needed. `CLAUDE.md` summarizes each rule and names this skill.

## Targets traps

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

## No Working DuckLake

::: There is **no Working DuckLake**, and no ingest calls `finalize_ingest()`.
Both appear in `README_PLAN.qmd` as design intent and were documented here as if
built; verified 2026-07-30 — `gs://calcofi-db/ducklake/working/` holds **zero
objects**, `grep -l finalize_ingest ingest_*.qmd` matches **nothing**, and
`release_database.qmd`'s `con_wdl` is `get_duckdb_con(":memory:")` (the `wdl` in
the name is vestigial). All 16 data ingests use the
`write_parquet_outputs()` + `build_metadata_json()` + `sync_to_gcs()` trio.
Do not "migrate the laggards onto `finalize_ingest()`" — there are no laggards,
and that function expresses neither the content-hash upload dedup nor the `_new`
delta sidecars that the trio does. :::

## `in_release: false` — stage an ingest without releasing it

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


## Notebook inputs, DuckDB and rendering

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

