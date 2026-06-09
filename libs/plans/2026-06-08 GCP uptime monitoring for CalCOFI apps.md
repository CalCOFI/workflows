# Plan: CalCOFI uptime monitoring via Upptime (self-contained on GitHub)

## Context

The CalCOFI Shiny apps run on a Google Cloud VM (`shiny-server`) behind Caddy, served publicly at
**`https://app.calcofi.io/<app>/`**. There is **no uptime monitoring** today — outages (e.g.
`tile.calcofi.io/` was returning **502** during planning) go unnoticed until a user complains.

The original question was whether Google Cloud Monitoring could do this. It can (multi-region Uptime
Checks + alert policies), but the goal evolved toward a **dedicated, self-contained GitHub repo with a
visual, themed status page** matching the sibling sites `schema` and `query`. The best fit for that is
**[Upptime](https://upptime.js.org/)** — a GitHub-Actions-powered uptime monitor that checks endpoints
on a cron, commits history to the repo, opens/closes a GitHub Issue per incident, and publishes a
color-coded status page (with response-time histograms by period) to GitHub Pages. No servers, no GCP
credentials, no external service.

### Verified facts (this session)
- `schema` / `query` are **Jekyll** sites at `calcofi.io/schema` and `/query` (org `CalCOFI.github.io`
  + apex CNAME), sharing a dark/light palette, the calcofi.io logo (`assets/logo_calcofi.svg` +
  `_light.svg`), and favicons. Both render client-side from JSON.
- **No `uptime/` repo exists yet**; no Upptime in use.
- Apps return HTTP 200 but **cold-start in 11–16s**.
- **GitHub Actions**: public repos = unlimited free minutes; cron minimum = **5 min** (Upptime's
  default), best-effort (5–30 min delays possible under load); cron auto-disables after 60 days of repo
  inactivity, but Upptime's per-run commits keep it active.
- **Upptime timeout**: a site is only **degraded** (still "up") if slower than `maxResponseTime`
  (**default 30,000 ms**). Our 11–16s apps register **green** by default — no false "down".
- **Upptime theming**: `status-website` supports `name`, `logoUrl`, `faviconSvg`, `theme`, `navbar`,
  `introTitle/introMessage`, **and `css`/`js`/`links`/`scripts` injection** — enough to apply the
  calcofi.io logo, palette, and favicon via config alone (no fork).

### Decisions (from user)
- **Tool:** Upptime, in a new **public** repo `CalCOFI/uptime` (public → free unlimited Actions; it
  only holds public URLs + status data).
- **Status page URL:** **`status.calcofi.io`** (subdomain via Upptime `cname` + one DNS record — avoids
  the base-path hacking that `calcofi.io/uptime` would need).
- **Notifications:** **GitHub Issues + repo watchers** (Upptime-native; issue per outage, auto-closed on
  recovery). No Google Group / GCP / Slack for now.

## Setup steps

1. **Create the repo from the Upptime template** (public):
   `gh repo create CalCOFI/uptime --template upptime/upptime --public --clone`
   Upptime's "Setup CI" workflow self-configures the repo on first run.
2. **Add the `GH_PAT` secret** (manual): a PAT with contents + issues + workflow + pages permissions on
   `CalCOFI/uptime`, stored as repo secret `GH_PAT`. Upptime needs it to commit results, manage issues,
   and trigger its workflows. (Fine-grained PAT scoped to the one repo, or a classic `repo`+`workflow`
   PAT.)
3. **Edit `.upptimerc.yml`** — the single source of truth (owner/repo, `sites`, `status-website`,
   `assignees`). Content below.
4. **Enable GitHub Pages** on the repo, source = `gh-pages` branch (Upptime's static-site workflow
   deploys there). Upptime writes the `CNAME` file from `status-website.cname`.
5. **DNS**: add a CNAME record **`status.calcofi.io` → `calcofi.github.io`** (wherever calcofi.io DNS is
   managed). Set the repo's Pages custom domain to `status.calcofi.io`.
6. **First run**: dispatch the "Uptime CI" workflow manually to seed `history/` + `api/`, confirm the
   static-site workflow deploys, then it self-runs every 5 min.

## `.upptimerc.yml` — endpoints

Derived from the authoritative `/srv/shiny-server` symlinks (URL path → repo). Monitor `int` only (the
`int-app` alias is identical); skip `sample-apps`.

```yaml
owner: CalCOFI
repo: uptime
sites:
  # --- production Shiny apps (app.calcofi.io) ---
  - { name: Oceano,        url: https://app.calcofi.io/oceano/,       maxResponseTime: 30000 }
  - { name: CTD Viz,       url: https://app.calcofi.io/ctd/,          maxResponseTime: 30000 }
  - { name: Datacheck,     url: https://app.calcofi.io/datacheck/,    maxResponseTime: 30000 }
  - { name: Dashboard,     url: https://app.calcofi.io/dashboard/,    maxResponseTime: 30000 }
  - { name: Copernicus,    url: https://app.calcofi.io/copernicus/,   maxResponseTime: 30000 }
  - { name: Interactive,   url: https://app.calcofi.io/int/,          maxResponseTime: 30000 }
  - { name: MarMam,        url: https://app.calcofi.io/marmam/,       maxResponseTime: 30000 }
  - { name: Pollutants,    url: https://app.calcofi.io/pollutants/,   maxResponseTime: 30000 }
  - { name: SaferSeafood,  url: https://app.calcofi.io/SaferSeafood/, maxResponseTime: 30000 }
  - { name: Capstone,      url: https://app.calcofi.io/capstone/,     maxResponseTime: 30000 }
  # --- dev apps (optional; comment out to disable) ---
  - { name: Oceano (dev),  url: https://app.calcofi.io/oceano-dev/,   maxResponseTime: 30000 }
  - { name: Casts,         url: https://app.calcofi.io/casts/,        maxResponseTime: 30000 }
  - { name: Hex Density,   url: https://app.calcofi.io/hex/,          maxResponseTime: 30000 }
  - { name: Taxa (dev),    url: https://app.calcofi.io/taxa-dev/,     maxResponseTime: 30000 }
  - { name: up2db,         url: https://app.calcofi.io/up2db/,        maxResponseTime: 30000 }
  # --- supporting infrastructure ---
  - { name: Shiny server,  url: https://app.calcofi.io/ }
  - { name: Tile server,   url: https://tile.calcofi.io/index.json }   # use a real path; "/" 502s
  - { name: File server,   url: https://file.calcofi.io/ }
  - { name: Main site,     url: https://calcofi.io/ }
```

Notes:
- `maxResponseTime: 30000` on apps documents intent (30s headroom over the 11–16s cold start → green;
  flags genuinely stuck loads as degraded). Infra endpoints are fast → leave default.
- **Per-endpoint expected codes / redirects to verify at setup**: confirm `file.calcofi.io/` and
  `tile.calcofi.io/index.json` return 200 (add `expectedStatusCodes` if any redirect). A disabled check
  = comment out its line (the "easy to turn off later" the user asked for).
- Optional deeper check (Tier-2 flavor): add `__dangerous__body_down` to match a known string so a
  shiny-server error page that still returns 200 is caught as down.

## `.upptimerc.yml` — theming + notifications

```yaml
status-website:
  cname: status.calcofi.io
  name: CalCOFI Status
  introTitle: "CalCOFI Status"
  introMessage: "Live status of CalCOFI apps and services."
  theme: dark
  logoUrl: https://calcofi.io/schema/assets/logo_calcofi.svg
  faviconSvg: https://calcofi.io/schema/assets/logo_calcofi.svg
  navbar:
    - { title: Home,   href: https://calcofi.io }
    - { title: Schema, href: https://calcofi.io/schema }
    - { title: Query,  href: https://calcofi.io/query }
    - { title: GitHub, href: https://github.com/CalCOFI/uptime }
  css: |
    /* map Upptime theme vars to the calcofi.io palette (--accent #4dabf7, bg #1b1d20,
       panel #24272b). Exact selector/var names finalized by inspecting the built page. */

assignees:
  - bbest    # auto-assign incident issues so the maintainer is notified
```

- **Notifications**: native GitHub Issues. Stakeholders should **Watch** `CalCOFI/uptime` (or be added
  as `assignees`) to receive incident emails. No external channel configured.
- **Logo/favicon** reuse the already-deployed `schema` assets by absolute URL (no need to copy files).
  If a light-on-dark variant reads better, swap to `logo_calcofi.svg` (white text) which already suits a
  dark page.
- Keep `workflowSchedule.uptime: "*/5 * * * *"` (the 5-min floor). Response-time graphs/histograms are
  produced automatically by Upptime's `graphs`/`responseTime` workflows — the visualization the user
  liked, no extra work.

## Verification
1. Dispatch "Uptime CI" → confirm commits land in `history/` and `api/`, and each site shows up/down +
   response time.
2. Confirm the static-site workflow deploys to `gh-pages`; after DNS propagates, load
   **https://status.calcofi.io** and verify the calcofi logo, dark palette, navbar links, and per-app
   bars + response-time histograms render.
3. Confirm slow apps (Oceano, Interactive) show **green** with ~11–16s response times (not degraded).
4. **Live incident test**: temporarily point one site at a bad path (e.g. `/oceano-NOPE/`), confirm an
   Issue opens and watchers are emailed, then revert and confirm the Issue auto-closes.

## Tier 2 (future — documented, not built)
The user flagged `shinytest2` for deeper checks. It's a *functional testing* framework (drives headless
Chrome via `chromote`), best run in **CI / pre-deploy** against app source (add a `tests/` dir per app —
none exist today), or on a schedule against live apps. A lighter middle step within Upptime is
`__dangerous__body_down`/`body_degraded` content matching to catch "200-but-broken" app pages. GCP
Uptime Checks remain an option if multi-region or sub-5-min paging is ever needed.

## Post-plan housekeeping (memory — deferred; plan mode blocks memory writes)
Save: prefer `app.calcofi.io` URLs; deployed apps map via `/srv/shiny-server` symlinks (path → repo) on
the rstudio docker instance; sibling sites `schema`/`query` are Jekyll on GitHub Pages at
`calcofi.io/<name>` sharing a dark/light theme + logo; uptime monitoring chosen = Upptime in public repo
`CalCOFI/uptime` at `status.calcofi.io` (GCP Monitoring considered but not used).
