---
description: Scaffold a publish workflow for OBIS, ERDDAP, or EDI from CalCOFI data
user_invocable: true
---

# /publish-template

Scaffold a new `publish_{dataset}_to_{portal}.qmd` Quarto notebook for publishing CalCOFI data to an external portal.

## Usage

```
/publish-template {dataset} {portal} [--source-ingest={ingest}]
```

## Arguments

- `dataset`: Dataset or subset identifier (e.g., `ichthyo-cephalopods`, `ctd`, `bottle`, `dic`, `zooplankton`, `seabird`, `mammals`)
- `portal`: Target portal (`obis`, `erddap`, or `edi`)

## Options

- `--source-ingest={ingest}`: Source ingest workflow that provides the data (e.g., `swfsc_ichthyo`, `calcofi_bottle`)

## Instructions

When the user invokes this skill:

### 1. Determine template

Select the appropriate template based on `{portal}`:

- **OBIS** → `.claude/skills/templates/publish_obis_template.qmd`
- **ERDDAP** → `.claude/skills/templates/publish_erddap_template.qmd`
- **EDI** → `.claude/skills/templates/publish_edi_template.qmd`

### 2. Read template and customize

Key substitutions:
- `{{dataset}}` → dataset identifier
- `{{dataset_name}}` → human-readable name
- `{{portal}}` → target portal
- `{{source_ingest}}` → source ingest workflow (e.g., `swfsc_ichthyo`)
- `{{source_parquet_dir}}` → path to source parquet (e.g., `data/parquet/swfsc_ichthyo`)

### 3. Generate the notebook

Write the customized notebook to:
```
publish_{dataset}_to_{portal}.qmd
```

### 4. Portal-specific sections

#### OBIS (Darwin Core Archive)
Following the pattern from `publish_ichthyo_to_obis.qmd`:

1. **Overview** — Dataset, target, DwC mapping
2. **Setup** — Libraries, paths
3. **Load source data** — From release parquet or ingest parquet
4. **Event hierarchy** — Design cruise → station → sample events
5. **Build Event table** — eventID, parentEventID, eventDate, decimalLatitude, decimalLongitude
6. **Build Occurrence table** — occurrenceID, eventID, scientificName, AphiaID, occurrenceStatus
7. **Build ExtendedMeasurementOrFact** — measurementType, measurementValue, measurementUnit (NERC P01/P06)
8. **Write DwC-A files** — event.csv, occurrence.csv, emof.csv
9. **Create meta.xml** — Column-to-DwC term mapping
10. **Create EML metadata** — Title, abstract, contacts, geographic/temporal coverage
11. **Data quality checks** — Event hierarchy, orphan occurrences, summary stats
12. **Package archive** — Zip as DwC-A
13. **Validate with obistools** — `check_eventids()`, `check_fields()`
14. **Upload to GCS**

#### ERDDAP (NCCSV)
1. **Overview** — Dataset, ERDDAP server target
2. **Setup** — Libraries, paths
3. **Load source data** — From release parquet
4. **Subset/filter** — Extract target subset (e.g., cephalopods from ichthyo)
5. **Format for ERDDAP** — Column naming, units, missing values
6. **Generate NCCSV metadata** — Global attributes (title, summary, institution, license, etc.)
7. **Generate variable attributes** — Per-variable: long_name, units, standard_name (CF conventions)
8. **Write NCCSV file** — Header + data in NCCSV format
9. **Generate datasets.xml snippet** — For ERDDAP admin to add to server config
10. **Validate** — Check CF standard names, coordinate conventions, time format
11. **Upload to GCS**

#### EDI (EML + Data Package)
1. **Overview** — Dataset, EDI scope and identifier
2. **Setup** — Libraries, paths, EDI credentials
3. **Load source data** — From release parquet
4. **Prepare data tables** — Clean for distribution (CSV format, UTF-8)
5. **Build EML metadata** — Using `EML` R package or `EMLassemblyline`:
   - Title, abstract, keywords
   - Creator, contact, associated parties
   - Geographic coverage (bounding box)
   - Temporal coverage (begin/end dates)
   - Taxonomic coverage (species list)
   - Methods (sampling, processing)
   - Data table descriptions (columns, types, units)
   - Intellectual rights (CC-BY or CC0)
6. **Validate EML** — `EML::eml_validate()`
7. **Create data package** — Zip data + EML
8. **Upload to EDI staging** — Via EDI API (optional)
9. **Upload to GCS**

### 5. Update `_targets.R`

Add the publish target after `release_database`:

```r
tar_target(
  publish_{dataset_snake}_to_{portal},
  {
    quarto::quarto_render(
      here("publish_{dataset}_to_{portal}.qmd"),
      output_file = here("_output/publish_{dataset}_to_{portal}.html"))
    Sys.glob(here("data/{output_format}/{dataset}_*.{ext}"))
  },
  format = "file"
)
```

### 6. Present results

Show the user:
- Created file path
- Section outline with TODO markers
- Portal-specific metadata fields to fill
- Target `_targets.R` entry
- Next steps:
  1. Fill in portal-specific metadata (contacts, abstract, etc.)
  2. Customize data subsetting/filtering
  3. Run the notebook to test
  4. Submit to portal
