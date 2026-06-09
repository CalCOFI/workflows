# Schema Site: YAML-Authoritative Relationships, Coloring, Contributions & Tag Filtering

## Context

The schema documentation site (`schema/`, rendered at https://calcofi.io/schema) is a static
Jekyll + vanilla-JS app that fetches per-release sidecars from GCS
(`metadata.json`, `catalog.json`, `relationships.json`, `erd.mmd`) and renders five tabs
(ERD, Tables, Columns, Datasets, Measurements). Today:

- The **ERD has many orphaned tables** (no FK edges) and no indication of dataset source.
  Color coding exists only in `release_database.qmd` as a **hard-coded 7-group list** that
  uses busy alternating-row `fill`.
- The **Datasets tab** lists datasets but not which tables each contributes, nor row/percentage
  splits for shared tables, nor links to the generating workflow.
- Provider/dataset **pill tags in Tables are not clickable** and not reused for filtering.
- Dataset→table→workflow provenance is scattered across `metadata/dataset.csv`, R setup chunks,
  and per-ingest sidecars rather than a single authoritative source.

Goal: make the ingest `*.qmd` YAML the **authoritative** source for dataset metadata, table
ownership, workflow links, and ERD colors; enrich the release sidecars with relationships,
per-dataset row contributions, and workflow links; and upgrade the site with dataset-colored
ERD (subtle stroke), a Datasets-tab contribution view, and a global clickable tag filter that
works across Datasets/Tables/Columns/Measurements.

User decisions (authoritative): ERD **color by dataset** (`provider_dataset`), derived from
metadata with optional YAML color + per-table overrides, **stroke not fill**; Datasets tab shows
**row counts + % per dataset**; **YAML authoritative for everything** (deprecate `dataset.csv`);
full plan across all three layers.

## Key facts grounding the design

- Per-ingest `metadata.json` **already has** `provider`, `dataset`, `workflow` (rendered HTML URL),
  `tables`, `columns` (`calcofi4db/R/wrangle.R::build_metadata_json` ~L1577). But
  `merge_metadata_json` (~L2032) **drops the `workflow` field** and builds `datasets` from
  `dataset.csv` (~L2141).
- Release `catalog.json` has per-table `rows` + `total_rows` (site already loads it).
- `cc_erd()` (`calcofi4r/R/erd.R` L92) takes `colors` (named list color→tables) and emits
  `classDef <cls> fill:<hex>,stroke:<darkened>` + `class <tbls> <cls>` (L237–250). An unused
  `.erd_build_color_map()` helper exists (L357).
- `release_database.qmd` hard-codes `colors` in **two** `cc_erd` calls (L414–428, L482–494) and
  `cross_fks` (L463–469); calls `merge_metadata_json(..., dataset_csv=...)` (~L730).
- `app.js` (`schema/app.js`): `State` is global; renders are independent; `relationships.json`
  is fetched (L139) but **never used**; chips are static `<span>` (L323–324); per-tab text filter
  only (L349). No shared filter state.

## Critical files

- `calcofi4db/R/wrangle.R` — `build_metadata_json` (~L1577), `merge_metadata_json` (~L2032); new `read_ingest_yaml()`
- `calcofi4r/R/erd.R` — `cc_erd` colors block (L237–250); new `cc_erd_color_map()`
- `workflows/release_database.qmd` — colors L414–494, cross_fks L463–469, merge call ~L730
- `workflows/ingest_calcofi_bottle.qmd` (+ `_ctd-cast`, `_dic`, `_swfsc_ichthyo`) — YAML block, `*_rels` FK lists, `build_metadata_json` call (~L1200)
- `schema/app.js`, `schema/index.html`, `schema/style.css` — filter bar, clickable chips, contribution + ERD legend rendering

---

## 1. Extended `calcofi:` YAML block (authoritative)

Add to each `ingest_*.qmd` YAML, keeping existing keys (`target_name`, `workflow_type`,
`dependency`, `output`, `modifies`) untouched. Example for bottle:

```yaml
calcofi:
  target_name: ingest_calcofi_bottle
  workflow_type: ingest
  dependency: [ingest_swfsc_ichthyo]
  output: data/parquet/calcofi_bottle/manifest.json
  modifies: [ship]
  # --- NEW: identity (moved out of R setup chunk) ---
  provider: calcofi
  dataset: bottle
  workflow_url: https://calcofi.io/workflows/ingest_calcofi_bottle.html
  # --- NEW: dataset metadata (same keys merge_metadata_json reads from dataset.csv today) ---
  dataset_meta:
    dataset_name: CalCOFI Bottle Database
    description: >
      Hydrographic bottle data: temperature, salinity, oxygen, nutrients, pigments, C14.
    citation_main: "..."
    link_calcofi_org: https://calcofi.org/data/oceanographic-data/bottle-database/
    link_data_source: https://...
    coverage_temporal: "1949-03 to 2021-05"
    coverage_spatial: "23-51°N, -170 to -117°W"
    license: ""
    pi_names: ""
  # --- NEW: tables this ingest OWNS (replaces dataset.csv `tables` column) ---
  tables_owned:
    - { table: casts }
    - { table: bottle }
    - { table: bottle_measurement }
    - { table: cast_condition }
    - { table: measurement_type, shared: true, note: "shared registry across bottle/ctd/dic" }
  # --- NEW: ERD color (optional; release may override) ---
  erd:
    color: "#cfe3f7"
    overrides: { measurement_type: "#e0e0e0" }
```

Read at release time with `rmarkdown::yaml_front_matter(qmd_path)$calcofi` (handles the fenced
block + `>` scalars). New `calcofi4db::read_ingest_yaml(workflow_dir)` globs `ingest_*.qmd` and
returns a list keyed by `provider_dataset`.

**ichthyo carries two datasets** (ichthyo + the folded-in `swfsc_invert`): allow `dataset_meta`
to be a list of dataset blocks, or add a small secondary block — resolve during implementation.

## 2. Per-dataset row contribution

Each ingest's DuckDB (`con`) contains only its own rows, so per-table `COUNT(*)` gives a clean
per-dataset contribution even for shared tables.

- **`build_metadata_json`** (add params `tables_owned`, `emit_contributions=TRUE`): emit a
  `contributions` block in per-ingest metadata.json: `{ table: { rows, owned, shared } }`.
- **`merge_metadata_json`** aggregates into a release-level `contributions` key, attaching the
  `workflow` link per contributor and computing `pct` against the release-final row count
  (passed via new `table_rows` param from freeze stats):

```jsonc
"contributions": {
  "measurement_type": {
    "total_rows": 108,
    "over_attributed": true,            // set when sum(by_dataset.rows) > total_rows (dedup)
    "by_dataset": [
      { "provider_dataset": "calcofi_bottle", "rows": 42, "pct": 38.9,
        "workflow": "https://calcofi.io/workflows/ingest_calcofi_bottle.html" },
      { "provider_dataset": "calcofi_ctd-cast", "rows": 35, "pct": 32.4, "workflow": "..." }
    ]
  },
  "casts": { "total_rows": 35234, "by_dataset": [ { "provider_dataset": "calcofi_bottle",
             "rows": 35234, "pct": 100.0, "workflow": "..." } ] }
}
```

Single-owner tables get a one-element `by_dataset` (uniform shape for the site). Cross-check
`measurement_type` per-ingest counts against `_source_datasets` in `measurement_type.csv`; warn on
drift. `pct` is computed at release time so the site stays dumb.

## 3. R package changes

**`calcofi4r/R/erd.R`**
- `cc_erd` colors block: emit **stroke-only** — `classDef <cls> stroke:<hex>,stroke-width:3px`
  (drop `fill:`), using the dataset color directly as the outline. Keep `.erd_darken` as fallback.
- New exported `cc_erd_color_map(table_dataset, dataset_colors, overrides=NULL, neutral="#d0d0d0")`:
  single-owner table → its dataset color; `shared`/multi-owner → neutral; `overrides` win; returns
  the `list(color = c(tables...))` shape `cc_erd(colors=)` expects. Generalizes `.erd_build_color_map`.
- Snapshot test: classDef contains `stroke:` and not `fill:`.

**`calcofi4db/R/wrangle.R`**
- New `read_ingest_yaml(workflow_dir)`.
- `build_metadata_json`: add `tables_owned`/`emit_contributions`, emit `contributions`
  (`COUNT(*)` per table); optionally stamp `workflow` onto each table entry too; warn if
  `tables_owned` ≠ `dbListTables(con)`. Backward compat: NULL `tables_owned` ⇒ all owned.
- `merge_metadata_json`: (a) build `datasets` from `ingest_yaml[[k]]$dataset_meta` (new
  `ingest_yaml` param; keep `dataset_csv` as deprecated fallback, YAML wins, warn on drift);
  (b) **propagate `workflow` per table** (fix L2059–2065); (c) aggregate `contributions`
  (new `table_rows` param for denominators); (d) bump `schema_version` to `"1.2"`; optionally
  write `erd_legend` (dataset→color). All new fields additive.

## 4. `release_database.qmd` changes

- Load `ingest_yaml <- read_ingest_yaml(here())` in setup.
- Replace both hard-coded `colors` lists with
  `cc_erd_color_map(tbl_ds_map, dataset_colors=map(ingest_yaml, ~.x$erd$color),
  overrides=c(yaml_overrides, release_overrides), neutral="#d8d8d8")`. `release_overrides` is a
  small inline list here for common tables (`dataset`, `measurement_type`, `_spatial`, `cruise`, `ship`).
- Move `cross_fks` into this file's own `calcofi:` YAML block (`cross_fks:`) read via
  `yaml_front_matter`; **extend** so currently-orphaned tables get edges (genuinely cross-dataset
  ones only — intra-dataset FKs belong in each ingest's `*_rels`).
- `merge_metadata_json` call: pass `ingest_yaml`, `table_rows` (from freeze stats); drop/keep
  `dataset_csv` as fallback.
- **Ask A intra-dataset edges**: extend each ingest's `*_rels` foreign_keys (e.g. site→cruise,
  tow→site, net→tow, dic_sample→casts, ctd_cast→cruise/ship/site) — only where referential
  integrity holds (the validate chunk flags orphans; do not draw edges the data violates).
- Re-running this notebook regenerates GCS sidecars for the new release.

## 5. Frontend (`schema/`)

- **Global filter state**: `State.filters = new Set()` (active `provider_dataset` tags) + new
  `applyFilters()` that show/hides the current tab's nodes by `data-dataset(s)` (OR across
  selected tags), composed with existing text search. Re-applied on tab switch in
  `renderActiveTab`.
