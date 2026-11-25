#!/usr/bin/env bash
# publish_all.sh — bring every published output onto the promoted release.
#
# Run from the workflows repo AFTER latest.txt has been promoted (scripts/deploy_consumers.sh
# calls it as its last step):
#   bash scripts/publish_all.sh [--dry-run] [--only zip,obis,netcdf,edi,erddap] [--log-dir DIR]
#
# WHY A SCRIPT: the publishers are targets downstream of test_release, but a release is cut by
# making release_database and test_release alone, so nothing ran them. v2026.11.18 and
# v2026.11.25 were both promoted with the download zips still at v2026.11.14, and the EDI, OBIS
# and netCDF publishers had earlier sat at v2026.09.11 for two months. A step that lives only
# in a person's memory is a step that gets skipped.
#
# IDEMPOTENT AND NON-REDUNDANT: every publisher is content-addressed
# (calcofi4db::publish_fingerprint()). It re-reads the promoted release, and for each dataset
# whose data, metadata and format version are what the last published object was built from, it
# builds nothing and uploads nothing: only the manifest's `checked_version` moves. Running this
# twice in a row is therefore a no-op the second time, and the summary line per publisher says so.
#
# What each leg does with its flag (the notebooks own the rules; this only sets the flags):
#   zip     CALCOFI_PUBLISH_ZIP=true        new zips to gs://calcofi-db/publish/zip/{key}/{hash24}/
#   obis    CALCOFI_PUBLISH_DWCA=true       new Darwin Core Archives to the bucket (not the IPT)
#   netcdf  CALCOFI_PUBLISH=true            new CF netCDF files to the bucket
#   edi     CALCOFI_PUBLISH_EDI_STAGE=true  EML + entities staged to the bucket and evaluated by PASTA.
#           It does NOT create or revise a package on EDI: that mints a DOI, cannot be undone, and
#           stays a person's decision (CALCOFI_PUBLISH_EDI=true, by hand).
#   erddap  (deploys by default)            config regenerated, parquet synced, changed datasets flagged
#   status  publish_status.qmd              every publisher's output against what each portal holds
set -uo pipefail

DRY=0; ONLY="zip,obis,netcdf,edi,erddap"; LOG_DIR="${CALCOFI_PUBLISH_LOG_DIR:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --only)    ONLY="$2"; shift 2 ;;
    --log-dir) LOG_DIR="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
cd "$(dirname "$0")/.." || exit 1
[ -n "$LOG_DIR" ] || LOG_DIR="$(pwd)/data/publish/logs"
mkdir -p "$LOG_DIR"

# a staging prefix would point every publisher at a candidate; this script is for the promoted release
case "${CALCOFI_RELEASE_PREFIX:-}" in *staging*|*preview*)
  echo "CALCOFI_RELEASE_PREFIX=${CALCOFI_RELEASE_PREFIX} is not the promoted release; unset it" >&2; exit 2 ;;
esac
unset CALCOFI_DATASETS CALCOFI_RELEASE_VERSION CALCOFI_PUBLISH_EDI
RELEASE=$(curl -sf --max-time 60 https://storage.googleapis.com/calcofi-db/ducklake/releases/latest.txt | tr -d '[:space:]')
[ -n "$RELEASE" ] || { echo "could not resolve the promoted release" >&2; exit 1; }
echo "==> publishing for $RELEASE (dry run: $DRY; legs: $ONLY; logs: $LOG_DIR)"

fail=0
leg() { # name, flag (or -), notebook
  local name=$1 flag=$2 nb=$3 log="$LOG_DIR/publish_${1}_${RELEASE}.log" start rc
  case ",$ONLY," in *",$name,"*) ;; *) [ "$name" = status ] || { echo "    $name: skipped (--only)"; return 0; } ;; esac
  rm -f "$log.done"; start=$(date +%s)
  if [ "$DRY" = 1 ]; then
    env CALCOFI_DEPLOY=false quarto render "$nb" > "$log" 2>&1; rc=$?
  elif [ "$flag" = - ]; then
    quarto render "$nb" > "$log" 2>&1; rc=$?
  else
    env "$flag=true" quarto render "$nb" > "$log" 2>&1; rc=$?
  fi
  echo "exit=$rc secs=$(( $(date +%s) - start ))" > "$log.done"
  echo "    $name: $(cat "$log.done")  ($log)"
  [ $rc -eq 0 ] || fail=1
}
leg zip    CALCOFI_PUBLISH_ZIP       publish_to-zip.qmd
leg obis   CALCOFI_PUBLISH_DWCA      publish_to-obis.qmd
leg netcdf CALCOFI_PUBLISH           publish_to-netcdf.qmd
leg edi    CALCOFI_PUBLISH_EDI_STAGE publish_to-edi.qmd
leg erddap -                         publish_to-erddap.qmd
leg status -                         publish_status.qmd

# what each content-addressed publisher did: built (new content) against carried (unchanged)
Rscript -e '
  f <- c(zip = "data/zip/manifest.csv", obis = "data/darwincore/publish_plan.csv",
         netcdf = "data/netcdf/publish_plan.csv", edi = "data/edi/manifest.csv")
  for (n in names(f)) if (file.exists(f[[n]])) {
    d <- utils::read.csv(f[[n]], colClasses = "character")
    a <- if ("action" %in% names(d)) table(d$action) else table(character())
    cat(sprintf("    %-6s %d rows; action: %s\n", n, nrow(d),
                if (length(a)) paste(names(a), a, sep = "=", collapse = ", ") else "(no action column)"))
  }' 2>/dev/null || true
[ $fail -eq 0 ] && echo "==> every publisher leg finished for $RELEASE" || echo "==> at least one publisher leg FAILED for $RELEASE" >&2
exit $fail
