---
description: Profile a new CSV or ERDDAP dataset before ingestion into the CalCOFI database
user_invocable: true
---

# /explore-dataset

Profile a new dataset to understand its structure, coverage, and compatibility with the CalCOFI database before ingestion.

## Usage

```
/explore-dataset {csv_path_or_directory}
```

## Arguments

- `csv_path_or_directory`: Path to a CSV file, directory of CSVs, or ERDDAP URL to profile

## Instructions

When the user invokes this skill, run the R script `scripts/explore_dataset.R` against the provided data source. Follow these steps:

1. **Determine data source type**:
   - If a local CSV file or directory: use directly
   - If an ERDDAP URL: download a sample first using `rerddap` or `curl`
   - If a Google Drive path: ensure it's accessible via `~/My Drive/...`

2. **Run the profiling script**:
   ```bash
   Rscript scripts/explore_dataset.R "{csv_path_or_directory}"
   ```

3. **Review the output** and present a structured summary to the user covering:
   - Table/file inventory (names, row counts, column counts)
   - Column types and NULL rates
   - Potential primary key columns (unique identifiers)
   - Foreign key candidates matching existing CalCOFI tables:
     - `cruise_key` (YYYY-MM-NODC format)
     - `ship_key`, `ship_nodc`, `ship_name`
     - `site_uuid`, `tow_uuid`, `net_uuid`
     - `cast_id`, `bottle_id`
     - `species_id`, `sppcode`
     - `grid_key` (line_station format)
   - Spatial coverage (lat/lon ranges vs CalCOFI grid extent ~23-51°N, ~-135 to -117°W)
   - Temporal coverage (date ranges, overlap with existing cruises 1949-present)
   - Species columns (if present) and match rate against existing species table
   - Measurement columns that could map to `measurement_type.csv`
   - Data quality flags (duplicates, outliers, encoding issues)

4. **Scrape CalCOFI.org landing page**:
   - Use `WebFetch` on the CalCOFI.org page for the dataset (e.g.,
     `https://calcofi.org/data/oceanographic-data/{dataset}/`) to check
     for updated data, download links, methodology notes, and citations.
   - If not available, check the data portal landing page (NCEI, EDI, ERDDAP).
   - Extract: citation, DOI, PI names, temporal/spatial coverage, license.

5. **Determine provider**:
   - The `provider` is the **organization curating the data**, not the
     data portal where it's hosted. For example:
     - Data from CalCOFI → `provider = "calcofi"` (even if hosted on NCEI or EDI)
     - Data from SWFSC → `provider = "swfsc"`
     - Data from SIO/PIC → `provider = "pic"`
   - The data portal (NCEI, EDI, ERDDAP) is recorded in `link_data_source`
     in the `dataset` metadata table, not in the provider name.

6. **Generate recommendations**:
   - Suggest whether this is an **ingest** (new data) or **publish** (subset of existing data)
   - Recommend table naming following `{dataset}_{table}` convention
   - Identify which existing tables to join against
   - Flag any data cleaning needed before ingestion
   - Estimate complexity (Low/Medium/High) based on:
     - Number of source tables
     - Need for pivoting (wide → long)
     - Taxonomy standardization needed
     - Spatial matching complexity

7. **Output**: Display the markdown report directly in the conversation.

## Example Output

```markdown
## Dataset Profile: DIC measurements

### Source Files
| File | Rows | Cols | Size |
|------|------|------|------|
| CalCOFI_DIC_data.csv | 12,345 | 15 | 487KB |

### Key Columns
- **PK candidates**: cast_id (integer, unique per row)
- **FK matches**: cast_id → casts.cast_id (98.7% match rate)
- **Spatial**: Lat_Dec (32.5-34.8°N), Lon_Dec (-121.3 to -117.3°W) — within CalCOFI grid
- **Temporal**: 2008-2021 (overlap with existing cruises: 95%)

### Measurement Columns
- DIC (µmol/kg) — add to measurement_type.csv
- TA (µmol/kg) — add as "alkalinity"
- pH_measured — add to measurement_type.csv

### Recommendation
- **Type**: Ingest (merge into bottle_measurement)
- **Complexity**: Low
- **Join strategy**: cast_id + bottle_id → existing bottle table
- **Next step**: `/generate-metadata ncei dic`
```
