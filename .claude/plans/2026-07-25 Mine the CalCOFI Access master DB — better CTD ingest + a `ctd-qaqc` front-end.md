# Mine the CalCOFI Access master DB → better CTD ingest + a `ctd-qaqc` front-end

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
authoring environment.

### Purpose — and the hard boundary

**No Access data is imported into the integrated database.** The master is a *knowledge*
source, not a data source. It is being mined for exactly two things:

1. **Metadata, processing rules and QA/QC logic that improve the CTD ingest from source
   files** — the `-99` sentinel handling, the quality-code vocabulary, measurement
   method/accuracy provenance, and canonical-variable identification. These change
   `ingest_calcofi_ctd-cast.qmd` and the `metadata/` registries.
2. **A `ctd-qaqc` front-end and its own database.** That app *does* need tables imported
   from the master (harmonic climatology, station average depths, standard depths, station
   codes) — into a **`ctd-qaqc`-specific database, never the release.**

The distinction that matters: `HarmCoeff*` and friends are the **QC engine's reference
inputs**, not published science tables. Phases 1–3 (extraction, triage, reconciliation)
are already done and unaffected by this scoping; Phases 4–7 below were rewritten for it.

Superseded by this scope: an earlier draft had Phase 4 ingesting 15 net-new Access tables
into the release via a new `ingest_calcofi_hydro-master.qmd`. That is dropped. The
reconciliation that produced the net-new list still stands as the evidence that nothing
needs importing.

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

**Front-end: a Shiny app, `apps/ctd-qaqc`**, sibling to `apps/ctd-viz`. An earlier draft
proposed a static DuckDB-WASM site modelled on `db-query`; that was wrong for this job.
A QA/QC tool must *run* checks in the background, persist mutable review state, and query
a 212 M-row table — none of which a static page does. Full reasoning in Phase 7.

The Turso question above is unchanged by this: server-side Shiny means review state has a
natural home (the Postgres already on the server, or git-tracked correction CSVs), so it
still buys nothing.

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

### Phase 2 — Harvest the metadata layer ✅ DONE

`libs/build_hydro_master_metadata.R` (re-runnable, idempotent). Three deviations from
the original design, each forced by what the data turned out to be:

- **Nothing was merged into `metadata/field_dictionary.csv`.** That registry is
  *prescriptive*; the Access tables are *descriptive* of a 1949-era source schema
  (`T_degC`, `Salnty`, `Cst_Cnt`). Injecting 181 source names would corrupt it. Instead:
  `accdb_field_descriptions.csv` (181 fields / 19 tables, merging `0-Field Descriptions`
  for the core tables with `0-Categories` for the rest) plus `accdb_field_crosswalk.csv`
  proposing canonical targets — 35 matched (8 canonical / 10 alias / 17 measurement_type),
  146 unmatched, all left for review.
- **`0-Measurements` became its own registry, not columns on `measurement_type.csv`** —
  it is one-to-many (Temperature has 6 method eras, Chlorophyll and Phosphate 4 each).
  Flattening would discard the instrument history, which is the entire value.
  `measurement_method.csv`: 35 method-eras, 17 linked by an **explicit seed map**
  (fuzzy matching linked 0 — "Sil"/"PO4-P"/"O2" share no substring with the canonical
  keys, and a looser rule would mis-link silently).
- **The quality vocabulary split in two.** `metadata/measurement_qual.csv` is the real
  controlled vocabulary — 3 documented (`6` = data OK but taken from CTD, `8` = suspect,
  `9` = missing) plus 7 observed-but-undocumented single-digit codes. The full per-column
  distribution went to `qual_code_observed.csv` (279 pairs, 248 with code > 9), because
  pooling them would drown a 3-code vocabulary in what is almost certainly corruption.

Also emitted: `change_log.csv` (280 entries, 2005-10-19 → 2023-10-16, 9 contributors),
`station_code.csv`, `ship_crosswalk.csv` (29 Access ships, 5 matched to `ship_renames.csv`).

**Interpreting `measurement_qual` is deliberately NOT done yet** — it is blocked on
questions 02/02b/05 below. Guessing the semantics would be worse than the current
honest pass-through.

### Data-manager review gate

14 questions are queued in `metadata/calcofi/hydro-master/questions.csv`
(2 blocker, 6 high, 6 medium) rather than resolved by guesswork. The two blockers both
concern quality-flag semantics and gate Phase 5:

- **`hydro_master_02`** — `T_qual` uses 0–7 and `P_qual` uses 3/5/7, but only 6/8/9 are
  documented.
