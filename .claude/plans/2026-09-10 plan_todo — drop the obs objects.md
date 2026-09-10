# plan_todo — drop the `obs` objects: every consumer on `obs_bio` + `obs_env` before the next release

Status: **todo, written 2026-09-10.** The release running today (the relaunched staging cut after
v2026.09.06) ships the `obs` objects for the last time; RELEASES.md says so. The release after it
drops them. Nothing below runs until that release is being prepared; every item is a precondition
of cutting it.

## Why, in numbers (catalog of v2026.09.06)

| what | objects | bytes |
|---|---:|---:|
| `obs` (deprecated: 16 hive partitions by `dataset_key` + the single-file `obs.parquet` twin) | 16 | 401 MB |
| `obs_bio` (one file) | 1 | 25 MB |
| `obs_env` (hive by `measurement_type`) | 84 | 317 MB |

The same 26 M rows ship twice. `obs` changes every release (every ingest touches it), so
content-addressing saves nothing on it: ~400 MB per cut, and the catalog, the dataset pages and
the ERD all show a table the docs call deprecated. Dropping it halves the observation bytes and
leaves one story: **`obs_bio` + `obs_env` are the tables; `obs` is a view.**

## Two decisions this settles

- **Keep the hive partitioning of `obs_env` by `measurement_type`.** It is not about globbing. Every
  browser reader — the Explorer (`explore/src/release.ts`), db-query (`lib/release.js`), the two
  static apps' `resolve_release.py` — takes the object list from `catalog.json` `objects[]` and
  passes an explicit URL list to `read_parquet([...], hive_partitioning = true)`; nothing expands a
  glob over GCS. The partition is what lets a browser fetch one variable (one ≤ 10 MB object) instead
  of 317 MB, and DuckDB prunes the list by the hive column before opening a file. The glob limitation
  is real for a *plain* HTTPS reader without a catalog, and the answer for that reader is the
  catalog, not a duplicate file.
- **Drop the single-file twin with the table.** `obs.parquet` existed for readers that could not
  take a list. Every reader we ship reads the catalog now; the twin's remaining callers are listed
  below and each has a better source (`obs_env`, `obs_bio` or the view).

## The consumers, measured 2026-09-10

`mechanism` is how the reader reaches `obs` today; `after the drop` is what happens with no change.
Owner is who lands the fix. **Verify** is the check that closes the row.

