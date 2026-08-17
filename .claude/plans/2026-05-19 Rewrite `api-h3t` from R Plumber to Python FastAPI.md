# Rewrite `api-h3t` from R Plumber to Python FastAPI

## Context

`api-h3t` is the H3 hex tile API at `/Users/bbest/Github/CalCOFI/api-h3t/`,
consumed by `int-app` (MapLibre, one HTTP request per tile per pan/zoom),
fronted by Varnish at `h3t.calcofi.io`. It's currently ~380 LOC of R + Plumber
that calls `sqlglot` (Python) via reticulate for SQL validation.

**Motivation:** Headroom for future workload — the user expects more users /
heavier queries. Current per-request perf is fine; the worry is concurrent
cache-miss bursts (e.g. a new species filter forcing N fresh tiles
simultaneously). Plumber serializes requests per worker; FastAPI + uvicorn
handles them concurrently. Secondary wins: drop the R+Python polyglot Docker
image, shrink the codebase ~40%, and run `sqlglot` natively.

**Performance claim being bought:** Concurrency on cache miss, not per-request
latency. DuckDB dominates and is unchanged.

## Target architecture

```
api-h3t-py/
├── app/
│   ├── __init__.py
│   ├── main.py             # FastAPI app, routes, middleware
│   ├── config.py           # env vars, constants
│   ├── db.py               # DuckDB connection + per-request cursor
│   ├── sql_validate.py     # COPY VERBATIM from existing api-h3t/sql_validate.py
│   ├── h3t_query.py        # port of h3t_query.R
│   └── tiles.py            # h3j payload assembly, etag, cache headers
├── tests/
│   ├── test_sql_validate.py   # already covered by existing api-h3t — extend
│   ├── test_h3t_query.py      # parity vs R via golden outputs
│   ├── test_endpoints.py      # FastAPI TestClient — etag, CORS, 400s
│   └── test_parity.py         # diff JSON responses vs running R service
├── Dockerfile              # python:3.13-slim base
├── requirements.txt        # fastapi, uvicorn[standard], duckdb, sqlglot, orjson
├── pyproject.toml
└── README.md
```

## Key implementation decisions

### 0. Multi-database support via `?db=` parameter

**Goal:** Serve tiles from multiple DuckDB files (e.g. different releases or
datasets) from one service, with full backward compatibility — calls without
`?db=` continue to hit the existing default DB.

**Configuration via env (two modes, transparent fallback):**

- **Registry mode** — `H3T_DBS="default:/data/release_v2026.05.14.duckdb,wrangling:/data/calcofi_wrangling.duckdb"`
  parses to a name→path dict. `H3T_DEFAULT_DB="default"` picks the fallback
  name when `?db=` is omitted.
- **Legacy single-DB mode** — if `H3T_DBS` is unset, fall back to the existing
  `DUCKDB_PATH` env var, mapped as the sole entry `{"default": DUCKDB_PATH}`.
  This keeps current deploys working without env changes.

**Endpoint changes:**

```python
@app.get("/h3t/{z}/{x}/{y}.h3t")
async def tile(z: int, x: int, y: int, q: str,
               db: str = Query(default=None),  # → DEFAULT_DB if None
               ...):
    db_name = db or DEFAULT_DB
    con = get_connection(db_name)  # KeyError → 400 with allowed names
    ...
```

Same `?db=` query param added to `/stats` and `/meta`. `/health` returns the
list of registered DB names + their mtimes.

**Connection management:**

```python
# app/db.py
_CONS: dict[str, duckdb.DuckDBPyConnection] = {}

def init_connections(dbs: dict[str, Path]) -> None:
    for name, path in dbs.items():
        if not path.exists():
            raise SystemExit(f"DB '{name}' not found at {path}")
        con = duckdb.connect(str(path), read_only=True)
        con.execute("INSTALL h3 FROM community; LOAD h3;")
        con.execute("INSTALL spatial; LOAD spatial;")
        _CONS[name] = con

def get_connection(name: str) -> duckdb.DuckDBPyConnection:
    if name not in _CONS:
        raise HTTPException(400, f"unknown db '{name}'; available: {sorted(_CONS)}")
    return _CONS[name]
```

