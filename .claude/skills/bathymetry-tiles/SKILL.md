---
name: bathymetry-tiles
description: "Building and publishing the GEBCO 2025 bathymetry artefacts on gs://calcofi-db/bathymetry/ with scripts/build_bathymetry_tiles.py — terrain and contour PMTiles, the two-archive decision, the 1 m encoding, the crop COG extent, verify and upload. Load before touching bathymetry tiles, the GEBCO crop or a map's terrain/contour layers."
---

# Bathymetry artefacts (gs://calcofi-db/bathymetry/)

Built by **`scripts/build_bathymetry_tiles.py`** (Homebrew python3 + `osgeo`, tippecanoe, the `pmtiles`
CLI) from the local GEBCO 2025 sub-ice tile
`~/_big/gebco_2025_sub_ice_topo_geotiff/gebco_2025_sub_ice_n90.0_s0.0_w-180.0_e-90.0.tif` (download:
gebco.net → sub-ice topo, the n90/w-180/e-90 GeoTIFF). Bulk outputs stage at `~/_big/calcofi/bathymetry/`;
`--steps prep,terrain,contours,crop` builds, `--steps ship,json` assembles the published set, `--steps verify`
re-derives a random sample of shipped tiles from the source and dies unless byte-identical, `--upload`
copies the ship set and then you run `Rscript scripts/build_storage_index.R`. `gebco_2025.json` on the
bucket describes every artefact (bbox / zooms / encoding / bytes / sha256) — consumers read it, nothing
hard-codes what the build decided. Decisions measured in the 2026-08-31 spike (plan `.claude/plans/2026-08-31
Explorer map layers …`, § Measured):

- **Two terrain archives, not one sparse** — MapLibre never fetches a parent tile as a fallback, so a
  sparse archive's missing z6–8 children leave the far field blank and the map never idle. Core
  (lon −140→−105 × lat 15→56, z0–8) + far (the whole tile, z0–5), 512-px tiles, **custom 1 m encoding**
  (`redFactor 65536 · greenFactor 256 · blueFactor 1 · baseShift 10000`; half the bytes of mapbox 0.1 m).
- **Land is clamped to exactly 0 before resampling; never resample an encoded tile** (an averaged
  terrain-RGB byte is not an averaged elevation). A `color-relief` ramp must go transparent at exactly 0.
- **tippecanoe's `-j` filter drops integer-typed attributes silently** — the contour `ele`/`level`
  attributes are written as doubles on purpose.
- **`gebco_2025_calcofi.tif` (the crop `calcofi4r::cc_bathy()` serves) covers every released
  observation** (lon −165→−100 × lat 15→56, Int16 depth COG; D29). If a future dataset falls outside it,
  re-cut the crop here — one extent for every consumer — rather than teaching one app a special raster.
  The full tile also ships as a COG (`gebco_2025_sub_ice_n90_w180_e90_cog.tif`, raw **elevation**):
  `release_database.qmd`'s `depth_coverage` falls back to it over `/vsicurl/` when `CALCOFI_GEBCO_TIF`
  names no local file, so a release runs on any machine.
- Not release content: no `catalog.json` entry, no `RELEASES.md` section for the tiles themselves.

> Moved out of the root `CLAUDE.md` on 2026-09-03 so it loads on demand; the hard rules stay resident there. Edit this file, not both.
