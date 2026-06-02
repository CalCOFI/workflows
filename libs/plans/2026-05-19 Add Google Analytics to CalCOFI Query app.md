# Add Google Analytics to CalCOFI Query app

## Context

`https://calcofi.io/query` (source: `/Users/bbest/Github/CalCOFI/query/`) currently has **no** analytics. The user wants:

1. Google Analytics 4 with measurement ID `G-0HVK8TDMCF` wired up.
2. Track **which queries are clicked on** (nav navigation between queries).
3. Track **which queries are run** (form submit), including the **parameter values used** and a flag/summary of which params differ from their query's defaults.
4. Track **downloads** (CSV / SQL / Copy-SQL) and **query failures** (SQL build error, DuckDB run error).

The app is a **Jekyll static site** with vanilla JS (no Shiny, no Quarto). All UI flow is in one module — `app.js` — and the page shell is `_layouts/default.html`. Defaults for each parameter are rendered by Jekyll into the DOM via standard HTML attributes (`value=`, `checked`, `selected`), so they are readable from each form element's native `defaultValue` / `defaultChecked` / `<option>.defaultSelected` — no shadow state needed.

## Approach

Three small changes:

### 1. Create `_includes/google-analytics.html`

Path: `/Users/bbest/Github/CalCOFI/query/_includes/google-analytics.html`

Standard gtag.js loader for `G-0HVK8TDMCF`. Matches the pattern in `/Users/bbest/Github/CalCOFI/int-app/app/google-analytics.html` (which uses a different property `G-VV117EV9ZT`). Keep it minimal — just the loader and `gtag('config', ...)`. All event firing happens in `app.js` (cleaner than the int-app's jQuery-based generic `change`/`click` listeners, which would over-fire on this app's dense forms).

```html
<!-- Google tag (gtag.js) — Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-0HVK8TDMCF"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){ dataLayer.push(arguments); }
  gtag('js', new Date());
  gtag('config', 'G-0HVK8TDMCF');
</script>
```

### 2. Include it from `_layouts/default.html`

Path: `/Users/bbest/Github/CalCOFI/query/_layouts/default.html`

Add `{% include google-analytics.html %}` just before `</head>` (line 22), so `gtag()` is defined globally before `app.js` runs.

### 3. Fire events from `app.js`

Path: `/Users/bbest/Github/CalCOFI/query/app.js`

Add a tiny safe wrapper at the top of the file (so the app keeps working if GA is blocked or fails to load):

```js
const ga = (name, params = {}) => {
  if (typeof gtag === "function") {
    try { gtag("event", name, params); } catch (_) {}
  }
};
```

Then add `ga(...)` calls at five hook points. All event names use snake_case to follow GA4 conventions.

| Hook | Event | Where | Params |
|---|---|---|---|
| Nav click → query shown | `query_view` | inside `showQuery(hash)` (line 61), after the section is unhidden and `hash` resolved (so it fires once per actual view, including hashchange and initial boot) | `query_id` (the resolved hash, e.g. `bio-env-matching--by-name`), `category` (split on `--`, first half), `label` (second half) |
| Form submit → run starts | `query_run` | inside `runQuery(section, form)` (line 249), right after `readForm(form)` returns `args` | `query_id` (`section.dataset.queryId`), `release_version` (`args.version` if present), `n_params_changed`, `params_changed` (comma-joined list of changed param names, truncated to 100 chars), `params_total` |
| Run succeeds | `query_success` | in `runQuery`'s success branch after `setStatus(... "success")` (line 317) | `query_id`, `n_rows`, `n_cols`, `duration_sec` |
| Run fails | `query_error` | in both error paths in `runQuery`: SQL build catch (line 282) and DuckDB run catch (line 318) | `query_id`, `error_stage` (`"sql_build"` or `"duckdb_run"`), `error_message` (truncated to 100 chars) |
| Download / copy | `download` | in the three click handlers at lines 238, 240, 242 | `query_id` (read from the visible section's `data-query-id`), `kind` (`"csv"` / `"sql"` / `"copy_sql"`) |

**Params-changed detection** — small helper, no shadow state needed since the DOM already remembers defaults:

```js
function paramsChangedFromDefaults(form) {
  const changed = [];
  for (const el of form.elements) {
    if (!el.name) continue;
    if (el.type === "checkbox") {
      if (el.checked !== el.defaultChecked) changed.push(el.name);
    } else if (el.type === "radio") {
      // a radio group is "changed" if the currently-checked option
      // isn't the one that was default-checked; only count once per name
      if (el.checked && !el.defaultChecked && !changed.includes(el.name))
        changed.push(el.name);
    } else if (el.tagName === "SELECT") {
      const def = Array.from(el.options).find((o) => o.defaultSelected);
      if (def && el.value !== def.value) changed.push(el.name);
    } else {
      if (el.value !== el.defaultValue) changed.push(el.name);
    }
  }
  return changed;
}
```

The list of changed param **names** (not values) keeps the payload safe under GA4's 100-char string cap and 25-param-per-event cap — even for the SQL-shell textarea, which can be arbitrarily long. Values are intentionally **not** sent: full SQL bodies could be huge, and aggregating param *names* in GA already answers "which knobs do people actually turn?" which is the real question.

**Active-section helper** (needed by `download` events since the download buttons are global, not per-section):

```js
const activeQueryId = () => {
  const s = $$("[data-query-id]").find((s) => !s.hidden);
  return s ? s.dataset.queryId : null;
};
```

## Files to modify

- **Create**: `/Users/bbest/Github/CalCOFI/query/_includes/google-analytics.html`
- **Edit**: `/Users/bbest/Github/CalCOFI/query/_layouts/default.html` (one-line include)
- **Edit**: `/Users/bbest/Github/CalCOFI/query/app.js` (wrapper + helpers + 5 hook sites; ~30 lines added)

No other files touched. No new dependencies. Works the same in `bundle exec jekyll serve` locally as on GitHub Pages.

## Verification

1. **Build locally**: `cd /Users/bbest/Github/CalCOFI/query && bundle exec jekyll serve` → open `http://localhost:4000`.
2. **Confirm GA loads**: DevTools → Network → filter `googletagmanager` — should see a 200 for `gtag/js?id=G-0HVK8TDMCF`.
3. **Confirm events fire**: DevTools → Console → run `window.dataLayer` after each of:
   - clicking a nav link → expect a `query_view` push
   - clicking Run with defaults → expect `query_run` with `n_params_changed: 0`, then `query_success`
   - changing one param + clicking Run → expect `params_changed: "<param_name>"`, `n_params_changed: 1`
   - clicking Download CSV / SQL / Copy SQL → expect three `download` events with correct `kind`
   - triggering an error (e.g. broken SQL in sql-shell) → expect `query_error` with `error_stage: "duckdb_run"`
4. **Confirm in GA Realtime**: GA4 → Reports → Realtime → DebugView (with `?gtm_debug=1` query param) — events should show up within ~30 s with the right names and params.
5. **Deploy**: push to `main`; GitHub Pages rebuilds; recheck Realtime on `https://calcofi.io/query`.
