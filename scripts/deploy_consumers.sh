#!/usr/bin/env bash
# deploy_consumers.sh — bring every server-side consumer onto the promoted release.
#
# Run from the workflows repo AFTER latest.txt has been promoted:
#   bash scripts/deploy_consumers.sh [--release vYYYY.MM.DD] [--skip-prep]
#
# test_release.qmd calls this automatically when CALCOFI_DEPLOY=true, so a normal
# `tar_make()` still only builds and promotes; deploying stays one deliberate flag.
#
# WHY A SCRIPT AND NOT A LIST OF SSH COMMANDS IN A NOTEBOOK: every consumer here
# drifted at least once because its update lived only as prose. Each step below
# was performed by hand on 2026-08-04, and each failed silently in a way that
# looked like success:
#
#   * The h3t API opens `calcofi_latest.duckdb` and HOLDS IT OPEN. prep_db.R
#     advances that symlink, but the running container keeps serving the old
#     inode — on 2026-08-04 the API was still on v2026.08.03 while the symlink
#     had moved to v2026.08.04. Nothing errors; the map is quietly stale.
#   * Varnish keys tiles on URL, and the URL carries a release tag. If the tag
#     does not change when the data does, cached tiles from the OLD release are
#     served indefinitely. (db-viz-hex now DERIVES that tag from the symlink, so
#     it cannot lag — but the ban here clears anything already cached.)
#   * `restart.txt` is how shiny-server reloads an app; without it the app keeps
#     the previous database handle for as long as the process lives.
#
# Exit non-zero on the first real failure: a half-deployed consumer set is worse
# than an obviously failed deploy.
set -euo pipefail

HOST="${CALCOFI_SSH_HOST:-calcofi}"
GH="/share/github/CalCOFI"
RELEASE=""
SKIP_PREP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --release)   RELEASE="$2"; shift 2 ;;
    --skip-prep) SKIP_PREP=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# ssh emits harmless port-forward warnings on this host; keep them out of the log
sshq() { ssh "$HOST" "$@" 2>&1 | grep -vE "remote port forwarding failed|bind \[|channel_setup_fwd|Could not request local forwarding" || true; }

