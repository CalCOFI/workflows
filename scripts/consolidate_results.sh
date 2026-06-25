#!/usr/bin/env bash
# Consolidate per-run bench CSVs (/share/data/erddap-bench/bench/results_*.csv) into one
# row-per-cell table (latest wins) and copy it where the report (rstudio) can read
# it: workflows/data/bench_erddap/results_all.csv (written via sudo; dir is owned
# by the container/root). Run after the benchmark cells complete.
set -e
BENCH=/share/data/erddap-bench/bench
OUT=/share/github/CalCOFI/workflows/data/bench_erddap/results_all.csv
tmp=$(mktemp)
hdr=$(head -1 "$(ls -t "$BENCH"/results_*.csv | head -1)")
{ echo "$hdr"
  # newest files first; keep the first row seen per cell (= most recent)
  ls -t "$BENCH"/results_*.csv | xargs cat | grep -vE '^cell,' | awk -F, 'NF>1 && !seen[$1]++'
} > "$tmp"
sudo cp "$tmp" "$OUT"; rm -f "$tmp"
echo "wrote $OUT"; column -s, -t < "$OUT"
