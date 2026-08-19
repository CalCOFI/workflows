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
echo "==> 1/5 pulling sources"
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
echo "==> 1b/5 checking calcofi4r in the rstudio container"
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
  echo "==> 2/5 rebuilding app databases (slow)"
  sshq "docker exec rstudio bash -lc 'cd $GH/db-viz-hex && Rscript prep_db.R' > /tmp/deploy_prep_hex.log 2>&1; echo hex_rc=\$?" | tail -1
  sshq "docker exec rstudio bash -lc 'cd $GH/apps/db-viz-cruise && Rscript prep_db.R TRUE' > /tmp/deploy_prep_cruise.log 2>&1; echo cruise_rc=\$?" | tail -1
  for f in /tmp/deploy_prep_hex.log /tmp/deploy_prep_cruise.log; do
    sshq "grep -iE '^Error|Execution halted|Killed' $f | head -3" | sed 's/^/    /'
  done
else
  echo "==> 2/5 skipping prep_db (--skip-prep)"
fi

# 3. h3t API + varnish -----------------------------------------------------
# `restart` reuses the SAME container so its docker IP is unchanged and Varnish
# keeps resolving it. A `compose up -d` that RECREATES the container gives it a
# new IP and would require restarting Varnish too — do not swap these.
echo "==> 3/5 reopening the h3t database + flushing tiles"
sshq "cd $GH/server && sudo docker compose restart h3t_api_py" | tail -1
sshq "sudo docker exec varnish varnishadm ban 'obj.http.X-Url ~ \"^/h3t/\"'" | tail -1

# 3b. PostgreSQL release.* views -------------------------------------------
# The CTD team's calcofi database exposes the release through pg_duckdb views
# (server/postgis/init/50_release_views.sql), pinned to a version string in the
# read_parquet() URLs. Re-point them at $RELEASE by literal substitution — the
# repo file stays canonical (and pinned to whatever release it was last committed
# against); the live views always track the promoted release.
echo "==> 3b/5 re-pointing PostgreSQL release.* views at $RELEASE"
sshq "sed -E 's|/releases/v[0-9.]+/|/releases/$RELEASE/|g' $GH/server/postgis/init/50_release_views.sql | sudo docker exec -i postgis psql -U admin -d calcofi -v ON_ERROR_STOP=1 -q -f - >/dev/null 2>&1 && sudo docker exec postgis psql -U admin -d calcofi -tAc 'SELECT count(*) FROM release.cruise' | sed 's/^/    release.cruise rows: /'" | tail -1

# 4. shiny apps ------------------------------------------------------------
echo "==> 4/5 restarting apps"
sshq "touch $GH/db-viz-hex/app/restart.txt $GH/apps/db-viz-cruise/restart.txt && echo ok" | tail -1

# 5. verify ----------------------------------------------------------------
# The h3t check is the load-bearing one: it is the consumer that silently served
# a stale release, and `db_mtime` is the only field that reveals which file the
# API actually has open.
echo "==> 5/5 verifying"
fail=0
for u in https://app.calcofi.io/db-viz-hex/ https://app.calcofi.io/db-viz-cruise/ \
         https://h3t.calcofi.io/h3t/health; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 90 "$u" || echo 000)
  printf '    %-46s %s\n' "$u" "$code"
  [ "$code" = "200" ] || fail=1
done
echo "    h3t open file:"
curl -s --max-time 60 https://h3t.calcofi.io/h3t/health | sed 's/^/      /'
[ "$fail" -eq 0 ] || { echo "==> FAILED: a consumer is not answering 200" >&2; exit 1; }
echo "==> consumers deployed for $RELEASE"
