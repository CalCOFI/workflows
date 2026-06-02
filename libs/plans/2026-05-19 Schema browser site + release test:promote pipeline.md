# Plan: Schema browser site + release test/promote pipeline

## Context

Two related needs, planned together:

1. **Schema reference site** — `metadata.json` is now on GCS for every release (tables, columns, descriptions, units, datasets, measurement types). We need a UI that turns it into a useful reference: a zoom/pan ERD, sortable tables/columns, dataset citations, with a dropdown to view past releases. This will inform pre-baked queries in the query app and any custom queries users build. Per user direction it lives at its own site, `github.com/CalCOFI/schema` → `calcofi.io/schema` (repo already cloned to `/Users/bbest/Github/CalCOFI/schema`, currently empty besides LICENSE).

2. **Release promotion loop** — today `release_database.qmd` unconditionally pushes `latest.txt` to GCS on every render, and the query app's `default_version` is manually edited in `_config.yml`. The user wants: run `_targets.R` → test the pre-baked queries against the new release → only then promote (`latest.txt` + bump query app's `_config.yml` via GH Action). The schema site needs no version pinning (it always reads `latest.txt` and offers the dropdown), but the query app does.

Plus a small enhancement: make the query app's left sidebar collapsible.

## Overview of changes

| # | Repo | Change |
|---|------|--------|
| 1 | `workflows` (`release_database.qmd`) | Emit `erd.mmd` sidecar via `cc_erd()`; add `data_type` to `metadata.json` columns; stop unconditionally writing `latest.txt` |
| 2 | `workflows` (new `test_release.qmd`) | Run every `_queries/*.md` against the new release; produce HTML report; on green, push `latest.txt` |
| 3 | `workflows` (`_targets.R`) | Add `test_release` target after `release_database`, dependency ordered |
| 4 | `schema` (new repo) | Jekyll site: ERD (Mermaid + svg-pan-zoom), Tables, Columns, Datasets, Measurement types, version dropdown, release-notes panel |
| 5 | `query` (new GH Action) | Poll GCS `latest.txt`; if differs from `_config.yml:default_version`, open PR (or commit) bumping it; existing `pages.yml` redeploys |
| 6 | `query` (existing) | Collapsible left sidebar (toggle button + CSS state + localStorage) |

---

## Part 1 — Workflows: emit ERD sidecar & data types; stop pushing latest.txt

**File: `/Users/bbest/Github/CalCOFI/workflows/release_database.qmd`**

In the chunk that builds `metadata.json` (≈ lines 719–742):

- Extend the per-column dict to include `data_type` (from `information_schema.columns` joined on `table_name`, `column_name`). Keeps the JSON self-contained so the schema site doesn't need DuckDB-WASM.
- Optionally also fold `row_count` per table from `catalog.json` so the schema site fetches one file instead of two. Pragmatic call: keep them separate (single-responsibility) and have the schema site fetch both.

Add a new chunk (right after `metadata.json` is built and uploaded) that emits the ERD:

```r
# erd_mmd_sidecar ----
library(calcofi4r)
erd <- cc_erd(
  con       = con_wdl,
  rels_path = path_relationships_json,
  view      = "all")          # full ERD with PK/FK annotations
mmd_path <- file.path(release_dir, "erd.mmd")
writeLines(as.character(erd), mmd_path)
put_gcs_file(mmd_path, gcs_release_url("erd.mmd"))
```

Source: `cc_erd()` is at `/Users/bbest/Github/CalCOFI/calcofi4r/R/erd.R:92` — already produces Mermaid syntax keyed by `relationships.json`, so no new R code is needed beyond this wrapper.

**Remove the unconditional `latest.txt` push** (currently at `release_database.qmd:775–778`). It moves into `test_release.qmd` (Part 2), gated on tests.

---

## Part 2 — Workflows: query test harness as a Quarto notebook

**New file: `/Users/bbest/Github/CalCOFI/workflows/test_release.qmd`**

Renders into `_output/test_release.html` (same pattern as the other notebooks). The notebook is its own validation artifact and lives in `_targets.R` as the "promote gate" — it runs after `release_database.qmd` and is what writes `latest.txt`.

Outline:

1. **Setup**: load just-built release version; attach DuckDB to GCS parquet for that version (or to the local pre-upload DuckDB if simpler — single-file `data/calcofi_wrangling.duckdb` already exists in the worktree).
2. **Discover queries**: enumerate `/Users/bbest/Github/CalCOFI/query/_queries/**/*.md`. Path is a sibling clone today; for CI we'd `git clone --depth=1 CalCOFI/query` into a tmp dir. Each `.md` has YAML front-matter + a Handlebars-templated SQL body (per the query-app architecture). For parameterized queries, use the front-matter `default` for each parameter as the test input (the same defaults the form populates with).
3. **Execute**: for each query, render the SQL via a minimal Handlebars-in-R substitution (or `glue()` if the templating is simple enough — verify by inspection during implementation), run it through DuckDB, capture: pass/fail, rowcount, elapsed ms, error message.
4. **Report**: render a sortable table of results with a green/red badge per query. Save the same data as `test_results.json` and upload alongside the release.
5. **Promote (gated)**: if every test passes, write `latest.txt` with the new version and upload to GCS. Otherwise stop and print the failures.

