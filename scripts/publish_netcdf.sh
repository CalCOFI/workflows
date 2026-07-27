#!/usr/bin/env bash
# Publish the WHOLE-DATASET CF NetCDF files for public download.
#
# These are the single-file (one file per dataset) CF Discrete-Sampling-Geometry
# builds from gen_ctd_lumped.R — not the per-cruise collections, which exist only
# to be served by ERDDAP file backends. The public product is deliberately
# "one dataset = one self-documenting file you can download and open".
#
# Why NetCDF at all, when the release is already Parquet: Parquet carries data
# TYPES, NetCDF carries scientific MEANING. Units, standard names, coordinate
# conventions and provenance travel inside the file, so it explains itself to any
# CF-aware tool without our documentation alongside it.
#
# Run ON THE CALCOFI HOST (has the built files + fast path to GCS):
#   bash /share/github/CalCOFI/workflows/scripts/publish_netcdf.sh
set -euo pipefail

SRC=/share/data/erddap-duckdb/serving/wide_lumped_netcdf
BUCKET=gs://calcofi-files-public
DEST=$BUCKET/netcdf
WEB=https://storage.calcofi.io/calcofi-files-public/netcdf

# Provenance: the NetCDF are built from the ERDDAP serving snapshot, which is NOT
# necessarily the current release. State the snapshot date rather than implying
# they match whatever release/latest.txt currently points at.
SNAPSHOT=$(date -u -r /share/data/erddap-duckdb/datasets/ctd_cast.parquet +%Y-%m-%d 2>/dev/null || echo unknown)
BUILT=$(date -u -r "$SRC/ctd_thin/ctd_thin.nc" +%Y-%m-%d 2>/dev/null || echo unknown)

declare -a FILES=("ctd_thin/ctd_thin.nc" "ctd_measurement/ctd_measurement.nc")
for f in "${FILES[@]}"; do
  [ -f "$SRC/$f" ] || { echo "missing $SRC/$f — run gen_ctd_lumped.R netcdf" >&2; exit 1; }
done

# `gcloud storage` is not in the default release track on every host (the CalCOFI
# server only has it under `alpha`), so pick a working uploader once rather than
# assuming. gsutil is the last resort — it takes content-type differently.
if gcloud storage --help >/dev/null 2>&1;       then UPLOADER="gcloud-storage"
elif gcloud alpha storage --help >/dev/null 2>&1; then UPLOADER="gcloud-alpha"
elif command -v gsutil >/dev/null 2>&1;         then UPLOADER="gsutil"
else echo "no gcloud storage / gsutil available" >&2; exit 1; fi
echo "==> uploader: $UPLOADER"

gcs_cp() {  # $1=local $2=gs:// dest $3=content-type [$4=cache-control]
  local cc_args=()
  case "$UPLOADER" in
    gcloud-storage|gcloud-alpha)
      local sub=(storage); [ "$UPLOADER" = gcloud-alpha ] && sub=(alpha storage)
      cc_args=(--content-type="$3"); [ -n "${4:-}" ] && cc_args+=(--cache-control="$4")
      gcloud "${sub[@]}" cp "${cc_args[@]}" "$1" "$2" ;;
    gsutil)
      local hdrs=(-h "Content-Type:$3"); [ -n "${4:-}" ] && hdrs+=(-h "Cache-Control:$4")
      gsutil "${hdrs[@]}" cp "$1" "$2" ;;
  esac
}

echo "==> uploading $(echo "${FILES[@]}" | wc -w) whole-dataset NetCDF -> $DEST"
for f in "${FILES[@]}"; do
  base=$(basename "$f")
  sz=$(du -h "$SRC/$f" | cut -f1)
  echo "    $base ($sz)"
  gcs_cp "$SRC/$f" "$DEST/$base" "application/x-netcdf"
done

# rows for the index, computed from what we just uploaded
rows=""
for f in "${FILES[@]}"; do
  base=$(basename "$f"); nm="${base%.nc}"
  bytes=$(stat -c %s "$SRC/$f")
  mb=$(awk -v b="$bytes" 'BEGIN{printf "%.0f", b/1048576}')
  rows="$rows<tr><td><a href=\"$WEB/$base\">$base</a></td><td class=\"num\">${mb} MB</td></tr>"
