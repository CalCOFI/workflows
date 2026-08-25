# Database changelog (`RELEASES.md`), archive thinning, content-addressed release tables

**Status:** DRAFT 2026-08-25 — for review. Decisions taken in conversation: (1) `workflows/RELEASES.md`,
release fails without a section; (2) thinning keeps six consolidated versions + latest two;
(3) content addressing goes all the way (Level 1 + Level 2, **all** consumers) but only after this
plan is accepted, with a byte-ordering policy and tests — including the storage redirects — proven
first. Part 1 is implemented as soon as the plan is accepted; Parts 2–3 are gated below.

## Why

Three findings from the 2026-08-25 audit (three read-only sweeps over workflows, calcofi4db,
calcofi4r, calcofi4py, db-schema, db-query, db-viz-*, ctd-transects, apps, erddap, server, GCS):

- **Release notes carry no narrative.** `RELEASE_NOTES.md` is a `paste0()` template
  (`release_database.qmd:1606-1655`): ~55 of 65 lines are a hard-coded string that still lists
  four datasets (sixteen ship) and tables retired in July (`taxa_rank`, `species`, `ctd_thin`).
  `diff` between any two versions is row counts and the version string. The delivery path is fine
  — db-schema renders the file in a modal (`app.js:294-338`), `calcofi4r::cc_release_notes()`
  fetches it — the content is empty. The narrative already exists in three places: calcofi4db /
  calcofi4r `NEWS.md` (mechanism + numbers, in exactly the right register), the workflows commit
  subjects (the only source spanning every release), and `.claude/calcofi_notes.md` (motive: who
  asked, what the provider said, what was deliberately not done).
- **The archive is 157 GB across 28 GCS versions; six March/April releases (old per-dataset
  schema) are 100 GB = 60 %; the eleven August releases total 22 GB.** Bucket has no lifecycle
  rules, no object versioning, and a 7-day soft-delete (deleted bytes bill for a week).
- **Byte-level dedup would save almost nothing today.** v2026.08.14 → v2026.08.25: only 52 MB of
  2.09 GB is byte-identical, and tables whose row counts did not change (`obs_mets_full`, `taxon`,
  `cruise`, `measurement_type`) still differ byte-for-byte, because the release writes
  (`COPY … PARTITION_BY` at `release_database.qmd:1472,1489` and `export_parquet()` at
  `calcofi4db/R/parquet.R:29`) carry no total order and run multi-threaded. Not one of the
  142 `obs_ctd_full` cruise partitions was byte-stable. The row-signature hash calcofi4db already
  computes at ingest (`.table_content_hash()` / `.partition_content_hashes()`, `wrangle.R:1273-1316`)
  is the right identity; deterministic writes are what make the bytes reusable.
