#!/usr/bin/env bash
# Benchmark DOWNLOAD BREADTH on the isolated ERDDAP (port 8091): what happens when a
# user asks for the WHOLE dataset versus ONE VARIABLE at a time. This is the axis the
# format x schema x granularity matrix (bench_erddap.sh) does not cover — every query
# there is bounded to one cruise or a depth slice, so none of them reproduce the
# out-of-memory failures users hit when they press "Submit" on an unconstrained form.
#
# Usage: bench_download.sh <heap e.g. 2g> <cell1 cell2 ...>
#
# Emits TIDY LONG format (one row per cell x query) rather than widening
# results_all.csv, because the interesting outcome here is a STATUS + an ERROR
# STRING, not just a latency: an OOM, a DuckDB "Out of Memory Error", and a
# successful 12-GB stream are three different things that a single ms column cannot
# distinguish.
#
# The four queries, narrow -> wide, all UNBOUNDED in row count:
#   onevar_1     one variable, whole time/space extent   (the "safe" way)
#   onevar_3     three variables                          (does cost scale with width?)
#   allvars      every variable, no constraint            (the "Submit" button)
#   allvars_das  metadata only                            (control: never touches rows)
#
# KEY METRIC IS TIME-TO-FIRST-BYTE, not total time. A backend that streams starts
# emitting almost immediately regardless of result size; a backend that materializes
# the whole result first shows a long TTFB and then either OOMs or dumps at line
# speed. TTFB separates "streams" from "buffers" in a way total time cannot.
#
# Downloads are capped (MAX_TIME) and discarded — we are measuring server behaviour,
# not client throughput. A capped run is recorded as status=capped with the bytes
# transferred so far, which is NOT a failure; failures are status=error (with the
# server's message) or status=oom.
set -u
HEAP="${1:-2g}"; shift || true
CELLS=("$@"); [ ${#CELLS[@]} -eq 0 ] && CELLS=(thin_duckdb_long meas_duckdb_long thin_netcdf_wide_split meas_netcdf_wide_split)
MAX_TIME="${MAX_TIME:-300}"           # seconds before we stop pulling (status=capped)
LOAD_TIMEOUT="${LOAD_TIMEOUT:-300}"
MIN_AVAIL_MB="${MIN_AVAIL_MB:-1500}"

BENCH=/share/data/erddap-bench
BLOCKS=/share/github/CalCOFI/workflows/data/bench_erddap
CONTENT=$BENCH/content/datasets.xml
HEADER=$BENCH/bench/header.xml
COMPOSE=(docker compose -f /share/github/CalCOFI/server/docker-compose.bench.yml -p erddap-bench)
BASE=http://localhost:8091/erddap/tabledap
TS=$(date +%Y%m%d_%H%M%S)
RES=$BENCH/bench/download_${TS}.csv
mkdir -p "$BENCH/bench"
echo "cell,table,format,schema,granularity,heap,query,nvars,status,http_code,ttfb_ms,total_ms,bytes,peak_heap_mb,peak_rss_mb,error" > "$RES"
echo "results -> $RES (heap=$HEAP, max_time=${MAX_TIME}s, cells: ${CELLS[*]})"

heap_mb() { docker exec erddap_bench jcmd 1 GC.heap_info 2>/dev/null \
  | grep -oE 'used [0-9]+K' | head -1 | grep -oE '[0-9]+' | awk '{printf "%d", $1/1024}'; }
rss_mb() { local b; b=$(docker exec erddap_bench cat /sys/fs/cgroup/memory.current 2>/dev/null); \
  [ -n "$b" ] && awk -v b="$b" 'BEGIN{printf "%d", b/1048576}' || echo 0; }
csv_escape() { printf '%s' "$1" | tr '\n\r"' "   " | cut -c1-300; }  # field is emitted quoted

assemble() { local tmp; tmp=$(mktemp)
  { sed -n '1,/BENCH: dataset block spliced/p' "$HEADER"; cat "$1"; printf '\n</erddapDatasets>\n'; } > "$tmp"
  sudo cp "$tmp" "$CONTENT"; rm -f "$tmp"; }

# Run one download. Echoes: status http_code ttfb_ms total_ms bytes error
# ERDDAP reports failures as an HTTP error WITH a text body, so on non-200 we keep the
# body (truncated) — that is where "OutOfMemoryError" / DuckDB's "Out of Memory Error"
# actually appears, and it is the whole point of this benchmark.
download() {
  local url="$1" body rc out code ttfb total bytes err status
  body=$(mktemp)
  # capture curl's OWN exit status (28 == hit --max-time), not read's
  out=$(curl -s --max-time "$MAX_TIME" -o "$body" \
    -w '%{http_code} %{time_starttransfer} %{time_total} %{size_download}' "$url" 2>/dev/null)
  rc=$?
  read -r code ttfb total bytes <<< "${out:-000 0 0 0}"
  err=""
  if [ "$code" = 200 ]; then
    # a capped stream exits non-zero (28) with a partial body but a 200 header
    if [ "$rc" -ne 0 ] || awk -v t="$total" -v m="$MAX_TIME" 'BEGIN{exit !(t >= m-2)}'; then
      status=capped
    else
      status=ok
    fi
  elif [ "$code" = 000 ]; then
    status=timeout
  else
    err=$(head -c 2000 "$body" | grep -oiE '(java\.lang\.OutOfMemoryError|Out of Memory Error[^"]*|Query error[^"]*|Error[^"]{0,120})' | head -1)
    [ -z "$err" ] && err=$(head -c 200 "$body")
    case "$err" in *[Mm]emory*) status=oom;; *) status=error;; esac
  fi
  rm -f "$body"
  printf '%s %s %d %d %s %s' "$status" "$code" \
    "$(awk -v x="$ttfb" 'BEGIN{printf "%d", x*1000}')" \
    "$(awk -v x="$total" 'BEGIN{printf "%d", x*1000}')" "$bytes" "$(csv_escape "$err")"
}

