# Port the CalCOFI Access master DB → DuckDB/Parquet + a `db-qaqc` front-end

## Context

`CalCOFI_4903-2304_Master_Final_through_2105_October162023.accdb` (2.0 GB, ACE12 /
Access 2007 format) is the **hydrographic master / authoring database** behind the
published CalCOFI bottle database, covering 1949-03 → 2023-04. It holds roughly 30
years of institutional QA/QC knowledge — 155 saved Access queries, a self-documenting
metadata layer, a declared FK graph, and a harmonic-climatology expected-value engine —
**none of which exists in the modern `workflows` pipeline**.

Today the pipeline ingests this database's *published outputs* (bottle CSVs) but not its
*logic*, and not several of its tables at all. Concretely:

- `measurement_qual` is a verbatim pass-through of the source `*q` column — never
  interpreted, no controlled vocabulary anywhere in the repo, used only as a tiebreak
  sort key in `ctd_thin` assembly (`ingest_calcofi_ctd-cast.qmd:1891`).
- Validation is hard-coded, not declarative: `calcofi4db/R/freeze.R:230`
  `validate_for_release()` has four families (a column-name-suffix NULL heuristic, four
  literal ranges, row counts, table completeness). `validate_dataset()`
  (`R/validate.R:245`) accepts only `fk` and `lookup` types via an R list literal.
- **Nothing in the pipeline evaluates a measurement against an expected oceanographic
  range, cross-sensor agreement, or a climatological anomaly** — exactly the categories
  the Access queries hold.

The file is a **frozen archive**: it is being mined and retired, not replaced as a live
authoring environment. So everything downstream is read-only, and no mutable multi-user
store is needed.

Outcome: reproducible extraction → enriched metadata registries → full reconciliation
against the current release → the net-new tables ingested → a declarative QC rule
registry that runs at release time → a `db-qaqc` front-end.

### Scope note

Despite living in the Drive `ctd-cast/` folder this is **not** the CTD-cast dataset. Its
`Cast` table is 36,217 *hydrographic* casts; the repo's `ctd_cast` is 5.55 M per-scan
rows. It maps to `ingest_calcofi_bottle` (plus zooplankton, productivity, weather, DIC).
Its integer keys `Cst_Cnt` / `Btl_Cnt` correspond to the `cast_id` / `bottle_id` source
counters the bottle ingest already uses — so the reconciliation join key already exists.

---

## Findings from the spike (verified on this Mac, not assumed)

**No Windows VM is needed.**

| Question | Result |
|---|---|
| Format | `mdb-ver` → **ACE12** |
| Tables readable on macOS ARM? | Yes — `brew install mdbtools`; **65 user tables** (91 `table_local` incl. system), `mdb-schema` 1,715 lines |
| Saved query SQL readable? | Yes — **Jackcess 4.0.7 + JDK 25 extracted 154 / 155** at full fidelity |
| mdbtools SQL good enough? | **No.** Measured across all 155: **96 lost a `JOIN`**, **81 lost a `GROUP BY`**, 1 rendered empty, **0 gained anything Jackcess lacked**. Strict subset — cross-check only |
| Forms / reports / macros / VBA? | Only **2 VBA modules** (`mdl_autonum`, `rownum` — utility, not science), **1 form** (`Cruises` data entry), **1 report** (`QC_Weather`, whose record source Jackcess recovered anyway) |

Jackcess output is faithful, e.g. `TR - Cast & Bottle: Cst_Cnt`:

```sql
SELECT Cast.Cst_Cnt, Cast.Cruise, Cast.Sta_ID, Bottle.Cst_Cnt
FROM Cast LEFT JOIN Bottle ON Cast.Cst_Cnt = Bottle.Cst_Cnt
WHERE (((Bottle.Cst_Cnt) Is Null));
```

**The 155 queries** — ~90 KB of SQL total, entirely reviewable by hand:

| Access type | n | Disposition |
|---|---|---|
| `SELECT` | 95 | The QA/QC + analysis corpus → port |
| `UPDATE` | 30 | Historical one-time repairs → **document, never re-run** |
| `MAKE_TABLE` | 16 | Materialization → obsolete (pipeline owns publishing) |
| `CROSS_TAB` | 13 | Access `TRANSFORM…PIVOT`; no DuckDB equivalent → manual translation |
| `APPEND` | 1 | Document |

By the naming taxonomy **the database documents itself** (table `0-Query Info`):
`TR -` test table linkage (21), `TQ -` quality control (9), `TS -` probe data structure
(4), `TV -` test unusual values (3), `TX -` intermediate test results (2), `QC*` explicit
QC (9) → **~48 portable checks**. Plus 13 `Anomalies`, 3 `Isopycnal`, 4 `ML Data`,
3 `Depth Data` = derived science products. **26 of 155 queries reference other saved
queries** — Access queries are views, so porting must respect that DAG.

