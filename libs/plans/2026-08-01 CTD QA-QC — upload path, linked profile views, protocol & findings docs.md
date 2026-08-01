# CTD QA/QC — upload path, linked profile views, protocol & findings docs

Successor to `2026-07-25 Mine the CalCOFI Access master DB`. That plan's Phases 0–7
are **done**; this one covers what running the app revealed was missing. Written to
be self-contained so the preceding context can be discarded.

---

## Part 1 — Where this stands

### What exists now

| Artifact | What it is |
|---|---|
| `libs/extract_accdb.R`, `libs/java/DumpQueries.java`, `scripts/extract_accdb.sh` | Reads any `.accdb` on macOS/Linux — no Windows |
| `metadata/calcofi/hydro-master/accdb/` | 155 query `.sql` files + catalogs (committed, 812 KB) |
| `metadata/calcofi/hydro-master/reference/` | QC reference data: harmonic climatology, 75 stations, standard depths (0.6 MB) |
| `metadata/calcofi/hydro-master/questions.csv` | **17 open questions** for the data providers (2 blocker, 7 high, 8 medium) |
| `metadata/qc_rules/` | Rule registry: `rules.csv` + `sql/*.sql`. **16 active, 2 parked** |
| `metadata/measurement_qual.csv` | The quality-code vocabulary the repo never had |
| `libs/build_hydro_master_metadata.R`, `build_qc_reference.R`, `build_ctd_measurement_registry.R` | Idempotent builders for the above |
| `explore_accdb_hydro-master.qmd` | Query triage notebook |
| `apps/ctd-qaqc/` | The Shiny app: `R/rules.R` engine, `prep_db.R`, `global/ui/server.R` |

Commits: workflows `118cce7`, `1fe0d4e`, `b1c70b2`, `2263a88`, `6f1698a`;
apps `bc89f49`, `287d8f7`, `22a859a`, `62eeff0`.

### Findings that matter (all measured, not assumed)

**Fixed in the pipeline**

- **`-99` sentinel** — the source's missing marker was stripped from lon/lat only, so
  84,302 rows of headline data (incl. canonical oxygen) carried it as a real value.
  Now deleted in the pivot; verified **0** in `obs` (7.3 M) and `obs_ctd_full` (212 M).
- **`btl_*` made canonical** — 11 bottle-reference types were excluded from `obs`;
  only `btl_ammonium` was flagged, which read as a stray edit. `obs` grew
  5,940,598 → 7,310,636. This is what enables the calibration checks.
- **Quality codes** — stored as `"9.0"` from a double→string cast, so none matched
  the vocabulary. Stripped textually (not via INTEGER cast, which would round an
  unexpected `"9.5"`). **3,860 spurious "unrecognized code" hits → 0.**
- **`valid_min`/`valid_max`** moved from an inline tribble into the registry.

**Discovered, not yet actioned**

- **Impossible temperatures.** `temperature_ave` up to **60.4 °C**, 98 values above
  the 40 °C ceiling across ≥6 cruises spanning 1998–2023, **78 of them deeper than
  2 m** (so not a sensor warming on deck). Corroborated independently by the range
  rule and the bottle-vs-sensor rule (bottle says 20.2 °C where the sensor says
  56.8 °C). *User is taking this to the providers.*
- **`S_qual` holds 253 distinct values** in the Access master, clustered at 256–271
  (256 + a low nibble — looks like bit 8 of a bitmask), where every other quality
  column has 3–10. Blocker question.
- **The master holds 573 casts / 13,705 bottles the release lacks** (7 cruises,
  202107–202304) — but the file is "Final through 2105" and 202304 is mid-import.
- **85 bottles were deleted from the master** after its published export was made.
  Checked: **none leaked into the release.**

**Validated method choices**

- **Harmonic form is `Mean + Ampl·sin(Freq·(doy − Phase))`** — determined by scoring
  candidates against the 200,640 bottle observations the coefficients came from
  (+25.2% RMSE vs mean-only; every *cosine* variant was *worse* than the mean).
  Confirmed physically (seasonal signal 42% at surface decaying to ~5% by 500 m) and
  statistically (residual/StDev ~ N(0,1)).