- **Object storage has no symlinks, and every consumer string-concatenates
  `{version}/parquet/{table}.parquet` on `storage.googleapis.com`** (calcofi4r, calcofi4py,
  db-query's `_queries/*.md`, db-viz-station's `r()` macro, ctd-transects, ERDDAP's `gsutil cp -r`,
  the postgis `release.*` views, ctd-qaqc's partition enumeration). `catalog.json` carries no paths.
  `storage.calcofi.io` (Caddy → GCS) can 302 a legacy path — a working precedent exists for netCDF
  (`server/caddy/Caddyfile:79-96`, `libs/publish_netcdf.R:117-138`) — `storage.googleapis.com`
  cannot.

## Part 1 — `RELEASES.md`: the database's NEWS file (accepted)

**File.** `workflows/RELEASES.md`, one running file, newest first, uploaded verbatim to
`gs://calcofi-db/ducklake/releases/RELEASES.md` and linked from the releases `index.html`.

**Convention (goes into `CLAUDE.md`, mirroring the package NEWS rule).**

```
# Unreleased
## <declarative sentence: what is now true that was not>
<why; the numbers; provider questions raised (Qnn); consumer impact; package versions>

# v2026.08.25 (2026-08-25)
...
```

- Every change that alters release *content* (a schema column, a key derivation, a validation
  gate, a dataset entering/leaving, a data fix) adds to `# Unreleased` **in the same commit**.
  Headings are sentences, not categories; bodies say what was wrong, what is true now, and by how
  much. Consumer-facing breakage gets a `**Consumers:**` line naming the repos.
- `release_database.qmd` (new chunk `release_notes_narrative`, before `freeze_release`) renames
  `# Unreleased` → `# {release_version} ({date})` if present, then **`stop()`s if no section for
  `release_version` exists** — the same hard stop as the package `NEWS.md` rule.
- Per-version `RELEASE_NOTES.md` = that section + an auto-generated **appendix** (tables and rows
  from `catalog.json`, datasets from `metadata.json`, gates from `test_results.json` when present,
  calcofi4db/calcofi4r/calcofi4py versions, the promoted-at timestamp). Everything hard-coded today
  is deleted. db-schema and `cc_release_notes()` need no change.
- **Update until approval.** `calcofi4db::publish_release_notes(version, releases_md, bucket)`
  re-renders and re-uploads `RELEASE_NOTES.md` (+ `RELEASES.md`) for *any* version, tagged
  `cache-control: no-cache`. It is notes-only, so the data republish guard does not apply; it is
  the path for edits between freeze and `test_release`, and for backfilling. A `release_notes`
  target (`output: data/releases/_notes_stamp.json`, an md5 of `RELEASES.md`) makes an edit
  re-publish on the next `tar_make()` without re-cutting the release.
- **Backfill.** v2026.07.15 → v2026.08.25 written in full from the reconstructed history (git
  subjects + NEWS.md + catalog/test_results deltas + calcofi_notes); v2026.02 → v2026.06.26 as
  shorter entries (catalog deltas + commit subjects). Then `publish_release_notes()` over all 28
  GCS versions (v2026.07.17 has no notes on GCS at all today).

**Tests.** calcofi4db: `test-release_notes.R` — section extraction (exact heading match,
`Unreleased` rename, missing → error), appendix rendering from a synthetic catalog/test_results,
idempotence (publishing twice yields identical bytes).

## Part 2 — Archive thinning: consolidated versions (policy accepted; execution gated)

**Policy.** `versions.json` gains `consolidated: true|false` and `retired: {to: <version>}`.
Keep the parquet of: `v2026.04.08` (last of the per-dataset schema), `v2026.05.14` (docs examples
pin it), `v2026.06.26`, `v2026.07.17`, `v2026.08.14`, `v2026.08.25`, **plus always the promoted
version and the one before it**. Every other version keeps its sidecars and `RELEASE_NOTES.md`
(the record stays complete and db-schema can still show it) and gets `retired.json`
`{retired_utc, to, reason}`; its `parquet/` prefix is deleted. Expected: ~130 GB of 157 GB freed
(billing drops after the 7-day soft-delete window).

**Mechanics.** `scripts/thin_releases.R` — dry-run by default (prints per-version bytes to
delete, refuses if a version to delete is `latest.txt` or its predecessor, or pinned anywhere in
`docs/`, `db-query/_config.yml`, `server/postgis/init/50_release_views.sql`); `--execute` deletes
with `gcloud storage rm -r`, writes `retired.json`, rebuilds `versions.json` and the index pages
(`build_release_index.R` already exists). db-schema: a retired version shows its notes with a
banner "data retired → {to}"; `cc_get_db()` / `cc_get_db` (py) error clearly on a retired
version, naming the replacement.

**Gate.** Runs only after this plan is accepted and after Part 3's staging prefix has been
validated (so we never delete a version that the redirect tests still need).

## Part 3 — Content-addressed release tables (Level 1 + Level 2, all consumers; gated)

### 3.1 Byte-ordering policy — the default that stops duplicate uploads

Measured 2026-08-25 on v2026.08.25 tables, DuckDB CLI 1.5.5 / R duckdb 1.5.2:

| export | run-to-run bytes |
|---|---|
| `sample.parquet`, no ORDER BY, default threads | identical (input order preserved) |
| `sample.parquet`, `ORDER BY sample_key`, default threads | **differ** |
| `sample.parquet`, `ORDER BY sample_key`, `SET threads = 1` | identical |
| `PARTITION_BY dataset_key`, total order, default threads | **differ** (16 files) |
| `PARTITION_BY dataset_key`, total order, `threads = 1` | identical |
| `obs.parquet` 26 M rows, total order, default threads ×2 | identical this time; 6.4 s |
| `obs.parquet` 26 M rows, total order, `threads = 1` | 18.6 s (~3×) |

A total order alone is **not** sufficient; the writer must be single-threaded. Policy, enforced
by one function `calcofi4db::export_release_parquet(con, sql_or_table, path, order_by,
partition_by = NULL)` that every release write goes through (replacing `export_parquet()` and the
raw `COPY` calls in `release_database.qmd`):

1. `SELECT … ORDER BY <partition cols>, <sort cols>, <primary key>` — a unique total order. Sort
   cols come from `core_sort`; the primary key from `core_relationships()`'s `pk` list
   (`model.R:676-687`), extended for every released table; a table with no declared PK **fails
   the export** rather than writing non-deterministically.
2. `SET threads = 1` for the duration of the COPY (restored after), `PRESERVE_INSERTION_ORDER`
   left at its default `true`.
3. Pinned writer options: `FORMAT PARQUET, COMPRESSION 'zstd', ROW_GROUP_SIZE 122880,
   PARQUET_VERSION 'V1'` — a change to any of them is a change to every table's bytes and must be
   recorded in `RELEASES.md`.
4. Deterministic file names: single file `{table}.parquet`; partitioned `{col}={value}/data_0.parquet`
   (single-threaded writes produce exactly one file per partition).
5. Provenance columns stay stripped from released tables; `release_date`-like columns never
   enter a table (they belong in the catalog).
6. **Identity is the row signature, bytes are the storage key.** For each object compute both
   `content_hash` (`.table_content_hash()` — order- and file-independent) and `sha256` of the bytes
   (plus GCS's crc32c). Reuse rule: if `content_hash` equals the previous release's, the previous
   object is reused *even if the bytes would differ* (a DuckDB upgrade changes bytes, not content);
   the previous object's sha256 is recorded. Cost of determinism is then only paid when content
   changed — and it is what makes a fresh write reusable by the *next* release.

### 3.2 Layout

```
gs://calcofi-db/ducklake/
  tables/{table}/{content_hash}/{table}.parquet                       # single-file tables
  tables/{table}/{part_col}={value}/{content_hash}/data_0.parquet     # one object per partition
  releases/{version}/catalog.json        # + per-table objects[] (see 3.3), unchanged fields kept
  releases/{version}/RELEASE_NOTES.md, metadata.json, relationships*.json, erd.mmd, test_results.json
  releases/{version}/parquet/…           # COMPAT objects: real copies, only for the promoted
                                          # version and the consolidated ones (Part 2), made by
                                          # GCS server-side copy from tables/ (no upload bytes)
  releases/RELEASES.md, versions.json, latest.txt, index.html
```

Objects under `tables/` are immutable and shared by every version whose catalog points at them.
Thinning (Part 2) then means: delete a version's `parquet/` compat copies and any `tables/`
objects no retained catalog references (a reachability sweep in `thin_releases.R`).

### 3.3 `catalog.json` (additive)

```json
"tables": [{
  "name": "obs_ctd_full", "rows": 271394164, "partitioned": true, "supplemental": true,
  "content_hash": "…",                      // whole-table signature
  "bytes": 1365454571,
  "objects": [                              // one entry per object; single-file tables have one
    {"partition": {"cruise_key": "2000-10-32NM"}, "path": "tables/obs_ctd_full/cruise_key=2000-10-32NM/ab12…/data_0.parquet",
     "bytes": 9876543, "sha256": "…", "crc32c": "…", "content_hash": "ab12…", "since": "v2026.08.10"}
  ],
  "compat_path": "releases/v2026.08.25/parquet/obs_ctd_full/"   // present only while compat copies exist
}]
```

`path` is bucket-relative so a consumer picks its scheme: `https://storage.googleapis.com/calcofi-db/`,
`s3://calcofi-db/` (DuckDB globs), or `https://storage.calcofi.io/calcofi-db/`. `since` = first
version that shipped this object — the per-partition "what changed" that `RELEASES.md` can cite.

### 3.4 Consumers (every one, with the change)

| consumer | today | change |
|---|---|---|
| calcofi4r `cc_get_db()`, `.cc_parquet_base()`, `cc_db_info()` (`database.R:181-215, 376`; `match.R:61-64`) | concatenates `{version}/parquet/{table}` | read `objects[].path` from the catalog; partitioned tables → `read_parquet([list of s3 urls], hive_partitioning=true)`; `cc_release_notes()` unchanged |
| calcofi4py `cc_get_db()` (`release.py:90-105`) | same | same, in step with calcofi4r (one test fixture shared by both: a synthetic catalog) |
| db-schema `app.js:297` | catalog for names only | show `objects[].since` per table (what changed in this version); retired banner |
| db-query `lib/match.js:13-28`, `lib/options-sources.js`, `_queries/**/*.md`, `_config.yml` | fully hard-coded URLs | `parquetBase()` → `tableUrl(table)` resolved from the catalog (fetched once per page load); the `.md` queries get a `{{tbl obs}}` helper instead of literal URLs |
| db-viz-station `scripts/build_*.sql` (`r()` macro), `public/app.js:1705`, `refresh.yml` | `__RELEASE__` substitution | a `resolve_release.py` step writes a `tables.json` (name → gs path list) that the SQL macros read via `read_json`; app.js uses catalog paths |
| ctd-transects `scripts/build_sections.sql:55-61` | `read_text(latest.txt)` + concat | same `tables.json` pattern |
| db-viz-hex `prep_db.R:73`, `app/functions.R:2637-2650` | concat | via `calcofi4r::cc_get_db()` / a `cc_table_urls(version)` helper |
| apps/db-viz-cruise `prep_db.R:42-49`, apps/ctd-viz `prep_db.R` (via calcofi4r), apps/ctd-qaqc `prep_db.R:85,195-198` (enumerates partitions through the JSON list API) | concat / prefix listing | `cc_table_urls()`; ctd-qaqc's partition enumeration becomes the catalog's `objects[]` |
| ERDDAP `libs/erddap_deploy.R:53-58` (`gsutil -m cp -r …/parquet`) | copies the version prefix | copies from `objects[].path` into the same server layout (a manifest-driven `gsutil cp` list; on-server DuckDB views unchanged) |
| postgis `server/postgis/init/50_release_views.sql` | hard-coded `v2026.08.14` URLs | `deploy_consumers.sh` step 3b regenerates the view SQL from the catalog instead of `sed` on a version string |
| docs `data-access.qmd`, `db.qmd`, `server-access.qmd` | pinned literal URLs | document `catalog.json` `objects[]` as the contract; examples use `cc_get_db()` / `cc_table_urls()` |
| `scripts/build_release_index.R` | lists the version prefix | lists `objects[]` with `since`, links compat + canonical |

Legacy `releases/{v}/parquet/…` URLs keep working **on `storage.calcofi.io`** for every version
(Caddy 302 → canonical object, scoped like the netCDF rule) and **on `storage.googleapis.com`** only
where compat objects exist (promoted + consolidated versions). That is the deprecation surface:
announce it in `RELEASES.md` and in `docs/data-access.qmd`, keep compat objects for the promoted
version for at least two release cycles after all consumers above are migrated.

### 3.5 Tests — must pass before the real prefix changes

- **T1 determinism (calcofi4db `test-export_release_parquet.R`):** export a synthetic table
  (with a GEOMETRY column, NULLs in sort keys, a partitioned variant) twice → identical sha256;
  exporting the same rows in shuffled input order → identical sha256; a table without a declared
  PK → error.
- **T2 identity:** `content_hash` equal across shuffled input and across compression settings;
  differs on a single changed value; per-partition hashes only change for the touched partition.
- **T3 catalog:** schema validation of `objects[]` (every `path` exists on GCS, `bytes`/`crc32c`
  match `gcloud storage hash`, every object referenced by `latest` is present); the existing
  `catalog_covers_export` guard extended to objects.
- **T4 redirects (storage.calcofi.io):** `curl -I …/releases/{v}/parquet/{table}.parquet` → 302
  → 200 with the canonical `Location`; a genuinely missing object still 404s (no blanket
  redirect); DuckDB `read_parquet()` over `httpfs` follows the 302 (verify — if httpfs does not
  follow redirects, the Caddy rule must `rewrite` + proxy rather than `redir`, which also removes
  the egress double-hop); `robots.txt` still disallows `*.parquet`.
- **T5 consumer contract (`test_release.qmd`):** the 32 gates run against catalog-resolved paths;
  plus one new gate per consumer family: calcofi4r `cc_get_db()`, calcofi4py `cc_get_db()`,
  db-query `tableUrl()`, the `tables.json` builders — all resolving the same object set.
- **T6 staging end-to-end:** a full release cut to `gs://calcofi-db/ducklake-staging/` (a
  prefix, not a bucket — same IAM), then the Caddy allow-list extended to it, then every consumer
  pointed at the staging prefix by environment variable and its refresh/prep_db run once. Only
  after T1–T6 are green does `release_database.qmd` write to `ducklake/`.
- **T7 thinning dry run:** `thin_releases.R` prints exactly what it would delete and what remains
  reachable; the reachability sweep is asserted against the catalogs of all retained versions.

### 3.6 Rollout order

1. Part 1 (`RELEASES.md`, appendix, publisher, backfill) — no data or URL change. *(now)*
2. calcofi4db: `export_release_parquet()` + `content_hash` in catalog (`objects[]` with
   `path` **still** `releases/{v}/parquet/…`) + server-side copy of unchanged objects from the
   previous version at freeze — Level 1: consumers unaffected, upload bytes drop to the delta.
3. Canonical `tables/` store written **in addition** to compat objects; catalog `path` → canonical;
   Caddy 302 rule; T1–T4 green on the staging prefix.
4. Consumers migrated one PR each (calcofi4r + calcofi4py first, shared fixture), T5 green.
5. First real release on the new layout; compat objects for that version only.
6. Part 2 thinning, T7 first, then `--execute`.
7. Two release cycles later: drop compat objects for non-consolidated versions;
   `storage.googleapis.com` legacy paths for those versions 404 by design (documented).

### Open questions for review

Each of these changes what gets built. For each: what it is, the options, what each costs, and
what I recommend.

#### Q1 — What names a canonical object: the row-signature hash or the byte hash?

Every table (and every partition of a partitioned table) will be stored **once** under
`ducklake/tables/{table}/{KEY}/…`, and each release's `catalog.json` points at the objects it
uses. The question is what `{KEY}` is.

- **Option A — `content_hash` (the row signature).** calcofi4db already computes this at ingest:
  an order-independent checksum of the *values* (`.table_content_hash()`), so two exports of the
  same rows get the same key even if the parquet bytes differ (a DuckDB upgrade, a different
  row-group size, a non-deterministic write). Consequence: identical *content* is never stored
  twice, ever. Cost: the key does not verify the bytes — you cannot check a downloaded file
  against its name; you verify against the recorded `sha256`/`crc32c` in the catalog instead.
- **Option B — `sha256` of the bytes.** The file's name *is* its checksum: download it, hash it,
  compare. Simplest possible verification and what most content-addressed stores do. Cost: the
  same rows written twice with different bytes are two objects — which is exactly the situation
  measured today (every table differs byte-for-byte between releases even when nothing changed),
  so B only works once the byte-ordering policy (3.1) is in force and stays in force; any future
  writer change silently doubles storage until the old objects are pruned.

**Recommendation: A**, with `sha256` and `crc32c` recorded per object in the catalog for
verification. The row signature is the identity we actually care about ("did the data change?");
bytes are an implementation detail we are about to make deterministic but cannot promise forever.
If you prefer B for its verify-by-name simplicity, the plan works unchanged except that a writer
change must be treated as a "re-store everything" event.

#### Q2 — How long do legacy `releases/{v}/parquet/{table}.parquet` URLs keep working on `storage.googleapis.com`?

Today every consumer builds that URL by string concatenation (§3.4). After Level 2 the bytes
live under `tables/…`, and a `releases/{v}/parquet/…` URL only works where we keep a **compat
copy** (a real duplicate object, made by GCS server-side copy so it costs storage but no upload).
Two decisions inside this one:

- **Which versions get compat copies?** Plan: the promoted version and the six consolidated ones.
  Every other version's legacy URLs stop working on `storage.googleapis.com` (they still work on
  `storage.calcofi.io`, see Q3). That is the same set Part 2 keeps anyway, so no extra storage.
- **For how long after consumers are migrated?** Anyone who copied a URL from `docs/data-access.qmd`
  or the release index into their own script is a consumer we cannot see. Options: (i) **two
  release cycles** after the last repo in §3.4 is migrated — bounded by our own cadence, so the
  window is short if we release often; (ii) **a calendar date** (say 2026-12-31), announced in
  `RELEASES.md` and on the index page — predictable for outsiders regardless of our cadence;
  (iii) **indefinitely for consolidated versions** (their compat copies cost ~2 GB each and are
  kept by Part 2 anyway), dropping only for retired versions.

**Recommendation: (iii) + (ii)** — keep compat copies for consolidated versions indefinitely (it
is what the thinning policy retains anyway, so the legacy URL of any version we still serve keeps
working), and set a calendar date only for the *non-consolidated* versions' legacy paths, which
Part 2 deletes. Announce both in `RELEASES.md` and `data-access.qmd`.

#### Q3 — Should `storage.calcofi.io` redirect to `storage.googleapis.com`, or keep proxying bytes?

`storage.calcofi.io` is a Caddy vhost on our VM that reverse-proxies to
`storage.googleapis.com` so that folder URLs can serve `index.html` (GCS itself has no directory
listing). Because it *proxies*, every byte a client downloads through it passes through the VM
and is billed as **VM egress** — which is why `robots.txt` there already tells crawlers not to
fetch `*.parquet`/`*.nc`. Level 2 needs `storage.calcofi.io` to resolve a legacy path to its
canonical object; it can do that two ways:

- **302 redirect** to `https://storage.googleapis.com/calcofi-db/ducklake/tables/…`: the VM
  answers with one small header and the bytes flow straight from GCS. No egress on the VM, and
  the client sees the canonical URL (which it can cache/pin). Caveat to test (T4): DuckDB's
  `httpfs` must follow the redirect; if it does not, R/Python users reading a legacy URL through
  `storage.calcofi.io` would fail. (Browsers and `curl -L` follow it fine.)
- **Rewrite + proxy**: the VM fetches the canonical object from GCS and streams it — transparent
  to every client, but every gigabyte read through `storage.calcofi.io` costs VM egress, which is
  the cost the domain was supposed to avoid for bulk data.

**Recommendation: 302** for parquet objects; keep the proxy only for the browse pages
(`index.html`) it exists for. If T4 shows `httpfs` does not follow redirects, fall back to
rewrite+proxy for `*.parquet` only and document that bulk reads should use
`storage.googleapis.com` (which is what every consumer in §3.4 uses today anyway).

#### Q4 — Does `RELEASES.md` stay hand-written, or also carry a generated "what changed" list?

With Level 2 the catalog knows, per object, the first version that shipped it (`since`) — so we
could generate "in this release the following tables/partitions changed: …" automatically.
Where should that appear?

- **In the appendix only** (the generated part of each version's `RELEASE_NOTES.md`, alongside
  the tables/rows/validation lines). `RELEASES.md` stays purely narrative and hand-written; the
  machine-derived facts live in the machine-derived section. Keeps the two kinds of content
  separate and the file readable.
- **Also inserted into `RELEASES.md`** under each version (e.g. a trailing "Changed tables:"
  line written by `promote_unreleased()`). Makes the changelog self-contained when read on GitHub
  or from `ducklake/releases/RELEASES.md` without the per-version files — but it means a script
  edits the narrative file, and re-publishing an old version cannot regenerate a line that was
  computed at cut time.

**Recommendation: appendix only**, with `RELEASES.md` staying human-authored. The narrative
should say *why* a table changed; the appendix can say *which* ones did, and it is regenerated
from the catalog whenever the notes are re-published.

## Status (2026-08-25, evening)

Done, committed locally (not pushed):
- **Level 1 + Level 2 engine** — calcofi4db 3.22–3.23.2: `export_release_parquet()` (total order,
  one thread, pinned writer), `release_objects()` / `freeze_plan()` / `upload_release_objects()` /
  `build_release_catalog()` (per-object `compat_path`), `build_versions_json()` (stamps
  `consolidated`/`retired`), `thin_plan()`; tests green (72). `get_duckdb_con()` creates the
  DuckDB temp dir (spill under memory pressure failed three staging runs).
- **Notebook** — `release_database.qmd` freezes through the plan, supports `CALCOFI_RELEASE_PREFIX`
  / `CALCOFI_RELEASE_LAYOUT` staging; `test_release.qmd` resolves the contract suite through the
  catalog and substitutes `__TBL:table[:col=val]__` tokens.
- **Resolvers** — calcofi4r 1.11.0 (`cc_catalog()`, `cc_release_sources()` incl. the `single_file`
  twin rule, `cc_read_parquet_sql()`, retired-version error, `.cc_match_con()` S3 settings);
  calcofi4py 0.4.0 (same, `RetiredVersionError`); shared fixtures.
- **Consumers migrated** (one commit each, on main): db-query (`lib/release.js`, `__TBL:` tokens in
  every query), db-viz-station + ctd-transects (`scripts/resolve_release.py` renders the SQL,
  `tables.json` for the app), db-schema (`since`/hash chips, consolidated/retired), apps
  (db-viz-cruise, ctd-qaqc), db-viz-hex (manifest provenance), docs (data-access/db/server-access),
  workflows libs (`publish_netcdf.R`, `pg_ctd.R`, `erddap_deploy.R` manifest copy,
  `render_release_views.R` for the PostgreSQL views, warm scripts, index builders).
- **Part 2 machinery** — `metadata/release_policy.yml`, `scripts/thin_releases.R` (dry-run default;
  retired.json, reachability sweep of `tables/`, versions.json + index rebuild), index badges.
- **Caddy** — `server/caddy/Caddyfile` 404→302 map + `scripts/build_release_redirects.R`;
  `scripts/verify_storage_redirects.sh` (T4) written; not yet deployed.

Pending, in order: staging run on the compat layout (T6) → `verify_release_objects.R` (T3) → second
staging run showing `copy` → canonical-layout staging run → deploy Caddy + T4 → push all repos →
first real release → `thin_releases.R` dry-run (T7) → `--execute`.