**Self-documenting metadata tables:**

| Access table | Rows | Maps to |
|---|---|---|
| `0-Categories` | many | `metadata/field_dictionary.csv` — `Table_Name, Field_Name, Units, Values, Description` |
| `0-Measurements` | ~29 | `metadata/measurement_type.csv` — adds **`Method`, `Accuracy`, `Year_started`, `Year_ended`** (e.g. reversing thermometer → CTD thermistor on 1993-08-11; PO4 method changes 1949→1983). The repo has none of this |
| `0-Units`, `0-Tables Info`, `0-Ships`, `0-Sta_Code` | — | Unit vocabulary, table docs, UNOLS ship codes, station-code semantics |
| `0-Work Done` | **281** | Dated, initialled change log → corrections provenance |
| `Bottle_Q` | 909,076 | `T_prec, T_qual, S_prec, S_qual, P_qual, O_qual, SThtaq, O2Satq` — **the missing controlled vocabulary for `measurement_qual`**, 1:1 with `Bottle` |
| `HarmCoeff{Bottle,Chla,Sigma,LogZoo,10m}` | 841 + … | Per `Sta_ID × StDepth × {Temp,Sal,Sigma,O2}`: mean, amplitude, frequency, phase, **stdev** — an expected-value climatology, i.e. a z-score outlier engine |

**Declared FK graph** (`MSysRelationships`, 12 relationships, mostly RI-enforced):

```
Cruises ─< Cast ─< Bottle ─< {Bottle_Q, Chl, Nuts, Rpt_Data, Prodo_Bottle}
             ├─< Prodo_Cast ─< Prodo_Bottle
             ├─< Weather
             ├──> CurrentStations   (Cast.DbSta_ID)
             └──  Zooplankton       (by Cruise, RI not enforced)
```

**Row counts** (verified against the Phase 0 Parquet, 65 tables / 10,509,889 rows total):
`Bottle` / `Bottle_Q` / `Chl` / `Nuts` / `Rpt_Data` / `Prodo_Bottle` 909,076 **each**;
`BottleData_194903_202304` 909,068 (an **8-row delta**); `Cast` 36,217;
`Zooplankton` 49,943; `Station_ID` 4,091; `Cruises` 400; `CurrentStations` 75;
`HarmCoeffBottle` 840; `MLD_Sigma` 620; `NutClineDepth` 585.

Two things that fall out of those counts:

- **`Bottle` and its five satellites are 1:1, not 1:many** — a classic Access vertical
  partition. They should collapse into long-format `obs` rows, not survive as six tables.
- Do **not** re-derive counts with `mdb-export | wc -l`. Free-text fields contain embedded
  newlines (e.g. a captain name in `Cruises` line 345), so `wc -l` over-counts; DuckDB's
  CSV reader parses the quoted field correctly. All 400 `Cruises.Cruise` values are distinct.

---

## Decisions

**Storage: DuckDB + Parquet.** Turso is out. It is row-oriented OLTP against 909 K–216 M-row
column scans; the Rust engine is explicitly beta (maintainers state libSQL is the
production line, the rewrite is not production-ready); it has no Parquet/GCS story when
the data already lives as Parquet read by `calcofi4r::cc_get_db()`, ERDDAP-over-DuckDB and
DuckDB-WASM; and it would be the org's only SQLite (the sole current hits are *denylist*
entries in `api-h3t/sql_validate.py`). The one use that could have justified it — a
writable multi-user review ledger — is moot now that the Access file is a frozen archive.

**Front-end: a new `CalCOFI/db-qaqc` repo**, Jekyll + DuckDB-WASM on GitHub Pages, modelled
on `db-query` but with its own audience and domain. An Access "saved query with a documented
Purpose" maps 1:1 onto a `_queries/<category>/<name>.md`, with the `0-Query Info` purpose
text as the body.

**Windows: not required.** Everything scientific is reachable from macOS/Ubuntu; the only
unreachable content is 2 utility VBA modules and 1 data-entry form, which is not worth
standing up infrastructure for. If you ever want them, ask a colleague who already runs
Access (~10 min, $0), or UTM + a Windows 11 ARM64 ISO + an M365 trial (~2 h, $0). Note the
free Access **Runtime cannot open Design View**, so it does not help. On the Ubuntu servers
the path is identical: `apt install mdbtools` + JDK + Jackcess.

---

## Plan

### Phase 0 — Reproducible extraction harness ✅ DONE