- **Salinity and sigma-theta excluded from the climatology** on evidence: sd(z) of
  6.73 and 4.80 respectively — the tabulated StDev is not the residual scale, so a
  z-score would flag thousands of ordinary values.
- **Spikes need neighbour agreement** — the naive test flagged 92 scans on one
  cruise; requiring the neighbours to agree with each other kept **19**. The other 73
  were real thermocline gradients.
- **`obs_id` is not scan order** (~50% of consecutive pairs decrease in depth). Loop
  edits must order by `datetime`, which is genuinely per-scan.
- **GEBCO agrees with the data**: 100% coverage of 14,336 casts; median cast stops
  ~982 m *above* the seafloor; only 2 casts exceed it by >50 m.

### Environment gotchas worth not rediscovering

- **`tar_make()` is blocked for every target** by `target_name:
  ingest_sio_sio_pic-zooplankton` in the staged `ingest_sio_pic-zooplankton.qmd` —
  doubled `sio_` and a hyphen make it an invalid R symbol. Should be
  `ingest_sio_pic_zooplankton`. The CTD notebook was rendered directly instead.
- **DuckDB cannot hold a read-only and a read-write handle on one file.** This is why
  the review ledger is its own database.
- **`measurement_type.csv` must be read with `calcofi4db::read_measurement_type()`** —
  a plain read turns empty cells into the literal string `"NA"`.
- **mermaid PNG rendering hangs** (system Chrome profile lock; quarto's bundled
  Chromium is too old) — now disabled project-wide in `_quarto.yml`.

### The gap the app exposed

The app runs rules and shows **counts**. It cannot: ingest new data, show a profile,
explain what a rule means, or tell a reviewer why a value is suspect. Four
workstreams below.

---

## Part 2 — Workstreams

### W1 — Run rules on new data, not just the release

**The design principle that makes this cheap:** every rule targets `obs` / `sample`.
Project an upload into that shape and **all 16 rules run unchanged**. No rule needs
to know where the data came from.

- **Extract the projection from the notebook into `calcofi4db`.** The transformation
  raw-CTD-CSV → `obs` rows lives inside `ingest_calcofi_ctd-cast.qmd` today. Lift it
  to an exported function (e.g. `ctd_csv_to_obs()`) so the notebook *and* the app
  call the same code and cannot drift — the `CLAUDE.md` rule that scientific logic
  belongs in the package with a testthat fixture.
- **Column mapping is already solved**: `measurement_type.csv` `_source_column` holds
  the raw CTD CSV column names (`temp1`, `salt_ave_corr`, …). An upload maps through
  the existing registry.
- **Staging, not merging.** An upload lands in a temp schema (`upload_obs`,
  `upload_sample`), rules run against it, findings are reported and downloadable.
  Nothing touches the release. Wipe on session end.
- **UI**: `fileInput` → parse → column-mapping preview (show unmapped columns, which
  is where a format change will announce itself) → run → same findings tables.
- **SQLite** — *confirm before building.* Sea-Bird SeaSave writes `.hex`/`.cnv`/`.btl`,
  not SQLite, so a shipboard SQLite capture is a CalCOFI-specific system. Need: what
  writes it, its schema, and one sample file. Add as a provider question. DuckDB can
  read SQLite directly (`sqlite_scanner`), so if the schema is known this is a small
  addition, not a separate path.
- **Reuse the sentinel/`-99` and quality-code handling** on upload — a new file is
  exactly where those problems arrive.

### W2 — See the data

Findings are currently a table of keys. A reviewer cannot judge a flag without seeing
it in context.

- **Cast profile, down vs up overlaid**, for a selected cast. This is the single
  highest-value view and nothing in the org does it — `ctd-viz` interpolates *across*
  sites; this is *within* one cast. Data is already there (`obs_ctd_full`, direction
  from the `sample_key` `d`/`u` suffix).
- **Finding → profile.** Clicking a finding should plot its cast with the flagged
  scan highlighted. The findings already carry `sample_key` + `depth_min_m`, so this
  is a join away.
