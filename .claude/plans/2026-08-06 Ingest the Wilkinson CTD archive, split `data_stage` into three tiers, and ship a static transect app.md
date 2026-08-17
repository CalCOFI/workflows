# Ingest the Wilkinson CTD archive, split `data_stage` into three tiers, and ship a static transect app

## Context

Rasmus asked for two things in the "data management plan…" thread (2026-08-05):

1. **Ingest the 2607 summer-cruise preliminary CTD this week**, so he can pull summer
   temperature from the database for a CCIEA meeting — and, if possible, against a
   **1993-2013 baseline** rather than 1998-2013.
2. **Interpolated visual products** worth serving publicly, pointing at Dan Rudnick's
   [CUGN climatology anomaly plots](https://spraydata.ucsd.edu/products/cugn-climatology/)
   as the model.

Both are blocked on the same gap. The released CTD **jumps 1998 → 2003**: calcofi.org
publishes 1 m-binned *Final* zips only for 1998 and 2003+, and raw `CTDCast`/`CTDTest`
zips before that. Jim Wilkinson's Drive folder
([11Xkcax…](https://drive.google.com/drive/folders/11Xkcax4zvdfjxKLf3gULsBWLGcsMH6sk))
holds the missing decade.

Three facts established while planning, which shape the whole approach:

- **The Wilkinson archive is the same product, not a variant.**
  `20-0302JD_CTDBTL_001-100D.csv` extracted from `20-0302JD_CTDFinalDB.zip` is
  **md5-identical** (`0f596ecf…`, 17,710,137 bytes) to calcofi.org's copy inside
  `20-0302JD_CTDFinalQC.zip`. The 1993 CSVs carry the **same 82 columns** as 2026's.
  So this is a coverage extension with no schema work and no reconciliation.
- **The lean `_CTDFinalDB.zip` set is what we want**: 111 cruises, **0.89 GB**, containing
  exactly the `*_CTDBTL_*.csv` files the ingest reads. The parallel `_CTDFinalQC.zip` set
  is 4.83 GB of processing intermediates and is not needed. Diffing cruise keys:
  **Wilkinson adds 45 finals calcofi.org lacks** (all of 1993–2002, plus 7 more 1998
  cruises); calcofi.org has 9 Wilkinson lacks (1902RL…2105SH). The sources are
  complementary — keep both.
- **`20-2607SH_CTDPrelim.zip` is already on GCS** (`_sync/calcofi/ctd-cast/download/`,
  synced 2026-07-28) and already primed to `dir_dl`. It is invisible purely because
  `d_zips` is built **only** from the calcofi.org scrape, so `download_and_unzip` never
  unzips it — and if it were unzipped, `stopifnot(length(cruises_csv_notzip) == 0)`
  (`ingest_calcofi_ctd-cast.qmd:550`) would abort the render.

That last point is the architectural fix that unlocks everything else: **the zip inventory
must be the union of the web scrape and the object-store listing**, not the scrape alone.
Once it is, 2607SH, the Wilkinson archive, and any future Drive-only drop all flow in
through one path.

Separately, the tier problem Ben raised on 2026-08-04 becomes urgent here. calcofi.org's
CTD Cast Files table names six categories, but each cruise offers a **single**
`_CTDPrelim.zip` replaced in place as processing advances — so the two preliminary tiers
are invisible from the filename. Verified by opening them:

| cruise | CSV inside `_CTDPrelim.zip` | tier |
|---|---|---|
| 2501RL, 2504SH | `db-csvs/…_CTDBTL_001-116D.csv` | bottle-merged |
| 2507SR, 2511SR, 2601RL, 2604SH, **2607SH** | `…_CTD_001-112D.csv` (top level) | sensor only |

`_CTDBTL_` vs `_CTD_` in the CSV filename is the discriminator. Content confirms it: in
`20-2604_CTD_001-112D.csv`, `Salt1`/`Salt2`/`Ox1`/`Ox2`/`Ox1uM` are **100 % populated**
while `Salt*_Corr`, `Ox*_StaCorr`, `SaltAve_Corr`, `EstChl_*` and all of `BTL_Depth…SIL`
are **0 %**. Because only the *corrected* forms are canonical, those five cruises — the
five most recent, including the one Rasmus needs — currently reach the release with
**no salinity and no oxygen at all**, and no error anywhere.

**Intended outcome:** CTD coverage continuous from **1993-08**, a three-tier `data_stage`
consumers can act on, salinity/oxygen present on sensor-only cruises, and a static
`ctd-transects` app that draws nearshore→offshore sections for any line × cruise with no
Shiny server and no station picking.

---

## Part 1 — Ingest (`ingest_calcofi_ctd-cast.qmd`)

### 1a. Make the zip inventory a union of scrape + object store

This is the enabling change; do it first. Today the chunk order is
`d_zips` (176) → `check_resume` (261) → `prime_zips_from_gcs` (387) → `download_and_unzip` (436).
The prime runs *after* the inventory is fixed and after the fingerprint is computed, so
primed-only zips can never be seen.

**Reorder to:** `prime_zips_from_gcs` → `d_zips` → `check_resume` → `download_and_unzip`.

Then build `d_zips` as two sources with one schema:

- `d_zips_web` — the existing scrape, unchanged (keep the `tryCatch` cache fallback and
  `write_csv(d, cache_csv)` to `metadata/calcofi/ctd-cast/ctd_zip_urls.csv`).
- `d_zips_local` — `list.files(dir_dl, pattern = "\\.zip$")`, anti-joined on `file_zip`
  against `d_zips_web` so only Drive/GCS-exclusive zips are added.

Add a `source` column (`"web"` | `"gcs"`). Reuse the existing `cruise_key` and `zip_type`
regexes verbatim — `19-9308NH_CTDFinalDB.zip` already yields `cruise_key = "9308NH"` and
`zip_type = "final"` under `str_detect(file_zip, "CTDFinal")`, so the
`stopifnot(!any(zip_type == "unknown"))` guard at line 224 stays satisfied with no edit.
Derive `year`/`month` **from the filename** for local rows only (`19-`/`20-` gives the
century, `YYMM` the rest); leave web rows on the existing URL-path derivation so no
current value changes.

Two consequential follow-ons:

- **`download_and_unzip` must not try to download a local-only row.** It keys off
  `basename(url)`; set `url = NA_character_` for `source == "gcs"` and return early from
  the download branch when `is.na(url)` (the file is already in `dest_dir` by
  construction). The unzip branch is unchanged.
- **The resume fingerprint must cover the new zips.** Line 287 hashes `sort(d_zips$url)`,
  which is `NA` for local rows. Change to
  `sort(paste(d_zips$source, d_zips$file_zip))`. This deliberately changes the hash and
  forces one full rebuild — which is what we want.

### 1b. Acquire the Wilkinson archive reproducibly

Per the repo convention that acquisition code is committed, not ad-hoc: add
**`scripts/sync_jrw_ctd_to_gcs.sh`**, modelled on `scripts/sync_gdrive_to_gcs.sh`.

```bash
# copies JRW's lean per-cruise final zips into the same prefix the ingest already primes
rclone copy gdrive-ecoquants: \
  --drive-root-folder-id 11Xkcax4zvdfjxKLf3gULsBWLGcsMH6sk \
  --include "*_CTDFinalDB.zip" --max-depth 1 \
  gcs-calcofi:calcofi-files-public/_sync/calcofi/ctd-cast/download/
```

Sync **all 111** (0.89 GB — the archive has value beyond the gap, and it answers the
"backfill calcofi.org so there is one online source" question in Ben's email). There is
**no filename collision**: calcofi.org publishes `_CTDFinalQC.zip`, never `_CTDFinalDB.zip`.
Do **not** sync `_CTDFinalQC.zip` (4.83 GB of intermediates the ingest never reads).

Also copy `DatabaseFilesReadMe.txt` (JRW, 07/11/2024) alongside as provenance.

### 1c. Gap-fill only — decide *in the notebook*, not at sync time

Archive completely; read selectively. After `d_zips` is assembled and before
`download_and_unzip`, drop `source == "gcs"` finals whose `cruise_key` already has a
`source == "web"` final. This avoids re-reading 66 cruises' CSVs on a ~1 hr heavy path
for byte-identical content, while leaving the archive complete on GCS.

Render the dropped set as a `dt()` table — do not truncate silently.

Add a cheap standing regression guard rather than trusting the one-off md5 check: unzip a
single overlapping cruise's `_CTDFinalDB.zip` to `tempdir()` and assert its top-level
`*_CTDBTL_*.csv` md5s match calcofi.org's `db_csv(s)/` copies. ~35 MB of I/O; it turns
"they were identical in August 2026" into an assertion that cannot silently rot.

### 1d. Three-tier `data_stage`

Rewrite the `case_when` at `ingest_calcofi_ctd-cast.qmd:504-517`. The `_CTDBTL_`/`_CTD_`
filename token is the discriminator; the archive folder gives final vs preliminary:

| rule | `data_stage` | `priority` |
|---|---|---|
| `Final.*db[_-]csvs?/` in `path_unzip` (calcofi.org `_CTDFinalQC`) | `final` | 1 |
| `dir_unzip` ends `CTDFinalDB` **and** CSV is at the archive top level (JRW) | `final` | 1 |
| `Prelim` dir **and** `_CTDBTL_` in `file_csv` | `preliminary_ctd_bottle` | 2 |
| `Prelim` dir **and** `_CTD_` in `file_csv` | `preliminary_ctd` | 3 |
| existing `2111SR` `csvs-plots` special case | `preliminary_ctd` | 3 |

The top-level restriction on the JRW arm matters: those zips also carry
`orig/`, `orig_dbcsvs/`, `SeparateRuns_Fl/`, `south-north/` subfolder copies of the same
casts. Excluding them explicitly is better than relying on the
`ORDER BY length("_source_file")` tiebreak in `dedup_ctd_raw` (line 1160) to pick the
right one by accident.

The precedence block at lines 533-543 (`group_by(cruise_key) |> min(priority)`) already
generalizes — only the `priority` mapping changes.

`2111SR`'s files are per-cast plot CSVs (`2111_08170435_072d.csv`), matching neither
token, so the hardcoded rule stays. **Add a content assertion** that makes the filename
classification self-checking and covers it: group `ctd_raw` by `data_stage` and assert
`preliminary_ctd` rows have **zero** non-null `salt1_corr`/`ox1_sta_corr`/`btl_depth`,
while `final` and `preliminary_ctd_bottle` have some. That catches a mis-named or
re-organized zip, which the filename rule alone cannot.

**Sites that hardcode the two-value vocabulary and must change:**

- line 2824-2827 — `stopifnot` on `data_stage NOT IN ('final','preliminary')`
- line 3791 — Gantt `colors <- c("final" = …, "preliminary" = …)`; add a third
- lines 3820-3830 — Gantt legend traces (`name = "Final"` / `"Preliminary"`)
- lines 3365-3373 — `findings_stage` query + caption
- `metadata/calcofi/ctd-cast/metadata_derived.csv` — the `ctd_cast,data_stage` description
  ("data processing stage: final or preliminary")
- `metadata/calcofi/ctd-cast/questions.csv` — **Q14** (`calcofi_ctd-cast_14`, status
  `proposed`, `related_field = data_stage`) asserts the two-value vocabulary; revise the
  proposed answer to the three tiers so Rasmus confirms the new one

`calcofi4db` needs **no change** — `sample.data_stage` is a free-form `VARCHAR` with no
`CHECK` constraint (`R/model.R:141`), and `append_sample()` already accepts it as the
optional 16th column (`R/model.R:259-294`), which the notebook already passes at line 2787.

### 1e. Restore salinity and oxygen on sensor-only cruises

Cheaper than expected: the uncorrected types **already exist** in
`metadata/measurement_type.csv` with `is_canonical = FALSE` —

`salinity_1` (`salt1`), `salinity_2` (`salt2`), `oxygen_ml_l_1` (`ox1`),
`oxygen_ml_l_2` (`ox2`), `oxygen_umol_kg_1` (`ox1u_m`), `oxygen_umol_kg_2` (`ox2u_m`)

— so they are already parsed into `ctd_measurement` and are excluded from `ctd_thin`/`obs`
only by the canonical filter. This is a **flag change, not new rows**.

Add it as decision #3 in **`libs/build_ctd_measurement_registry.R`**, which already does
exactly this kind of idempotent flag edit (its decision #1 flags the bottle-reference
group canonical) and already writes through `register_measurement_types()`. Set
`is_canonical = TRUE` for those six and give the four lacking bounds the same
`valid_min`/`valid_max` as their corrected siblings. Sharpen the `description` so the
distinction is legible to a consumer, e.g. `"Salinity sensor 1 (uncorrected)"`.

Cost: ~+1M rows on `obs` (against 20M) — and it means every cruise, not just sensor-only
ones, carries the raw sensor value, which is the correct outcome anyway.

### 1f. Metadata and coverage

- YAML `coverage_temporal: 1998-01 to 2026-04` → **`1993-08 to 2026-07`** (measure from
  the published `sample` shard after the run, as the existing comment instructs).
- `link_data_source` names only the calcofi.org page. Note the Drive archive as a second
  source — either in `description` or by extending the block, since the release's
  `dataset` table and the schema site both surface it.

### 1g. Run and validate

Editing a `.qmd` does **not** make its target outdated:

```r
targets::tar_invalidate(ingest_calcofi_ctd_cast)
Sys.setenv(CTD_FORCE_REBUILD = "TRUE")
eval(bquote(targets::tar_make(names = tidyselect::all_of(.("ingest_calcofi_ctd_cast")))))
```

Confirm the render actually happened by `_output/ingest_calcofi_ctd-cast.html` mtime —
never by exit code or an unchanged hash. Then re-render `release_database.qmd` (which
auto-discovers the shards; no `rels_paths` edit) and let `test_release.qmd`'s
consumer-contract suite gate promotion of `latest.txt`.

**Flag before running:** `obs_ctd_full` is 2.1 GB locally for 96 cruises; +45 cruises is
roughly **+1 GB** on a table already at 212M rows in the release. `BUILD_OBS_CTD_FULL=FALSE`
exists as an escape if the release size is a problem, but the default should stay `TRUE`.

---

## Part 2 — `ctd-transects` static app

A new repo **`CalCOFI/ctd-transects`**, structured on **`db-viz-station`** — the existing
static precedent: prebuilt JSON in `public/data/`, vanilla JS, GitHub Pages, data rebuilt
from the release by Actions.

**Blocker to design around:** the current release (v2026.08.06) **no longer contains
`ctd_thin`, `ctd_cast` or `ctd_summary`** — they consolidated into `obs` + `sample`.
`apps/ctd-viz/prep_db.R:141` hard-fails on this today. The new app reads `obs`, `sample`
and `grid` only.

### 2a. Transect definition — no station pickers

`apps/ctd-viz` defines its transect by **two clicks on a MapLibre map**, ordered by
`ord_occ` (ship-track order), with distance as cumulative haversine
(`server.R:293-311`, `server.R:466-479`). That is what makes it manual, and why the
direction is whichever way the ship steamed.

Derive it instead from line/station geometry, which is exactly the nearshore→offshore
ordering asked for:

- `sample.grid_key` is `st100-ln76.7`; join to release `grid.parquet` (218 rows) for
  `line`, `station`, `shore`, `zone`, `geom_ctr`.
- **Order by `station` ascending = nearshore → offshore** (`calcofi4r/R/data.R:175` sets
  `is_offshore = station > 60`; station 100 on line 76.7 sits at lon −124.3).
- Distance = cumulative haversine along that station order — a true cross-shelf transect,
  not a track.
- `ord_occ` is **null for roughly half** of `sample`'s cast rows in the release, so it
  cannot be the ordering key even if we wanted it.

Six core lines carry essentially every cruise: **93.3, 90, 86.7, 83.3, 80, 76.7**
(89–95 cruises each, 1,312–2,917 casts). Lines 60–73.3 exist for ~20–27 cruises and can be
offered but should not be the default.

### 2b. Build scripts → `public/data/`

`scripts/build_sections.sql`, run by the DuckDB CLI, resolving the release version from
`latest.txt` exactly as `db-viz-station/scripts/build_depth_profiles.sql` does — never
hardcode a release tag.

Dedupe cast direction with `QUALIFY row_number() … ORDER BY right(sample_key,1)='d' DESC`:
`obs` is already effectively one direction per cast (7,163 downcast vs 12 upcast samples
for `temperature_ave`; only 5 stations carry both).

Outputs:

- **`data/index.json`** — lines; cruises per line **sorted year-month descending**;
  per-(line, cruise) variable availability; `data_stage` per cruise; default = most recent.
- **`data/grid.json`** — the 218 grid stations with lon/lat and a **build-time GEBCO
  seafloor depth**, so the app never ships the 4.28 MB GeoTIFF that `ctd-viz` carries.
- **`data/sections/{line}__{cruise_key}.json`** — one shard per section.

**Shard shape — this is what keeps it small.** Pre-render each variable as a
**station × depth matrix** (5 m bins to 500 m), with an explicit non-uniform `x` array of
`dist_km`. Roughly 10 stations × 101 depths ≈ 1,010 numbers per variable, ~5 variables →
**~30 KB per shard**. Measured against the current parquet: **1,464,121 values across 555
shards, ~2,638 per shard, ~17 MB total** — growing to ~780 shards once the Wilkinson
cruises land. Lazily fetched one at a time, so first paint loads one shard.

Variables: `temperature_ave`, `salinity_ave_corr`, `oxygen_ml_l_ave_sta_corr`,
`sigma_theta_1`, `fluorescence_v` — plus the newly-canonical `salinity_1` /
`oxygen_ml_l_1` as the **uncorrected fallback** the app shows on `preliminary_ctd` cruises.

### 2c. Front end (`public/index.html`, `app.js`, `styles.css`)

- **Controls:** line dropdown, cruise dropdown (year-month descending, default newest),
  variable dropdown, max-depth. No start/end station inputs.
- **Section plot:** Plotly.js `heatmap` with `zsmooth: "best"` over the station × depth
  matrix, plus a `contour` overlay — this reproduces the ODV look of `ctd-viz`'s
  `MBA::mba.surf()` + `ggplotly` output (`global.R:189-364`) **with no interpolation code
  in the browser and no JS port of MBA**, which has none. Viridis fill, white contours,
  station guide lines and labels along the top, bathymetry as a clipped grey silhouette
  from the baked per-station depth.
- **Map** (the piece Rudnick's page lacks): MapLibre GL showing the CalCOFI grid, the
  selected line's stations highlighted in occupation order, the rest greyed — so a reader
  can see *where* the section is. Clicking a station selects the line.
- **Tier badge:** show `data_stage` for the selected cruise. On a `preliminary_ctd` cruise,
  disable the corrected variables and offer the uncorrected ones, labelled — so the
  absence is explained rather than silent. This is the case the default view hits today.
- Vendor Plotly and MapLibre locally; do not depend on a CDN.

### 2d. Deploy and register

- `.github/workflows/pages.yml` — Pages with **`build_type=workflow`** deploying `public/`.
  The legacy branch-source setting does not work here; this bit us on `db-viz-station`.
- `.github/workflows/refresh.yml` — weekly + `repository_dispatch` on release, rebuilding
  `public/data/` and stamping `data/version.json` with the release tag. `app.js` appends
  `?v=<release>` to every fetch (Pages serves `public/data/` with `max-age=600`).
  **Every built artifact must be in the `git add` list** — a `db-viz-station` regression.
- Wire `release_database.qmd`'s existing consumer-deploy step to dispatch this repo
  alongside `db-viz-station`.
- Register the slug **`ctd-transects`** consistently in all three places: `uptime/.upptimerc.yml`,
  `CalCOFI.github.io/_data/products.yml`, and the analytics slug.

### 2e. Natural follow-on (not built here)

Rasmus wants **anomalies** against a 1993-2013 baseline for CCIEA. Once Part 1 lands, the
baseline becomes computable for the first time. A per-(line, station, depth-bin, month,
variable) climatology is a small additional build-time table over the same query, and the
app can then toggle value ↔ anomaly with a diverging scale. Worth scoping separately.

---

## Verification

**Part 1**

1. `20-2607SH_CTDPrelim.zip` appears in `d_zips` with `source = "gcs"`, `zip_type = "preliminary"`,
   and 2607SH shows up in the "Files to Ingest" table as `preliminary_ctd`.
2. `stopifnot(length(cruises_csv_notzip) == 0)` passes — the union inventory is what makes it.
3. Cruise count rises from 96 to ~141; `SELECT min(datetime) FROM sample` returns **1993-08**,
   and 1999, 2000, 2001, 2002 are all non-empty.
4. `SELECT data_stage, count(*) FROM sample GROUP BY 1` returns exactly the three new values
   and no NULLs; the guard at 2824 passes.
5. The content assertion holds: `preliminary_ctd` rows have zero non-null
   `salt1_corr`/`ox1_sta_corr`/`btl_depth`; the other two tiers have some.
6. The overlap md5 guard passes for the spot-checked cruise.
7. `salinity_1` and `oxygen_ml_l_1` appear in `obs` for 2604SH/2607SH — the case that
   returns nothing today.
8. `_output/ingest_calcofi_ctd-cast.html` mtime is new (not an exit code, not a hash).
9. `release_database.qmd` re-renders; `test_release.qmd`'s contract suite passes before
   `latest.txt` is promoted.

**Part 2**

10. `duckdb -c ".read scripts/build_sections.sql"` writes `index.json`, `grid.json` and the
    `sections/` shards; total under ~25 MB; each shard's stations ascend nearshore→offshore.
11. Serve `public/` locally; the app opens on the newest cruise with a drawn section and no
    console errors; switching line/cruise/variable fetches one shard each time.
12. Line 90 in a known-good final cruise visually matches the same transect drawn in
    `apps/ctd-viz` — same field, same structure.
13. A `preliminary_ctd` cruise shows the tier badge, disables corrected salinity/oxygen, and
    offers the uncorrected series instead of rendering blank.
14. Pages deploys from the workflow; `version.json` matches `latest.txt`.