- **`hydro_master_02b`** — `S_qual` holds **253 distinct values** with a dense 256–271
  cluster (256 + a low nibble, i.e. bit 8 of a bitmask), where every other quality column
  has 3–10. Until resolved, salinity quality cannot be interpreted and any ported
  salinity QC rule would be built on sand.

### Phase 3 — Full reconciliation against the current release ✅ DONE

`libs/reconcile_hydro_master.R`. **The headline is that the pipeline is vindicated:**

- **The release is a strict subset of the master, with zero release-only rows.**
  `Cast` 36,217 → 35,644 shared + 573 Access-only; `Bottle` 909,076 → 895,371 shared +
  13,705 Access-only. Nothing invented, no orphans.
- **All 13 measurement types agree to floating-point rounding.** Across 6.0 M shared
  bottle-measurement comparisons exactly **one** value differs by more than 1e-4
  (`oxygen_umol_kg`, 3e-4); max deviation anywhere is 3e-4. No nulls introduced in either
  direction.
- **The Access-only rows are exactly 7 cruises, 202107–202304** — post-2021-05 data the
  release does not have, consistent with it being built from the published
  "through 2105" extract.

Two corrections to what this plan previously assumed:

- The `Bottle` vs `BottleData_194903_202304` gap is **not** "8 missing rows". It is
  **93 out / 85 in**, netting −8. The 93 are all cruise 202304 (mid-import); the 85 are
  bottles *deleted from the master after* the export was generated, across 202105 /
  202111 / 202208 / 202211.
- `BottleData_194903_202304` is **not a plain extract** of `Bottle` — it is a
  denormalized Cast⨝Bottle export (30 columns vs 13).
- Since 202105 falls inside the release's coverage, withdrawn data could plausibly have
  leaked in. **Checked: zero of the 85 appear in `bottle` or `bottle_measurement`.**

**Table disposition** — all 65 Access tables classified, none left unclassified
(`metadata/calcofi/hydro-master/table_disposition.csv`): 30 working copies / staging,
10 documentation (harvested in Phase 2), 8 covered by an existing release dataset,
2 reconciled and verified, and **15 NET-NEW carrying 2,853,787 rows** — the Phase 4 input.

Deferred: running the ported `TR` checks against the release moves to Phase 5, since it
needs the rule registry that phase builds.

### Phase 4 — Feed the CTD ingest (metadata + processing + QA/QC) ✅ MOSTLY DONE

**Nothing from the Access master enters the integrated database.** It is a knowledge
source. This phase spends that knowledge on `ingest_calcofi_ctd-cast.qmd` and the
`metadata/` registries.

**4a. `-99` sentinel — DONE and verified.** The source's missing marker was stripped from
longitude/latitude only, so it flowed through `ctd_measurement` → `ctd_thin` → `obs` as a
real reading (84,302 rows in v2026.07.17, including canonical oxygen). Now deleted in the
pivot, exact-match rather than tolerance, with an accounting `stopifnot`. Placed before
`ctd_summary` and `ctd_thin` derive from it, so the fix propagates; `ctd_wide` — the one
output built earlier — is retired. **Verified empirically: zero `-99` in `obs`
(5.94 M rows) and `obs_ctd_full` (212 M rows).**

**4b. `measurement_qual` — decoded, deliberately not acted on.** The vocabulary from
Phase 2 (`6` = data OK but taken from CTD, `8` = suspect, `9` = missing) is now joined and
reported in a Data Quality Diagnostics subsection, with unrecognized codes surfaced loudly
rather than left as a silent `NA` from the join. The `"9.0"` cast artifact is fixed at the
source — stripped **textually** (`regexp_replace(…, '\.0+$', '')`) rather than via an
INTEGER cast, so an unexpected `"9.5"` stays visible instead of being rounded to 9.

Nothing drops or rewrites a flagged value: questions 02 / 02b / 05 are open, two of them
blockers, and acting on unconfirmed semantics would be guessing with released data.
**The real gap remains** — 8 of the now-27 canonical types carry no flag at all, because
source flags attach to component sensors (`Temp1Q`, `Salt1Q`, `Ox1Q`) while the canonical
value is the *average*. That propagation rule (worst-of? both-must-pass?) is `ctd-qaqc`
work.

