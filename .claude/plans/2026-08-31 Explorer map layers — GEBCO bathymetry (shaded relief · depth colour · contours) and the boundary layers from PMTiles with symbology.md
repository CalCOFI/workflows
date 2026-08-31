# Explorer map layers — GEBCO bathymetry (shaded relief · depth colour · contours) and the boundary layers from PMTiles with symbology

**Status:** proposed 2026-08-31; Ben reviewed it the same day ("looks great") and added three things, folded in:
the artefacts stay on **`gs://calcofi-db/bathymetry/`** (a first move to `calcofi-files-public` was reverted once
it was clear the folder already existed — the storage.calcofi.io root link had hidden it), the R consumers' GEBCO
crop is **widened so no observation samples `NULL`** (D29), and the storage index lands on the bucket, not on
`ducklake/releases/` (D30); the open questions stand on their recommended answers · **Date:** 2026-08-31 ·
**Scale:** mostly one repo (`CalCOFI/explore`, ~4 new modules + the Layers card); one reproducible build script
+ a metadata JSON in `workflows` (the bathymetry tiles and the re-cropped GeoTIFF → `gs://calcofi-db/bathymetry/`);
a `calcofi4r` patch (`cc_bathy()` / `cc_bathy_depth()`); one small sidecar builder in `calcofi4db`
(`build_spatial_layers()`) wired into `release_database.qmd`'s `browser_objects` chunk; a one-field fix in
`scripts/build_storage_index.R` (+ a timestamp column); **~51 h in three shippable slices** plus an optional 8-h 3-D spike. Extends the 2026-08-28 plan's D7 (*"one 'show boundaries'
layer toggle on every lens"*) and the 2026-08-29 UI plan's D11 (cards) / D19 (figures). Decision numbering
continues from that plan: **D21–D28**.

## The ask (Ben, 2026-08-31)

1. A **default bathymetry layer** in the explorer that follows the dark / light theme — "perhaps 3D shaded with
   depth contours", derived from GEBCO, "which we already sample from".
2. **Which is fastest to render — map image tiles, or PMTiles (contours)?**
3. The bathymetry **toggles on and off**.
4. The **other layers already in the `spatial` table** (and already on GCS as PMTiles for interactive mapping)
   available as **background layers**, with **basic symbology editing**: colour all the same *or* a palette by a
   value (probably `name`), transparency, line colour and thickness.
5. (Review, 2026-08-31) **Several layers at once, ordered by dragging a layer up or down** — the draw order is
   the user's, not the registry's (D24 *Draw order*, D25's *On the map* list, D26's `layers=` order).
6. (Review, 2026-08-31) Keep everything under **`gs://calcofi-db/bathymetry/`**; **re-crop `gebco_2025_calcofi.tif`**
   — the raster `calcofi4r::cc_bathy()` serves — so that sampling observation positions never yields `NULL` for
   want of extent (D29); and fix **storage.calcofi.io**, whose root page sent `calcofi-db` straight to
   `ducklake/releases/` instead of the bucket's own listing, which is why the folder looked as if it did not exist (D30).
7. (Review, 2026-08-31) A **datetime stamp on the storage listings** — to judge, for instance, whether the 18.29 GB
   under `calcofi-db/gcloud/tmp/parallel_composite_uploads/…` can be deleted (D30: it can — three interrupted
   uploads, Feb–Jun 2026).

Reading of "3D shaded": **shaded relief** (hillshade — the illuminated, 3-D-looking sea floor drawn flat) is
the default; a *pitched* true-3-D terrain view is a separate, optional, spike-gated item (D28), because deck.gl's
non-interleaved overlay does not know about MapLibre terrain and the station dots would need re-verifying.

## Context — what exists (read 2026-08-31; `explore` @ `58e940c`)

**The explorer's map** (`src/map.tsx`): MapLibre 5.24 with CARTO's keyless *dark-matter* / *positron* style, and the
theme flip is a **whole-style swap** — `map.setStyle(STYLE[theme])` on `cc:theme` (`map.tsx:238`). Anything added
with `addSource`/`addLayer` after load would vanish on every theme change, so custom layers must be part of the
style object itself (D22). deck.gl's `MapboxOverlay` runs **non-interleaved** — its own canvas above *every*
MapLibre layer, `pointer-events` pass through to the map — so a MapLibre bathymetry or boundary layer is
underneath the dots and hexagons by construction, and MapLibre's own `mousemove`/`queryRenderedFeatures` still
work beside deck's picking. Both canvases keep `preserveDrawingBuffer`, so the map ⬇ PNG and the feedback
capture (`capture.ts`) already include whatever MapLibre draws. The Regions lens draws its polygons from the
release sidecar `spatial.geojson` (11 MB: every layer, simplified at 0.002°) through a deck `GeoJsonLayer`, and
`state.ts` hard-codes the four region layers in `LAYERS`. Map chrome: `.map-tl` (legend + minimized-card pills),
`.map-tr` (the map's ⬇ and the status chip, left of MapLibre's +/−); the stacking scale `--z-map-chrome 5 ·
--z-pills 10 · --z-cards 20 · --z-max 30 · --z-menu 35 · --z-modal 40 · --z-tour 50`. Panels: `FloatCard`
(`CardId = section | cruise | station | timing`) with minimize-to-pill, maximize, drag; on a phone a card opens
as the bottom `Sheet`. **The URL is the whole view** (`fromUrl` / `toUrl`), so anything a share link must
reproduce goes in `Sel`.

