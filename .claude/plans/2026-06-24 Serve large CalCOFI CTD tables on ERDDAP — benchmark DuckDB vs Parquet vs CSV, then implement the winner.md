# Serve large CalCOFI CTD tables on ERDDAP — benchmark DuckDB vs Parquet vs CSV, then implement the winner

## Context

A prior attempt to serve `ctd_wide` on ERDDAP failed: the single ~935 MB
`ctd_wide.parquet` is read **fully into the JVM heap** by `EDDTableFromParquetFiles`
before any filtering, blowing the 4 GB heap on the 15 GB host and aborting the
*entire* `LoadDatasets` run (so all datasets fail). The dataset was disabled.

We want to (1) **benchmark** how the large CTD tables perform on ERDDAP across
serving backends — **DuckDB (via JDBC views over Parquet) vs raw Parquet vs CSV**,
for **long-format** tables — measuring *server memory load* and *query latency*;
then (2) **implement** the winning approach as live ERDDAP datasets. The thesis to
prove: a DuckDB JDBC backend lets ERDDAP **stream** filtered results (predicate
pushdown + partition pruning + disk spill) so the whole table is never on-heap,
fixing the OOM and serving tables that are otherwise too big.

**Decisions (from user):** benchmark → implement the winner; target **`ctd_thin`**
(headline, ~5.5M rows / ~155 MB) and **`ctd_measurement`** (stress test, ~216M
rows / ~14.7 GiB); run on the **production host** (isolated bench container, live
ERDDAP untouched); add the DuckDB driver via a **custom ERDDAP image**.

## Key findings that shape the approach

