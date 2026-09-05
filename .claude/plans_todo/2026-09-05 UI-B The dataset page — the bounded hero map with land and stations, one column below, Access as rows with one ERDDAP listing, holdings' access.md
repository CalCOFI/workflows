# UI-B · The dataset page — the bounded hero map with land and stations, one column below, Access as rows with one ERDDAP listing, holdings' access

**Agent:** Opus 5 · high. **Wave 2**, `CalCOFI.github.io` worktree (branch `ui-page`), from main **after UI-C is
merged**, in parallel with UI-A (the integrator merges A first; rebase your `style.css` and `datasets.rb` hunks —
they overlap by section, not by line). **Needs:** UI-C; from UI-A after merge: `normalize_variables` and the
reference band (until then, keep a local copy of the normaliser and skip the band's map). **Plan:** `.claude/plans/2026-09-05 CalCOFI.io UI refresh — emphasis, density and the dataset page, now that the catalog is live.md` § D-4,
D-5, D-6, D-7, D-9 (the fallbacks and their markers), D-10, Decisions 5–11, 14, 15, 17–20; **the artifact is the
spec**: https://claude.ai/code/artifact/b06dcb2e-f899-4c00-831e-7383a5f4e87e (the page mock, round 3 — the bounded hero map, the one-column Overview, the Coverage band, the Access
rows and the ERDDAP matrix, the phone frame; "The map shows where the dataset is"; the holding-page mock).

## Goal

`/datasets/{key}/` opens on the dataset drawn where it was sampled, over a coast, beside a title block it can never
be taller than; nothing below the head is two columns; Access is full-width rows with the URL on its own
middle-elided line, ERDDAP listed once as a matrix, metadata records apart from data, portals by identifier; a
holding page says where the data live today. All generated from the record; every fallback marked for deletion.

## Read first

- `_plugins/datasets.rb`: `bbox_svg` (the projection to keep), `access_groups`, `erddap_current`, `PORTAL_NAMES`,
  `record_pages`, `cite_text`, `jsonld` (untouched), `read_grid`; `_layouts/dataset.html`; `style.css` § "a dataset
  page" and "the Access table"; `scripts/fetch_release.sh`; `README.md`.
