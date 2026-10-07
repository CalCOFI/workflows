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
gh workflow run refresh.yml     --ref main -R CalCOFI/CalCOFI.github.io # calcofi.io: datasets, measurements, species
gh workflow run render_book.yml --ref main -R CalCOFI/docs             # the docs book
```

**calcofi.io is a release consumer too** (`CalCOFI/CalCOFI.github.io`, Jekyll). Its
`scripts/fetch_release.sh` pulls the promoted release's `datasets.json`, `measurements.json`
and `taxa.json`, and `_plugins/{datasets,measurements,species}.rb` draw `/datasets/`,
`/measurements/` and `/species/` from those and nothing else. It followed a promotion only
through `test_release.qmd`'s `gh_dispatch` table and a Monday cron until the dispatch was
added to step 6; a dispatch that only fires says "dispatched" even when the run goes red.

**Step 6b verifies it.** The script polls the live `/data.json`, `/measurements/` and
`/species/` (cache-busted, up to ~12 min each) and requires the promoted version string on
every one; a page that never shows it makes the script **exit 1** after step 7 has run.
The check reads the live site, so it needs no secret. If it fails: `gh run list -R
CalCOFI/CalCOFI.github.io -L 3`, then `gh run view <id> --log-failed`.

### Step 7: the media, run whenever the release added a key

The species faces (`taxa_media.json`) and the measurement faces
(`measurements_media.json` + the ChEBI structures) are **not release content**: they are
fetched from public services into `gs://calcofi-files-public/{species,measurement}-media/`,
one copy for every release. Until 2026-10-06 the script only printed this step, and skipping
it is silent: the site builds, and a taxon or measurement key the release added draws no face.
It now runs itself, **only when it is due**:

1. `scripts/media_due.py` (in `../CalCOFI.github.io`, tested by `_test/media_due_test.py`)
   compares the promoted release's `taxa.json` + `measurements.json` with the two published
   sidecars: exit 0 nothing missing, 3 due, 2 cannot tell. An entry is what counts, so a
   measurement key in the sidecar's `skipped` list is covered, and a key only the sidecar has
   (a release dropped it) is never a reason to fetch.
2. When due: `gcloud` must be the calcofi-admin account (the GitHub workflows
   `species-media.yml` / `measurement-media.yml` stay `if: false` for want of a `GCP_SA_KEY`
   secret; the Mac mini has the account), then `fetch_release.sh`, and for each kind that is
   due its fetcher → its check (the gate, before the bucket) → `--upload`, logged to
   `../CalCOFI.github.io/.cache/deploy_media_<release>.log`.
3. `media_due.py` again, on the published bytes: it must find nothing missing.
4. `refresh.yml` dispatched and watched to green, because Jekyll reads both sidecars at build.

A failure anywhere fails the deploy (exit 1 at the end, after the rest has run).
`--skip-media` opts out; `CALCOFI_SITE_DIR` points at another site checkout. Two traps the
step is written around:

- **A fetcher always writes the whole sidecar from the record.** `--only` would publish a
  sidecar holding just the new keys and blank every other page; the warm `.cache/` in the
  site checkout is what makes a full run fetch only the new keys (cold species: ~1.2 h). The
  warm cache lives on the mini (`.cache/species-media/_cache`, ~207 MB), which is one more
  reason the deploy runs there.
- **`set -e` does not reach into a subshell on the left of `||`**, so each fetch/check/upload
  line ends in `|| exit 1`; without it a failed check would not have stopped its upload.

By hand, from `../CalCOFI.github.io` (same order): `python3 scripts/media_due.py`, then
`scripts/fetch_release.sh`, `.venv-media/bin/python scripts/fetch_species_media.py`,
`python3 scripts/check_species_media.py`, `… fetch_species_media.py --upload`, the same three
for `fetch_measurement_faces.py` / `check_measurement_faces.py`, and
`gh workflow run refresh.yml --ref main -R CalCOFI/CalCOFI.github.io`.

Release-side registry rows
(`metadata/measurement_{face,why,method,chem,scale}.csv`) reach the site through
`measurements.json`, so author them **before** the release is cut; the pages only draw keys
whose values sit in `obs_env` (`build_measurements_catalog()` reads nothing else), so the
per-cast, `obs_bio` and attribute types appear on `/datasets/` pages but have no
`/measurements/` page.

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