- **ERDDAP has no native DuckDB type.** `EDDTableFromDuckDb` (issue #448) is a
  March-2026 *proposal*, not implemented. The working path is
  **`EDDTableFromDatabase` + the DuckDB JDBC driver** pointed at a tiny `.db` file
  holding `CREATE VIEW … read_parquet(…)`. Verified against ERDDAP source that
  `EDDTableFromDatabase` supports `<connectionProperty name="…">value</…>` (passed
  verbatim to the JDBC `Properties`), so we can set DuckDB `duckdb.read_only=true`,
  `memory_limit`, `threads`, `temp_directory`.
- **Stock `erddap/erddap:latest` (v2.30)** already ships the PostgreSQL JDBC jar
  (EDDTableFromDatabase plumbing is proven) but **not** DuckDB JDBC → custom image
  required. Latest DuckDB JDBC: **1.3.1.0**.
- **Long tables need a join.** `ctd_thin`/`ctd_measurement` are keyed by
  `ctd_cast_uuid` with `depth_m, measurement_type, measurement_value,
  measurement_qual, cruise_key` (thin adds `cast_dir, retained_reason`). They carry
  **no time/lat/lon** — those live in `ctd_cast` (`datetime_start_utc, latitude,
  longitude, site_key, line, sta`). A DuckDB **view** denormalizes via a logical,
  zero-copy join; raw Parquet cannot join (which is why `ctd_wide` was physically
  materialized and ballooned). `publish_calcofi_to_erddap.qmd:46-49` already
  anticipates "joined views in a later pass."
- **Data lives in GCS, not locally.** `gs://calcofi-db/ducklake/releases/`:
  v2026.06.08 → `ctd_thin/` (hive by `cruise_key`, 155 MiB) + `ctd_cast.parquet`
  (128 MiB) + `ctd_summary/` (3 GiB); **`ctd_measurement` (14.68 GiB) is the
  v2026.04.08 supplemental.** `/share` is a symlink to `/ssd` (≈99 GB free) — fits.
- **Reuse target — `workflows/libs/erddap.R`:** `stage_table_for_erddap()` does the
  ERDDAP transforms (epoch-seconds `time`, `lat/lon/depth` as doubles, drops
  `geom`) but via a **physical `COPY … TO` rewrite** (the ballooning step).
  `erddap_dataset_xml()` + helpers (`.erddap_datavar_xml`, `.duckdb_to_erddap_type`,
  `.erddap_ioos_category`, `.erddap_coord_attrs`, `units_from_metadata`) build the
  per-variable XML from `metadata.json`. **All metadata machinery is reusable
  verbatim** for the DuckDB path; only the source/transform and dataset wrapper tags
  change.

## Approach

Benchmark a **backend × table** matrix on an isolated bench ERDDAP, then promote
the winner into the live config.

| Backend (EDDType) | `ctd_thin` | `ctd_measurement` |
|---|---|---|
| **A. `EDDTableFromParquetFiles`** (current; needs physical denorm) | baseline | expect OOM |
| **B. `EDDTableFromDatabase` + DuckDB view** (join, streaming) | ✔ | expect ✔ |
| **C. `EDDTableFromFiles` CSV** (uncompressed baseline) | slow | disk-prohibitive (a result) |

**Metrics**, at a deliberately low `-Xmx 2g` (then sweep 1g/4g) to expose
differences: binds-without-OOM (pass/fail); peak JVM heap + container RSS during
(P1) dataset load and (P2) queries; median latency (N=11, drop warm-up) for
4 representative queries.

## Pre-flight

- `git pull` in `CalCOFI/erddap`, `CalCOFI/server`, `CalCOFI/workflows` (bind-mounted
  + edited repos). Re-check ERDDAP issue #448 / docs for any change since this plan.
- **Reconcile the live `calcofi_ctd` flag:** a commit disabled it (`active="false"`)
  but exploration found `active="true"` at `erddap/content/datasets.xml:20`. Confirm
  the live ctd_wide is not currently serving + OOM-risky before promotion.

## Implementation

### 1 — Custom ERDDAP image + isolated bench instance
- **`server/erddap/Dockerfile`** (new): `FROM erddap/erddap:latest`; add
  `duckdb_jdbc-1.3.1.0.jar` to `/usr/local/tomcat/webapps/erddap/WEB-INF/lib/` via
  a `DUCKDB_JDBC_VERSION` build ARG. Prefer **vendoring/`COPY`** the jar (build-host
  egress not guaranteed) over `ADD <maven-url>`.
- **`server/docker-compose.bench.yml`** (new): an `erddap_bench` service, **port
  8091**, `ERDDAP_MEMORY=${BENCH_ERDDAP_MEMORY:-2g}`, isolated content/data dirs
  under `/share/erddap-bench/`, mounting `/share/erddap/datasets:ro` (same Parquet
  as prod), `/share/erddap-bench/duckdb:ro` (the `.db`), `/share/erddap-bench/tmp`
  (DuckDB spill). Mirrors the live `erddap` env from `server/docker-compose.yml`.
  Live ERDDAP on 8090 is never touched.

### 2 — Stage Parquet + build the DuckDB `.db`
- `gsutil -m cp` the Parquet to host so both backends see identical files under
  `/share/erddap/datasets/{calcofi_ctd_thin,calcofi_ctd_measurement,calcofi_ctd_cast}/`
  (thin v2026.06.08; measurement v2026.04.08 supplemental; cast v2026.06.08).
  `df -h /ssd` pre-flight (~15 GB + Docker overlay).
- **`workflows/libs/erddap_duckdb.R`** (new) — `build_ctd_duckdb()`: open a DuckDB
  built with an engine matching JDBC **1.3.1.0**, `SET memory_limit='1500MB',
  threads=2, temp_directory='/erddap/tmp'`, then `CREATE OR REPLACE VIEW
  ctd_thin_erddap` / `ctd_measurement_erddap` joining the long Parquet to
  `ctd_cast.parquet` `USING (ctd_cast_uuid)`, emitting `epoch(datetime_start_utc)`
  as `time`, `lat/lon/depth_m` as doubles (canonical ERDDAP names). Paths inside the
  views are **container paths** (`/datasets/…`). Write `BUILD_VERSION.txt`.

### 3 — Generate datasets.xml for all three backends
- **`erddap_duckdb_dataset_xml()`** in the new lib: emits the `EDDTableFromDatabase`
  wrapper (`<sourceUrl>jdbc:duckdb:/erddap/duckdb/calcofi_ctd.db</sourceUrl>`,
  `<driverName>org.duckdb.DuckDBDriver</driverName>`, the four
  `<connectionProperty>` tags, `<schemaName>main</schemaName>`, `<tableName>`,
  `<columnNameQuotes>"</columnNameQuotes>`, `<orderBy>cruise_key, ctd_cast_uuid,
  measurement_type, depth</orderBy>`) and **reuses `.erddap_datavar_xml()`** for every
  column. `cdm_data_type=TrajectoryProfile`, `cf_role=trajectory_id` on
  `ctd_cast_uuid`, and **`subsetVariables` = only low-cardinality cols**
  (`cruise_key, site_key, measurement_type, cast_dir`) — never `ctd_cast_uuid`/`depth`.
- **A (Parquet)** + **C (CSV)** blocks: reuse the existing `stage_table_for_erddap()`
  / `erddap_dataset_xml()` against staged single-file Parquet (A) and an
  `EDDTableFromFiles`/ascii CSV export (C, `ctd_thin` only).
- Drive it all from **`workflows/bench_erddap_ctd.qmd`** (new): stage → build `.db`
  → generate the 3 backend × 2 table blocks → run the harness → render report.

### 4 — Benchmark harness + report
- **`workflows/scripts/bench_erddap.sh`** (new): background 1 Hz sampler of JVM heap
  (`docker exec erddap_bench jcmd 1 GC.heap_info`) + container RSS (`docker stats` /
  cgroup `memory.current`), peaks split into P1 (load) / P2 (query); grep
  `/share/erddap-bench/data/logs/log.txt` for `OutOfMemoryError` / `Too much data` /
  `Bad line(s)`. Latency via `curl -w '%{http_code} %{time_total} %{size_download}'`,
  median of N=11. Queries per dataset: (1) `.das`/`.dds` metadata; (2) single-cruise
  + one `measurement_type` (subsetVariable pushdown); (3) `measurement_type` +
  `depth>=0&depth<=200`; (4) large dump (whole year `time>=…&time<=…`). Sweep heap
  2g → 1g → 4g. Archive raw CSVs under `/share/erddap-bench/data/bench/<ts>/`.
- Report → `workflows/_output/bench_erddap_ctd.html`: environment block, the
  matrix table per heap, heap/RSS time-series (A's spike→OOM vs B's flat streaming),
  latency bars, and a verdict + exact promotion delta.

### 5 — Promote the winner to prod (expected: B / DuckDB)
- `server/docker-compose.yml`: switch live `erddap` from `image: erddap/erddap:latest`
  to `build: ./erddap` (keep old tag as a rollback comment); add `:/erddap/duckdb:ro`
  + `/erddap/tmp` mounts. Copy validated `.db` to `/share/erddap/duckdb/`.
- `erddap/content/datasets.xml`: splice the winning `calcofi_ctd_thin` +
  `calcofi_ctd_measurement` blocks; retire/`active="false"` the old `calcofi_ctd`
  (ctd_wide) block. Commit/push the bind-mounted `CalCOFI/erddap` repo.
- `docker compose build erddap && up -d erddap`; per-dataset `touch
  /share/erddap/data/flag/<datasetID>`.
- Extend **`publish_calcofi_to_erddap.qmd`**: add an `eddtype` column to the `cfg`
  tribble and branch the publish loop (parquet rows → existing path; duckdb rows →
  `build_ctd_duckdb()` + `erddap_duckdb_dataset_xml()`), so this stays one notebook /
  one metadata source.

## Files

**New:** `server/erddap/Dockerfile`; `server/docker-compose.bench.yml`;
`workflows/libs/erddap_duckdb.R`; `workflows/scripts/bench_erddap.sh`;
`workflows/bench_erddap_ctd.qmd`; host dirs `/share/erddap-bench/{content,data,duckdb,tmp}`.
**Modify (at promotion):** `server/docker-compose.yml`;
`erddap/content/datasets.xml`; `workflows/publish_calcofi_to_erddap.qmd`.
**Reuse:** `workflows/libs/erddap.R` (all metadata/XML helpers).

## Verification

1. **Bench binds:** `curl localhost:8091/erddap/tabledap/calcofi_ctd_thin.das`
   returns 200 for B; confirm A's `ctd_measurement` OOMs (non-200 + `OutOfMemoryError`
   in log) — that's the headline result, not a failure.
