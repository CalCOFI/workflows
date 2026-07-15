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

## deploy (release → consumers)

After a new release is frozen, uploaded, and promoted to `latest`, refresh the
read-only consumers. Details in [`CLAUDE.md`](CLAUDE.md#deploy-release--consumers)
and [`../server/README.md`](https://github.com/CalCOFI/server).

**Shiny apps** (`ssh calcofi`) — source at `/share/github/CalCOFI/{repo}`, served by
`shiny-server` in the `rstudio` container via `/srv/shiny-server/{app}` symlinks:

```bash
ssh calcofi
git -C /share/github/CalCOFI/calcofi4r  pull --ff-only   # prep_db.R load_all()s it
git -C /share/github/CalCOFI/db-viz-hex pull --ff-only
git -C /share/github/CalCOFI/apps       pull --ff-only
docker exec -d rstudio bash -lc 'cd /share/github/CalCOFI/db-viz-hex        && Rscript prep_db.R'
docker exec -d rstudio bash -lc 'cd /share/github/CalCOFI/apps/db-viz-cruise && Rscript prep_db.R TRUE'
touch /share/github/CalCOFI/db-viz-hex/app/restart.txt
touch /share/github/CalCOFI/apps/db-viz-cruise/restart.txt
```

`prep_db.R` rebuilds each app's local DuckDB from the release parquet (heavy — run
it backgrounded in the `rstudio` container). Runtime-reading apps (`apps/cruises`)
need only `git pull` + `restart.txt`.

**Static / hosted consumers** self-deploy: the station portal
(`2026-ucsb-station-data-portal`) rebuilds coverage JSON on release dispatch /
weekly (`gh workflow run refresh.yml --ref main`); `calcofi.io/query` + `/schema`
are GitHub Pages (rebuild on push); `calcofi4r` reads `latest` directly.

See the full implementation plan at [README_PLAN.md](README_PLAN.md).