Notes / open implementation calls:

- *Handlebars in R*: the query app uses Handlebars at runtime. For tests, we don't need the full Handlebars expression set — most pre-baked queries use simple `{{var}}` substitution. A `gsub()` shim should cover the current set; if a query uses `{{#if}}` or helpers, mark it as untestable and skip rather than miswriting the SQL.
- *Database target*: simplest is to point DuckDB at the local file (`data/calcofi_wrangling.duckdb`) which contains the just-frozen tables, rather than re-downloading parquet from GCS. Faster, and tests the bytes that were just uploaded.
- *Spatial/geometry queries*: any `_queries/` SQL that needs the spatial extension must `INSTALL spatial; LOAD spatial;` first — mirror what the query app does in `lib/duckdb.js`.

---

## Part 3 — Workflows: extend `_targets.R`

**File: `/Users/bbest/Github/CalCOFI/workflows/_targets.R`**

`_targets.R:15–20` calls `build_targets_list()` from `calcofi4db`. Two options:

- **A. Extend `build_targets_list()`** in `calcofi4db` to recognize a new `type = "test"` and add `test_release.qmd` to the recipe. Cleanest long-term.
- **B. Hand-append a target** in `_targets.R` after `build_targets_list()` returns. Less invasive, faster to implement, easy to refactor into (A) later.

