#!/usr/bin/env bash
# Benchmark CTD serving backends on an isolated ERDDAP (port 8091).
# For each (approach x table) cell: splice its <dataset> block into the bench
# datasets.xml, recreate the container with a clean JVM at the chosen heap,
# measure the load phase (does it bind without OOM; peak JVM heap + container
# RSS; load seconds), then run representative queries (median latency, bytes,
# peak heap/RSS). Appends one row per cell to a results CSV.
#
# Usage: bench_erddap.sh <heap e.g. 2g> <cell1 cell2 ...>
#   cells: thin_duckdb thin_parquet thin_csv meas_duckdb meas_parquet
set -u
HEAP="${1:-2g}"; shift || true
CELLS=("$@"); [ ${#CELLS[@]} -eq 0 ] && CELLS=(thin_duckdb thin_parquet thin_csv meas_duckdb meas_parquet)
LOAD_TIMEOUT="${LOAD_TIMEOUT:-300}"   # seconds to wait for a dataset to bind
MIN_AVAIL_MB="${MIN_AVAIL_MB:-1500}"  # host-memory guard (no swap on this VM)

BENCH=/ssd/erddap-bench
BLOCKS=/share/github/CalCOFI/workflows/data/bench_erddap
CONTENT=$BENCH/content/datasets.xml   # owned by container uid 1000 -> write via sudo
HEADER=$BENCH/bench/header.xml         # dir we own
COMPOSE=(docker compose -f /share/github/CalCOFI/server/docker-compose.bench.yml -p erddap-bench)
BASE=http://localhost:8091/erddap/tabledap
TS=$(date +%Y%m%d_%H%M%S)
RES=$BENCH/bench/results_${TS}.csv
mkdir -p "$BENCH/bench"
echo "cell,table,approach,heap,load_status,load_secs,load_peak_heap_mb,load_peak_rss_mb,q1_das_ms,q2_cruise_ms,q3_type200_ms,q4_dump_ms,q2_rows,q3_rows,q4_rows,query_peak_heap_mb,query_peak_rss_mb" > "$RES"
echo "results -> $RES (heap=$HEAP, cells: ${CELLS[*]})"

# JVM heap used (MB) via jcmd; 0 if unavailable (e.g. mid-OOM)
heap_mb() { docker exec erddap_bench jcmd 1 GC.heap_info 2>/dev/null \
  | grep -oE 'used [0-9]+K' | head -1 | grep -oE '[0-9]+' | awk '{printf "%d", $1/1024}'; }
# container RSS (MB) via cgroup v2
rss_mb() { local b; b=$(docker exec erddap_bench cat /sys/fs/cgroup/memory.current 2>/dev/null); \
  [ -n "$b" ] && awk -v b="$b" 'BEGIN{printf "%d", b/1048576}' || echo 0; }

assemble() { # $1=block file -> bench datasets.xml (sudo: dir owned by container uid)
  local tmp; tmp=$(mktemp)
  { sed -n '1,/BENCH: dataset block spliced/p' "$HEADER"
    cat "$1"
    printf '\n</erddapDatasets>\n'; } > "$tmp"
  sudo cp "$tmp" "$CONTENT"; rm -f "$tmp"
}

# median of N curl time_total (ms) for a URL; echoes "median_ms last_bytes"
timeit() { local url="$1" n="$2" t bytes; local -a arr=()
  for i in $(seq 1 "$n"); do
    read -r t bytes < <(curl -s -o /dev/null --max-time 180 -w '%{time_total} %{size_download}' "$url" 2>/dev/null || echo "999 0")
    arr+=("$t"); done
  bytes=${bytes:-0}
  printf '%s\n' "${arr[@]}" | sort -n | awk -v b="$bytes" '{a[NR]=$1} END{m=(NR%2)?a[(NR+1)/2]:(a[NR/2]+a[NR/2+1])/2; printf "%d %s", m*1000, b}'
}

# write a static header file once (everything up to the splice marker)
cat > "$HEADER" <<'HDR'
<?xml version="1.0" encoding="UTF-8" ?>
<erddapDatasets>
<cacheMinutes>60</cacheMinutes>
<decompressedCacheMaxGB>10</decompressedCacheMaxGB>
<drawLandMask>over</drawLandMask>
<logLevel>info</logLevel>
<loadDatasetsMinMinutes>1</loadDatasetsMinMinutes>
<loadDatasetsMaxMinutes>60</loadDatasetsMaxMinutes>
<nGridThreads>1</nGridThreads>
<nTableThreads>1</nTableThreads>
<!-- BENCH: dataset block spliced -->
HDR

for cell in "${CELLS[@]}"; do
  case "$cell" in
    thin_*) TABLE=thin;        DID="calcofi_ctd_${cell}";;
    meas_*) TABLE=measurement; DID="calcofi_ctd_measurement_${cell#meas_}";;
  esac
  case "$cell" in *_duckdb) APP=duckdb;; *_parquet) APP=parquet;; *_csv) APP=csv;; esac
  BLOCK="$BLOCKS/${DID}.xml"
  echo "================ CELL $cell  (DID=$DID, heap=$HEAP) ================"
  [ -f "$BLOCK" ] || { echo "  MISSING block $BLOCK, skip"; continue; }

  avail=$(free -m | awk '/Mem:/{print $7}')
  if [ "${avail:-0}" -lt "$MIN_AVAIL_MB" ]; then echo "  ABORT cell: host avail ${avail}MB < ${MIN_AVAIL_MB}MB"; break; fi
  rm -rf "$BENCH"/data/* 2>/dev/null   # cold: clear datasetInfo/cache/logs
  assemble "$BLOCK"
  BENCH_ERDDAP_MEMORY="$HEAP" "${COMPOSE[@]}" up -d --force-recreate erddap_bench >/dev/null 2>&1

  # wait for tomcat
  for i in $(seq 1 40); do [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8091/erddap/index.html)" = 200 ] && break; sleep 2; done

  # LOAD phase: poll .das until loaded / failed / timeout, sampling heap+rss
  # Poll until loaded / OOM / timeout. File datasets (Parquet/CSV) DEFER on first
  # start to build fileTable.nc, then load on ERDDAP's own follow-up cycle — just
  # keep polling (do NOT touch the reload flag: that triggers a reloadASAP churn
  # loop that never settles). A truly broken dataset times out; OOM stops early.
  t0=$(date +%s); lph=0; lpr=0; status=timeout
  while [ $(( $(date +%s) - t0 )) -lt "$LOAD_TIMEOUT" ]; do
    h=$(heap_mb); r=$(rss_mb); [ "${h:-0}" -gt "$lph" ] && lph=$h; [ "${r:-0}" -gt "$lpr" ] && lpr=$r
    code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/${DID}.das")
    if [ "$code" = 200 ]; then    # confirm STABLE (file datasets briefly flap 200/503 while settling)
      sleep 3; c2=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/${DID}.das")
      sleep 3; c3=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/${DID}.das")
      [ "$c2" = 200 ] && [ "$c3" = 200 ] && { status=loaded; break; }
    fi
    if docker exec erddap_bench bash -lc 'grep -lqE "OutOfMemoryError" /erddapData/logs/log.txt 2>/dev/null'; then status=OOM; break; fi
    sleep 2
  done
  load_secs=$(( $(date +%s) - t0 ))
  echo "  load: status=$status secs=$load_secs peak_heap=${lph}MB peak_rss=${lpr}MB"

  q1=-1; q2=-1; q3=-1; q4=-1; q2r=0; q3r=0; q4r=0; qph=$lph; qpr=$lpr
  if [ "$status" = loaded ]; then
    CRU='%221998-04-31JD%22'; T1='%22temperature_ave%22'; T2='%22salinity_ave_corr%22'
    read -r q1 _   < <(timeit "$BASE/${DID}.das" 5)
    h=$(heap_mb); r=$(rss_mb); [ "${h:-0}" -gt "$qph" ] && qph=$h; [ "${r:-0}" -gt "$qpr" ] && qpr=$r
    read -r q2 q2r < <(timeit "$BASE/${DID}.csv?time,depth,measurement_value&cruise_key=$CRU&measurement_type=$T1" 3)
    h=$(heap_mb); r=$(rss_mb); [ "${h:-0}" -gt "$qph" ] && qph=$h; [ "${r:-0}" -gt "$qpr" ] && qpr=$r
    read -r q3 q3r < <(timeit "$BASE/${DID}.csv?time,latitude,longitude,depth,measurement_value&measurement_type=$T2&depth%3E=0&depth%3C=200" 2)
    h=$(heap_mb); r=$(rss_mb); [ "${h:-0}" -gt "$qph" ] && qph=$h; [ "${r:-0}" -gt "$qpr" ] && qpr=$r
    read -r q4 q4r < <(timeit "$BASE/${DID}.csv?&cruise_key=$CRU" 2)
    h=$(heap_mb); r=$(rss_mb); [ "${h:-0}" -gt "$qph" ] && qph=$h; [ "${r:-0}" -gt "$qpr" ] && qpr=$r
    echo "  q1_das=${q1}ms q2_cruise=${q2}ms(${q2r}B) q3_type200=${q3}ms(${q3r}B) q4_dump=${q4}ms(${q4r}B) peak_heap=${qph}MB peak_rss=${qpr}MB"
  fi
  echo "$cell,$TABLE,$APP,$HEAP,$status,$load_secs,$lph,$lpr,$q1,$q2,$q3,$q4,$q2r,$q3r,$q4r,$qph,$qpr" >> "$RES"
done
echo "=== DONE -> $RES ==="; column -s, -t < "$RES"
