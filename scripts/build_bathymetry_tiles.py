#!/opt/homebrew/bin/python3
"""build_bathymetry_tiles.py — GEBCO 2025 → terrain-RGB PMTiles (+ contour PMTiles, + the consumers' crop COG)

Plan: `.claude/plans/2026-08-31 Explorer map layers …` (D21 · D29, Appendix C). Needs Homebrew python3 with the
`osgeo` bindings (GDAL 3.11), numpy, tippecanoe and the `pmtiles` CLI. Bulk outputs go OUTSIDE the repo
(`~/_big/calcofi/bathymetry/`, like `cc_stage_dir()` for parquet); nothing here touches the bucket unless `--upload`.

  python3 scripts/build_bathymetry_tiles.py                       # every step, mapbox + custom encodings, no land mask
  python3 scripts/build_bathymetry_tiles.py --steps terrain --land-mask src/land-polygons-split-4326.zip --variant mask
  python3 scripts/build_bathymetry_tiles.py --steps contours,crop,json
  python3 scripts/build_bathymetry_tiles.py --steps ship,json       # assemble the SHIPPED set (custom-1 m core+far under the final names)
  python3 scripts/build_bathymetry_tiles.py --steps verify          # re-derive a sample of shipped tiles from the source: byte-identical or die
  python3 scripts/build_bathymetry_tiles.py --steps json --upload   # gcloud storage cp of the ship set → gs://calcofi-db/bathymetry/

Tiling rule (Appendix C): the elevation is warped to each zoom's EXACT 512-px WebMercator tile grid (`average`
below GEBCO's native ~463 m cell, `bilinear` at/above it) and only then encoded to terrain-RGB — never resample an
encoded tile, an averaged terrain-RGB byte is not an averaged elevation. Land is clamped to 0 before any
resampling (so a coastal cell averages sea with a 0 plane, not with a +300 m hill); cells with no source data
encode as +1 m (transparent in `color-relief`, flat for `hillshade`).
"""
import argparse, datetime as dt, hashlib, json, math, os, random, shutil, sqlite3, subprocess, sys, time
import numpy as np
from osgeo import gdal, ogr

gdal.UseExceptions()
gdal.SetConfigOption("GDAL_NUM_THREADS", "ALL_CPUS")
gdal.SetCacheMax(2048 * 1024 * 1024)

HOME = os.path.expanduser("~")
SOURCE_DEFAULT = f"{HOME}/_big/gebco_2025_sub_ice_topo_geotiff/gebco_2025_sub_ice_n90.0_s0.0_w-180.0_e-90.0.tif"
OUT_DEFAULT = f"{HOME}/_big/calcofi/bathymetry"
GCS_PREFIX = "gs://calcofi-db/bathymetry/"
CORE_BBOX = (-140.0, 15.0, -105.0, 56.0)   # w, s, e, n — Baja to Haida Gwaii: the home view with room to pan, every CalCOFI/CUFES survey
FAR_BBOX = (-180.0, 0.0, -90.0, 60.0)      # the far tier: the whole source tile (its tiles reach 61.6–66.5 N at z5–2)
CROP_BBOX = (-165.0, 15.0, -100.0, 56.0)   # D29: the consumers' crop — every bottle/PIC/CUFES/dungeness/DIC/euphausiid position
FAR_ZMAX, CORE_ZMAX = 5, 8
TILE = 512
LEVELS = [50, 100, 200, 300, 400, 500, 750, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500]
FAR_LEVEL_MIN = 500                        # the far tier's contours: level 2–3 only (500-multiples from z5, 1000-multiples from z0)
O = 20037508.342789244                     # WebMercator half-extent (m)
NATIVE_M = (15.0 / 3600.0) * O / 180.0     # a GEBCO 15" cell in mercator x units ≈ 463.3 m
CHECK_POINTS = [(-150.0, 30.0), (-128.0, 54.0), (-119.7, 33.9)]  # NORPAC-era bottle · CUFES north · Santa Cruz Basin
CITATION = "GEBCO Compilation Group (2025) GEBCO 2025 Grid (doi:10.5285/37c52e96-24ea-67ce-e063-7086abc05f29)"
LICENCE = "GEBCO grids are placed in the public domain and may be used free of charge (GEBCO terms of use)."

def log(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)

def run(cmd, **kw):
    log("$", " ".join(cmd))
    return subprocess.run(cmd, check=True, text=True, capture_output=True, **kw)

def sha256(path, chunk=1 << 24):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while b := f.read(chunk):
            h.update(b)
    return h.hexdigest()

def mb(path):
    return os.path.getsize(path) / 1e6

# ── the tile grid ─────────────────────────────────────────────────────────────
def merc_x(lon):
    return lon * O / 180.0

