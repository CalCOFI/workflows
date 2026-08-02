# Resolve CTD QA/QC loose ends → question registry → schema changes → full release → consumer deploys

Successor to `2026-08-01 CTD QA-QC — upload path, linked profile views, protocol &
findings docs` (W1–W4 all **done**, committed and pushed). Written to be
self-contained so the preceding context can be discarded.

**Recommendation: yes, clear context before executing.** This is ~13 workstreams
across 5 repos, including a breaking change to a shared core table, a multi-hour
full pipeline re-render, a release, and a server deploy. The reconnaissance is
done and recorded below so nothing needs rediscovering.

---

## Part 1 — Where this stands

### Shipped and pushed (2026-08-01)

| | |
|---|---|
| `calcofi4db` 3.3.0 | QC rule engine (`qc_*`), input fingerprinting, `qc_cast_profile()`, the CTD upload path (`read_ctd_upload()` + `ctd_upload_to_core()` + `qc_upload_con()`). 508 tests pass. |
| `ingest_calcofi_ctd-cast.qmd` | `## Findings` section (reads parquet, renders in ~6 s), input-fingerprint fast path, source-documentation narrative |
| `qc_protocol.qmd` | generated from `metadata/qc_rules/`; build fails on an undocumented rule |
| `apps/ctd-qaqc` | Profile tab (down/up overlay, finding → ringed scan, cruise map), Upload tab, two `testServer` wiring tests |
| `metadata/` | `measurement_qual.csv` now dataset-scoped (`code_set`), `sbe_name_map.csv`, 19 QC rules (16 active, 3 parked) |

### Reconnaissance already done — do not redo

- **136 questions across 17 `questions.csv` files.** Status vocabulary is
  inconsistent (`open` / `answered` / `resolved` / `wontfix`) and priority has both
  `normal` and `medium`. `id` is already globally unique
  (`{provider}_{dataset}_{nn}`); what is missing is a short display label.
- **`obs_freq` no longer exists — `obs_attribute` absorbed it.** `calcofi4db/R/model.R:94`
  states it outright ("`obs_freq` (same columns; adds behavior rows + the
  taxon_key rename)"), the released parquet has `obs_attribute.parquet` and no
  `obs_freq`, and ERDDAP agrees. **The only work left is documentation**:
  `design_env-bio-consolidation.md` still says `obs_freq` 22 times and is stale.
- **`append_sample()` has a fixed 15-column positional contract**
  (`calcofi4db/R/model.R:261`) and **16 ingests call it**. Adding a column
  positionally would break all 16 at once.
- **The `Comment` column never appears.** 0 of 26 sampled CSVs (including the 6
  oldest) have it; every file has exactly 82 columns. The spec lists `Comment` as
  field 82.
- **`db-schema` is a 3-file Jekyll app**: `index.html` (81 lines), `app.js` (870),
  `style.css` (540). Supplemental handling is `app.js:542,579`. The Tables filter
  is `#tables-filter` (`index.html:54`). There is no explicit ERD→Tables click
  handler in `app.js` — the navigation is via `location.hash` (`app.js:242`), so
  the confounding click is most likely mermaid's own node links inside the SVG.

---

## Part 2 — Design decisions, with recommendations

These are the questions the user asked. Each has a recommendation; **confirm before
building** where marked ⚠️.

### D1. `data_stage` on core `sample` (question `calcofi_ctd-cast_14`)

**Recommendation: add it as an OPTIONAL trailing column**, not a positional one.

`append_sample()` binds `select_sql` positionally to 15 named columns. Make the
helper accept 15 **or** 16 columns: when 16, the last is `data_stage`; when 15, it
inserts `NULL`. Then only `ingest_calcofi_ctd-cast.qmd` changes now, the other 15
ingests keep working untouched, and each can opt in later when it has a
meaningful stage.

- `.ensure_sample_schema()` gains `data_stage VARCHAR`.
- Add a test for both arities.
- `ctd-cast` supplies `final` / `preliminary` (it already has it on `ctd_cast`).
- Consumers: `db-schema` picks it up from the sidecar automatically; `calcofi4r`
  needs no change; the **`ctd-qaqc` Profile/Findings tabs should show it**, since
  "this cast is preliminary" is exactly the context a reviewer needs.

### D2. The `Comment` discrepancy