One shared connection per DB at startup; per-request cursors (thread-safe).
Eager open at boot so missing files fail-fast in container health checks.

**ETag must include `db`:** add to the input tuple so two databases serving
the same query never share a cache entry.

```python
etag = sha256(f"{db_name}|{q}|{z}|{x}|{y}|{res}|{release}|{db_mtime}").hexdigest()
```

**`db_mtime` becomes per-DB**, stored alongside the connection at startup.

**Security:** strict allowlist via the registry — there is no path
traversal vector because the user only supplies a *name*, never a path.

**Varnish:** because `db` is a query-param, Varnish keys on it naturally
(default config hashes the full URL). No vcl changes needed.

### 1. Concurrency model — async routes + threadpool for DuckDB

```python
@app.get("/h3t/{z}/{x}/{y}.h3t")
async def tile(z: int, x: int, y: int, q: str, res_h3: int | None = None, ...):
    # validation + sql wrapping is pure-CPU, sub-ms — run inline
    wrapped = wrap_tile_sql(...)
    # DuckDB call → threadpool so the event loop stays free for other tiles
    rows = await run_in_threadpool(execute_query, wrapped)
    ...
```

`fastapi.concurrency.run_in_threadpool` farms blocking DuckDB calls out to a
worker pool while the async loop keeps accepting connections. Net effect:
N concurrent tile requests proceed in parallel against DuckDB, limited by
the threadpool size (default 40) and DuckDB's own read concurrency.

### 2. DuckDB connection management — one shared connection, per-request cursor

```python
# app/db.py
import duckdb

_CON = duckdb.connect(DUCKDB_PATH, read_only=True)
_CON.execute("INSTALL h3 FROM community; LOAD h3;")
_CON.execute("INSTALL spatial; LOAD spatial;")

def execute_query(sql: str) -> list[tuple]:
    # cursor() is cheap and thread-safe; the shared connection is not
    cur = _CON.cursor()
    try:
        return cur.execute(sql).fetchall()
    finally:
        cur.close()
```

This matches the current R single-connection pattern and lets DuckDB's
internal scheduler handle parallel read queries. Verified pattern from
DuckDB Python docs.

### 3. SQL validation — reuse `sql_validate.py` unchanged

The existing `sql_validate.py` is already a self-contained native Python
module (lines 1–182). Copy it into `app/sql_validate.py` verbatim. Same
allowlist, same denylist, same AST cap, same projection rules. Existing
tests (if any) port directly; if none, write them now — this is the
security-critical surface.

### 4. Port `h3t_query.R` to `h3t_query.py` — line-for-line

Pure functions, trivial port. Key correctness notes:

- `zoom_to_res(z)`: R's `findInterval(..., rightmost.closed=TRUE, all.inside=TRUE)`
  is the binary-search equivalent of `bisect.bisect_right(breaks, z) - 1`,
  clamped to `[1, 10]`. Write a parity test with R-generated golden values
  for z = 0, 0.5, 1, 1.99, 2, ..., 22, 22.5.

- `tile_bbox(z, x, y)`: identical math (`math.atan(math.sinh(...))`). Validate
  on a fixed grid of (z, x, y) tuples against R.

- `h3_edge_length_deg(r)`: `1106.54 / (math.sqrt(7) ** r) / 111.32`. Trivial.

- `wrap_tile_sql` / `wrap_stats_sql`: copy the `sprintf` templates as Python
  f-strings or `str.format`. **Critical** — preserve whitespace and column
  ordering byte-for-byte because the wrapped SQL output feeds the ETag.
  (Strictly: ETag is over the *input* `q`, not the wrapped form, so this is
  belt-and-suspenders.)

### 5. ETag — preserve byte-for-byte compatibility

