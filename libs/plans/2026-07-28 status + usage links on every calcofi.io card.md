# calcofi.io: restructure cards, add status + usage links, new Hugo analytics site

## Context

The calcofi.io landing page has accumulated 31 cards across five sections (`featured`, `explore`,
`data`, `build`, `students`), including several legacy apps, infrastructure that nobody browses to,
and display names that don't match the repo/app names used everywhere else. From the front door
there is also no way to answer "is it up?" or "does anyone use it?".

This change does four things:

1. **Prunes and restructures** the cards to 24 across `Apps / Services / Developer / Documentation /
   Student Contributions`, with canonical names (`Integrated App` → `db-viz-hex`).
2. **Renames the uptime slugs to match**, so every surviving card links to
   `status.calcofi.io/history/<canonical-slug>` (today they slugify to `integrated-app`,
   `mar-mam-app`, `datacheck-app` — unrelated to anything else).
3. **Adds a `usage` link** to a new **Hugo** site at `calcofi.io/analytics/`, refreshed daily from
   GA4, plus a Google-Sheet summary for db-viz-hex.
4. **Tags the six surviving sites that emit no GA4 at all**, so the usage link has data behind it.

The analytics repo is deliberately the first Hugo site in the org — a clean reference for the
possible later migration of `db-schema` and `CalCOFI.github.io` off Jekyll. Its layouts port the
existing CSS variables and header/footer so that migration is mostly copy-paste.

**Scale:** ~11 repos. Phase A is standalone and ships immediately; E must land last so no published
link 404s.

---

## Final card inventory (drives every phase)

| section | cards (title = canonical name) | status | usage |
|---|---|---|---|
| **Apps** | `db-viz-station`, `db-viz-hex`, `db-viz-cruise`, `ctd-viz`, `oceano` (keeps superseded badge), `pollutants` | ✅ all 6 | ✅ all 6 |
| **Services** | `erddap`, `storage` *(new)* | ✅ both | — (no HTML surface we control) |
| **Developer** | `calcofi4r`, `calcofi4db`, `db-query`, `db-schema`, `workflows` | ✅ all 5 | ✅ all 5 |
| **Documentation** | `docs`, `server` | ✅ (`server` → `shiny-server` monitor) | ✅ `docs` only |
| **Student Contributions** | unchanged, titles stay human-friendly: Larvae Dashboard, Station Data Portal, CA Ocean & Coastal Monitoring Map, Marine Mammal App, SaferSeafood App, Capstone App, Hypoxia Story, 75th Anniversary Timeline, Offshore Wind Monitoring | ✅ 7 | ✅ 7 |

**Dropped entirely** (card + monitor + usage): `api`, `copernicus`, `dashboard`, `tile`,
`larvae-cinms`, `viz-gallery` (legacy) and `status`, `api-h3t` (linked elsewhere / too technical).
No analytics card — it's reachable from every card's `usage` link. `file-server` stays commented out.

**No links** on `calcofi-75th-timeline` (KnightLab CDN) and `offshore-wind-monitoring`
(third-party shinyapps.io) — nothing to monitor or tag.

→ 24 cards; 22 get `status`, 19 get `usage`.

Dropping `api` also removes the one dead link: `https://api.calcofi.io/` returns **502** right now
(verified this session), so it would otherwise have shipped a permanently red status page.

---

## Phase A — restructure `CalCOFI.github.io` (standalone, ship first)

