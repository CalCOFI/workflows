# Consistent dark/light theme, nav back-link & favicon across every calcofi.io product

**Status:** executed 2026-08-25 (all eight decisions as recommended; see the session recap and `CLAUDE.md` § The brand contract) · **Date:** 2026-08-25 · **Scale:** ~17 repos, 7 phases; Phases 0–1
are the enabling work and ship first, everything after is per-product adoption that can land in
any order.

## Context

calcofi.io is dark by default with a 🌓 toggle, and the four sites built in its image
(`db-schema`, `db-query`, `workflows`, `analytics`) match it. Everything else was themed by
whatever framework it was built in, so the card grid on the front door is a checkerboard and
the experience of clicking into a product is a coin-flip on background colour.

Measured today (mean luminance of each card image in `CalCOFI.github.io/images/`):

| dark (8) | light (19) |
|---|---|
| db-viz-hex, db-viz-cruise, ctd-viz, db-query, db-schema, workflows, calcofi4py, ucsb-station-portal (reused for db-viz-station) | **ctd-transects, erddap, storage, docs, calcofi4r, calcofi4db, server, oceano, pollutants**, + 10 student cards |

Under the images the situation is worse than "some are white". Surveyed 2026-08-25 across all
repos (full per-product table in Appendix A):

- **Five unrelated theme mechanisms** are in play and none reads a URL parameter:
  hub `localStorage["theme"]` (dark default) · mkdocs-material `__palette` (dark default) ·
  `prefers-color-scheme` with no toggle (ctd-transects light-default, storage index light-default,
  Caddy's stock `browse` template) · bslib `input_dark_mode()` (three Shiny apps, dark default,
  bslib's own persistence) · hardcoded light (pkgdown ×2, Quarto docs, every rendered workflows
  notebook, ERDDAP, Swagger, ctd-qaqc, oceano). A theme choice made anywhere carries nowhere —
  and `app.calcofi.io`, `erddap.`, `storage.`, `status.` are different origins from `calcofi.io`,
  so even a shared localStorage key could not carry it.
- **The back-link is almost never there.** Only `analytics` (mid-nav "home") and `uptime` (first
  navbar item) link to `https://calcofi.io` from the chrome. `db-schema`/`db-query`/`workflows`
  point their far-left logo at *their own* root. The three Shiny apps with a logo do link it to
  calcofi.io (good — that is the pattern). Ten products have no logo and no link at all.