Current: `digest::digest(list(q, z, x, y, query_res, release, DB_MTIME), algo = "sha256")`.

R's `digest::digest()` on a list serializes via R's internal serialization, which
is **not** trivially reproducible in Python. Options:

**Option A (recommended): change the ETag input format to a stable string.**
Both old and new compute `sha256(f"{q}|{z}|{x}|{y}|{res}|{release}|{db_mtime}")`.
Update the R service in parallel so old cache entries match. One-time Varnish
flush during cutover.

**Option B: Reverse-engineer R's serialization.** Not worth it.

Pick A. The Varnish flush is a known cutover cost.

### 6. Per-request statement timeout

Current: `setTimeLimit(elapsed = STMT_TIMEOUT_MS / 1000, transient = TRUE)`.

Python equivalent inside threadpool: pass a per-cursor timeout via DuckDB's
`SET statement_timeout = '3s'` PRAGMA before execute, or use
`asyncio.wait_for(run_in_threadpool(...), timeout=3.0)` (cleaner; cancels
the awaitable but DuckDB keeps running until it checks for interrupt —
acceptable since the client has gone away).

Recommend: set `PRAGMA threads=4; SET statement_timeout='3s'` per cursor.

### 7. CORS — FastAPI middleware

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=[os.getenv("H3T_CORS_ORIGIN", "*")],
    allow_methods=["GET", "OPTIONS"],
    allow_headers=["Content-Type", "If-None-Match"],
    expose_headers=["ETag", "X-Calcofi-Release", "X-Cache"],
    max_age=600,
)
```

1:1 replacement of the plumber `cors` filter.

### 8. JSON serialization — `orjson` for speed

`ORJSONResponse` is faster than the default and handles NaN/Inf the same way
plumber's `unboxedJSON` did (errors on NaN by default; we already filter
non-finite values in `wrap_tile_sql`). Use `ORJSONResponse` as the default
response class.

### 9. Compression — let Varnish handle it; opt-in app-level for direct access

Tile JSON compresses ~70–80% with gzip (a 30 KB tile → ~6 KB). Two layers
could do it; we want exactly one.

**Recommended:** Varnish does the gzip. The app emits plain JSON.

- **Why Varnish:** It already inspects `Accept-Encoding` from the client and
  stores one gzipped copy in cache; if the app gzips first, Varnish has to
  keep both (or stream-decompress to re-gzip). Varnish 6+ gzip is built-in
  and on by default for `application/json` if `Accept-Encoding: gzip` is
  present.
- **App's job:** set `Content-Type: application/json` (FastAPI default) and
  `Vary: Accept-Encoding` so Varnish caches correctly. Add an explicit
  `vary` header in the cache headers helper.
- **Verify Varnish config:** the existing `h3t.calcofi.io` Varnish VCL
  should already gzip JSON — confirm during cutover with
  `curl -H 'Accept-Encoding: gzip' -I` and look for `Content-Encoding: gzip`.
  If it's missing, add `set beresp.do_gzip = true;` in `vcl_backend_response`.

**Optional app-level fallback for direct access** (e.g. dev, or anyone
hitting the origin directly):

```python
from fastapi.middleware.gzip import GZipMiddleware

if os.getenv("H3T_APP_GZIP", "false").lower() == "true":
    app.add_middleware(GZipMiddleware, minimum_size=1024)
```

Off by default in prod (Varnish handles it); on by default in dev. The
`minimum_size=1024` skips tiny payloads where gzip overhead outweighs savings.

**Brotli:** skip for now. Varnish doesn't ship with native brotli; adding
`brotli-asgi` to the app would force the app layer to compress, defeating
the Varnish caching design. Revisit only if measurement shows a real win.

### 10. Health check + meta endpoints — straight port

`/h3t/health` and `/h3t/meta` are trivial — return dicts with DB path,
mtime, table names from `information_schema`.

## Endpoint sketches

```python
# app/main.py
from fastapi import FastAPI, Query, Response, HTTPException
from fastapi.responses import ORJSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.concurrency import run_in_threadpool

