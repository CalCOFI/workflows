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
Rscript -e 'targets::tar_unblock_process()'            # clear a locked db process

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

## RELEASES.md is not optional (the database's NEWS file)

`RELEASES.md` at the repo root documents **what changed between database releases and
why** — one `# vYYYY.MM.DD (date)` section per release, newest first, with `# Unreleased`
collecting changes until the next cut. It is uploaded to
`gs://calcofi-db/ducklake/releases/RELEASES.md`, and each version's `RELEASE_NOTES.md`
(what db-schema's "release notes" modal and `calcofi4r::cc_release_notes()` show) is its
section plus a **generated appendix** (tables/rows from `catalog.json`, datasets, the
consumer-contract result, package versions). Before 2026-08-25 `RELEASE_NOTES.md` was a
`paste0()` template whose only live content was row counts; it listed four datasets while
sixteen shipped and named tables retired months earlier.

- **Every change that alters release content adds to `# Unreleased` in the same commit**
  — a schema column, a key derivation, a validation gate, a dataset entering or leaving, a
  data fix. Headings are declarative sentences ("Depth is a coordinate, and it is now
  bounded"), bodies say what was wrong, what is true now, by how much, and which
  provider question it raised; consumer-facing breakage gets a `**Consumers:**` line.
- `release_database.qmd`'s `release_notes_narrative` chunk (before the freeze) renames a
  non-empty `# Unreleased` to the release and **stops the release** if no section for
  `release_version` exists — `calcofi4db::promote_unreleased()`. Do not bypass it by
  writing a one-line section; the packages' `NEWS.md` rule has the same intent.
- Notes are not data. `Rscript scripts/publish_release_notes.R [version | --all]`
  (`calcofi4db::publish_release_notes()`) re-renders and re-uploads `RELEASE_NOTES.md` for
  any version at any time — an edit between the freeze and `test_release`, a correction to
  a promoted version, or the full backfill — without touching parquet, `catalog.json` or
  `latest.txt`. `test_release.qmd` re-publishes the promoted version's notes so the
  appendix carries the validation result.
- A range heading (`# v2026.08.04 – v2026.08.06`) documents several closely spaced
  releases at once; each of those versions' `RELEASE_NOTES.md` says so.

## The brand contract (theme, header, favicon) — `calcofi.io/brand/v1/`

Every CalCOFI product wears one theme, one header and one favicon, honours
`?theme=dark|light` and `?tour=off`, and the rule is **checked weekly, not assumed**
(`CalCOFI.github.io/scripts/check_brand.py`; the contract is
`CalCOFI.github.io/brand/v1/README`). Quarto renders here get it from
`libs/brand/quarto_head.html` + `quarto_header.html` via `_quarto.yml`. **Load the
`brand-contract` skill** before touching a product's theme, header, favicon,
screenshots or `products.yml` card — it holds the cookie chain, the header rules,
the new-product checklist and the two framework traps.

## Deploy (release → consumers)

The per-app procedure — the Shiny apps on the CalCOFI server (`git pull`,
`prep_db.R` inside the `rstudio` container, `restart.txt`) and the static
consumers that redeploy themselves — lives in the **`deploy-consumers`** skill,
which loads on demand instead of sitting in every session's context.

## Architecture

### Data flow

Source files sit on Google Drive and rclone to `gs://calcofi-files/`; `targets`
runs each `ingest_*.qmd`, which stages bulk parquet at `$CALCOFI_STAGE_DIR` and
JSON sidecars in `data/parquet/` (both mirrored to `gs://calcofi-db/parquet/`);
`release_database.qmd` assembles those shards in memory, validates, freezes and
uploads `gs://calcofi-db/ducklake/releases/{version}/`.

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

### Provider UUIDs are columns; the cruise key is checked against the cruise

Ed Weber (SWFSC) asked that the release adopt NOAA's own UUIDs (2026-09-02). The
answer is not to re-key: `sample_key` / `cruise_key` stay the join keys of a
read-only frozen release (15 of 16 datasets mint no UUID at all, and a v5 UUID of
a natural key is that key with worse legibility). Instead the provider's own
identifiers are released as **typed columns beside the namespaced keys**:

- **`cruise.cruise_uuid`** (NOAA's CruiseId) was already released, 691/691
  populated — it is the public join key to NOAA's own CalCOFI database, not
  "internal to the swfsc source" as this file used to say.
- **`sample.source_uuid`** (calcofi4db ≥ 3.32.0, `append_sample()`'s 17th,
  trailing, optional column) — the provider's own identifier for *that* event
  exactly as shipped: ichthyo's `site_uuid` / `tow_uuid` / `net_uuid`. NULL for
  the 15 datasets that mint none; the shards are unioned by name, so a column
  only one shard carries arrives NULL for the rest with no arm touched.
- **`sample.station_uuid` + `station_uuid_method`** (calcofi4db ≥ 3.32.0,
  `match_station_occupation()`, run at release) — the SWFSC station occupation
  *any* event belongs to, on every `sample` row: `self` for ichthyo's own
  site/tow/net; `parent` for a foreign row parented directly to an ichthyo site
  (the Dungeness crab's examined subsamples); `order_occ` / `datetime` for every
  other dataset's root, matched on cruise + station (+ occupation order, or a
  unique occupation within 24 h); otherwise NULL. The match is computed once per
  root sample and copied to every row under it via `root_sample_key`.
- **No `cruise_uuid` on `sample`.** It is a function of `cruise_key` (`cruise` is
  unique on both), so a 1.3M-row UUID column would be pure denormalization — join
  `cruise` once. The one place a real `cruise_uuid` ↔ `cruise_key` link matters
  beyond that join is `swfsc_ichthyo`'s own `site` table, and it does not survive
  past that notebook's emit-core step (its compat VIEW rebuild carries only
  `cruise_key`) — so **the check runs inside the ichthyo notebook**, before that
  rebuild, and its result (0 or not) travels in `manifest.json`
  (`mismatches$cruise_uuid`) for the release gate to read.
- **`create_cruise_key()` must run *after* ship corrections, never before.** The
  July 2019 Bold Horizon cruise shipped as `cruise_key = "2019-07-"` (an empty
  NODC segment — DuckDB's `CONCAT()` treats `NULL` as `''`) because
  `apply_data_corrections()` (which patches the source's blank `ship_nodc` for
  that ship) used to run 280 lines *after* `create_cruise_key()` in the ichthyo
  notebook. `create_cruise_key()` (calcofi4db ≥ 3.32.0) now refuses outright to
  mint a key from a blank/NULL `ship_nodc` or one that fails the `YYYY-MM-NODC`
  format, naming the ship — a reordering mistake fails loudly instead of shipping
  a bad key again; `resolve_cruise_key()`'s source/month steps carry the same
  guard.
- **The `cruise` reference is completed at release, not asserted.** `cruise` is
  the SWFSC ichthyo export's station-occupation cruise list, not a designation
  registry — bottle/CTD/METS/picoplankton key events to cruises (mostly
  1949–1950 and post-export years) the export has no station row for. Measured
  at v2026.08.25: 152 such `cruise_key`s, carried by 153,306 `sample` rows and
  3.8M `obs` rows, named no `cruise` row at all, and nothing failed — the FK was
  never declared. `complete_cruise_reference()` adds one row per missing key
  (`cruise_key_method = 'derived'`, `cruise_key_datasets` = the datasets that
  carry it; the 691 SWFSC rows get `cruise_key_method = 'swfsc'`), resolving
  `ship_key` from the key's own NODC segment — an unresolvable NODC is an error,
  not a silent skip. `check_cruise_key_integrity()` (a new `cruise_key_integrity`
  chunk in `release_database.qmd`, run after the completion + enrichment) is the
  hard gate: key format, `date_ym`/NODC agreement, the FK from `sample`/`obs`
  into `cruise`, `cruise_uuid` hygiene, and every event's date within its
  cruise's span (`tolerance_days`, default 31 — 99.97% of measured outside-span
  events fit; named exceptions for the handful that do not, e.g. seven
  `calcofi_ctd-cast` casts with corrupted timestamps) — plus three ratchets that
  may only ever be lowered: the derived-row count, span overlaps between two
  cruises of one ship, and the per-dataset `NULL cruise_key` backlog (largest for
  `calcofi_dic`, whose unmatched Niskins carry no cruise designation at all —
  `metadata/calcofi/dic/questions.csv` Q07). This gate **supersedes** the old
  warn-only `cruise_key` format regexp that used to print the same "1 rows"
  warning on every render forever.

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

### One climatology for every anomaly (`climatology`, calcofi4db ≥ 3.26.0)

An anomaly is only as good as the baseline it subtracts, and until 2026-08-31 three
products each computed their own: ctd-transects (1993–2013 monthly mean, 5 m bins, one
arbitrary cast per grid cell), the Explorer's Sections lens (**all calendar months** of the
year-slider range — a seasonal-cycle map, not an anomaly: line 90 surface is 15.2 °C in
January, 18.3 in July, 16.8 annually, so a January cruise lost 1–1.5 °C of warming) and
`calcofi4r::cc_climatology()`. The same July 2026 section read +1.4 °C in one and ~0 in
another. `release_database.qmd`'s `browser_objects` chunk now builds **`climatology`** with
`calcofi4db::build_climatology()` — a plain mean per **dataset × `grid_key` × calendar month ×
10 m floor `depth_bin` × measurement type** over **1993–2013**, kept where **≥ 3 distinct
cruises** contribute, the window stamped on every row — partitioned by `measurement_type`
like `obs_env`. Every consumer subtracts that table: ctd-transects (`__TBL:climatology__`,
with `scripts/climatology_fallback.sql` for a release that predates it), explore
(`sql/section_clim.sql`, pooling a variable's member types weighted by `clim_n`),
`cc_climatology()` (reads it when the connection has it). Rules that fell out:

- **Month-matched, always.** A cast's anomaly is its value minus the cell of *its own*
  calendar month. Pooling months is never an option, whatever the UI's season filter says.
- **10 m floor bins, not 5.** `obs` carries the *thinned* CTD series (10 m grid + RDP
  inflection points + bottle depths); at 5 m the off-grid bins hold a third of the casts,
  sampled where the profile bends, and their means sit visibly off their neighbours'.
- **A floor in cruises, not observations.** Nearshore grid cells hold 2–4 real stations
  (`st30-ln90` = 90.30, 90.28, 90.27.7, 88.5/30.1), so one cruise supplies four casts.
  That same fact means the sections should key on `sample.site_key`, not `grid_key` —
  ctd-transects currently keeps whichever cast the ship hit first, explore averages them.
  **Open** (2026-08-31); fixing it moves the climatology's grain to `site_key` too.
- **Plotly's built-in `"RdBu"` runs blue → red** (`0 = rgb(5,10,172)`). Pass an explicit
  ramp — both apps share ctd-transects' five stops — and check the sign in a screenshot.

### Attribution is a contract, checked like links

**Every dataset's `citation_main`, `license` and `doi` are checked, not trusted** —
by `scripts/build_workflows_index.R` and by `release_database.qmd`'s
`dataset_coverage` chunk, both through `calcofi4db::check_dataset_citation()`
(≥ 3.30.0). A citation needs a year and a locator; `license` must be an active id in
**`metadata/license.csv`** (`custom` requires `license_url`; `unknown` or empty fails
unless a question is open); `doi` is bare and must resolve. The network half asks
the source's own authority (EDI cite service, NCEI "Cite as", ERDDAP `.das`,
DataCite) behind `CALCOFI_SKIP_LINK_CHECK`, caches it in
`metadata/{provider}/{dataset}/citation_authority.json`, and reports drift — **it
never writes into a notebook's YAML**; the author's string is the record. An error
is exempt only while an `open`/`proposed` `questions.csv` row on `related_table =
dataset` names the field, so a gap is fixed or on record with the provider. A value
is written only with evidence (a `# source: <url>, checked <date>` comment);
**never invent a license**. `source_accessed` is measured at release time
(`resolve_source_accessed()`: the ingest's `stamp_source_access()` record, else the
sidecar's last commit), never authored. The release cites itself
(`release_citation()` → `catalog.json` `citation`/`concept_doi`/`doi`, the notes'
"How to cite", `.zenodo.json` + `CITATION.cff` from
`scripts/build_citation_files.R`); the Zenodo version DOI is written in by
`publish_release_notes()` after WS-F's tag. Findings, resolvers, the Zenodo flow and
what was measured are in the **`attribution` skill** — load it before touching a
`dataset_meta` citation/license key, `R/citation.R` or the release citation.

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

The core tables — `sample`, `obs`, `obs_attribute`, `sample_measurement` and the
supplemental `obs_ctd_full` — with their grains and the `append_*()` helper that
builds each are specified in `design_env-bio-consolidation.md` and calcofi4db's
`R/model.R` documentation.

### `obs_bio` + `obs_env` are the observation store; `obs` is a catalog view (D-S1, calcofi4db ≥ 3.31.0)

The ingests still `append_obs()` into `obs` — that is the assembly grain — but what the
**release publishes** is the bifurcated pair `release_database.qmd`'s `browser_objects` chunk cuts
from it (`build_obs_slim()`): `obs_bio` (one object, the bio realm with its sample's gear, effort
and the D8 densities inline) and `obs_env` (one object per `measurement_type`). Since 2026-09-03
each carries `sample_key`, `measurement_prec` and `hex_id` too, so it is a strict superset of
`obs` under a name mapping (`realm` = the table, `value` = `measurement_value`), both are **core**,
and `obs` is a **view** the catalog carries (`catalog.json` `views.obs`, the token SQL from
`calcofi4db::obs_view_sql()`; `release_views()` is the registry `build_release_catalog()` consults).
Rules that fell out:
- **The pair must reproduce `obs`, and the release proves it.** `check_obs_pair_parity()` compares
  per `(realm, dataset_key)` the row count, distinct `obs_id`s and a `bit_xor(hash(...))` signature
  of every non-depth column, and errors on any mismatch or on a non-NULL depth that changed.
  The one allowed difference is the depth *fallback* (a bio row with no depth in `obs` carries its
  tow's span; 482,250 ichthyo rows) — reported, never hidden.
- **`obs` still ships its own objects for one release, `deprecated`.** `cc_get_db()` (R, Python)
  and db-query's `__TBL:obs__` serve `obs` through the view whenever `obs_bio` + `obs_env` load,
  and read the deprecated objects only when they do not; `test_release.qmd` runs every `obs`
  contract row three ways (objects, view, pair). Next release drops the objects
  (`removed_in: "next"` — versions are dates, so the next one is not knowable at freeze time).
- **Do not rename `value`, `root_id` or `hex7`** on the pair: every Explorer SQL template reads
  them. New columns are appended; the view maps names, consumers never do.
- **A `{{table}}` token, never a path, in a catalog view.** Each resolver substitutes its own
  reader (`cc_view_sql(catalog, name, rp)` / `view_sql()` / `viewSql()`), so the same SQL serves a
  connection that has the tables and a browser that has only https objects.

Shared taxonomy refs — `taxon` (one row per taxon, `taxon_key` = `worms:<id>`, or
`itis:<id>` for birds/Aves), `dataset_taxon` (per-dataset vocabulary → `taxon_key`;
`obs` joins it on `(dataset_key, ds_taxa_code)`) and `taxon_group` — are built by
`calcofi4db/R/taxa.R`. The rules that are not negotiable, with their mechanics and
history in the **`taxon-reference` skill** (load it before touching taxon code in
an ingest, `R/taxa.R` or a taxon metadata CSV):
- Call `ensure_taxon_xref()` **then** `ensure_taxon_lineage()` **then** the
  builders. A key must be an *accepted* id; a cross-reference id is whatever the
  authority links. Skip either step and taxa ship with no ids, ranks or
  classification — silently.
- `clean_taxon_name()` output is the lookup query, **never** `ds_taxa_code`
  (rewriting the code orphans every `obs` row of that taxon).
- Stage `measurement_taxon.csv` with `ensure_measurement_taxon()`, never
  `dbWriteTable()`; `taxon_override.csv` rows match on their own `match_column`,
  and an unknown `dataset_key` there errors.
- Assert coverage **by rank position**, never blanket non-NULL (`family` is NULL
  above family rank; `kingdom` is NULL for `worms:1` Biota).
- `release_database.qmd`'s `taxon_authority_coverage` chunk: `check_taxon_ids()`
  **fails the release** on a dataset-local key outside its explicit allowlist —
  declare non-taxonomic classes one key at a time, never as a pattern.

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
| `category.csv` | **Registry of the twelve data categories** (`category, order, realm, icon, description`) — what an ingest's `calcofi.dataset_meta.category` and `measurement_type.category` must be one of (`build_workflows_index.R` errors on an unregistered one); the explorer's *Browse* tab, the schema site and the calcofi.io cards group by it, and `icon` is the brand sprite id (`calcofi.io/brand/v1/icons/`). Set a type's `category` / `variable` with `calcofi4db::declare_measurement_fields()`, never a bare `write_csv` (`scripts/declare_measurement_fields.R` seeds them). |
| `provider.csv` | **Registry of curating organizations** — one row per `provider` slug with `provider_short` (display label), `provider_name`, `url`, `status`. Any provider an ingest declares MUST be here: `scripts/build_workflows_index.R` errors out otherwise. Replaced a hardcoded label vector in that script, which silently yielded `NA` and published a literal `.na.character` heading for unregistered orgs. |
| `license.csv` | **Registry of dataset licenses** (`license, name, url, status, notes`): the SPDX-style ids an ingest's `calcofi.dataset_meta.license` may carry — `CC-BY-4.0`, `CC0-1.0`, `CC-BY-NC-4.0`, `CC-BY-SA-4.0`, `US-PD`, `custom` (needs `license_url`), `unknown`. Read with `calcofi4db::read_license_registry()`; `check_dataset_citation()` fails the index and the release on a value outside it (see § "Attribution is a contract"). |
| `{provider}/{dataset}/citation_authority.json` | **Generated cache** of what the source's own authority says (EDI / NCEI / ERDDAP / DataCite: `authority, url, citation, license, creator, title, checked, doi, doi_status`). Written by `check_dataset_citation()`; safe to delete (it refetches); `refresh = TRUE` refetches in place. A proposal, never the record — nothing copies it into the YAML. |
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

**Every ingest that emits measurements calls `calcofi4db::check_measurement_bounds()`
(≥ 3.10.0) on its `{dataset}_measurement` / `obs` and on every supplemental table it
publishes, and resolves every non-`ok` row before the notebook is done** — by
`declare_measurement_bounds()` (generous; one-sided is fine and usually right;
`register_measurement_types()` only appends and cannot set bounds) or by a
`proposed` provider question carrying the `finding`. Do not invent a bound to make
the check quiet, and never set one to the observed range: a bound describes what is
physically possible. Enforcement is the separate `drop_out_of_bounds()`, which
DELETEs. `release_database.qmd`'s `bounds_coverage` chunk is the backstop, not the
mechanism: `out_of_range` fails the release, `undeclared` is ratcheted by
`BOUNDS_UNDECLARED_MAX` (only ever down). The two findings, the resolution
procedure and the incidents behind these rules are in the **`measurement-bounds`
skill**.

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

Each active provider also gets a Google Sheet (`metadata/questions_sheets.yml`, one tab
per dataset, `Rscript scripts/sync_questions_sheets.R push|pull [provider] [--execute]`) —
the CSV stays the record and every column but `answer`/`status`/`answered_date`/`who` is
protected there, so `pull` only ever writes those four columns back into `questions.csv`.

### The ingest skills loop (`.claude/skills/`, see `RUNBOOK.md`)

```
/explore-dataset {path|url}  →  /generate-metadata {provider} {dataset}
   →  /ingest-new {provider} {dataset}  →  run the notebook
   →  /validate-ingest {provider} {dataset}  →  re-render release_database.qmd
```

Each skill updates the shared tracking artifacts above so the loop is
self-documenting; human review happens at every hand-off. Scaffolds come from
`.claude/skills/templates/`.

## Release tables are content-addressed (calcofi4db ≥ 3.22)

Every released parquet object lives once under
`gs://calcofi-db/ducklake/tables/{table}/{content_hash}/…`, and a release's
`catalog.json` lists its objects; `releases/{v}/parquet/…` is a real copy only for
promoted and consolidated versions (`metadata/release_policy.yml`). **Never build a
`releases/{v}/parquet/` path by hand** — go through `calcofi4r::cc_catalog()` /
`cc_release_sources()` / `cc_read_parquet_sql()`, `calcofi4py.release_sources()`, or
this repo's `libs/publish_netcdf.R` helpers. Stage a run without touching the real
prefix with `CALCOFI_RELEASE_PREFIX=ducklake-staging/releases`. Freeze planning,
byte determinism, `storage.calcofi.io` redirects and archive thinning
(`scripts/thin_releases.R`) are in the **`release-objects` skill** — load it before
cutting, staging or thinning a release.

## Bathymetry artefacts (`gs://calcofi-db/bathymetry/`)

Built by `scripts/build_bathymetry_tiles.py` from the local GEBCO 2025 sub-ice tile;
`gebco_2025.json` on the bucket describes every artefact and consumers read it,
nothing hard-codes what the build decided. Not release content. The build steps,
the two-archive terrain decision, the 1 m encoding, the crop extent and the
tippecanoe trap are in the **`bathymetry-tiles` skill** — load it before touching
tiles, the GEBCO crop or a map's terrain/contour layers.

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
