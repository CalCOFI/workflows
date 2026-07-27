#!/usr/bin/env bash
# Retire an ERDDAP dataset: remove its <dataset> block from datasets.xml, drop the
# published source files, and tell ERDDAP to forget it.
#
# The inverse of deploy_ctd_netcdf.sh. Written as a script rather than an ad-hoc
# command because /share/github/CalCOFI/erddap/content is owned by another uid, so
# this needs root — and a root one-liner that edits production config by regex is
# exactly the thing that should be reviewable in git instead.
#
# Run ON THE CALCOFI HOST:
#   sudo bash /share/github/CalCOFI/workflows/scripts/retire_erddap_dataset.sh <datasetID> [--purge-files]
#
# --purge-files also deletes /share/erddap/datasets/<datasetID>/ (the served copy).
# Omit it to leave the files in place and only stop serving them.
set -euo pipefail

DSID="${1:-}"
PURGE="${2:-}"
[ -n "$DSID" ] || { echo "usage: $0 <datasetID> [--purge-files]" >&2; exit 2; }

DATASETS_XML=/share/github/CalCOFI/erddap/content/datasets.xml
SERVED=/share/erddap/datasets/${DSID}
FLAGDIR=/share/erddap/data/hardFlag

[ -f "$DATASETS_XML" ] || { echo "missing $DATASETS_XML" >&2; exit 1; }
grep -q "datasetID=\"${DSID}\"" "$DATASETS_XML" || {
  echo "==> ${DSID} not present in datasets.xml — nothing to remove"; }

BAK="${DATASETS_XML}.bak.$(date +%Y%m%d%H%M%S)"
cp -p "$DATASETS_XML" "$BAK"
echo "==> backup: $BAK"

python3 - "$DATASETS_XML" "$DSID" <<'PY'
import re, sys, pathlib, xml.etree.ElementTree as ET
path, dsid = pathlib.Path(sys.argv[1]), sys.argv[2]
text = path.read_text()
# non-greedy to the first </dataset>; dataset blocks do not nest
pat = re.compile(r'\n?[ \t]*<dataset\b[^>]*datasetID="%s"[^>]*>.*?</dataset>[ \t]*\n?'
                 % re.escape(dsid), re.S)
new, n = pat.subn("\n", text)
if not n:
    print(f"    no <dataset> block for {dsid}")
    sys.exit(0)
ET.fromstring(new)                       # refuse to write XML ERDDAP could not load
path.write_text(new)
print(f"    removed {n} block(s), {len(text)-len(new)} bytes")
PY

python3 -c "import xml.etree.ElementTree as ET; ET.parse('$DATASETS_XML'); print('    datasets.xml parses OK')"

if [ "$PURGE" = "--purge-files" ] && [ -d "$SERVED" ]; then
  echo "==> removing served files: $SERVED ($(du -sh "$SERVED" | cut -f1))"
  rm -rf "$SERVED"
fi

# A removed dataset needs ERDDAP to drop it from its in-memory set; flagging the id
# makes it re-evaluate that datasetID on the next LoadDatasets instead of waiting.
mkdir -p "$FLAGDIR" && touch "${FLAGDIR}/${DSID}"
echo "==> flagged ${DSID} (loadDatasetsMinMinutes=15; may take a few minutes)"
echo
echo "verify:  curl -sI https://erddap.calcofi.io/erddap/info/${DSID}/index.json   # expect 404"
echo "commit:  git -C /share/github/CalCOFI/erddap add content/datasets.xml && \\"
echo "         git -C /share/github/CalCOFI/erddap commit -m 'erddap: retire ${DSID}'"