done

TMP=$(mktemp -d)
cat > "$TMP/index.html" <<HTML
<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light dark">
<title>CalCOFI whole-dataset NetCDF</title>
<style>
:root{--bg:#fff;--fg:#1a1f24;--muted:#5b6670;--line:#e3e8ec;--accent:#1b6ec2;--chip:#eef4fa;--head:#f6f8fa}
@media (prefers-color-scheme:dark){:root{--bg:#12171c;--fg:#e6edf3;--muted:#9aa7b2;--line:#26303a;--accent:#6cb6ff;--chip:#182430;--head:#182028}}
*{box-sizing:border-box}body{margin:0;padding:2rem 1.25rem 4rem;background:var(--bg);color:var(--fg);
font:16px/1.55 Inter,-apple-system,BlinkMacSystemFont,"Segoe UI",system-ui,sans-serif}
.wrap{max-width:52rem;margin:0 auto}h1{font-size:1.5rem;margin:0 0 .2rem}
.sub{color:var(--muted);margin:0 0 1.5rem;font-size:.95rem}
a{color:var(--accent);text-decoration:none}a:hover{text-decoration:underline}
.scroll{overflow-x:auto;border:1px solid var(--line);border-radius:8px}
table{border-collapse:collapse;width:100%;font-size:.92rem}
th,td{text-align:left;padding:.5rem .7rem;border-bottom:1px solid var(--line);white-space:nowrap}
th{background:var(--head);font-weight:600;font-size:.82rem;text-transform:uppercase;letter-spacing:.04em;color:var(--muted)}
tr:last-child td{border-bottom:none}td.num{text-align:right;font-variant-numeric:tabular-nums}
.note{background:var(--chip);border:1px solid var(--line);border-radius:8px;padding:.8rem 1rem;font-size:.88rem;margin:1.5rem 0;color:var(--muted)}
code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.85em}
footer{margin-top:2.5rem;font-size:.82rem;color:var(--muted)}
</style></head><body><div class="wrap">
<h1>CalCOFI whole-dataset NetCDF</h1>
<p class="sub">CF Discrete-Sampling-Geometry profile files — one self-documenting file per dataset.</p>
<div class="scroll"><table>
<thead><tr><th>file</th><th style="text-align:right">size</th></tr></thead>
<tbody>$rows</tbody></table></div>

<div class="note">
<b>What these are.</b> Each file is a single CF profile dataset:
<code>featureType=Profile</code>, one profile per CTD cast, depth levels stored as a
contiguous ragged array, and each canonical sensor its own variable with its own
units and <code>long_name</code>. Unlike a Parquet extract, the file carries its own
documentation — a CF-aware tool can read it without reference to anything else.
<br><br>
<b>Provenance.</b> Built <b>$BUILT</b> from the CalCOFI integrated database
snapshot of <b>$SNAPSHOT</b>. For the authoritative versioned tables see the
<a href="https://storage.calcofi.io/calcofi-db/ducklake/releases/">Parquet releases</a>;
for filtered subsets rather than whole datasets see
<a href="https://erddap.calcofi.io">erddap.calcofi.io</a>, which can also emit
NetCDF for any query.
<br><br>
<b>Scope.</b> Canonical sensors only. <code>ctd_thin</code> is the adaptively-thinned
headline table; <code>ctd_measurement</code> is the full-resolution record.
</div>

<footer>Generated by <code>scripts/publish_netcdf.sh</code> in
<a href="https://github.com/CalCOFI/workflows">CalCOFI/workflows</a>.</footer>
</div></body></html>
HTML

gcs_cp "$TMP/index.html" "$DEST/index.html" "text/html" "no-cache"
rm -rf "$TMP"

echo
echo "published: $WEB/"
for f in "${FILES[@]}"; do echo "           $WEB/$(basename "$f")"; done
