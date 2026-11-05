#!/usr/bin/env bash
# preview_candidate.sh — the candidate release for ONE held dataset, as the private-preview
# pathway requires (preview-release skill, stage 3): release_database.qmd run into the private
# preview bucket under the dataset's own root, every public gate running, the held dataset
# included (CALCOFI_RELEASE_INCLUDE) and its siblings held out, so scripts/build_preview.sh can
# show the provider their dataset in calcofi.io and the Explorer before they agree to publish.
#
#   scripts/preview_candidate.sh <provider> <dataset> [short-name]
#
# Run from a workflows checkout (the current directory) whose HEAD origin/main contains, after
# every sibling held dataset is merged: the release discovers every shard in the SHARED stage
# directory and excludes only the held datasets this checkout knows as in_release: false, so a
# checkout missing a sibling's notebook counts that sibling's rows into the candidate (or fails
# core_parity). The script fetches and refuses otherwise.
#
# Takes about 4.5 h on the Mac mini (IFCB, 2026-11-03), so the caller detaches it in tmux with
# stdin from /dev/null, e.g.
#   tmux new-window -d -n cand-ifcb \
#     'cd ~/Github/CalCOFI/workflows && scripts/preview_candidate.sh sccoos ifcb-ctd ifcb < /dev/null; touch ~/_big/calcofi-cand/ifcb/.done'
# Two at a time fit in 48 GB with the memory and thread defaults below.
#
# Env (every one optional):
#   CALCOFI_PREVIEW_BUCKET       the private bucket (default calcofi-preview); a public bucket is refused
#   CALCOFI_DUCKDB_MEMORY_LIMIT  DuckDB memory for the release (default 20GB)
#   CALCOFI_DUCKDB_THREADS       DuckDB threads (default 5)
#   CALCOFI_CAND_ROOT            where each candidate's own stage dir lives (default ~/_big/calcofi-cand)
#   CALCOFI_SHARED_STAGE_DIR     the shared stage dir whose parquet/ the candidate reads (default ~/_big/calcofi)
#   CALCOFI_CAND_OVERRIDE        space-separated dataset keys whose shard the caller rendered into
#                                $CALCOFI_CAND_ROOT/<short>/parquet/<key>/ for this candidate alone; every other
#                                dataset is a symlink to the shared shard
# and ~/.config/calcofi/env.sh is sourced first when present (R_LIBS_USER, the service account,
# the CalCOFI limits). Set by the script for the render, never by the caller:
#   CALCOFI_STAGE_DIR=$CALCOFI_CAND_ROOT/<short>  its own releases-staging/<version> and tmp/;
#                                                 parquet/ a symlink to the shared shards
#   CALCOFI_RELEASE_BUCKET=<bucket>               the candidate goes to the private bucket only
#   CALCOFI_RELEASE_PREFIX=ducklake-preview-<short>/releases
#   CALCOFI_TABLES_PREFIX=ducklake-preview-<short>/tables   (a root per dataset: two candidates
#                                                 on one day share the date version and must not
#                                                 share a root)
#   CALCOFI_RELEASE_INCLUDE=<provider>_<dataset>  the one held dataset this candidate includes
#   CALCOFI_DUCKDB_TEMP_DIR=$CALCOFI_STAGE_DIR/tmp/release_duckdb
#
# After a successful render the script writes the version the run produced to
# gs://<bucket>/ducklake-preview-<short>/releases/latest.txt (what build_preview.sh reads; the
# public test_release.qmd does not run on a candidate), stamps the root with the dataset it
# holds (dataset_key.txt, what scripts/sync_preview_tracker.R reads) and prints the
# build_preview.sh command.
# The render log is $CALCOFI_STAGE_DIR/render_<utc>.log. A failed attempt leaves
# releases/v<date>/ in its root; delete it before the rerun.
set -euo pipefail

PROVIDER="${1:?provider, e.g. sccoos}"
DATASET="${2:?dataset, e.g. ifcb-ctd}"
DS="${3:-$DATASET}"
KEY="${PROVIDER}_${DATASET}"

[ -f "$HOME/.config/calcofi/env.sh" ] && source "$HOME/.config/calcofi/env.sh"

BUCKET="${CALCOFI_PREVIEW_BUCKET:-calcofi-preview}"
case "$BUCKET" in
  calcofi-db|calcofi-files-public) echo "refusing the public bucket $BUCKET: a candidate holds a held dataset" >&2; exit 1;;
esac
ROOT="ducklake-preview-$DS"
WF="$(pwd)"
QUESTIONS="$WF/metadata/$PROVIDER/$DATASET/questions.csv"
NOTEBOOK="$WF/ingest_$KEY.qmd"

# a workflows checkout, with the notebook, its consent row and the dataset held ----
[ -f "$WF/release_database.qmd" ] || { echo "run from a workflows checkout: no release_database.qmd in $WF" >&2; exit 1; }
[ -f "$NOTEBOOK" ] || { echo "no $NOTEBOOK" >&2; exit 1; }
grep -Eq '^[[:space:]]*in_release:[[:space:]]*false' "$NOTEBOOK" ||
  { echo "$NOTEBOOK does not hold the dataset (in_release: false): a candidate is for a held dataset" >&2; exit 1; }
[ -f "$QUESTIONS" ] || { echo "no $QUESTIONS" >&2; exit 1; }
python3 - "$QUESTIONS" <<'PY' || { echo "$QUESTIONS has no consent row (related_field = consent); add it first (copy sccoos/ifcb-ctd Q17)" >&2; exit 1; }
import csv, sys
with open(sys.argv[1], newline="") as f:
    rows = [r for r in csv.DictReader(f) if (r.get("related_field") or "").strip() == "consent"]
