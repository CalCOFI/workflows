# Explorer Contours lens — an interpolated surface with its error, the data layer's ramp and order, and the transition audit

**Status:** proposed 2026-09-07 and **DECIDED the same day** (Ben: kriging default · `ice` for oxygen · the cast
grain as the default if fast enough · retire `app.calcofi.io/contour` · "finish the slices and ship"); **all slices
executed 2026-09-07** — see *Decided* and *Measured* at the end ·
**Date:** 2026-09-07 · **Scale:** one repo (`CalCOFI/explore`: three new modules — `contour.worker.ts`,
`contour.ts`, `ramps.ts` — and edits to `state.ts`, `map.tsx`, `App.tsx`, `sentence.tsx`, `layers.tsx`,
`sql/station.sql`, `sql/cruise_track.sql`); no release change, no server; ~14 h spent, ~24 h left across three slices.
Decision numbering continues from the 2026-08-31 map-layers plan (D21–D30): **D31–D42**.

## The ask (Ben, 2026-09-07)

1. The superseded **Contour Explorer** (`app.calcofi.io/contour`, `apps/oceano`) reads the legacy PostgreSQL. Can a
   **Contour lens** join the Explorer? `ctd-transects` draws something like it, but *"it is very unclear from a
   simple mean value what underlying data contributes and what kind of error surface would be generated from a
   geostatistical surface like kriging, IDW or GAM"*. Wanted: an **error surface, observation density, min/max
   year, 5/95 % bounds**. Open question: **JavaScript only, or a server API to crunch and report back?**
2. **Clarify the animations** between lenses — distracting or helpful? The **cruise animation draws extra segments**
   along the track between points.
3. The **hexagon size** control as a **slider with ticks on the H3 resolutions**, reporting the rough size, *smaller
   and less imposing*.
4. (mid-session) **Turn the data layer on/off, change its colour ramp, and move it up or down** relative to the
   other layers in the Layers control.
5. (mid-session) Colour schemes **borrowed from cmocean, oce's `oceColorsGebco()`, pals** (and the matplotlib /
   PyVista / oceans catalogues of the same ramps).

## Context — what exists (read 2026-09-07; `explore` @ `d7cd898`)

- **`apps/oceano`** (879 lines, Shiny + Leaflet): `get_points()` aggregates `ctd_casts ⋈ ctd_bottles (⋈ ctd_dic)` per
  cast in SQL, then `calcofi4r::pts_to_rast_idw()` → **`terra::interpIDW(radius = 1.5, power = 1.3, smooth = 0.2)`**
  on a ~100-px grid clipped to an AOI, cached as `idw_{hash}.tif` under `/share/data/cache_idw`, contoured by
  `stars::st_contour` on `classInt` "pretty" breaks into Leaflet polygons. Controls: variable (`field_labels`),
  depth range, season, date range, AOI (preset `places` or drawn), aggregate avg/min/max/stddev. **No error
  surface, no density, no years.** Unused in the package beside it: `calcofi4r::pts_to_contours_gam()` —
  `mgcv::gam(v ~ s(lon, lat, k = 60), method = "REML")` + `isoband`.
- **`ctd-transects`** interpolates nothing: it ships the station × depth matrix and lets Plotly's `zsmooth: "best"`
  resample it (the `MBA::mba.surf()` of `ctd-viz` has no JS port). Its anomaly is a plain difference from the
  release `climatology` table.
- **The Explorer** already has the input the Contour Explorer lacked: the **Stations lens table** (`sql/station.sql`:
  per `grid_key` `n`, `n_samples`, `mean`, `med`, `y0`, `y1` under every filter — years, season, depth band,
  datasets, stage and denominator for biology). The 2026-08-28 plan's Phase 4 already said *"contour-as-rendering
  on the Stations lens (IDW in-browser) so `oceano` can be archived"*, and the brand sprite has carried a
  `lens-contours` glyph since 2026-09-06. The **grain caveat** stands (memory `grid-key-cells-hold-several-stations`):
  a nearshore `grid_key` cell holds 2–4 real stations, so a surface over the station table is only as fine as that
  grid until the station table keys on `site_key`.