app = FastAPI(default_response_class=ORJSONResponse)
app.add_middleware(CORSMiddleware, ...)  # see §7

@app.get("/h3t/health")
async def health():
    return {
        "ok": True,
        "default_db": DEFAULT_DB,
        "dbs": {name: {"path": str(p), "mtime": DB_MTIMES[name]}
                for name, p in DB_PATHS.items()},
    }

@app.get("/h3t/{z}/{x}/{y}.h3t")
async def tile(
    z: int, x: int, y: int,
    response: Response,
    q: str = Query(...),
    res_h3: int | None = None,
    release: str = "",
    db: str | None = None,
):
    db_name = db or DEFAULT_DB
    con = get_connection(db_name)             # 400 on unknown name
    db_mtime = DB_MTIMES[db_name]

    bbox = tile_bbox(z, x, y)                 # ValueError → caught → 400
    qres = res_h3 if res_h3 is not None else zoom_to_res(z)
    if not 1 <= qres <= 10:
        raise HTTPException(400, "res_h3 must be in [1, 10]")

    sql = decode_sql(q)
    if sql is None:
        raise HTTPException(400, "q must be valid base64")
    sql = substitute_res(sql, qres)

    v = validate(sql)
    if not v["ok"]:
        raise HTTPException(400, v["reason"])

    wrapped = wrap_tile_sql(
        v["normalized"], bbox, has_n=v["has_n"],
        max_rows=MAX_ROWS_PER_TILE,
        buffer_deg=h3_edge_length_deg(qres) * 1.5,
    )

    rows = await run_in_threadpool(execute_query, con, wrapped, STMT_TIMEOUT_MS)

    etag = compute_etag(db_name, q, z, x, y, qres, release, db_mtime)
    set_cache_headers(response, etag, release, db_mtime)
    return {"cells": build_cells(rows)}

@app.get("/h3t/stats")
async def stats(response: Response, q: str, release: str = "",
                res_h3: int = 5, db: str | None = None):
    ...  # same shape, calls wrap_stats_sql against get_connection(db or DEFAULT_DB)

@app.get("/h3t/meta")
async def meta(response: Response, db: str | None = None):
    ...  # tables come from get_connection(db or DEFAULT_DB); include available db names