**`_data/products.yml`** — rewrite `sections:` to the five above (keep the emoji/blurb idiom; reuse
the user's wording for Apps: *"Visualize and download subsets of data from the integrated database
via these applications oriented by station, hexagons or cruise"*, and Developer: *"R packages with
documented functions"* extended to cover db-query/db-schema/workflows). Then:

- delete the 8 dropped product entries (and their `images/*.png`);
- set `title:` to the canonical name for every non-student card;
- move `key: oceano`'s `superseded_by: db-viz-hex` badge through unchanged;
- add the new `storage` entry (no `source_url` — it's a Caddy vhost in `CalCOFI/server`, see
  `server/caddy/Caddyfile:25-50`), with an extra deep link:

```yaml
  - key: storage
    title: storage
    section: services
    live_url: https://storage.calcofi.io/
    img: images/storage.png
    description: >-
      Browse the public CalCOFI cloud buckets over HTTPS — database releases,
      source files and project outputs, with folder listings.
    extra_links:
      - { label: netcdf, url: "https://storage.calcofi.io/calcofi-files-public/netcdf/" }
```

**`_includes/product_card.html`** — render `extra_links` in the existing `.links` row, immediately
after `source ↗`, using the same `↗` convention:

```liquid
      {%- for l in p.extra_links -%}<a href="{{ l.url }}">{{ l.label }} ↗</a>{%- endfor -%}
```

**Also:** update the header comment (`products.yml:1-7`) and README's field list; regenerate
`images/storage.png` via `scripts/shots.sh` + `_data/shots.yml`.

---

## Phase B — `CalCOFI/uptime`: 24 monitors, canonical slugs

**File: `uptime/.upptimerc.yml`** — the single source of truth; `.github/workflows/*` and `README.md`
are Upptime-generated, never hand-edit.

Rewrite `sites:` to exactly the monitored set above. Set `name:` to the canonical id **and pin
`slug:` explicitly** — `@sindresorhus/slugify` decamelizes and its digit handling isn't worth
betting 24 published URLs on (`calcofi4r` could plausibly slug as `calcofi-4r`):

```yaml
  - name: db-viz-hex
    slug: db-viz-hex
    url: https://app.calcofi.io/db-viz-hex/
    maxResponseTime: 30000        # Shiny cold-starts; app.calcofi.io/* only
```

| renames | additions | removals |
|---|---|---|
| `integrated-app`→`db-viz-hex`, `ctd-app`→`ctd-viz`, `datacheck-app`→`db-viz-cruise`, `mar-mam-app`→`marmam`, `safer-seafood-app`→`saferseafood`, `oceano-app`→`oceano`, `pollutants-app`→`pollutants`, `capstone-app`→`capstone` | `db-viz-station`, `ucsb-larvae-dashboard` (Shiny→30000), `db-query`, `db-schema`, `workflows`, `docs`, `calcofi4r`, `calcofi4db`, `erddap`, `storage`, `ucla-monitoring-map`, `ucsb-station-portal`, `hypoxia-story` | `copernicus-app`, `dashboard-app`, `tile-server` (cards dropped) |

Unchanged: `shiny-server`, `file-server`, `home-website`.

URL gotchas verified live: `erddap` → `https://erddap.calcofi.io/erddap/index.html` (root
redirects); `saferseafood` path is case-sensitive `/SaferSeafood/`; `storage` root returns a 404
text banner by design (`Caddyfile:38-49`) so monitor
`https://storage.calcofi.io/calcofi-db/ducklake/releases/` instead.

**Preserve history in the same commit:** `git mv history/integrated-app.yml history/db-viz-hex.yml`
(and the other 7 renames). Upptime reuses the `startTime` already in the file and the prune step
then leaves them alone. Caveat: uptime *percentages* come from the commits touching
`history/<slug>.yml` and GitHub doesn't follow renames, so percentages restart regardless —
unavoidable, and already accepted.

**Same push:** `.upptimerc.yml:157` fetches `…/CalCOFI/uptime/master/history/` but the branch is
`main`; it works today only via GitHub's rename redirect.

**Sequence** (per `uptime/OPERATIONS.md` — all workflows share one concurrency group, so an
in-flight check can cancel Setup CI):

```bash
gcloud scheduler jobs pause calcofi-uptime-dispatch --project=ucsd-sio-calcofi --location=us-central1
# push .upptimerc.yml + history/ renames
gh run watch -R CalCOFI/uptime               # Setup CI regenerates workflows + README
gh workflow run site.yml -R CalCOFI/uptime --ref main
gcloud scheduler jobs resume calcofi-uptime-dispatch --project=ucsd-sio-calcofi --location=us-central1
```

---

## Phase C — GA4 on the six untagged survivors

One hostname-guarded snippet; only `CONTENT_GROUP` changes. A hostname guard rather than
calcofi.io's `{% if jekyll.environment == "production" %}` gate, because four of the six aren't
Jekyll-with-layouts and one is built by `actions/jekyll-build-pages@v1` (no `JEKYLL_ENV` control):

```html
<script>window.__CC_GA = location.hostname.endsWith("calcofi.io");</script>
<script async src="https://www.googletagmanager.com/gtag/js?id=G-0HVK8TDMCF"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){ dataLayer.push(arguments); }
  if (window.__CC_GA) {
    gtag('js', new Date());
    gtag('config', 'G-0HVK8TDMCF', { content_group: 'CONTENT_GROUP' });
  }
</script>
```

Canonical copy in `analytics/snippets/gtag-site.html` with a "copy from here" banner — the same
convention `calcofi4r::cc_ga_html()` uses for the app snippets.

| repo | file | `content_group` |
|---|---|---|
| `db-schema` | `_layouts/default.html` | `db-schema` |
| `workflows` | `_output/_layouts/default.html` | `workflows` |
| `db-viz-station` | `public/index.html` | `db-viz-station` |
| `2026-ucla-cal-ocean-coastal-monitoring-map` | `web/index.html` | `ucla-monitoring-map` |
| `2026-ucsb-station-data-portal` | `public/index.html` | `ucsb-station-portal` |
| `hypoxia-story` | `index.html` | `hypoxia-story` — **not cloned locally**, clone first |

Three one-liners so attribution needs no path special-casing: add
`{ content_group: 'db-query' }` to `db-query/_includes/google-analytics.html` (it stays on the
**apps** property), and the equivalent in `calcofi4r/inst/_pkgdown.yml` + `calcofi4db/inst/_pkgdown.yml`
(effective next pkgdown build). Leave `docs` — Quarto emits its own config call; attribute by path.

The dropped apps (copernicus, dashboard) keep their GA4 tags — harmless, and removing them is
pointless churn. They simply get no card and no report page.

---

## Phase D — new repo `CalCOFI/analytics` (Hugo) → calcofi.io/analytics/

Hand-rolled minimal theme, no upstream module. Layouts port the dark/light CSS variables, pre-paint
theme script and dual-logo header from `db-schema/_layouts/default.html` so the site matches
calcofi.io and doubles as the migration reference.

```
analytics/
├── hugo.toml                        # baseURL https://calcofi.io/analytics/
├── layouts/_default/{baseof,list,single}.html
├── layouts/partials/{head,header,footer,chart-area,chart-bars,stat-tile,geo-map}.html
├── content/_index.md                # overview page
├── content/products/<slug>.md       # GENERATED stub per product (front matter only)
├── data/usage/<slug>.json           # GENERATED — .Site.Data.usage
├── data/registry.yml                # HAND-MAINTAINED — product → property + attribution
├── static/data/{daily,geo,events}/<slug>.csv, static/data/hex_log/*.csv   # published + downloadable
├── assets/css/style.css             # Hugo Pipes; ported palette
├── assets/js/app.js
├── snippets/gtag-site.html          # canonical copy of the Phase-C snippet
├── scripts/{refresh,ga4,sheet,build}.py, scripts/requirements.txt
├── .github/workflows/{refresh,pages}.yml
└── README.md, OPERATIONS.md
```

Hugo specifics: `hugo --gc --minify` in CI via `actions/setup-hugo` (or the `hugo-extended` deb);
publish `public/` with `actions/upload-pages-artifact` + `deploy-pages`, matching how the Jekyll
siblings deploy. Per-product URL is `/analytics/<slug>/` from `content/products/<slug>.md`.
Generated stubs (not a Hugo taxonomy trick) so a missing product page is impossible to introduce
silently.

**Join key = `contentGroup`, not `app_name`.** `app_name` is an *event parameter*: querying it
needs a registered custom dimension in GA4 Admin plus a 24–48 h backfill gap. `contentGroup` is a
**built-in** Data API dimension already populated by `calcofi4r::cc_ga_js()`
(`calcofi4r/R/analytics.R`) on every app, and Phase C adds it to the rest. No admin step.

**`data/registry.yml`** maps each card's `usage` slug → property + attribution: a row belongs to a
product if `contentGroup ∈ content_groups`, else if `hostName` + `pagePath` matches
`path_prefixes`. The path leg is required for `docs`/`calcofi4r`/`calcofi4db` (no content group)
and for every product's pre-instrumentation history. One real mismatch to encode here: card key
`ucsb-larvae-dashboard` vs GA4 `content_group: larvae-dashboard` — map it, don't rename the app id
and orphan its history.

**GA4 reports** (`scripts/ga4.py`, `google-analytics-data` + `google-auth`), per property, paginated:

| report | dimensions | metrics | range |
|---|---|---|---|
| usage over time | `date`, `contentGroup` | `activeUsers`, `newUsers`, `sessions`, `engagedSessions`, `screenPageViews`, `eventCount`, `userEngagementDuration` | rolling 35 d (full backfill first run) |
| path fallback | `date`, `hostName`, `pagePath` | same | same, filtered to registry prefixes |
| users over space | `contentGroup`, `country`, `countryId`, `region` | `activeUsers`, `sessions` | rolling 365 d |
| top events / pages | `contentGroup`, `eventName` / `pagePath` | `eventCount`, `activeUsers` | rolling 90 d |

Derive in Python, never request: avg engagement time per user = `userEngagementDuration /
activeUsers`; engaged-session rate; views/user; 28-day totals + Δ vs prior 28 d. **Upsert into
append-only `static/data/daily/<slug>.csv`** so the site survives GA4's 2-month default retention
and each daily pull stays cheap. Index-page footnote: the two properties can't be de-duplicated, so
org totals are a sum.

**Sheet summarizer** (`scripts/sheet.py`, db-viz-hex only) reads `'db-viz-hex'!A:P`; columns are
`calcofi4r::cc_log_header()`. **First statement drops `ip`, `user_agent`, `session`;
`client_id`/`session_id` are used for distinct counts then discarded**, with a closing assert that
none survive into any written column. Outputs `daily.csv`, `events.csv` (p50/p95 `ms`, error rate,
from `cc_track_query`'s reserved numeric columns), `params.csv` (top-20 taxa/env_var — the detail
GA4 buckets into `(other)`), `versions.csv` (adoption per deployed SHA). Renders as a "Query log"
section only on `/analytics/db-viz-hex/`.

**`refresh.yml` — one workflow that fetches, commits, builds AND deploys.** A push made with
`GITHUB_TOKEN` never triggers another workflow, and `[skip ci]` suppresses `on: push` — the existing
`db-viz-station/.github/workflows/refresh.yml` has exactly this bug (worth a one-line follow-up fix
there). Triple trigger (`workflow_dispatch` + `schedule` + `repository_dispatch: [analytics]`),
committer `calcofi-bot <bot@calcofi.io>`, `git diff --cached --quiet` guard, **no `[skip ci]`**.
GitHub drops most public-repo cron, so add a `calcofi-analytics-dispatch` Cloud Scheduler job
mirroring `calcofi-uptime-dispatch`, plus a "data as of <date>" footer that turns warn-colored past
48 h so a dead cron is visible rather than silently frozen.

**Charts** — load the `dataviz` skill before writing any chart code. Hero figure (28-day active
users); KPI stat-tile row with Δ; single-series area chart with 7-day mean; **sortable table with
sparklines** for comparing 19 products (never 19 colored lines); Leaflet 1.9.4 circles (radius ∝
√users) from GA4 `countryId` + a ranked table twin; horizontal bars for top events. One hue
(`--accent`) plus gray — no categorical palette, no dual-axis, a `<details>` table twin per chart,
one delegated tooltip listener copying `db-viz-station/public/app.js:1170-1188`.

**Secrets:** `GCP_SA_KEY` (a **new** `calcofi-analytics@` SA with *no* IAM roles — do not reuse
`calcofi-admin@`, which holds objectAdmin on three buckets) and `USAGE_SHEET_ID` =
`1fBUZlq8zIjWjfYROOkgcnWdHSNxIV2TUuZAvzpt75KU`. Property IDs live in committed `registry.yml`:
apps = `509537765`; site property (`G-0HVK8TDMCF`) **must be looked up**.

---

## Phase E — the two links on every card (last)

**`_data/products.yml`** — two keys per product. **Not `status:`**, which already means lifecycle
(`interim|superseded|archived`) and is used twice in the template:

```yaml
    uptime: db-viz-hex     # slug at status.calcofi.io/history/<slug>
    usage:  db-viz-hex     # slug at calcofi.io/analytics/<slug>/
```

Values equal `key` everywhere except `server` → `uptime: shiny-server`. Omit per the inventory table.

**`_config.yml`**: `status_url: "https://status.calcofi.io"`,
`analytics_url: "https://calcofi.io/analytics"`.

**`_includes/product_card.html`** — append inside the existing `.links` div; `open`/`source`/
`extra_links` untouched:

```liquid
      {%- if p.uptime or p.usage -%}
      <span class="links-meta">
        {%- if p.uptime -%}<a href="{{ site.status_url }}/history/{{ p.uptime }}" title="uptime history for {{ p.title }}">status</a>{%- endif -%}
        {%- if p.usage  -%}<a href="{{ site.analytics_url }}/{{ p.usage }}/" title="usage analytics for {{ p.title }}">usage</a>{%- endif -%}
      </span>
      {%- endif -%}
```

**`style.css`** (after `.prod-card .links` at :176) — `.links` is flex+wrap with no
`justify-content`, so `margin-left:auto` right-aligns the pair and lets it wrap to its own line on
narrow cards. Muted color reuses the `.header-links a` idiom already in the file, so these read as
metadata rather than peers of `open ↗`:

```css
.prod-card .links .links-meta { margin-left: auto; display: inline-flex; gap: 0.7rem; white-space: nowrap; }
.prod-card .links .links-meta a { color: var(--muted); }
.prod-card .links .links-meta a:hover { color: var(--accent); text-decoration: none; }
```

---

## Sequencing

**A** (restructure) ships immediately, independent. **C** (GA4 tags) next, since GA4 needs 24–48 h
before the data is worth showing. **B** (uptime) in parallel with C. Then the human Google setup,
then **D**, then **E** — only once both link targets resolve.

## Human-only steps (outside git)

1. Look up the numeric **property ID for `G-0HVK8TDMCF`** (GA4 → Admin → Property Settings).
2. `gcloud iam service-accounts create calcofi-analytics --project=ucsd-sio-calcofi` (**no IAM
   roles**); JSON key → repo secret `GCP_SA_KEY`.
3. Enable `analyticsdata.googleapis.com` + `sheets.googleapis.com`.
4. Add the SA as **Viewer** on both GA4 properties (UI-only).
5. Share the usage-log Sheet with the SA (Viewer). While there, delete the decoy `1VQcfdP3…`
   "calcofi.io apps log" with the old 10-column header.
6. Raise GA4 data retention to **14 months** on both properties.
7. Create `CalCOFI/analytics`; Pages source = GitHub Actions.
8. Create `calcofi-analytics-dispatch` Cloud Scheduler job; pause/resume `calcofi-uptime-dispatch`
   around the Phase-B push.

## Verification

**Uptime** — `curl` is invalid here: `status.calcofi.io/history/<slug>` 404s for *every* slug
(Sapper SPA renders client-side; verified). Use instead:
```bash
ls uptime/history/*.yml | wc -l          # expect 24
curl -s https://raw.githubusercontent.com/CalCOFI/uptime/main/history/summary.json \
  | python3 -c "import json,sys;print(sorted(x['slug'] for x in json.load(sys.stdin)))"
```
Diff against every `uptime:` in products.yml (must be a superset), then browse one renamed
(`/history/db-viz-hex`) and one new (`/history/storage`) link.

**GA4 tags** — `curl -s https://calcofi.io/db-schema/ | grep -c G-0HVK8TDMCF` → 1 per site, then
GA4 **Realtime → Content group** after visiting each in a browser (the only check that proves the
tag *fires*).

**Analytics** — after the first `workflow_dispatch`: `gh run watch` all green; `wc -l
static/data/daily/*.csv` non-empty; loop every registry slug through
`curl -o /dev/null -w '%{http_code}' https://calcofi.io/analytics/<slug>/` → all 200 (valid here —
Hugo emits real pages); `head -1 static/data/hex_log/daily.csv` shows **no `ip`/`user_agent`**; open
`/analytics/db-viz-hex/` for the Query-log section; toggle light/dark; hover a bar for one tooltip.

**Cards** — `bundle exec jekyll serve`, confirm the five new sections, canonical titles, the
`storage` card's `netcdf ↗`, and that status/usage sit flush-right on the `open`/`source` line and
wrap to their own right-aligned line on a narrow card. After deploy:
`curl -s https://calcofi.io/ | grep -c links-meta` → 22.

## Privacy

GA4 never exposes raw IPs to the Data API (geo resolved server-side), so **prefer GA4 geo dimensions
for the map**. The Sheet is the only PII surface and is stripped at read (above). Publish `country`
always; `region`/`city` only at `activeUsers ≥ 10`, folding the rest into `Other`. Cap the `params`
table at top-20 so a one-off free-text value can't fingerprint. State all of this in
`analytics/README.md` — the site is public and the obvious question is "what are you collecting?"

## Also

Record in memory: prefers **Hugo over Jekyll** for new static sites (render speed, flexibility);
`db-schema` and `CalCOFI.github.io` are migration candidates once the analytics site proves it out.