def merc_y(lat):
    return math.log(math.tan(math.pi / 4.0 + math.radians(lat) / 2.0)) * O / math.pi

def tile_range(bbox, z):
    """xyz tile range (x0, y0, x1, y1) covering bbox at zoom z (y from the top)."""
    w, s, e, n = bbox
    span = 2.0 * O / 2 ** z
    eps = 1e-9 * span
    x0 = math.floor((merc_x(w) + O) / span); x1 = math.floor((merc_x(e) - eps + O) / span)
    y0 = math.floor((O - merc_y(n)) / span); y1 = math.floor((O - merc_y(s) - eps) / span)
    m = 2 ** z - 1
    return (max(0, x0), max(0, y0), min(m, x1), min(m, y1))

def tiers(sparse=True):
    """(tier, bbox, zooms) — far z0–5 over the whole tile, core z6–8 over the core box."""
    return [("far", FAR_BBOX, range(0, FAR_ZMAX + 1)), ("core", CORE_BBOX, range(FAR_ZMAX + 1, CORE_ZMAX + 1))]

def expected_tiles():
    return sum((x1 - x0 + 1) * (y1 - y0 + 1) for _, bbox, zs in tiers() for z in zs for (x0, y0, x1, y1) in [tile_range(bbox, z)])

# ── step: prep (clamp ≤ 0 · optional OSM land mask · depth raster) ─────────────
def prep(src, work, land_mask=None, force=False):
    clamped = f"{work}/dem_clamped.tif"
    depth = f"{work}/depth_full.tif"
    if force or not os.path.exists(clamped) or not os.path.exists(depth):
        log("prep: clamp elevation ≤ 0 and derive depth = max(-elev, 0) over the whole source tile")
        s = gdal.Open(src)
        nx, ny = s.RasterXSize, s.RasterYSize
        drv = gdal.GetDriverByName("GTiff")
        co = ["TILED=YES", "BLOCKXSIZE=512", "BLOCKYSIZE=512", "COMPRESS=DEFLATE", "PREDICTOR=2", "ZLEVEL=1", "BIGTIFF=IF_SAFER"]
        c = drv.Create(clamped, nx, ny, 1, gdal.GDT_Int16, options=co); c.SetGeoTransform(s.GetGeoTransform()); c.SetProjection(s.GetProjection())
        d = drv.Create(depth, nx, ny, 1, gdal.GDT_Int16, options=co); d.SetGeoTransform(s.GetGeoTransform()); d.SetProjection(s.GetProjection())
        d.GetRasterBand(1).SetDescription("depth_m"); d.GetRasterBand(1).SetNoDataValue(-32768)
        step = 1024
        for y in range(0, ny, step):
            h = min(step, ny - y)
            a = s.GetRasterBand(1).ReadAsArray(0, y, nx, h)
            c.GetRasterBand(1).WriteArray(np.minimum(a, 0), 0, y)
            d.GetRasterBand(1).WriteArray(np.maximum(-a, 0), 0, y)
        c = d = None
        log(f"prep: {clamped} {mb(clamped):.0f} MB · {depth} {mb(depth):.0f} MB")
    out = clamped
    if land_mask:
        masked = f"{work}/dem_clamped_mask.tif"
        if force or not os.path.exists(masked):
            log(f"prep: burn OSM land polygons as +1 m into {masked}")
            shutil.copyfile(clamped, masked)
            vec = land_mask if not land_mask.endswith(".zip") else f"/vsizip/{land_mask}/land-polygons-split-4326/land_polygons.shp"
            ds = gdal.Open(masked, gdal.GA_Update)
            gdal.Rasterize(ds, vec, burnValues=[1], layers=["land_polygons"])
            ds = None
            log("prep: mask burned")
        out = masked
    return out, depth

# ── step: terrain tiles ───────────────────────────────────────────────────────
def warp_zoom(dem, z, bbox, out_tif, force=False):
    x0, y0, x1, y1 = tile_range(bbox, z)
    span = 2.0 * O / 2 ** z
    res = span / TILE
    alg = "average" if res > NATIVE_M else "bilinear"
    w, h = (x1 - x0 + 1) * TILE, (y1 - y0 + 1) * TILE
    if force or not os.path.exists(out_tif):
        log(f"warp z{z}: tiles x{x0}-{x1} y{y0}-{y1} → {w}×{h} px @ {res:.1f} m ({alg})")
        gdal.Warp(out_tif, dem, dstSRS="EPSG:3857", outputBounds=(x0 * span - O, O - (y1 + 1) * span, (x1 + 1) * span - O, O - y0 * span),
                  width=w, height=h, resampleAlg=alg, outputType=gdal.GDT_Float32, dstNodata=float("nan"),
                  multithread=True, warpOptions=["NUM_THREADS=ALL_CPUS"], warpMemoryLimit=1024 * 1024 * 1024,
                  creationOptions=["TILED=YES", "BLOCKXSIZE=512", "BLOCKYSIZE=512", "COMPRESS=LZW", "BIGTIFF=IF_SAFER"])
    return (x0, y0, x1, y1), alg, res

