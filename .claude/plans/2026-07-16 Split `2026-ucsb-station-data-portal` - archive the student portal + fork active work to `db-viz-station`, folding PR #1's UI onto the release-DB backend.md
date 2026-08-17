# Split `2026-ucsb-station-data-portal`: archive the student portal + fork active work to `db-viz-station`, folding PR #1's UI onto the release-DB backend

## Context

`CalCOFI/2026-ucsb-station-data-portal` is a mess with three lineages that diverged at
commit **`eb6c9ec`** (2026-06-10, the UCSB student capstone snapshot; the live GitHub
Pages site at `calcofi.io/2026-ucsb-station-data-portal/`):

1. **Student portal** — everything **through `eb6c9ec`** (the capstone deliverable).
2. **Ben/CalCOFI line** — 14 commits on `main` (now `cb0cf28`) that rebuilt the portal to
   read the **consolidated CalCOFI release DB**: SQL builders (`scripts/build_stations.sql`,
   `build_vars.sql`, `build_crosswalk.sql`) → `public/data/{stations,variables}.json`;
   `app.js` fetches those. This is the "integrated database" approach (recent work).
3. **Intern PR #1** (`bhuang0022`, student-now-intern; branch `year-slider-and-integrated-db`,
   also branched from `eb6c9ec`) — adds a **year-range slider**, **category-filters browse
   panel**, and **decade-means** views, but via a **Python/ERDDAP+oceaninformatics** pipeline
   (`scripts/build_vars.py`, baked `*_station_decade_means.json`). **CONFLICTS** with `main`
   (both rewrote `app.js`/`styles.css`; +203k/−1.8k, mostly data).

**Goal:** freeze the student capstone as an archived contribution, move active development to a
clean `CalCOFI/db-viz-station`, and fold PR #1's **UI** onto the **release-DB backend**.

### Decisions (from the user)
- **Backend/data = the integrated release-DB approach** (keep the SQL builders; do NOT switch
  to bhuang's ERDDAP/Python pipeline).
- **Frontend = extend the current UI** with bhuang's year-slider + category panel + decade-means.
- Archive `2026-ucsb-station-data-portal` **at `eb6c9ec`, same repo name**, as a student
  contribution under `calcofi.io/#students`.
- New repo **`CalCOFI/db-viz-station`** for all the commits since.

---

## Part A — Repo surgery (do FIRST; nothing lost)

1. **Create `CalCOFI/db-viz-station`** (`gh repo create CalCOFI/db-viz-station --public`) and push
   the current full history to it: `main` = `cb0cf28` (student lineage + the 14 release-DB
   commits), **plus** bhuang's branch (`git push … cb0cf28:main` and `pr1:year-slider-and-integrated-db`
   so her work + attribution are preserved for the merge).
2. **Enable Pages** on db-viz-station (branch `main`, path `/`) → `calcofi.io/db-viz-station/`
   (`gh api --method POST repos/CalCOFI/db-viz-station/pages …`; mirror the old repo's Pages/CNAME).
3. **Archive the old repo**: only after (1) verifies db-viz-station has everything —
   `git push origin +eb6c9ec:main` (reset `main` to the student snapshot; its pre-`eb6c9ec`
   history stays), confirm its Pages still serves `calcofi.io/2026-ucsb-station-data-portal/`
   (now the student version), then `gh repo archive CalCOFI/2026-ucsb-station-data-portal`.
   PR #1 (targets this repo) gets closed with a comment pointing to db-viz-station; the actual
   merge is realized in Part B (preserving bhuang's authorship).

## Part B — Fold PR #1's UI onto the release-DB backend (in `db-viz-station`)

Realizes "merge PR #1": port the intern's UI, keep the release-DB data pipeline.

4. **Backend** — extend the SQL builders so `stations.json`/`variables.json` carry what the new
   UI needs, from the release DB (not ERDDAP):
   - `scripts/build_vars.sql` / `build_stations.sql`: add per-station **`station_years`** per
     variable (drives the year slider — bhuang's `app.js` reads `v.station_years`); keep the
     category grouping fields the panel uses.
   - Add per-station **decade-means** for the zoo/euphausiid datasets (`cce-lter_zoodb`,
     `cce-lter_euphausiids` exist in the release DB) — replacing bhuang's baked
     `public/data/*_station_decade_means.json` + `scripts/build_vars.py`/ERDDAP.
   - `refresh.yml` keeps driving the builders (already reads `latest.txt` + release parquet).
5. **Frontend** — port bhuang's components from her `pr1` tree onto the current `public/` (which
   fetches the release-DB JSON), reconciling data-shape (`station_years`, decade-means):
   - `public/index.html`: add `#year-slider`, `#category-filters`, browse panel, resizable
     side-panel markup (bhuang only touched index.html vs base → take hers, wire to current data).
   - `public/app.js`: port the year-slider filter, `activeCategory`/`PANEL_EXCLUDE`/category
     browse logic, and decade-means view — on top of the current `fetch(stations/variables.json)`.
   - `public/styles.css`: merge bhuang's new styles (year-slider, category chips, panel).
6. **Verify locally**: run the extended SQL builders against `latest` (v2026.07.16) to emit the
   JSON, serve `public/`, confirm the year-slider / category panel / decade-means render and
   filter correctly against release-DB data.

## Part C — Landing page + consumers

7. **`CalCOFI/CalCOFI.github.io` `_data/products.yml`**:
   - Add a **`section: students`** card for `2026-ucsb-station-data-portal`
     (`status: archived`, `credits: {org: UCSB, year: 2026, team: [<pre-eb6c9ec authors>, bhuang0022]}`,
     `live_url: https://calcofi.io/2026-ucsb-station-data-portal/`, `source_url:` the archived repo).
   - Add a **`section: data`** (or `explore`) card for **`db-viz-station`** (the active portal,
     `live_url: https://calcofi.io/db-viz-station/`, `source_url:` new repo).
8. **Repoint consumers** from the old portal → `db-viz-station`: `workflows/CLAUDE.md` deploy
   runbook + station-portal refresh note; `workflows/RUNBOOK.md`; `uptime/.upptimerc.yml` (if it
   lists the portal); the `gh workflow run refresh.yml` trigger (now `--repo CalCOFI/db-viz-station`);
   any app-URL inventory / cross-links (see memory `project_app_urls_uptime`).

---

## Verification

- `calcofi.io/db-viz-station/` serves the **new UI** (year-slider + category panel + decade-means)
  reading **release-DB-derived** `stations.json`/`variables.json` (not ERDDAP).
- `2026-ucsb-station-data-portal` is **archived** (read-only), Pages still at
  `calcofi.io/2026-ucsb-station-data-portal/` showing the **student** version, listed under
  `calcofi.io/#students` (archived badge + credits).
- `db-viz-station` `refresh.yml` rebuilds coverage JSON (incl. `station_years` + decade-means)
  from `latest.txt`; a manual `gh workflow run refresh.yml -R CalCOFI/db-viz-station` succeeds.
- `git -C db-viz-station log` shows the full lineage incl. bhuang's commits (attribution preserved).
