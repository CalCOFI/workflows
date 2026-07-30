# Generic `publish_to-netcdf.qmd` + `publish_to-erddap.qmd`, then close the ingest-skills gaps

Handoff from the 2026-07-30 session. Everything below is **remaining** work; the
context section records what already shipped so a fresh session does not redo it.

---

## Context — what shipped 2026-07-30 (do not redo)

**Release `v2026.07.30` is live and promoted** (`test_release.qmd` passed, so the
consumer contract holds).

Three CTD data fixes, all verified in the published release:

| fix | result |
|---|---|
| `-99` missing-value sentinel stripped from measurements | **0 remain** (was 3,983,321 rows across 35 of 54 types, incl. canonical oxygen) |
| `btl_ammonium` promoted to `is_canonical` | **67,385 values** now in thinned `obs` |
| `ctd_thin` retains bottle-trip depths (`retained_reason = 'bottle'`) | without it the flag change delivered only 26.7% |

netCDF regenerated and published, version-scoped (`v2026.07.17` untouched):
`ctd-cast.nc` 15→16 sensor vars, 434,312→465,428 obs levels; `ctd-cast_full.nc`
**32→54 variables** (the single-partition type-inference bug).

Also: `explore_ctd-cast.qmd` + `explore_ctd-cast2.qmd` published;
`questions.csv` backfilled for ctd-cast (11), ichthyo (5), bottle (6);
`metadata.json` for `v2026.07.30` patched after fixing the measurement-type
attribution cross product (calcofi4db 2.19.1). Email to Rasmus et al. **sent**.

::: note
**A parallel session is migrating `emit_core` projections into the ingest
notebooks** (commits `3f08912`, `184c0a0`, `e02933a`, `42a602b`, `eca7a4f`, …).
Check `git log` and coordinate before editing any `ingest_*.qmd` — especially
`measurement_type.csv` handling, which that session hardened across 9 ingests.
:::

---

## Task A — generic `publish_to-netcdf.qmd`

Replaces `publish_ctd-cast_to-netcdf.qmd` **and** `publish_ichthyo_to-netcdf.qmd`
with one dataset-agnostic notebook.

### Why this is now possible

`libs/publish_netcdf.R` justifies the per-dataset notebooks with *"the nesting
differs per dataset, which is why these are notebooks rather than one generic
script."* **That comment predates the consolidated core and is now false.** Every
ingest emits `sample` with `sample_type` + `parent_sample_key`, so the nesting is
*data* (an adjacency list), not code. Verified by reading the existing notebooks:

- `publish_ichthyo_to-netcdf.qmd` already derives `site`/`tow`/`net` from
  `sample_type`, effort from a `sample_measurement` pivot, bins from
  `obs_attribute` split by `measurement_type`, and `parent_index` from
  `match()` on the parent's ordered key vector — all generic patterns.
- `nc_level_vars()` / `nc_level_put()` in `libs/publish_netcdf.R` are **already
  generic**; ichthyo just unrolls the loop by hand, once per level.
- `ctd-cast` is the degenerate one-level case (flat CF profile).

### Groundwork already landed (tested)

**calcofi4db 2.19.1**, `R/netcdf.R` — 6 exported-function assertions + full suite
295 pass:

```r
discover_sample_levels(con, dataset_key)
#> tibble: sample_type, n, parent_sample_type, depth, n_orphan  (root-first)

plan_dataset_netcdf(con, dataset_key, obs_tbl = "obs")
#> list(shape = "profile" | "groups", feature_type, has_depth_axis,
#>      levels, measurement_types, attribute_types, effort_types)

summarise_netcdf_plan(plan)   # one row per dataset, for the notebook's plan table
```

Shape rule: one sampling level + a depth axis → CF profile
(`featureType=profile`, contiguous ragged array); more than one level → netCDF-4
groups with explicit `parent_index`. `measurement_types` is the union across the
whole dataset **deliberately** — sampling one partition is what shipped
`ctd-cast_full.nc` with 32 of 54 variables.

### Steps

