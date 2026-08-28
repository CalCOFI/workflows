# CalCOFI Explorer — one browser-native app across station, hexagon, cruise, region & section grains

**Status:** proposed 2026-08-28; Ben confirmed D6 (grid morph) and moved D9 to `calcofi.io/explore`, asked for the D4 cold-start budget and for packaged downloads + reproducible code (D10) the same day; for the 9/3 and 9/8 meetings (Erin, Betty, Mark) · **Date:** 2026-08-28 ·
**Scale:** one new repo (`CalCOFI/explore`, GitHub Pages at `calcofi.io/explore/`), two release additions (`sample_spatial` + browser-shaped
`obs` objects, in `calcofi4db`), five phases across the SoW year; supersedes `db-viz-hex`, `db-viz-station`,
`db-viz-cruise` and `oceano` one lens at a time, and retires the H3T/Varnish tile path with them.

## The question

calcofi.io now presents the integrated database through four apps, each a different **spatial grain** —
station, hexagon, cruise, contour — and Erin's 2026-08-20 thread ("Update map layers on integrated app?")
effectively asks for a fifth, **arbitrary polygon** (~45 regulatory/management layers, summarized, not just
drawn). Ben's 2026-08-27 reply on the renames thread put the real question on the 9/3 + 9/8 agenda:
*could or should these be one app, and is Shiny still the right fit?* Erin: "not sure yet that we want to
consolidate into a single app at this point — but worth discussing." Mark: apps need "connective tissue to
the brand" without being SIO-template dull. This plan answers all three, with the numbers behind it.

## Context — what exists today

Surveyed 2026-08-28 (full table in Appendix A):

| app | stack | hosting | data at runtime | grain | depth | URL state | size |
|---|---|---|---|---|---|---|---|
| **Hexagon Explorer** `db-viz-hex` | Shiny + bslib + `mapgl` (fork) + plotly | shiny-server | local `calcofi_<v>.duckdb` **475 MB** built by `prep_db.R`; hex tiles from **h3t.calcofi.io** (FastAPI + Varnish) | H3 res 1–10 by zoom; *or* one polygon layer ("Summarize Within") | depth-range filter; transect depth profile | **none** | 6,321 lines + 790 `prep_db.R` |
| **Station Explorer** `db-viz-station` | vanilla JS + Leaflet, hand-rolled SVG | GitHub Pages, weekly CI + `db-release` dispatch | ~8 MB prebuilt JSON; DuckDB-WASM only for downloads | station (`grid_key`) | per-station depth profiles vs bathymetry | none (only `?tour=`) | 4,638 lines `app.js` |
| **Cruise Explorer** `db-viz-cruise` | Shiny + bslib + `mapgl` | shiny-server | local duckdb from `sample` root events | cruise → dataset events | none | **full** (`?cruise=&datasets=&id=`) | 701 lines |
| **Contour Explorer** `oceano` | Shiny + shinydashboard + Leaflet | shiny-server | **legacy PostGIS**; server-side IDW cached as tif | interpolated surface over an AOI | depth slider + profile | bookmarking wired, unused | 879 lines · superseded |
| CTD Explorer `ctd-viz` | Shiny + bslib + `mapgl` + `MBA` | shiny-server | local duckdb **465 MB** | cruise → casts → picked transect | vertical section (MBA) | bookmarking | 1,696 lines |
| CTD Transects `ctd-transects` | vanilla JS + Plotly | GitHub Pages, CI + dispatch | 896 committed shards, ~32 KB each (77 MB) | CalCOFI line, nearshore→offshore | vertical section (`zsmooth`), anomaly default | **full** | 686 lines |

Three things the table says that the cards do not:

