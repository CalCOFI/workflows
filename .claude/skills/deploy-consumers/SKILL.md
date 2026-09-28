---
name: deploy-consumers
description: Refresh the read-only CalCOFI consumers after a release is frozen, uploaded and promoted to `latest`. Runs scripts/deploy_consumers.sh, which handles the h3t API's held-open database and the Varnish tile cache that hand-deploys forget. Use after cutting a release, or when an app is serving stale data.
---

# Deploy the consumers

**Run the script. Do not do this by hand.**

```bash
bash scripts/deploy_consumers.sh                 # from the workflows repo
bash scripts/deploy_consumers.sh --skip-prep     # app databases already rebuilt
bash scripts/deploy_consumers.sh --release v2026.08.10   # pin, else reads latest.txt
```

It resolves the release from `latest.txt`, then: pulls sources → rebuilds the two
app databases inside the `rstudio` container → restarts the h3t API and bans the
cached tiles → re-points the PostgreSQL `release.*` views → touches `restart.txt`
→ **verifies all three endpoints return 200 and prints which file the h3t API
actually has open** → dispatches the hosted consumers, the docs book included
(step 6, below). It is `set -euo pipefail` and exits non-zero on the first real
failure, because a half-deployed consumer set is worse than an obviously failed
one.

`test_release.qmd` invokes it automatically when `CALCOFI_DEPLOY=true`, so a
normal `tar_make()` still only builds and promotes — deploying stays one
deliberate flag.

## Why not by hand

The script exists because every consumer here drifted at least once when its
update lived only as prose. Two steps are invisible until someone reports stale
data, and both were missed in a by-hand deploy on 2026-08-10 that otherwise
looked completely successful:

- **The h3t API opens `calcofi_latest.duckdb` and HOLDS IT OPEN.** `prep_db.R`
  advances that symlink, but the running container keeps serving the old inode.
  Nothing errors — the map is just quietly on the previous release. Step 5's
  health check prints `db_mtime`, the only field that reveals which file is
  actually open, which is why the script verifies rather than assuming.
- **Varnish keys tiles on a URL carrying the release tag**, so anything already
  cached survives the new data until it is banned.

Restart the h3t container with `docker compose restart`, never `up -d`: restart
reuses the same container so its docker IP is unchanged and Varnish keeps
resolving it. Recreating it would need Varnish restarted too.

## The hosted consumers (step 6)

Hosted consumers redeploy themselves on GitHub Actions rather than on the CalCOFI
server, so step 6 only fires the dispatch — non-fatally, since `gh` may be absent
or unauthorized on the machine cutting the release:

```bash
gh workflow run refresh.yml     --ref main -R CalCOFI/db-viz-station   # coverage JSON
gh workflow run refresh.yml     --ref main -R CalCOFI/ctd-transects    # section shards
gh workflow run render_book.yml --ref main -R CalCOFI/docs             # the docs book
```

**The docs book is a release consumer, and the least obvious one.** `CalCOFI/docs`
renders through `libs/pre-render.R`, which snapshots the **promoted** release's
sidecars (`catalog.json`, `integrity.json`, `metadata.json`, `relationships.json`,
`datasets.json`, the `dataset` table, the release notes) plus this repo's
`metadata/` registries, and every generated table in the book reads that snapshot.
Until the book re-renders it describes the *previous* release — no error, no stale
marker, just last release's inventory, keys, versions and datasets on
calcofi.io/docs. `render_book.yml` also accepts a `repository_dispatch` of type
`release-promoted` and runs on a weekly schedule, so the dispatch here is belt and
braces rather than the only path.

`calcofi.io/db-query` and `calcofi.io/db-schema` are GitHub Pages and rebuild on
push. `calcofi4r` reads `latest` directly and needs no deploy — but keep
`calcofi4r/R/match.R` byte-identical with `db-query/lib/match.js` (CI verifies).

## If `db-viz-hex`'s `prep_db.R` is OOM-killed

Symptom: `exit 137`, log truncated mid-layer with **no error text**, app keeps
serving its previous `data/calcofi_v*.duckdb`. The spatial join is not spillable,
so `memory_limit` cannot contain it. See that repo's `prep_db.R` for the vertex
subdivision and the `CC_SPATIAL_BUCKETS` / `CC_SPATIAL_BATCH` knobs; restarting
ERDDAP first frees ~4.8 GB of the 16 GB box.
