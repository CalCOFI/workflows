# Explorer reference layers — the OSM land mask, GEBCO gazetteer labels, and the ocean stack at the bottom of the basemap

*2026-09-09 · Ben: "the GEBCO bathymetry and Contours raster outputs look crude and spill over with fuzz around the
coastline … we need to use our own land layer … keep political boundaries, roads, parks … Esri Ocean labels? … layers
on/off + ordering in the Layers control … a reproducible workflow notebook … vector reference layers as PMTiles on GCS."*

## What is actually wrong (measured 2026-09-09)

- **The Contours surface clips itself on its own cells.** `contour.ts` `landMask()` rasterizes Natural Earth 10 m land
  (`public/land.geojson`, D42) onto the surface grid — 0.1° (≈ 10 km) cells at the site grain — and the 60 km edge fade
  then blurs that staircase. At the home view the coast is a 10 km staircase with a fuzzy fringe (shot: `_shots/before_*`).
- **CARTO has no land layer.** Positron / Dark Matter paint land as `background` and the ocean as the `water` fill
  (index 9); `landcover`, `park_*`, `landuse*`, `waterway`, `boundary_county`, `boundary_state` sit BELOW `water`
  (indices 1–8), roads / buildings / country boundaries / labels above it. The sea floor is inserted right after `water`,
  so every 390 m GEBCO cell that straddles the coast paints over the land side, and nothing above can hide it.
- **The DEM's water-side rim is a non-issue**: both ramps fade to transparent at 0 m, and on light the shallow end IS
  CARTO's water colour, so a coastal cell GEBCO calls ≥ 0 reads as the shallows either way. No DEM rebuild.
- "Crude" at z10+ is GEBCO's 15″ (≈ 390 m) overzoomed from z8 — inherent; a finer coastal DEM (NOAA CRM 3″ / CUDEM)
  would be a separate artefact, out of scope here.

## Decisions

- **D47 — The ocean stack moves to the bottom of the basemap.** In `composeStyle()` CARTO's `water` fill moves to right
  after `background`; the sea floor, the boundary layers under the Data row, and the data (deck, `beforeId = "land"`)
  draw over it; then the **land mask** (`osm_land.pmtiles`, a `fill` in the theme's `background-color`); then a copy of
  CARTO's `water` filtered to `class != ocean` (lakes, rivers and ponds, which the coastline-derived land polygons
  cover); then every CARTO land layer in its own order (landcover, landuse, waterway, county and state lines, roads,
  buildings, country boundaries, labels) — untouched, now above the mask. The boundary layers ABOVE the Data row insert
  where they always did (before `water_shadow`, under roads and labels). `land=off` restores today's stack exactly.
- **D48 — The mask is OSM's own coastline**, not Natural Earth: osmdata.openstreetmap.de `land-polygons-split-4326`
  is the source CARTO's water polygons derive from, so the mask's coast is the basemap's coast at every zoom (NE 10 m
  is generalized by hundreds of metres, wrong at z9+). Cropped to the sea-floor tiles' core box (−140, 15, −105, 56):
  outside it the background is land already and the far sea-floor tier (z ≤ 5) has sub-pixel fuzz. 45,249 polygons,
  3.8 M vertices, read through `/vsizip` with a bbox filter in 10 s.
- **D49 — `park_*` sink under water.** CARTO's `park_national_park` / `park_nature_reserve` include marine polygons
  (Channel Islands NP's 1 nmi ring, the Baja *Islas del Pacífico* biosphere reserve, state marine reserves tagged
  `nature_reserve`); above the mask they would tint the ocean, so they move to right after `background` — hidden by
  water at sea (as today) and by the mask on land (a loss of faint green tints on land, light theme only; dark paints
  them in the background colour anyway). One-line flip in `basemap.ts` (`SINK_UNDER_WATER`).
- **D50 — Undersea feature names are a vector layer from the GEBCO Gazetteer** (IHO DCDB feature service: 186 points,
  20 lines, 17 polygons in the box) as `gebco_gazetteer.pmtiles`: label = `NAME + TYPE` ("Cortes Bank", "Patton
  Escarpment"), `rank` 1/2/3 by generic term (escarpments, fracture zones, ridges, trenches, fans from z4; basins,
  banks, canyons, seamounts from z6; knolls, hills, valleys from z8), points and polygon centroids as point symbols,
  lines labelled along the line. Not Natural Earth's marine polygons: CARTO already labels bays and straits from OSM
  (`water_name`), and NE 10 m has 11 named polygons in the box.
- **D51 — Esri's World Ocean Reference is offered as a raster row, off by default**, so it can be compared: it is
  pre-rendered (no dark restyle, fixed label sizes), duplicates CARTO's land labels and boundaries, is not PMTiles,
  and rides Esri's terms (attribution "Esri, GEBCO, NOAA, National Geographic, Garmin, HERE, Geonames.org, and other
  contributors"). Ben decides whether it stays in the registry.