- The record shapes (`_data/datasets.json`, staging v2026.09.05): `distributions[]` kinds `download | service | mirror
  | source | archive | page | notebook`, formats `parquet | netcdf | erddap | iso19115 | html`, portals
  `erddap-calcofi | erddap-noaa | edi | ncei | obis | ipt | caloos | datazoo | ucsd-library | zenodo | ncbi | calcofi.org |
  gcs | other`, status `current | superseded | retired | external | planned`, ERDDAP rows carry `id`, `grain`
  (`observations · sampling events · length/stage frequency · full resolution (pre-thinning)`), `info_url`;
  `objects[]` carry `table, scope (partition | table), shared, bytes, sha256, since, url`; `registrations[]` carry
  `portal (erddap | obis | edi | ncei | caloos | zenodo), status (published | planned | n/a), url?, note?, issues[]` and
  **no id or title** (UI-D adds them; you derive from the URL until then); holdings carry `distributions[]` of kind
  `source` and `status.{stage, module, priority_caloos, next_step, gh_issue}`; `tables[]` (the CTD casts: sample,
  obs, obs_ctd_full, measurement_type; `sio_pic-zooplankton`: sample only); `coverage.variables[]` strings today,
  objects next release; `coverage.bbox` (the ichthyoplankton's is 0–54° N × 180–77° W — bad upstream coordinates).
- `_data/grid.geojson` properties: `grid_key, station, line, shore, pattern (historical | extended | standard), zone,
  lon_ctr, lat_ctr` — 218 cells (standard 67, extended 37, historical 114).
- `coverage_stations.json` beside the record (476 KB; fetch it): `{version, stations: [{grid_key, datasets:
  [{dataset_key, n_obs, year_min, year_max, years: [[y, n]], months: [12]}]}]}` — the CTD casts sit at 97 cells
  (max 415,649 obs), the ichthyoplankton at 207, DIC at 37.
- db-query: query ids are `category--name` (`datasets--bottle`, `datasets--ichthyo`, `sql-shell--shell`); the shell's
  SQL is a `<textarea name="sql">`; `__TBL:obs__` resolves to the pinned release; `?sql=` is read only after UI-E.
- Apps' deep links (measured): Explorer `?datasets={key}`; Cruise Explorer `?datasets={key}`; the rest open the app
  (UI-E adds Station `?dataset=` and Hexagon's bookmark later).
- Measured on 2026-09-05 (plan § Context): CTD page main 418 vs side 1,346 px; Download 13 rows (9 ERDDAP); the
  Access table's `th` at 34 % is what put URLs and code in a right-hand column.

## Do

1. **Data in.** `scripts/fetch_release.sh` also fetches `coverage_stations.json` from the record's folder into `_data/`
   (git-ignored; `WARN` if absent → the map draws without stations).
2. **The coast.** `scripts/build_land.py` (one-off, committed, documented in README; the prototype is the appendix
   below): Natural Earth 1:50 m land (public domain; `https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_land.geojson`)
   clipped to 135–105° W × 19–49° N (Sutherland–Hodgman), simplified by Douglas–Peucker at 0.012° with the closed-ring
   split, written to `_data/land.geojson` (committed; ≈ 21 KB, 28 rings, 791 points) with a `source` property.
3. **The map** (`map_svg(record)` in the plugin, replacing `bbox_svg`): the frame = the standard + extended cells ∪ the
   cells this dataset sampled, padded 6 % (min 0.4°); land rings clipped to the frame at draw time; the projection as
   `bbox_svg` (equirectangular, cos of the mean latitude on longitude), width 360; `<rect class="water">` then
   `<path class="land">` then every cell in frame hollow (`.st`, r 1.3) and the sampled cells filled (`.st-on`,
   r = 1.6 + 4.4·√(n / max)) each with a `<title>{grid_key} · {n} obs</title>` (sampled only); the record's bbox clipped
   to the frame as `.bbox` (dashed) with the corner text "extent continues beyond the frame" when clipped; 5° ticks
   (`.tk`) as edge labels; `preserveAspectRatio="xMaxYMin meet"`, no background on the element, `role="img"` with a
   label naming the count. `map_svg(nil)` draws the grid alone for the reference band (UI-A renders the band; add the
   map there after merge).
4. **The layout** (`_layouts/dataset.html`) per D-4: head band = `.ds-hero` grid (1.35fr / 1fr, `align-items: stretch`):
   left, breadcrumb · icon + h1 (short name as h1 and the full name as `.cc-lede` when both exist; `.ds-title-long`
   at the h2 size when the only name exceeds 80 characters) · chips (key with its colour dot · provider · licence ·
   DOI · release · stage) · the 3 × 2 stat grid · the years sparkline + caption; right, `.ds-mapwrap` (grid rows
   `minmax(0,1fr) auto`, `min-height: 0`), the SVG `position: absolute; inset: 0; width/height: 100%` in the first row,
   the caption in the second; at ≤ 820 px one column and the map cell takes `aspect-ratio` from the SVG's viewBox
   (write it as a style attribute). Then `.cc-tabs` (sticky under the header; anchors `#overview #coverage #access
   #cite #provenance #related` with counts). Overview: one column at 72 ch (description, PIs / creators / contact /
   funding, keywords, open questions, head links). Coverage band: variables chips `name` + `units` + `title=uri`
   (normalised), collapsed past 16 in a `<details>` "all n ▸"; taxa (top 50: scientific · common · n obs) in two
   columns when the record has them; life stages; contributes-to. Access on the Sand band. Cite + Provenance keep
   two columns with `align-items: start`; Related as built. A holding: no map, title block alone.
5. **Access** (`access_groups` rewritten; one include `_includes/access_row.html` for the two-line row and
   `_includes/access_matrix.html`): six groups with a one-sentence lede each — **Explore** (one row per app from the
   reverse index; `dataset_url:` template on the product substituted with `{key}` → chip *this dataset*, else chip
   *the app* + reason; add the two templates to `products.yml`: explore `https://calcofi.io/explore/?datasets={key}`,
   db-viz-cruise `https://app.calcofi.io/cruise/?datasets={key}`), **Query** (saved query `#datasets--{name}` when
   db-query has one — a short list in the plugin: bottle, ichthyo — else
   `https://calcofi.io/db-query/?sql={urlencoded}#sql-shell--shell`; the SQL uses `__TBL:{t}__` where `t` is the first
   of the dataset's tables carrying `dataset_key` — `obs`, else `sample`), **Code** (R, Python, DuckDB anywhere on the
   first parquet object's URL), **Get the data** (Parquet rows: table · scope phrase · bytes · since · sha256; CF
   netCDF rows with the `cf_scope` in a `<details>`; **the one ERDDAP matrix** — id · grain · CSV · netCDF · JSON · page
   · info · graph (`tabledap/{id}.graph`) — with the grain glossary below it from `grain_description` when present,
   else the site map keyed by grain (`# until the record carries grain_description`), and the legacy ids muted with
   "replaced by" and the sunset date 2026-12-04; From the provider: the `source` rows with `portal_name`),
   **Metadata records** (ISO 19115-3 from the record; FGDC at
   `https://erddap.calcofi.io/erddap/metadata/fgdc/xml/{primary_id}_fgdc.xml`; `{key}.jsonld`, `{key}.json`,
   `/data.json`, the STAC row when `format == "stac"`), **Archives & portals** (registrations, then archive / mirror /
   EDI-source rows: portal (link, description in `title=` from `PORTAL_NAMES` + a site-side one-liner map, `# until the
   record carries portals[]`) · identifier · title · status chip with meaning in `title=`). Identifier =
   `row["id"]`, else `derive_id(url)`: EDI `packageid=` or `scope=&identifier=&revision=` → `scope.identifier.revision`;
   NCEI `id=`; OBIS `/dataset/{uuid}`; IPT `r=`; Zenodo `doi.org/{doi}`; CalOOS `#module-metadata/{uuid}`; CoastWatch
   `tabledap/{id}` — **unit-tested** (a `_test/derive_id.rb` or a Ruby `Minitest` file run in the build script) against:
   `edi.109.4`, `knb-lter-cce.78.3`, `knb-lter-cce.313`, `gov.noaa.nodc:0301029`, `0e223f55-c826-4513-ae9a-b04cbf2e189c`,
   `calcofi_ichthyo`, `10.5281/zenodo.22281994`, `1a1a7812-48f9-4325-8ad0-e51e67e366ba`, `erdCalCOFIlrvcnt`. The URL is
   split for display into head + tail (tail = the last path segment, or the query string when present); the full
   URL in `title=` and on the copy button.
6. **Rows and CSS** (`style.css`, tokens only): `.ds-arow` two-line rows spanning the container; `.ds-url` flex with
   `.h { flex: 0 1 auto; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap }` and
   `.t { flex: none }`; the matrix as a CSS grid `max-content max-content 1fr` folding to one column at ≤ 520 px; the
   old `.ds-table` rules go once nothing uses them; the hero and map rules; `.ds-title-long`.
7. **Copy** (`assets/copy.js` ≤ 20 lines): `.cc-copy[data-copy]` → `navigator.clipboard.writeText`, a 1.5 s "copied"
   state; progressive (no JS → the text is still selectable).
8. **Holding pages** (D-7): groups *Where it lives today* (the source rows as in 5) and *Status* (stage chip quiet,
   module, priority, next step, tracking issue); no map; the head note in `--muted`.
9. **Stage chips**: `published` → `.cc-chip-ok`; `ingested | validated | metadata` → `.cc-chip-na`; holdings'
   `external | archived` → `.cc-chip-quiet`; `planned` → `.cc-chip-warn`; meanings in `title=` from a site-side map
   with a `# Open question 3` marker (Ben supplies the sentences).
10. **`scripts/check_layout.py`** gains the page assertions (extend UI-A's script; if A is not merged yet, write yours
    to the same file and let the integrator merge): the hero's two columns within 120 px; no `.ds-cols`-style
    two-column region between the hero and Cite; no `.ds-url` taller than one line at 375 px; exactly one
    `tabledap/{id}.html` per ERDDAP id per page; a11y via Lighthouse on `calcofi_ctd-cast`, `swfsc_ichthyo`,
    `calcofi_prodo`, both themes.
11. JSON-LD, DCAT, sitemap, search: unchanged (`check_jsonld.py _site` green). README: the map asset and script, the
    Access model, the fallbacks list.

## Gates

- A fresh clone builds with `scripts/build.sh serve` (fetch → build); `jekyll build` under 1.5 s with the maps.
- `check_layout.py` green on the three pages at 1470 and 375, both themes; `check_brand.py --url` on a dataset page;
  `check_jsonld.py _site` green; Lighthouse accessibility 100 on the three pages, both themes.
- The identifier tests pass; the ichthyoplankton page's Access lists all 29 distributions and 6 registrations
  (regrouped, none lost) and its map says the extent continues beyond the frame; the CTD casts' map draws 97 filled
  stations; `calcofi_prodo` shows *Where it lives today* with `knb-lter-cce.78.3`.
- Every fallback in the plugin carries `# until the record carries …`; the list is in the hand-back.

## Do not

Touch the tile grid or `catalog_grid.html` (UI-A's) except through the merged normaliser; change `brand/v2/`
(UI-C's); add a map library, a framework or an external image; type a dataset fact (a grain's meaning and a portal's
one-liner are the two marked fallbacks — nothing else); change `products.yml` beyond the two templates; alter the
JSON-LD.

## Hand back

Branch + sha, the check outputs and Lighthouse scores, screenshots of the three pages at 1470 and 375 in both
themes, the derive_id test output, the fallback list, one *Measured* line for the plan (sizes: `land.geojson`, the
inline map per page).

## Appendix — the basemap prototype (Python, 2026-09-05; port the geometry to Ruby or keep the coast build in Python)

```python
"""prototype of CalCOFI.github.io/scripts/build_land.py — clip Natural Earth land to the CalCOFI
frame, simplify (Douglas-Peucker, pure python), write a small GeoJSON + an SVG basemap in the
plugin's projection (equirectangular, cos(mean lat) on longitude). No shapely needed."""
import json, math, sys
LON0, LON1, LAT0, LAT1 = -135.0, -105.0, 19.0, 49.0      # the frame: the station grid + margin
TOL = 0.012                                              # degrees; ~1 km — invisible at 360 px

def dp(pts, tol):
    if len(pts) < 3: return pts
    if pts[0] == pts[-1]:                       # a closed ring: split at the farthest point first
        k = max(range(1,len(pts)-1), key=lambda i: (pts[i][0]-pts[0][0])**2+(pts[i][1]-pts[0][1])**2)
        return dp(pts[:k+1], tol)[:-1] + dp(pts[k:], tol)
    (x0,y0),(x1,y1) = pts[0], pts[-1]
    dx,dy = x1-x0, y1-y0; L = math.hypot(dx,dy) or 1e-12
    imax,dmax = 0,0.0
    for i in range(1,len(pts)-1):
        x,y = pts[i]; d = abs(dy*x-dx*y+x1*y0-y1*x0)/L
        if d > dmax: imax,dmax = i,d
    if dmax > tol:
        return dp(pts[:imax+1],tol)[:-1] + dp(pts[imax:],tol)
    return [pts[0], pts[-1]]

def clip_ring(ring):
    # Sutherland–Hodgman against the frame rectangle
    def clip(poly, inside, intersect):
        out=[]
        for i,p in enumerate(poly):
            q = poly[i-1]
            if inside(p):
                if not inside(q): out.append(intersect(q,p))
                out.append(p)
            elif inside(q): out.append(intersect(q,p))
        return out
    def ix(a,b,axis,val):
        (x0,y0),(x1,y1)=a,b
        if axis==0: t=(val-x0)/(x1-x0); return (val, y0+t*(y1-y0))
        t=(val-y0)/(y1-y0); return (x0+t*(x1-x0), val)
    poly=ring
    for axis,val,keep in ((0,LON0,lambda p:p[0]>=LON0),(0,LON1,lambda p:p[0]<=LON1),(1,LAT0,lambda p:p[1]>=LAT0),(1,LAT1,lambda p:p[1]<=LAT1)):
        if not poly: return []
        poly = clip(poly, keep, lambda a,b,axis=axis,val=val: ix(a,b,axis,val))
    return poly

land = json.load(open('ne_50m_land.geojson'))
rings=[]
for f in land['features']:
    g=f['geometry']; polys = g['coordinates'] if g['type']=='MultiPolygon' else [g['coordinates']]
    for poly in polys:
        for ring in poly:
            pts=[tuple(p) for p in ring]
            if max(p[0] for p in pts)<LON0 or min(p[0] for p in pts)>LON1 or max(p[1] for p in pts)<LAT0 or min(p[1] for p in pts)>LAT1: continue
            c=clip_ring(pts)
            if len(c)>=3:
                s=dp(c+[c[0]],TOL)
                if len(s)>=4: rings.append(s)
gj={"type":"FeatureCollection","name":"land_calcofi","source":"Natural Earth 1:50m land (public domain), clipped to the CalCOFI frame, simplified 0.012°",
    "features":[{"type":"Feature","properties":{},"geometry":{"type":"Polygon","coordinates":[[list(p) for p in r]]}} for r in rings]}
json.dump(gj,open('land_calcofi.geojson','w'),separators=(',',':'))
import os; print('rings',len(rings),'points',sum(len(r) for r in rings),'bytes',os.path.getsize('land_calcofi.geojson'))

# ── the SVG, in the plugin's projection ─────────────────────────────────────
grid=json.load(open('/Users/bbest/Github/CalCOFI/CalCOFI.github.io/_data/grid.geojson'))
cells={f['properties']['grid_key']:(f['properties']['lon_ctr'],f['properties']['lat_ctr'],f['properties']['pattern']) for f in grid['features']}
cov=json.load(open('coverage_stations.json'))
def build(key, bbox):
    sampled={}
    for s in cov['stations']:
        for d in s['datasets']:
            if d['dataset_key']==key: sampled[s['grid_key']]=d['n_obs']
    core=[(lon,lat) for gk,(lon,lat,pat) in cells.items() if pat in ('standard','extended') or gk in sampled]
    x0=min(p[0] for p in core); x1=max(p[0] for p in core); y0=min(p[1] for p in core); y1=max(p[1] for p in core)
    padx=max((x1-x0)*0.06,0.4); pady=max((y1-y0)*0.06,0.4); x0-=padx; x1+=padx; y0-=pady; y1+=pady
    k=math.cos((y0+y1)/2*math.pi/180); wl=(x1-x0)*k; hl=(y1-y0); W=360.0; H=W*hl/wl
    px=lambda lon:(lon-x0)*k/wl*W; py=lambda lat:(y1-lat)/hl*H
    global LON0,LON1,LAT0,LAT1
    keep=(LON0,LON1,LAT0,LAT1); LON0,LON1,LAT0,LAT1=x0,x1,y0,y1
    fr=[c for c in (clip_ring(r) for r in rings) if len(c)>=3]
    LON0,LON1,LAT0,LAT1=keep
    land_d=' '.join('M'+' L'.join(f'{px(a):.1f} {py(b):.1f}' for a,b in r)+' Z' for r in fr)
    mx=max(sampled.values()) if sampled else 1
    dots=[]
    for gk,(lon,lat,pat) in cells.items():
        if gk in sampled:
            r=1.6+4.4*math.sqrt(sampled[gk]/mx)
            dots.append(f'<circle class="st st-on" cx="{px(lon):.1f}" cy="{py(lat):.1f}" r="{r:.1f}"><title>{gk} · {sampled[gk]:,} obs</title></circle>')
        else:
            dots.append(f'<circle class="st" cx="{px(lon):.1f}" cy="{py(lat):.1f}" r="1.3"/>')
    b=bbox; beyond = b['lon_min']<x0 or b['lon_max']>x1 or b['lat_min']<y0 or b['lat_max']>y1
    bx=px(max(b['lon_min'],x0)); bw=px(min(b['lon_max'],x1))-bx; by=py(min(b['lat_max'],y1)); bh=py(max(b['lat_min'],y0))-by
    # graticule ticks every 5°
    ticks=[]
    if beyond: ticks.append(f'<text class="tk" x="{W-4:.0f}" y="12" text-anchor="end">extent continues beyond the frame</text>')
    for lon in range(-135,-105,5):
        if not (x0<lon<x1): continue
        ticks.append(f'<text class="tk" x="{px(lon):.1f}" y="{H-3:.1f}" text-anchor="middle">{abs(lon)}°W</text>')
    for lat in range(20,51,5):
        if not (y0<lat<y1): continue
        ticks.append(f'<text class="tk" x="4" y="{py(lat)+3.5:.1f}">{lat}°N</text>')
    svg=(f'<svg class="cc-map" viewBox="0 0 {W:.0f} {H:.0f}" role="img" aria-label="{key}: sampled stations over the CalCOFI grid, with the coastline">'
         f'<rect class="water" width="{W:.0f}" height="{H:.0f}"/><path class="land" d="{land_d}"/>'
         f'<g class="stations">{"".join(dots)}</g>'
         f'<rect class="bbox" x="{bx:.1f}" y="{by:.1f}" width="{bw:.1f}" height="{bh:.1f}"/>'
         f'<g class="ticks">{"".join(ticks)}</g></svg>')
    open(f'map_{key}.svg','w').write(svg)
    print(key,'sampled',len(sampled),'svg bytes',len(svg),'W/H',W,round(H),'frame lon %.1f..%.1f lat %.1f..%.1f'%(x0,x1,y0,y1),'bbox beyond' if beyond else '')
build('calcofi_ctd-cast',{"lat_min":29.8268,"lat_max":37.8491,"lon_min":-126.4843,"lon_max":-117.2734})
build('swfsc_ichthyo',{"lat_min":22.0,"lat_max":48.0,"lon_min":-135.0,"lon_max":-109.0})
```