**4c. Instrument provenance — DONE (rendered).** `measurement_method.csv` is joined by
*base property*, stripping sensor/correction suffixes (`temperature_ave` → `temperature`,
`oxygen_ml_l_ave_sta_corr` → `oxygen_ml_l`, `oxygen_btl_ml_l` → `oxygen_ml_l` — the bottle
marker appears as prefix, suffix **and infix**, which is why it is three rules not one).
24 of 54 CTD types now carry instrument, stated accuracy and era. The payoff case:
`temperature_ave` shows both the reversing thermometer (through 1993-04-15) and the CTD
thermistor (from 1993-08-11) — the changeover this dataset begins at.

Still a table, not a sidecar: promoting it into `metadata.json` belongs in
`calcofi4db::build_metadata_json()`, and 18 of 35 era rows await mapping confirmation
(`hydro_master_06`).

**4d. Bottle-reference pairs — DONE.** All 12 `btl_*` / `*_btl` types are now
`is_canonical`, not just `btl_ammonium` (which read as a stray edit). These are the
reference side of the sensor-vs-Winkler/Portosal calibration check that `ctd-qaqc` is
built around. Thinning correctly does **not** apply to them: a bottle fires at a few
discrete depths that no interpolation reconstructs, and subsetting them to the 10 m grid
discarded ~73% of real lab samples when `btl_ammonium` was first promoted. The ingest's
`canon_btl` / `btl_clause` (`retained_reason = 'bottle'`) already handles this and is
prefix-based, so the whole group is covered automatically.

**Also done:** `valid_min` / `valid_max` moved out of the `plaus` tribble that lived inline
in one diagnostics chunk and into the registry, exactly as that chunk's comment asked —
same values, now reviewable in a diff, emittable by the CF netCDF writer as real variable
attributes, and available to any QC rule. Still report-only; they catch impossible values
and are not the agreed oceanographic ranges.

The registry is now read with `calcofi4db::read_measurement_type()` rather than bare
`read_csv` — the round-trip trap, which mattered here because line ~1293 does `na.omit()`
on `_qual_column` and a literal `"NA"` string would have become a phantom flag column.

Applied by `libs/build_ctd_measurement_registry.R` (idempotent).

**Not yet done:** re-run the ingest so the release reflects 4b/4c/4d. Expect `ctd_thin` /
`obs` to grow — 11 more canonical types, each retained whole at bottle depths.

### Phase 5 — The `ctd-qaqc` reference database

A **separate** DuckDB for the QA/QC app. These tables are the QC engine's reference
inputs, not published science tables, and they do **not** go in the release:

| from the Access master | role in `ctd-qaqc` |
|---|---|
| `HarmCoeff{Bottle,Chla,Sigma,LogZoo}` | expected value + stdev per station × depth → z-score test |
| `CurrentStations` (`Avg_Depth`) | bottom-depth plausibility (the `TQ - BottomDepth_Vs_AvgBottomDepth` ±500 m rule) |
| `StDepths` | canonical standard-depth grid |
| `0-Sta_Code` | station-class filter the `TR`/`TQ` checks depend on |
| `MLD_Sigma`, `NutClineDepth` | derived-product reference values to validate recomputation against |
| `measurement_qual.csv`, `measurement_method.csv` | vocabularies from Phase 2 |

If these should instead flow through pipeline machinery (Parquet + `metadata.json` + GCS)
without entering the release, the mechanism already exists: a `calcofi:` block with
**`in_release: false`** (see `CLAUDE.md`). That is the deliberate choice to make — a
standalone app DB, or a staged non-released ingest.

Also evaluate the **CTD final-QC databases** found alongside the master
(`CTD downcast upcast - databases/`): 1 m bin-averaged, final-QC'd, 1993–2019, up- and
downcast as separate ~4 GB products, plus a SQL Server Express backup. That is a curated
CTD product the pipeline does not currently read — a validation target for `ctd_thin`, and
possibly a better basis than DIY adaptive thinning. Note it **ends 2019** while the ingest
reaches 2021-05, and the same harness (`libs/extract_accdb.R`) reads its Access form.

### Phase 6 — CTD QC rule set

Split by what can be ported versus what must be written:

**Portable from the master** (~48 triaged `validate` queries, 37 hazard-free): referential
(`TR`), coverage (`TS`), bottom-depth and station-name checks (`TQ`), value-range (`TV`).
Rewrite against `ctd_cast` / `ctd_thin`, keeping `source_query` for provenance. Honour the
Access-dialect hazards already scored in `query_triage.csv`.

**Must be written — the master is bottle-grain and has no concept of these:**
- spike / despiking on adjacent scans
- density inversion (σθ must increase with depth)
- pressure monotonicity and loop edits
- sensor 1 vs sensor 2 disagreement
- up- vs downcast disagreement (the source ships both; `ctd_thin` keeps one direction, so
  this signal is currently discarded)
