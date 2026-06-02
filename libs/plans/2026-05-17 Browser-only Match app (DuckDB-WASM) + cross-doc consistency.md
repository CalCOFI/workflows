# Browser-only Match app (DuckDB-WASM) + cross-doc consistency

## Context

The three CalCOFI pages [`docs/data-access.qmd`](../../Github/CalCOFI/docs/data-access.qmd), [`docs/helpers.qmd`](../../Github/CalCOFI/docs/helpers.qmd) and [`calcofi4r/vignettes/bio-env-matching.Rmd`](../../Github/CalCOFI/calcofi4r/vignettes/bio-env-matching.Rmd) all promise the new paradigm — *query 22 GB of CalCOFI Parquet from anywhere, including a web browser, via DuckDB-WASM* — but the only "from a browser" instruction is **paste your SQL into [shell.duckdb.org](https://shell.duckdb.org)**. That's a generic third-party shell with zero CalCOFI context: no example wired up, no form for the three retired Plumber endpoints, nothing to click "Run" on.

This plan delivers what was promised:

1. **A standalone, JavaScript-only "Match" app at `docs/match/`** — a client-side mirror of the retired Plumber API's three bio↔env endpoints (`zooplankton_biomass`, `itis_ichthyodata`, `ichthyodata`), implemented as a tabbed form whose **Run** button executes against the public CalCOFI release Parquet in DuckDB-WASM **right in the user's browser** — no server, no install, no R, no Python.
2. **A `match.js` ES module** that ports the SQL builders from `calcofi4r/R/match.R` to JavaScript. The emitted SQL is **character-identical** to `attr(cc_match_*(...), "sql")` from R, so the page, the package, and the [Integrated App](https://app.calcofi.io/int) download bundle remain a single source of truth.
3. **Consistency edits** to the three referenced docs so the "Run it from anywhere" story is told the same way each time and each page links to the new Match app.

User-locked decisions: **standalone HTML app at `docs/match/`** (not a Quarto chapter, not Observable JS). **Five tabs** in the UI: the 3 wrappers + a `cc_match_bio_env` custom-SQL tab + a free-form DuckDB shell.

---

## Part 1 — `docs/match/` standalone app

Four files, deployed alongside the Quarto book under `docs/_book/match/` (Quarto copies the `match/` resource directory into the rendered book at build time).

| File | What it does |
|---|---|
| `docs/match/index.html` | Page shell + raw HTML form/result panels. Loads `app.js` as an ES module. Title `"CalCOFI Match — query 75 years of ocean data in your browser"`. |
| `docs/match/match.js` | Pure-JS port of [`calcofi4r/R/match.R`](../../Github/CalCOFI/calcofi4r/R/match.R) — only the SQL-builder side, no I/O. Exports `parquetBase`, `buildEnvSQL`, `buildBioSQLIchthyo`, `buildMatchSQL`, `matchIchthyoByName`, `matchIchthyoByTaxon`, `matchZooplanktonBiomass`, `extractSourceUrls`. Each "match*" function returns `{ sql, queryMeta }`. |
| `docs/match/app.js` | UI/runtime: lazy-init the DuckDB-WASM bundle, tab switcher, dynamic form rendering, `Run` handler, result table, "Show SQL" / "Metadata" panels, "Download CSV", "Copy SQL". |
| `docs/match/style.css` | Light, accessible styling — system-font stack, tabs, table with sticky header, status pill. Matches the docs book's `cosmo` Bootswatch palette so it doesn't look orphaned. |

### 1.1 DuckDB-WASM wiring (in `app.js`)

```js
import * as duckdb from "https://cdn.jsdelivr.net/npm/@duckdb/duckdb-wasm@1.29.0/+esm";

let _db, _conn;
async function getConn() {
  if (_conn) return _conn;
  const bundles = duckdb.getJsDelivrBundles();
  const bundle  = await duckdb.selectBundle(bundles);   // picks SIMD/MVP per browser
  const worker  = await duckdb.createWorker(bundle.mainWorker);
  _db = new duckdb.AsyncDuckDB(new duckdb.ConsoleLogger(), worker);
  await _db.instantiate(bundle.mainModule, bundle.pthreadWorker);
  _conn = await _db.connect();
  await _conn.query("INSTALL httpfs; LOAD httpfs;");
  await _conn.query("INSTALL spatial; LOAD spatial;");
  return _conn;
}
```

Initialization runs lazily on first **Run** click (cold start ≈ 3–6 s; cached afterwards). A status pill at the top shows `"Initializing DuckDB-WASM…"` → `"Running query…"` → `"Done: 13 rows in 18.7 s"`.

Results come back as Apache Arrow tables; convert to JS rows via `arrowResult.toArray()` and render into a sticky-header `<table>`, with a 100-row page size + page nav.

### 1.2 Tabs in the UI

Five tabs, switched by `<button role="tab">`s. Each tab owns a `<form>` whose submit handler builds `{sql, queryMeta}` and runs it.

| Tab | UI form fields → call |
|---|---|
| **by name** *(default)* | `scientific_name` (text, default `"Sardinops sagax"`), `env_var` (`<select>` populated on init from `measurement_type.parquet`, default `temperature`), `exact_match` (checkbox), `life_stage` (radio: *any* / *egg* / *larva*, default *larva*), `date_min` / `date_max` (date inputs, default `2018-01-01` / `2018-03-31`), `depth_m_min` / `depth_m_max` (numeric, optional), `relax_matching` (checkbox, default checked → 5 km / 72 hr; un-checks reveal `max_dist_km` + `max_time_hr` numeric inputs), `join_method` (radio: *nearest_time* / *nearest_dist* / *average*), `version` (text, default `v2026.05.14`) → `matchIchthyoByName(args)` |
| **by taxon** | `worms_id` (number, default `125724` = genus *Engraulis*) + same rest → `matchIchthyoByTaxon(args)` |
| **zoo biomass** | `biomass_type` (radio: *totalplankton* / *smallplankton*) + tolerances + dates + version → `matchZooplanktonBiomass(args)` |
| **custom** | `bio` (textarea, pre-populated with the worked-example bio CTE) + `env` (textarea, pre-populated with the worked-example env CTE) + tolerances + `join_method` + `version` → `matchBioEnv({bio, env, ...})` |
| **shell** | `sql` (textarea, with a "Load example" button that fills in `SELECT scientific_name, common_name, worms_id FROM read_parquet('https://.../v2026.05.14/parquet/species.parquet') WHERE common_name ILIKE '%sardine%'`) → runs raw SQL directly |

### 1.3 Result panel

Three sub-tabs:
- **Results** — paginated `<table>` (100 rows/page) of the query result; click column headers to sort; sticky header.
- **SQL** — `<pre><code>` block of the exact interpolated query, prefixed with the `INSTALL`/`LOAD` setup so it is copy-paste runnable elsewhere. **Copy** + **Download `.sql`** buttons.
- **Metadata** — pretty-printed `queryMeta`: package version (the `match.js` module version, e.g. `0.1.0`), release version, params, all `read_parquet()` source URLs (extracted via `extractSourceUrls()`), `n_rows`, `generated_at`. Identical shape to R's `attr(d, "query_meta")`.

Plus a **Download CSV** button rendering all result rows to CSV via a `Blob` + `URL.createObjectURL`.

### 1.4 Pre-populated default → instant gratification

On page load, the **by name** tab's form is pre-filled with the recurring worked example. Click Run → DuckDB-WASM initializes (~5 s) → query runs (~15 s) → see the same 13 rows you get from `cc_match_ichthyo_by_name("Sardinops sagax", env_var="temperature", life_stage="larva", date_min="2018-01-01", date_max="2018-03-31", relax_matching=TRUE)` in R.

### 1.5 `match.js` faithfulness

`match.js` is a literal port of [`calcofi4r/R/match.R`](../../Github/CalCOFI/calcofi4r/R/match.R) — same template strings, same nested CTEs (`WITH bio AS (… )` wrapping the `WITH RECURSIVE taxon_tree` for the taxon wrapper), same env-date padding by `pad_hours`, same `WHERE time_diff_hr = mn_time_diff_hr` filter for `nearest_time`, same `* EXCLUDE (...) GROUP BY ALL`. The R and JS SQL outputs are character-identical for matching inputs; we'll assert this in verification (see §4).

### 1.6 CORS sanity

DuckDB-WASM fetches Parquet over HTTPS from `storage.googleapis.com`, which requires CORS headers on the bucket. The `calcofi-files-public` bucket already has a CORS config (see `int-app/global.R` notes); we'll verify `calcofi-db` has the same. If it doesn't, the fix is one `gcloud storage buckets update gs://calcofi-db --cors-file=cors.json` away (see §4).

---

## Part 2 — Doc updates for consistency

Single shared snippet — call it the **"Run it from anywhere"** block — appears verbatim (or with one-line framing tweaks) in `data-access.qmd`, `helpers.qmd`, and the vignette. It is structured as a 4-row table mirroring the one already in the vignette, **with the browser row pointing to the new app** instead of just shell.duckdb.org.

| Where | How |
|---|---|
| **R**, on your laptop | `calcofi4r::cc_match_ichthyo_by_name(...)` ([helpers](helpers.qmd)) |
| **Python**, on a notebook server | `duckdb.connect().sql(sql).df()` ([data-access](data-access.qmd#from-python)) |
| **shell**, on the command line | `duckdb -c "$(cat query.sql)"` |
| **your web browser**, no install | **[CalCOFI Match](match/)** — point-and-click form, runs in DuckDB-WASM |

### 2.1 `docs/data-access.qmd`

- **`## From your browser`** — new subsection between `## From Python` (line 132) and `## Reproducibility` (line 148). Two paragraphs: (a) link + one-screenshot description of the Match app, (b) a ~15-line vanilla-JS snippet for embedding DuckDB-WASM in any page (the same one used in `app.js`, abbreviated). Mentions [shell.duckdb.org](https://shell.duckdb.org) as the alternative for arbitrary SQL.
- **`## Run it from anywhere`** — new subsection just before `## Reproducibility`, containing the shared 4-row table.
- **`## Reproducibility`** (lines 148–171) — one-sentence edit noting the WASM Match app emits the same `query/integrated_*.sql`.

### 2.2 `docs/helpers.qmd`

- **`## Run it from anywhere`** — new section between `## Reproducible SQL` (line 91) and `## The core engine: cc_match_bio_env()` (line 115). Contains the shared 4-row table.
- One-line edit at line 101–103 (the existing "copy-paste it into the DuckDB CLI, Python, or a colleague's R session" sentence) to add `…, the browser-based [Match app](https://calcofi.io/docs/match/),` to the list.

### 2.3 `docs/api.qmd`

- Add a **second callout** below the existing `.callout-important` (lines 3–20), pointed at the WASM Match app:
  > **Try the new client-side Match app** — the three retired bio↔env endpoints are now an interactive form at **[/docs/match/](match/)** that runs entirely in your browser. Pick a function, fill the form, see results — no server, no credentials, no install.
- In the **Endpoint → replacement** table (lines 27–38), add a third column "**Browser**" with links to `match/` for the three bio↔env rows.

### 2.4 `calcofi4r/vignettes/bio-env-matching.Rmd`

- **`## Run it from anywhere`** section (lines 250-ish): replace the current paragraph "**A web browser, no install** — paste the same SQL into shell.duckdb.org" with a paragraph linking to the new Match app first, and keep shell.duckdb.org as a fallback for ad-hoc SQL.
- The 4-row table at the top of the vignette (the "anywhere" pitch) updates the browser row to point at `https://calcofi.io/docs/match/` instead of shell.duckdb.org.

### 2.5 `docs/_quarto.yml`

- Add `match/` to the project's `resources:` list so Quarto copies the standalone app into `_book/match/` on render.
  ```yaml
  project:
    type: book
    output-dir: _book
    resources:
      - "/.nojekyll"
      - "match/"          # <— new: ships the standalone DuckDB-WASM app
    post-render:
      - libs/post-render.R
  ```
- **No change** to the `chapters:` list — the Match app is not a Quarto chapter (per the user's choice), it's a standalone HTML page linked from chapters.

---

## Critical files

| Path | Change |
|---|---|
| `docs/match/index.html` | **new** — page shell, raw HTML form/result panels, loads `app.js` |
| `docs/match/match.js` | **new** — pure-JS port of the SQL builders in `calcofi4r/R/match.R` |
| `docs/match/app.js` | **new** — UI + DuckDB-WASM runtime + per-tab form handlers |
| `docs/match/style.css` | **new** — light styling matching the docs `cosmo` theme |
| `docs/_quarto.yml` | add `match/` under `project.resources` |
| `docs/data-access.qmd` | add `## From your browser` and `## Run it from anywhere`; one-line edit to `## Reproducibility` |
| `docs/helpers.qmd` | add `## Run it from anywhere`; widen the line-101 "copy-paste it into…" enumeration |
| `docs/api.qmd` | second callout + Browser column in the endpoint→replacement table |
| `calcofi4r/vignettes/bio-env-matching.Rmd` | point the browser bullet at the Match app; same 4-row table at top, updated browser row |

## Reused functions / files

- [`calcofi4r/R/match.R`](../../Github/CalCOFI/calcofi4r/R/match.R) — source of truth for the SQL builders; `match.js` is a 1:1 port. Functions to port: `.cc_parquet_base`, `.cc_extract_source_urls`, `.cc_build_match_sql`, `.cc_env_sql`, `.cc_bio_sql_ichthyo`, plus the three wrappers `cc_match_ichthyo_by_name`, `cc_match_ichthyo_by_taxon`, `cc_match_zooplankton_biomass`.
- [`calcofi4r/vignettes/bio-env-matching.Rmd`](../../Github/CalCOFI/calcofi4r/vignettes/bio-env-matching.Rmd) — the 4-row "Where / How" table at the top is the canonical "Run it from anywhere" content; reuse verbatim in `data-access.qmd` and `helpers.qmd` (with one-line framing tweaks).
- `docs/_book/` is git-ignored; pkgdown-style GHA workflow renders the book + deploys to `gh-pages` (see `docs/.gitignore` line `/_book/`). No workflow changes needed — Quarto picks up the new `match/` directory automatically once it's listed under `project.resources`.

## Verification

1. **SQL fidelity (programmatic)** — node script that runs the 3 JS wrappers with the worked-example args, compares each output `sql` to `attr(cc_match_*(...), "sql")` in R:
   ```sh
   node -e "
     import('./docs/match/match.js').then(({matchIchthyoByName}) => {
       const {sql} = matchIchthyoByName({
         scientific_name: 'Sardinops sagax', env_var: 'temperature',
         life_stage: 'larva', date_min: '2018-01-01', date_max: '2018-03-31',
         relax_matching: true, version: 'v2026.05.14'});
       process.stdout.write(sql);
     });
   " > /tmp/js.sql
   Rscript -e 'cat(calcofi4r::cc_match_ichthyo_by_name(
     "Sardinops sagax", env_var="temperature", life_stage="larva",
     date_min="2018-01-01", date_max="2018-03-31",
     relax_matching=TRUE, version="v2026.05.14", return_sql=TRUE))' > /tmp/r.sql
   diff /tmp/js.sql /tmp/r.sql      # expect: empty
   ```
2. **Page renders & query runs** — `quarto preview docs/` (or open `docs/_book/match/index.html` directly after `quarto render docs/`). Confirm the page loads, the default form is pre-populated with the Q1 2018 example, clicking Run shows status `"Initializing DuckDB-WASM…" → "Running query…" → "Done: 13 rows in ~15 s"`, the result table shows 13 rows, and the SQL panel matches the data-access.qmd worked-example block.
3. **All 5 tabs run** — by taxon (`worms_id=125724` → Engraulis subtree, salinity), zoo biomass (totalplankton, temperature), custom (the two pre-populated CTEs), and shell (a simple `SELECT` against `species.parquet`). Each produces rows + a Metadata panel with sensible source URLs.
4. **CSV download + Copy SQL** — files round-trip with no encoding issues; the downloaded `.sql` is runnable as-is in the `duckdb` CLI.
5. **Docs render** — `quarto render docs/data-access.qmd helpers.qmd api.qmd --to html` succeeds; rendered HTML for each links to `match/`; the shared 4-row table appears in all three with consistent framing.
6. **CORS check** — open the deployed `https://calcofi.io/docs/match/` in Chrome (or whatever the gh-pages URL is) with DevTools open; confirm no CORS errors when DuckDB-WASM fetches `https://storage.googleapis.com/calcofi-db/...`. If there's a preflight failure, apply `gcloud storage buckets update gs://calcofi-db --cors-file=cors.json` with:
   ```json
   [{"origin":["*"],"method":["GET","HEAD"],"responseHeader":["Content-Type","Range"],"maxAgeSeconds":3600}]
   ```

## Open risks / follow-ups

- **CORS on `gs://calcofi-db`** — must allow GETs with Range from the docs origin (or `*`). The bucket may already be configured; if not, a one-off `gcloud` update fixes it. Verify before merging.
- **DuckDB-WASM cold start** is ~3–6 s; the first query against GCS adds ~10–20 s of parquet-footer fetches. We surface a status pill, but expect to see one or two questions about "why is the first run slow". A persistent IndexedDB cache of httpfs ranges would help; out of scope for v1.
- **Mobile** — DuckDB-WASM works on modern mobile browsers but the ~5 MB bundle on cellular is a tax. The page should remain usable on a phone; we won't chase optimization.
- **Future reuse** — `match.js` is structured so it can be lifted into an npm package or imported by a future int-app browser-only edition. Out of scope for this PR, but the file lives at a stable path for that.
- **Match.js version sync** — when `calcofi4r/R/match.R` evolves (new wrappers, signature tweaks), `match.js` must follow. Add a sentence to the calcofi4r CONTRIBUTING (or to `match.R`'s top comment) noting the JS twin and the diff-check above.
