# workflows

scripts to explore and load data into the CalCOFI database

## notebooks

See rendered notebooks at <https://calcofi.github.io/workflows/>.

## data pipeline

The CalCOFI data workflow uses the `targets` R package for dependency management and reproducibility.

### quick start

```r
# from the workflows/ directory
setwd("workflows")

# run the full pipeline
targets::tar_make()

# visualize the dependency graph
targets::tar_visnetwork()

# check which targets are outdated
targets::tar_outdated()
```

### pipeline architecture

```
Google Drive → rclone → GCS (calcofi-files) → targets → Parquet → DuckDB
                              ↓
                         archive/ (versioned)
```

**Key files:**
- `_targets.R` - pipeline definition
- `scripts/sync_gdrive_to_gcs.sh` - rclone sync with versioning
- `scripts/run_pipeline.R` - pipeline runner script

**GCS buckets:**
- `gs://calcofi-files/` - versioned source CSV files
- `gs://calcofi-db/` - Parquet files and DuckDB database

### rclone setup

1. install rclone: `brew install rclone`
2. configure remotes: `rclone config`
   - `gdrive`: Google Drive (readonly scope)
   - `gcs`: Google Cloud Storage (project: ucsd-sio-calcofi)
3. run sync: `./scripts/sync_gdrive_to_gcs.sh`

### R package functions

The `calcofi4db` package provides helper functions:

```r
# cloud operations
get_gcs_file("gs://calcofi-files/current/file.csv")
put_gcs_file("local.csv", "gs://calcofi-files/current/file.csv")
list_gcs_versions("path/to/file.csv")

# parquet operations
csv_to_parquet("data.csv", "output.parquet")
read_parquet_table("data.parquet")

# duckdb operations
con <- get_duckdb_con("calcofi.duckdb")
create_duckdb_from_parquet(parquet_files, "calcofi.duckdb")
```

See the full implementation plan at [README_PLAN.md](README_PLAN.md).