| # | repo · reader | mechanism today | after the drop | change | owner | verify |
|---|---|---|---|---|---|---|
| 1 | **calcofi4r** `cc_get_db()` (`R/database.R` 193–216) | serves `obs` as the catalog view when the pair loads (`served_by_view`) | works | none | — | `cc_get_db()`; `tbl(con, "obs")` counts equal the pair |
| 2 | **calcofi4r** `R/match.R` 221, 275 (`cc_match_bio_env()` env + bio SQL) | reads the **single-file `obs.parquet` twin** via `prefer_single_file = TRUE` | **breaks** (no twin) | env SQL over `obs_env` (its `value`, `qual_ok`), bio SQL over `obs_bio`; the `bio-env-matching` vignette re-knits; `cc_release_sources(cat, "obs")` already errors for a view (test line 77 pins it) — remove the `prefer_single_file` path once no table has a twin | Ben | `devtools::test()`; vignette renders against the staged release |
| 3 | **calcofi4r** `tests/testthat/test-release-sources.R` 14, 64, 84, 93 | fixtures with an `obs` table + twin | tests still pass (fixtures are synthetic) | keep the legacy-catalog fixture (pre-v2026.09 releases exist); retire the twin expectation | Ben | tests green |
| 4 | **calcofi4py** `cc_get_db()` (`release.py` `_register_catalog`) | view when the pair loads; deprecated objects only when they are not | works | none | — | `con.sql("SELECT count(*) FROM obs")` |
| 5 | **calcofi4py** `release_sources(cat, "obs")` + `single_file` legacy branch; `tests/test_release_sources.py` 27–58 | resolves the table's objects / twin | `release_sources(cat, "obs")` errors (view) — only tests call it | retire the twin assertions; keep the legacy-catalog case | Ben | `pytest` |
| 6 | **db-query** `lib/release.js` `readParquetForCatalog` | expands `__TBL:obs__` to the view's SQL over the pair's objects | works | none required; **better:** the six templates (`_queries/quick-facts/release.md` 15–18, `datasets/bottle.md` 38, `datasets/ichthyo.md` 38, `bio-env-matching/custom.md` 21, 45) and `lib/match.js` `.cc_env_sql` mirror read `__TBL:obs_env__` / `__TBL:obs_bio__` directly so a bottle query opens one variable's object, not 85 | Ben | `npm test`; each query page answers on the staged release |
| 7 | **db-query** `test/release.test.js` 45–77 | pins the `obs` twin as `singleFile` | tests still pass (synthetic) | retire the twin test with the twin | Ben | `npm test` |
| 8 | **Explorer** `src/release.ts`, `sql/*.sql` | reads `obs_bio` / `obs_env` objects by name; `release.ts` 61 only *recognises* a twin | works | none (the `single` branch becomes dead code; delete it) | Ben | `scripts/smoke_release.mjs` on the staged release |
| 9 | **ctd-transects** `scripts/build_sections.sql` 111, `climatology_fallback.sql` 23 via `scripts/resolve_release.py` | `__TBL:obs__` → the table's objects; the resolver has **no view support** | **breaks** ("table 'obs' is not in the catalog") | read `__TBL:obs_env__` (the resolver already supports partition tokens: `__TBL:obs_env:measurement_type=temperature_ave__`, one object per variable) and rename `measurement_value` → `value`; delete `climatology_fallback.sql` + its `FALLBACKS` entry (every release the app can point at ships `climatology`); fold into PR #3 (merges after today's release) | Ben | `python3 scripts/resolve_release.py && duckdb < build/build_sections.sql`; shard count unchanged |
| 10 | **db-viz-station** `scripts/build_stations.sql` 70, `build_stations_local.sql` 91, `build_depth_profiles.sql` 51, `build_regions.sql` 70 via the same `resolve_release.py`; `test_resolve_release.py` pins the twin | `__TBL:obs__` → objects | **breaks** | give `resolve_release.py` view expansion (port of db-query `readParquetForCatalog`: `__TBL:<view>__` → the view SQL with its `{{table}}` tokens resolved, parenthesised) so `FROM __TBL:obs__ o` stands; ctd-transects gets the same file; then move the heavy reads to the pair at leisure | Betty (with Ben on the resolver) | `python3 -m pytest scripts/`; `refresh.yml` green on the staged release |
| 11 | **db-viz-hex** `app/functions.R` 4155, 4209 `FROM {rp('obs')} o` (`release_read_parquet()` → `cc_release_sources(cat_, "obs")`) | resolves the `obs` table's objects at query time | **breaks** (`cc_release_sources()` errors on a view) | 4155/4209 read `obs_env` / `obs_bio` per realm (they already filter by `dataset_key`/type), or `rp` expands views via `cc_view_sql()`; `prep_db.R` is fine (`cc_get_db()`) | Ben | app boots against the staged release; the two queries return |
| 12 | **apps/ctd-viz** `prep_db.R` 168–222, **apps/ctd-qaqc** `prep_db.R` 78 | `cc_get_db()` → view | works | none | — | `Rscript prep_db.R` on the staged release |
| 13 | **apps/db-viz-cruise** | its `obs` is app-local, built from `sample` | works | none | — | — |
| 14 | **workflows** `publish_to-netcdf.qmd` 143–160 (`PQ('obs')` single file; `cc_release_partitions("obs")` keyed by `dataset_key`) + `libs/publish_netcdf.R` 103–122 | the twin + the `dataset_key` partitions | **breaks**, and not mechanically: `obs_env` is partitioned by `measurement_type`, not `dataset_key` | planning table from the pair (`obs_bio` whole + `obs_env` all objects, projected to the four columns — 342 MB once, cached); per-dataset extraction reads `obs_bio` filtered (bio datasets) or `obs_env` filtered by `dataset_key` (env datasets); `cc_release_partitions()` keeps working for `obs_ctd_full`; the `single_file` helper's error text updated | Ben | `quarto render publish_to-netcdf.qmd` against the staged release regenerates nothing (idempotent) and the manifest lists every dataset |
| 15 | **workflows** `test_release.qmd` 365–380, 569 | contract rows run twice — `rp('obs')` (objects) and `rpv('obs')` (view) — "until the objects are dropped"; `rp1` reads the twin | `rp('obs')` errors | keep only the view rows; drop `rp1`; add the assertion that `obs` is **not** in `catalog$tables` and `views.obs` is | Ben | `test_release.qmd` 0 fail on the staged release |
| 16 | **workflows** `release_database.qmd` 1533 (`core_keep`), 2104–2112 + 2138–2141 (the twin export), 1768 (`check_obs_pair_parity()` — keeps reading the in-memory `obs`, fine), `metadata/release_tables.csv` (`obs` row) | exports `obs` | — | remove `"obs"` from `core_keep`; delete the twin branches; keep the parity gate; `release_tables.csv` `obs` row → described as a view (or removed if the schema browser reads it as a table); `calcofi4db::release_views(removed_in = "<this version>")` so the catalog states the fact, not "next" | Ben | catalog: no `obs` in `tables[]`, `views.obs` present; `integrity.json` skips `obs` keys; `verify_release_objects.R` 0 problems |
| 17 | **calcofi4db** `core_relationships()` (`obs` PK/edges), `check_release_relationships()` | `obs` edges declared | skipped (table not released) — intended | nothing; the ERD loses the `obs` box, gains none (the pair is already drawn) | — | `relationships.json` has no `obs` edge |
| 18 | **server** `postgis/init/50_release_views.sql` 7 (comment), `caddy/releases_redirects.caddy` | the comment points at `read_parquet()` over the hive partitions; the redirect serves `releases/{v}/parquet/obs/` compat paths | the compat path for the new release has nothing to redirect to | comment → the pair; redirects stay for old versions | Ben | `curl -I` an old `parquet/obs.parquet` URL still 302s |
| 19 | **CalCOFI.github.io** `_plugins/datasets.rb` 1066 (`TABLE_ABOUT["obs"]`) | describes `obs` when a dataset's objects include it | rows vanish from *Get the data*; the description is dead | leave the description (harmless) or drop it; check the "DuckDB, anywhere" snippet picks `obs_bio`/`obs_env` as the first object | Betty (#12 review) | dataset page renders; access table lists the pair |
| 20 | **docs** `data-access.qmd` 96–98, `db.qmd` 38, 55–72, `cite.qmd` 131 (`tbl(con, "obs")` via the view — fine) | say "deprecated, drop in the next" | stale wording | name the release that dropped them; keep the view explanation | Ben | book renders; `check_layout` |
| 21 | **ERDDAP** (`publish_to-erddap.qmd` `HAS_OBS_PAIR`; `erddap` repo 0 hits; `scripts/render_release_views.R` 0 hits) | the pair | works | none | — | `allDatasets` unchanged |
| 22 | **analytics, api-h3t-py, uptime** | 0 hits | works | none | — | — |

