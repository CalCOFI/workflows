# Refactor file paths to a shared data folder + run pipeline + host on GCS

## Context

The CA ocean-monitoring map has a 3-script R pipeline (`R/`) that builds GeoJSON/CSV
layers consumed by a static Leaflet app (`web/index.html`). Today the paths are
inconsistent and non-portable:

- `build_combine_map.R` and `build_discharger_layer.R` hardcode Windows paths
  (`C:/Users/bhuan/Downloads/...`) — unrunnable on this Mac.
- `build_program_layer.R` already uses `here()`/`glue()` but anchors inputs to
  `here("data")` / `here("outputs")`, neither of which exists in the repo.
- The real inputs live in the shared Google Drive folder
  `~/My Drive/projects/calcofi/data-public/_projects/ca-ocean-monitoring-map/`
  (9 category folders of raw CSVs).

Goal: one portable path convention rooted at that shared data folder (via
`here()` + `glue()`), runnable end-to-end, with built outputs served to the web
app from a public Google Cloud Storage bucket.

**Decisions from the user:**
- The 3 reference files are now **present** in the data folder — confirmed:
  `Attribute_Table.csv`, `ca_state/CA_State.shp` (+ sidecars), and
  `gebco_2025_n48.0_s30.0_w-130.0_e-110.0_geotiff.tif`. (`~/My Drive` is a symlink
  to `/Users/bbest/Library/CloudStorage/GoogleDrive-ben@ecoquants.com/My Drive`,
  so the `~/My Drive/...` data root resolves correctly.) The pipeline can run now.
- Layer mapping (one-per-category vs. other) is **TBD** — validate on a single
  small folder first once `Attribute_Table.csv` is present, then decide together.
- Built data layers will be **hosted on Google Cloud Storage**; the web app fetches
  from the bucket.

## Approach

### 1. Central path config — new `R/paths.R`

Single source of truth, sourced by all three scripts. Keep `library()` style to
match existing scripts (not `librarian::shelf`). Uses `here()` for repo paths and
`glue()` for everything derived from the data root.

```r
# R/paths.R — shared path config for the monitoring-map pipeline
library(here)
library(glue)

# raw input data root (shared Google Drive folder); override with env var
dir_data <- Sys.getenv(
  "CALCOFI_DATA",
  unset = "~/My Drive/projects/calcofi/data-public/_projects/ca-ocean-monitoring-map"
) |> path.expand()

dir_out <- here("outputs")   # built layers (synced to GCS)
dir_tmp <- here("tmp")
dir_web <- here("web")
dir.create(dir_out, showWarnings = FALSE, recursive = TRUE)
dir.create(dir_tmp, showWarnings = FALSE, recursive = TRUE)

# reference files (user adds these into dir_data)
attribute_table_path <- glue("{dir_data}/Attribute_Table.csv")
ca_boundary_path     <- glue("{dir_data}/ca_state/CA_State.shp")
gebco_raster_path    <- glue("{dir_data}/gebco_2025_n48.0_s30.0_w-130.0_e-110.0_geotiff.tif")
```

### 2. Refactor the three scripts to source it

- **`R/build_program_layer.R`** (lines ~31–54): replace the path block with
  `source(here::here("R/paths.R"))`. Set the per-run input folder from the data
  root, parameterized so we can target one category at a time, e.g.
  `program_folder <- glue("{dir_data}/{Sys.getenv('PROGRAM', 'eDNA')}")`.
  Keep the existing derived-path logic (`program_name`, `output_folder`) and the
  existing `file.exists()` guards for `ca_boundary_path` / `gebco_raster_path`.
- **`R/build_discharger_layer.R`** (lines 24–29): source `paths.R`;
  `discharger_folder <- glue("{dir_data}/Dischargers")`, `output_root <- dir_out`.
  Note: no `Dischargers/` folder exists in the data yet — guard so a missing
  folder is skipped cleanly instead of `stop()`-ing.
- **`R/build_combine_map.R`** (line 20): source `paths.R`; `output_root <- dir_out`.
  Internal `file.path(output_root, ...)` calls stay as-is.

All three keep using `file.path()` for joining dynamic, discovered paths
(`list.files`, per-chunk folders) — that's appropriate; `glue()` is for the
named, configured paths.