- **Favicon coverage is 5 of 20** (hub family + db-viz-hex). `calcofi4r`'s favicon links **404
  on the live site** (pkgdown 2.2 emits a new file set the repo's 2025 RealFaviconGenerator set
  doesn't contain), `calcofi4db` and `docs` have none, ERDDAP shows NOAA's, `api-h3t-py` shows
  FastAPI's, ctd-transects shows an emoji.
- **The logo asset itself has not drifted** — `logo_calcofi.svg` + `logo_calcofi_light.svg`
  (9,053 B each) are byte-identical in all 9 copies, as are the three favicon files. There is no
  divergence problem to untangle, only no single source. `uptime` hotlinks them from
  `calcofi.io/db-schema/assets/` (rename db-schema and the status page loses its logo).
- **Three different brand blues**: `#193E6D` (calcofi4r hex / calcofi4py), `#128CB5` (ERDDAP
  banner), `#4dabf7`/`#2780e3` (hub accent).
- **Every basemap and most plots are pinned** to one theme regardless of the page: carto
  `dark_all` (db-viz-station), `light_nolabels` (analytics), Esri Ocean at 0.4 opacity under a
  darkly theme (pollutants), carto `dark-matter` under a flatly theme (apps/cruises). In the three
  toggle-able Shiny apps the *map* follows the toggle but the *plots* stay light except in
  db-viz-hex, whose `plot_ts(is_dark)` is a local fork that has drifted ahead of `calcofi4r`.
- The single biggest gap by page count: **~60 rendered workflows notebooks** in `_output/*.html`
  are plain Quarto `cosmo` — white, no favicon, no header, no way back — while the
  `calcofi.io/workflows/` index that links to them is dark CalCOFI chrome.

## Goal

Every CalCOFI-controlled product:

1. **honours one theme contract** — `?theme=dark|light` on any URL forces the theme; the choice
   persists across every `*.calcofi.io` origin; one visible 🌓 toggle; **dark is the default**
   (the hub's convention, kept so the default state of every screenshot is the same);
2. **has the CalCOFI logo far-left in its top bar, linking to `https://calcofi.io`**, with the
   product's own title beside it (linking to the product's root — that is how the two links stay
   distinguishable);
3. **serves the CalCOFI favicon**, except products with their own designed mark — `calcofi4r`
   (hex) and `calcofi4py` (squircle) keep theirs (and `calcofi4r`'s must stop 404ing);
4. **is captured twice** for the front door — `images/<key>_dark.png` and `_light.png` — and the
   hub swaps card images when its theme toggles.

Consistency is **checked, not asserted** (Phase 7): a weekly job fetches every `live_url` and
fails on a missing favicon, missing back-link, or a page that ignores `?theme=`.

## Non-goals (explicit, so scope does not creep)

- **Student contributions and archived apps** (ucla map, larvae dashboard, hypoxia story,
  ucsb-station-portal, marmam, SaferSeafood, capstone, 75th timeline, offshore-wind). Six of
  these repos are archived (unarchive → push → verify → re-archive per card), two are third-party
  hosts, and the ucla map alone has ~12 `background: white` literals in a 187 KB inline
  stylesheet. They keep a single screenshot used for both themes. Revisit individually if one
  gets active maintenance.
- **`oceano`** (superseded, shinydashboard/Bootstrap 3): favicon + back-link only, no dual theme.
- **The scratch apps in `apps/`** (casts, copernicus, cruises, dashboard, hex_density, querychat,
  taxa, vtiles, mapgl_h3, slide_filter, up2db): not on calcofi.io, untouched. `querychat` is the
  one worth doing later, when it ships.
- Rewriting any product's own colours beyond the shared tokens. The contract sets the *ground*
  (bg/panel/border/fg/muted/accent); an app's data colours are its own.
- OS `prefers-color-scheme` as the default. Deliberate: see Decision 1.

---

## The contract (`calcofi.io/brand/v1/`)

Lives in `CalCOFI.github.io/brand/v1/` — the hub is already the de-facto source and already
serves `calcofi.io/assets/logo_calcofi.svg`; a separate repo would be one more thing to keep in
step (Decision 3). Versioned path so a breaking change ships as `v2` without touching consumers.

```
brand/v1/
  theme.css              # the tokens + header/footer idiom (extracted from the hub's style.css)
  theme.js               # resolve → apply → persist → toggle → notify (~60 lines, no deps)
  head.html              # the inline pre-paint snippet, for copy-paste (must be inline: no FOUC)
  logo_calcofi.svg       # dark-ground variant (white text)
  logo_calcofi_light.svg # light-ground variant
  favicon.ico  favicon.svg  favicon-16x16.png  favicon-32x32.png  apple-touch-icon.png
  README.md              # the contract, the per-framework recipes, the checker
```

**Theme resolution order** (`theme.js`, run once at load and again on toggle):

1. `?theme=dark|light` in the URL → apply **and persist** (Decision 2), then strip nothing (the
   param is harmless and keeps the URL shareable);
2. cookie `cc_theme` (`Domain=.calcofi.io; Path=/; SameSite=Lax; Max-Age=1y`) — this is what
   carries the choice from `calcofi.io` to `app.`/`erddap.`/`storage.`; set from JS, no server
   needed, works on GitHub Pages;
3. `localStorage["theme"]` — the hub's and pkgdown's existing key, kept for continuity;
4. default `dark`.

**Apply** = set every attribute a framework on the page might key on — `data-theme` (ours),
`data-bs-theme` (Bootstrap 5.3 / bslib / pkgdown / Quarto), `data-md-color-scheme`
(mkdocs-material: `slate`/`default`) — write `color-scheme` on `:root`, then
`document.dispatchEvent(new CustomEvent("cc:theme", {detail: {theme}}))` so maps, Plotly and
Mermaid re-style. Products with framework-native toggles (Quarto's `quarto-color-scheme`, bslib's
`input_dark_mode`, mkdocs' palette) get a small bridge: theme.js seeds the framework's state on
load, and the framework's toggle writes back through `theme.js.set(theme)`. No page gets two
toggles.

**Header markup** (what `theme.css` styles; what `cc_brand_header()` and the Jekyll/Hugo/Quarto
includes emit):

```html
<header class="cc-header">
  <a class="cc-home" href="https://calcofi.io" aria-label="CalCOFI.io home">
    <img class="cc-logo-dark"  src="…/logo_calcofi.svg">
    <img class="cc-logo-light" src="…/logo_calcofi_light.svg">
  </a>
  <a class="cc-title" href="./">{Product title}</a>
  <span class="cc-spacer"></span>
  <nav class="cc-links">…product's own links…</nav>
  <button class="cc-theme-toggle" aria-label="Toggle dark / light theme">🌓</button>
</header>
```

Where a framework owns the top bar (Quarto navbar, pkgdown navbar, mkdocs header, bslib
`page_navbar`), we do **not** stack a second bar: the logo→calcofi.io goes in the framework's
brand slot (Quarto `navbar.logo` + `logo-href`; pkgdown a leading `html:` navbar component;
mkdocs `extra.homepage`), and the toggle is the framework's own, bridged.

**Screenshot contract**: `?theme=` is what makes a capture deterministic — shot-scraper opens a
fresh browser context with no cookie and no localStorage, so the param is the only thing that
can pick the theme. Every card also needs a `?tour=off` (db-viz-hex already honours it;
ctd-viz and db-viz-cruise gate their tours on localStorage only and cannot be suppressed from a
URL today).

---

## Phase 0 — hub: brand assets, contract, dual card images (`CalCOFI.github.io`)

Ships alone; nothing depends on it being adopted yet.

1. Create `brand/v1/` as above. `theme.css` is the hub's current `:root` / `:root[data-theme]`
   block plus `.cc-header`/`.cc-footer`; the hub's own `style.css` then `@import`s it, so the hub
   is consumer #1 and the file cannot drift from the hub.
2. `_layouts/default.html`: replace the inline pre-paint + toggle listener with `head.html` +
   `theme.js`. Hub gains `?theme=` for free.
3. `_includes/product_card.html`: when a product declares `shots: themed`, emit two lazy images
   `<img class="shot-dark" src="images/<key>_dark.png">` + `<img class="shot-light" …_light.png>`
   and hide the inactive one with the same `:root[data-theme]` CSS idiom the header logo already
   uses. A `display:none` lazy image is never fetched, so cost is one image per card per theme.
   Products without `shots: themed` keep the single `img:` (students, third-party hosts).
4. `_data/shots.yml` → keep only the *overrides* (tour-dismiss JS, `wait:`); `scripts/shots.sh`
   generates the shot-scraper multi file from `products.yml` × `{dark, light}` by appending
   `theme=<t>&tour=off` to `live_url`, at a fixed 1200×750 (today's images range from 569×640 to
   2160×1620). Add a `scripts/check_shots.py` that reports each image's mean luminance so a
   "dark" capture that came out white (app ignored the param) is caught before commit.
5. `README.md`: document the contract and link `brand/v1/README.md`.

Verification: hub renders identically; `?theme=light` on calcofi.io flips it; cookie present on
`.calcofi.io`; `curl https://calcofi.io/brand/v1/theme.js` after deploy.

## Phase 1 — `calcofi4r` 1.5.0: the R half of the contract

All five Shiny apps in scope copy-paste the same 30 lines (logo pair, `[data-bs-theme]` CSS
block, `input_dark_mode(id="dark_toggle", mode="dark")`), and the only favicon is a one-off in
db-viz-hex. Same shape as the existing `cc_ga_head()`: helpers that emit tags, so an app declares
against the contract instead of re-implementing it.

- `cc_brand_head(title, ga_app = NULL)` — `<title>`, favicon links, `theme.css`, `head.html`
  pre-paint (inline), `theme.js`, and `cc_ga_head()` if `ga_app` is given. Assets are referenced
  at `calcofi.io/brand/v1/` (not vendored — one source; see Decision 3).
- `cc_brand_header(title, ..., toggle_id = "dark_toggle")` — the `.cc-header` div with
  logo→calcofi.io, title, `...` for the app's own controls, and `bslib::input_dark_mode()`.
- `cc_theme_init(session, toggle_id = "dark_toggle")` — server side: reads `?theme=` from
  `session$clientData$url_search`, calls `bslib::toggle_dark_mode(mode)`; and a JS bridge that
  writes bslib's toggle back to the `cc_theme` cookie (bslib's persistence key is its own —
  verify at implementation, the package source on disk shows none).
- `cc_tour_enabled(session)` — the `?tour=off|false|0|no` rule from db-viz-hex, one place.
- Theme-aware plot helpers, so plots stop lagging maps: `cc_plotly_layout(is_dark)` (paper/plot
  bg transparent, font/grid colours), `cc_ggplot_theme(is_dark)`, and **promote db-viz-hex's
  `plot_ts(..., is_dark)` fork into the package** (`db-viz-hex/app/functions.R:1917` is ahead of
  `calcofi4r::plot_ts()`). `map_sp()`/`map_env()` already take `is_dark`.
- `NEWS.md` entry; testthat for `cc_tour_enabled()` parsing, `cc_brand_head()` tag set, and the
  `?theme=` parse. Reinstall in the `rstudio` container before Phase 4 deploys.

## Phase 2 — the hub family (`db-schema`, `db-query`, `workflows`, `analytics`)

Already on-palette; mechanical.

- Swap inline pre-paint/toggle for `brand/v1/head.html` + `theme.js`; point favicon/logo links at
  `brand/v1/` (delete the local copies — this is the *only* place drift could start).
- **Far-left logo → `https://calcofi.io`**; the `<h1>` becomes the link to the site's own root
  (today the logo goes to the site root and there is no hub link in the header at all).
- `workflows/_output` header links `schema/query/docs` currently hit the meta-refresh stubs
  (`calcofi.io/schema/` → `/db-schema/`); point them at the real paths.
- `db-schema`: the Mermaid ERD already re-renders on toggle — move that listener onto `cc:theme`.
- `analytics`: Leaflet basemap `light_nolabels` ↔ `dark_nolabels` on `cc:theme`; re-read
  `--accent` for markers.
- **`workflows` notebooks (~60 HTML files)** — two mechanisms, deliberately:
  1. `_quarto.yml` gets `theme: {light: [cosmo, brand-light.scss], dark: [cosmo, brand-dark.scss]}`,
     `include-in-header: brand/head.html` (favicon, `theme.js` bridge to Quarto's
     `quarto-color-scheme`), `navbar: logo/logo-href → calcofi.io`. Every **future** render is
     on-pattern.
  2. **Do not re-render 60 notebooks for a stylesheet** — a render is an ingest run. A small
     idempotent injector (`scripts/brand_inject_html.R`, run from `build_workflows_index.R` in the
     Pages workflow) inserts the head snippet + a `brand-quarto.css` override into any
     `_output/*.html` lacking the marker. Quarto ≥1.4 ships Bootstrap 5.3, so `data-bs-theme=dark`
     on `<html>` should give a usable dark page without recompiling SCSS — **verify on one
     notebook first**; if Quarto's compiled bundle lacks the colour-mode CSS, the injector ships
     a hand-written `[data-bs-theme=dark]` override for the ~15 Bootstrap variables Quarto uses.

## Phase 3 — static JS apps (`ctd-transects`, `db-viz-station`)

- **`ctd-transects`** (the card that prompted this; the only light-default product): switch from
  `prefers-color-scheme` to the contract (dark default, toggle), rename `--line`→`--border` and
  adopt the token values, add the header (logo→calcofi.io, title, release badge, toggle) and the
  favicon (drop the 🌊 data URI). Its plot theming is best-in-class already
  (`darkMode()`/`theme()`, diverging ramps, `scattergeo` land/ocean colours) — it just needs to
  call `render()` on `cc:theme` instead of reading the OS once at load. Fix the stale
  `calcofi.io/ctd/` footer link → `app.calcofi.io/ctd/`.
- **`db-viz-station`**: bespoke ocean palette (`--ocean/--deep/--surface/--glow`), dark-only. Keep
  the palette as the *dark* values, add a light set under `:root[data-theme=light]` (bind to the
  brand tokens where a token exists), header logo→calcofi.io + toggle, favicon, and
  `dark_all` ↔ `light_all` basemap on `cc:theme`. The `#ffffff` literals on hover states
  (`styles.css:2306, 2461`) become tokens. Served by the server's `git pull` cron, so it deploys
  itself within 30 min of merge.

## Phase 4 — Shiny apps (`ctd-viz`, `db-viz-cruise`, `db-viz-hex`, `ctd-qaqc`, `pollutants`, `oceano`)

Each app: replace its hand-rolled head/header/CSS with `cc_brand_head()` + `cc_brand_header()`,
add `cc_theme_init()` and `cc_tour_enabled()` in `server`, delete the local `www/logo_calcofi*.svg`.
Then per app:

| app | today | work beyond the helpers |
|---|---|---|
| `ctd-viz` | dark default, toggle, map follows; ggplotly plots pinned light (`#222`/`#666`); tour not URL-suppressible; no favicon; `dark_toggle` excluded from bookmarks | plots via `cc_ggplot_theme(is_dark)`; `?tour=off`; keep `dark_toggle` bookmark-excluded (theme is a preference, not a view) |
| `db-viz-cruise` | same pattern; Plotly space-time scatter pinned light; reads `cruise/datasets/id` params | `cc_plotly_layout(is_dark)`; `?tour=off`; `theme` must not collide with `updateQueryString()` rewriting — pass it through |
| `db-viz-hex` | the reference implementation (favicon, `?tour=off`, `plot_ts(is_dark)`) | consume the promoted `calcofi4r::plot_ts()`; compare-map restyle already on toggle |
| `ctd-qaqc` | light only (`preset="shiny"`), no logo, no link, no favicon, map pinned `voyager` | add `input_dark_mode` (dark default), `map_env(is_dark)`, Plotly profiles via `cc_plotly_layout()`; it is the CTD team's daily tool, so confirm dark default with them (Decision 1) |
| `pollutants` | fixed `darkly`, Esri Ocean basemap at 0.4 under it, GA via `includeHTML` | default `bs_theme()` + toggle; `map_base(is_dark)` in `apps/libs/functions.R` (Esri Ocean ↔ carto dark); migrate to `cc_ga_head()` |
| `oceano` | shinydashboard / BS3, superseded | `cc_brand_head()` only (favicon + title); logo already links to calcofi.io |

Deploy via the `deploy-consumers` skill procedure (`git pull`, `restart.txt`); `calcofi4r` 1.5.0
must be installed in the `rstudio` container first.

## Phase 5 — docs & packages (`docs`, `calcofi4r`, `calcofi4db`, `calcofi4py`)

- **`docs`** (Quarto book, `theme: cosmo`, no favicon, empty `sidebar-logo-link`, no hub link):
  `theme: {light, dark}` + Quarto's toggle bridged to `theme.js`; `favicon: brand`; sidebar/navbar
  logo → `https://calcofi.io`; the "CalCOFI.io" sidebar title currently links to `/docs` — make
  it read "docs" and leave the home link to the logo.
- **`calcofi4r`** (pkgdown 2.2, light hardcoded, favicon 404s): `template: light-switch: true`
  (pkgdown's key is `localStorage["theme"]`, same as ours — bridge sets `data-bs-theme`);
  `navbar.components.home: {html: <logo img>, href: https://calcofi.io}` first in
  `structure.left`; regenerate favicons from `man/figures/logo.svg` with
  `pkgdown::build_favicons(overwrite = TRUE)` so the hex is the favicon **and the links resolve**;
  add the `theme.js` include via `template.includes.in_header`. Also flip the deploy action's
  `clean: false` → `true` (stale `lightswitch.js` etc. accumulate on `gh-pages` forever). Note
  the config is at `inst/_pkgdown.yml`, not repo root.
- **`calcofi4db`** (no `_pkgdown.yml` at all): create one with the same template block; CalCOFI
  favicon from `brand/v1/` (no hex exists — Decision 4); `clean: true`.
- **`calcofi4py`** (mkdocs-material, already dark-default with toggle, squircle logo/favicon —
  kept): `extra.homepage: https://calcofi.io` (material makes the logo link there — the
  far-left back-link with zero markup), `extra_javascript: [brand/v1/theme.js]` bridging
  `data-md-color-scheme` ↔ the cookie. `stylesheets/extra.css` forces the header navy "regardless
  of scheme" — keep (it's the package's design) but confirm it reads on light. The
  `mkdocs-jupyter` notebooks are pinned `theme: dark`; leave, note in README.

## Phase 6 — services (`erddap`, `storage`, `status`, `api-h3t-py`)

- **ERDDAP** (customisable only via `startHeadHtml5`/`startBodyHtml5`/`endBodyHtml5` in the
  bind-mounted `erddap/messages.xml` + `images/erddap2.css`): head gets favicon + `theme.css` +
  pre-paint + `theme.js` and a real `<title>`; the `#128CB5` table banner becomes the `.cc-header`
  markup (logo→calcofi.io, "CalCOFI ERDDAP", toggle) on brand tokens; `erddap2.css` (currently
  the unmodified sample and **not even wired up** — it must be named `erddap2.css` and mounted)
  gets a `[data-theme=dark]` override for `body`, links, `table.commonBGColor` and the yellow
  `#ffffcc` panels. ERDDAP's tables carry inline `bgcolor` attributes, so dark will be
  **best-effort** (Decision 7). Mount the favicon files alongside `calcofi.svg` in
  `docker-compose.yml`. Re-derive on every ERDDAP upgrade, as the existing note already says.
- **storage.calcofi.io** — every page is generated by `workflows/libs/gcs_index.R::page()`
  (light default, OS-following, third palette, no header, no favicon). Move `page()` onto the
  brand tokens + `.cc-header` + favicon + `theme.js` (hotlinking calcofi.io is fine from a bucket
  page) and regenerate the three indexes (`build_storage_index.R`, `build_release_index.R`,
  `build_netcdf_index.R`). `file.`/`static.calcofi.io` use Caddy's stock `browse` template — add
  a `browse.html` with the header; low priority, they are not cards.
- **status.calcofi.io** (Upptime, `theme: dark` fixed, no runtime toggle possible): stays dark;
  repoint `logoUrl`/`favicon` from `calcofi.io/db-schema/assets/…` to `brand/v1/`; define the
  `--muted` its CSS references and never sets.
- **api-h3t-py**: `FastAPI(title=…, description=…, version=…)` + a custom `/docs` route passing
  `swagger_favicon_url` to `get_swagger_ui_html()` — a CalCOFI host serves FastAPI's favicon today.
  No dark mode in stock Swagger UI; not a card; stop there.

## Phase 7 — reshoot, swap, and keep it true

1. `scripts/shots.sh` over every `shots: themed` product × 2 themes; `check_shots.py` luminance
   gate; commit `images/<key>_{dark,light}.png`, delete the odd-sized originals; flip each
   product's `shots: themed` in `products.yml` as its site lands (a card is only dual-imaged once
   its product honours `?theme=`, so the grid never shows a light "dark" shot).
2. `scripts/check_brand.py` (shot-scraper `javascript` mode) for each `live_url` we control:
   `<link rel=icon>` present and 200; `href="https://calcofi.io"` inside the header; opening
   `?theme=light` yields `documentElement.dataset.theme === "light"` and `?theme=dark` yields
   dark. Run weekly from `CalCOFI.github.io/.github/workflows/check-brand.yml` alongside the
   existing refresh jobs; failures open an issue. This is the "checked, not asserted" half.
3. Update `RUNBOOK.md`/`CLAUDE.md` in this repo with a short "new product checklist": brand head
   + header + favicon + `?theme=` + `?tour=off` + two screenshots + uptime + analytics slugs
   (extends the three-slug contract to a five-item one).

---

## Decisions to confirm before starting

1. **Default theme = dark, not the OS preference.** Keeps the hub's convention and makes the
   default state of every screenshot identical. Counter-argument: `ctd-qaqc` is a daily working
   tool for the CTD team; a light default there is a one-line `mode="light"` if they ask.
   *Recommend dark everywhere.*
2. **`?theme=` persists** (writes the cookie) rather than being a one-shot override. A user who
   follows a `?theme=light` link and then clicks around should stay light. Screenshots are
   unaffected (fresh context). *Recommend persist.*
3. **Brand home = `CalCOFI.github.io/brand/v1/`, consumed by URL** — not a new repo, not vendored
   copies. Vendoring is exactly how nine identical copies got here; hotlinking means one edit
   ships everywhere on the next page load (and every product already depends on calcofi.io being
   up). Trade-off: a bad push to `theme.js` breaks every site at once → the `v1` path is
   immutable once adopted; changes go to `v1.1`/`v2` and consumers opt in. *Recommend as stated.*
4. **`calcofi4db` favicon = CalCOFI logo** (it has no hex; it is an internal package).
   Alternative: mint a hex to match `calcofi4r`. *Recommend CalCOFI logo.*
5. **`oceano` = favicon + back-link only** (superseded, Bootstrap 3). *Recommend minimal.*
6. **Students/archived = out of scope, single image both themes.** *Recommend.*
7. **ERDDAP dark = best-effort overlay**, accepting that some ERDDAP table panels stay light.
   Alternative: light-only ERDDAP with brand header + favicon, and the card ships a light shot for
   both themes. *Recommend the overlay; fall back if it looks worse than light.*
8. **Card image swap via two lazy `<img>` + CSS**, not a JS `src` swap — same idiom as the header
   logo, no script, instant. *Recommend.*

## Risks / things to verify early

- Quarto dark without re-render (Phase 2 injector) — verify on one notebook before writing it.
- bslib's dark-mode persistence key (none found in the installed package source) — the bridge
  must own persistence regardless; verify `toggle_dark_mode()` fires the attribute change the
  bridge listens for.
- A product with no header at all (`storage` index pages, ERDDAP) gains one: check nothing in
  those pages assumed it was at the top of the viewport (ERDDAP's own sticky bits).
- Cookie on `.calcofi.io` from GitHub Pages: JS-set, so it works, but `SameSite=Lax` means a link
  from an *external* site still lands on the default theme (fine).
- `check_brand` must use ranged GETs/JS, never HEAD — same lesson as `build_workflows_index.R`'s
  link check (EDI answers 405 to HEAD).

## Rough order & size

| phase | repos | size |
|---|---|---|
| 0 hub + contract | CalCOFI.github.io | 1 day |
| 1 calcofi4r 1.5.0 | calcofi4r | 1 day |
| 2 hub family | db-schema, db-query, workflows, analytics | 1 day (+ notebook injector ½) |
| 3 JS apps | ctd-transects, db-viz-station | 1 day |
| 4 Shiny | apps/{ctd-viz,db-viz-cruise,ctd-qaqc,oceano}, db-viz-hex, pollutants-app + server deploy | 1½ days |
| 5 docs/pkgs | docs, calcofi4r, calcofi4db, calcofi4py | 1 day |
| 6 services | erddap, workflows/libs/gcs_index.R, uptime, api-h3t-py | 1 day (ERDDAP is the unknown) |
| 7 reshoot + checker | CalCOFI.github.io | ½ day |

Phases 2–6 are independent of each other once 0 and 1 have shipped; the card for a product only
flips to dual images when that product passes the checker.

---

## Appendix A — per-product state (surveyed 2026-08-25)

| product | framework · deploy | theme today | header back-link | favicon | map/plot theming |
|---|---|---|---|---|---|
| calcofi.io (hub) | Jekyll · Pages | dark default, `data-theme`, localStorage `theme`, toggle; no `?theme` | logo → `/` (is home) | ✅ | — |
| db-schema | Jekyll · Pages | on-pattern | logo → own root; hub links footer only | ✅ | Mermaid ERD re-renders on toggle ✅ |
| db-query | Jekyll · Pages | on-pattern | logo → own root | ✅ (+ apple-touch) | — |
| workflows index | Jekyll (`_output`) · Pages | on-pattern | logo → own root; links hit `/schema/` redirect stubs | ✅ | — |
| workflows notebooks (~60) | Quarto `cosmo`, no `theme:` | **light only**, no toggle | **none** | **none** | — |
| analytics | Hugo · Pages | on-pattern | "home" mid-nav | ✅ (no .ico) | Leaflet `light_nolabels` pinned |
| ctd-transects | HTML+JS · Pages | **light default**, `prefers-color-scheme`, no toggle; `--line` not `--border` | **none** | 🌊 emoji data-URI | plotly fully theme-aware, read once at load |
| db-viz-station | HTML+JS · server Caddy (`git pull` cron) | **dark only**, bespoke `--ocean/--deep/--surface` palette | **none** (text title) | **none** | Leaflet `dark_all` pinned |
| db-viz-hex | Shiny bslib · `/srv/shiny-server/db-viz-hex` | dark default, `input_dark_mode`, `?tour=off` | logo → calcofi.io ✅ | ✅ (only Shiny app) | map ✅, `plot_ts(is_dark)` local fork ✅ |
| ctd-viz | Shiny bslib · `/ctd` | dark default, `input_dark_mode`; tour localStorage-only | logo → calcofi.io ✅ | none | map ✅; ggplotly pinned light |
| db-viz-cruise | Shiny bslib · `/db-viz-cruise` | dark default, `input_dark_mode`; reads `cruise/datasets/id` | logo → calcofi.io ✅ | none | map ✅; plotly pinned light |
| ctd-qaqc | Shiny bslib `preset="shiny"` | **light only** | **none** | none | map `voyager` pinned |
| oceano | shinydashboard BS3 | light only | logo → calcofi.io ✅ | none | leaflet Esri Ocean pinned |
| pollutants | Shiny `navbarPage` BS5 `darkly` | **fixed dark** | none (logo in About only) | none | Esri Ocean @0.4 under dark |
| docs | Quarto **book** `cosmo` · Pages | **light only** | sidebar title → `/docs`; empty logo link | **none** | — |
| calcofi4r | pkgdown 2.2 (`inst/_pkgdown.yml`) · gh-pages `clean:false` | light hardcoded; `lightswitch.js` present, unreferenced | Schema/Query/Docs links, **no hub root** | **links 404** (old file set); hex = `man/figures/logo.svg` | — |
| calcofi4db | pkgdown 2.2, **no `_pkgdown.yml`** | light hardcoded | none | **none** | — |
| calcofi4py | mkdocs-material · gh-deploy | **dark default + toggle** (`__palette`) | footer icon only | squircle (own) ✅ keep | notebooks pinned dark |
| erddap | ERDDAP 2.30 · docker, `messages.xml` bind-mount | none (white) | banner logo → calcofi.io ✅ (`#128CB5` table) | NOAA stock | — |
| storage | generated by `workflows/libs/gcs_index.R` | light default, OS-following, 3rd palette | **none** | **none** | — |
| file./static. | Caddy stock `browse` | OS-following (Caddy's own) | none | none | — |
| status | Upptime `theme: dark` | fixed dark, no toggle possible | "Home" first ✅ | hotlinked from db-schema | — |
| api-h3t-py | FastAPI Swagger | light | none | FastAPI's | — |
| students ×9 | various, 6 repos archived | none / hardcoded | none | none | pinned | 

Logo inventory: canonical pair (`logo_calcofi.svg` 9,053 B md5 `f9158f13…`, `_light` md5
`0566238d…`) ×9 byte-identical; favicon trio ×5–6 byte-identical; one-off rasters in
hypoxia-story, marmam, SaferSeafood, pollutants; `erddap/content/images/calcofi.svg` is a
different file under a different name.