Not a data-loss issue — resolve it as documentation. One query settles whether the
files' 82nd column is `SIL` (spec off-by-one) or an unnamed trailing field. Record
the answer in the protocol's "Smaller points" and, if it is genuinely ambiguous,
raise it as a low-priority question rather than leaving a dangling note.

### D3. Q15 — can the span / DBcoeff / xmlcoeff values be computed from the data?

Answering per family, because they differ:

| file | computable? | recommendation |
|---|---|---|
| `*_span_*.csv` (per-cast min/max) | **Yes, trivially** — `GROUP BY sample_key, measurement_type` | Compute it, but understand it answers a *different question*. The source file records what the **processor** saw; recomputing from our own `obs` is circular (a corrupted value simply widens the span we compute) and cannot validate anything. **Build it as a profile-summary panel in the app** for review context; keep the parked rule `ctd_value_outside_cast_span` pointing at the ingested source file for the actual cross-check. |
| `*_DBcoeff_*.csv` (salinity offsets, O2 regressions, residual SDs) | **Partly — and this is the valuable one** | Now that `btl_*` are canonical, **both sides of every regression are in `obs`**. We can re-derive per-cast salinity offset (mean bottle − sensor below 350 m) and the per-cast residual SD, and compare against the *applied* correction. The residual SD is exactly what the core's declared-but-empty `measurement_prec` is for. **Recommend: compute the per-cast residual as a new QC rule + candidate `measurement_prec` source**, and still ingest DBcoeff to check our reconstruction against theirs. |
| `*_xmlcoeff_*.csv` (serials, calibration dates) | **No** | Pure instrument metadata; not derivable from values. Must be ingested if wanted. It would give per-cast instrument provenance, far finer than the decade-scale `measurement_method.csv` eras. |

### D4. Q17 — expressing the `EstChl` 0–200 m and `_StaCorr` restrictions

Two different kinds of constraint; do not force them into one mechanism.

