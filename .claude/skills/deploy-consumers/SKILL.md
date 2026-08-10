---
name: deploy-consumers
description: Refresh the read-only CalCOFI consumers after a release is frozen, uploaded and promoted to `latest` — Shiny apps on the CalCOFI server (git pull, prep_db.R in the rstudio container, restart.txt) and the static/hosted consumers that redeploy themselves. Use after cutting a release, or when an app is serving stale data.
---


After a new release is frozen, uploaded, and promoted to `latest`, the read-only
consumers must be refreshed. They fall in two buckets:

**Shiny apps** live on the CalCOFI server (`ssh calcofi`). Source repos are cloned
to `/share/github/CalCOFI/{repo}`; `shiny-server` runs inside the **`rstudio`**
Docker container and serves them from `/srv/shiny-server/{app}`, which are symlinks
into those repos (e.g. `db-viz-hex → …/db-viz-hex/app`, `datacheck` +
`db-viz-cruise → …/apps/db-viz-cruise`). Deploy per app:

```bash
ssh calcofi                                            # documented in ../server/README.md
# 1. pull source (and calcofi4r, since prep_db.R does devtools::load_all("../calcofi4r"))
git -C /share/github/CalCOFI/calcofi4r  pull --ff-only
git -C /share/github/CalCOFI/db-viz-hex pull --ff-only
git -C /share/github/CalCOFI/apps       pull --ff-only
# 2. rebuild each app's local DuckDB from the new release — MUST run in the
#    rstudio container (it has R + the pkg deps + network to the public GCS bucket)
docker exec -d rstudio bash -lc 'cd /share/github/CalCOFI/db-viz-hex        && Rscript prep_db.R'
docker exec -d rstudio bash -lc 'cd /share/github/CalCOFI/apps/db-viz-cruise && Rscript prep_db.R TRUE'  # TRUE = force rebuild (else skips if db exists)
# 3. restart the app(s) — touch restart.txt in the served app dir
touch /share/github/CalCOFI/db-viz-hex/app/restart.txt
touch /share/github/CalCOFI/apps/db-viz-cruise/restart.txt
```

Notes: `prep_db.R` is heavy (downloads the release parquet + materializes H3 /
join tables), so background it with `docker exec -d` and tail the log. Apps that
read the release **at runtime** (e.g. `apps/cruises`) have no `prep_db.R` and need
only `git pull` + `restart.txt`. Ports 5432-forward warnings from `ssh calcofi`
are harmless.

**Static / hosted consumers** redeploy themselves on push or on release dispatch:
the **station portal** (`db-viz-station`; the archived 2026 UCSB student capstone
`2026-ucsb-station-data-portal` was forked here) rebuilds its coverage
JSON from the DB via GitHub Actions — `gh workflow run refresh.yml --ref main -R CalCOFI/db-viz-station`
(also runs weekly + on release dispatch); **`calcofi.io/query`** and
**`calcofi.io/schema`** are GitHub Pages and rebuild on push. `calcofi4r` reads
`latest` directly, so it needs no deploy — but keep `calcofi4r/R/match.R`
byte-identical with `db-query/lib/match.js` (verified in CI).