Rows 2, 9, 10, 11, 14, 15, 16 are the ones that break; 6 and 8 are cleanups; the rest are checks.

## Sequence

1. **Consumers first, release last.** Land 2, 5, 6, 9 (in PR #3), 10, 11, 14, 15 against the release
   running today (its pair is complete and its `obs` still ships, so every fix can be tested before
   the objects go). Each is its own commit/PR; nothing waits on another except 10 → 9 (shared
   resolver file).
2. **Then 16** (`release_database.qmd` + `release_tables.csv` + `RELEASES.md # Unreleased`: "the
   `obs` objects are gone; `obs` is the view; readers …").
3. **Staging cut** with both staging prefixes; `test_release.qmd` green with the new assertion
   (row 15); `smoke_release.mjs`; db-query pages; the two static apps' refresh workflows pointed at
   the staging version; db-viz-hex booted against it.
4. **Promote**; `deploy_consumers.sh`; docs (row 20) in the same day.

## Not in scope

- Renaming `value` back to `measurement_value` or otherwise touching the pair's columns (CLAUDE.md:
  append, never rename).
- `obs_ctd_full` / `obs_mets_full`: supplementals at another grain, not duplicates.
- Backfilling older releases: their `obs` objects stay where they are (immutable, and pre-v2026.09
  anonymous DuckDB globs read them — memory `gcs-public-list-is-load-bearing`).

## Board

Tracked as CalCOFI/workflows issue "Drop the obs objects (next release)": Owner Ben, Area release,
Size L, with this file as the checklist; rows 10 and 19 cross-linked to Betty's issues.