1. **Depth restriction is a property of the TYPE** → add `valid_depth_min_m` /
   `valid_depth_max_m` to `metadata/measurement_type.csv`, mirroring
   `valid_min`/`valid_max`. `est_chlorophyll_a_*` gets `0` / `200`. Cheap,
   diffable, immediately usable by a rule ("a value outside the depth range over
   which its type is defined"), and emittable as a netCDF attribute.
   Also add a free-text **`derivation`** column recording *how* a derived type was
   produced ("regression of fluorometer voltage vs bottle chl-a, per-cast or
   per-cruise coefficients, 0–200 m") — that is provenance the registry has
   nowhere to put today.
2. **`_StaCorr` availability is a property of the CAST**, not the type (needs a
   500 m cast with ~10+ bottles). It does not belong in `measurement_type.csv`.
   Express it as a **completeness rule that knows the condition**, so a null on a
   qualifying cast is a finding and a null on a shallow/bottle-poor cast is not.

### D5. Question labelling and the registry convention (item 6)

**Recommendation:**

- Keep `id` (`calcofi_ctd-cast_15`) as the durable globally-unique key.
- Add a **`label`** column holding the short form (`Q15`), unique *within* a
  dataset. Render it as the first column so "Q15" in prose resolves.
- Standardise `status` to **`open` | `proposed` | `answered` | `wontfix`**
  — adding `proposed` is the point of item 5 below: a question with a solution we
  have already built, awaiting approval rather than an answer.
- Standardise `priority` to `blocker | high | normal | low` (fold `medium` into
  `normal`).
- Add **`proposed_answer`** — what we did or suggest, so the provider is approving
  a solution rather than being handed a problem.
- Propagate to **all 17 `questions.csv`**, `CLAUDE.md`, `.claude/skills/*` (the
  templates and the `generate-metadata` / `validate-ingest` skills), and the
  questions chunk in **all 16 ingest notebooks**.

### D6. Item 5 — pre-answer what we can across 136 questions

This is the largest single item and deserves its own pass. Method: for each
question, decide whether the repo can already *propose* an answer (from the data,
from the source documentation, or from work since it was written), and if so fill
`proposed_answer` + set `status = proposed`. Expect a meaningful fraction of the
53 `open/normal` to convert. Do the CTD set first — several are already answerable
from the documentation comb.

### D7. `obs_ctd_full` out of the db-schema core (item 11)

`app.js` already knows about `supplemental` (lines 542, 579) and chips it. The ask
is stronger: **exclude supplemental tables from the core schema view entirely** —
the ERD, the Tables list and the Columns list — with an opt-in toggle to show
them. Applies to `obs_ctd_full` and `mets_*` full. Confirm whether they should be
*hidden behind a toggle* (recommended) or *removed entirely* (loses discoverability
of a hosted product).

### D8. db-schema UI (item 12)

- Remove the Diagram→Tables navigation: mermaid emits clickable nodes and the
  click fires while panning/zooming. Fix by disabling node links in the ERD render
  rather than by intercepting clicks.
- Replace the Tables **search** with a **dropdown** (`#tables-filter`): too many
  tables reference each other in name/description for substring search to be
  useful. A `<select>` of table names that jumps to the entry.

---

## Part 3 — Sequencing

Ordered so each phase is releasable and nothing blocks on a long render.

**Phase 1 — schema + registry (no render).**
D1 `data_stage` (calcofi4db + arity test + ctd-cast); D4 `measurement_type.csv`
columns; D5 question-registry convention + `CLAUDE.md` + skills + all 17 CSVs +
all 16 notebooks; D2 Comment; fix `design_env-bio-consolidation.md` for
`obs_freq` → `obs_attribute`.

**Phase 2 — protocol document.**
Rename `qc_protocol.qmd` → **`ctd-cast_qa-qc-protocol.qmd`** (update
`calcofi:` `target_name`/`output`/`workflow_url`, the app's Rules-tab link, the
ingest cross-reference, and `scripts/build_workflows_index.R` output); add
`format: html + docx`; author the **mermaid workflow diagram** (raw CTD → thinned
`obs`) plus the explanatory opening that ties together the diagram, the rule sets,
the notebooks/scripts, the app and the provider questions. Re-render; prune the
old `_output/qc_protocol.*`.

**Phase 3 — QC additions (D3).**
Per-cast residual/offset rule from `btl_*` vs sensor; profile-span panel in the
app; decide whether to ingest span/DBcoeff/xmlcoeff (a new `ingest` step or a
`libs/` builder).

**Phase 4 — full rebuild + release.** ⚠️ multi-hour, outward-facing.
`CTD_FORCE_REBUILD=TRUE` + `targets::tar_make()` for every notebook, then
`release_database.qmd` → validate → freeze → upload → `test_release.qmd` →
promote `latest.txt`.
**Known blocker:** `tar_make()` is blocked for *every* target by
`target_name: ingest_sio_sio_pic-zooplankton` in `ingest_sio_pic-zooplankton.qmd`
— doubled `sio_` and a hyphen make it an invalid R symbol. Fix to
`ingest_sio_pic_zooplankton` first.

**Phase 5 — consumers.**
`db-schema` (D7 + D8, then it rebuilds on push); `ctd-qaqc` deploy on the server
**plus `calcofi4r` update there** — and note `ctd-qaqc` now also requires
`calcofi4db >= 3.3.0` in the `rstudio` container; `db-viz-hex` / `db-viz-cruise`
`prep_db.R` re-runs; `db-viz-station` `refresh.yml`.

---

## Verification

- `devtools::test()` in `calcofi4db` — including the new `append_sample()` arity test.
- Both `apps/ctd-qaqc/tests/*.R` still pass.
- The protocol build guard still fails on an undocumented rule.
- Every ingest notebook renders; the release passes `test_release.qmd`'s
  consumer-contract suite **before** `latest.txt` is promoted.
- After deploy: `db-schema` shows no `obs_ctd_full` in the core view; the app's
  Rules tab links to the renamed protocol.

## Gotchas carried forward

- Editing a `.qmd` does **not** make its target outdated — `tar_invalidate()` first.
- `tar_make()` takes a tidyselect expression: `tar_make(names = tidyselect::all_of(t))`.
- `mermaid-format: png` is disabled project-wide and must stay that way.
- The ingest's input fingerprint hashes only inputs that can change **outputs** —
  `measurement_qual.csv` was deliberately removed from it.
- A fast-path render of `ingest_calcofi_ctd-cast.qmd` produces a **hollow** HTML
  (no ERD, previews, diagnostics); do not commit it. Phase 4's full render is what
  should be published.
