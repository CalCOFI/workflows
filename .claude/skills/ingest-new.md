---
description: Scaffold a new CalCOFI dataset ingest workflow from template
user_invocable: true
---

# /ingest-new

Scaffold a new `ingest_{provider}_{dataset}.qmd` Quarto notebook from the production ingest template, customized for the target dataset.

## Usage

```
/ingest-new {provider} {dataset} [--options]
```

## Arguments

- `provider`: Data provider identifier (e.g., `ncei`, `edi`, `pic`, `swfsc`, `calcofi`, `sccoos`)
- `dataset`: Dataset identifier (e.g., `dic`, `euphausiids`, `zooplankton`)

## Options

- `--has-taxonomy`: Include taxonomy standardization sections (species table, WoRMS/ITIS matching)
- `--has-pivot`: Include wide→long measurement pivoting sections
- `--merge-into={table}`: Merge into existing table instead of creating new (e.g., `bottle_measurement`)
- `--depends-on={prior_ingest}`: Declare dependency on prior ingest (e.g., `swfsc_ichthyo`)

## Instructions

When the user invokes this skill:

### 1. Verify prerequisites

Check that metadata files exist:
```bash
ls metadata/{provider}/{dataset}/tbls_redefine.csv metadata/{provider}/{dataset}/flds_redefine.csv
```

If not found, suggest running `/generate-metadata {provider} {dataset}` first.

### 2. Read template and customize

Read the ingest template from `.claude/skills/templates/ingest_template.qmd` and customize it with the provided parameters.

Key substitutions:
- `{{provider}}` → provider value
- `{{dataset}}` → dataset value
- `{{dataset_name}}` → human-readable name (derive from dataset or ask user)
- `{{dir_label}}` → `{provider}_{dataset}`
- `{{depends_on}}` → prior ingest dependency (default: `swfsc_ichthyo` for shared tables)

### 3. Determine ingest pattern

Based on the dataset characteristics (from `/explore-dataset` output or user input), select the appropriate pattern:

**Pattern A: Standalone ingest** (like ichthyo)
- Creates its own tables with dataset-prefixed names
- Generates own PKs (sequential or UUID)
- Full spatial/grid assignment
- Example: euphausiids, zooplankton

**Pattern B: Merge into existing table** (like DIC → bottle_measurement)
- Appends rows to an existing table
- Uses existing PKs from the target table
- Joins via FK to existing casts/bottles
- Example: DIC measurements → bottle_measurement

**Pattern C: Multi-source ingest** (like phytoplankton)
- Reads from multiple source formats (CSV, API, etc.)
- Requires source reconciliation
- Complex taxonomy mapping
- Example: phytoplankton from DataZoo + EDI

### 4. Generate the notebook

Write the customized notebook to:
```
ingest_{provider}_{dataset}.qmd
```

The notebook includes these sections (customize based on pattern):

#### Universal sections (always included):
1. **YAML frontmatter** — title, editor options
2. **Overview** — Dataset description, source, Mermaid data flow diagram
3. **Setup** — Libraries, paths, DuckDB initialization
4. **Read source data** — `read_csv_files()` or custom reader
5. **Check data integrity** — `check_data_integrity()`, `render_integrity_message()`
6. **Show source files** — `show_source_files()`
7. **Show tables/fields** — Redefinition display
8. **Load into database** — `ingest_dataset()` or custom load
9. **Schema documentation** — dm visualization
10. **Validate** — `validate_for_release()`
11. **Enforce column types** — `enforce_column_types()`
12. **Data preview** — `preview_tables()`
13. **Write parquet** — `write_parquet_outputs()`
14. **Write metadata** — `build_metadata_json()`, `build_relationships_json()`
15. **Upload to GCS** — `sync_to_gcs()`
16. **Cleanup** — Close DuckDB connection

#### Conditional sections:
- **Cross-dataset loading** — `load_prior_tables()` (if depends on prior ingest)
- **Primary key setup** — `assign_deterministic_uuids()` or `assign_sequential_ids()`
- **Pivot measurements** — Wide→long transformation (if `--has-pivot`)
- **Taxonomy** — `standardize_species_local()`, `build_taxon_hierarchy()` (if `--has-taxonomy`)
- **Spatial** — `add_point_geom()`, `assign_grid_key()` (if has lat/lon)
- **Lookup tables** — `create_lookup_table()` (if categorical vocabularies exist)
- **Ship/cruise matching** — `derive_cruise_key_on_casts()` (if cross-dataset bridge needed)

### 5. Mark dataset-specific sections

In the generated notebook, mark sections requiring manual implementation with:

```r
#| label: TODO-{section}
# TODO: implement dataset-specific logic here
# - {specific guidance based on dataset characteristics}
```

### 6. Update `_targets.R`

Add a new target entry for the ingest workflow:

```r
tar_target(
  ingest_{provider}_{dataset_snake},
  {
    quarto::quarto_render(
      here("ingest_{provider}_{dataset}.qmd"),
      output_file = here("_output/ingest_{provider}_{dataset}.html"))
    here("data/parquet/{provider}_{dataset}/manifest.json")
  },
  format = "file"
)
```

Insert it in the correct dependency order (after its `depends_on` target, before `release_database`).

### 7. Present results

Show the user:
- Created file path
- Section outline with TODO markers
- Dependencies added to `_targets.R`
- Next steps:
  1. Fill in TODO sections with dataset-specific transforms
  2. Run the notebook to test
  3. Run `/validate-ingest {provider} {dataset}` to verify
