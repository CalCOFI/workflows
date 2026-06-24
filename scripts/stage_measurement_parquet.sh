#!/usr/bin/env bash
# Stage the denormalized ctd_measurement Parquet for the Approach-A
# (EDDTableFromParquetFiles) benchmark cell — the same columns the DuckDB view
# serves, but physically materialized and partitioned by cruise_key (the "just
# split/denormalize the Parquet" fix). `time` is written as epoch-seconds DOUBLE
# (file-based ERDDAP reads the double directly; only the JDBC path needs a real
# TIMESTAMP). Strict DuckDB memory_limit so this never blows the no-swap host.
#
# Run with the bench ERDDAP STOPPED. ~20 GB output, a few minutes.
set -e
DB=/ssd/erddap-bench/bin/duckdb
DBFILE=/ssd/erddap-bench/duckdb/calcofi_ctd.db
OUT=/ssd/erddap-bench/staged/A_measurement
rm -rf "$OUT"; mkdir -p "$OUT"
echo "staging denormalized ctd_measurement -> $OUT (partitioned by cruise_key)"
"$DB" "$DBFILE" -readonly -c "
  SET memory_limit='2GB'; SET threads=2; SET temp_directory='/ssd/erddap-bench/tmp';
  SET preserve_insertion_order=false;
  COPY (
    SELECT * REPLACE (epoch(time)::DOUBLE AS time)
    FROM ctd_measurement_erddap
  ) TO '$OUT' (FORMAT parquet, PARTITION_BY (cruise_key), OVERWRITE_OR_IGNORE);
"
echo "done. size:"; du -sh "$OUT"
echo "partitions:"; ls "$OUT" | head -3; echo "  ... ($(ls "$OUT" | wc -l) cruise partitions)"