sys.exit(0 if len(rows) == 1 else 1)
PY

# at a commit origin/main contains ----
git -C "$WF" fetch --quiet origin main
git -C "$WF" merge-base --is-ancestor HEAD origin/main ||
  { echo "HEAD is not contained in origin/main: merge first, the release excludes only the held datasets this checkout knows" >&2; exit 1; }
if [ -n "$(git -C "$WF" status --porcelain -- '*.qmd' 2>/dev/null)" ]; then
  echo "uncommitted .qmd changes in $WF; the candidate must come from a committed state" >&2; exit 1
fi

# the per-run stage root: its own releases-staging/<version>, the shared shards ----
CAND_ROOT="${CALCOFI_CAND_ROOT:-$HOME/_big/calcofi-cand}"
SHARED="${CALCOFI_SHARED_STAGE_DIR:-$HOME/_big/calcofi}"
STAGE="$CAND_ROOT/$DS"
[ -d "$SHARED/parquet" ] || { echo "no shared shards at $SHARED/parquet" >&2; exit 1; }
mkdir -p "$STAGE/tmp/release_duckdb"
# the shards: a symlink to the shared parquet/, or, when CALCOFI_CAND_OVERRIDE names datasets the
# caller re-rendered for this candidate alone (e.g. farallon_bird-mammal with the marine-mammal cut
# that is gated off in public), a directory of one symlink per shared dataset with those datasets as
# real directories the caller filled beforehand (render with CALCOFI_STAGE_DIR=$STAGE)
if [ -n "${CALCOFI_CAND_OVERRIDE:-}" ]; then
  [ -L "$STAGE/parquet" ] && rm "$STAGE/parquet"
  mkdir -p "$STAGE/parquet"
  for d in "$SHARED"/parquet/*/; do
    k="$(basename "$d")"
    case " $CALCOFI_CAND_OVERRIDE " in
      *" $k "*) [ -f "$STAGE/parquet/$k/sample.parquet" ] ||
                  { echo "override $k: no shard at $STAGE/parquet/$k (render it with CALCOFI_STAGE_DIR=$STAGE first)" >&2; exit 1; };;
      *)        [ -d "$STAGE/parquet/$k" ] && [ ! -L "$STAGE/parquet/$k" ] && { echo "$STAGE/parquet/$k is a real directory but not in CALCOFI_CAND_OVERRIDE" >&2; exit 1; }
                ln -sfn "${d%/}" "$STAGE/parquet/$k";;
    esac
  done
  echo "shards: $SHARED/parquet with override(s) $CALCOFI_CAND_OVERRIDE"
else
  [ -d "$STAGE/parquet" ] && [ ! -L "$STAGE/parquet" ] && { echo "$STAGE/parquet is a directory (an override farm); set CALCOFI_CAND_OVERRIDE or remove it" >&2; exit 1; }
  ln -sfn "$SHARED/parquet" "$STAGE/parquet"
fi
export CALCOFI_STAGE_DIR="$STAGE"
export CALCOFI_PREVIEW_BUCKET="$BUCKET" CALCOFI_RELEASE_BUCKET="$BUCKET"
export CALCOFI_RELEASE_PREFIX="$ROOT/releases" CALCOFI_TABLES_PREFIX="$ROOT/tables"
export CALCOFI_RELEASE_INCLUDE="$KEY"
export CALCOFI_DUCKDB_MEMORY_LIMIT="${CALCOFI_DUCKDB_MEMORY_LIMIT:-20GB}"
export CALCOFI_DUCKDB_THREADS="${CALCOFI_DUCKDB_THREADS:-5}"
export CALCOFI_DUCKDB_TEMP_DIR="$STAGE/tmp/release_duckdb"

START="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$STAGE/render_$START.log"
cat <<EOF
candidate $KEY -> gs://$BUCKET/$ROOT/ (stage $STAGE, $CALCOFI_DUCKDB_MEMORY_LIMIT / $CALCOFI_DUCKDB_THREADS threads)
  checkout $WF @ $(git -C "$WF" rev-parse --short HEAD), log $LOG
EOF

# the render (4–5 h) ----
cd "$WF"
quarto render release_database.qmd 2>&1 | tee "$LOG"

# the version the run produced ----
VERSION="$(sed -nE 's/.*Release version: (v[0-9]{4}\.[0-9]{2}\.[0-9]{2}).*/\1/p' "$LOG" | tail -1)"
if [ -z "$VERSION" ]; then
  for d in "$WF"/data/releases-staging/v*/; do [ -d "$d" ] && VERSION="$(basename "$d")"; done   # glob sorts, last = newest
fi
[ -n "$VERSION" ] || { echo "the render finished but no version was found in $LOG or data/releases-staging/" >&2; exit 1; }
gcloud storage ls "gs://$BUCKET/$ROOT/releases/$VERSION/" >/dev/null ||
  { echo "the render finished but gs://$BUCKET/$ROOT/releases/$VERSION/ holds nothing" >&2; exit 1; }
printf '%s\n' "$VERSION" | gcloud storage cp - "gs://$BUCKET/$ROOT/releases/latest.txt"
printf '%s\n' "$KEY" | gcloud storage cp - "gs://$BUCKET/$ROOT/dataset_key.txt"
cat <<EOF

candidate $VERSION of $KEY at gs://$BUCKET/$ROOT/releases/$VERSION/ (latest.txt written)
next, the preview build:
  PREVIEW_ACCESS=link PREVIEW_RELEASE_ROOT=$ROOT scripts/build_preview.sh $PROVIDER $DATASET _output/ingest_$KEY.html
EOF