ENCODINGS = {
    # MapLibre `raster-dem` source options. mapbox: elevation = -10000 + (R·256² + G·256 + B)·0.1
    "mapbox": {"encoding": "mapbox", "step_m": 0.1},
    # custom, 1 m: elevation = R·65536 + G·256 + B − 10000 → R is always 0 for a sea floor, G/B carry 0…10000
    "custom": {"encoding": "custom", "redFactor": 65536, "greenFactor": 256, "blueFactor": 1, "baseShift": 10000, "step_m": 1.0},
}

def encode(e, enc):
    e = np.where(np.isnan(e), 1.0, e)  # no source data → +1 m: transparent in color-relief, flat for hillshade
    if enc == "mapbox":
        v = np.rint((e + 10000.0) * 10.0).astype(np.int64).clip(0, 2 ** 24 - 1)
        return np.stack([(v >> 16) & 255, (v >> 8) & 255, v & 255]).astype(np.uint8)
    v = np.rint(e + 10000.0).astype(np.int64).clip(0, 65535)
    return np.stack([np.zeros_like(v), (v >> 8) & 255, v & 255]).astype(np.uint8)

def decode(rgb, enc):
    r, g, b = (rgb[i].astype(np.float64) for i in range(3))
    return -10000.0 + (r * 65536 + g * 256 + b) * 0.1 if enc == "mapbox" else r * 65536 + g * 256 + b - 10000.0

PNG = gdal.GetDriverByName("PNG"); MEM = gdal.GetDriverByName("MEM")

def png_bytes(rgb):
    ds = MEM.Create("", TILE, TILE, 3, gdal.GDT_Byte); ds.WriteArray(rgb)
    p = "/vsimem/tile.png"; PNG.CreateCopy(p, ds, options=["ZLEVEL=9"]); ds = None
    b = bytes(gdal.VSIGetMemFileBuffer_unsafe(p)); gdal.Unlink(p)
    return b

def png_decode(b):
    p = "/vsimem/tile_in.png"; gdal.FileFromMemBuffer(p, b)
    a = gdal.Open(p).ReadAsArray(); gdal.Unlink(p)
    return a

def mbtiles_create(path, meta):
    if os.path.exists(path): os.remove(path)
    con = sqlite3.connect(path)
    con.executescript("CREATE TABLE metadata (name TEXT, value TEXT); CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB);"
                      "CREATE UNIQUE INDEX tile_index ON tiles (zoom_level, tile_column, tile_row);")
    con.executemany("INSERT INTO metadata VALUES (?, ?)", [(k, str(v)) for k, v in meta.items()])
    return con

def mbtiles_meta(name, bbox, zmin, zmax, enc, mask):
    w, s, e, n = bbox
    return {"name": name, "format": "png", "type": "baselayer", "version": "1", "bounds": f"{w},{s},{e},{n}",
            "center": f"{(w + e) / 2},{(s + n) / 2},{min(zmax, 5)}", "minzoom": zmin, "maxzoom": zmax, "attribution": CITATION,
            "description": f"GEBCO 2025 sub-ice sea floor as terrain-RGB ({enc} encoding, {TILE}px tiles, land clamped to 0{', OSM land mask +1 m' if mask else ''})"}

def pmtiles_convert(mbt, out):
    if os.path.exists(out): os.remove(out)
    run(["pmtiles", "convert", mbt, out])
    show = run(["pmtiles", "show", out]).stdout
    run(["pmtiles", "verify", out])
    n = next((int(l.split(":")[1].replace(",", "")) for l in show.splitlines() if l.startswith("addressed tiles count")), None)
    log(f"{os.path.basename(out)}: {mb(out):.1f} MB · {n} addressed tiles · verify ok")
    return {"bytes": os.path.getsize(out), "addressed_tiles": n, "show": show.strip()}