- **D52 — Reference layers live in the boundary registry** (`metadata/spatial_layers.csv`) with `role = reference`,
  `source_type = pmtiles | raster`, `source_url` (raster only) and `geom_type ∈ polygon | line | point | label | raster`;
  `build_spatial_layers()` (calcofi4db 4.8.0) passes them through, reads their counts from
  `data/parquet/spatial/reference_layers.json` (they are not in the release's `spatial` table: no memberships, no
  Regions lens), and no longer warns for them. The Explorer draws `label` as symbol layers and `raster` as a raster
  layer; the land mask is not an "On the map" row — it is a **Land** checkbox beside Sea floor (`land=off`), always
  directly above the Data row.
- **D53 — The Data row is the sea surface.** With Land on, everything from the Data row down is clipped to the ocean
  (the mask sits immediately above the data, wherever the row is dragged); boundaries above it draw on the surface,
  land parts included. The card says so under the Data row.
- **D54 — One notebook owns `_spatial/`.** `ingest_spatial.qmd` gains a *Reference layers* section (`libs/
  reference_layers.R`: guarded downloads under `cc_stage_path("reference")`, the crop, the ranks, tippecanoe, the
  manifest); the PMTiles upload with the boundary archives. Nothing under Drive or git.

## Kickoff (executed 2026-09-09)

workflows (`libs/reference_layers.R`, `ingest_spatial.qmd`, `metadata/spatial_layers.csv`, `release_database.qmd`,
`RELEASES.md`, skill `reference-layers`, `CLAUDE.md` line) · calcofi4db 4.8.0 (`build_spatial_layers()` + test + NEWS) ·
explore (`basemap.ts`, `state.ts`, `layers.tsx`, `App.tsx`, `README.md`, `help.tsx`, `tour.ts`, `verify.mjs`,
`spatial_layers.fallback.ts` regenerated) · docs `explore.qmd` Layers paragraph. Results under *Measured* below.

## Measured

*Executed 2026-09-09 (nothing committed, nothing deployed; the two archives ARE on the bucket).*

- **Archives** (`ingest_spatial.qmd` through `targets`, 3 m 09 s end to end; the reference section alone ~50 s):
  `osm_land.pmtiles` 8.0 MB — 45,249 polygons, 3,803,808 vertices, z0–10, bounds −134.6 → −105 × 18.3 → 57.0 (the crop's
  east and north edges; nothing west of −134.6 is land); `gebco_gazetteer.pmtiles` 622 KB — 219 labels (186 points, 20
  lines, 17 polygon centroids; rank 1/2/3 = 31/159/29), the fracture-zone lines reach −168 and −54.7 S. Both at
  `gs://calcofi-files-public/_spatial/` (206 on a ranged GET); `reference_layers.json` records sha256 / bytes / source
  versions (OSM extract 2026-08-31). `sync_to_gcs` re-uploaded them from the notebook run (tippecanoe bytes differ
  run to run by 37 B — the metadata timestamp).
- **The stack, live** (`map.style._order`, light, z9.3 Oxnard): `background 0 · park_national_park 1 ·
  park_nature_reserve 2 · water 3 · gebco-far-relief … gebco-contour-label 4–9 · deck-layer-group-before:land 10 ·
  land 11 · water-inland 12 · landcover 13 … boundary_state 18 · water_shadow 19 · roads … labels`. deck 9 interleaves
  ONE custom group per `beforeId`, named `deck-layer-group-before:<id>`; `map.getStyle()` drops custom layers, so
  the tests read `style._order`.
- **Pixels**: the Oxnard plain (−119.1, 34.22) reads 246,246,244 with the mask (the surface's magenta without it); the
  Santa Barbara Channel (−119.7, 34.25) 167,105,141 (the surface); the Salton Sea reads CARTO's water through the
  inland copy; the desert is land. Shots: `coast_before.png` / `coast_after.png` (temperature, kriging, z9.3): before,
  the surface covers Ventura, Oxnard, Thousand Oaks and Simi Valley; after, it stops at the coast and the basemap's
  roads, county line and place labels sit over it.
- **Labels** at z7.5 (dark): Arguello Canyon · San Juan Seamount · Rodriguez Seamount · East Cortes Basin · Cortes Bank ·
  Tanner Bank · San Nicolas Basin · Catalina Basin, SANTA LUCIA ESCARPMENT in capitals; Esri's raster row draws at
  `layers=esri_ocean_reference::0.8` (the opacity is the SECOND field of the grammar, `slug:colour:opacity:width`).
- **verify.mjs**: 6 new `ref_*` cases + the two checkbox counts (6 → 7) — all green; the 18 pre-existing layer /
  contour / hex-under-sanctuaries cases re-run green. `npm run build` (tsc + vite) clean. calcofi4db 4.8.0:
  `devtools::test(filter = "explore")` 161 passed, installed locally. Docs `explore.qmd` Layers paragraph + the
  `layers_panel.png` figure re-shot (`tour_shots.mjs --only=layers_panel`); the book is not re-rendered here.
- **Not done, by design**: no DEM rebuild (the ramps already hide the water-side rim); no finer coastal DEM; the docs
  book render; the Explorer deploy (push to `main` deploys via Pages — Ben's call after a look at `land=off` vs on).
- **Left over from the session**: Homebrew's `re2` had been upgraded past the `abseil` it linked (every GDAL CLI and the
  Python `osgeo` bindings died with "Library not loaded … libabsl_log_internal_check_op.2508"); `brew upgrade re2`
  (→ 2025-11-05_2) fixed all of them — the bathymetry build script runs again.