- `libs/extract_accdb.R` — tool discovery, catalogs (`accdb_objects()`,
  `accdb_relationships()` with decoded DAO flag bitmasks), `accdb_export_tables()`
  (all-VARCHAR → Parquet), both query extractors, and `accdb_diff_query_sql()`.
- `libs/java/DumpQueries.java` — Jackcess `Query#toSQLString()` dumper, emitting one CSV
  so the filename-sanitizing rule lives only in R.
- `scripts/extract_accdb.sh` — driver. Jars pinned (`jackcess 4.0.7`,
  `commons-lang3 3.14.0`, `commons-logging 1.3.0`), cached in `data/cache/jackcess`.
- Outputs split by reviewability:
  `metadata/calcofi/hydro-master/accdb/` **committed** (~800 KB: `sql/*.sql` ×155,
  `queries.csv`, `query_sql_diff.csv`, `relationships.csv`, `objects.csv`, `schema.sql`,
  `tables.csv`); `data/accdb/calcofi_hydro-master/tables/*.parquet` **gitignored**.
- **Known gaps, encoded rather than hidden**: `Anomalies ISL 0 IM` fails Jackcess
  (`IllegalStateException: Inconsistent join types`) and lands with `ok=false` + the
  message in `queries.csv`; the 13 `CROSS_TAB` queries emit Access `TRANSFORM…PIVOT`,
  which DuckDB will not parse.
- Portability trap fixed: macOS ships a `/usr/bin/java` stub that exists but is not a JVM,
  so `accdb_tool_paths()` probes candidates with `-version` instead of trusting `Sys.which`.

### Phase 1 — Land + triage

- `explore_accdb_hydro-master.qmd` (an `explore_*` notebook — deliberately not yet a
  pipeline target). Loads the Parquet into DuckDB, renders the FK graph and row counts, and
  a **triage table** classifying all 155 queries as `validate` / `correction-history` /
  `derived-product` / `obsolete` / `unclassified`, each carrying its `0-Query Info` purpose
  text and Access query type. Resolve the 26-query dependency DAG into topological order.
- **Human review gate** before porting — the triage is a scientific judgement, and the
  `Goericke` / `JRW` / `AEH` initials in `0-Work Done` name the people whose intent we are
  reconstructing.

### Phase 2 — Harvest the metadata layer

- Merge `0-Categories` → `metadata/field_dictionary.csv`; regenerate via
  `libs/build_field_dictionary.R`.
- Extend `metadata/measurement_type.csv` with new `method`, `accuracy`, `year_started`,
  `year_ended` columns from `0-Measurements`.
- New `metadata/measurement_qual.csv` from `Bottle_Q` — the controlled vocabulary
  `measurement_qual` has always lacked. Then **start interpreting the flag** instead of
  passing it through.
- New `metadata/calcofi/bottle/change_log.csv` from `0-Work Done` (281 rows).
- Cross-check `0-Ships` / `0-Sta_Code` against `metadata/ship_renames.csv`, and
  `MSysRelationships` against `relationships.json` / `relationships_cross.csv`.

### Phase 3 — Full reconciliation against the current release

This runs **before** any new ingest, because it determines what is actually net-new.

- Row-by-row compare Access `Cast` (36,217) and `Bottle` (909,076) against the released
  bottle tables, joining on the `Cst_Cnt` → `cast_id` / `Btl_Cnt` → `bottle_id` source
  counters. Report: rows only in Access, rows only in the release, and per-column value
  deltas for shared rows.
- Explain the 8-row `Bottle` (909,076) vs `BottleData_194903_202304` (909,068) delta.
- Reconcile `Chl`, `Nuts`, `Zooplankton`, `DICs`, `Cruises`, `Station_ID`,
  `CurrentStations` the same way.
- Deliverable: a reconciliation report chunk plus
  `data/accdb/calcofi_hydro-master/reconciliation/*.csv`. Every delta resolves to either a
  release bug, an Access-era artifact, or a documented intentional difference — no
  unexplained residue.
- Run the ported `TR` (referential) checks against the current release as part of this;
  each finding is either a real bug or a rule to retire.

### Phase 4 — Ingest the net-new tables

Only what Phase 3 proves is *not* already in the release. Expected: `Weather`,
`Prodo_Cast`, `Prodo_Bottle`, `Rpt_Data`, `MLD_Sigma`, `NutClineDepth`, `HarmCoeff*`.

- New `ingest_calcofi_hydro-master.qmd` with a `calcofi:` YAML block —
  `provider: calcofi`, `dataset: hydro-master`, `dependency: [ingest_calcofi_bottle]`
  (so it can reconcile and reuse `cast_id`/`bottle_id`), `tables_owned` listing only the
  net-new tables. **Do not hand-edit `_targets.R`** — `build_targets_list()` discovers it
  from the YAML.