- **The four "by spatial unit" apps run the same query with a different `GROUP BY`.** Every one of them
  filters `obs` by taxon/variable × time × depth and then aggregates by `grid_key` (station),
  `h3_cell_to_parent(hex_id, r)` (hexagon), `cruise_key` (cruise) or a `sample_spatial` membership
  (polygon); a contour is a rendering of the station grain. Users do not pick a grain, they pick a
  question — which is exactly why Erin is now asking for self-explanatory names ("which app do I need for
  my Q?").
- **The fleet is already migrating off Shiny, by evidence rather than policy.** The two newest apps
  (`db-viz-station`, `ctd-transects`) are static, deep-linkable, rebuilt by CI on every release, and cost
  nothing at request time; `ctd-transects/README.md` states the Shiny-vs-static trade-off explicitly.
  Meanwhile the Shiny side has the operational scars: `prep_db.R`'s `sample_spatial` join was OOM-killed
  on the 16 GB shiny-server VM on 2026-08-04 (took the VM down) and 2026-08-10 (exit 137, silent stale
  data); each Shiny app holds a ~0.5 GB DuckDB; H3T + Varnish exist only to make Shiny's hex map fast;
  and the two richest UIs (`db-viz-hex`, `db-viz-station`) have **no URL state at all**.
- **Polygons are in the data, not in the product.** `ingest_spatial.qmd` already ships 19 layers
  (13,206 features: EEZ, 12/24 NM, state waters, MPAs, sanctuaries, cowcod, BOEM wind, disposal sites,
  counties, HUC8, MEOW …) as the release `spatial` table + PMTiles, with a registry
  (`metadata/spatial_layers.csv`, 19 rows, styling + attribution). But the sample↔polygon **membership
  is not in the release** — every consumer rebuilds it (`db-viz-hex/prep_db.R:584`, the join that OOMs,
  and where a pagination bug once silently dropped 32 % of CDFW Regions memberships). The Hexagon
  Explorer then exposes layers in three places (Map Layers · Filters › Spatial · Plot Options › Summarize
  Within) with three different lists.

### The data, sized for a browser (v2026.08.25, measured locally)

| | rows | notes |
|---|---:|---|
| `obs` | 26,261,931 | 401 MB partitioned by `dataset_key` + a 200 MB single-file twin published *because DuckDB-WASM cannot glob* |
| … `realm = 'bio'` | 1,255,348 | 1,212 taxa; per-taxon slice **median 22 rows**, p90 1,125, p99 14.8 k, max 122 k |
| … `realm = 'env'` | 25,006,583 | 84 types; the largest (`temperature`) is **0.88 M rows** |
| `sample` | 1,467,245 | 419,543 root events (cast/tow/transect…), `seafloor_depth_m`, `geom` |
| `spatial` | 13,206 | 19 layers · `grid` 218 station cells with `geom` **and** `geom_ctr` |
| grains on `obs` | 216 grid keys · 840 cruise keys · H3 cells 3.1 k (res 4) / 7.1 k (5) / 18.9 k (6) / 42.7 k (7) / 179 k (10) · 78 years · 472 ten-metre depth bins |

Two consequences. **The whole bio realm fits in one fetch** (1.26 M slim rows ≈ 15–20 MB parquet), and any
env variable is one ~6–10 MB object — so a browser can hold everything a lens needs and aggregate it to
*any* grain in tens of milliseconds; the Mosaic/DuckDB-WASM demos cross-filter 10 M rows in-browser.
And the machinery already exists: `db-query` runs DuckDB-WASM 1.29 against `storage.googleapis.com/calcofi-db`
directly (CORS open, range requests), resolving tables through the release **catalog** — `lib/release.js`
is a port of `calcofi4r::cc_release_sources()`, and the catalog lists every partition object explicitly,
so "no glob" is a solved problem. `db-query` also measured the cost to avoid: ~5 s DuckDB-WASM init and
10–20 s of parquet-footer reads when a query touches many large objects. The explorer's data layout is
designed around that number.

`obs_ctd_full` (271 M rows, 1.37 GB) and `obs_mets_full` stay out of the explorer, as they are out of every
app today; the section lens uses the 10 m thinned CTD in `obs`, which `ctd-transects` proved is enough.

## The idea in one sentence

**One question, any grain.** The frozen release is the backend; the browser aggregates; the grain is a
`GROUP BY` the user can *watch happen*; depth is an axis of every view, not a filter in a modal.

## Decisions

### D1 · One app or many? → One **explorer** for the integrated database; dataset-specific apps stay separate

Consolidate the four "by spatial unit" apps (+ polygon) into a single **CalCOFI Explorer** with five
**lenses** over one selection: **Stations · Hexagons · Cruises · Regions · Sections** (contour becomes a
rendering option of the station lens: interpolate in the browser, or don't). A selection (taxon or
variable, dataset(s), years, quarters, depth band, region) persists when the lens changes — that is the
thing no arrangement of separate apps can offer.

Keep separate: **CTD Explorer / ctd-qaqc** (cast/scan grain, QA audience, will read the CTD team's
PostgreSQL flags), **Pollutants** (not in the release), and the student apps. They adopt the shared
component kit (D9) so they look like one family; they do not merge. `ctd-transects` is the exception
in the other direction — it *is* the section lens already (static shards + JS); it folds in during Phase 4.

Erin's hesitation is about the user-facing split, and it is compatible with this: consolidate the
**engine, the data contract and the design first**; the front door can still offer two entries —
"Find what has been collected" (coverage) and "Explore the data" (values) — as two URLs into the same
app, and the calcofi.io cards can keep one card per lens if that helps findability. Superseded apps
stay live at the bottom of the page with a banner, exactly as Erin asked, until each lens reaches parity.

### D2 · Shiny or browser-native? → Browser-native, static

For the public explorer the workload is read-only aggregation over a frozen, content-addressed release
that is already served over HTTPS with range requests — the textbook case for doing the work in the
client. Concretely, moving off Shiny buys:

- **No server in the request path.** Static hosting (GitHub Pages or the existing `static.calcofi.io`
  Caddy `file_server`) scales for free; the 16 GB VM stops being a single point of failure for the
  flagship app, `prep_db.R` and its OOM history go away, and H3T + Varnish retire.
- **URL as the state.** Every selection is a query parameter (`?lens=hex&res=6&taxon=worms:126983
  &var=temperature&depth=0-200&years=2000-2026&q=1,2&layer=mpa&release=v2026.08.25`), so a link
  reproduces a view — the property `db-viz-cruise` and `ctd-transects` have and the two big apps lack,
  and what makes `?theme=`/`?tour=off` screenshots and `images/<key>_{dark,light}.png` deterministic.
- **Release pinning is a query parameter.** The app reads `versions.json`/`latest.txt` at runtime, so a
  paper can cite `?release=v2026.06.26` and get that release — no redeploy per release, only a CI
  `db-release` dispatch to refresh the small coverage JSON (Phase 1).
- **Contributors.** Betty and the capstone teams write JS/Python; the SIO web team can embed a static
  app (or a single lens) in the new SIO-templated site; a Shiny app needs our server.

Where Shiny stays right: internal QA against PostgreSQL (`ctd-qaqc`), anything that needs R packages at
request time (`MBA::mba.surf()` — though `ctd-transects` showed Plotly `zsmooth` replaces it), and
prototypes. **Shinylive** (webR) was considered and rejected: tens of MB of R runtime before first paint,
no DuckDB-WASM inside webR, and it would keep the R-only contributor constraint.

### D3 · Framework → TypeScript + Vite, **React** shell, **MapLibre GL + deck.gl** map, **DuckDB-WASM** engine, **Plotly** charts

- **React + TypeScript (Vite)**, not another 4,600-line global-scope `app.js`: five linked lenses, a
  shared selection store, async DuckDB queries with cancellation, URL round-tripping and a component kit
  reused by the other apps are a component/state problem. React is the choice for *who maintains it in
  2028* (largest student/contractor pool; first-class bindings for deck.gl and MapLibre; what LLM
  tooling produces most reliably). **Svelte 5** is the honest runner-up — its built-in `tweened`/
  `crossfade` primitives make the grain morph (D6) nearly free and bundles are smaller — pick it only if
  Ben wants to own the front end personally. **Observable Framework** was rejected on precedent (the
  2026-05-17 browser-only match app chose standalone HTML over Observable JS) and because bespoke linked
  interaction ends up as custom JS anyway. Vanilla was rejected above.
- **MapLibre GL** (basemap; the existing PMTiles polygon groups at `gs://calcofi-files-public/_spatial/`)
  with a **deck.gl** overlay: `H3HexagonLayer` draws hexagons straight from cell ids (no geometry
  shipped — today `hex.geojson` is 146 MB), `ScatterplotLayer` for stations, `PathLayer`/`TripsLayer` for
  cruise tracks, `PolygonLayer` for regions, `ColumnLayer`/`PointCloudLayer` for the optional 3-D view,
  and layer **`transitions`** are the morph. Everything restyles on the brand `cc:theme` event.
- **DuckDB-WASM** over release objects resolved through the catalog (port of `db-query/lib/release.js`,
  itself a port of `cc_release_sources()`), so `calcofi4r`, `calcofi4py`, `db-query` and the explorer
  read the same bytes by the same rule. H3 parents are **precomputed columns** in the browser-shaped
  objects (D4) rather than a runtime `h3` community-extension load; the `spatial` extension is not
  needed at all in the client (membership is precomputed).
- **Plotly.js** for the water-column strip, time series, sections and Hovmöller — already themed via
  `cc_plotly_theme`/`cc:theme` in `ctd-transects` and the Shiny apps; Observable Plot is the lighter
  alternative if bundle size matters more than continuity.

### D4 · Where aggregation happens → in the browser, over browser-shaped release objects; H3T retires

`calcofi4db` adds, at release time (tested like every other release step):

| object | shape | why |
|---|---|---|
| `obs_bio.parquet` (one file) | slim `obs` (bio): `root_sample_key` (int id), `dataset_key`, `taxon_key`, `life_stage`, `grid_key`, `hex_r3…hex_r7`, `cruise_key`, `year`, `quarter`, `depth_bin`, `depth_min_m`, `depth_max_m`, `value`, `qual_ok`, `tow_type`, effort (`std_haul_factor`, `prop_sorted`, `volume_sampled_m3`), `density_per_10m2`, `density_per_1000m3`, `effort_class` (D8) | the whole bio realm in one ~15–20 MB fetch; any grain is a `GROUP BY` |
| `obs_env/measurement_type=*/…` (84 objects, explicit in the catalog) | same columns, `measurement_type` as the hive key | one variable = one ~6–10 MB object; footers read once |
| `sample_spatial.parquet` | `root_sample_key`, `layer`, `spatial_key` | membership computed **once**, per root sample (exact — not by hex centroid), on the pipeline machine, chunked per layer; every consumer inherits it (`db-viz-hex`'s copy retires) |
| `coverage.json` (or parquet) | n samples by dataset × variable × station × year × depth bin | first paint in < 1 s before DuckDB-WASM wakes up; this is also **Task 14's inventory backbone** |
| `grid`, `spatial`, `cruise`, `dataset`, `taxon` | as released | station cells + centroids (218), polygons (simplified for display), the attribution fields |

`qual_ok` is `cc_qual_ok_sql()` evaluated at build, so the flag semantics live in one place. The H3T API
(FastAPI, Varnish, reading `db-viz-hex`'s derived DuckDB, arbitrary base64 `SELECT`) has no role once
hexes are aggregated client-side from a slice — it retires with `db-viz-hex` in Phase 5. `db-viz-station`
and `ctd-transects` keep their build-time JSON pattern until their lenses reach parity.

#### Cold start — measured against this design, not against `db-query` (Ben's hesitation, 2026-08-28)

`db-query`'s "~5 s init, 10–20 s of footers" are the cost of *its* shape, not of WASM: the 5 s is the
~5 MB `duckdb-wasm` bundle from jsDelivr **plus** `INSTALL/LOAD httpfs, spatial` (two more multi-MB
downloads); the 10–20 s is the bio↔env match touching many large objects — `obs` (the 200 MB twin or 15
partitions), `sample` (26 MB), `taxon`, `dataset_taxon` … — one footer round-trip each, then row groups
whose sort order does not follow the predicate. The explorer's budget removes both by construction:

1. **Prebuilt first paint; WASM never in the critical path.** `coverage.json` plus a prebuilt default
   view per lens (the default taxon + `temperature` at every grain, a few hundred KB) render in < 1 s.
   DuckDB-WASM initializes in a Web Worker *behind* that; a user's first custom selection normally lands
   after it is warm. The progress bar, when one is needed, is over a data fetch, never over an engine.
2. **No extensions.** Hex parents, depth bins, `qual_ok`, effort + the D8 densities and membership are precomputed
   columns; the client loads none of `httpfs`/`spatial`/`h3` (`duckdb-wasm` reads HTTPS parquet natively).
   One ~5 MB bundle, self-hosted beside the app; the browser's wasm code cache and a service worker make
   a repeat visit ~0.3–0.8 s to instantiate.
3. **One object per lens, fetched whole.** `obs_bio` (~15–20 MB) and one `obs_env/measurement_type=…`
   object (~6–10 MB) are single GETs (HTTP/2, ~1–3 s on broadband) registered as in-memory buffers — no
   footer or row-group chatter at all. And because release objects are **content-addressed, their URLs
   are immutable**: `Cache-Control: immutable` + the Cache API mean the second session pays nothing, and
   a new release invalidates by changing the URL, exactly as H3T's `release=` does today.
4. **Aggregation** of ≤ 1 M rows to any grain is tens of milliseconds (Mosaic's 10 M-row cross-filter
   demos are the reference point).

Expected, and what Phase 0 must measure: first paint < 1 s; first custom query 1–4 s on a first visit
(fetch-bound) and < 100 ms after; repeat visits near-instant; the bio slice holds on a phone.

**A kept-warm backend is a legitimate transport, not the architecture.** A warm DuckDB service answers
the same SQL in ~50–100 ms natively, and Varnish makes repeats ~5 ms — that is precisely what H3T is
today. Two things to be clear-eyed about: it would be **native** DuckDB (`@duckdb/node-api`, the
existing FastAPI, or R), not a server-side WASM build — WASM on a server is single-threaded and 2–5×
slower than native for nothing in return; and it buys no client init and no slice download at the
price of the server back in the request path (the VM, the SQL-validation surface, per-release cache
busting, the on-call), while still paying its own cold start on every *new* query. The design keeps the
door open without walking through it: the query layer speaks SQL strings behind a transport interface,
`wasm | http`, and the same SQL runs in either. If Phase 0 shows a first custom query over ~4 s on a
laptop, or a phone that cannot hold the bio slice, the `http` transport (Cloud Run with
`min-instances=1`, or the existing `h3t_api_py` service given a `/query` route) moves from optional to
Phase 2 — for heavy queries (`obs_ctd_full`, bio↔env matching) and WASM-less clients first, and for
everything only if the numbers say so.

### D5 · Depth → an axis of every lens, three depth grains, one linked brush

- **Three depth grains, drawn honestly.** A bottle is a *point* at a depth; a CTD is a *profile* (10 m
  thinned); a net tow is an *integrated span* (`depth_min_m`–`depth_max_m`, e.g. 0–210 m oblique). The
  data model already carries all three (`depth_min_m`/`depth_max_m`); no app renders the distinction.
- **The water-column strip.** A vertical panel docked to the map — depth on the y-axis (standard levels,
  0–500 m by default, extendable to the 6,500 m ceiling), the current selection's profile envelope
  (median ± IQR per depth bin; spans as bars). **Brushing it slices the map** (hex/station colours
  recompute for that band) and brushing the map or the year strip re-draws it: map × depth × time are
  three linked brushes over the same slice. This replaces the depth-range slider buried in a filter modal.
- **Section lens** = `ctd-transects` generalized: x is a CalCOFI line (stations ascending, nearshore →
  offshore) *or a cruise track* (curtain plot along `order_occ`/`datetime` — the cruise lens with depth),
  anomaly-vs-climatology as the default view, seafloor from `cc_transect_bathy()`.
- **Hovmöller** (time × depth) for a station or a hex — the "what changed at 90.30 at 100 m over 70
  years" question, which no app answers today and which is one `GROUP BY year, depth_bin` on the slice.
- **3-D, optional.** deck.gl `PointCloudLayer`/`ColumnLayer` in an orbit view: a cruise's casts as
  coloured columns with vertical exaggeration. A tour/outreach view, not the default — hard to read
  quantitatively, so it is Phase 5 and stays behind a toggle.

### D6 · The grid morph → yes, as the grain transition and the tour's opening move

The CalCOFI grid (218 Voronoi cells + centroids in the release `grid` table; `cc_grid_zones` for the
6 nearshore/offshore × standard/extended zones) is the app's "home" shape. Switching lens is an animated
regrouping — deck.gl attribute `transitions` on `getPosition`/`getFillColor` with stable ids per
station:

- Stations → **Hexagons**: dots travel to their parent-hex centroids while hexagons cross-fade in.
- Stations → **Regions**: dots gather at polygon label points as polygons fill (unsampled polygons
  render outline + "no data", never zero — the 2026-08-03 decision).
- Stations → **Cruises**: dots link into a track in `order_occ`/`datetime` order (`TripsLayer` can play
  the ship steaming the grid).
- Stations → **Sections**: the line's stations highlight, the depth strip widens into the section.

A few hundred elements, ~300–600 ms — cheap. It earns its place because it *shows the aggregation*
(what a hexagon or an MPA summary is made of), not as decoration; it honours `prefers-reduced-motion`
and `?tour=off`, and the guided tour opens with it.

### D7 · Polygons → Erin's list into the registry, membership into the release, one Region lens

- `metadata/spatial_layers.csv` **is** the sheet Erin asked for; extend it with the columns she named —
  `agency`, `source_url`, `service_type` (ArcGIS REST / feature service / shapefile / gdb),
  `date_accessed`, `coverage` — and add her layers as rows (Coastal Zone + CCC districts + LCP
  jurisdictions, State Lands, Regional Water Boards, ASBS, marine bioregions, no-discharge zones, EFH,
  HAPC, groundfish closures/EFH conservation areas, USACE jurisdictions, NPDES outfalls, OCS blocks/
  leases/planning areas, wind lease + WEA, contiguous zone, US–Mexico boundary, Mexico EEZ). Prioritize
  as she said: downloadable, authoritative ownership, no hand-drawn boundaries. Betty can own the rows
  and the PMTiles rebuild.
- `sample_spatial` moves into the release (D4) — computed once, exact per root sample, tested.
- The three pickers collapse into **one Region lens** (summarize by layer, single-select because layers
  overlap) plus one **"show boundaries" layer toggle** on every lens; the download carries the per-polygon
  summary with `n`, date span, unit — the `env_polygon.csv`/`species_polygon.csv` shape Ben attached on
  2026-08-21.

### D8 · Effort, denominators and attribution → effort travels with every observation; densities are derived once in the release and named; nothing is averaged across denominators, datasets or life stages without saying so

Ben, 2026-08-28, from the "A thought on the integrated app" thread: *"for our default Pacific sardine,
three different units (count, count/10m2, count/100m3) are averaged (which doesn't actually make much
sense) without attributing which datasets … We need to include effort wherever possible and responsibly
resolve denominator differences or provide ways of filtering to datasets and by common denominators."*

What the release actually holds (v2026.08.25, measured 2026-08-28):

- Sardine is **two datasets and two life stages, and both publish raw counts** (`measurement_type =
  abundance`, `units = count`): `swfsc_cufes` eggs, 49,572 rows (underway pump); `swfsc_ichthyo` eggs
  5,906 + larvae 7,420 rows across five gears (C1/CB/CV/PV oblique–vertical, MT manta). The
  `count/10m2` and `count/100m3` in the Hexagon Explorer are its own `prep_db.R` derivations — the
  release never made them, so no other consumer has them.
- Effort exists in `sample_measurement` for **one** bio dataset: ichthyo's `std_haul_factor`,
  `prop_sorted`, `volume_sampled` (76,512 nets, covering all 482,250 ichthyo rows). CUFES has **no effort
  in the release at all** (284,097 rows; `ingest_swfsc_cufes.qmd` reads no volume), and neither do
  phyllosoma (source has `volume_water_filtered_ml_`), mesopelagic-fish (source has `volume_sampled`),
  farallon (survey `effort`) or dungeness (only `prop_sorted` + `settled_volume_ml`).
- Across all 1,255,348 bio rows: **482 k counts with effort** (1 dataset) · **355 k raw counts with none**
  (5 datasets) · 155 k densities already published (euphausiids per m², zoodb per m² and per 1000 m³,
  zooscan per m²) · 263 k other units (cells/L, mgC, µgC, mm).
- Worse than averaging: the polygon summary Ben attached on 2026-08-21 picked the unit with the most
  rows — the bare CUFES `count`, 3,673 rows — and *excluded* the standardized `count/10m2` (739) and
  `count/100m3` (178). Largest-n chose the least comparable unit.

Rules — the first two are release rules, the third an ingest rule, the last two the app's:

1. **Effort travels with the observation.** The browser-shaped `obs_bio` carries, per row, the gear
   (`tow_type`) and the effort of its own sample — `std_haul_factor`, `prop_sorted`, `volume_sampled_m3`,
   pump volume, transect effort as each lands — joined from `sample_measurement` at cut time. No consumer
   re-derives it from ingest parquet again (the `net_tow` workaround the Hexagon Explorer once needed).
2. **Two canonical denominators, derived once, tested, named.** `density_per_10m2` — areal,
   depth-integrated: `count × std_haul_factor / prop_sorted` for oblique/vertical tows, and published
   per-m² densities × 10 — and `density_per_1000m3` — volumetric: `count / prop_sorted / volume_sampled ×
   1000` for any tow with a volume (manta, and CUFES once its volume is ingested), published per-1000 m³
   as is. Raw `count` stays. Every row carries `effort_class` ∈ {`count_with_effort`,
   `raw_count_no_effort`, `density_as_published`, `other_unit`}, and `metadata/measurement_type.csv`
   gains a `denominator` column (`area | volume | none`) so the vocabulary is registry-owned. The
   derivation is **one expression in three runtimes** — `calcofi4r::cc_density_sql()`,
   `calcofi4py.density_sql()`, the explorer's SQL templates — fixture-tested like `cc_qual_ok_sql()` and
   asserted by the consumer-contract suite. Phase 1 puts the columns on `obs_bio`; promoting them onto the
   release `obs` is a later `RELEASES.md` entry once the suite covers them. Areal and volumetric are
   deliberately **not** converted into each other: that needs the tow's integrated depth and an assumption
   about vertical distribution, which is a scientific choice the app must not make silently.
3. **Missing effort is an ingest task, not a UI caveat.** Each bio ingest emits the effort its source has
   into `sample_measurement`: CUFES pump volume (a provider question if the export lacks it), phyllosoma
   volume filtered, mesopelagic-fish volume sampled, farallon transect effort (a third denominator,
   per km², for birds and mammals), dungeness settled volume. `questions.csv` rows for each; until they
   land the rows are `raw_count_no_effort` and the app says so.
4. **The picker is taxon × life stage × denominator, and the legend names all three.** Eggs and larvae
   are never merged. The denominator switch (per 10 m² · per 1000 m³ · raw count) greys out datasets
   that cannot supply it and shows the excluded count; dataset pills with row counts sit under every
   selection; gear (`tow_type`) is a filter. The **default** is the denominator that covers the most
   datasets *with effort* for that taxon and stage — never largest-n; raw counts are labelled "not
   comparable across gear or datasets". A station, hexagon, cruise or polygon summary that would mix
   denominators, datasets or stages is not computed — the UI asks which. (Env has no denominators, but
   the same pills attribute bottle vs CTD temperature, which *are* comparable.)
5. **Attribution as before.** The release `dataset` table already carries `citation_main`,
   `citation_others`, `license`, `pi_names`, `link_data_source`; every bundle gets `CITATION.md` (D10)
   and every downloaded row carries `dataset_key` and `effort_class`. Erin's next step with Rasmus and Ed
   — preferred citations per provider — lands as edits to the ingest `dataset_meta` blocks.

Sardine, the spike's default, therefore opens as **larvae · per 10 m² · swfsc_ichthyo (6,158 rows; 1,262
manta rows excluded, available per 1000 m³)**, with pills reading *ichthyo larvae 7,420 · ichthyo eggs
5,906 · CUFES eggs 49,572 (raw count, no effort in release)* — instead of one number averaged over all
62,898 rows.

### D9 · Name, URL, brand → **CalCOFI Explorer** at **`calcofi.io/explore/`** (repo `CalCOFI/explore`, GitHub Pages); lenses as subtitles; brand v1 as the connective tissue

- **`calcofi.io/explore/`, not `app.calcofi.io/explore/`** (Ben, 2026-08-28). `calcofi.io/<repo>` is
  where the static products already live — `db-query`, `db-schema`, `ctd-transects`, `workflows`, `docs`,
  the package sites — and `app.calcofi.io/*` is the server (Caddy → shiny-server; `/station` is the one
  static exception, hosted on the VM only to get a short path). A static explorer belongs with the
  former: Pages CI deploys, GitHub's CDN, no VM in the request path, and a URL that reads as a product
  of the site rather than "an app" — which is what Erin's naming ask is about. A Pages project site is
  always `/<repo>/`, so the repo is named **`explore`** (the `app-*` repo-rename TODO in
  `calcofi_notes.md` does not apply to it). `app.calcofi.io/explore` becomes a 308 alias in the
  Caddyfile so either form works; the `cc_theme` cookie is on `.calcofi.io`, so the theme carries.
  Pages' limits (1 GB site, 100 GB/month soft) are irrelevant — the data comes from GCS and the app
  bundle is ~6 MB. Three-slug contract: `explore` in `products.yml`, `uptime`, `analytics`.
- One product name resolves the renames thread: the card says *CalCOFI Explorer*; the lens names are
  the subtitles Erin wanted ("Stations — what has been collected where"; "Hexagons — larval fish and
  oceanography by area"…). The old `app.calcofi.io/{station,hex,cruise,contour}` paths become 308s into
  `calcofi.io/explore/?lens=…` (query strings preserved — the `route {}` gotcha from the 2026-08-25
  rename applies) when each lens reaches parity, so shared links keep working.
- Mark's brand question: the app consumes `calcofi.io/brand/v1/` (theme cookie, `.cc-header`, favicon,
  release chip) and exposes its own components — picker, dataset pills, water-column strip, release
  chip — as a small kit the dataset-specific apps reuse. That is the "connective tissue"; the SIO
  template's whitespace governs calcofi.io pages, not a data-dense app. Erin's dark-by-default stays
  (it is the brand contract's default already).

### D10 · Downloads and reproducible code → first-class: the bundle is the query plus the bytes, and the same SQL runs in the browser, R and Python

Ben's question, 2026-08-28: will the app include packaged downloads and code (SQL / Python / R notebook) for
reproducible access given the current filters? **Yes — and in this architecture it is nearly free.** Every
lens is SQL over public, immutable release objects, so a download is not a feature bolted onto a
visualization; it is the app handing over what it just ran. `db-viz-hex` already proves the shape
(`build_download_bundle`, `functions.R:2762`: `data/original|summarized|integrated/` + `query/manifest.json`,
per-file `.sql`, `REPRODUCE.md` — the `calcofi_data_20260820.zip` Ben sent Erin on 2026-08-21) and
`db-viz-station` the mechanics (JSZip in the browser, CSV/PNG, observation CSVs via DuckDB-WASM, generated
ERDDAP/ZooDB query URLs). The explorer generalizes both, entirely client-side:

**The bundle** — `calcofi_explore_<lens>_<release>_<yyyymmdd>.zip`, built with JSZip from the in-memory slice:

```
README.md            what was selected, the URL that reproduces the view, release + catalog sha256, generated-at
CITATION.md          per dataset in the selection: citation_main, citation_others, license, pi_names (from `dataset`)
data/summary/        the lens table as shown — one row per station | hex | cruise | polygon | (line, depth bin) —
                     CSV, plus GeoJSON for map grains (geometry from `grid`, H3 cell boundaries, or `spatial`)
data/observations/   the filtered observation rows behind it — CSV and Parquet (DuckDB-WASM `COPY … TO`) —
                     every row carrying dataset_key, life_stage, effort_class, the density columns, measurement_qual, depth_min_m/max_m
data/reference/      dataset.csv, the measurement_type and taxon rows used, the polygon layer's attributes
query/
  selection.json     the URL parameters, verbatim
  01_slice.sql …     the exact SQL the browser ran, table tokens resolved to the release's canonical https
                     object URLs — content-addressed, so the query runs unchanged in ten years
  reproduce.R        calcofi4r: cc_get_db(version = …) / cc_read_parquet_sql() + the same SQL
  reproduce.py       calcofi4py: release_sources() + duckdb, the same SQL
  reproduce.qmd      the R notebook: selection → query → the summary table → the same figure
  reproduce.ipynb    the Python notebook, same cells
```

In-app: a **"Copy as…"** menu (SQL · R · Python · curl of the object URLs) beside every lens, and **"Open in
db-query"** (needs a `?sql=` parameter in `db-query`, a small addition). Rules that make it trustworthy:

- **One SQL, three runtimes.** Templates live in `explore/sql/*.sql` with named parameters bound from the
  selection; the browser executes them and the generators emit them verbatim. A parity test runs every
  template in DuckDB-WASM (node), R and Python against the frozen release on each `db-release` and compares
  row counts + hashes — the `match.js` ≡ `calcofi4r` precedent (2026-05-17 plan) made systematic — and
  `test_release.qmd`'s consumer-contract suite gains the same templates, so a schema drift fails the
  release rather than someone's notebook.
- **Pinned, explicit, honest.** Generated code pins the release (`?release=` → `cc_get_db(version =
  "v2026.08.25")`), states the quality predicate (`qual_ok`), the life stage and denominator chosen (D8), the depth band,
  the viewport bbox *if* it was applied as a filter, and the `sample_spatial` join behind a region summary
  — the number in the notebook is the number on the screen, by construction rather than by care.
- **Raw data beyond the slice is a pointer, not a payload.** The bundle never streams `obs_ctd_full`; for
  anything larger than the in-memory slice (tens of MB) it includes the canonical object URLs and the code
  that reads them — the content-addressed store means "download the object" is always available.
- **Downloads are tracked** (`cc_track`-style beacon carrying the selection URL), so Erin's usage reporting
  and the providers' citations can show what is actually taken, by dataset.

Phasing: Phase 2 ships the bundle with README, CITATION, summary + observations, `query/*.sql`,
`reproduce.R`/`.py`; Phase 3 adds the notebooks (`.qmd`, `.ipynb`), "Copy as…", "Open in db-query" and the
parity CI; Phase 4 adds the section/Hovmöller matrices (the `ctd-transects` shard format). ~+10 h across
Phases 2–3, counted in the table below.

## Architecture

```
release (GCS, content-addressed)                  browser (static app, GitHub Pages / static.calcofi.io)
─────────────────────────────────                 ──────────────────────────────────────────────────────
catalog.json ── objects[] per table ─────────────▶ release.ts  (port of cc_release_sources; picks files)
obs_bio.parquet (1 file, ~15–20 MB)  ────range──▶ DuckDB-WASM ── GROUP BY grid_key | hex_r{3..7} |
obs_env/measurement_type=temperature/… ──range──▶               cruise_key | spatial_key | line×depth_bin
sample_spatial.parquet, grid, spatial, dataset ─▶               | year×depth_bin  … ⟶ lens data
coverage.json ───────────────────────────────────▶ first paint (Stations lens) before WASM is warm
_spatial/*.pmtiles ──────────────────────────────▶ MapLibre boundaries
                                                   deck.gl layers + transitions ⟵ selection store ⟷ URL
                                                   Plotly: water-column strip · time strip · section · Hovmöller
build (calcofi4db, release_database.qmd)          CI: repository_dispatch db-release → refresh coverage.json
```

**Selection model (the URL):** `lens` · `res` (hex) · `taxon` | `var` · `datasets` · `unit` · `years` ·
`q` (quarters) · `depth` (band) · `layer` + `region` · `line` | `cruise` · `stat` (mean/median/n/anomaly)
· `release` · `theme` · `tour`. Every lens is a pure function of the slice and the URL — which is also what
makes D10 mechanical: `explore/sql/*.sql` templates + the URL are the whole reproduction recipe, and the
generators (`query/*.sql`, `reproduce.R|py|qmd|ipynb`) are string templates over the same two inputs.

## Phases

| phase | what ships | ~hours |
|---|---|---:|
| **0 · Decide + spike** (9/3, 9/8) | Confirm D1–D3. A 2-day spike: a hand-cut `obs_bio` + `obs_env/temperature` object (the D4 shape), no extensions, DuckDB-WASM in a worker, aggregate to station/res 5–7, deck.gl with transitions; measure on a laptop and a phone, first visit and repeat. Go/no-go: first paint < 1 s (prebuilt), first custom query < 4 s cold and < 100 ms warm, grain switch < 300 ms, the bio slice holds on a phone. A miss routes the `http` transport into Phase 2 (D4). **Measured 2026-08-28** (production build on localhost, 8-core laptop, Chrome, fresh profile → repeat visit): first paint 1.06 s cold / 0.34 s warm · engine + objects + slice ready 2.5 s / 0.78 s · first lens query 13 ms · grain switch 27–47 ms (+ 700 ms transition by design) · phone-shaped viewport ready in 0.83 s — **go**; detail and caveats under "Phase 0 — measured" below. | 12 |
| **1 · Release additions** (`calcofi4db`) | `obs_bio` / `obs_env` browser-shaped objects with `hex_r3…7`, `depth_bin`, `qual_ok`, effort columns; `sample_spatial` computed per root sample, chunked per layer, with a row-count assertion per layer; `coverage.json`; `density_per_10m2`/`density_per_1000m3` + `effort_class` on `obs_bio`, `denominator` column in `measurement_type.csv`, `cc_density_sql()` in calcofi4r/py, effort-ingest questions filed for cufes/phyllosoma/mesopelagic/farallon/dungeness (D8); catalog entries; `RELEASES.md` § Unreleased. Tests for each derivation. | 30 |
| **2 · App skeleton + Stations + Hexagons** | `explore` (Vite/React/TS, Pages), brand v1, URL state, release picker, picker with dataset pills + units, water-column and year strips as linked brushes, Stations lens at parity with `db-viz-station`'s coverage, Hexagons lens at parity with `db-viz-hex`'s map/time-series/depth profile, download bundle with `CITATION.md` + `query/*.sql` + `reproduce.R|py` (D10). `/station` redirects. | 65 |
| **3 · Regions + Cruises** | Region lens over `sample_spatial` (single-select layer, "no data" outlines, per-polygon download); extended layer registry (Betty); Cruise lens with track animation and the space-time plot from `db-viz-cruise`. `/hex`, `/cruise` redirect; H3T/Varnish/`db-viz-hex` `prep_db.R` retire. Notebooks (`.qmd`, `.ipynb`), "Copy as…", "Open in db-query", SQL parity CI (D10). | 30 |
| **4 · Sections + Hovmöller** | Section lens (line or cruise track × depth, anomaly default) folding in `ctd-transects`; Hovmöller; contour-as-rendering on the Stations lens (IDW in-browser) so `oceano` can be archived. | 20 |
| **5 · 3-D + tour + polish** | Optional 3-D cruise view; grid-morph tour; `?tour=off` screenshots + `shots: themed`; weekly `check_brand.py` passes; analytics slugs; docs chapter. | 15 |
| | **total** | **~172** |

The SoW's Visualize line is **113 h**, and it currently words the deliverable as "expanded hexagon
summarization … continued H3T and management-area layers in the integrated app". This plan delivers the
same outcomes (hexagon summaries across every ingested dataset, management-area layers) in the explorer
instead of in Shiny + H3T — a wording change to raise with Erin and Mark, not a scope change. Phase 1 is
legitimately Integrate/Publish work (`sample_spatial` and the coverage cube are release products, and the
coverage cube is Task 14's variable-based inventory), which is where most of the ~60 h gap belongs. If hours must
be cut, cut Phase 5 first, then defer the Cruise lens (the app it replaces is 700 lines and already
deep-linkable).

## Phase 0 — spike brief (for a fresh session; asked 2026-08-28, wanted within two days)

**Deliverable.** A local Vite app in `~/Github/CalCOFI/explore` (new local git repo — **do not create the
GitHub repo or push**; Ben decides that) that opens on the CalCOFI grid and morphs through **Stations →
Hexagons → Cruises → Regions → Sections** for one taxon (Pacific sardine, `worms:217452`, 62,898 bio rows)
and one env variable (`temperature`; `oxygen_ml_l` is cut too, for the variable switch), with a depth strip,
a year range, URL state and a timing panel. It is a demo of the grain morph and a measurement of the D4
cold-start budget — not Phase 2. Ugly is fine; slow is a finding.

**Data — already cut**, by `~/_big/calcofi/explore-spike/build_spike_data.sql` from the local
v2026.08.25 release into `~/_big/calcofi/explore-spike/data/` in 82 s — **measured: `obs_bio.parquet` 28 MB (with effort + densities) (1,255,348 rows), `temperature` 4.5 MB (884,402), `oxygen_ml_l` 3.5 MB (725,630), `sample_spatial` 308 KB (92,589 memberships), `sample_root` 11 MB (419,543), `spatial_spike.geojson` 1.5 MB, `grid.geojson` 400 KB** — so the bio object is over the plan's 15–20 MB guess (the effort and density columns are worth it) and an env variable is well under it; symlink the
directory to `public/data/` so `vite dev` serves it, later copy to GCS for the cross-origin test):

- `obs_bio.parquet` (28 MB, re-cut by `build_spike_bio_effort.sql`) — the whole bio realm, slim: `realm,
  dataset_key, root_id, grid_key, cruise_key, latitude, longitude, datetime, year, quarter, depth_min_m,
  depth_max_m, depth_bin, taxon_key, life_stage, measurement_type, unit, value, measurement_qual, qual_ok,
  tow_type, std_haul_factor, prop_sorted, volume_sampled_m3, density_per_10m2, density_per_1000m3,
  effort_class, hex_r3 … hex_r7` (H3 cell strings — `H3HexagonLayer` takes them directly; `h3-js` gives
  centroids/boundaries client-side, no WASM extension). The density and `effort_class` columns implement
  D8 rule 2 exactly as written there; the spike's picker must implement rule 4.
- `obs_env/measurement_type=temperature/data.parquet`, `…=oxygen_ml_l/…` — same columns.
- `sample_root.parquet` — root events with `root_id`, position, `datetime`, `cruise_key`, `order_occ`,
  `tow_type`, `seafloor_depth_m` (cruise tracks = root samples ordered by `datetime` per `cruise_key`).
- `sample_spatial.parquet` — exact per-root-sample membership for four layers: Marine Protected Areas,
  National Marine Sanctuaries, CDFW Regions, CA Counties (`root_id, layer, spatial_key, spatial_name`).
- `spatial_spike.geojson` (those four layers, simplified 0.002°), `grid.geojson` (218 cells with
  `lon_ctr`/`lat_ctr` — the morph's home positions), `cruise.parquet`, `dataset.parquet`,
  `measurement_type.parquet`, `taxon_bio.parquet`.
- `qual_ok` is `calcofi4r::cc_qual_ok_sql()` evaluated at cut time (bottle/CTD 8, 9; DIC 3, 4, 9).

**Stack (D3, minimal).** Vite + React 18 + TypeScript · `maplibre-gl` with a keyless CARTO dark/light style ·
`@deck.gl/react`, `@deck.gl/layers`, `@deck.gl/geo-layers` (`ScatterplotLayer`, `H3HexagonLayer`,
`PolygonLayer`, `TripsLayer`) via `MapboxOverlay`, `transitions` on `getPosition`/`getFillColor`/`getRadius`
with stable ids · `@duckdb/duckdb-wasm` **self-hosted bundles in a Web Worker, no extensions**, objects
fetched whole and registered with `registerFileBuffer` · `plotly.js-dist-min` for the depth strip and the
section · `h3-js` · brand from `https://calcofi.io/brand/v1/` (theme css/js + header), dark default ·
URL state hand-rolled with `URLSearchParams` + `history.replaceState` (the `ctd-transects` pattern).

**SQL templates** (`explore/sql/*.sql`, named parameters; the browser runs them, D10 will emit them):
`station.sql` (`GROUP BY grid_key`), `hex.sql` (`GROUP BY hex_r{res}`), `cruise.sql` (`GROUP BY cruise_key`
+ track from `sample_root`), `region.sql` (join `sample_spatial` on `root_id`, `GROUP BY spatial_key`,
unsampled polygons drawn as outline + "no data"), `section.sql` (one line × `depth_bin`, one cruise, plus
the climatology for the anomaly), `depth_strip.sql` (median/IQR by `depth_bin`), `years.sql`. Every template
filters on `qual_ok`, the year range, the depth band and — for bio — **one life stage and one denominator**
(`density_per_10m2` | `density_per_1000m3` | raw `value`), with the excluded rows counted per dataset for
the pills; a template never aggregates across `effort_class` (D8).

**Day 1.** Scaffold; worker + engine warm-up behind a static first paint (station dots from `grid.geojson`
before any WASM); fetch the two objects; Stations and Hexagons lenses (res 4–7, control or zoom) with
transitions; picker (taxon × life stage × denominator with dataset pills and excluded counts — D8 rule 4 — or variable); year range; URL state; timing panel (first paint, WASM init, fetch,
first query, grain switch).
**Day 2.** Cruises (`TripsLayer` playing the track), Regions (single-select layer, exact membership), Sections
(Plotly heatmap `zsmooth: "best"`, line 90 default, anomaly toggle), depth-strip brush recoloring the map, the
grid morph as the opening move (grid → chosen lens), `prefers-reduced-motion` respected; `vite --host` for a
phone check; record the measured numbers in the Phase-0 row above and a one-paragraph verdict here.

**Go/no-go (from D4):** first paint < 1 s · first custom query < 4 s cold / < 100 ms warm · grain switch
< 300 ms · the bio object holds on a phone.

**Kickoff prompt** (fresh session at xhigh, cwd `~/Github/CalCOFI/workflows`):

> Read `.claude/plans/2026-08-28 CalCOFI Explorer — one browser-native app across station, hexagon, cruise,
> region & section grains.md`, section "Phase 0 — spike brief", and build exactly that in
> `~/Github/CalCOFI/explore` (new local repo; do not create the GitHub repo or push). The data is already cut
> at `~/_big/calcofi/explore-spike/data/` (see `_sizes.txt`). Work in a few large files, verify in Chrome with
> one screenshot per lens, and append the measured numbers to the plan. Do not re-derive anything the brief
> already states.

### Phase 0 — measured (2026-08-28; built in `~/Github/CalCOFI/explore`, local repo, commit `287c020`, not pushed)

**Setup.** `vite build` served by `vite preview` on localhost — so every fetch below is loopback-bound and
the network cost of a first visit is estimated from bytes, not measured — driven headed through the
installed Chrome by `scripts/verify.mjs` (puppeteer-core; a fresh profile is "cold", the same profile
reloaded is "warm"), MacBook 8 cores / 16 GB, dark theme, `?tour=off`. The "phone" column is an emulated
390×844 viewport in the same Chrome: a layout/behaviour check, not a phone CPU or memory — the real phone
check is still to do (`npx vite preview --host --port 5179`, then http://192.168.178.173:5179/ on the LAN).
Sizes: `obs_bio.parquet` 29.5 MB, `temperature` 4.7 MB, `sample_root` 11.3 MB (fetched lazily, Cruise lens
only); duckdb-wasm `1.33.1-dev57` `eh` bundle 35.9 MB raw = 8.1 MB gzip = 6.5 MB brotli; app JS 6.4 MB
(1.9 MB gzip) in one chunk. Sardine opens exactly as D8 says: larva · per 10 m² · swfsc_ichthyo, 6,158 rows in
view, 1,262 manta rows excluded, pills *CUFES egg 49,572 ⚠ · ichthyo egg 5,906 · ichthyo larva 7,420*.

| go/no-go | target | cold (first visit) | warm (repeat) | phone-shaped |
|---|---|---|---|---|
| first paint — basemap `load` + 218 grid dots, before any WASM | < 1 s | **1.06 s** ✗ (by 60 ms) | 0.34 s ✓ | 0.32 s ✓ |
| engine + objects + slice ready | — | 2.48 s (wasm init 1.14 s ∥ `obs_bio` fetch 0.99 s → slice 0.84 s) | 0.78 s (0.50 ∥ 0.21 → 0.18) | 0.83 s |
| first lens query — station, 6,158 rows → 137 stations | < 4 s cold · < 100 ms warm | **13 ms** ✓ (answered 2.52 s after page open, everything included) | 4.5 ms ✓ | 5 ms ✓ |
| grain switch — click → the new lens's data (700 ms transition excluded) | < 300 ms | hex 27 · region 47 · section 30 · cruise 348 ✗ (271 ms of it is the first, lazy 11 MB `sample_root` fetch; 76 ms once it is registered) | station 24 · hex 27 ✓ | — |
| env variable — temperature, 884,402 rows | — | slice 0.72 s · station 54 ms · depth strip 56 ms · section (line 90, one cruise + climatology) 157 ms | | |

Every lens query on the sardine slice is 4–20 ms; on the 884 k-row temperature slice 20–60 ms. Aggregation
is not where the time goes — D4 point 4 holds with a wide margin. What the cold column actually contains:

- **The first paint miss is the app bundle and the basemap, not WASM.** The dots depend on `grid.geojson`
  (400 KB) and React; the mark waits for MapLibre's `load` (CARTO tiles over the real network) and sits
  behind a 6.4 MB single JS chunk (Plotly is ~3.5 MB of it). Code-split Plotly and deck's extra layers
  behind the first frame and mark the dot frame itself, and this is well under 1 s. Trivial, and Phase 2's.
- **WASM is not the cold-start problem the `db-query` numbers suggested.** Self-hosted, no extensions,
  in a worker: 1.14 s to instantiate cold (35.9 MB raw off loopback; 6.5 MB brotli over a CDN is ~1 s at
  50 Mbps) and 0.50 s warm, entirely overlapped with the object fetch. The `latest` npm tag is a dev build
  (`1.33.1-dev57`, the only tag published); a release build should be pinned and re-measured.
- **The bio object is the real first-visit cost.** 29.5 MB — the plan guessed 15–20 MB before the effort
  and density columns went in. Off loopback it is 1 s; at 50–200 Mbps broadband it is 1.2–5 s, once, then
  immutable and cached (0.21 s warm here, and content-addressed URLs make that the steady state). Worth
  measuring what the five `hex_r3…7` strings cost (one UBIGINT cell + `h3-js` parents client-side would
  remove four columns) before Phase 1 fixes the shape. One env variable at 4.7 MB is well under budget.
- **Repeat visits are 0.8 s to a live, queryable app** with nothing prebuilt — which means `coverage.json`
  and the prebuilt default views (D4 point 1) buy a first visit, not the common case.

**Verdict — go on D2–D4.** Three of four gates pass with room; the two misses are a 60 ms first-paint
overshoot with an obvious cause and a one-off lazy fetch inside the cruise gate. Nothing here routes the
`http` transport into Phase 2; keep it behind the interface. The spike also settled the morph: dots
travelling to their H3 parents while hexagons cross-fade in, gathering at sanctuary centroids, linking
into the cruise track under a `TripsLayer`, highlighting the line under the section — a few hundred
elements, 700 ms, and it reads as the aggregation it is.

**What the build surfaced, for Phase 1 (the data cut) and Phase 2 (the app):**

- `obs_bio` carries no depth for ichthyo (`depth_min_m`/`depth_max_m` NULL; the root sample is the
  `site`, the tow span lives on the net), so the water-column strip is empty for the default taxon and the
  bio "section" is line × year. The release cut must carry the tow span on every bio row (D5's
  "integrated span" grain).
- `sample_root` (11.3 MB, 419,543 rows) exists only to draw one cruise's track; the release should ship
  tracks per cruise (a few KB each) or a single `cruise_track` object, not the whole root table.
- The section over historical bottle cruises is banded — 1950 sampled standard depths, not every 10 m bin
  — so the release-time climatology should be on standard levels, with `zsmooth` interpolating between.
- `maplibre-gl` 6 ships a module worker that Vite's dependency optimizer breaks (no tiles, no `load`,
  no error); pinned to 5.24 with deck.gl 9.3.10. `@duckdb/duckdb-wasm` must be in `optimizeDeps.exclude`
  for the same reason. And the Claude-in-Chrome MCP tab never paints (`outerWidth` 0, `document.hidden`,
  0 rAF/s), so nothing that needs a frame — MapLibre, transitions — can be verified there;
  `scripts/verify.mjs` drives a real window instead and is the way to take these numbers again.
- The picker's rule-4 defaults are two pure functions (`defaultStage`, `defaultDen` in `src/state.ts`)
  over `picker.sql`'s rows; they belong in `calcofi4r`/`calcofi4py` beside `cc_density_sql()` so the
  kit and the packages agree on what "default" means.

Screenshots (one per lens, cold, plus env section with anomaly, warm hex morph, phone viewport) are in
`explore/shots/prod/` with `results.json` holding every mark.

### Phases 1–2 — executed (2026-08-28, same day; `CalCOFI/explore` created and pushed, Pages live at calcofi.io/explore/)

**Phase 1 (release additions) — calcofi4db 3.24.0, calcofi4r 1.13.0, calcofi4py 0.5.0, workflows wiring; a
staging release run (`ducklake-staging/`) is proving the chunk end-to-end.**

- `R/explore.R`: `build_sample_root()` (dense deterministic `root_id`), `build_obs_slim(con, realm, qual_ok_sql,
  density_sql)` → `obs_bio` / `obs_env` (one schema; `hex7` UBIGINT; depth = obs → sample → root), `h3_parent_sql()`
  (bit arithmetic, tested against `h3_cell_to_parent()` for res 0–9), `build_sample_spatial()` (polygon layers
  only, chunked per layer, duplicates refused), `build_coverage()` + `build_coverage_stations()`;
  `release_sort_keys()` registers the four tables. 65 tests. Measured over v2026.08.25: `obs_bio` 0.9 s → 21.8 MB
  (the five hex strings were 7.4 MB of the spike's 29.5; one UBIGINT + a total ORDER BY is the shape), `obs_env`
  5 s → 84 objects ≤ 10 MB, `sample_spatial` 104 s (15 polygon layers, ≈1 M memberships, 7.3 MB), `coverage.json`
  181 KB + `coverage_stations.json` 475 KB.
- `cc_density_sql()` / `density_sql()` — one expression, three runtimes, fixture byte-identical
  (`calcofi4r/tests/testthat/fixtures/density_sql.txt` = `calcofi4py/tests/fixtures/density_sql.txt` =
  `explore/sql/density.sql`); `cc_default_stage()` / `cc_default_denominator()` = `state.ts`'s two functions.
- `release_database.qmd` chunk `browser_objects` (after `normalize_crs`): builds the four tables, writes
  `coverage.json`, `coverage_stations.json`, `grid.geojson`, `spatial.geojson` sidecars (uploaded beside
  `catalog.json`, tagged `no-cache`), `core_keep += sample_spatial`, `supplemental_keep += sample_root, obs_bio,
  obs_env`, `core_spec` rows; `test_release.qmd` +7 contract rows; `measurement_type.csv` `denominator`;
  `relationships_cross.csv` + `release_columns.csv` rows; `RELEASES.md § Unreleased`; six provider questions
  (cufes Q05, phyllosoma Q05, mesopelagic Q08, farallon Q08, dungeness Q13 — effort; **ichthyo Q08 — no tow
  span anywhere in `sample`**, found by the cut: `depth_max_m` is NULL for every ichthyo tow/net).
- The staging path had a latent gap: on a date with no `# vYYYY.MM.DD` section the run skipped
  `promote_unreleased()` and then demanded the section; it now promotes in memory only.

**Phase 2 (app) — shipped in `CalCOFI/explore` (Pages workflow, `VITE_DATA_URL` = bucket root +
`VITE_RELEASE_PREFIX`):** `release.ts` (port of `cc_release_sources`: canonical `objects[]` first, compat path
second; `?release=` → `latest.txt`; `versions.json` picker), coverage-first paint (station dots from
`coverage.json` before any WASM; `index.html` starts `latest.txt` → catalog/coverage/grid fetches before the
bundle parses), all 84 env variables from the release (labels from `measurement_type`), the station coverage
card (`coverage_stations.json`: per-dataset years + months, db-viz-station's card), the year strip as a
mean ± se time series broken at unsampled years (db-viz-hex's series), and the **D10 bundle** (README,
CITATION from `dataset`, `data/summary` CSV + GeoJSON, `data/observations` parquet + CSV ≤ 300 k rows,
`data/reference`, `query/01–04_*.sql` resolved to the canonical object URLs + `objects.json` with bytes/sha256,
`reproduce.R`/`.py`/`.qmd`/`.ipynb`, "Copy as…" SQL/R/Python; hex 0.67 MB in 0.4 s, env-region 4.4 MB in 2 s). **Parity verified on a live bundle:** `scripts/parity/parity.{R,py}` run its `query/*.sql` and reproduce the browser's 1,048-hex table exactly (max |Δ| 4.5e-13, counts equal) — the same SQL in three runtimes. Plotly is lazy (main bundle 6.4 → 2.5 MB),
duckdb-wasm pinned to the 1.29.0 release (7.1 MB gz). PRs open for the three-slug contract:
CalCOFI.github.io #5 (card + themed shots), uptime #90. Until a release ships the objects, Pages reads a
catalog-shaped copy of them at `gs://calcofi-db/explore-dev-root/explore-dev/` built by the same
`release_objects()`/`build_release_catalog()`.

**Live, cross-origin (calcofi.io/explore → GCS, one broadband run each):** cold — catalog 0.9 s, first paint
1.55 s, wasm 2.3 s, `obs_bio` 3.7–5.4 s, ready 6.5 s, first lens query 14 ms; warm — first paint 0.3 s, ready
1.2 s, queries 7–40 ms; phone-shaped — ready 0.96 s. The cold budget is now the `obs_bio` download and nothing
else; a per-dataset (or per-taxon-rank) split of the bio object would let the default open on ~60 % of it.
Cruise's first switch pays the lazy 11 MB `sample_root` (0.8–2.3 s): ship per-cruise tracks.

**Left for the next session:** merge the two PRs after review; cut the real release (the chunk is proven by
the staging run — see `release_database-staging-p1.html`) and flip Pages to `ducklake/releases`; `/station`
308; effort ingests once the providers answer; Phase 3 (Cruise/Region parity, notebooks, "Copy as…", SQL parity
CI) and Phase 4 (Section/Hovmöller, contour rendering).

## Risks and what bounds them

- **DuckDB-WASM cold start and footer reads** — `db-query` measured ~5 s init and 10–20 s of footers on
  multi-object queries. Bounded by D4's cold-start budget (no extensions; one whole-object fetch per lens;
  content-addressed URLs cached forever; `coverage.json` + prebuilt defaults for first paint; engine warmed
  in a worker), the Phase-0 numbers as a hard go/no-go, and a same-SQL `http` transport to a warm native
  DuckDB as the fallback if they miss.
- **Memory on iOS/Safari** (~1–2 GB tab budget) — slices are tens of MB; `obs_ctd_full` never enters.
- **The membership join moves, it does not vanish** — it runs once per release on the pipeline machine,
  chunked per layer, instead of on the 16 GB server per app. Membership stays exact (per root sample).
- **Exactness of polygon summaries vs today** — same definition (`sample_spatial` by `sample_key`), so
  numbers match `db-viz-hex`'s "Summarize Within" bundle; assert that in Phase 3.
- **Two front ends during migration** — each lens replaces exactly one app, with a 308 and a banner;
  no period where a grain has no home.
- **Skills** — React/TS is new to the fleet; the kit is small and the patterns (`release.ts`,
  `catalog` resolver, brand head/header) are ports of code that already exists in JS.
- **What is lost from R** — `MBA::mba.surf()` sections (replaced by `zsmooth`, already proven),
  server-side arbitrary SQL through H3T (replaced by `db-query` for power users).

## For 9/3 and 9/8

1. One explorer with five lenses for the integrated database; dataset-specific apps stay, share the kit. (D1)
2. Browser-native and static; Shiny stays for QA/internal tools. (D2)
3. React + TypeScript, MapLibre + deck.gl, DuckDB-WASM, Plotly — or Svelte if Ben owns the front end. (D3)
4. The release grows `obs_bio`/`obs_env`/`sample_spatial`/`coverage` so every consumer — not just this app —
   gets exact polygon summaries and cheap slices. (D4, D7)
5. Depth as an axis with three drawn grains; sections and Hovmöller; 3-D last and optional. (D5)
6. Name "CalCOFI Explorer" at `calcofi.io/explore/` (repo `explore`, Pages), lens names as subtitles; brand v1
   is the connective tissue. (D9)
7. SoW wording: same Visualize deliverables, delivered in the explorer instead of `db-viz-hex` + H3T.
8. Bring the Phase-0 spike to 9/8 if it can be built in time — a station ↔ hexagon morph over one taxon
   is the most persuasive minute of the meeting.
9. Every view downloads as a bundle with the bytes, the exact SQL against content-addressed object URLs,
   `CITATION.md`, and R/Python/notebook code pinned to the release — parity-tested per release. (D10)
10. Effort travels with every bio observation; two canonical denominators (per 10 m², per 1000 m³) derived once
    in the release and named; picker = taxon × life stage × denominator with dataset pills; missing effort is an
    ingest task (CUFES first). Nothing averaged across denominators, datasets or stages silently. (D8)

## Appendix A — fleet inventory (2026-08-28)

- **db-viz-hex** — Shiny + bslib, `mapgl` fork `bbest/mapgl@feat/add-h3t-source`, `maplibreCompareOutput`,
  plotly, highcharter, DT, conductor; `prep_db.R` (790 lines) reads `obs, sample_measurement, sample,
  taxon, dataset_taxon, measurement_type, spatial, spatial_attribute` → `calcofi_<v>.duckdb` (475 MB) +
  `hex.geojson` (146 MB, 434 k polygons, 10 resolutions; fallback only — tiles come from H3T). Layers in
  three places (`functions.R:1418`, `functions.R:2085`, `global.R:120-146`); polygon summary is
  server-side DuckDB on raw obs joined to `sample_spatial` (`functions.R:697, 781`). Download bundle is
  reproducible (`build_download_bundle`, `functions.R:2762`). No URL state. 6,321 lines; 81 commits in 2026.
- **db-viz-station** — vanilla JS + Leaflet; `scripts/build_*.sql` through `resolve_release.py` + the
  catalog → `public/data/*.json` (~8 MB); DuckDB-WASM lazily for observation downloads; CI `pages.yml`,
  `refresh.yml` (weekly + `repository_dispatch: db-release`), `check.yml`. `CLAUDE.md:148`: "one file,
  plain script tag, everything at global scope … no bundler." 4,638 lines `app.js`; 128 commits in 2026.
- **db-viz-cruise** — Shiny + bslib + `mapgl` + plotly; `prep_db.R` streams `sample` root events; URL
  round-trip via `getQueryString`/`updateQueryString` (`server.R:22,84`). 701 lines.
- **oceano** — Shiny + shinydashboard + Leaflet + `leaftiles`; PostGIS `gis` DB, `functions_pgidw.R` IDW
  cached under `/share/data/cache_idw`; `# TODO: play: animate window of time` never built. 879 lines.
- **ctd-viz** — Shiny + bslib + `mapgl` + `MBA::mba.surf()` + terra (GEBCO 4.3 MB); `ctd-viz.duckdb` 465 MB
  (legacy `ctd_cast`/`ctd_thin` names); bookmarking + Share. 1,696 lines.
- **ctd-transects** — vanilla JS + vendored Plotly; 896 shards (line × cruise station×depth matrices, 5 m
  bins to 500 m); `?line=&cruise=&var=&mode=anomaly|value`; committed line/station bathymetry from
  `cc_transect_bathy()`. 686 lines.
- **Services** — `api-h3t-py` (FastAPI; `GET /h3t/{z}/{x}/{y}.h3t?q=<base64 SELECT>`, `/stats`, `/meta`;
  h3j JSON; res 1–10 by zoom; reads `db-viz-hex/data/calcofi_latest.duckdb`, **not** the release) behind
  Varnish 7 (1 GB, 24 h TTL, `release=` busts). `db-query` (DuckDB-WASM 1.29.0, httpfs + spatial, GCS
  direct, catalog resolver). `calcofi4r`: `cc_grid` (217 keys), `cc_grid_ctrs`, `cc_grid_zones` (6),
  `cc_places` (27 polygons, 5 categories), `cc_catalog`/`cc_release_sources`/`cc_read_parquet_sql`,
  `cc_qual_ok_sql`, `cc_transect_*`, `cc_brand_*`, `cc_track*`. Server: caddy, rstudio (shiny-server),
  postgis, erddap, h3t_api_py, varnish, pg_tileserv, plumber (legacy); `app.calcofi.io/station` is a
  static `file_server`, `/hex /cruise /contour /ctd` proxy to shiny-server.
- **Nothing in any repo mentions React, Svelte, deck.gl, kepler.gl, three.js or Cesium.** Precedents for
  the direction: `.claude/plans/2026-05-17 Browser-only Match app (DuckDB-WASM)…`, `…2026-08-06 … ship a
  static transect app.md`, `ctd-transects/README.md:12-24`.

## Appendix B — sources

- Email "Update map layers on integrated app?" (Erin 2026-08-20; Ben 2026-08-21 with the three-pickers
  screenshot and `calcofi_data_20260820.zip` polygon summaries).
- Email "CalCOFI.io product renames & themes" (Ben 2026-08-25 ×2, Erin 2026-08-26, Mark 2026-08-27,
  Ben 2026-08-27, Erin 2026-08-27, Mark 2026-08-27).
- Email "A thought on the integrated app" (Erin 2026-08-27; Ben 2026-08-27 on units and dataset pills).
- `~/My Drive/projects/calcofi/docs/CalCOFI - Ocean Metrics SoW, 2026-07 to 2027-06.md` § 4 Visualize
  (113 h; Task 14).
- `workflows/data/releases/v2026.08.25/catalog.json` + local parquet at `~/_big/calcofi/releases/v2026.08.25/`
  (counts above measured with DuckDB 1.5.5 + `h3`).
- `workflows/metadata/spatial_layers.csv`; `ingest_spatial.qmd`; `db-viz-hex/prep_db.R`; `db-query/lib/release.js`;
  `docs/maps.qmd`; `server/caddy/Caddyfile`; `server/varnish/default.vcl`.