- **Filter bar** (`index.html` + `style.css`): persistent chip bar `#global-filter-bar` above the
  tab panels, populated from `meta.datasets` keys; each `class="chip filter-chip" data-dataset=...`
  toggles membership + `.active`; add a "clear" chip. Colored left-border from `erd_legend` color.
- **`renderTables`**: chips become `class="chip filter-chip" data-dataset="${prov}_${ds}"`; card
  tagged `data-datasets`; fold `#tables-filter` into `applyFilters`.
- **`renderColumns`**: derive each column's dataset from `meta.tables[table]`; tag `<tr data-dataset>`.
- **`renderMeasurements`**: tag rows `data-datasets` from `contributions[mt].by_dataset[].provider_dataset`.
- **`renderDatasets`**: add a **Tables** section per card listing contributed tables with rows,
  `% from this dataset` for shared tables, and workflow link(s) (from `contributions`/`tables_owned`).
- **`renderErd`**: colors already baked into `erd.mmd` (no JS change for coloring); add an
  `#erd-legend` (dataset→swatch) rendered from `meta.erd_legend`.
- **Backward compat (critical)**: read every new field defensively (`meta.contributions || {}`,
  `meta.erd_legend || []`, `t.workflow` optional). Old releases render as today; chips still filter
  off `provider`/`dataset` present in all existing metadata.json.