- **Point selection → table row**, bidirectionally (plotly `event_data("plotly_click")`
  ↔ DT row selection).
- **Cruise/site context** — reuse `apps/db-viz-cruise`'s map + cruise selection
  pattern rather than rebuilding; deep-link to `apps/ctd-viz` for the interpolated
  section view.
- Keep the URL-bookmarking convention so a flagged cast is a shareable link.

### W3 — Protocol document

A long, linked-from-the-app document explaining every rule.

- **Generate it from the registry**, don't hand-write it: `libs/build_qc_protocol.R`
  assembles `rules.csv` + `sql/*.sql` + per-rule prose into one Quarto document, so
  the doc cannot drift from the rules that actually run. Per rule: what it checks,
  the SQL verbatim, the threshold *and how it was derived*, provenance (which Access
  query, if any), and known limitations.
- **Include the background**: how the Access master was mined, the harmonic-form
  derivation and its evidence table, why salinity/sigma are excluded, the quality
  vocabulary and its unresolved codes.
- **Position against standards and prior art**:
  - **QARTOD** — the IOOS profile manual is the community reference, and its `1/2/3/4/9`
    flags are what ERDDAP consumers expect. Map our native codes to it.
  - **`oce`** (Dan Kelley) — `read.ctd()`, `ctdTrim()`, `despike()`, `ctdDecimate()`.
    Compare our spike and loop-edit rules against its implementations; cite the two
    vignettes.
  - **`castr`** (jiho) — cast-oriented smoothing, despiking, MLD/DCM detection.
  - ⚠️ **CRAN `CTD` is a name collision** — "Connecting The Dots", a weighted-graph
    pattern-discovery package for metabolomics. Not oceanographic. Do not cite it.
- Publish alongside the other notebooks at calcofi.io/workflows, link from the app's
  Rules tab.

### W4 — Findings narrative inside the ingest notebook

`ingest_calcofi_ctd-cast.qmd` (3,074 lines) should carry the story of what the MDB
work found and what the rules say about the current data — but it currently re-does
~1 hour of work to render.

- **Short-circuit the heavy path.** A checkpoint mechanism already exists
  (`db_checkpoint`, "Check for Resumable State" at :193). Extend it to a **content
  hash of the inputs** — the zip URL list plus the metadata registries — so an
  unchanged run skips download/parse/pivot entirely and renders narrative +
  diagnostics from the existing parquet. `write_parquet_outputs()` already
  content-hashes tables for upload dedup; same idea, one level up.
- **Add the narrative**: what the `-99` fix changed and its before/after numbers;
  why `btl_*` are canonical and the depth-thinning trap that made flagging them
  necessary-but-not-sufficient; the instrument-era provenance; the quality-code
  vocabulary and what is still unknown.
- **Surface the rule results** for the current release, so the notebook is where a
  reader learns the data's actual condition.
- **Elaborate the provider questions** in place, feeding
  `metadata/calcofi/ctd-cast/questions.csv` — including the temperature anomaly with
  its cruise-level table.

---

## Sequencing

W4 first (cheapest, makes the notebook usable as a living document and captures the
findings while fresh), then W3 (the protocol doc is what makes the app credible to a
reviewer), then W2 (the views a reviewer needs), then W1 (the largest, and gated on
the SQLite question).

W1 and W2 both argue for extracting shared logic into `calcofi4db` rather than
growing the app — keep scientific logic in the package with tests, per `CLAUDE.md`.

## Verification

- `devtools::test()` in `calcofi4db` for anything extracted there — a fixture per
  transformation, per the repo's testing rule.
- W4: render the notebook twice; the second run must skip the heavy chunks and
  produce identical parquet hashes.
- W3: assert every active rule in `rules.csv` appears in the generated protocol —
  a rule with no documentation should fail the build.
- W2: click a finding, confirm the highlighted scan matches its `depth_min_m`.
- W1: upload a known-bad CSV (inject a `-99` and a spike) and confirm the same rules
  fire as they would in-pipeline.
- End to end: `Rscript -e 'targets::tar_make()'` — **blocked until the
  `ingest_sio_sio_pic-zooplankton` target name is fixed.**