1. **Move `nc_level_vars()` / `nc_level_put()` into calcofi4db** (`R/netcdf.R`),
   so the writer lives in the package per `CLAUDE.md` ("keep core logic in the
   package"). Add a testthat fixture per branch. Bump `DESCRIPTION` + `NEWS.md`
   in the same change.
2. **Write `publish_to-netcdf.qmd`**: loop datasets from the frozen release, call
   `plan_dataset_netcdf()`, branch on `plan$shape`, write, verify, publish. Render
   `summarise_netcdf_plan()` for every dataset as the up-front plan table.
3. **Per-dataset residue goes in the ingest YAML**, not the notebook: `title`,
   `summary`, `cf_scope`, an optional level-order override, and which
   `obs_attribute` types to split.
4. **Keep reading the frozen release.** `libs/publish_netcdf.R`'s comment is
   right that reading a serving tree is how the first netCDF shipped a month-old
   snapshot. A local-shard fast path is the fix for the 216M-row re-read cost —
   *not* moving the build into each ingest, which would re-distribute the bespoke
   code this task removes.
5. **Retire** both per-dataset notebooks and their `_targets.R` exclude entries.

---

## Task B — generic `publish_to-erddap.qmd`

**Higher value than Task A**: `publish_calcofi_to_erddap.qmd` is *already broken*
and *already prescribes this design*. Its own callout says every parquet path in
it points at per-dataset tables the ingests no longer publish, that it "will fail
until the config is repointed", and that:

> `sample` carries `time`/`latitude`/`longitude`/`depth_min_m`/`depth_max_m`
> directly … **one config row per `dataset_key` over `sample`/`obs` replaces the
> per-table list.**

So this is the fix it is waiting for, not a refactor of working code. It was left
unconverted deliberately because "repointing changes what is served to ERDDAP,
which is a decision for whoever owns that contract" — **confirm that decision
before changing what ERDDAP serves.**

Reuse `libs/erddap_duckdb.R` (`EDDTableFromDatabase` over DuckDB views) — that
combination is what fixed the whole-file heap OOM; see
`bench_erddap_ctd.qmd`.

---

## Task C — `finalize_ingest()` across the three legacy ingests

**Do this LAST.** It is the only remaining item that forces an ingest + release
cycle, so it should ride along with the next release rather than trigger one.

`ingest_swfsc_ichthyo.qmd`, `ingest_calcofi_bottle.qmd` and
`ingest_calcofi_ctd-cast.qmd` all hand-roll `write_parquet_outputs()` +
`build_metadata_json()` + `sync_to_gcs()` instead of calling
`calcofi4db::finalize_ingest()`. The user's stated preference is to generalize
rather than hand-roll.

**Verify before swapping**: ctd-cast's hand-rolled sequence carries three
behaviours that must survive —

1. content-hash dedup so unchanged partitions are not re-uploaded,
2. `_new` delta sidecars for tables named in `calcofi.modifies` (picked up by
   `build_release_table_registry()`, and *not* in the manifest),
3. skip-sync-if-unchanged.

If `finalize_ingest()` does not express all three, extend it (with tests) rather
than dropping the behaviour.

---

## Task D — remaining ingest-skills gaps

Per `.claude/skills/ingest-new.md`:

| gap | where |
|---|---|
| `check_data_integrity()` + `render_integrity_message()` missing | **ctd-cast only** (bottle + ichthyo have them) |
| `show_source_files()` missing | **ctd-cast only** |
| post-ingest `metadata.json` completeness scan (empty `description_md` / `units`) | **absent from every notebook in the repo** — `grep description_md *.qmd` returns nothing |

The completeness scan is the highest-value of the three: those empties ship
verbatim to the release `metadata.json` and on to `calcofi4r::cc_describe_table()`
/ `cc_db_catalog()`, and nothing currently surfaces them.

---

## Open data questions (need a human, not code)

`metadata/calcofi/ctd-cast/questions.csv` — 3 blockers:

- **Q02** — physically impossible sensor maxima survive the sentinel fix:
  `salinity_ave_corr` > 1000 PSU, oxygen ~1e9–1e10, `ph` up to 16.5. The ingest's
  new range audit **reports** these; it deliberately does not gate. Bad scans or a
  units error?
- **Q09** — the canonical CTD variables are *averages*
  (`temperature_ave`, `salinity_ave_corr`, `oxygen_ml_l_ave_sta_corr`) and carry
  **no quality flags at all**, because source flags attach to the component
  sensors (`Temp1Q`, `Salt1Q`, `Ox1Q`, `Ox2Q`). There is currently no way to tell
  whether a headline CTD value is trustworthy.
- **Q10** — the bottle↔sensor calibration pairs (`btl_temperature`,
  `salinity_btl`, `oxygen_btl_ml_l`) are `is_canonical = FALSE`, so sensor-vs-
  Winkler/Portosal validation is invisible in the default release. The promotion
  path now works correctly (see `retained_reason = 'bottle'`).

Once agreed, Q02's ranges belong in `metadata/measurement_type.csv` as
`valid_min`/`valid_max` — which would also let the CF writer emit them as real
`valid_min`/`valid_max` variable attributes.

---

## Gotchas learned the hard way (read before running anything)

1. **`cc_netcdf_publish()` does NOT write the browse pages.** It writes the
   payload, per-release `manifest.json`/`index.html`, `manifests.json` and
   `latest.txt`. The per-dataset and root listings come from
   `scripts/build_netcdf_index.R`, which **must be run after publishing**.
   Skipping it makes correctly-published files look unpublished.
2. **`overwrite <- FALSE` in `libs/ingest.R` is not safe as a global.** Every
   ingest sources that file. Setting it to let one dataset resume broke
   `ingest_cce-lter_euphausiids.qmd` in `[emit_core]`, whose resume path sets
   `eval = FALSE` on the chunks that build the tables `emit_core` then reads. The
   reason is recorded in the file; per-notebook resume needs a per-notebook
   mechanism (ctd-cast's `check_resume` chunk is the model).
3. **Never `sed s/message(/say(/g` blindly.** It silently rewrites
   `render_integrity_message(` → `render_integrity_say(`, which parses fine and
   fails at runtime deep into a long ingest. Check with
   `grep -nE '[A-Za-z0-9_.]say\('` — `say(` preceded by a word character is always
   damage.
4. **Don't restart the pipeline to "retry" a network step.** Three restarts inside
   ~40 min got us rate-limited by EDI (`pasta.lternet.edu` answered 200 at the
   host while the data object returned 403), and the failed write emptied the
   cache so there was no local fallback. Root cause was
   `if (overwrite || !file_exists(f))` re-downloading every run; now fixed to
   gate on file existence with `overwrite_all` as force-refresh. Source archives
   are recoverable from `gs://calcofi-files-public/archive/{provider}/{dataset}/`.
5. **A decorative chunk must not be able to fail a target.** The ctd-cast gantt
   appendix read a retired parquet and aborted the whole ingest *after* all
   outputs were written and synced. It is now `error: true`. Apply the same
   thinking to any new appendix.
6. **`data/flagged/*.csv` sidecars can be stale.** `validate_dataset()` writes
   them only when `n_flagged > 0` (`calcofi4db R/validate.R:291`), so a resolved
   condition leaves the old file sitting there looking current.
   `orphan_species.csv` (April) was read by two sessions as live data loss; the
   species were in fact resolved and present. **Check the mtime against the
   release before trusting one.**
7. **The CTD ingest loads the entire shared `measurement_type` registry** as a
   reference table, so its preview shows all 198 types across 14 datasets, not
   ctd-cast's 54 (16 canonical). This caused a real miscommunication with
   collaborators. Both numbers are now printed explicitly.

---

## Verification

- `devtools::test()` in calcofi4db — a fixture per new rule; red is a hard stop.
  Reinstall so notebooks pick up changes.
- `knitr::purl()` + `parse()` on every edited notebook before running the
  pipeline; a syntax error surfaces hours in otherwise.
- Confirm helper calls still resolve after any bulk rename (see gotcha 3).
- `Rscript -e 'targets::tar_make()'` → `release_database.qmd` must pass
  `core_parity` (shard conservation, key uniqueness, FK validity) and
  `test_release.qmd` must pass before `latest.txt` promotes.
- After any netCDF publish: run `scripts/build_netcdf_index.R`, then check
  `https://storage.calcofi.io/calcofi-files-public/netcdf/` shows the new version.
- After adding/removing a notebook: `Rscript scripts/build_workflows_index.R`
  (reads `_output`, so do not run it while the pipeline is writing there).
