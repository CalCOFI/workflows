#!/usr/bin/env bash
# build a local DuckDB of views over one frozen CalCOFI release, for the AI-readiness pilot
#   usage: libs/bench_ai_readiness/build_release_db.sh [version] [dir]
# downloads every table in the release catalog except the two full-resolution sensor tables
# (obs_ctd_full, obs_mets_full; ~1.7 GB, no pilot question uses them) and the `obs` table,
# which is re-created as the catalog's own view over obs_bio + obs_env.
set -euo pipefail
ver="${1:-v2026.10.21}"
dir="${2:-$HOME/_big/bench_ai_release}"
base="https://storage.googleapis.com/calcofi-db"
mkdir -p "$dir/parquet" && cd "$dir"

curl -sf "$base/ducklake/releases/$ver/catalog.json" > catalog.json

# one row per object: table <tab> path; local path drops the content-hash folder
jq -r '.tables[] | select(.name|IN("obs_ctd_full","obs_mets_full","obs")|not)
       | .name as $n | .objects[] | "\($n)\t\(.path)"' catalog.json > objects.tsv
while IFS=$'\t' read -r n p; do
  rel="${p#ducklake/tables/}"
  d="parquet/$n/$(echo "$rel" | sed -E "s#^$n/##; s#/[0-9a-f]{24}/#/#")"
  mkdir -p "$(dirname "$d")"
  printf 'url = "%s/%s"\noutput = "%s"\n' "$base" "$p" "$d"
done < objects.tsv > curl.cfg
curl -sf --parallel --parallel-max 16 -K curl.cfg

# views: one per table, plus `obs` from the catalog definition
{
  for t in $(ls parquet); do
    echo "CREATE OR REPLACE VIEW $t AS SELECT * FROM read_parquet('$dir/parquet/$t/**/*.parquet', hive_partitioning=true);"
  done
  echo "CREATE OR REPLACE VIEW obs AS $(jq -r '.views.obs' catalog.json | sed 's/{{obs_bio}}/obs_bio/; s/{{obs_env}}/obs_env/');"
} > views.sql
rm -f release.duckdb
duckdb release.duckdb < views.sql
echo "$ver" > version.txt
duckdb -readonly release.duckdb -c "select count(*) as obs_rows from obs"