2. **Memory thesis:** heap/RSS time-series shows B flat under the large dump (q4)
   while A spikes; B's `ctd_measurement` binds at 2g heap where A cannot.
3. **Correctness:** a B query (q2) returns the same rows/values as the equivalent
   DuckDB query run directly against the Parquet (spot-check a cruise × depth).
4. **Latency:** matrix filled; B's filtered queries (q2/q3) fast via partition
   pruning; report renders.
5. **Prod promotion:** after splice, `curl
   https://erddap.calcofi.io/erddap/tabledap/calcofi_ctd_thin.das`, run q1–q4 at 4g,
   watch `/share/erddap/data/log.txt`, and confirm the **other 6 datasets still load**
   (a bad block aborts the whole run). Rollback = revert the splice + `build`→`image`.

## Risks & caveats

- **DuckDB JDBC ↔ build-engine version pin (top risk):** the `.db` storage format +
  Parquet reader must match `duckdb_jdbc 1.3.1.0`. Build the `.db` with the matching
  DuckDB minor; record `BUILD_VERSION.txt`; rebuild on any jar bump.
- **Double memory budget:** ERDDAP heap (4g) and DuckDB `memory_limit` (1.5g) are
  separate allocations on a 15 GB host also running Postgres/RStudio/Varnish. Keep
  `memory_limit`/`threads` low + force `temp_directory` spill so a big dump degrades
  to disk, not OOM. Cap pool concurrency × per-conn memory.
- **`ctd_measurement` provenance:** it's the v2026.04.08 supplemental, not in the
  current release. Decide at promotion whether prod serves it (heavy) or `ctd_summary`
  (3 GiB) — only the view's `read_parquet` glob differs.
- **CF semantics:** long format (one `measurement_value` keyed by `measurement_type`)
  is not a classic CF multi-variable profile; ERDDAP serves it but flag the
  discriminator. Per-type convenience views are cheap if needed.
- **Read-only concurrency** is safe (DuckDB read-only allows multiple connections);
  validate under a concurrent q3+q4 bench cell.