- **The cruise track** (`sql/cruise_track.sql`) was every root sampling event of the cruise ordered by `datetime`.
- **Transitions** (`map.tsx`): the 218 station dots are the *morph carrier* — on a lens change their positions and
  colours tween over 700 ms (cubic-out) to the hexagon centres / the region centroids while hexagons and polygons
  cross-fade in from transparent; on opening, the URL's lens follows the stations after 900 ms. The cruise
  playback is a `requestAnimationFrame` loop calling `setTime()` — a full `App` re-render per frame while the lens
  is open. `prefers-reduced-motion` zeroes every duration.
- **The Layers card** (`layers.tsx`, D24–D26) holds the sea floor and the boundary layers with symbology and drag
  order — *the data layer is not a row in it*: it is deck.gl's own canvas, drawn above every MapLibre layer
  because the overlay is non-interleaved (D22).

## The take — JavaScript only; no server

**The station grain is small enough that every method Ben named runs in the browser in well under a second**, and
the numbers that matter for the decision are these (plain JS, typed arrays, one thread, an 8-core laptop; the
script is the spike's benchmark, the app's worker is the same code):

| input | grid (cells within 60 km of a point) | IDW | ordinary kriging, value | + kriging SD | thin-plate spline (9 GCV fits) |
|---|---|---|---|---|---|
| 213 station means (temperature 0–10 m) | 0.1° · 16,790 | 9 ms | ≈ 25 ms | 0.9 s | 0.23 s |
| 213 station means | 0.05° · 67,155 | 25 ms | ≈ 60 ms | 3.4 s | 0.49 s |
| 1,898 casts 2015–24 (the cast grain, for scale) | 0.1° · 4,539 | 37 ms | global: 27 s (n³) · **local, 32 nearest: 0.66 s** | (in the local figure) | n³ per fit — needs a low-rank basis (mgcv's k = 60) |

Leave-one-out RMSE on the same 213 stations: IDW 1.72 °C · kriging 0.91 · spline 0.83 — the model-based methods halve
IDW's error *and* say where they are unsure, which is the whole point of the ask. The kriging **standard deviation**
and the spline's **standard error** are the error surfaces; IDW has none (a weighted average is not a model).

**What a server would add, and when to want it:** `mgcv`'s **soap-film smoother** (a GAM that respects the
coastline as a boundary — the one thing a `s(lon, lat)` basis cannot do), REML in place of GCV, and the cast grain
at full fidelity. None of it is needed for the station grain, and a server would break the Explorer's contract
("no server between you and the data", the bundle's `reproduce.R` / `reproduce.py` running the same SQL). If it is
ever wanted, the shape is a plumber `/interpolate` endpoint in `CalCOFI/api` that takes the Explorer's station CSV
and returns a COG + a JSON fit, rendered by the same `BitmapLayer` — the lens does not change. Not proposed now.

## Decisions

### D31 · Contours is a lens over the station grain, computed in a Web Worker

`lens=contour`. The lens **queries nothing new**: it reads the Stations lens table under the current filters and
hands `{lon, lat, z}` per `grid_key` (the grid cell's centre, `grid.geojson`) to `src/contour.worker.ts`. Three
interpolators, `interp=idw|ok|tps`:

- **`idw`** — inverse-distance weighting, power 1.3, radius 200 km, smoothing 5 km: parity with the Contour
  Explorer's `terra::interpIDW`. No error surface.
- **`ok`** (default) — ordinary kriging: an empirical semivariogram in 15 bins to half the maximum distance, an
  exponential model fitted by weighted least squares over a nugget × range × sill grid (Cressie weights), the
  augmented (Lagrange) system inverted once; predictions are one dot product per cell, the **kriging SD** is the
  n² term (delivered second, see D33), the **leave-one-out RMSE** is Dubrule's closed form from the same inverse.
- **`tps`** — a thin-plate spline (`r² log r` + a linear trend, mgcv's `s(lon, lat)` basis), the ridge λ picked by
  **GCV** over nine values on a log grid (LOO residuals and the hat-matrix trace both fall out of the inverse); its
  **standard error** from the smoother rows with σ² = RSS / (n − edf). This is the GAM `pts_to_contours_gam()` fits,
  minus REML and minus a coastline boundary.

The grid: cells of **0.06°** of longitude, rows evenly spaced in **Web-Mercator y** so the bitmap the map stretches
between its bounds is exact (no resampling); a local equirectangular km frame for the distances. **A cell farther
than 60 km from every station is blank** — the surface never extrapolates past the sampling (the Contour Explorer's
AOI clip served the same purpose). The station grain is ≤ 218 points, so a global solve is always cheap; the cast
grain (thousands of points) would need the local-neighbourhood kriging the benchmark timed — a later slice if Ben
wants it (open question 3).

### D32 · Eight surfaces from one table; the error only where there is a model

`surface=value|se|n|y0|y1|p05|p95|spread` — the statistic itself (mean · median · count, the lens's `stat`), **its
error** (kriging SD or spline SE; disabled for IDW, and the method segment switches a `se` view back to `value` when
IDW is picked), **observation density** (`n`), **first / last year sampled** (`y0`, `y1`), the **5th / 95th
percentiles** and their **spread** — `sql/station.sql` gains `quantile_cont({{val}}, 0.05) AS p05` and `p95`, so the
Stations lens, its CSV and the bundle carry them too. Every surface is interpolated the same way from the station
table (a year surface is a smooth of the years, read as "where the record is old / recent", not a claim about any
cell). The statistic shares the Stations lens's 5–95 % colour window, so the two lenses agree; every other surface
takes its own (counts, errors and spreads from 0). Year legends read `1951`, not `1,951.27`.

### D33 · What the map draws: a bitmap, isolines, the inputs on top — and the fit line under the method

A deck.gl **`BitmapLayer`** (the surface as an RGBA canvas; a blank cell borrows a neighbour's colour at alpha 0 so
linear filtering leaves no dark fringe) at 0.88 opacity, **isolines** by marching squares on the cell centres at
"pretty" 1·2·5 levels (~8 across the range; squares with a blank corner are skipped) as a 1-px `PathLayer`, and the
**station dots** in white, sized by √n, faint where a cell holds nothing in the selection — the answer to *"what
underlying data contributes"* is on the map, not in a footnote. Hovering the surface reads the cell's value, the
method and the LOO RMSE; hovering a dot reads its station summary. **The fit line** under the method segment:
`213 stations → 56,591 cells of 0.06° · leave-one-out RMSE 0.79 degC · variogram: nugget 0.46 · sill 13.91 · range
2634 km · 368 ms (+2945 ms for the error surface) · blank beyond 60 km of a station · dots are the inputs, sized by
their observations`. The value surface lands first; the error surface follows in a second message from the worker
(it is the n² term), so the map never waits on it. `interp=` and `surface=` are in the URL (D26's rule: the URL is
the whole view); the sentence reads *"…the mean as a contoured surface by ordinary kriging, showing the error of the
estimate, all years · all seasons"* with the method and surface as chips; the map's CSV and the bundle's summary are
the station table the surface interpolates (a contour is a rendering, not a query — `reproduce.R` stays honest).

### D34 · The data layer is a row in the Layers card: on/off, opacity, ramp

At the top of the Layers card, above *Sea floor*: **Data** (`data=off` hides every deck data layer — the stations,
hexagons, polygons, track, surface — and leaves the sea floor and boundaries), **opacity** (`datao=0.6`, applied
as deck's per-layer `opacity`), and **colours** (D35). All three are view state in the URL, nothing in localStorage.

### D35 · Ramps: cmocean + viridis + GEBCO, a convention per variable, `_r` to reverse

`src/ramps.ts` carries **cmocean's 22 ramps** (Thyng et al. 2016; eleven stops each, taken from the `cmocean` R
package 0.3.2 and interpolated in RGB — thermal, haline, solar, ice, gray, oxy, deep, dense, algae, matter, turbid,
speed, amp, tempo, rain, phase, topo, balance, delta, curl, diff, tarn), **viridis** and **oce's GEBCO** ramp; `pals`
is not installed here and adds nothing these do not. `ramp=thermal` names one, `ramp=thermal_r` reverses it; with no
`ramp=` the **variable picks its cmocean convention** — thermal for temperature, haline for salinity, algae for
chlorophyll / fluorescence / phytoplankton, dense for density, tempo for nutrients, solar for light, matter for the
carbonate variables, **ice for oxygen** (not cmocean's `oxy`: its red / grey / yellow breaks assume fixed 0–10 ml/L
limits, and the legend is a 5–95 % window), viridis for biology. The ramp colours every lens's map layer and the
title sentence's bar; the section heatmaps keep Plotly's explicit ramps for now (a follow-up folds `balance` into the
anomaly view, which is what `defaultRamp(…, anomaly = true)` already returns).

### D36 · Moving the data layer BELOW a boundary layer needs the interleaved overlay — EXECUTED (the four proofs passed)

deck.gl's `MapboxOverlay` runs **non-interleaved** (D22): its canvas sits above every MapLibre layer, so "move the
data layer down" has no meaning today, and the Layers card says so under the Data row. The supported route is
**`interleaved: true`** — deck's layers become MapLibre custom layers with a `beforeId`, so the Data row could sit
anywhere in *On the map* and `layers=` would carry its position. Four things to prove in a spike before flipping it:
(1) the composed style's `setStyle(diff)` on a theme / sea-floor change keeps deck's custom layers (deck re-inserts on
`styledata`, to be verified); (2) `TripsLayer`, `H3HexagonLayer` and `BitmapLayer` render interleaved without
artefacts; (3) `capture.ts` (which today composites two canvases) still gets both; (4) the phone. The fallback if
any fails: draw the boundary layers *in deck* (an `MVTLayer` over the same PMTiles) whenever the data layer is
ordered below one — heavier, but it needs no overlay change. **Executed 2026-09-07:** `MapboxOverlay({ interleaved:
true })`; a `data` entry in `layers=` names the data layer's place (absent = on top; a list whose first row is
`data` is written without it), every deck layer takes the `beforeId` of the boundary immediately above it (that
entry's fill / line / circle layer), and the Layers card's *On the map* list carries a draggable **Data** row. One
trap: deck inserts each `beforeId` group with `map.addLayer(group, beforeId)`, which throws — and drops the whole
data layer — when the named layer is not in the style yet (the composed style lands after load and again on every
theme / sea-floor change), so `MapView` passes a `beforeId` only while `map.getLayer()` finds it and re-applies the
layers on the style's next `idle`. Proven headless: the sanctuaries' fill draws over the hexagons with
`layers=noaa_onms_sanctuaries,data`; the deck group survives the theme flip (`map.style._order` before and after);
`captureView()` composites at nonBg 0.61 / sd 36 (not blank). A side effect worth keeping: interleaved, the data
draws **under CARTO's labels**.

### D37 · Transitions: keep the one morph that explains something, drop the ones that only move

The audit (headed Chrome, `?tour=off`, the recording `explorer_lens_transitions.gif` in Downloads):

- **Stations ↔ Hexagons** — helpful. The dots travel less than a hexagon's radius and the hexagon fades in under
  them: it *shows* pooling. Keep the 700 ms.
- **→ Regions** — distracting. All 218 dots fly to four centroids and stack; the rest dim to 15 % alpha. It reads
  as "the stations vanished", not "the stations pooled" — the polygon fade already says that. **Change:** the dots
  cross-fade in place (no travel), the polygons fade in.
- **→ Cruises / → Sections** — neutral to distracting: the dots only re-colour (dim, or the line's stations light
  up), so the position transition is a no-op and the colour tween is a 700 ms flicker. **Change:** 250 ms fades.
- **The cruise playback re-renders the whole App per frame** (`setTime` in the rAF loop). It works, but a 1,100-line
  component at 60 fps is the wrong cost model; **change:** hold `currentTime` in a ref and update the one
  `TripsLayer` through `overlay.setProps` from the loop.
- **The extra segments — a data fault, fixed (executed).** The track was every root sampling event of the cruise
  ordered by `datetime`, across datasets whose clocks disagree: net-tow times are local (a tow sorts 7 h before its
  own station's cast and after the next station's), the METS underway series sits on a stale fix in port for hours
  (32.696 N, −117.153 E at 00:00–03:00 while the ship was at station 25), and duplicates abound. On 2019-04-33UD
  that was **2,719 events, 858 changes of station and ~80,000 km of track for a 3,800 km cruise**. `cruise_track.sql`
  now returns **one point per station visit** — the median position of its events, its time the median of its
  *casts* (the ship's own clock) else of every event; the underway series only when a cruise has nothing else —
  **53 visits, 3,841 km**. The hint under the cruise picker reads "53 station visits on the track · 455 sampling
  events".

### D40 · The site grain is the default; the station grid stays for the spline and for speed (executed)

Ben: *"the cast grain should be the much more scientifically accurate version … if not too slow, want more accurate
cast grain as default (pending timing tests)"*. Measured, in order: **every cast** (`GROUP BY root_id`, 44,946
temperature casts, 32 nearest on 0.06° cells) 12.8 s; 24 nearest on 0.1° cells 3.6 s; and the sardine tows — 52,376
at ~2,000 positions — **55 s with a leave-one-out error of 292**, because two dozen coincident tows make every local
system singular. So the grain is **every site**: the casts pooled to their position rounded to 0.01° (≈ 1 km,
`sql/contour_cast.sql`, `n_samples` kept), repeat occupations one point (their spread is the nugget). Then the bucket
search's unbounded ring walk over empty ocean showed up (35 s of the 36 s were the mask), capped at **3 rings = 3 ×
mask_km = 180 km** — so the local neighbourhood is *the 24 nearest within 180 km*, exact, and the same definition in
R and Python. Result: **12,046 temperature sites in 1.0 s, 18,961 sardine sites in 1.1 s** (mask 50–95 ms · variogram
55 · surface 850 · LOO 14), one small solve per cell so the error surface comes free; the station grid stays as
`grain=station` (0.3 s, global solve, and the only grain the spline runs on — the picker greys *every site* under
*spline*). The sardine surface's LOO of 333 per 10 m² is the raw-density tail, not a fault; a log1p option is the
follow-up (Risks).

### D41 · One lens at a time: the lens picker (executed)

Ben: *"seeing them all at once causes more visual/mental friction … show just the icons of the other lenses as
selectable tab slivers, then clicking shows all of them with perhaps some helptext below … which then becomes full
size with the text describing it."* `src/lenspicker.tsx`: the active lens reads full size — icon, name, a ▾, its
one-line description under the row — and the other five are 26-px icon-only slivers beside it (each titled with its
line). Any sliver, or the name, opens the six as rows (icon · bold name · description; the active one tinted);
picking one closes it; Esc and a click outside close it too. It replaces the six-button grid and the phone sheet's
strip; the sentence's lens chip keeps its own menu. The tour step says *Six ways to view it* and describes the
slivers; `verify.mjs` clicks lenses through the picker.

### D42 · Land is clipped from the surface by Natural Earth land rasterised onto the grid, not by layer order (executed)

Ben (mid-session): *"clip out land from the interpolated surface, which could be done by putting the data layer
below the land basemap layer."* Order cannot do it: in CARTO's styles land is the **background colour**, not a layer
— `water`, landcover, parks and roads are the layers, so nothing drawn above the surface covers land as a whole, and
below `water` the surface vanishes at sea. The first cut read the GEBCO terrain-RGB tiles the 3-D curtain decodes
(elevation ≥ 0 = land): right where the tiles exist (Los Angeles reads 0 m, the basin −1,090 m) but they stop at the
CalCOFI crop, so Arizona and the Gulf of California stayed coloured, and the mosaic over a site-grain grid reaching
165° W took 8.8 s. The shipped clip is **Natural Earth 10 m land** — `rnaturalearth::ne_countries(scale = 10)`
unioned, clipped to 170–95° W × 5–55° N, simplified, bundled as `public/land.geojson` (267 KB, 11,443 vertices) —
**rasterised onto the grid's own Mercator-regular cells with a canvas** (`landMask()` in `src/contour.ts`, the
even-odd rule so lakes are holes): complete coverage, no fetch beyond the one file, milliseconds. A display mask
like the edge fade: the bitmap, the isolines and the hover are blank over land; the values, the CSV and the R /
Python parity are untouched (mask `cc_interpolate_rast()` with `calcofi4r::cc_bathy()` in R for the same effect).
`loadMosaic()` in `curtain.tsx` kept its new zoom argument and `mosaicAt()` for whoever needs elevations next.

### D38 · The hexagon size is a slider (executed)

`<input type="range" min=3 max=7 step=1>` with a `<datalist>` tick per H3 resolution, 110 px wide, the readout
beside it (`~8.5 km · H3 5`), the title carrying the resolution and mean edge; the sentence chip keeps its menu.
`.lens5` became six columns for the sixth lens.

### D39 · One algorithm, three runtimes: `cc_interpolate()` and `calcofi4py.interpolate()` reproduce the map (executed)

Ben (mid-session): *"R and Python functions that replicate the exact output in the browser."* The same precedent as
`cc_density_sql()` / `density_sql()` / `sql/density.sql`: **the browser's own worker writes the fixture**
(`explore/scripts/parity/contour_fixture.mjs` bundles `src/contour.worker.ts` with `self` shimmed, runs a seeded
30-point set through all three methods at 0.25° cells and writes every cell of the value and error surfaces plus the
fit lines), the fixture is copied byte-for-byte into `calcofi4r/tests/testthat/fixtures/` and `calcofi4py/tests/fixtures/`,
and both packages implement the algorithm by hand — not gstat / mgcv / scipy / pykrige, which would give a *different*
surface — and test every cell against it (`tolerance 1e-5`; the fixture is rounded to 6 dp). **`calcofi4r 1.21.0`:**
`cc_interpolate(pts, method = c("ok", "idw", "tps"), cell_deg = 0.06, mask_km = 60, se = TRUE)` → `grid`, `values`
(`ny × nx`, row 1 = north), `se`, `fit`; `cc_interpolate_rast()` → a `terra` raster in EPSG:3857 (the honest CRS: the
rows are regular in Mercator y). **`calcofi4py 0.8.0`:** `interpolate(points, method, cell_deg, mask_km, se)` →
`Surface(grid, values, se, fit, extent_3857)`; numpy via the `interp` extra. Tests: R 34 assertions (593 in the whole
suite, 0 failures); Python 5 tests. The natural follow-up (Slice 2): the download bundle's `reproduce.R` / `reproduce.py`
call these on `summary/station.csv` when the lens is Contours, so the bundle re-draws the surface too.

## Architecture (what changed)

| file | change |
|---|---|
| `src/contour.worker.ts` (new, ~150 lines) | the numerics: grid + mask, IDW, OK (variogram, inverse, LOO, SD), TPS (GCV, SE); two messages per request |
| `src/contour.ts` (new) | the worker client (`computeSurface`, request ids so a superseded answer is dropped), `isolines`, `niceLevels`, `surfaceImage`, `cellToLonLat`, `cellValue`, `MASK_KM` |
| `src/ramps.ts` (new) | `RAMPS`, `rampColors`, `rampCss`, `parseRamp`, `defaultRamp` |
| `src/state.ts` | `Lens` + `contour`; `interp`, `surface`, `ramp`, `data`, `datao` in `Sel`, `fromUrl`, `toUrl`; `INTERP_*`, `SURFACE_*` labels |
| `src/map.tsx` | `colorScale(domain, alpha, ramp)`; `LayerInputs.contour / ramp / dataOn / dataOpacity`; the `BitmapLayer` + isolines; contour dots; every data layer takes `opacity` |
| `src/App.tsx` | the surface effect (worker call, generation guard, timing mark `contour:<method>`), `legendDomain` / `legendUnit`, `contourInputs`, the lens options block, the surface tooltip, the sentence's bar |
| `src/sentence.tsx` | the contour clause with method + surface chips |
| `src/layers.tsx` | the Data row (D34, D35) |
| `sql/station.sql` · `sql/cruise_track.sql` | `p05`, `p95` · one point per station visit |
| `scripts/verify.mjs` | the lens walk includes Contours |
| `README.md` | the Contours and data-layer paragraphs |
| `scripts/parity/contour_fixture.mjs` → `contour_fixture.json` (new) | the parity fixture from the worker (D39) |
| `calcofi4r/R/interpolate.R` + `tests/testthat/test-interpolate.R` · `calcofi4py/src/calcofi4py/interpolate.py` + `tests/test_interpolate.py` | the two runtimes (D39); versions 1.21.0 / 0.8.0 with NEWS / CHANGELOG |

## Phases

| slice | what | h |
|---|---|---|
| **1 · the spike (executed 2026-09-07, explore `e39e0bc`, calcofi4r `748ef4d`, calcofi4py `e6d2398`)** | D31–D35, D37's track fix, D38, D39 | 17 |
| **2 · polish (executed 2026-09-07)** | the mask edge fades over the last 15 km; verify states for each method, the surface, the Data row, the ordering and the picker; the tour step; the bundle's `reproduce.R` / `.py` name the parity functions; D37's transition changes and the cruise loop off React | 5 |
| **3 · D36 → interleaved overlay (executed 2026-09-07)** | the four proofs, the Data row in *On the map*, `layers=…,data,…` | 4 |
| **4 · the site grain (executed 2026-09-07, D40)** | `grain=site` default, `contour_cast.sql`, the local mode in the worker + calcofi4r 1.22.0 + calcofi4py 0.9.0 with the seeded subsamples | 6 |
| **5 · the lens picker (executed 2026-09-07, D41)** | `src/lenspicker.tsx` | 2 |
| **7 · land clip (executed 2026-09-07, D42)** | `landMask()` rasterises Natural Earth land onto the grid; `public/land.geojson` | 1 |
| **6 · retire the Contour Explorer (executed 2026-09-07)** | `server/caddy/Caddyfile`: `/contour` and `/oceano` 308 to `calcofi.io/explore/?lens=contour&var=temperature` (deployed: Caddy restarted on the server); `products.yml`: the card superseded by the Explorer, the Explorer card lists contours; `uptime`: the monitor dropped | 1 |
| left | the kriging SD at the station grid stays ≈ 3 s (delivered after the value; a Cholesky path would halve it); isoline labels; a log1p transform for heavy-tailed biology (D40); `reproduce.R` running the surface itself rather than naming the call | — |

## Measured (2026-09-07)

- The benchmark table above (`bench.mjs`, station means of temperature 0–10 m and 1,898 casts 2015–24 from the
  dev catalog).
- In the app (Vite dev, headless Chrome): `first_lens_ready` 0.28 s warm; **`contour:ok` 0.37–0.39 s** for 213
  stations → 56,591 cells (LOO RMSE 0.791 °C; variogram nugget 0.46 · sill 13.91 · range 2,634 km — the range says the
  station means vary as a trend across the grid, which is why the spline does as well); the kriging SD **+2.9 s**;
  `contour:tps` 0.49 s (205 sardine stations, 13.0 effective df).
- **The Claude-in-Chrome MCP tab freezes the moment a `BitmapLayer` is added** (JS and screenshots time out for
  45 s+), with the canvas *or* `ImageData`, with picking on or off, with a 2×2 test image — while headed and
  headless puppeteer Chrome on the same page stay at 60 fps ("alive", heartbeat every 2 s). An extension artefact,
  not the app; verify with `scripts/verify.mjs` / puppeteer, as `feedback_explorer_verify_gotchas` already says.

### `verify.mjs`, 2026-09-07 (the dev catalog, headed Chrome, 1280 × 800 and 390 × 844)

The first full run after slices 2–5 failed 33 states in four groups, and each group had one cause: the lens picker
was two rows tall inside the phone sheet's peek strip (one CSS rule: the description hides there and the open list
floats over the map, `position: fixed`, since the sheet clips overflow); the Layers-card states counted checkboxes,
indexed rows and read the first range slider from before the Data row (the expectations updated: 6 checkboxes, the
Data row leads *On the map*, the sea floor's slider is the second); **interleaved deck forwards no mouse events** —
its overlaid mode registered MapLibre's `mousemove`/`click` itself — so no tooltip or click reached the app until
`MapView` drove picking from the map's own events into one `.deck-tooltip` element (and the hover state picked a
feature under the floating Controls panel; it now picks one in the open map); and a run of late-suite
`first_lens_ready` timeouts that pass in isolation (run fatigue in one Chrome profile, not regressions). **Left
failing, and pre-existing** (they fail at `d7cd898`, before this plan, from the 2026-09-06 first-look tweaks that
moved feedback under *Help* and dropped the sea-floor legend row): `u4b_feedback_open`, `u4b_annotate`,
`u4b_send_mock`, `u7_annotate_text`, `p4b_feedback` (`[data-tour="feedback"]` / `[data-tour="more"]`), `p4_share`
(`.menu-btn` *Share*), `layers_default_dark` (`.legend-bathy`). A follow-up should re-anchor those states. **The final full run (146 states) fails exactly those 7 plus 7 late-run timeouts, all 7 of which pass when run alone.** **Smoke test on the real release** (`npm run build` with the
defaults, `vite preview`, `scripts/smoke_release.mjs`): v2026.09.06 with the eight-version picker, no console
errors, the Contours lens on the site grain reads *"Temperature, the mean as a contoured surface by ordinary kriging
over every site"*; the one "failed" request is DuckDB-WASM's `eh` bundle probe, aborted by design when the `mvp`
bundle is chosen.

## Risks and what bounds them

- **A surface reads as truth.** The mask (60 km), the input dots, the error surface and the LOO RMSE on the fit
  line are the bounds; the sentence says *"by ordinary kriging"*, never just "temperature".
- **The grid_key grain nearshore** (2–4 stations per cell) smooths the coast. Bound: the same caveat the sections
  carry; the fix is the station table on `site_key`, tracked in memory.
- **A heavy-tailed biology statistic** (larvae per 10 m²) kriged in raw units gives negative lobes. Bound: the
  0–95 % window hides them; the honest fix is a log1p transform with back-transform (Slice 2 option), as
  `explore_interpolate-larvae.qmd` did.
- **`quantile_cont` on the station table** costs a sort per group; measured no visible change to `station` (< 60 ms).

## Decided (Ben, 2026-09-07)

1. **Kriging** is the default method. 2. **`ice`** for oxygen. 3. **The cast grain** as the default if not too slow,
else the station grid with the cast grain optional — measured (D40): the *site* grain at ~1 s is the default, the
station grid stays. 4. **Retire `app.calcofi.io/contour`** — done (slice 6). 5. **Finish the slices and ship** — done;
`verify.mjs` run recorded below. 6. (mid-session) **The lens picker** — D41.

## Open questions for Ben (each with the recommended answer)

1. **Default method** — kriging (recommended: it has the error surface and halves IDW's error), or IDW for parity
   with what people saw on app.calcofi.io/contour?
2. **Oxygen's default ramp** — `ice` (recommended) or cmocean's `oxy` with the legend clamped to 0–10 ml/L?
3. **The cast grain** (Slice 4) — wanted, or is the station grain the product?
4. **Retire `app.calcofi.io/contour`** now (308 → `calcofi.io/explore/?lens=contour&var=temperature`) per the
   2026-08-28 plan, or after Slice 2?
5. **Ship the spike as is** (after a `verify.mjs` run), or after Slice 2?

## Kickoff prompt (Slice 2; cwd `~/Github/CalCOFI/workflows`)

> Read `.claude/plans/2026-09-07 Explorer Contours lens ….md` (D31–D38, Slice 2) and the Explorer memories. Work in
> `/Users/bbest/Github/CalCOFI/explore` (branch `contours` off main; the spike is the uncommitted tree — commit it
> first as one commit). Do Slice 2: the mask edge, the faster kriging SD, verify states for each method / surface and
> the Data row, the tour step, D37's transition changes. Run `npm run build` and
> `node scripts/verify.mjs http://localhost:5178/ shots/dev --only=contour` and paste the timings into the plan's
> Measured section. Do not push.