Recommend **B** for now (matches the user's "I am unclear how to proceed" framing — keep the change small and visible in this repo). Skeleton:

```r
targets <- build_targets_list(...)
test_release_tar <- tar_quarto(
  name      = test_release,
  path      = "test_release.qmd",
  cue       = tar_cue(mode = "always"),  # always run if release_database changed
  packages  = c("calcofi4db","calcofi4r","duckdb","DBI","glue","DT"))
list(targets, test_release_tar)
```

`tarchetypes::tar_quarto` already drives the existing notebooks; the `release_database` target's output is implicitly upstream because `test_release.qmd` reads `data/calcofi_wrangling.duckdb` (or the freshly-uploaded GCS files).

---

## Part 4 — New schema site at `/Users/bbest/Github/CalCOFI/schema`

Live URL: `calcofi.io/schema` (GH Pages on `CalCOFI/schema`).

**Stack**: Jekyll (mirrors the query app for shared layout muscle memory) + vanilla ES6 + Mermaid.js + `svg-pan-zoom` + `marked` for `description_md`. No DuckDB-WASM needed — everything is metadata.

**Structure**:

```
schema/
├── _config.yml                # title, GCS base URL, cdnjs versions
├── _layouts/default.html      # header + version dropdown + main; copy-and-trim from query/_layouts/default.html
├── _includes/
│   ├── version-picker.html    # <select>; populated from versions.json
│   └── release-meta.html      # release_date, notes link
├── lib/
│   ├── metadata.js            # fetch metadata.json, erd.mmd, relationships.json, catalog.json, RELEASE_NOTES.md for a chosen version (sessionStorage cache by version)
│   ├── render-erd.js          # mermaid.initialize + svg-pan-zoom; "click table → highlight FKs in list" optional v2
│   ├── render-tables.js       # sortable table; row click expands columns subtable
│   ├── render-columns.js      # flat columns view (sortable, filter input), grouped-by-table toggle
│   ├── render-datasets.js     # cards: provider · dataset · coverage_temporal/spatial · citation_main · links
│   └── render-measurements.js # measurement_type list with is_canonical badge + units
├── assets/style.css           # reuse query app palette / typography; copy logo SVGs
├── index.html                 # tabbed shell: ERD | Tables | Columns | Datasets | Measurement types
├── app.js                     # router (#erd, #tables, ...) + version dropdown change handler
└── README.md
```

**GCS files fetched per version**:

| File | Provides |
|------|----------|
| `metadata.json` | tables, columns, datasets, measurement_types (+ `data_type` added in Part 1) |
| `erd.mmd` | Mermaid string for ERD view (new in Part 1) |
| `relationships.json` | FK list (used for "click table → see relations") |
| `catalog.json` | row counts, file sizes per table |
| `RELEASE_NOTES.md` | shown in collapsible panel under version picker |
| `versions.json` | populates dropdown (all known versions + `is_latest`) |

**Routing**: `index.html#erd?v=v2026.05.14` style. Default view = `#erd`, default version = whatever `versions.json.is_latest` says (mirrors how `calcofi4r::cc_get_db("latest")` resolves).

**Reuse hooks from the query app** (copy, don't depend on):
- Header layout + theme toggle: `query/_layouts/default.html:28–47`
- Sortable table helper: `query/app.js:193–220` (Arrow-aware — strip Arrow specifics, keep DOM sort)
- Subtabs styling: `query/_includes/result-panel.html:2–6` + `style.css:313–340`

**Dropdown behaviour**: shows version + `release_date`; tooltip with first-line of RELEASE_NOTES.md. Changing the dropdown re-fetches the per-version files, re-renders the active tab, and updates the URL hash.

---

## Part 5 — Query repo: GH Action to bump `default_version`

**New file: `/Users/bbest/Github/CalCOFI/query/.github/workflows/bump-default-version.yml`**

Triggers:
- `schedule: cron '0 */6 * * *'` (4× daily — cheap, low-latency enough)
- `workflow_dispatch:` (manual nudge)

Job (concise; not the final YAML):
1. Checkout `main`.
2. `curl -fsSL https://storage.googleapis.com/calcofi-db/ducklake/releases/latest.txt > /tmp/latest`
3. Read current `default_version:` from `_config.yml:50`.
4. If same → exit 0.
5. If different → `sed -i` the line, commit ("Bump default_version to vYYYY.MM.DD"), push to `main`. The existing `pages.yml` (push trigger) rebuilds & redeploys.

Alternative: open a PR rather than direct push. **Direct push is fine** — the GH Action only runs if `latest.txt` already changed, and `latest.txt` is only written by `test_release.qmd` after every query passes. The human review happened at the test-results report. PR adds friction without adding safety here.

**Schema site does NOT need this Action** — it reads `versions.json` / `latest.txt` at runtime, so it auto-tracks new releases as soon as `latest.txt` flips.

---

## Part 6 — Query app: collapsible sidebar

**Files**:
- `/Users/bbest/Github/CalCOFI/query/_layouts/default.html` — add a toggle button (e.g., between `.app-logo` and `<h1>` at line 39, or as a floating tab on the edge of `<aside id="nav">`)
- `/Users/bbest/Github/CalCOFI/query/style.css` — add `#layout[data-nav-collapsed="true"] #nav { display: none }` (or transform to a thin rail with icons; full hide is the lowest-effort first cut)
- `/Users/bbest/Github/CalCOFI/query/app.js` — toggle handler, persist via `localStorage.getItem("nav-collapsed")`, mirror the existing theme-toggle pattern

Lowest-friction approach: just hide/show the `<aside>`. The `<main>` already grows naturally. Save state to localStorage so it persists across reloads, same as the theme toggle.

---

## Critical files to read / modify

**Read first to confirm details before editing:**
- `/Users/bbest/Github/CalCOFI/workflows/release_database.qmd` (lines 91, 631–782 — release_version, GCS upload, latest.txt push)
- `/Users/bbest/Github/CalCOFI/calcofi4r/R/erd.R:92–259` — `cc_erd()` signature
- `/Users/bbest/Github/CalCOFI/calcofi4r/R/database.R:958–1052` — `cc_db_catalog()` shape (reference for columns view)
- `/Users/bbest/Github/CalCOFI/query/_queries/` — every `.md` to understand front-matter shape for the test harness
- `/Users/bbest/Github/CalCOFI/query/lib/duckdb.js` — how the app loads the spatial extension (mirror in tests)

**Modify:**
- `workflows/release_database.qmd` — add `data_type` to columns, add `erd.mmd` sidecar chunk, remove unconditional `latest.txt` push
- `workflows/test_release.qmd` — **new**
- `workflows/_targets.R` — append `tar_quarto(test_release, ...)`
- `schema/*` — **new repo** (Jekyll site, files listed in Part 4)
- `query/.github/workflows/bump-default-version.yml` — **new**
- `query/_layouts/default.html`, `query/style.css`, `query/app.js` — sidebar collapse

---

## Verification (end-to-end)

1. **Local release dry-run** (workflows repo):
   - `targets::tar_make()` → runs ingests → `release_database.qmd` → `test_release.qmd`.
   - Confirm: `data/releases/v2026.MM.DD/erd.mmd` exists locally; `metadata.json` has `data_type` per column.
   - Confirm: `test_release.html` lists every `_queries/*.md` with pass/fail + timing.
   - Confirm (intentional failure): introduce a typo in one `_queries/*.md`, re-render — `latest.txt` is NOT pushed; report shows the failure.
   - Confirm (happy path): with all green, GCS now has `latest.txt` pointing at the new version.

2. **Schema site smoke** (schema repo, local):
   - `bundle exec jekyll serve` → open `localhost:4000/schema/`.
   - Default view shows ERD via Mermaid with pan/zoom working.
   - Version dropdown lists every release; switching re-fetches and re-renders.
   - Tables view: click a table → expands to columns with type/units/description.
   - Datasets view: each card has citation + links + coverage.

3. **Query app bump** (query repo):
   - Trigger `bump-default-version.yml` via `workflow_dispatch`.
   - Confirm: a commit lands on `main` updating `_config.yml:50` to the new `default_version`; `pages.yml` rebuilds.
   - Confirm: sidebar toggle hides/shows the nav and survives reload.

4. **Cross-site sanity**:
   - From the query app, the release link in the header points at the new `RELEASE_NOTES.md`.
   - From the schema site, "Open in query app" link (small nicety to add) jumps to query app at the same version.