- Project into the core model rather than adding another per-dataset triple:
  `Weather` → `sample_measurement` at cast grain; `Prodo_Bottle` → `obs`;
  `Rpt_Data` → `obs` (derived: dynamic height, sigma-theta); `MLD_Sigma` /
  `NutClineDepth` → `obs` at cast grain; `HarmCoeff*` → a `climatology_harmonic`
  reference table.
- Observe the key-suffix convention (`*_id` integer, `*_key` string) and end with
  `finalize_ingest()`.

### Phase 5 — Declarative QC rule registry

- New `metadata/qc_rules.csv`:
  `rule_key, rule_type, dataset_key, table, column, sql, severity, description,
  source_query, source_purpose, active`
  with `rule_type ∈ {fk, lookup, range, unique, coverage, crosscheck, climatology}`.
- New `calcofi4db::validate_rules(con, rules)`; extend `validate_dataset()`
  (`R/validate.R:245`) with the new types and call it from `validate_for_release()`
  (`R/freeze.R:230`) so rules run at release time. Per `CLAUDE.md` the logic lives in the
  package with a testthat fixture per rule type; the notebook only calls it. Bump
  `DESCRIPTION` `Version:` with a matching `NEWS.md` entry in the same change.
- Port the ~48 `TR`/`TQ`/`TS`/`TV`/`QC` queries as rows, **rewriting Access SQL against the
  core model** (`sample` / `obs` / `sample_measurement`), not Access table names. Keep
  `source_query` on every row so provenance stays traceable.
- The 30 `UPDATE` queries go into the change log and are **not executed** — one-time repairs
  against the Access copy. Anything still needed becomes a correction CSV row following the
  `metadata/calcofi/ctd-cast/cruise_key_corrections.csv` pattern.

### Phase 6 — Climatology / anomaly engine

- Publish `climatology_harmonic` as a release reference table: expected value and stdev per
  station × depth × day-of-year → a z-score outlier test.
- Add the `climatology` rule type: flag `|z| > k`, `k` configurable per measurement type.
- **Recompute** the coefficients independently from the release and assert agreement with
  the Access-era values — an excellent permanent regression fixture.
- Reimplement the `MLD_Sigma`, `NutClineDepth`, `Anomalies` and `Isopycnal` recipes in the
  same pass.

### Phase 7 — `db-qaqc` front-end

- New `CalCOFI/db-qaqc` repo → calcofi.io/db-qaqc, Jekyll + GitHub Pages.
  **Gotcha:** set Pages `build_type=workflow` (deploy `public/` from an action), not the
  legacy branch source — this is what bit `db-viz-station`.
- Lift `db-query/lib/duckdb.js` verbatim (dependency-free CDN singleton) and
  `lib/options-sources.js` (cruise / measurement-type pickers). Reuse the
  `_queries/<category>/<name>.md` frontmatter convention: parameters for cruise / line /
  station / depth / year, inline Handlebars `sql:`, body = the Access purpose text. Keep
  `render_with_liquid: false` on the collection.
- Reuse `db-schema`'s sidecar-fetch pattern (`versions.json`, `latest.txt`,
  `metadata.json`, `catalog.json`) for release selection and units, and
  `db-viz-cruise`'s URL-query-string permalinks so a flagged cast is a shareable link.
- **QC scorecard**: `release_database.qmd` emits a `qc_results.json` sidecar alongside the
  existing ones, so every release publishes its own pass/fail dashboard.
- Adopt db-query's `workflow_dispatch` `default_version` bump so the site never points at a
  release that has not passed `test_release.qmd`.
- Register the new site in `CalCOFI.github.io/_data/products.yml` and
  `uptime/.upptimerc.yml` (the authoritative service list).

---

## Verification

- `devtools::test()` in `calcofi4db` — a synthetic fixture per new rule type; a red test is
  a hard stop. Reinstall the package so notebooks pick up changes.
- Re-run `scripts/extract_accdb.sh` from clean; assert the row counts in this document.
- Diff Jackcess vs mdbtools SQL across all 155 queries; mdbtools must be a strict subset —
  this is the guard against silently trusting the lossy extractor.
- Render `explore_accdb_hydro-master.qmd`: 155 queries triaged, 12 relationships reproduced,
  the 1 known Jackcess failure explicitly listed.
- Phase 3 reconciliation report has **zero unexplained deltas**.
- `Rscript -e 'targets::tar_make()'` → the new ingest runs and `release_database.qmd`
  executes the new rules; `test_release.qmd`'s consumer-contract suite must still pass
  before `latest.txt` promotes.
- Hand-check three ported rules against their Access originals (open the `.sql`, run both,
  compare row counts).
- Load `db-qaqc` in a browser and confirm the checks execute against the current release.
