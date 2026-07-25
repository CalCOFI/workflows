#!/usr/bin/env bash
# Extract the CalCOFI hydrographic master Access database to Parquet + SQL.
#
# No Windows, no Access install: mdbtools reads the tables and system catalogs,
# Jackcess (Java) reads the saved-query SQL. See libs/extract_accdb.R for why both
# engines are run and diffed rather than trusting mdbtools' lossy query output.
#
# Outputs split by reviewability:
#   metadata/calcofi/hydro-master/accdb/  committed  — sql/*.sql, queries.csv,
#                                                      relationships.csv, objects.csv,
#                                                      schema.sql, tables.csv
#   data/accdb/calcofi_hydro-master/      gitignored — tables/*.parquet (~GBs)
#
# Prereqs:
#   brew install mdbtools openjdk      # macOS
#   apt install mdbtools default-jdk   # Ubuntu
# The Jackcess jars are fetched from Maven Central into data/cache/jackcess on first
# run (versions pinned in libs/extract_accdb.R).
#
# Usage:
#   scripts/extract_accdb.sh [/path/to/db.accdb]
#
# Default source is the Google Drive copy; override with ACCDB_PATH or argv[1] when
# running on the server against a GCS-synced copy.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DEFAULT_ACCDB="${HOME}/Library/CloudStorage/GoogleDrive-ben@ecoquants.com/My Drive/projects/calcofi/data-public/calcofi/ctd-cast/CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb"
ACCDB="${1:-${ACCDB_PATH:-$DEFAULT_ACCDB}}"

DIR_META="${REPO}/metadata/calcofi/hydro-master/accdb"
DIR_DATA="${REPO}/data/accdb/calcofi_hydro-master"

if [[ ! -f "$ACCDB" ]]; then
  echo "error: Access DB not found: $ACCDB" >&2
  echo "       pass a path as argv[1] or set ACCDB_PATH" >&2
  exit 1
fi

echo "source:   $ACCDB"
echo "metadata: $DIR_META"
echo "data:     $DIR_DATA"
echo

Rscript -e "
  here::i_am('scripts/extract_accdb.sh')
  source(here::here('libs/extract_accdb.R'))
  extract_accdb(
    db       = '${ACCDB//\'/\'\\\'\'}',
    dir_meta = here::here('metadata/calcofi/hydro-master/accdb'),
    dir_data = here::here('data/accdb/calcofi_hydro-master'))
"