### 3. Web app — make the data source configurable (`web/index.html`)

Add one config constant near the top of the `<script>` (by line ~205) and prefix
the three data fetches with it:

```js
// '' = same folder as index.html (local). For GCS, set to the bucket base URL:
// 'https://storage.googleapis.com/<bucket>/'
const DATA_BASE = '';
```

- `DISCHARGER_SOURCES` path (line 206) → `fetch(DATA_BASE + src.path)` (line 376)
- `fetch('transects.csv')` (line 506) → `fetch(DATA_BASE + 'transects.csv')`
- `fetch('Master_Inventory.geojson')` (line 559) → `fetch(DATA_BASE + 'Master_Inventory.geojson')`

Local testing uses `DATA_BASE=''` with built artifacts copied next to
`index.html`; production sets it to the GCS bucket URL.

### 4. Run the pipeline

Reference files are in place, so this runs immediately. Per the "validate first"
decision:

1. `PROGRAM=eDNA Rscript R/build_program_layer.R` — smallest folder, confirms the
   CSV schema parses against `Attribute_Table.csv`. Inspect the output GeoJSON.
2. **Checkpoint with user** on layer mapping (treat each of the 9 category folders
   as one program layer, or group differently) before scaling to the rest.
3. Run `build_program_layer.R` for each chosen folder.
4. `Rscript R/build_discharger_layer.R` (skips if no `Dischargers/` folder).
5. `Rscript R/build_combine_map.R` → `outputs/Master_Inventory.geojson` +
   `outputs/transects.csv`.

### 5. Documentation

Update `README.md`: new `R/paths.R` convention, `CALCOFI_DATA` env override,
`PROGRAM` selection, the `outputs/` → GCS flow, and the hosting steps below.
Add `outputs/` to `.gitignore` (built artifacts live on GCS, not in git).

## Verification

- **Scripts run clean:** each `Rscript R/*.R` completes without error; confirm
  `outputs/Master_Inventory.geojson`, `outputs/transects.csv`, and (if present)
  `outputs/Dischargers/Dischargers.geojson` exist and are valid GeoJSON
  (`Rscript -e 'sf::st_read("outputs/Master_Inventory.geojson")'`).
- **Web app loads locally:** copy the 3 artifacts into `web/`, then
  `cd web && python3 -m http.server 8000`. `curl -sI` each asset for HTTP 200 and
  confirm the GeoJSON/CSV parse. Open `http://localhost:8000` in a browser and
  verify hex layer, transects toggle, and discharger toggle render (use the
  `verify` skill / screenshot if browser automation is available).
- **GCS path:** after `gsutil rsync`, set `DATA_BASE` to the bucket URL, reload,
  and confirm the same three layers load cross-origin (requires bucket CORS — see
  hosting).

## Hosting instructions (to add to README)

**Data on Google Cloud Storage (chosen):**
```bash
# one-time bucket setup (public-read static data)
gsutil mb -l us-west1 gs://calcofi-monitoring-map
gsutil iam ch allUsers:objectViewer gs://calcofi-monitoring-map
# CORS so the web app can fetch cross-origin
printf '[{"origin":["*"],"method":["GET"],"responseHeader":["Content-Type"],"maxAgeSeconds":3600}]' > cors.json
gsutil cors set cors.json gs://calcofi-monitoring-map
# publish built layers
gsutil -m rsync -r outputs/ gs://calcofi-monitoring-map/
```
Set `DATA_BASE = 'https://storage.googleapis.com/calcofi-monitoring-map/'` in
`web/index.html`.

**Static site — two options for `web/index.html`:**
- *GitHub Pages:* enable Pages on the repo, serve from `/web` (or move to `/docs`).
  Only `index.html` is committed; data comes from GCS via `DATA_BASE`.
- *Google VM:* copy `web/` to the VM and serve via nginx/Apache (or
  `python3 -m http.server` behind the existing reverse proxy); data via `DATA_BASE`.

## Critical files
- `R/paths.R` (new) — shared path config
- `R/build_program_layer.R` — lines ~31–54 path block
- `R/build_discharger_layer.R` — lines 24–29
- `R/build_combine_map.R` — line 20
- `web/index.html` — `DATA_BASE` + 3 fetch sites (lines ~205, 376, 506, 559)
- `README.md`, `.gitignore`
