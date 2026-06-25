#!/usr/bin/env bash
# Evaluate how Parquet partitioning/ordering of the LONG-format CTD measurements
# affects a lat/lon/depth bounding-box query for one variable (Lynn DeWitt's
# question). All served via DuckDB, so this measures DuckDB partition-pruning +
# Parquet row-group skipping. Builds each layout, times the bbox query, captures
# EXPLAIN ANALYZE, then deletes the layout (disk-safe on the no-swap host).
#
#   bash scripts/bench_parquet_layout.sh
set -u
DB=/share/data/erddap-bench/bin/duckdb
SRCDB=/share/data/erddap-duckdb/duckdb/calcofi_ctd.db      # has ctd_measurement_erddap view (denormalized)
EXP=/share/data/erddap-exp; mkdir -p "$EXP"
TMP=/share/data/erddap-duckdb/tmp
PRAGMA="SET memory_limit='3GB'; SET threads=3; SET temp_directory='$TMP'; SET preserve_insertion_order=false;"
RES=$EXP/layout_results.csv
echo "layout,build_secs,size,nfiles,query_secs_median,scan_rows,result_rows" > "$RES"

# bbox query for one variable (temperature_ave), depth 0-200m, ~393k rows
read -r -d '' WHERE <<'EOF'
measurement_type='temperature_ave' AND latitude BETWEEN 32 AND 34
  AND longitude BETWEEN -121 AND -119 AND depth BETWEEN 0 AND 200
EOF

timed_query() {  # $1 = FROM-source SQL ; echoes "median_secs result_rows" (shell-timed; startup ~0.02s)
  local from="$1" rows=0 t0 t1 times=""
  $DB "$SRCDB" -readonly -noheader -list -c "$PRAGMA SELECT count(*) FROM $from WHERE $WHERE;" >/dev/null 2>&1  # warm
  for i in 1 2 3; do
    t0=$(date +%s.%N)
    rows=$($DB "$SRCDB" -readonly -noheader -list -c "$PRAGMA SELECT count(*) FROM $from WHERE $WHERE;" 2>/dev/null | tr -dc '0-9')
    t1=$(date +%s.%N)
    times+="$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.3f", b-a}')"$'\n'
  done
  echo "$(printf '%s' "$times" | grep -E '[0-9]' | sort -n | sed -n 2p) ${rows:-0}"
}
explain_scan() {  # $1 = FROM, $2 = name ; save EXPLAIN ANALYZE for the report
  $DB "$SRCDB" -readonly -box -c "$PRAGMA EXPLAIN ANALYZE
SELECT count(*) FROM $1 WHERE $WHERE;" > "$EXP/explain_${2}.txt" 2>&1
  echo "see explain_${2}.txt"
}

run_layout() {  # $1 name, $2 build SELECT (empty=use prod view), $3 partition col
  local name="$1" sel="$2" part="$3"
  local dir="$EXP/$name"
  local from="" bsec=0 size="" nf=0 q="" rows=0 scan=""
  if [ -z "$sel" ]; then
    from="ctd_measurement_erddap"; size="(view over cruise-partitioned raw + JOIN)"; nf=95
  else
    rm -rf "$dir"; local b0; b0=$(date +%s)
    $DB "$SRCDB" -readonly -c "$PRAGMA COPY ($sel) TO '$dir' (FORMAT parquet, PARTITION_BY ($part), OVERWRITE_OR_IGNORE);" 2>&1 | tail -1
    bsec=$(( $(date +%s) - b0 ))
    size=$(du -sh "$dir" | cut -f1); nf=$(find "$dir" -name '*.parquet' | wc -l)
    from="read_parquet('$dir/**/*.parquet', hive_partitioning=true)"
  fi
  read -r q rows < <(timed_query "$from")
  scan=$(explain_scan "$from" "$name")
  echo "$name,$bsec,$size,$nf,$q,${scan:-NA},$rows" >> "$RES"
  echo "  [$name] build=${bsec}s size=$size files=$nf query=${q}s scan_rows=${scan:-NA} result=$rows"
  [ -n "$sel" ] && rm -rf "$dir"   # reclaim disk before next layout
}

echo "=== Parquet layout experiment (bbox: temperature_ave, 32-34N, 121-119W, 0-200m) ==="
run_layout "A_prodview_cruise_join" "" ""
run_layout "B_denorm_cruise"   "SELECT * FROM ctd_measurement_erddap"                                   "cruise_key"
run_layout "C_denorm_type"     "SELECT * FROM ctd_measurement_erddap"                                   "measurement_type"
run_layout "D_type_spatialsort" "SELECT * FROM ctd_measurement_erddap ORDER BY latitude, longitude, depth" "measurement_type"
echo "=== DONE ==="; column -s, -t < "$RES"
