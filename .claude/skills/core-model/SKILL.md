---
name: core-model
description: "The CalCOFI core data model — parquet shards (stage dir vs tracked JSON sidecars, the write_parquet_outputs/build_metadata_json/sync_to_gcs trio), the sample/obs/obs_attribute/sample_measurement family whose projection lives in each ingest notebook, obs_bio + obs_env as the store with obs a catalog view, namespaced keys, hex_id, key-suffix and identifier conventions, tidy long measurements, measurement_qual and cc_qual_ok_sql(), the climatology table. Load before editing an ingest's Emit Core Tables section, a release table's columns, or a consumer's SQL over obs."
---

# The core data model

> Moved verbatim out of `CLAUDE.md` on 2026-09-08 so the rules stay in every session's context and the mechanics and incidents behind them load only when needed. `CLAUDE.md` summarizes each rule and names this skill.

## Parquet shards → frozen release

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

## Consolidated core model (`obs` / `sample` / …)

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

## `obs_bio` + `obs_env` are the observation store; `obs` is a catalog view (D-S1, calcofi4db ≥ 3.31.0)

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


## Key and measurement conventions

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

## Quality flags reach consumers only if consumers apply them

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

## One climatology for every anomaly (`climatology`, calcofi4db ≥ 3.26.0)

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


