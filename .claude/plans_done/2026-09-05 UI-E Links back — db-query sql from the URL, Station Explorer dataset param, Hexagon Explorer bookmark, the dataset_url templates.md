# UI-E · Links back — db-query `?sql=` (any field from the URL), Station Explorer `?dataset=`, Hexagon Explorer bookmark, the `dataset_url` template lines

**Agent:** Sonnet 5 · high. **Wave 1**, worktrees: `db-query` (branch `url-params`), `db-viz-station` (branch
`dataset-param`), `db-viz-hex` (branch `dataset-bookmark`). **Needs:** nothing. **Does not touch** the landing repo:
hand the two `products.yml` template lines to the integrator. **Plan:** `.claude/plans/2026-09-05 CalCOFI.io UI refresh — emphasis, density and the dataset page, now that the catalog is live.md` § D-6 (Explore, Query), Decisions 10
and 20, Phase E; the artifact's Explore and Query rows: https://claude.ai/code/artifact/b06dcb2e-f899-4c00-831e-7383a5f4e87e.

## Goal

Every app that can open on one dataset does so from a URL the dataset page can build: db-query prefills its SQL
shell (and any query's fields) from the query string; the Station Explorer opens its panel on `?dataset=`; the
Hexagon Explorer restores a dataset selection from the URL. Nothing else in the apps changes.

## Read first

- `db-query/app.js`: `showQuery(hash)` (query ids are `category--name`, e.g. `sql-shell--shell`, `datasets--bottle`;
  today the app reads **only** `location.hash`), `readForm`, `runQuery`, the GA `paramsChangedFromDefaults` (names
  only — keep that rule); `_includes/form-field.html` (the shell's `<textarea name="sql">`); `_queries/sql-shell/shell.md`
  (`__TBL:table__` tokens); `test/` and `package.json` (`node --test`); `README.md` § adding a query.
- `db-viz-station/public/app.js` (~4,600 lines; the only URL parameter today is `?tour` at ~line 4641; the dataset
  crosswalk and the panel's dataset rows; WS-P2's alias canonicalisation onto the record's real keys — reuse it),
  `db-viz-station/README.md`, its `build/` and tests.
- `db-viz-hex/app/` (R Shiny; `global.R`, `ui.R`, `server.R`; no bookmarking today), `db-viz-hex/CLAUDE.md`,
  `apps/db-viz-cruise/server.R` (the `getQueryString` pattern to copy: parse once on connect, `updateQueryString`
  with `mode = "replace"`).
- The brand contract `CalCOFI.github.io/brand/v2/README.md` (`?theme=` and `?tour=off` must keep working;
  `check_brand.py` probes them).

## Do

1. **db-query**: on load, parse `location.search` once; for the section named by the hash (default `_intro` →
   `sql-shell--shell` when `sql` is present), set each form field whose name matches a parameter (`sql` for the
   shell; `env_var`, `date_min` … for the others — generic, by `form.elements[name]`), then `showQuery(hash)`; never
   write values back into the URL (the app already avoids it); a `?run=1` triggers `runQuery` after the release is
   pinned — optional, only if it is clean. Add a `node --test` case for the parser; README: "Open a query from a
   link". Deep-link example to verify by hand:
   `https://calcofi.io/db-query/?sql=SELECT+*+FROM+__TBL:obs__+WHERE+dataset_key+%3D+%27calcofi_ctd-cast%27+LIMIT+100#sql-shell--shell`.
2. **db-viz-station**: `?dataset={key}` (record key; canonicalise aliases as P2 did) opens the app with that dataset
   selected in the panel and its station layer drawn — the same state a click produces; unknown key → ignore.
   Keep `?tour`, `?theme`. Update README and the app's tests/build (`node --test`, the build script).
3. **db-viz-hex**: restore the dataset selection from `?datasets=a,b` on connect (`getQueryString`), and keep the
   URL in sync with `updateQueryString(mode = "replace")` as the cruise app does; `?theme=` untouched; no layout
   change. It is a server-side Shiny app: do not deploy (the integrator uses the deploy-consumers skill).
4. Hand the template lines to the integrator for `CalCOFI.github.io/_data/products.yml`:
   `db-viz-station: dataset_url: https://app.calcofi.io/station/?dataset={key}`,
   `db-viz-hex: dataset_url: https://app.calcofi.io/hex/?datasets={key}` (UI-B adds explore and db-viz-cruise itself).

## Gates

Each repo's own tests and build pass (`node --test`; the station app's build; `shiny::runApp` starts and the URL
parse works with `?datasets=calcofi_bottle`); `check_brand.py db-query db-viz-station` still passes (`?theme=`
honoured, favicon, back-link, toggle); the three deep links open on the dataset in a browser.

## Do not

Change any app's layout or default view; add a dependency; touch the landing repo; deploy.

## Hand back

One commit per repo (branch + sha), the three verified deep links, the two template lines, one *Measured* line.
