#!/usr/bin/env bash
# build_preview_finder.sh — the Dataset Finder (CalCOFI/db-viz-station, Betty's station app) built
# against a private candidate release, for a dataset's preview (Ben + Erin, 2026-11-03: the Finder is
# one of the obvious links a provider should get).
#
#   scripts/build_preview_finder.sh <finder_dir> <bucket> <release_prefix> <version> <data_url> <out>
#
# The Finder's refresh (its .github/workflows/refresh.yml) renders scripts/build_*.sql from the
# release's catalog.json with resolve_release.py and runs them with the DuckDB CLI; the same here,
# except: the catalog is fetched from the private bucket with the active account's token, the
# rendered object URLs point at that bucket behind a DuckDB http secret, and public/data/tables.json
# (what the app's DuckDB-WASM reads at run time) is rewritten to the preview's data route
# (<data_url>/<object path>), so the browser reads the candidate through the same link it opened.
# The app's own files are copied as they are; it reads ./data/ relatively and takes ?dataset=<key>.
set -euo pipefail
FINDER="${1:?db-viz-station checkout}"; BUCKET="${2:?bucket}"; REL="${3:?release prefix}"
VERSION="${4:?version}"; DATA_URL="${5:?absolute data url base}"; OUT="${6:?out dir}"
TOKEN="${CALCOFI_RELEASE_TOKEN:-$(gcloud auth print-access-token)}"
command -v duckdb >/dev/null || { echo "duckdb CLI missing" >&2; exit 1; }

B="$(mktemp -d)"
curl -fsS -H "Authorization: Bearer $TOKEN" "https://storage.googleapis.com/$BUCKET/$REL/$VERSION/catalog.json" > "$B/catalog.json"
mkdir -p "$OUT"; cp -R "$FINDER/public/." "$OUT/"
(cd "$FINDER" && python3 scripts/resolve_release.py --catalog "$B/catalog.json" --out-dir "$B/build" \
   --tables-json "$B/tables.json" --tables obs,taxon >/dev/null)
# the rendered SQL: the private bucket, behind the token; outputs into the preview's copy
SECRET="INSTALL httpfs; LOAD httpfs; CREATE OR REPLACE SECRET release_token (TYPE http, BEARER_TOKEN '$TOKEN');"
for f in "$B"/build/*.sql; do
  perl -pi -e "s{https://storage\.googleapis\.com/calcofi-db/}{https://storage.googleapis.com/$BUCKET/}g; s{public/data/}{$OUT/data/}g" "$f"
  printf '%s\n' "$SECRET" | cat - "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
# build_crosswalk.sql reads public metadata, not the release; its output feeds build_vars
perl -pe "s{public/data/}{$OUT/data/}g; s{'metadata/}{'$FINDER/metadata/}g" "$FINDER/scripts/build_crosswalk.sql" > "$B/build/build_crosswalk.sql"
run() { echo "finder: $1"; duckdb -c ".read $B/build/$1"; }
cd "$FINDER"
run build_crosswalk.sql
run build_stations.sql
gzip -9 -f "$OUT/data/taxon_coverage.json"
run build_vars.sql
run build_decades.sql
run build_bottle_cast_coverage.sql
run build_datasets.sql
REGION="$(python3 scripts/resolve_release.py --catalog "$B/catalog.json" --expr region | perl -pe "s{https://storage\.googleapis\.com/calcofi-db/}{https://storage.googleapis.com/$BUCKET/}g")"
HAS_GEOM="$(duckdb -noheader -list -c "$SECRET SELECT count(*) FROM (DESCRIBE SELECT * FROM $REGION) WHERE column_name = 'geom'" 2>/dev/null || echo 0)"
if [ "$HAS_GEOM" = "1" ]; then run build_regions.sql; else echo "finder: no region.geom in $VERSION, keeping the committed regions.json"; fi
run build_depth_profiles.sql
gzip -9 -f "$OUT/data/depth_profiles.json"
# what the browser reads: the candidate through the preview's data route
python3 - "$B/tables.json" "$OUT/data/tables.json" "$DATA_URL" <<'PY2'
import json, sys
src, dst, data_url = sys.argv[1:4]
t = json.load(open(src))
pub = "https://storage.googleapis.com/calcofi-db/"
def rw(u): return data_url.rstrip("/") + "/" + u[len(pub):] if isinstance(u, str) and u.startswith(pub) else u
for tbl in t.get("tables", {}).values():
    tbl["urls"] = [rw(u) for u in tbl.get("urls", [])]
    if tbl.get("single_file"): tbl["single_file"] = rw(tbl["single_file"])
json.dump(t, open(dst, "w"), indent=1)
PY2
printf '{"release":"%s","built":"%s"}\n' "$VERSION" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$OUT/data/version.json"
rm -rf "$B"
echo "finder built into $OUT for $VERSION ($(ls "$OUT/data" | wc -l | tr -d ' ') data files)"
