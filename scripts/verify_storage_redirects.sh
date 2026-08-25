#!/usr/bin/env bash
# T4 — storage.calcofi.io serves a release's tables under BOTH addresses:
#   * the canonical content-addressed object  (…/ducklake/tables/{table}/{hash}/…)  -> 200
#   * the legacy per-release path             (…/releases/{v}/parquet/{table}.parquet)
#       -> 200 if a compat copy exists (promoted / consolidated versions), else
#       -> 302 to the canonical object (Caddy map from releases_redirects.caddy), then 200
# and DuckDB can read a table through the redirected legacy URL.
#   bash scripts/verify_storage_redirects.sh vYYYY.MM.DD [prefix]   (prefix default ducklake/releases)
set -euo pipefail
V="${1:?version}"; PREFIX="${2:-ducklake/releases}"
SITE=https://storage.calcofi.io/calcofi-db
GCS=https://storage.googleapis.com/calcofi-db
cat_json=$(curl -sf "$GCS/$PREFIX/$V/catalog.json")
layout=$(printf '%s' "$cat_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("layout","legacy"))')
echo "==> $V under $PREFIX (layout: $layout)"
fail=0
# every single-file table: canonical object 200 via storage.calcofi.io (ranged GET, 1 byte)
printf '%s' "$cat_json" | python3 -c '
import json,sys
c=json.load(sys.stdin)
for t in c["tables"]:
    if t.get("objects") and not t.get("partitioned"):
        print(t["name"], t["objects"][0]["path"], t.get("compat_path",""))' | while read -r tbl path compat; do
  code=$(curl -s -o /dev/null -w '%{http_code}' -r 0-0 "$SITE/$path")
  printf '    %-22s canonical %s ' "$tbl" "$code"; [ "$code" = 206 ] || [ "$code" = 200 ] || { echo FAIL; fail=1; continue; }
  if [ -n "$compat" ]; then
    # legacy path: follow redirects, report the chain
    chain=$(curl -s -o /dev/null -w '%{http_code} %{redirect_url}' -r 0-0 "$SITE/$compat")
    first=${chain%% *}; loc=${chain#* }
    if [ "$first" = 302 ]; then
      final=$(curl -s -o /dev/null -w '%{http_code}' -r 0-0 -L "$SITE/$compat")
      printf '| legacy 302 -> %s (%s)\n' "$final" "${loc##*/ducklake/}"
      [ "$final" = 206 ] || [ "$final" = 200 ] || fail=1
      case "$loc" in *"$path"*) ;; *) echo "      redirect target is not the catalog object: $loc"; fail=1;; esac
    else
      printf '| legacy %s (compat copy)\n' "$first"
      [ "$first" = 206 ] || [ "$first" = 200 ] || fail=1
    fi
  else echo; fi
done
# DuckDB reads one table through the legacy URL on storage.calcofi.io (httpfs follows 302)
tbl=cruise
compat=$(printf '%s' "$cat_json" | python3 -c '
import json,sys; c=json.load(sys.stdin)
t=[t for t in c["tables"] if t["name"]=="cruise"][0]; print(t.get("compat_path") or "")')
if [ -n "$compat" ] && command -v duckdb >/dev/null; then
  n=$(duckdb -csv -noheader -c "SELECT count(*) FROM read_parquet('$SITE/$compat')" 2>&1 | tail -1)
  echo "    duckdb count(*) via legacy URL: $n"
  case "$n" in ''|*[!0-9]*) echo "    FAIL: duckdb could not read through the redirect"; fail=1;; esac
fi
[ "$fail" -eq 0 ] && echo "==> redirects OK" || { echo "==> FAILED"; exit 1; }