```

## Parity testing strategy

### Unit tests (Python only)

- `test_sql_validate.py` — every existing rule, plus fuzzing on borderline cases.
- `test_h3t_query.py` — golden tables: `(z, x, y) → bbox`, `z → res`,
  `r → edge_deg`, plus `wrap_tile_sql` snapshot tests.

### Cross-language parity (R service still running)

Add a `tests/test_parity.py` that:
1. Spins up the new FastAPI service on port 8890.
2. Fires the same requests at `localhost:8890` and the live R service.
3. Diffs:
   - HTTP status
   - `cells[]` lengths and entry-wise JSON (after sorting by h3id)
   - `min/max/p02/p98/n` from `/stats` (allow ±1e-9 tolerance)
   - Header keys present
   - Body parity for `/meta` and `/health`

Run against a curated fixture of ~20 real queries pulled from
`int-app/functions_h3t.R` (species, env, multi-quarter, edge-of-world tile,
empty result, hit-the-row-cap). Include cases with and without `?db=` to
verify legacy single-DB callers and registry mode coexist.

### Load test

Use `vegeta` or `oha`:
- Sustained 100 req/s, 50 concurrent — current R baseline vs FastAPI.
- Burst test: 200 concurrent unique tiles, cold Varnish (bypass with
  `Cache-Control: no-cache`). This is the scenario the rewrite is meant to
  improve. Acceptance: p95 ≤ 2× single-request p95 on FastAPI; for R, expect
  p95 ≈ N × per-request.

## Deploy / cutover plan

1. **Phase 1 — build & test in parallel**
   - Deploy `api-h3t-py` to a sibling host or port (e.g. 8890).
   - Smoke + parity tests against live R service.
   - Run for 24–48h with synthetic traffic; compare metrics.

2. **Phase 2 — Varnish cutover**
   - Coordinate the ETag scheme change (see §5).
   - Switch the Varnish backend to the Python service.
   - Flush the Varnish cache once.
   - Monitor: hit rate, origin latency, 5xx rate.

3. **Phase 3 — decommission**
   - Keep R service available for 1 week as instant rollback.
   - Archive once stable.

## Files to modify or create

**New repo or new directory** (recommend new repo `CalCOFI/api-h3t-py` for clean
git history; merge back into `api-h3t` only if you want a single repo with
`/r` and `/py` subdirs during transition).

- `app/main.py` — endpoints + middleware
- `app/config.py` — env var parsing, constants
- `app/db.py` — DuckDB connection, `execute_query`
- `app/sql_validate.py` — **copy** of `api-h3t/sql_validate.py` (no changes)
- `app/h3t_query.py` — port of `api-h3t/h3t_query.R`
- `app/tiles.py` — `build_cells`, `compute_etag`, `set_cache_headers`,
  `decode_sql`, `substitute_res`
- `tests/*` — see Parity Testing Strategy
- `Dockerfile` — `python:3.13-slim` + `pip install -r requirements.txt`
- `requirements.txt` — `fastapi`, `uvicorn[standard]`, `duckdb>=1.5`,
  `sqlglot>=25`, `orjson`
- `pyproject.toml`
- `README.md` — endpoints, env vars, deploy notes

**Edits to existing repos:**

- `api-h3t/plumber.R:155` and `:192` — switch ETag input format to the stable
  string scheme so the two services can coexist during cutover.
- `int-app` — no changes (it's a pure client of HTTP endpoints; URLs and
  shapes are preserved).
- `docs/maps.qmd` — update "the service runs on R Plumber" → "FastAPI" once
  cutover completes.

## Verification

End-to-end checks after cutover, in order:

1. **Health:** `curl https://h3t.calcofi.io/h3t/health` → `{"ok":true,...}`
2. **Meta:** `curl https://h3t.calcofi.io/h3t/meta` → table list matches old.
3. **Stats parity:** Run same `?q=...` against staging Python + production R;
   diff `min/max/p02/p98/n`. Should match to numeric precision.
4. **Tile parity:** Pick 5 tiles at varying `(z, x, y)` from a real int-app
   session; verify cell counts and `h3id` sets match.
5. **Browser smoke:** Open `int-app`'s map, switch species, pan/zoom across
   the CalCOFI grid. No visible seams, tile counts match the previous behavior,
   legends populate.
6. **Multi-DB:** `curl '.../h3t/5/3/12.h3t?q=...&db=wrangling'` returns
   different data than `?db=default`; `?db=bogus` returns 400 with allowed
   names. Omitting `?db=` matches the pre-rewrite response (legacy parity).
7. **Compression:** `curl -H 'Accept-Encoding: gzip' -sI https://h3t.calcofi.io/h3t/5/3/12.h3t?q=...`
   shows `Content-Encoding: gzip` and `Vary: Accept-Encoding`. Body size with
   gzip should be ~20–30% of plaintext for typical JSON tiles.
8. **Load test:** `oha -z 60s -c 50 'https://h3t.calcofi.io/h3t/5/3/12.h3t?q=...&release=v...'`
   — p50/p95/p99 latency under cache hit, then under cache bypass.
9. **Varnish health:** hit rate ≥ pre-cutover baseline within 1h; 5xx rate
   unchanged.

## Out of scope

- Switching tile payload format (h3j JSON stays).
- Changing the SQL allowlist semantics.
- Adding new endpoints (the `?db=` param is added to existing endpoints; no new routes).
- Authentication (still public, read-only — applies per DB; if you ever want
  a private DB, that's a follow-up).
- Brotli compression (gzip via Varnish only).