def terrain(dem, work, out, encodings, variant, force=False, report=None):
    """far z0–5 + core z6–8 into one sparse MBTiles per encoding, then the core (z0–8 over the core box) and far (z0–5) subsets."""
    grids = {}
    for tier, bbox, zs in tiers():
        for z in zs:
            tif = f"{work}/z{z}_{tier}{variant}.tif"
            rng, alg, res = warp_zoom(dem, z, bbox, tif, force)
            grids[z] = (tier, tif, rng, alg, res)
    stats = {enc: {"tiles": 0, "png_bytes": 0, "decode_check": []} for enc in encodings}
    cons = {}
    for enc in encodings:
        name = f"gebco_2025_calcofi_terrain{'' if enc == 'mapbox' else '_' + enc}{variant}"
        cons[enc] = (name, mbtiles_create(f"{work}/{name}.mbtiles", mbtiles_meta(name, FAR_BBOX, 0, CORE_ZMAX, enc, variant != "")))
    rnd = random.Random(2025)
    src = gdal.Open(dem); gt = src.GetGeoTransform()
    for z, (tier, tif, (x0, y0, x1, y1), alg, res) in grids.items():
        ds = gdal.Open(tif); band = ds.GetRasterBand(1)
        t0 = time.time(); n = 0
        for j, y in enumerate(range(y0, y1 + 1)):
            for i, x in enumerate(range(x0, x1 + 1)):
                e = band.ReadAsArray(i * TILE, j * TILE, TILE, TILE)
                check = rnd.random() < (5.0 / max(1, (x1 - x0 + 1) * (y1 - y0 + 1))) if z == CORE_ZMAX else False
                for enc in encodings:
                    rgb = encode(e, enc); b = png_bytes(rgb)
                    name, con = cons[enc]
                    con.execute("INSERT INTO tiles VALUES (?, ?, ?, ?)", (z, x, 2 ** z - 1 - y, sqlite3.Binary(b)))
                    stats[enc]["tiles"] += 1; stats[enc]["png_bytes"] += len(b)
                    if check:  # round-trip the PNG and compare the tile's centre to the source's nearest cell
                        d = decode(png_decode(b), enc); ok = ~np.isnan(e)
                        err = float(np.max(np.abs(d[ok] - e[ok]))) if ok.any() else 0.0
                        span = 2.0 * O / 2 ** z; cx = (x + 0.5) * span - O; cy = O - (y + 0.5) * span
                        lon = cx * 180.0 / O; lat = math.degrees(2 * math.atan(math.exp(cy * math.pi / O)) - math.pi / 2)
                        px = int((lon - gt[0]) / gt[1]); py = int((lat - gt[3]) / gt[5])
                        sv = float(src.GetRasterBand(1).ReadAsArray(px, py, 1, 1)[0, 0])
                        stats[enc]["decode_check"].append({"z": z, "x": x, "y": y, "max_roundtrip_err_m": round(err, 3), "centre_lonlat": [round(lon, 4), round(lat, 4)],
                                                           "tile_centre_m": round(float(d[TILE // 2, TILE // 2]), 1), "source_nearest_m": sv})
                n += 1
        for enc in encodings: cons[enc][1].commit()
        log(f"z{z} {tier}: {n} tiles × {len(encodings)} encodings in {time.time() - t0:.0f}s ({alg} @ {res:.0f} m/px)")
    result = {}
    for enc, (name, con) in cons.items():
        con.close()
        sparse = f"{work}/{name}.mbtiles"
        # the core archive: z0–8 over the core box (the far tier's z0–5 tiles that intersect it + all of z6–8); the far archive: z0–5
        core = f"{work}/{name}_core.mbtiles"; far = f"{work}/{name}_far.mbtiles"
        cc = mbtiles_create(core, mbtiles_meta(name + "_core", CORE_BBOX, 0, CORE_ZMAX, enc, variant != "")); cc.execute("ATTACH ? AS s", (sparse,))
        for z in range(0, CORE_ZMAX + 1):
            x0, y0, x1, y1 = tile_range(CORE_BBOX, z)
            cc.execute("INSERT INTO tiles SELECT * FROM s.tiles WHERE zoom_level=? AND tile_column BETWEEN ? AND ? AND tile_row BETWEEN ? AND ?", (z, x0, x1, 2 ** z - 1 - y1, 2 ** z - 1 - y0))
        cc.commit(); cc.close()
        fc = mbtiles_create(far, mbtiles_meta(name + "_far", FAR_BBOX, 0, FAR_ZMAX, enc, variant != "")); fc.execute("ATTACH ? AS s", (sparse,))
        fc.execute("INSERT INTO tiles SELECT * FROM s.tiles WHERE zoom_level <= ?", (FAR_ZMAX,)); fc.commit(); fc.close()
        result[enc] = {"encoding": ENCODINGS[enc], "tiles": stats[enc]["tiles"], "png_bytes_total": stats[enc]["png_bytes"], "decode_check": stats[enc]["decode_check"],
                       "sparse": pmtiles_convert(sparse, f"{out}/{name}.pmtiles"), "core": pmtiles_convert(core, f"{out}/{name}_core.pmtiles"), "far": pmtiles_convert(far, f"{out}/{name}_far.pmtiles")}
        exp = expected_tiles()
        assert stats[enc]["tiles"] == exp, f"{enc}: {stats[enc]['tiles']} tiles written, {exp} expected"
        assert result[enc]["sparse"]["addressed_tiles"] == exp, f"{enc}: pmtiles addressed {result[enc]['sparse']['addressed_tiles']} ≠ {exp}"
        for c in stats[enc]["decode_check"]:
            assert c["max_roundtrip_err_m"] <= ENCODINGS[enc]["step_m"] / 2 + 0.01, f"{enc}: round-trip error {c}"  # + float32 representation of the warped grid
    result["_grid"] = {z: {"tier": tier, "tiles": [x0, y0, x1, y1], "resampling": alg, "m_per_px": round(res, 2)} for z, (tier, _, (x0, y0, x1, y1), alg, res) in grids.items()}
    return result

# ── step: contours ────────────────────────────────────────────────────────────
def level_of(ele):
    return 3 if ele % 1000 == 0 else 2 if ele % 500 == 0 else 1 if ele >= 100 else 0

def contour_tier(depth, work, tag, bbox, levels, nodata_box=None, min_len_deg=0.0, upsample=False, force=False):
    """gdal_contour on the depth raster (positive down, so the levels are positive) → FlatGeobuf with ele + level."""
    fgb = f"{work}/contours_{tag}.fgb"
    if not force and os.path.exists(fgb): return fgb
    w, s, e, n = bbox
    win = f"{work}/depth_{tag}.tif"
    gdal.Translate(win, depth, projWin=[w, n, e, s], creationOptions=["TILED=YES", "COMPRESS=LZW"])
    if nodata_box:  # blank the core so the far tier's lines stop where the core's full-resolution lines start
        ds = gdal.Open(win, gdal.GA_Update); gt = ds.GetGeoTransform()
        bw, bs, be, bn = nodata_box
        px0, py0 = int(round((bw - gt[0]) / gt[1])), int(round((bn - gt[3]) / gt[5])); px1, py1 = int(round((be - gt[0]) / gt[1])), int(round((bs - gt[3]) / gt[5]))
        ds.GetRasterBand(1).WriteArray(np.full((py1 - py0, px1 - px0), -32768, np.int16), px0, py0); ds = None
    if upsample:
        up = f"{work}/depth_{tag}_2x.tif"; ds = gdal.Open(win)
        gdal.Warp(up, win, width=ds.RasterXSize * 2, height=ds.RasterYSize * 2, resampleAlg="cubicspline", creationOptions=["TILED=YES", "COMPRESS=LZW"]); win = up
    gpkg = f"{work}/contours_{tag}.gpkg"
    if os.path.exists(gpkg): os.remove(gpkg)
    t0 = time.time()
    run(["gdal_contour", "-f", "GPKG", "-a", "ele", "-nln", "contour", "-fl", *[str(l) for l in levels], "-snodata", "-32768", win, gpkg])
    log(f"contours {tag}: gdal_contour in {time.time() - t0:.0f}s")
    src = ogr.Open(gpkg); lyr = src.GetLayer(0)
    drv = ogr.GetDriverByName("FlatGeobuf")
    if os.path.exists(fgb): drv.DeleteDataSource(fgb)
    dst = drv.CreateDataSource(fgb); ol = dst.CreateLayer("contours", lyr.GetSpatialRef(), ogr.wkbLineString)
    # doubles on purpose: tippecanoe's -j filter refuses to compare an integer-typed attribute ("mismatched type in comparison") and drops every feature
    for fld, typ in (("ele", ogr.OFTReal), ("level", ogr.OFTReal)): ol.CreateField(ogr.FieldDefn(fld, typ))
    n = kept = 0
    for f in lyr:
        n += 1
        g = f.GetGeometryRef()
        if min_len_deg and g.Length() < min_len_deg: continue
        ele = int(round(f.GetField("ele")))
        o = ogr.Feature(ol.GetLayerDefn()); o.SetGeometry(g.Clone()); o.SetField("ele", float(ele)); o.SetField("level", float(level_of(ele))); ol.CreateFeature(o); kept += 1
    dst = src = None
    log(f"contours {tag}: {n} lines, {kept} kept → {fgb} {mb(fgb):.1f} MB")
    return fgb

def contours(depth, work, out, force=False, upsample=False):
    core = contour_tier(depth, work, "core", CORE_BBOX, LEVELS, upsample=upsample, force=force)
    far = contour_tier(depth, work, "far", (FAR_BBOX[0], FAR_BBOX[1], FAR_BBOX[2], 67.0), [l for l in LEVELS if l >= FAR_LEVEL_MIN], nodata_box=CORE_BBOX, min_len_deg=0.05, force=force)
    pm = f"{out}/gebco_2025_calcofi_contours.pmtiles"
    # per-zoom gate on `level` (0 = 50 m, 1 = 100–750, 2 = 500-multiples, 3 = 1000-multiples): 1000s from z0, 500s from z5, 100s from z7, 50s from z9
    flt = json.dumps({"*": ["any", ["==", "level", 3], ["all", [">=", "$zoom", 5], ["==", "level", 2]], ["all", [">=", "$zoom", 7], ["==", "level", 1]], ["all", [">=", "$zoom", 9], ["==", "level", 0]]]})
    t0 = time.time()
    run(["tippecanoe", "-o", pm, "--force", "-z10", "-Z0", "-l", "contours", "-n", "GEBCO 2025 isobaths", "-A", CITATION,
         "--simplify-only-low-zooms", "--drop-smallest-as-needed", "--no-tiny-polygon-reduction", "-j", flt, core, far])
    show = run(["pmtiles", "show", pm]).stdout; run(["pmtiles", "verify", pm])
    log(f"contours: tippecanoe in {time.time() - t0:.0f}s → {os.path.basename(pm)} {mb(pm):.1f} MB")
    return {"path": pm, "bytes": os.path.getsize(pm), "levels_m": LEVELS, "far_levels_min_m": FAR_LEVEL_MIN, "level_attribute": {"0": "50 m", "1": "100–750 m", "2": "500-multiples", "3": "1000-multiples"},
            "minzoom_by_level": {"3": 0, "2": 5, "1": 7, "0": 9}, "zooms": [0, 10], "upsampled_2x": upsample, "show": show.strip()}

# ── step: the consumers' crop (D29) ───────────────────────────────────────────
def read_at(path, lon, lat):
    ds = gdal.Open(path); gt = ds.GetGeoTransform()
    px, py = int((lon - gt[0]) / gt[1]), int((lat - gt[3]) / gt[5])
    if not (0 <= px < ds.RasterXSize and 0 <= py < ds.RasterYSize): return None
    return float(ds.GetRasterBand(1).ReadAsArray(px, py, 1, 1)[0, 0])

def crop(depth, src, work, out, force=False):
    w, s, e, n = CROP_BBOX
    win = f"{work}/depth_crop.tif"
    gdal.Translate(win, depth, projWin=[w, n, e, s], creationOptions=["TILED=YES", "COMPRESS=LZW"])
    cog = f"{out}/gebco_2025_calcofi.tif"
    t0 = time.time()
    gdal.Translate(cog, win, format="COG", creationOptions=["COMPRESS=DEFLATE", "PREDICTOR=2", "LEVEL=9", "BLOCKSIZE=512", "OVERVIEWS=AUTO", "RESAMPLING=AVERAGE", "NUM_THREADS=ALL_CPUS"])
    info = gdal.Info(cog, format="json")
    is_cog = info.get("metadata", {}).get("IMAGE_STRUCTURE", {}).get("LAYOUT") == "COG"
    checks = []
    for lon, lat in CHECK_POINTS:
        d = read_at(cog, lon, lat); sv = read_at(src, lon, lat); sd = max(-sv, 0.0) if sv is not None else None
        checks.append({"lon": lon, "lat": lat, "crop_depth_m": d, "source_depth_m": sd, "match": d is not None and sd is not None and abs(d - sd) < 1.0})
    log(f"crop: {os.path.basename(cog)} {mb(cog):.1f} MB in {time.time() - t0:.0f}s · COG={is_cog} · {info['size']} px · checks {[c['match'] for c in checks]}")
    assert is_cog and all(c["match"] for c in checks)
    return {"path": cog, "bytes": os.path.getsize(cog), "bbox": list(CROP_BBOX), "size_px": info["size"], "dtype": "Int16", "nodata": -32768, "units": "m, positive down, land 0",
            "layout": "COG (DEFLATE, predictor 2, 512-px blocks, average overviews)", "checks": checks}

# ── step: the ship set (the exact objects slice 1 publishes; plan 2026-08-31, spike decisions) ──
# custom 1 m encoding (160 vs 293 MB; metre precision is all a sea-floor background needs) and TWO
# archives — the spike measured that MapLibre never fetches a parent as a fallback, so a sparse
# single archive leaves the far field blank and the map never idle. The full source tile rides along
# as a plain COG (ELEVATION, unlike the crop) for /vsicurl/ streaming: the release's fallback and
# `cc_bathy(extent = "full", remote = TRUE)`.
SHIP = [
    ("gebco_2025_calcofi_terrain.pmtiles",        "terrain-RGB DEM, core z0-8 @512px, custom 1 m encoding"),
    ("gebco_2025_calcofi_terrain_far.pmtiles",    "terrain-RGB DEM, far tier z0-5 @512px, custom 1 m encoding"),
    ("gebco_2025_calcofi_contours.pmtiles",       "isobath lines z0-10 (ele, level; doubles)"),
    ("gebco_2025_calcofi.tif",                    "the consumers' crop: Int16 positive-down depth, land 0, COG"),
    ("gebco_2025_sub_ice_n90_w180_e90_cog.tif",   "the whole source tile as a streamable COG (raw ELEVATION)"),
]

def ship(out, results, force=False):
    import shutil
    for dst, src in [("gebco_2025_calcofi_terrain.pmtiles", "gebco_2025_calcofi_terrain_custom_core.pmtiles"),
                     ("gebco_2025_calcofi_terrain_far.pmtiles", "gebco_2025_calcofi_terrain_custom_far.pmtiles")]:
        assert os.path.exists(f"{out}/{src}"), f"{src} missing — run --steps terrain first"
        shutil.copyfile(f"{out}/{src}", f"{out}/{dst}")
        run(["pmtiles", "verify", f"{out}/{dst}"])
        log(f"ship: {dst} ← {src} ({mb(f'{out}/{dst}'):.1f} MB)")
    objs = []
    for name, kind in SHIP:
        p = f"{out}/{name}"; assert os.path.exists(p), f"{name} missing"
        objs.append({"name": name, "kind": kind, "bytes": os.path.getsize(p), "sha256": sha256(p)})
        log(f"ship: {name} · {objs[-1]['bytes']/1e6:.1f} MB · sha256 {objs[-1]['sha256'][:12]}…")
    t = results.get("terrain", {}).get("custom", {})
    return {"layout": "two archives (a sparse one leaves MapLibre waiting forever on missing children)",
            "raster_dem_source": {"encoding": "custom", "redFactor": 65536, "greenFactor": 256, "blueFactor": 1,
                                  "baseShift": 10000, "tileSize": 512},
            "core": {"file": "gebco_2025_calcofi_terrain.pmtiles", "bbox": list(CORE_BBOX), "zooms": [0, CORE_ZMAX],
                     "tiles": t.get("core", {}).get("addressed_tiles")},
            "far": {"file": "gebco_2025_calcofi_terrain_far.pmtiles", "bbox": list(FAR_BBOX), "zooms": [0, FAR_ZMAX],
                    "tiles": t.get("far", {}).get("addressed_tiles")},
            "objects": objs}

def verify_ship(out, dem, n_per_archive=6):
    """re-derive a random sample of shipped tiles straight from the prepared DEM: byte-identical or die."""
    rnd = random.Random(7)
    for name, bbox, zmax in [("gebco_2025_calcofi_terrain.pmtiles", CORE_BBOX, CORE_ZMAX),
                             ("gebco_2025_calcofi_terrain_far.pmtiles", FAR_BBOX, FAR_ZMAX)]:
        arch = f"{out}/{name}"
        show = run(["pmtiles", "show", arch]).stdout
        addressed = next(int(l.split(":")[1].replace(",", "")) for l in show.splitlines() if l.startswith("addressed tiles count"))
        expected = sum((x1 - x0 + 1) * (y1 - y0 + 1) for z in range(0, zmax + 1) for (x0, y0, x1, y1) in [tile_range(bbox, z)])
        assert addressed == expected, f"{name}: {addressed} tiles addressed, {expected} expected"
        picks = []
        for _ in range(n_per_archive):
            z = rnd.choice([zmax, zmax, max(0, zmax - 1), 3])
            x0, y0, x1, y1 = tile_range(bbox, z)
            picks.append((z, rnd.randint(x0, x1), rnd.randint(y0, y1)))
        for z, x, y in picks:
            got = subprocess.run(["pmtiles", "tile", arch, str(z), str(x), str(y)],
                                 check=True, capture_output=True).stdout
            span = 2.0 * O / 2 ** z
            res = span / TILE
            alg = "average" if res > NATIVE_M else "bilinear"
            w = gdal.Warp("", dem, format="MEM", dstSRS="EPSG:3857",
                          outputBounds=(x * span - O, O - (y + 1) * span, (x + 1) * span - O, O - y * span),
                          width=TILE, height=TILE, resampleAlg=alg, outputType=gdal.GDT_Float32,
                          dstNodata=float("nan"), multithread=True)
            want = png_bytes(encode(w.ReadAsArray(), "custom"))
            ok = hashlib.sha256(got).hexdigest() == hashlib.sha256(want).hexdigest()
            log(f"verify {name} z{z}/{x}/{y}: {'byte-identical' if ok else 'MISMATCH'} ({len(got)} B)")
            assert ok, f"{name} z{z}/{x}/{y}: shipped tile differs from a fresh derivation"
    log("verify: every sampled tile reproduces byte-for-byte from the source")

# ── step: the family description ─────────────────────────────────────────────
def write_json(out, src, results):
    p = f"{out}/gebco_2025.json"
    doc = {"built": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"), "source": {"file": os.path.basename(src), "sha256": results.get("source_sha256"), "bytes": os.path.getsize(src),
           "grid": "GEBCO 2025 sub-ice topo/bathy, 15 arc-second, Int16 m, lon -180→-90 × lat 0→90", "citation": CITATION, "licence": LICENCE, "url": "https://www.gebco.net/data-products/gridded-bathymetry-data"},
           "gdal": gdal.__version__, "tippecanoe": subprocess.run(["tippecanoe", "--version"], capture_output=True, text=True).stderr.strip() or subprocess.run(["tippecanoe", "--version"], capture_output=True, text=True).stdout.strip(),
           "gcs_prefix": GCS_PREFIX, "tile_size": TILE, "core_bbox": list(CORE_BBOX), "far_bbox": list(FAR_BBOX), "core_zooms": [0, CORE_ZMAX], "far_zooms": [0, FAR_ZMAX],
           "land": "clamped to 0 m before resampling; cells outside the source encode +1 m", **{k: v for k, v in results.items() if k != "source_sha256"}}
    with open(p, "w") as f: json.dump(doc, f, indent=1)
    log(f"wrote {p}")
    return p

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", default=SOURCE_DEFAULT); ap.add_argument("--out", default=OUT_DEFAULT)
    ap.add_argument("--steps", default="prep,terrain,contours,crop,json"); ap.add_argument("--encoding", default="both", choices=["mapbox", "custom", "both"])
    ap.add_argument("--land-mask", default=None, help="OSM land-polygons-split-4326 zip/shp: burn +1 m where OSM has land"); ap.add_argument("--variant", default="", help="suffix for the archive names (e.g. _mask)")
    ap.add_argument("--upsample-contours", action="store_true", help="2× cubicspline before contouring the core (smoother lines at z10+)")
    ap.add_argument("--force", action="store_true"); ap.add_argument("--upload", action="store_true", help="gcloud storage cp the outputs to " + GCS_PREFIX)
    a = ap.parse_args()
    steps = a.steps.split(","); out = a.out; work = f"{out}/work"; os.makedirs(work, exist_ok=True)
    variant = a.variant or ("_mask" if a.land_mask else "")
    rp = f"{out}/work/results.json"
    def save(key, value):  # re-read then merge, so concurrent steps (terrain ‖ contours+crop) never clobber each other's keys
        cur = json.load(open(rp)) if os.path.exists(rp) else {}
        cur[key] = value; results.update(cur); json.dump(cur, open(rp, "w"), indent=1)
    results = json.load(open(rp)) if os.path.exists(rp) else {}
    t0 = time.time()
    if "source_sha256" not in results: save("source_sha256", sha256(a.source)); log(f"source sha256 {results['source_sha256']}")
    dem, depth = prep(a.source, work, a.land_mask, a.force) if ({"prep", "terrain", "contours", "crop", "verify"} & set(steps)) else (None, None)
    if "terrain" in steps:
        encs = ["mapbox", "custom"] if a.encoding == "both" else [a.encoding]
        save("terrain" + variant, {"dem": os.path.basename(dem), "land_mask": bool(a.land_mask), **terrain(dem, work, out, encs, variant, a.force)})
    if "contours" in steps:
        save("contours", contours(depth, work, out, a.force, a.upsample_contours))
    if "crop" in steps:
        save("crop", crop(depth, a.source, work, out, a.force))
    if "ship" in steps:
        save("ship", ship(out, results, a.force))
    if "verify" in steps:
        verify_ship(out, dem if dem else prep(a.source, work)[0])
    if "json" in steps:
        write_json(out, a.source, json.load(open(rp)))
    if a.upload:
        cur = json.load(open(rp))
        assert "ship" in cur, "run --steps ship first: only the ship set is uploaded"
        files = [f"{out}/{o['name']}" for o in cur["ship"]["objects"]] + [f"{out}/gebco_2025.json"]
        run(["gcloud", "storage", "cp", *files, GCS_PREFIX])
        log("uploaded; now: Rscript scripts/build_storage_index.R")
    log(f"done in {(time.time() - t0) / 60:.1f} min")

if __name__ == "__main__":
    main()