if [ -z "$RELEASE" ]; then
  RELEASE=$(curl -sf --max-time 60 \
    https://storage.googleapis.com/calcofi-db/ducklake/releases/latest.txt | tr -d '[:space:]')
fi
[ -n "$RELEASE" ] || { echo "could not resolve release" >&2; exit 1; }
echo "==> deploying consumers for $RELEASE (host: $HOST)"

# 1. sources ---------------------------------------------------------------
# calcofi4r included: db-viz-hex's prep_db.R does devtools::load_all("../calcofi4r"),
# so a stale checkout there silently builds against old package code. The apps
# load the INSTALLED package instead — see step 1b, which is the other half.
echo "==> 1/6 pulling sources"
for r in calcofi4r db-viz-hex apps; do
  printf '    %-12s ' "$r"
  sshq "git -C $GH/$r pull --ff-only" | tail -1
done

# 1b. calcofi4r into the container -----------------------------------------
# Pulling the checkout above is NOT enough, and the gap is invisible. prep_db.R
# reads calcofi4r through devtools::load_all(), so it picks up the pull — but the
# APPS load it with library(), i.e. the INSTALLED package, which a git pull never
# touches. On 2026-08-14 the server sat on calcofi4r 1.6.0 while the checkout was
# 1.7.0: prep_db.R built correctly, every endpoint returned 200, the deploy looked
# completely clean, and the fix in 1.7.0 (cc_ts_gaps) was simply absent from the
# running app. It was caught only by reading the rendered Highcharts series.
#
# Version-compared rather than installed unconditionally, because installing is
# ~40 s and most deploys do not touch the package.
echo "==> 1b/6 checking calcofi4r in the rstudio container"
SRC_VER=$(sshq "grep '^Version:' $GH/calcofi4r/DESCRIPTION | awk '{print \$2}'" | tail -1 | tr -d '[:space:]')
INS_VER=$(sshq "docker exec rstudio Rscript -e 'cat(as.character(packageVersion(\"calcofi4r\")))'" | tail -1 | tr -d '[:space:]')
printf '    checkout %s | installed %s ' "${SRC_VER:-?}" "${INS_VER:-none}"
if [ -n "$SRC_VER" ] && [ "$SRC_VER" != "$INS_VER" ]; then
  echo "-> installing"
  sshq "docker exec rstudio Rscript -e 'devtools::install(\"$GH/calcofi4r\", quiet=TRUE, upgrade=FALSE, dependencies=FALSE)'" | tail -2 | sed 's/^/    /'
  NEW_VER=$(sshq "docker exec rstudio Rscript -e 'cat(as.character(packageVersion(\"calcofi4r\")))'" | tail -1 | tr -d '[:space:]')
  [ "$NEW_VER" = "$SRC_VER" ] || {
    echo "    calcofi4r install did not take: wanted $SRC_VER, have $NEW_VER" >&2; exit 1; }
  echo "    installed calcofi4r $NEW_VER"
else
  echo "-> up to date"
fi

# 2. app databases ---------------------------------------------------------
# Must run INSIDE the rstudio container: it has R, the package deps, and network
# to the public GCS bucket. Heavy (downloads the release, materializes H3 + join
# tables), so it is run synchronously here and its exit status is checked.
if [ "$SKIP_PREP" -eq 0 ]; then
  echo "==> 2/6 rebuilding app databases (slow)"
  sshq "docker exec rstudio bash -lc 'cd $GH/db-viz-hex && Rscript prep_db.R' > /tmp/deploy_prep_hex.log 2>&1; echo hex_rc=\$?" | tail -1
  sshq "docker exec rstudio bash -lc 'cd $GH/apps/db-viz-cruise && Rscript prep_db.R TRUE' > /tmp/deploy_prep_cruise.log 2>&1; echo cruise_rc=\$?" | tail -1
  # ctd-viz and ctd-qaqc were NOT here until 2026-08-25: ctd-viz served its
  # 2026-05-15 database (v2026.05.14) through three releases with nothing
  # reporting it, and ctd-qaqc its 2026-08-03 one. Both skip when their db exists
  # unless forced — 'latest TRUE' is the force.
  sshq "docker exec rstudio bash -lc 'cd $GH/apps/ctd-viz && Rscript prep_db.R latest TRUE' > /tmp/deploy_prep_ctd-viz.log 2>&1; echo ctdviz_rc=\$?" | tail -1
  sshq "docker exec rstudio bash -lc 'cd $GH/apps/ctd-qaqc && Rscript prep_db.R latest TRUE' > /tmp/deploy_prep_ctd-qaqc.log 2>&1; echo ctdqaqc_rc=\$?" | tail -1
  for f in /tmp/deploy_prep_hex.log /tmp/deploy_prep_cruise.log /tmp/deploy_prep_ctd-viz.log /tmp/deploy_prep_ctd-qaqc.log; do
    sshq "grep -iE '^Error|Execution halted|Killed' $f | head -3" | sed 's/^/    /'
  done
else
  echo "==> 2/6 skipping prep_db (--skip-prep)"
fi

# 3. h3t API + varnish -----------------------------------------------------
# `restart` reuses the SAME container so its docker IP is unchanged and Varnish
# keeps resolving it. A `compose up -d` that RECREATES the container gives it a
# new IP and would require restarting Varnish too — do not swap these.
echo "==> 3/6 reopening the h3t database + flushing tiles"
sshq "cd $GH/server && sudo docker compose restart h3t_api_py" | tail -1
sshq "sudo docker exec varnish varnishadm ban 'obj.http.X-Url ~ \"^/h3t/\"'" | tail -1

# 3b. PostgreSQL release.* views -------------------------------------------
# The CTD team's calcofi database exposes the release through pg_duckdb views
# (server/postgis/init/50_release_views.sql). The repo file stays pinned to the
# release it was last authored against; scripts/render_release_views.R rewrites
# every read_parquet() URL THROUGH THE CATALOG of $RELEASE (content-addressed
# since v2026.09) and fails loudly if a table cannot be resolved. The previous
# `sed` on the version string would have matched nothing once the path shape
# changed and left the live views silently frozen.
echo "==> 3b/6 re-pointing PostgreSQL release.* views at $RELEASE"
VIEWS_SQL=$(Rscript scripts/render_release_views.R "$RELEASE" ../server/postgis/init/50_release_views.sql) || {
  echo "    render_release_views.R failed" >&2; exit 1; }
printf '%s\n' "$VIEWS_SQL" | ssh "$HOST" "sudo docker exec -i postgis psql -U admin -d calcofi -v ON_ERROR_STOP=1 -q -f - >/dev/null" 2>/dev/null || {
  echo "    applying release views failed" >&2; exit 1; }
sshq "sudo docker exec postgis psql -U admin -d calcofi -tAc 'SELECT count(*) FROM release.cruise' | sed 's/^/    release.cruise rows: /'" | tail -1

# 4. shiny apps ------------------------------------------------------------
echo "==> 4/6 restarting apps"
sshq "touch $GH/db-viz-hex/app/restart.txt $GH/apps/db-viz-cruise/restart.txt $GH/apps/ctd-viz/restart.txt $GH/apps/ctd-qaqc/restart.txt && echo ok" | tail -1

# 5. verify ----------------------------------------------------------------
# The h3t check is the load-bearing one: it is the consumer that silently served
# a stale release, and `db_mtime` is the only field that reveals which file the
# API actually has open.
echo "==> 5/6 verifying"
# canonical short URLs since the 2026-08-25 app-naming pass; the old
# /db-viz-hex//db-viz-cruise/ paths now 308 to these, so follow redirects (-L)
# rather than treat a 308 as a failure. ctd-viz is here because this script now
# rebuilds it (it silently served a May database through three releases).
fail=0
for u in https://app.calcofi.io/hex/ https://app.calcofi.io/cruise/ \
         https://app.calcofi.io/ctd/ https://h3t.calcofi.io/h3t/health; do
  code=$(curl -sL -o /dev/null -w '%{http_code}' --max-time 90 "$u" || echo 000)
  printf '    %-46s %s\n' "$u" "$code"
  [ "$code" = "200" ] || fail=1
done
echo "    h3t open file:"
curl -s --max-time 60 https://h3t.calcofi.io/h3t/health | sed 's/^/      /'
[ "$fail" -eq 0 ] || { echo "==> FAILED: a consumer is not answering 200" >&2; exit 1; }

# 6. hosted consumers ------------------------------------------------------
# Not on the CalCOFI server: these rebuild themselves on GitHub Actions, so all
# this does is fire the dispatch. Non-fatal — `gh` may be absent or unauthorized
# on the machine cutting the release, and none of them serves stale data in a way
# that breaks a query; they are refreshed here so nobody has to remember them.
#
#   * db-viz-station and ctd-transects bake release-derived JSON/parquet shards
#     into their repos and only refresh when told to.
#   * CalCOFI/docs is a release consumer too, and the least obvious one: its
#     libs/pre-render.R snapshots the PROMOTED release's sidecars at render time,
#     so until the book re-renders every generated table in it — the inventory,
#     the keys, the versions, the datasets — describes the previous release.
#     render_book.yml also runs weekly and accepts a `release-promoted`
#     repository_dispatch, so this is belt and braces.
#   * calcofi4r and calcofi4py are consumers whose README examples gated this
#     release (test_release.qmd, package_examples); their CI re-runs the examples
#     and vignettes against the promoted latest and republishes the sites.
#   * CalCOFI/CalCOFI.github.io (calcofi.io) draws its /datasets/, /measurements/
#     and /species/ sections from the promoted release's datasets.json,
#     measurements.json and taxa.json (scripts/fetch_release.sh), so it is a
#     release consumer like the book. It was missing from this loop until
#     2026-10-04 and followed a promotion only through test_release.qmd's
#     gh_dispatch table and its Monday cron; a dispatch that is not in the deploy
#     script is a dispatch nobody checks. Its refresh.yml also reads the two media
#     sidecars (species + measurement faces) at BUILD time, so the manual step 7
#     below re-dispatches it once the media are uploaded.
echo "==> 6/6 dispatching the hosted consumers (GitHub Actions)"
SITE_DISPATCHED=0
if command -v gh >/dev/null 2>&1; then
  for spec in "refresh.yml CalCOFI/db-viz-station" \
              "refresh.yml CalCOFI/ctd-transects" \
              "refresh.yml CalCOFI/CalCOFI.github.io" \
              "render_book.yml CalCOFI/docs" \
              "pkgdown.yaml CalCOFI/calcofi4r" \
              "test.yml CalCOFI/calcofi4py"; do
    set -- $spec
    printf '    %-16s %-28s ' "$1" "$2"
    if gh workflow run "$1" --ref main -R "$2" >/dev/null 2>&1; then
      echo "dispatched"; [ "$2" = "CalCOFI/CalCOFI.github.io" ] && SITE_DISPATCHED=1
    else echo "FAILED (run it by hand)"; fi
  done
else
  echo "    gh not installed — run by hand:"
  echo "      gh workflow run refresh.yml     --ref main -R CalCOFI/db-viz-station"
  echo "      gh workflow run refresh.yml     --ref main -R CalCOFI/ctd-transects"
  echo "      gh workflow run refresh.yml     --ref main -R CalCOFI/CalCOFI.github.io"
  echo "      gh workflow run render_book.yml --ref main -R CalCOFI/docs"
  echo "      gh workflow run pkgdown.yaml    --ref main -R CalCOFI/calcofi4r"
  echo "      gh workflow run test.yml        --ref main -R CalCOFI/calcofi4py"
fi

# 6b. the landing site shows the promoted version -----------------------------------------
# Dispatching is not deploying: refresh.yml fetches the record, builds Jekyll and publishes
# Pages, and any of those can fail while the dispatch above still says "dispatched". calcofi.io
# carries the release version in the text of every section built from a record, so read the LIVE
# pages and require the promoted version on each:
#   /data.json       the DCAT catalog on the front door   <- datasets.json
#   /measurements/   the measurement index                <- measurements.json
#   /species/        the species index                    <- taxa.json
# Polled (a refresh run takes ~1.5-2 min); a cache-busting query defeats the Pages CDN. A stale
# section is a FAILURE (exit 1 after the manual block below is printed), not a warning: it is the
# whole point of the dispatch. Skipped, saying so, where the dispatch did not fire.
SITE="${CALCOFI_SITE:-https://calcofi.io}"
site_fail=0
if [ "$SITE_DISPATCHED" -eq 1 ]; then
  echo "==> 6b/6 waiting for $SITE to show $RELEASE (up to ~12 min per page)"
  for page in data.json measurements/ species/; do
    ok=0
    for i in $(seq 1 24); do
      # into a variable, not `curl | grep -q`: grep exits at the first match, curl then dies of
      # SIGPIPE and pipefail turns a match into a failure
      body=$(curl -sf --max-time 30 "$SITE/$page?cb=$(date +%s)" || true)
      if grep -qF "$RELEASE" <<<"$body"; then ok=1; break; fi
      sleep 30
    done
    if [ "$ok" -eq 1 ]; then printf '    %-16s shows %s\n' "$page" "$RELEASE"
    else printf '    %-16s DOES NOT show %s\n' "$page" "$RELEASE"; site_fail=1; fi
  done
  [ "$site_fail" -eq 0 ] || echo "    $SITE is stale: gh run list -R CalCOFI/CalCOFI.github.io -L 3, then gh run view <id> --log-failed" >&2
else
  echo "==> 6b/6 skipped: the CalCOFI.github.io dispatch did not fire. Dispatch it, then: curl -s $SITE/data.json | grep -o 'release v[0-9.]*'"
fi

# 7. MANUAL: the media, then the site again ----------------------------------------------
# The species faces (taxa_media.json) and the measurement faces (measurements_media.json) are NOT
# release content: scripts/fetch_species_media.py and scripts/fetch_measurement_faces.py build
# them from public services into gs://calcofi-files-public/{species,measurement}-media/, ONE copy
# for every release. Their GitHub workflows are `if: false` (no GCP_SA_KEY secret), so this stays a
# human step on a machine whose gcloud is authenticated as calcofi-admin. It is printed, not run,
# because it writes to a public bucket and the species pass takes ~1.2 h cold (a warm .cache/
# resumes, so only the taxa new in this release are fetched). Run it AFTER the dispatch above and
# then dispatch the site once more, because Jekyll reads both sidecars at build time: a species the
# release added draws no face until its entry exists, a measurement key it added no structure.
cat <<EOF
==> 7/7 MANUAL: the media for $RELEASE (this script does not run it)
    cd ../CalCOFI.github.io                      # the landing site checkout
    scripts/fetch_release.sh                     # _data/taxa.json + measurements.json of the promoted release
    # species faces (Pillow only; resumable; a warm cache fetches just the new taxa)
    scripts/fetch_species_media.py
    scripts/check_species_media.py               # the gate, BEFORE anything reaches the bucket
    scripts/fetch_species_media.py --upload      # rsync to gs://calcofi-files-public/species-media/
    # measurement faces (RDKit, in the ignored venv: requirements-media.txt)
    [ -d .venv-media ] || { uv venv --python 3.12 .venv-media && uv pip install --python .venv-media/bin/python -r requirements-media.txt; }
    .venv-media/bin/python scripts/fetch_measurement_faces.py
    python3 scripts/check_measurement_faces.py
    .venv-media/bin/python scripts/fetch_measurement_faces.py --upload
    # the site reads both sidecars at build time: rebuild it, then re-run the 6b check
    gh workflow run refresh.yml --ref main -R CalCOFI/CalCOFI.github.io
EOF

echo "==> consumers deployed for $RELEASE"
[ "$site_fail" -eq 0 ] || exit 1