for cell in "${CELLS[@]}"; do
  DID="$cell"; BLOCK="$BLOCKS/${cell}.xml"
  [ -f "$BLOCK" ] || { echo "  MISSING block $BLOCK, skip"; continue; }
  # Classify from the BLOCK, not the cell name: the production-mirroring cells
  # (calcofi_ctd_measurement_netcdf, ..._duckdb) carry no wide/long/split token in
  # their name, and guessing from the name silently mislabels them in the results.
  case "$cell" in *thin*) TABLE=thin;; *meas*) TABLE=measurement;; *) TABLE=?;; esac
  case "$(grep -oE 'type="EDDTable[A-Za-z]+"' "$BLOCK" | head -1)" in
    *FromDatabase*)     APP=duckdb;;
    *FromNcCFFiles*)    APP=netcdf;;
    *FromParquetFiles*) APP=parquet;;
    *FromAsciiFiles*)   APP=csv;;
    *)                  APP=?;;
  esac
  # long schema declares measurement_value/measurement_type; wide names sensors directly
  if grep -q '<destinationName>measurement_value<' "$BLOCK"; then SCHEMA=long; else SCHEMA=wide; fi
  # granularity from the actual file count behind fileDir (DB-backed cells have none)
  FDIR=$(grep -oE '<fileDir>[^<]+' "$BLOCK" | head -1 | sed 's/<fileDir>//')
  if [ -z "$FDIR" ]; then GRAN=view
  else
    NF=$(find "$FDIR" -maxdepth 2 -type f \( -name '*.nc' -o -name '*.parquet' -o -name '*.csv' \) 2>/dev/null | wc -l)
    [ "$NF" -le 1 ] && GRAN=lumped || GRAN=split
  fi
  echo "======== CELL $cell (table=$TABLE $APP/$SCHEMA/$GRAN heap=$HEAP) ========"
  avail=$(free -m | awk '/Mem:/{print $7}')
  if [ "${avail:-0}" -lt "$MIN_AVAIL_MB" ]; then echo "  ABORT: host avail ${avail}MB < ${MIN_AVAIL_MB}MB"; break; fi
  rm -rf "$BENCH"/data/* 2>/dev/null
  assemble "$BLOCK"
  BENCH_ERDDAP_MEMORY="$HEAP" "${COMPOSE[@]}" up -d --force-recreate erddap_bench >/dev/null 2>&1
  for i in $(seq 1 40); do [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8091/erddap/index.html)" = 200 ] && break; sleep 2; done

  # wait for the dataset to bind (same stability check as bench_erddap.sh)
  t0=$(date +%s); status=timeout
  while [ $(( $(date +%s) - t0 )) -lt "$LOAD_TIMEOUT" ]; do
    if [ "$(curl -s -o /dev/null -w '%{http_code}' "$BASE/${DID}.das")" = 200 ]; then
      sleep 3; c2=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/${DID}.das")
      [ "$c2" = 200 ] && { status=loaded; break; }
    fi
    docker exec erddap_bench bash -lc 'grep -lqE "OutOfMemoryError" /erddapData/logs/log.txt 2>/dev/null' && { status=OOM; break; }
    sleep 2
  done
  if [ "$status" != loaded ]; then
    echo "  dataset did not load ($status) — recording and moving on"
    echo "$cell,$TABLE,$APP,$SCHEMA,$GRAN,$HEAP,load,0,$status,0,-1,-1,0,0,0," >> "$RES"
    continue
  fi

  # Variable sets. WIDE selects named sensor columns; LONG filters measurement_type,
  # so "one variable" means the same rows either way (the invariant bench_erddap.sh uses).
  if [ "$SCHEMA" = wide ]; then
    Q_ONE="time,latitude,longitude,depth,temperature_ave"
    Q_THREE="time,latitude,longitude,depth,temperature_ave,salinity_ave_corr,oxygen_ml_l_ave_sta_corr"
    Q_ALL=""                                   # empty selection = every variable
    SUF_ONE=""; SUF_THREE=""
  else
    Q_ONE="time,latitude,longitude,depth,measurement_value"
    Q_THREE="time,latitude,longitude,depth,measurement_type,measurement_value"
    Q_ALL=""
    SUF_ONE='&measurement_type=%22temperature_ave%22'
    SUF_THREE='&measurement_type=~%22(temperature_ave|salinity_ave_corr|oxygen_ml_l_ave_sta_corr)%22'
  fi

  run() { # $1=label $2=nvars $3=url
    local h0 r0 out
    h0=$(heap_mb); r0=$(rss_mb)
    out=$(download "$3")
    local h1 r1; h1=$(heap_mb); r1=$(rss_mb)
    [ "${h1:-0}" -lt "${h0:-0}" ] && h1=$h0
    [ "${r1:-0}" -lt "${r0:-0}" ] && r1=$r0
    read -r st code ttfb total bytes err <<< "$out"
    echo "  $1: status=$st code=$code ttfb=${ttfb}ms total=${total}ms bytes=$bytes heap=${h1}MB ${err:+err=$err}"
    echo "$cell,$TABLE,$APP,$SCHEMA,$GRAN,$HEAP,$1,$2,$st,$code,$ttfb,$total,$bytes,$h1,$r1,\"$err\"" >> "$RES"
  }

  run allvars_das 0 "$BASE/${DID}.das"
  run onevar_1    1 "$BASE/${DID}.csv?${Q_ONE}${SUF_ONE}"
  run onevar_3    3 "$BASE/${DID}.csv?${Q_THREE}${SUF_THREE}"
  run allvars     99 "$BASE/${DID}.csv?${Q_ALL}"
done
echo "=== DONE -> $RES ==="; cat "$RES"
