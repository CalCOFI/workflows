#!/usr/bin/env bash
# Publish the per-cruise CF Profile NetCDF (built by gen_ctd_netcdf.R) as a live
# ERDDAP dataset. This is the "native ERDDAP path" from bench_erddap_ctd.qmd:
# EDDTableFromNcCFFiles over 96 per-cruise files served as ONE datasetID, giving
# true CF .ncCF/.ncCFMA downloads (cdm_data_type=Profile) alongside the existing
# DuckDB-backed long datasets (cdm_data_type=Point).
#
# Run ON THE CALCOFI HOST (needs root: /share/erddap is owned by another uid):
#   sudo bash /share/github/CalCOFI/workflows/scripts/deploy_ctd_netcdf.sh [thin|measurement]
#
# Idempotent: re-running refreshes the published files and re-flags the dataset.
# NOTE the files are published as HARDLINKS (same filesystem, no extra space), so
# re-run this after any gen_ctd_netcdf.R rebuild or the served copies go stale.
#
# HEAP CAUTION: the live ERDDAP runs a 4g heap and already serves 7 datasets.
# bench_erddap_ctd.qmd measured per-cruise NetCDF load peaks at a 2g cap of
# ~879 MB (thin) and ~1099 MB (measurement). Deploy `thin` first and confirm the
# container is healthy before adding `measurement`.
set -euo pipefail

TABLE="${1:-thin}"
case "$TABLE" in
  thin)        DSID="calcofi_ctd_thin_nc" ;;
  measurement) DSID="calcofi_ctd_measurement_nc" ;;
  *) echo "usage: $0 [thin|measurement]" >&2; exit 2 ;;
esac

WF=/share/github/CalCOFI/workflows
SRC="/share/data/erddap-duckdb/netcdf/${TABLE}"
DST="/share/erddap/datasets/${DSID}"
XML="${WF}/data/bench_erddap/prod_${DSID}.xml"
DATASETS_XML=/share/github/CalCOFI/erddap/content/datasets.xml
FLAGDIR=/share/erddap/data/hardFlag

[ -d "$SRC" ] || { echo "missing source NetCDF dir: $SRC (run gen_ctd_netcdf.R)" >&2; exit 1; }
[ -f "$XML" ] || { echo "missing dataset xml: $XML (run gen_prod_netcdf_datasets.R)" >&2; exit 1; }

# 1. publish the .nc files where the erddap container can read them
#    (/share/erddap/datasets is bind-mounted at /datasets — see CalCOFI/erddap README)
echo "==> publishing $(ls "$SRC"/*.nc | wc -l) NetCDF files -> $DST"
mkdir -p "$DST"
rm -f "$DST"/*.nc
cp -al "$SRC"/*.nc "$DST"/            # hardlink: instant, same filesystem, no duplication
chmod -R a+rX "$DST"
echo "    published: $(ls "$DST"/*.nc | wc -l) files, $(du -sh "$DST" | cut -f1) (hardlinked)"

# 2. install the <dataset> block into datasets.xml (idempotent: replace if present)
if grep -q "datasetID=\"${DSID}\"" "$DATASETS_XML"; then
  echo "==> ${DSID} already in datasets.xml — leaving as-is (edit by hand to change)"
else
  cp -p "$DATASETS_XML" "${DATASETS_XML}.bak.$(date +%Y%m%d%H%M%S)"
  python3 - "$DATASETS_XML" "$XML" <<'PY'
import sys, xml.etree.ElementTree as ET
ds_path, block_path = sys.argv[1], sys.argv[2]
block = open(block_path).read().rstrip()
ET.fromstring(block)                                   # fail loudly on malformed XML
txt = open(ds_path).read()
assert "</erddapDatasets>" in txt, "no </erddapDatasets> close tag"
open(ds_path, "w").write(txt.replace("</erddapDatasets>", block + "\n\n</erddapDatasets>"))
print("    inserted <dataset> block before </erddapDatasets>")
PY
  python3 -c "import xml.etree.ElementTree as ET; ET.parse('$DATASETS_XML'); print('    datasets.xml parses OK')"
fi

# 3. ask ERDDAP to load it now rather than waiting for the LoadDatasets cycle
mkdir -p "$FLAGDIR" && touch "${FLAGDIR}/${DSID}"
echo "==> flagged ${DSID} for reload (loadDatasetsMinMinutes=15; may take a few min)"
echo
echo "verify:  curl -sI https://erddap.calcofi.io/erddap/info/${DSID}/index.json"
echo "         https://erddap.calcofi.io/erddap/tabledap/${DSID}.html"
echo "commit:  git -C /share/github/CalCOFI/erddap add content/datasets.xml &&"
echo "         git -C /share/github/CalCOFI/erddap commit -m 'erddap: serve ${DSID} (CF Profile NetCDF)' && git -C /share/github/CalCOFI/erddap push"