## 6. Sequencing

1. calcofi4db: `read_ingest_yaml`; extend `build_metadata_json`; fix `merge_metadata_json`.
2. calcofi4r: stroke-only `cc_erd`; `cc_erd_color_map`. (Unit-testable immediately.)
3. ingest `*.qmd`: add extended YAML; switch R chunks to read provider/dataset from YAML; extend
   `*_rels` FKs; pass `tables_owned`. **Re-run all 4 ingests** → new per-ingest sidecars.
4. release_database.qmd: YAML-driven colors + cross_fks; pass `ingest_yaml`/`table_rows`.
   **Re-run** → regenerates GCS sidecars (metadata.json, relationships.json, erd.mmd, catalog.json).
5. schema/ frontend: filter state/bar, clickable chips, contribution + legend rendering; deploy.

Frontend-only changes (filter bar, clickable chips off existing fields) deploy without regen;
contribution %/workflow rows + recolored/edged ERD require the regenerated sidecars (step 4).

## 7. Risks & open questions

- **Old-release compatibility** (top priority): additive JSON keys + defensive JS; do not
  re-render historical versions. Verify by loading an old version from the dropdown.
- **Deprecate vs delete `dataset.csv`**: keep as `merge_metadata_json` fallback during transition;
  grep the wider org (Shiny app, calcofi4r) for other readers before removing. Don't auto-generate it.
- **Mermaid 11.4.1 stroke-only**: verify `classDef stroke:#hex,stroke-width:3px` (no fill) styles
  the ER entity box border; fallback to a low-alpha tinted fill if it doesn't apply.
- **Shared-table attribution**: per-ingest counts can sum > deduped release total → divide by
  `total_rows`, set `over_attributed`, reconcile against `_source_datasets`.
- **FK edges are data-correctness work**: only add FKs whose referential integrity holds.
- **Multi-dataset filter**: tables like `measurement_type` need `data-datasets` (list) + ANY-match.
- **swfsc_invert**: not one of the 4 ingest YAMLs (folded into ichthyo) — decide where its
  `dataset_meta` lives.

## 8. Verification

- **R**: unit test `read_ingest_yaml` (4 qmds), `cc_erd_color_map` (owned/shared/override),
  `cc_erd` snapshot (stroke not fill); `devtools::test()` both packages.
- **Release**: render `release_database.qmd` to a temp `data/releases/vTEST/` with the GCS-upload
  chunk disabled; inspect `metadata.json` for `contributions`, per-table `workflow`, `erd_legend`;
  inspect `erd.mmd` for stroke classDefs + new FK edges; reconcile `by_dataset.rows` vs `total_rows`.
- **Frontend**: `cd schema && bundle exec jekyll serve` with `SCHEMA_GCS_BASE` pointed at the test
  release. Check: ERD colored outlines + legend + previously-orphaned tables now edged; click
  chips filter Tables (OR union, composes with text, clear resets); filter persists switching to
  Columns/Measurements/Datasets; Datasets tab shows table rows/% + working workflow links; an
  OLD version still renders (regression check).