**The boundary layers.** `ingest_spatial.qmd` writes two things from `metadata/spatial_layers.csv` (19 rows:
`dataset_id`, `dataset_group`, `layer` = the human name, `group` ∈ Maritime Zones · Protected Areas ·
Administrative · Ecological · Energy & Industry, `geom_type`, `filter_expr`, `line_color`, `fill_color`,
`line_width`, `fill_opacity`, `default_visible` — TRUE only for the 200 NM EEZ —, `name_field`, `description`,
`attribution`): the release `spatial` / `spatial_attribute` parquet, and **17 PMTiles archives at
`gs://calcofi-files-public/_spatial/{dataset_group}.pmtiles`** (37 MB total, built 2026-08-24 with tippecanoe
`-z10 -Z0 --simplify-only-low-zooms --no-tiny-polygon-reduction -l {dataset_group}`, so the **source-layer name
is the `dataset_group`** — exactly what db-viz-hex's `add_spatial_layers()` uses). Every feature carries `id`
(per-file sequential), `layer` (the human name), `name` (from `name_field`) plus all its source columns. The
bucket answers CORS `*` with the `Range`/`Content-Range` headers exposed, and a ranged GET returns **206** — the
protocol the `pmtiles` JS library needs. One known wrinkle, from db-viz-hex: the per-file `id` equals
`spatial.id` for single-layer groups but **not** for the one multi-layer group (`noaa_maritime_boundaries`, the
three line layers), so a background feature cannot be joined to `spatial_key` by `id` alone — fine here, since
background layers are drawn and hovered, not summarized.

**GEBCO.** Two artefacts already exist: the R consumers' crop `gs://calcofi-db/bathymetry/gebco_2025_calcofi.tif`
(4.3 MB, 15 arc-second, Float32 positive-down depth, land clamped to 0, **lon −126.98 → −116.78 × lat 29.33 →
38.35**; what `calcofi4r::cc_bathy()` downloads and caches, hence ctd-transects' station/line bathymetry and any
user's `cc_bathy_depth()`; ctd-viz points `calcofi4r.bathy` at its own identical local crop), and the full GEBCO
2025 sub-ice source tile `~/_big/gebco_2025_sub_ice_topo_geotiff/gebco_2025_sub_ice_n90.0_s0.0_w-180.0_e-90.0.tif`
(933 MB, Int16, lon −180 → −90 × lat 0 → 90, **local only**). workflows#54 ("bathymetry as a released layer")
closed with `seafloor_depth_m` on `sample` and that crop. Measured against the released `sample` table
(v2026.08.25, 1,461,405 positioned rows):

- **The release does not use the crop.** `release_database.qmd`'s `depth_coverage` chunk defaults
  `CALCOFI_GEBCO_TIF` to the full tile, so `seafloor_depth_m` is `NULL` for only 1,431 positioned samples — 1,360
  ichthyo positions *east of −90°* (lon −89.95 → −77.23, lat 0.02 → 16.79: outside the source tile, and doubtful
  coordinates) and 71 METS rows with a longitude but no latitude. Neither is an extent problem the crop could cause;
  both are `questions.csv` rows for their ingests. It is, however, a **laptop-only dependency**: a machine without
  the 933 MB download cannot run the release.
- **The crop is far too small for `cc_bathy()` users.** **360,568 positioned samples — 24.7 % — lie outside it**,
  across seven datasets: bottle 271,259 (its 1949–1987 offshore and Baja cruises, lon to −164, lat 18.4 → 47.9),
  ichthyo 59,768, PIC zooplankton 20,527, CUFES 8,230 (north to 54.7° N), dungeness 752, DIC 19, euphausiids 13.
  `cc_bathy_depth()` returns `NA` for every one of them, silently. A box of **lon −165 → −100 × lat 15 → 56**
  covers all of them but 5,703 ichthyo positions — 28 cruises 1972–2006 reaching lon −179.8 and −77.2 and lat 0.0,
  the far field and the bad coordinates — and a box of −170 → −90 × 0.5 → 58 leaves 1,595 (all ichthyo, all
  east of −90° or at lat ≈ 0). Beyond the explorer's core tile box (−140 → −105 × 15 → 56) sit 9,492 positions:
  ichthyo 6,341, bottle 2,973 (9 cruises 1955–1972, lon −164 → −140 — NORPAC-era, real), PIC 139, dungeness 39.
- **The crop is also too small for the explorer**: the home view (`MAP_HOME` z5.1 on a 1280-px map) spans about
  lon −135 → −108 × lat 24 → 42, so tiles cut from it would end in a hard edge in open ocean. The tiles come from
  the full source (D21), and the crop is re-cut from it too (D29).

**Tooling on this machine:** GDAL 3.11.5 (`gdaldem`, `gdal_contour`, `gdalwarp`, the new `gdal raster tile`) with
the `osgeo` Python bindings in Homebrew's python3, tippecanoe 2.79, the `pmtiles` CLI, `uv`; `rio-rgbify` is
**not** installed. In the app: MapLibre 5.24's runtime has `raster-dem` (mapbox / terrarium / custom encodings),
`hillshade` with `hillshade-method` (standard · basic · combined · igor · **multidirectional**), **`color-relief`**
(a GPU colour ramp over `["elevation"]` — a themed depth palette is a paint property, not a tileset), and
`terrain`. npm: `pmtiles` 4.5.0 (the `pmtiles://` protocol for MapLibre), `maplibre-contour` 0.1.0 (contours
generated in the browser from DEM tiles; its `DemSource` takes a `{z}/{x}/{y}` URL and only the worker-import
route mentions `pmtiles://` — to be tried, not assumed). MapLibre 6.6 exists but 6's module worker breaks under
Vite's optimizer (pinned to 5 since the spike).

**CARTO's layer order matters for where the relief goes:** `background` *is* the land colour (`#0e0e0e` dark ·
`#fafaf8` light) and `water` is a fill drawn over it (index 9; `#2C353C` dark · `#d4dadc` light), then `waterway`,
the boundaries, roads, and the labels from `waterway_label` on. Our layers go **right after `water`**: they cover
the flat water fill, stay under every label and boundary line, and never touch land (D21's land clamp).

## The take — the answer to "image tiles or PMTiles (contours)?"

Neither, as the primary. **Pre-rendered image tiles** are the fastest thing to *decode* and the slowest thing to
*change*: dark and light are two archives, every palette or shading tweak is a re-tile and a re-upload, and a
raster contour cannot be labelled, thinned by zoom or recoloured. **Contour PMTiles alone** give crisp, styleable
lines but no shaded relief and no depth colour. The fast *and* themable route is **one raster-DEM PMTiles archive
(terrain-RGB-encoded GEBCO) rendered by MapLibre on the GPU** — `hillshade` for the shaded relief and
`color-relief` for the depth colour, each a paint property that swaps with the theme in one `setPaintProperty`,
zero re-tiling — plus **contours as a small vector PMTiles** styled at runtime (colour, width, labels per zoom).
Render cost is a per-pixel shader over a 512² texture per tile — negligible on any WebGL device — and the bytes
per view are ~12 DEM tiles at the home zoom. Everything is PMTiles, so it is two static files on GCS behind range
requests, exactly like the boundary archives already are.

| route | render cost | bytes / home view | theme swap | contours | what it costs to change |
|---|---|---|---|---|---|
| **A · raster-DEM PMTiles → `hillshade` + `color-relief`** (recommended) | GPU shader per tile, ~0 | ~12 tiles (0.5–1.5 MB, cached) | a paint property | — | nothing: the DEM is theme-free |
| **B · contour vector PMTiles** (recommended, with A) | a line layer, ~0 | ~12 small tiles | a paint property | labelled, zoom-thinned | one `gdal_contour` + tippecanoe run if the levels change |
| B′ · `maplibre-contour` from A's tiles at runtime | marching squares in a worker per tile | 0 extra bytes | free | any interval, live | an extra 30 KB library; PMTiles compatibility to prove; phone CPU |
| C · pre-rendered image tiles (`gdaldem hillshade`/`color-relief` baked) | fastest decode | ~12 tiles | **a second archive** | unlabelled, baked | re-tile + re-upload per variant |

**Deterministic beats live** here (the fleet's rule since the station app: build-time pre-rendering over runtime
parsing, and the phone must not fail), so B is the primary contour source and B′ is a spike measurement, not a
dependency. C is kept only as the fallback for a device that cannot run the DEM shaders — none is known.

## Decisions

### D21 · Bathymetry → one terrain-RGB PMTiles from GEBCO 2025, shaded relief + depth colour + contours, themed by paint

- **Source and extent — two tiers.** Tile from the full GEBCO 2025 sub-ice grid. The **core**, **lon −140 → −105 ×
  lat 15 → 56** (Baja to Haida Gwaii — the home view with room to pan, the whole CalCOFI pattern and CUFES's northern
  surveys), at **z0–z8 with 512-px tiles** (≈ z9 at 256 px: a z8/512 pixel is ~0.25 km at 34° N against GEBCO's
  ~0.39 km cell, so nothing of the source is lost and everything above overzooms cleanly) — ≈ 950 tiles at z8,
  ≈ 1,270 in all. The **far field**, the whole source tile (lon −180 → −90 × lat 0 → 60) at **z0–z5** — ≈ 55 tiles,
  a few MB — so the 1955–1972 offshore cruises out to −164° have a sea floor under them when someone pans there,
  and there is no hard edge in open ocean anywhere a CalCOFI position exists. One sparse archive if the spike
  confirms MapLibre keeps the parent tile where a z6–8 child is missing; otherwise two archives as two sources
  (`gebco-far` under `gebco`, each bounded by its PMTiles header, so the far tier shows only outside the core's
  bounds) — deterministic either way. **Size is measured in the spike**: the core estimate is 50–190 MB depending
  on encoding — `mapbox` (0.1 m steps, broadest support) first; if it lands over ~120 MB, `custom` encoding at 1 m
  steps (`redFactor`/`baseShift`, MapLibre ≥ 4) roughly halves it, and metre precision is all a sea-floor background
  needs. The bytes only matter as storage — a view fetches its ~12 tiles.
- **Land is flat, and the coast is CARTO's.** Clamp elevation to `min(elev, 0)` before encoding, so land is a
  plane at 0 (no hillshade, `color-relief` transparent at 0), and CARTO's land, coastline and labels stay exactly
  what they are. GEBCO's 0 m line and OSM's coastline disagree by up to a few hundred metres, which at z10+ would
  show as a shallow-blue fringe on CARTO's land where GEBCO still says water. Two mitigations, both in the build:
  (1) **each theme's ramp ends, at 0 m, on CARTO's water colour** (`#2C353C` dark, `#d4dadc` light), so where OSM
  says water and GEBCO says land the flat fill merges into the shallows; (2) burn the **OSM land polygons**
  (osmdata.openstreetmap.de `land-polygons-split-4326`, the same coastline CARTO's water derives from) into the DEM
  as +1 m, so GEBCO never paints where OSM has land. (2) is optional — the spike screenshots the seam at z11
  with and without it and Ben picks.
- **Rendering** (MapLibre layers, all inserted after `water`): `gebco-relief` (`color-relief`, ramp per theme) →
  `gebco-shade` (`hillshade`, `hillshade-method: multidirectional` or `igor` — chosen by eye in the spike;
  exaggeration ~0.5; shadow/highlight colours per theme) → `gebco-contour` (`line` from the contour archive,
  `line-width` by `level`, faint on dark) → `gebco-contour-label` (`symbol`, `ele` along the line, from z8, majors
  only). The dots stay legible: relief opacity 0.6–0.7 on dark by default, contours at ~0.25 alpha. Ramps start
  from Appendix B and are tuned in the spike (the `dataviz` skill's palette validator checks both themes).
- **Contours** (archive B): `gdal_contour` on the same wide DEM at fixed levels — 50 · 100 · 200 · 300 · 400 · 500
  · 750 · 1000 · 1500 · 2000 · 2500 · 3000 · 3500 · 4000 · 4500 m — with a `level` attribute (0 = 50 m, 1 = 100/200,
  2 = 500-multiples, 3 = 1000-multiples) and a per-feature `tippecanoe:minzoom` so 1000-m lines exist from z0,
  500 s from z5, 100/200 s from z7 and 50 s from z9; optionally `gdalwarp -r cubicspline` to 2× before contouring
  for smoother lines at z10+. Expected 10–40 MB. B′ (`maplibre-contour`) is tried in the spike for one afternoon:
  if it reads the PMTiles source directly, costs nothing visible on the phone and its lines match, it can replace
  the archive later — the plan does not depend on it.
- **Hosting:** `gs://calcofi-db/bathymetry/gebco_2025_calcofi_terrain.pmtiles` + `…_contours.pmtiles` (+ `…_far.pmtiles`
  if the tiers are two archives), beside the crop that already lives there — Ben's call, 2026-08-31, after a brief
  detour to `calcofi-files-public` — with **`gebco_2025.json`** describing the whole family (source file + sha256,
  each artefact's bbox / zooms / tile size / encoding / land mask / contour levels, build date, GDAL and tippecanoe
  versions, the GEBCO citation and licence): the explorer reads it for its bounds and attribution, `cc_bathy()`
  for the crop's expected extent, so nothing hard-codes what the build decided. The bucket already answers CORS `*`
  with the Range headers exposed (`gsutil cors get`), which is all the `pmtiles` protocol needs.
- **Not in the release.** Bathymetry is a base layer, not database content: no `catalog.json` entry, no
  `RELEASES.md` line. The one release-adjacent touch is the sidecar of D23, which does not list it either.

### D22 · The style is composed, not patched — `src/basemap.ts`

`composeStyle(theme, mapLayers)` fetches CARTO's style JSON once per theme (cached), inserts our sources
(`gebco` raster-dem, `gebco-contours` vector, one `pmtiles://` vector source per visible boundary group) and our
layers after `water` — the sea-floor layers first, then each boundary's fill + line pair in the URL's list
*reversed*, since MapLibre draws later layers on top and the list is top-first — and returns a complete style. `MapView` applies it with **`map.setStyle(style, { diff: true })`**
— MapLibre diffs by id, so a theme flip is a handful of paint/source operations and a symbology change is a paint
diff — and if a diff ever cannot be computed, MapLibre rebuilds *from that same object*, so our layers survive
either way (the failure mode `addLayer`-after-load has). Two rules: **the first style has no DEM source** — it is
added by one diff right after the first `load`, so `first_paint` (the 1.06 s the spike measured, `onFirstFrame`)
does not wait for terrain tiles and the relief fades in (`raster-fade-duration`); and slider edits (opacity,
width) are throttled to one `setStyle` per animation frame. The style is a pure function of (theme, URL layer
state), like everything else in the app. `pmtiles` registers its protocol once at module load.

### D23 · Boundaries → the existing PMTiles, described by a release sidecar `spatial_layers.json`

The explorer must not hard-code the layer list (D7 said the registry is *Erin's sheet* and will grow) and must
not fetch a CSV from GitHub at runtime. `calcofi4db::build_spatial_layers(con, registry, version, pmtiles_base)`
joins `metadata/spatial_layers.csv` with the release's `spatial` table — feature counts, bbox, and the sorted
distinct `name`s per layer when there are ≤ 200 (the by-name palette, D24; `null` above that) — and writes
`spatial_layers.json` beside `coverage.json`; `release_database.qmd`'s `browser_objects` chunk calls it, and the
file joins the three sidecar lists (`unlink`, the `put_gcs_file` loop at ~1818, the `gs://` list at ~2028).
Until a real release carries it, `explore/scripts/dev_spatial_layers.R` writes the same file into the
`explore-dev` catalog (as `dev_coverage.R` did for `taxa[]`), and the app keeps a bundled snapshot
(`src/spatial_layers.fallback.json`, generated from the CSV) for an older release — the pattern `categories.ts`
already uses. Each entry: `id` (the slug), `group`, `name`, `source` (archive = source-layer = `dataset_group`),
`geom` (`polygon | line | point`), `filter` (the registry's expression, e.g. `["==", ["get","eez"], 1]`),
`line_color`, `fill_color`, `line_width`, `fill_opacity`, `default_visible`, `name_field`, `description`,
`attribution`, `n_features`, `bbox`, `names`. The same file lets the Regions lens' layer list become data-driven
(the layers with memberships in `sample_spatial`) instead of `LAYERS` — a small follow-on inside Phase 3.
Version skew (the archives are rebuilt by `ingest_spatial` outside releases) is accepted for now and named in
Risks; a `built` date from `ingest_spatial`'s manifest rides in the sidecar so it is at least visible.

### D24 · Symbology and order → one colour or a palette by `name`, fill opacity, line width; draw order by drag; the legend follows

Per layer: **visible**; **colour mode** = *one colour* (a 10-swatch strip in the registry's families + a free
`<input type=color>`) or *by name* (one of three categorical palettes, assigned to the layer's sorted `names`; a
layer with `names: null` falls back to `["%", ["get","id"], k]` so it is still distinguishable, never uniform);
**fill opacity** (0–1; lines ignore it); **line width** (0.5–4 px; a point layer reads it as radius); **line
colour** follows the fill colour darkened unless the user sets it; **reset to the registry**. Registry values
(`line_color` etc.) are the defaults, on both themes — they are mid-tone Material shades and read on dark and
light alike; the fills are 0.1–0.2 opaque, which is why they work as background. The palettes are validated on
both themes with the `dataviz` skill's checker before they ship. The map legend gains a **Layers block** under
the colour bar: one row per visible boundary layer (swatch · name; in by-name mode a six-swatch strip and
"by name · N"), plus one "sea floor · GEBCO 2025" row when the bathymetry is on — it is inside `.map-tl`, so the
map ⬇ PNG and the feedback capture carry it (D19).

**Draw order.** Any number of layers can be on at once, and they stack in the order the user sets. The card's *On
the map* list is **top-first** (the GIS table-of-contents convention: the top row is drawn on top), reordered by
dragging a row's handle (`ui-drag`; a pointer handler like the cards' own drag in `panels.tsx`, no library) or
with **▲ ▼** buttons (keyboard, and the phone sheet, where a drag fights the scroll). Adding a layer puts it on
top. Each layer is one fill + line pair (its line above its own fill) inserted as a unit, so the order is per
layer, exactly as the list shows it. The sea floor is always the base under every boundary and is not in the
list; the data — dots, hexagons, regions — are deck's canvas above everything MapLibre draws, so ordering only
ever decides boundary-over-boundary (MPAs above sanctuaries, or the reverse — which matters as soon as two fills
overlap). The legend block lists the visible layers in the same top-first order.

### D25 · The Layers card — a floating card from a button in the map's corner; a sheet on the phone

A **`layers` button** in `.map-tr` (a new `ui-map-layers` glyph — MDI `layers-triple-outline`; `ui-layers` is the
Lens group's) opens a **Layers `FloatCard`** (`CardId += "layers"`, default box top-right under the status chip
like the station card, minimize → pill, maximize, drag; on the phone the `Sheet`). Three parts: **Sea floor** —
on/off, then *shaded relief* · *depth colour* · *contours* checkboxes, an opacity slider, *labels*; **On the
map** — the visible boundary layers, top-first, each row `⋮⋮ drag handle · swatch · name · ▲ ▼ · ×`, expanding
into the D24 controls; and **Add a layer** — the registry groups as folded disclosures with a checkbox per layer
(a check adds it to the top of *On the map*). Hovering a visible boundary shows `name · layer` (MapLibre
`queryRenderedFeatures` on our layer ids, only when no deck object is under the pointer; the existing
`getTooltip` returns `null` there). The Regions lens draws the selected layer from `spatial.geojson` with deck,
so the *same* layer's background copy switches to outline-only while it is the lens' layer — never a double fill.
One tour step ("Layers — the sea floor, and the boundaries you can draw on top"); `data-tour="layers"`.

### D26 · The URL carries it — `bathy=`, `bathyo=`, `layers=`; nothing in localStorage

Defaults are absent from the URL: bathymetry **on** with relief + depth colour + contours, boundaries **off**
(recommendation below asks Ben whether the registry's EEZ default should apply). Grammar in Appendix A:
`bathy=off | relief,depth,contours` (any subset), `bathyo=0.6` (opacity, 2 decimals), `layers=slug[:colour][:fill_opacity][:line_width][,…]`
with `colour` = `hex6 | pal1..pal3`, positional fields optional, an empty field = the registry default
(`ca_marine_protected_areas::0.5`). **The entry order is the draw order, first on top** — the card's list read
downwards — and a drag or ▲ ▼ rewrites it. `fromUrl` ignores unknown slugs (an older link after a registry rename) and
`toUrl` writes fields only where they differ from the defaults. Symbology is view state, so it lives in the URL
and nowhere else — a share link, a bookmark and a feedback report reopen the same map, and `?tour=off` screenshots
stay deterministic.

### D27 · Credit — GEBCO in the attribution, the About dialog and the stamped figure

The `gebco` source carries `attribution: "GEBCO Compilation Group (2025) GEBCO 2025 Grid"` (and each boundary
source its registry `attribution`), so MapLibre's compact ⓘ lists them; About gains a *Map layers* paragraph with
the GEBCO citation/DOI and licence (from the build JSON) and a link to `metadata/spatial_layers.csv`; the map
figure's footer stamp (`stampFor("map")`) appends `· sea floor: GEBCO 2025` while the bathymetry is on, since the
compact attribution is collapsed in a capture.

### D28 · True 3-D — optional, spike-gated, last

MapLibre `setTerrain({ source: "gebco", exaggeration })` over the same DEM gives a pitched sea-floor view for
free (land at 0, basins × 10–20). The unknown is deck.gl: in non-interleaved mode the overlay projects with the
map's 2-D camera, so under pitch the station dots (at the sea surface, z = 0) and the terrain-displaced basemap
may not agree, and `interleaved: true` changes how every existing layer composites. Phase 4 is a 1-day spike with
an acceptance test (pitch 45°: the dots sit on the sea surface above their station's seafloor, hexagons draw
without z-fighting, the morph still runs); it ships as a `view=3d` toggle only if that passes, otherwise the
finding is recorded and the item closed. Not in the core estimate.

### D29 · The consumers' crop covers every observation — and an off-raster point is never a silent `NA`

`gebco_2025_calcofi.tif` was cut for one app's cast extent and became the raster `calcofi4r::cc_bathy()` serves to
everyone; a quarter of the released positions lie outside it (Context). The same build script re-cuts it from the
same source, under the **same name and URL** (so ctd-transects, ctd-viz and every `cc_bathy()` caller keep working
unchanged), as:

- **lon −165 → −100 × lat 15 → 56**, the box every bottle, PIC, CUFES, dungeness, DIC and euphausiid position falls
  in with margin; only ichthyo's 5,703 far-field / bad-coordinate positions stay outside, and those are an ingest
  question (`swfsc_ichthyo` — positions at lat 0.0 and east of −90°), not a raster problem. Same conventions:
  positive-down depth, land 0, `NA` off-extent — but **Int16** (GEBCO is metre-integer; the Float32 crop doubled its
  bytes for nothing) and a **Cloud-Optimized GeoTIFF** (512-px tiles, DEFLATE + predictor, overviews). ~150 M
  cells; the estimate is 60–120 MB, measured in the spike. A 20× bigger file is the honest cost of "no NULLs".
- **`cc_bathy()`** (calcofi4r patch): refreshes its cached copy when the object's size no longer matches (one
  `HEAD`, so a stale 4.3 MB cache is replaced without anyone knowing to pass `refresh = TRUE`); gains
  `remote = TRUE`, which returns `terra::rast("/vsicurl/<url>")` — GDAL then reads only the blocks a query touches,
  so sampling a handful of far-field points needs no download at all; the default stays download-and-cache
  (offline, deterministic — ctd-viz keeps its local file via `calcofi4r.bathy`).
- **`cc_bathy_depth()` warns** with the count and bounding box of the points that fall outside the raster's
  extent, instead of returning `NA` for them in silence — the behaviour that let a quarter of the positions read
  as "no depth" without a line of output anywhere. Tests: a NORPAC-era bottle position (−150, 30) and a CUFES
  position (−128, 54) read a finite depth from the new crop; a point at (−175, 10) warns and reads `NA`.
- **Recommended, same script, +1 h:** publish the full source tile as a COG too
  (`gebco_2025_sub_ice_n90_w180_e90_cog.tif`, ~450 MB, streamed, never downloaded whole), and let
  `release_database.qmd` fall back to `/vsicurl/` on it when `CALCOFI_GEBCO_TIF` is absent — the release then runs
  on any machine, and `cc_bathy(remote = TRUE, extent = "full")` answers the far field too. The `depth_coverage`
  chunk reports the remaining `seafloor_depth_m` `NULL`s **by cause** (no coordinates · NaN · outside the source
  tile) and fails on any positioned sample inside the tile that is `NULL`, so a regression of this kind cannot ship.

### D30 · storage.calcofi.io — the bucket card lands on the bucket

`scripts/build_storage_index.R` gives each bucket an `entry`; `calcofi-db`'s is `ducklake/releases/`, so the root
page's card skips the bucket's own listing — the page that shows `bathymetry/`, `ducklake/`, `erddap/`, `ingest/`,
`pg/`, `publish/`, `qc/` and already exists at `storage.calcofi.io/calcofi-db/`. That is how `bathymetry/` looked as
if it did not exist. Change: `entry = ""` for every bucket (a card lands on the bucket root; `releases` keeps its
header link and a *start here* link in the card text), and the bucket-root page gains a third column — a
one-line note per top-level folder from a `folders =` field in `BUCKETS` (`ducklake/` "releases + the
content-addressed `tables/` store — start at `releases/`", `bathymetry/` "GEBCO 2025: the consumers' crop, the
terrain + contour PMTiles, `gebco_2025.json`", `ingest/` "per-dataset parquet shards + sidecars", `erddap/`,
`publish/`, `qc/`, `pg/`, `gcloud/`). Re-run after slice 1's upload (write credentials — Ben's laptop, as the
script says); the walker picks the new `bathymetry/` objects up by itself.

**A timestamp on every row** (Ben, 2026-08-31). The XML `ListBucketResult` the lister already reads carries
`<LastModified>` per object; `gcs_list_all()` just never parsed it. Add it as a third column: an object shows its
`LastModified`; a folder shows **modified** (its newest object) and, in the cell's title and as a muted second
line, **since** (its oldest — for our write-once objects that is when the folder was started; the XML API has no
`timeCreated`, so this is the honest name). Zero extra requests. The example that prompted it:
`calcofi-db/gcloud/tmp/parallel_composite_uploads/see_gcloud_storage_cp_help_for_details/` holds **79 orphaned
chunks, 19.6 GB**, from three interrupted `gcloud storage cp` parallel composite uploads — 17 parts on
2026-02-24, 57 on 2026-03-13, 5 on 2026-06-06 — nothing since, so nothing was resuming them; **Ben deleted
the prefix on 2026-08-31** (`gcloud storage rm -r gs://calcofi-db/gcloud/`), so the bucket page's `gcloud/` row is
stale until the next index run. To stop it recurring, a bucket
**lifecycle rule** that deletes `gcloud/tmp/` objects older than 7 days (`gcloud storage buckets update
gs://calcofi-db --lifecycle-file=…`, matched on the prefix) — optional, 15 min. ~2.5 h in all.

## Architecture (what changes)

```
GEBCO 2025 sub-ice (local, 933 MB)                    metadata/spatial_layers.csv ─┐
   │  workflows/scripts/build_bathymetry_tiles.py                                  │
   │  (clamp ≤0 · [OSM land mask] · per-zoom resample → terrain-RGB → MBTiles       │ ingest_spatial.qmd (unchanged)
   │   → pmtiles convert;  gdal_contour → tippecanoe → pmtiles)                      ├─► gs://calcofi-files-public/_spatial/*.pmtiles
   ▼                                                                                 │
gs://calcofi-db/bathymetry/gebco_2025_calcofi_terrain.pmtiles  (+ _far)             │ release_database.qmd · browser_objects
                            gebco_2025_calcofi_contours.pmtiles                     └─► calcofi4db::build_spatial_layers()
                            gebco_2025_calcofi.tif  (re-cut: −165→−105 × 15→56, COG)      → {release}/spatial_layers.json
                            gebco_2025_sub_ice_n90_w180_e90_cog.tif  (full tile, streamed)
                            gebco_2025.json
        │  ← calcofi4r::cc_bathy() (download+cache, or /vsicurl/) · release depth_coverage fallback
        │                                                                                     │
        └──────────────── pmtiles:// (range requests, CORS) ───────────────┐                  │ fetch (sidecar)
                                                                           ▼                  ▼
                                   explore · src/basemap.ts  composeStyle(theme, layersState)
                                     CARTO style ⊕ gebco (raster-dem) ⊕ gebco-contours ⊕ boundary sources
                                     layers after `water`: relief · shade · contour · contour-label · boundaries
                                          │ setStyle(diff)                      ▲
                                   src/map.tsx MapView                          │ URL  bathy= bathyo= layers=
                                   src/layers.tsx  the Layers card + legend block  (src/state.ts Sel)
```

**`workflows`**
- `scripts/build_bathymetry_tiles.py` (Homebrew python3 + `osgeo`; Appendix C): idempotent on the source
  sha256 + parameters; writes to `~/_big/calcofi/bathymetry/` (bulk outputs outside the repo, as `cc_stage_dir()`
  does for parquet); writes the terrain/contour/far archives, the re-cut crop COG, the full-tile COG and
  `gebco_2025.json`; `--upload` runs `gcloud storage cp` to `gs://calcofi-db/bathymetry/`, then
  `Rscript scripts/build_storage_index.R` (D30). A short *Bathymetry* section in `CLAUDE.md`
  (source download URL, the command, what the JSON records, "re-crop `gebco_2025_calcofi.tif` to the same box
  when the R consumers next need it — one extent for every consumer").
- `release_database.qmd`: `build_spatial_layers()` in `browser_objects`; the file in the three sidecar lists;
  `depth_coverage` falls back to the streamed full-tile COG when `CALCOFI_GEBCO_TIF` is absent and reports the
  `seafloor_depth_m` `NULL`s by cause (D29).
- `scripts/build_storage_index.R`: `entry = ""` + the per-folder notes (D30).
- `metadata/spatial_layers.csv`: unchanged; Erin's future rows arrive through `ingest_spatial` as today.

**`calcofi4r`** (`R/transect.R`, D29): `cc_bathy()` size-checked cache refresh + `remote =` (+ `extent = "full"`);
`cc_bathy_depth()` off-extent warning; three tests against the published crop's bbox from `gebco_2025.json`; NEWS +
version bump. ctd-transects' `build_station_bathymetry.R` and ctd-viz need no change (same name, same conventions).

**`calcofi4db`** (`R/explore.R`): `build_spatial_layers(con, registry_csv, version, pmtiles_base)` + a testthat
fixture (a 3-row registry against a tiny `spatial`: counts, `names` cut-off at 200, the filter expression passed
through verbatim); NEWS + version bump.

**`explore`**
- deps: `pmtiles` (+ `maplibre-contour` for the spike only).
- `src/basemap.ts` — `composeStyle()`, the CARTO fetch/cache, the ramps and shading per theme, the boundary
  layer factory (fill + line for polygons, line for lines, circle for points; `filter` from the registry;
  `source-layer` = `dataset_group`), the layer-id vocabulary (`gebco-*`, `sp-{slug}-fill|line`); `VITE_BATHY_URL`
  (default `https://storage.googleapis.com/calcofi-db/bathymetry/`; a local build during development).
- `src/state.ts` — `Sel.bathy`, `Sel.bathyo`, `Sel.layers: LayerStyle[]`; parse/format per Appendix A; the
  `LAYERS` constant replaced by the sidecar-driven region list.
- `src/map.tsx` — `MapView` takes `style` instead of `theme`; `setStyle(diff)`; the post-`load` DEM add; the
  boundary hover; MapLibre `error` events on missing tiles ignored for our sources.
- `src/layers.tsx` — the Layers card body (the *On the map* list with its pointer-handler drag reorder and ▲ ▼,
  the *Add a layer* groups), the swatches/palettes, the legend block; `src/icon-paths.ts` +
  `brand/v1/icons/` gain `ui-map-layers` (`scripts/build_icons.mjs`).
- `src/App.tsx` — `CardId "layers"`, the `.map-tr` button, `titles`/`icons`/`cardBox`/pills/sheet wiring, the
  sidecar fetch (`spatial_layers.json` → fallback), the About paragraph, the stamp, the tour step (`tour.ts`).
- `scripts/verify.mjs` — the states in Appendix D; `scripts/dev_spatial_layers.R`.
- `README.md` — a *Map layers* paragraph (URL params, where the tiles come from, how to rebuild).

## Phases (each shippable on its own)

| # | slice | deliverable | acceptance | h |
|---|---|---|---|---|
| **0** | **Spike** (½–1 day) | the terrain archive over the wide box (mapbox encoding), a throwaway branch of `explore` drawing `color-relief` + `hillshade` from it behind `?bathy=`; the contour archive at three levels; `maplibre-contour` tried against the PMTiles; the z11 coast seam with and without the OSM land mask; archive sizes; `first_paint` / `first_lens_ready` before and after | numbers in *Measured*; Ben picks the shading method, ramp direction, the land-mask option, and whether B′ replaces B | 6 |
| **1** | **Bathymetry build + the crop + the index** (D21 · D29 · D30) | `build_bathymetry_tiles.py` (terrain core + far, contours, the re-cut crop COG, the full-tile COG, `gebco_2025.json`) + upload; the calcofi4r patch (`cc_bathy()` refresh / `remote =`, `cc_bathy_depth()` warning, tests, NEWS); the release `depth_coverage` fallback + NULL-by-cause report; `build_storage_index.R` `entry = ""` + folder notes, re-run; `CLAUDE.md` section; `verify_bathymetry_tiles` (re-run reproduces the archive's tile count and a sample of tile sha256s) | `pmtiles show` + `pmtiles verify` clean; the JSON complete; a `pmtiles://` source from GCS renders in a plain MapLibre page; `cc_bathy_depth()` reads a finite depth at every released bottle/PIC/CUFES/dungeness position (0 `NA`), and warns on the ichthyo far field; ctd-transects' `build_station_bathymetry.R` reproduces `line_bathymetry.csv` byte-for-byte on the new crop; `storage.calcofi.io/` → `calcofi-db` card → the bucket listing with `bathymetry/` on it, every row dated | 15 |
| **2** | **Explorer · sea floor** (D21 · D22 · D26 · D27) | `basemap.ts`, composed styles, the `bathy`/`bathyo` params, the Sea-floor half of the Layers card, the legend row, attribution + About + stamp, verify states, two card shots re-taken (`card_shots.mjs`) | both themes pass the luminance and known-pixel probes (Santa Cruz Basin vs the shelf vs flat water); `first_paint` within +50 ms of today; the phone states pass; `?bathy=off` reproduces today's map | 12 |
| **3** | **Explorer · boundaries + symbology + order** (D23 · D24 · D25) | `build_spatial_layers()` + release wiring + `dev_spatial_layers.R` + fallback; the `layers=` grammar; the *On the map* list with drag / ▲ ▼ reorder and the *Add a layer* groups; palettes; hover; the region-lens outline rule; the data-driven region list; tour step; verify states | every registry layer draws from its archive; a `layers=` round-trip is exact, order included; dragging a row flips which fill wins in an overlap (pixel probe) and rewrites the URL; the legend block and the map PNG match; the sheet works on the 390-px states with ▲ ▼; `test_release` untouched (the sidecar is not a table) | 18 |
| **4** | **3-D** (optional, D28) | a `view=3d` spike branch: `setTerrain`, exaggeration control, pitch; the deck alignment test | pass → ship behind the toggle; fail → a *Measured* note and the item closed | 8 |

Order: 0 → 1 → 2 → 3 (→ 4). Slice 2 is useful on its own — the sea floor under every lens — and slice 3 needs
nothing from a release to ship (the fallback snapshot carries the registry until `spatial_layers.json` is cut).

## Measured (appended per slice as it ships)

### Phase 0 · spike, 2026-08-31 — the build side

Built with `workflows/scripts/build_bathymetry_tiles.py` (Homebrew python 3.14 + osgeo, GDAL 3.11.5, tippecanoe 2.79, the
`pmtiles` CLI); every output under `~/_big/calcofi/bathymetry/` (`work/` holds the intermediates), **nothing uploaded**, the
published `gebco_2025_calcofi.tif` untouched. Source sha256 `5cdb6910…6551a`. Prep (clamp ≤ 0 + the depth raster over the
whole 21,600² tile) takes 5 s; the unmasked run with both encodings 8.2 min, of which PNG encoding at zlib level 9 is ~85 %
(z8's 1,014 tiles × 2 encodings = 409 s); the masked run (one encoding) 3.9 min including 61 s to burn the OSM land polygons
(`land-polygons-split-4326`, 926 MB zip, cached under `src/`).

**The tile grid (512 px).** Far tier z0–5 over lon −180→−90 × lat 0→60: 1 · 1 · 1 · 4 · 16 · 56 = **79 tiles**, `average` at every
zoom. Core z6–8 over −140→−105 × 15→56: 77 + 260 + 1,014 = **1,351** — `average` at z6–7, `bilinear` at z8 (305.7 m/px against
GEBCO's 463.8 m cell). 1,430 tiles in the sparse archive, 1,394 in the two-archive core (z0–8 ∩ the core box), 79 in the far one.
Ten random z8 tiles decoded back: round-trip error ≤ 0.051 m (mapbox) / ≤ 0.5 m (custom) — exact to each encoding's step — and the
tile centres sit within 2 m of the source's nearest cell except one abyssal-hill tile at 14 m (bilinear vs nearest, expected).

| artefact | mapbox · 0.1 m | custom · 1 m | notes |
|---|---|---|---|
| sparse — far z0–5 + core z6–8 in one file | **293.0 MB** | **159.6 MB** | per zoom: z8 193 / 97 MB (191 / 95 KB a tile) · z7 58 / 34 · z6 18 / 12 · z5 18 / 13 · z0–4 7 / 5 |
| core — z0–8 over the core box | 279.6 | 150.2 | |
| far — z0–5 | 24.7 | 17.6 | |
| sparse + the OSM land mask (+1 m) | 292.8 | — | the mask changes the bytes by 0.07 % |
| `…_contours.pmtiles` — z0–10, 30,808 tiles | 43.3 MB | | 37,987 core lines at the 15 levels + 26,983 far lines (≥ 500 m, ≥ 0.05° long, the core box blanked to NoData so the two tiers meet, not overlap); the per-zoom gate is tippecanoe's `-j` on `level`. **Trap:** `-j` silently drops every feature whose attribute is integer-typed (`Warning: mismatched type in comparison`, 0 tiles out) — `ele` and `level` are written as doubles |
| `gebco_2025_calcofi.tif` re-cut (D29) | 129.4 MB | | −165→−100 × 15→56 · 15,600 × 9,840 px · Int16 · COG (DEFLATE 9, predictor 2, 512-px blocks, 5 average overviews) · reads 6,311 m at (−150, 30), 0 m at (−128, 54) — that check point is inland BC, so 0 is right — and 983 m at (−119.7, 33.9), each equal to the source; **identical to the published crop on all 5,316,500 of its cells** (grid-aligned), so ctd-transects' `line_bathymetry.csv` cannot move |
| `gebco_2025.json` | 20 KB | | source + sha256, each artefact's bbox / zooms / encoding / bytes / checks, GDAL + tippecanoe versions |

The 0.1 m mapbox encoding is the size driver: its low byte is noise on a smooth sea floor, so the PNGs compress half as well
(191 vs 95 KB a tile at z8). That is over the plan's ~120 MB trigger, so **custom 1 m is the build to keep** — with one caveat
for the B vs B′ decision: `maplibre-contour` 0.1.0 decodes `mapbox` / `terrarium` only, so choosing B′ means keeping the
mapbox archive (or contributing a `custom` decoder). The crop lands at the top of its 60–120 MB estimate. Storage is not the
constraint either way — a view fetches its dozen tiles (measured below).

### Phase 0 · spike, 2026-08-31 — the browser side

Throwaway branch `spike/bathy-layers` in the worktree `~/_big/calcofi/explore-bathy` (from `58e940c`; `src/bathy.ts` +
`bathy=` threaded through `Sel`/`MapView`; `scripts/spike_bathy.mjs` drives 39 states, screenshots to `shots/bathy/` and
`shots/bathy_v1/`, pixels read from the MapLibre canvas, tiles counted in the `pmtiles` protocol; `pmtiles` 4.5.0 and
`maplibre-contour` 0.1.0 installed). The layers are added after the first `load` and re-added on every `style.load`, so
`first_paint` does not wait for DEM tiles (D22's rule); production build served by `vite preview` on 5179, timings from
`verify.mjs … --timing=1` (a bare `--timing` parses to `undefined` and runs nothing — the README's command never ran the
timing block; the branch's copy also saves per run, because the `warm` run has failed on `grain_switch` since the welcome
card arrived when the states are skipped).

- **Tiles per view.** At `MAP_HOME` (z5.1, 1280 px) the map fetches **4 DEM tiles at z5 + 4 contour tiles = 2.10 MB**
  (mapbox; 1.70 MB with the custom archive; DEM alone 1.49 / 1.09 MB, contours alone 0.61 MB) — the plan's "~12 tiles" was
  for 256-px tiles. The relief is applied ~10 ms after `load` and its tiles are in ~310 ms later (median of the home states;
  0.6–1.1 s after `t0`). A z11 coast view fetches 1 z8 DEM tile + 2 contour tiles (0.27 MB); z9 over the basin 2 + 4 (0.64 MB).
  The phone viewport fetches the same 4 + 4.
- **`first_paint` / `first_lens_ready`, before → after** (`verify.mjs` single cold samples): cold 414 → 507 ms / 41 → 42;
  env 411 → 339 / 229 → 221; phone 559 → 427 / 40 → 36. Across the spike's 32 desktop states with the sea floor on,
  `first_paint` has median **334 ms** (248–514) against 242 / 269 / 334 with it off — inside run-to-run noise, no regression,
  as the construction guarantees. `?bathy=off` reproduces today's map pixel-for-pixel at the probes (44,53,60 water · 14,14,14
  land on dark; 212,218,220 · 250,250,248 on light).
- **One sparse archive: no.** With the z6–8 children absent outside the core, MapLibre fetches the missing z7 tiles (6
  requests, 0 bytes) and draws **nothing** — the far probe at (−150, 45) reads CARTO's water (44,53,60) — and the map never
  becomes idle (`loaded()` stays false, the `idle` event never fires) because the `pmtiles` protocol answers a missing raster
  tile with `data: null`, which `RasterDEMTileSource.loadTile` leaves in the `loading` state for ever. `errorOnMissingTile`
  (`src:serr`) errors the tiles instead and changes nothing visible: MapLibre only ever *retains* a parent that is already in
  its cache, it does not fetch one as a fallback. **Two archives, two sources** (`gebco-far` under `gebco`): the same z7 view
  draws the far tier's one z5 tile overzoomed (probe 27,34,45, settled in 0.6 s). This is the plan's fallback; take it.
- **Hillshade methods** (dark, at the abyssal-plain probe, ramp a): `multidirectional` and `basic` add an ambient wash on
  *flat* ground — the plain reads 39,49,63 against 18,25,36 under `standard` / `igor` / `combined`, the whole basemap's mean
  luminance 62 vs 42, and flat *land* is tinted too (39,43,48 with the hillshade alone, CARTO's land is 14,14,14).
  `igor`/`standard`/`combined` leave flat ground alone and give the crisper relief (`shots/bathy/home_igor_dark.png` vs
  `home_dark.png`); `basic` is pixel-identical to `multidirectional` here. **Recommend `igor`** (or `standard`); exaggeration
  0.5 vs 0.8 is barely distinguishable at z5.
- **The ramp had a bug the pixels found.** Land is clamped to *exactly* 0 m and the transparent stop sat at +0.5 m, so
  `color-relief` painted every land pixel with the 0 m water colour (dark land 35,41,46; light 224,228,229; ramp b tinted all
  of southern California teal). Fixed in the branch (`-1 → water colour, 0 → transparent`): land is back to 15,15,15 /
  251,251,250. Two ramp notes for slice 2: on **dark**, "end at CARTO's water colour" is wrong-headed — `#2C353C` is *darker*
  than the −50 m shallows, so every shelf shallower than 50 m fades darker toward the coast (the dark rim in
  `seam_lajolla_*_dark.png`); end the dark ramp on the shallow colour and fade to transparent instead. On light the rule is fine.
  Ramp b (indigo → teal) is in the shots for comparison (`home_rampb_*.png`).
- **The z11 coast seam and the OSM land mask** (La Jolla, `shots/bathy/seam_lajolla_{,mask_}{dark,light}.png` after the ramp
  fix, `seam_lajolla_igor_*` under igor; the pre-fix pair is in `shots/bathy_v1/`): with the ramp fixed the mask is
  **indistinguishable at the probes** — shore pixel 41,47,52 vs 43,48,54 (dark, multidirectional), 17,17,18 vs 17,18,19 (dark,
  igor), 252,252,250 vs 248,248,247 (light) — and the two screenshots differ only in a sub-cell fringe. GEBCO's 460 m cells
  are what one sees at z11 either way (bilinear blur, not a hard edge). **Recommend no mask**: the 926 MB download and the
  extra build minute buy nothing once the ramp is right. Monterey (`seam_monterey_*`) says the same.
- **B′ — `maplibre-contour` reads the PMTiles, on the main thread.** Its worker route fetches by URL template and cannot
  see a MapLibre protocol, but `DemSource({worker: false})` exposes `manager.getTile`, and a hook that calls
  `PMTiles.getZxy()` and returns the PNG as a `Blob` works: at z9 it drew 146 line features from 2 DEM tiles (the archive
  draws 78 at that zoom with its own thinning), 125 ms per contour tile; at home 202–235 ms per tile (4 tiles), 0 errors,
  no extra bytes (`shots/bathy_v1/z9_basin_live_dark.png` vs `z9_basin_dark.png`). Costs: main-thread only (that is
  200 ms of jank per tile at the home zoom on this laptop, more on a phone), `mapbox`/`terrarium` encodings only (so B′ ties
  the build to the 293 MB archive, not the 160 MB one), no labels or `level` classes beyond its per-zoom thresholds.
  **Verdict: B stays primary** (deterministic, 43 MB, labelled, phone-safe); B′ is proven feasible if ever wanted.
- **Theme flip** re-adds the layers (probes after the flip equal a fresh load of the other theme) but re-fetches the 4 + 4
  tiles, since `setStyle` drops the sources — D22's composed style + `diff: true` is what avoids that.
- **Legibility notes for slice 2:** at z5 the 500 m-multiple contours show 4,051 features over the abyssal plain (every 4,000 /
  4,500 m ring around every abyssal hill — the ripple texture in the home shots); consider level 3 only below z6 and no
  4,500 m line. The busy relief under viridis dots reads better with `igor` at 0.7 than with the default; the contour
  labels (`Montserrat Regular` from CARTO's glyphs) place cleanly from z8.

### Phase 0 · spike, 2026-08-31 evening — the contour-contrast calibration, under brand v2 (Ben's follow-up)

Ben's read of the first shots: **`igor`, but its dark contours have too much contrast** (light is about right) — the sea
floor must be *visible without drawing attention from the plotted data* — and judge it under **brand v2**, the likely
theme. So the spike gained `c:<alpha>` (contour line alpha, default 0.3) and `cw:<factor>` (width), was rebuilt with
`VITE_BRAND=v2`, and re-shot into `shots/bathy_v2/` (25 states; the earlier runs are v1 in `shots/bathy{,_v1}/`):

- **Dark, igor, contour alpha:** `0.3` (current default) is the loud one Ben flagged — the abyssal ripple competes with
  the dots (`cal_home_igor_c030_dark.png`). **`0.15` is the recommendation**: the shelf and canyon lines still read, the
  plain settles under the data (`…c015…`); `0.1` is near-silent in the plain but the shelf starts to fade (`…c010…`);
  `0.15` + width × 0.7 sits between them (`…c015_cw07…`). At z9 the 500 m labels still read at 0.15
  (`cal_z9_igor_c015_dark.png`). Mean canvas luminance 35.4 → 32.6 → 31.6 across 0.3 / 0.15 / 0.1.
- **Light needs no change** (Ben: "about right"): igor at 0.3 on light (`cal_home_igor_light.png`); 0.2 is in the shots
  for comparison (`cal_home_igor_c020_light.png`). If symmetry is wanted, 0.2 light / 0.15 dark are the pair.
- **Data legibility check:** the Hexagons lens over the calibrated layer (`cal_hex_igor_c015_dark.png` /
  `cal_hex_igor_light.png`) — the hex fill covers the relief entirely where data exists; the sea floor shows only around
  the survey's margins, which is the intended reading.
- Under v2 the map itself is unchanged (same CARTO styles; v2 swaps the chrome, fonts and light default), so the v1
  measurements above carry over; v2 light with the full-opacity ramp is noticeably more saturated than the v2 chrome —
  worth revisiting `color-relief-opacity` on light (~0.8) when the ramps are tuned in slice 2.

**Slice-2 defaults this sets (pending Ben):** `hillshade-method: igor`, contour line alpha 0.15 dark / 0.3 (or 0.2)
light, relief opacity 0.7 dark / 1 (or ~0.8) light, ramp a with the transparent stop at 0 m and the dark shallow end
re-ended on the shallow colour.

**The theme-in-the-URL gap** (Ben, same review: "selected theme does not carry over into the shared url, maybe by
design?"): not by design — `README.md` already claims the URL carries the theme, but `toUrl` only echoes an incoming
`?theme=` (`state.ts:181`) and the header toggle (`cc:theme` → `setTheme`, `App.tsx:161`) never writes `sel.theme`, so a
toggled theme is absent from a share link. Fix is one line (`setSel({ theme: e.detail.theme })` in the listener), with
one consequence to accept first: the brand contract persists a link's `?theme=` onto the visitor's fleet-wide `cc_theme`
cookie, so every shared Explorer link would then set the recipient's theme everywhere. Options: accept (URL = whole
view, README already says so) or drop the param from `toUrl` and fix the README. **Pending Ben; belongs to slice 2's
`bathy=`/`layers=` URL work either way.**

**Decisions this leaves to Ben** (the plan's open questions 3–4 plus what the spike raised): shading method (recommend
`igor`), the dark ramp's shallow end (recommend: end on the shallow colour, transparent at 0), the mask (recommend none),
B vs B′ (recommend B), encoding (recommend custom 1 m, unless B′), one vs two archives (two — not a preference, a finding).
Nothing is uploaded; slice 1 runs `build_bathymetry_tiles.py` once more with the chosen options and `--upload`.

### Slice 1 · executed 2026-08-31 (Ben: "Looks good! Please proceed")

Shipped to **`gs://calcofi-db/bathymetry/`** (all sha256s in `gebco_2025.json`):
`gebco_2025_calcofi_terrain.pmtiles` (core z0–8, custom 1 m, 150.2 MB) · `…_terrain_far.pmtiles` (z0–5, 17.6 MB) ·
`…_contours.pmtiles` (43.3 MB) · `gebco_2025_calcofi.tif` (the D29 crop, Int16 COG, 129.4 MB, same name/URL) ·
`gebco_2025_sub_ice_n90_w180_e90_cog.tif` (the full tile as raw elevation, 439.0 MB) · `gebco_2025.json`.
`--steps ship` assembles exactly that set (custom core/far under the final names), `--steps verify` re-derives a random
sample of shipped tiles straight from the source — 12/12 byte-identical — and `--upload` copies only the ship list.

- **`cc_bathy_depth()` coverage gate: PASS, wider than promised.** Against the released v2026.08.25 `sample`
  (1,461,334 positioned rows), the new crop reads a real depth at **every position of every dataset** — bottle 931,015,
  PIC 82,343, CUFES 48,009, dungeness 2,316, DIC, euphausiids, zoodb, zooscan, mets, ctd-cast, farallon, mesopelagic,
  phyllosoma, phytoplankton, picoplankton: **0 NA each** — except `swfsc_ichthyo`'s known 5,703 far-field /
  bad-coordinate rows (lon −179.8 → −77.2, lat to 0.0), which now **warn** with count and bbox. calcofi4r 1.16.0
  (committed locally, not pushed): self-refreshing cache (size-checked HEAD), `remote =`, `extent = "full"`,
  the warning; `cc_transect_bathy()` keeps its documented silent-NA contract. Full test suite green.
- **The release runs anywhere** (calcofi4db 3.27.0, committed locally): `sample_seafloor()` accepts `/vsicurl/`,
  `release_database.qmd` falls back to the published full-tile COG when `CALCOFI_GEBCO_TIF` names no local file, and
  `check_seafloor_nulls()` classifies every NULL seafloor by cause — `inside_tile_null` **fails the release**
  (`# Unreleased` entry written). Full test suite green.
- **A plain MapLibre page renders the published archives from GCS** (`gcs_bathy_check.{html,mjs}` in the scratchpad:
  relief + hillshade + contours over both sources, pixel-probed; the pmtiles range-request path needs nothing but the
  bucket's existing CORS).
- **The ctd-transects "byte-for-byte" acceptance met a moving input.** Its `public/data/_grid.parquet` (rebuilt earlier
  on 2026-08-31) now carries **24 lines / 218 stations** where the committed CSVs were cut from 13 partial lines — so
  regeneration adds ~26 k samples (lines 10–55 and 120–160, and full offshore extents) regardless of the crop. On the
  12,590 (line, dist) keys both versions share, **12,582 depths are byte-identical**; 8 differ ≤ 19.1 m at re-anchored
  line ends, and 806 old line-90 keys re-gridded — all grid-change effects, none crop effects (the re-cut crop equals
  the old one on every overlapping cell). The two CSVs were left at HEAD; regenerating them is a grid-shape decision
  for the ctd-transects repo, not this slice.
- `CLAUDE.md` gained the Bathymetry section; `scripts/build_storage_index.R` + `libs/gcs_index.R` carry D30 and the
  index was re-run (4,528 pages): the `calcofi-db` card lands on the bucket's own listing (the *start here* link keeps
  `ducklake/releases/`), the bucket-root page carries the per-folder notes column, and **every row is dated** —
  `bathymetry/ · 6 objects · 743.6 MB · 2026-08-31`, `ducklake/ · 36.63 GB · modified 2026-08-25, since 2026-03-14`.
  The first render published a literal `"NA"` note for `ducklake-staging/` (a folder outside the notes map:
  `notes[missing]` is `NA_character_`, which `%||%` does not catch — the `provider.csv` failure mode again); fixed so an
  unlisted folder gets an empty cell, and re-rendered. The optional `gcloud/tmp/` lifecycle rule was NOT added (Ben
  already deleted `gcloud/` outright; add it if the orphaned-chunk pattern returns).

## Risks and what bounds them

- **A theme flip drops the layers.** Today's `setStyle(STYLE[theme])` would silently remove anything added after
  load. D22 puts the layers *in* the style; the verify state `layers_theme_flip` asserts a known pixel after the
  toggle, both directions.
- **First paint regresses.** DEM tiles arrive before the map's `load` if the source is in the first style. D22 adds
  the source after `load`; the `--timing` run is part of slice 2's acceptance.
- **The coast seam** (GEBCO vs OSM coastline). Bounded by the ramp-ends-on-CARTO-water rule; the OSM land mask
  removes the remaining fringe at the cost of one 600-MB download at build time, cached under `~/_big/`.
- **Archive size vs resolution.** If the core at full resolution is too large, the fallbacks in order: custom
  1-m encoding; z0–7 (a ~25 % loss of GEBCO detail, invisible below z9). The two tiers are one sparse archive only
  if the spike confirms MapLibre keeps the parent tile where a child is missing (blank holes otherwise); two
  bounded sources need no such behaviour.
- **A 60–120 MB `cc_bathy()` download.** The price of a crop with no `NULL`s; it happens once per machine and is
  cached, `remote = TRUE` streams instead, and ctd-viz keeps its local file. The size-checked refresh means the
  first call after the re-cut re-downloads — say so in calcofi4r's NEWS.
- **`/vsicurl/` on the CalCOFI server.** Egress-metered; the release's streamed fallback is for machines *without*
  the local tile, and the server's apps never call it.
- **`maplibre-contour` and PMTiles.** Unproven; it is why B (a built archive) is primary and B′ a measurement.
- **Legibility on dark.** A busy relief under viridis dots is the visual risk; the defaults (relief 0.6–0.7, faint
  contours) are set from the spike's screenshots, and a user can turn any part off.
- **Registry ↔ PMTiles skew.** `ingest_spatial` rebuilds archives outside releases. The sidecar carries the
  archives' `built` date; a later step (out of scope) versions the archives under `_spatial/{date}/`.
- **The multi-layer group's `id`.** Background layers never join on it; the Regions lens keeps using
  `spatial.geojson` + `sample_spatial` (exact `spatial_key`), so nothing regresses.
- **deck.gl under terrain** (Phase 4 only). Gated by the acceptance test; nothing in slices 0–3 depends on it.

## Open questions for Ben (each with the recommended answer)

1. **Default view.** Recommended: sea floor **on** (relief + depth colour + contours), **no boundaries** — the
   registry's `default_visible` EEZ is db-viz-hex's default, and one line at the grid's zoom adds little. Or apply
   the registry's default so the two apps open alike?
2. **Extent.** Recommended: tiles in two tiers — core lon −140 → −105 × lat 15 → 56 at full resolution, the whole
   source tile at z0–5 — and the consumers' crop at lon −165 → −100 × lat 15 → 56 (every non-ichthyo position;
   D29). Or should the crop be the core box (~50 MB instead of ~100, leaving 9,492 far-field positions to the
   streamed full tile), or the full tile only (no crop at all — every caller streams or downloads 450 MB)?
7. **The full-tile COG** (D29's recommended extra): publish it, so the release runs on any machine and the far
   field reads a depth? Recommended yes — +1 h and 450 MB of storage.
3. **Contours: built archive (recommended) or live `maplibre-contour`** if the spike shows it works from PMTiles?
4. **The land mask.** Decide from the spike's z11 seam screenshots.
5. **Where the layers live:** a floating card from the map's corner (recommended — the map's decoration belongs to
   the map, and it minimizes to a pill) or a fifth group in the Select rail?
6. **3-D:** spend the 8-h spike, or close D28 as "hillshade is the 3-D"?

## Decided (Ben, 2026-08-31)

Reviewed the same day — *"Looks great!"* — then three additions, all folded in:

1. **Bucket:** everything under **`gs://calcofi-db/bathymetry/`** (first moved to `calcofi-files-public`, then
   reverted — the storage.calcofi.io root page had sent him past the bucket listing, so the folder looked
   non-existent; that is D30).
2. **The crop:** re-cut `gebco_2025_calcofi.tif` so sampling observation positions through
   `calcofi4r::cc_bathy()` never yields `NULL` for want of extent — D29 (lon −165 → −100 × lat 15 → 56, Int16 COG,
   same name; `cc_bathy_depth()` warns on the rest; the release's own sampling already used the full tile).
3. **The index:** `storage.calcofi.io/` → `calcofi-db` should show the bucket's actual contents, and every listing
   should carry a datetime stamp — D30 (which also dates the 19.6 GB of orphaned upload chunks under `gcloud/tmp/`:
   safe to delete).

His earlier review question — several layers at once, ordered by dragging a layer up or down — is D24 *Draw
order* / D25's *On the map* list. The open questions above were not answered and stand on their recommended
answers until he says otherwise.

**After the Phase 0 spike (Ben, 2026-08-31 evening):** "Looks good!" — `igor` it is, with one correction: under igor the
**contours have too much contrast on dark** (about right on light); the sea floor is meant to be *visible but never to
draw attention from the plotted data*. Two additions: judge everything under **brand v2** (the SIO look, light default —
"much more likely to become the new theme than v1"), so the calibration shots below are v2 builds; and he noticed the
**toggled theme does not reach the share URL** — not by design but a gap (`README` says the URL carries the theme;
`toUrl` only echoes an incoming `?theme=`, the header toggle never writes `sel.theme`); the fix is one line, with the
brand-contract side effect that a shared `?theme=` link also sets the recipient's fleet-wide cookie — decision pending.

## Kickoff prompt (a new session — Fable at xhigh; cwd `~/Github/CalCOFI/workflows`, so CLAUDE.md and the memory index load)

> Execute Phase 0 of `.claude/plans/2026-08-31 Explorer map layers — …md`: build the GEBCO terrain-RGB PMTiles
> core over lon −140→−105 × lat 15→56 at z0–8 (512 px, mapbox encoding) plus the far tier (whole source tile,
> z0–5) with `workflows/scripts/build_bathymetry_tiles.py` (Homebrew python3 + osgeo; Appendix C) — test whether
> MapLibre keeps the parent where a sparse archive has no z6–8 child, else keep the tiers as two archives — the
> contour archive at the Appendix levels, the D29 crop COG (−165→−100 × 15→56, Int16; measure its bytes and read
> it back at the three check positions), and on a throwaway branch of
> `~/Github/CalCOFI/explore` draw `color-relief` + `hillshade` from a local copy (`public/bathy/` → `~/_big/calcofi/bathymetry/`,
> `VITE_BATHY_URL=bathy/`) behind `?bathy=`. Measure and append to *Measured*: archive sizes (mapbox vs custom
> 1 m), tiles fetched at `MAP_HOME`, `first_paint`/`first_lens_ready` before/after via `node scripts/verify.mjs
> http://localhost:5179/ shots/prod --timing`, whether `maplibre-contour` reads the PMTiles, and the z11 coast seam
> with/without the OSM land mask (two screenshots each theme). Do not touch `gebco_2025_calcofi.tif` or anything
> the R consumers read. Verify with `verify.mjs` only (the Claude-in-Chrome tab never paints); never edit `src/`
> while it runs. Stop after the numbers and the screenshots — Ben picks the shading method, ramps, mask and B vs B′
> before slice 1.

## Appendix A — the URL grammar

```
bathy=off                      sea floor off
bathy=relief,contours          any subset of relief · depth · contours (default: all three → absent)
bathyo=0.6                     sea-floor opacity 0–1, 2 decimals (default 1 on light, 0.7 on dark → absent)
layers=<entry>[,<entry>…]      visible boundary layers in draw order — FIRST ENTRY ON TOP (the card's list, read down)
  <entry> = slug[:colour][:fill_opacity][:line_width]
  slug          metadata/spatial_layers.csv dataset_id      ca_marine_protected_areas
  colour        hex6 (no #) | pal1 | pal2 | pal3            388e3c · pal1 (by name)
  fill_opacity  0–1 (2 dp; lines ignore)                     0.35
  line_width    0.5–4 px (0.5 steps; points: radius)         1.5
  empty field = the registry default:   noaa_maritime_eez::,ca_marine_protected_areas:pal1:0.35:1
```

Examples: `?lens=hex&taxon=worms:217452&layers=noaa_onms_sanctuaries:pal2:0.25:1.5,noaa_maritime_eez` ·
`?bathy=relief&bathyo=0.4&layers=ca_county_boundaries:f57c00:0:1` (outlines only, no depth colour) ·
`?layers=ca_marine_protected_areas:pal1,noaa_onms_sanctuaries::0.15` (MPAs drawn over the sanctuaries; dragging
the sanctuaries row above the MPAs writes `layers=noaa_onms_sanctuaries::0.15,ca_marine_protected_areas:pal1`).

## Appendix B — the style additions (starting values; tuned in the spike)

```jsonc
// sources
"gebco":          { "type": "raster-dem", "url": "pmtiles://https://storage.googleapis.com/calcofi-db/bathymetry/gebco_2025_calcofi_terrain.pmtiles",
                    "encoding": "mapbox", "tileSize": 512, "attribution": "GEBCO Compilation Group (2025) GEBCO 2025 Grid" },
"gebco-contours": { "type": "vector", "url": "pmtiles://https://storage.googleapis.com/calcofi-db/bathymetry/gebco_2025_calcofi_contours.pmtiles" },
"sp-ca_marine_protected_areas": { "type": "vector", "url": "pmtiles://https://storage.googleapis.com/calcofi-files-public/_spatial/ca_marine_protected_areas.pmtiles",
                    "attribution": "CA Dept of Fish and Wildlife" },
// layers, inserted after CARTO's `water`, in this order
{ "id": "gebco-relief", "type": "color-relief", "source": "gebco", "paint": {
    "color-relief-opacity": 0.7,
    "color-relief-color": ["interpolate", ["linear"], ["elevation"],
      // dark: deep navy → CARTO's water at 0 m           light: steel blue → CARTO's water at 0 m
      -4500, "#060d19", -3000, "#0b1a2e", -2000, "#11284a", -1000, "#183760", -500, "#20466e",
      -200, "#27536f", -100, "#2a5a6f", -50, "#2b5b68", 0, "#2C353C", 0.5, "rgba(44,53,60,0)"] } },
      // light: -4500 "#35638f" -3000 "#4a7aa6" -2000 "#6392ba" -1000 "#7ea8c9" -500 "#98bad5" -200 "#adc8dc"
      //        -100 "#bcd1df" -50 "#c8d6dd" 0 "#d4dadc" 0.5 transparent
{ "id": "gebco-shade", "type": "hillshade", "source": "gebco", "paint": {
    "hillshade-method": "multidirectional", "hillshade-exaggeration": 0.5,
    "hillshade-shadow-color": "rgba(0,0,0,0.55)", "hillshade-highlight-color": "rgba(170,200,230,0.35)" } },  // light: shadow rgba(40,60,80,.45) · highlight rgba(255,255,255,.6)
{ "id": "gebco-contour", "type": "line", "source": "gebco-contours", "source-layer": "contours",
  "paint": { "line-color": "rgba(150,190,220,0.3)", "line-width": ["match", ["get","level"], 3, 1.2, 2, 0.9, 0.5] } },
{ "id": "gebco-contour-label", "type": "symbol", "source": "gebco-contours", "source-layer": "contours", "minzoom": 8,
  "filter": [">=", ["get","level"], 2], "layout": { "symbol-placement": "line", "text-field": ["concat", ["get","ele"], " m"], "text-size": 10 },
  "paint": { "text-color": "rgba(170,200,230,0.8)", "text-halo-color": "rgba(0,0,0,0.6)", "text-halo-width": 1 } },
{ "id": "sp-ca_marine_protected_areas-fill", "type": "fill", "source": "sp-ca_marine_protected_areas", "source-layer": "ca_marine_protected_areas",
  "paint": { "fill-color": "#a5d6a7", "fill-opacity": 0.2 } },                       // by name: ["match", ["get","name"], "Anacapa Island SMR", "#4e79a7", …, "#bab0ab"]
{ "id": "sp-ca_marine_protected_areas-line", "type": "line", "source": "sp-ca_marine_protected_areas", "source-layer": "ca_marine_protected_areas",
  "paint": { "line-color": "#388e3c", "line-width": 1 } }
// a registry `filter_expr` (the maritime lines) becomes the layer's "filter" verbatim; a point layer is one "circle" layer
```

The contour archive's feature attributes: `ele` (m, positive down), `level` (0–3), `tippecanoe:minzoom`.

## Appendix C — `build_bathymetry_tiles.py` (sketch)

```
inputs   GEBCO source tif · bbox (−140,15,−105,50) · zooms 0–8 · tile 512 · encoding mapbox|custom · --land-mask path
steps    1 gdalwarp source → EPSG:3857 VRT clipped to bbox (float32; NaN → 0)
         2 gdal_calc: elev = min(elev, 0); if land mask: rasterize OSM land → elev = 1 where land
         3 for z in 0..8: warp step-2 raster to the zoom's exact tile grid (-te snapped, -tr = 40075016.686/(512·2^z);
             -r average below GEBCO's native zoom, bilinear at/above it) → encode to uint8 RGB
             (mapbox: v = (elev + 10000) / 0.1 → R,G,B = v>>16, v>>8 & 255, v & 255) → gdal raster tile --min-zoom z
             --max-zoom z (or cut 512² windows) → PNG → insert into MBTiles (sqlite, TMS row flip)
             NEVER resample after encoding: an averaged terrain-RGB byte is not an averaged elevation
         4 pmtiles convert out.mbtiles gebco_2025_calcofi_terrain.pmtiles
         5 gdal_contour -fl 50 100 200 300 400 500 750 1000 1500 2000 2500 3000 3500 4000 4500 -a ele (on -elev, or
             negate after) → add level + tippecanoe:minzoom → tippecanoe -z10 -Z0 -l contours --simplify-only-low-zooms
             -o gebco_2025_calcofi_contours.pmtiles
         6 the far tier: steps 1–4 over the whole source tile at z0–5 (one sparse archive, or gebco_2025_calcofi_far.pmtiles)
         7 the consumers' crop (D29): gdal_translate -projwin -165 56 -100 15 → depth = max(-elev, 0) as Int16 →
             gdal_translate -of COG -co COMPRESS=DEFLATE -co PREDICTOR=2 -co BLOCKSIZE=512 -co OVERVIEWS=AUTO
             → gebco_2025_calcofi.tif (same name; NoData off-extent only); the full tile → gebco_2025_sub_ice_n90_w180_e90_cog.tif
         8 write gebco_2025.json {source, sha256, per artefact: bbox, zooms, tile_size, encoding, land_mask, levels, bytes,
             built, gdal, tippecanoe, citation, licence}; --upload → gcloud storage cp to gs://calcofi-db/bathymetry/;
             then Rscript scripts/build_storage_index.R
checks   pmtiles verify; tile count == expected; decode 5 random tiles and compare to the source at their centres (< 1 m);
         the crop read back at (−150, 30), (−128, 54), (−119.7, 33.9) matches the full tile within 1 m; gdalinfo says COG
```

## Appendix D — verify states (`scripts/verify.mjs`)

`layers_default_dark` · `layers_default_light` (luminance + pixel probes at Santa Cruz Basin ~(−119.7, 33.9), the
shelf off Pt. Conception, and open water outside the tiles' bounds) · `layers_theme_flip` (probe after toggling,
both directions) · `layers_bathy_off` (matches today's `station_default` shot) · `layers_card_open` ·
`layers_mpa_palette` (`?layers=ca_marine_protected_areas:pal1`, a probe inside two MPAs differs) ·
`layers_url_roundtrip` (set three layers with styles in the card, read `location.search`, reload, compare the
style diff) · `layers_reorder` (MPAs + sanctuaries both on; probe a pixel inside an MPA that lies within a
sanctuary; drag the sanctuaries row to the top — the probe changes to the sanctuary fill and the URL's entry
order flips; ▲ ▼ do the same on the phone state) · `layers_region_outline` (Regions lens + the same layer visible → no double fill) ·
`layers_hover` (tooltip text `name · layer`) · `layers_map_png` (`window.__figure("map","png")` non-blank, legend
block present) · `phone_layers_sheet` (390 × 844: the card opens as a sheet, every control in view) · the
`--timing` run (`first_paint`, `first_lens_ready` within budget).

## Appendix E — sources

- `explore/src/{map,App,state,panels,ui,capture,release,brand}.tsx|ts` @ `58e940c`; `explore/README.md`;
  `explore/.github/workflows/pages.yml`
- `workflows/ingest_spatial.qmd` (PMTiles + parquet outputs, tippecanoe flags), `metadata/spatial_layers.csv`,
  `metadata/release_columns.csv` (`spatial`, `spatial_attribute`), `release_database.qmd` ~1443–1479 / 1818 / 2028
  (browser sidecars), `calcofi4db/R/explore.R` (`build_*`), `calcofi4db/R/depth.R`, `calcofi4r/R/transect.R`
  (`cc_bathy()`), `apps/ctd-viz/prep_db.R` (the crop), `ctd-transects/scripts/build_station_bathymetry.R`
- `gsutil ls/cors` on `calcofi-files-public/_spatial/` and `calcofi-db/bathymetry/`; `pmtiles show` on two archives;
  a ranged GET (206); the CARTO style JSONs (layer order, colours)
- `node_modules/@maplibre/maplibre-gl-style-spec` + `maplibre-gl/dist` (5.24: `color-relief`, `hillshade-method`,
  `terrarium`/`custom` encodings); `npm view pmtiles` (4.5.0), `maplibre-contour` (0.1.0) + its README/`dem-source.ts`
- workflows#54 (closed); plans `2026-08-28 CalCOFI Explorer …` (D7, the 3-D note) and `2026-08-29 … UI …` (D11,
  D17, D19)
- GEBCO Compilation Group (2025) GEBCO 2025 Grid, sub-ice topo/bathy, https://www.gebco.net/ ; OSM land polygons
  https://osmdata.openstreetmap.de/data/land-polygons.html
