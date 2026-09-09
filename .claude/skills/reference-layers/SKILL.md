---
name: reference-layers
description: "The map's reference layers — the OpenStreetMap land mask and the GEBCO gazetteer's undersea feature names as PMTiles on gs://calcofi-files-public/_spatial/, built by ingest_spatial.qmd's Reference layers section (libs/reference_layers.R), registered with role = reference, and the Explorer's ocean-at-the-bottom style stack (plan 2026-09-09 D47–D54). Load before touching the land mask, the gazetteer labels, spatial_layers.csv's reference rows, or the Explorer's basemap composition."
---

# Reference layers (gs://calcofi-files-public/_spatial/, role = reference)

Built by the **Reference layers** section of `ingest_spatial.qmd` (`libs/reference_layers.R`): sources download
once under `cc_stage_path("reference")` (the 926 MB OSM zip is reused from `~/_big/calcofi/bathymetry/src/` when
present), the archives land in `data/pmtiles/` beside the boundary archives and upload with them, and
`data/parquet/spatial/reference_layers.json` records each archive's count, bbox, bytes, sha256 and source version
(the manifest merges a skipped layer's previous record). `build_spatial_layers(reference_json =)` (calcofi4db ≥ 4.8.0)
reads it at release; a reference row is not in `spatial`, has no memberships and no names, and never warns.
Decisions and measurements: plan `.claude/plans/2026-09-09 Explorer reference layers …`.

- **The Explorer's coast is a mask, not a basemap trick.** CARTO paints land as `background` and the sea as the
  `water` fill, with landcover / parks / landuse / waterway / county + state lines UNDER that fill. `composeStyle()`
  (explore `src/basemap.ts`) moves `water` to right after `background`, draws the sea floor, the boundaries under
  the Data row and the data (deck, `beforeId = "land"`) over it, then `osm_land.pmtiles` in the theme's
  `background-color`, then a copy of `water` filtered to `class != ocean` (lakes sit inside the land polygons), and
  leaves every CARTO land layer where it was — above the mask. `park_*` sink under `water` (`SINK_UNDER_WATER`):
  marine reserves ride that layer and would tint the sea. `land=off` is the old stack.
- **The mask is OSM's coastline** (`land-polygons-split-4326`, the source CARTO's water derives from) cropped to the
  sea-floor tiles' core box (−140, 15, −105, 56) — outside it the background is land already. Natural Earth 10 m is
  hundreds of metres off at z9+; the Contours surface's own `landMask()` (NE, per cell) stays as a value mask only.
- **The Data row is the sea surface (D53):** with Land on, the mask sits directly above the data wherever the row is
  dragged; boundaries above the row draw on the surface (land parts included), boundaries below it are clipped to
  the ocean. `dataBeforeId` is `"land"` whenever `sel.land`.
- **Labels are data, the style gates the zoom.** `gebco_gazetteer.pmtiles` carries every feature at every zoom
  (`-r1`), with `label` = NAME + TYPE, `rank` 1/2/3 by generic term (`GAZ_RANK1` / `GAZ_RANK3`, else 2) and
  `min_zoom` 4/6/8; the Explorer draws three point symbol layers by rank (rank 1 letter-spaced capitals) plus one
  line-placed layer. Registry `geom_type = label`; `raster` rows (Esri's ocean reference, D51) are registry-only with
  a `source_url` template and no archive.
- **Verification** is `explore/scripts/verify.mjs --only=^ref_` (stack order via `map.style._order`, which carries
  deck's interleaved layers; `getStyle()` drops them), plus the Layers-card checkbox counts.
- Not release content beyond the sidecar rows; the archives are rebuilt outside releases like the boundary set.