- bottle-vs-sensor calibration offset at matched depth (Phase 4d)
- climatology z-score, once `HarmCoeff*` is regridded from standard depths onto
  `ctd_thin`'s 10 m grid

**Emit QARTOD alongside the native codes.** CalCOFI publishes to erddap.calcofi.io where
IOOS `1/2/3/4/9` flags are the convention; the Access `6/8/9` vocabulary is bespoke.

Registry: `metadata/qc_rules.csv` (`rule_key, rule_type, dataset_key, table, column, sql,
severity, description, source_query, active`). Logic in `calcofi4db` with a testthat
fixture per rule type; bump `DESCRIPTION` + `NEWS.md` in the same change. The 30 `UPDATE`
queries are documented history and are **never executed**.

### Phase 7 — `ctd-qaqc` front-end (Shiny)

New Shiny app, as a sibling in the **`apps/` monorepo** alongside `ctd-viz` — not a
static site. A QA/QC tool is a different animal from a query playground, and three of
its requirements rule out DuckDB-WASM on GitHub Pages:

- **It has to *run* checks, not just read results.** WASM can only query pre-computed
  Parquet. Shiny's `ExtendedTask` / `promises` / `callr` can kick off a rule sweep, a
  climatology refit, or a re-ingest of one cruise in the background and stream progress.
- **Review state is mutable.** Who flagged which cast, when, why, accepted or rejected —
  that is write traffic, and server-side makes it a non-issue rather than a design
  problem. (This is what the "frozen archive" answer settled for *Access* but not for the
  *app*.) Persist to the Postgres already running on the server, or to git-tracked
  correction CSVs following the `cruise_key_corrections.csv` pattern.
- **Scale.** `obs_ctd_full` is 212 M rows — hostile to WASM, routine for server-side
  DuckDB, which `apps/ctd-viz` already does via `prep_db.R`.

Reuse rather than rebuild:

- `apps/ctd-viz/prep_db.R` is the model for materializing a local DuckDB from the
  release (it already stages `ctd_thin`, `ctd_summary`, `ctd_cast`, `measurement_type`).
  `ctd-qaqc` needs the same plus the Phase 5 reference tables.
- `enableBookmarking(store = "url")` / the `db-viz-cruise` query-string convention so a
  flagged cast is a shareable link.
- Deep-link into `apps/ctd-viz` for profile inspection instead of duplicating plots.
- Deploy is the existing path: clone under `/share/github/CalCOFI/apps`, symlink into
  `/srv/shiny-server/`, `touch restart.txt`. No new hosting, no Pages workflow.
- Register in `CalCOFI.github.io/_data/products.yml` and `uptime/.upptimerc.yml`.

The tradeoff, stated plainly: it is down when the server is, and it loses the frictionless
public link a static site gives. `db-query` already covers ad-hoc SQL against the release,
so that gap is already filled and does not need duplicating.

---

## Verification

- `devtools::test()` in `calcofi4db` — a synthetic fixture per new rule type; a red test is
  a hard stop. Reinstall the package so notebooks pick up changes.
- **4a regression guard (in place):** the ingest asserts sentinel-delete accounting
  (`n_meas_raw - n_sentinel == n_meas`) and the diagnostics chunk reports zero `-99`; a
  regression shows up as a non-zero row in that audit rather than silently.
- **Re-run the CTD ingest** so the release reflects 4b/4c/4d. Expect `ctd_thin` / `obs` to
  GROW: 11 newly-canonical bottle-reference types, each retained whole at bottle depths
  rather than thinned to the 10 m grid.
- Re-run `scripts/extract_accdb.sh` from clean; assert the row counts in this document.
- Diff Jackcess vs mdbtools SQL across all 155 queries; mdbtools must be a strict subset.
- Render `explore_accdb_hydro-master.qmd`: 155 queries triaged, 12 relationships reproduced,
  the 1 known Jackcess failure explicitly listed.
- Phase 3 reconciliation report has **zero unexplained deltas**.
- `Rscript -e 'targets::tar_make()'` → the CTD ingest re-runs with the sentinel and flag
  changes; `test_release.qmd`'s consumer-contract suite must still pass before `latest.txt`
  promotes. **Expect the released `ctd_thin` values to change** — 84,302 sentinel rows
  become NULL, so row counts and any cached aggregate shift.
- Hand-check three ported rules against their Access originals (open the `.sql`, run both,
  compare row counts).
- Launch `apps/ctd-qaqc` locally against a prepped DuckDB and confirm a check runs in the
  background and its verdict persists across a session restart.
