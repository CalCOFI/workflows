# db-viz-hex: summarize within spatial polygons, not just hexagons

**Start a fresh session with this file.** Written to be self-contained; the
preceding session's context can be discarded.

---

## The ask

`db-viz-hex` aggregates observations into H3 hexagons. It should *also* be able
to aggregate them **within a named boundary** — an MPA, a county, a sanctuary,
the EEZ — and report a value per polygon rather than per hex.

**The data layer is already built and deployed. Only the UI is missing.**

## What already exists (do not rebuild)

`prep_db.R` materializes these into the app's local DuckDB
(`data/calcofi_latest.duckdb`, symlinked to the current release):

| table | what it is |
|---|---|
| `sample_spatial` | `sample_key, spatial_key, layer, spatial_name` — which polygons each sampling event falls in. Many-to-many on purpose: a station can be in a county *and* a sanctuary *and* an MPA, and all three are true. |
| `spatial` | `spatial_key, id, layer, name, geom` — the polygon geometry itself, ~3,373 features across 18 layers. Kept in the app DB precisely so a boundary can be drawn and labelled. |
| `bio_obs` | carries `sample_key`, so it joins `sample_spatial` directly |
| `env_obs` | carries `sample_key` **as `cast_id`** — join `sample_spatial.sample_key = env_obs.cast_id` |

A working end-to-end query, verified:

```sql
SELECT ss.spatial_name, COUNT(*) AS n_obs, ROUND(AVG(e.qty), 2) AS mean_temp
FROM env_obs e
JOIN sample_spatial ss ON ss.sample_key = e.cast_id
WHERE e.measurement_type = 'temperature'
  AND ss.layer = 'Marine Protected Areas'
GROUP BY 1 ORDER BY 2 DESC;
-- South Point State Marine Reserve  3186  12.39
-- Begg Rock State Marine Reserve    1963  13.16
```

The layers available, by how many samples fall in them: Marine Ecoregions
(MEOW), IEA Large Marine Ecosystems, Cowcod Conservation Areas, CDFW Regions,
CA Counties, CA Senate/Assembly Districts, CA State Waters (3NM), Marine
Protected Areas, Water Quality Protection Areas, SoCal Aquaculture AOAs, and
more.

## What to build

A way to switch the map's aggregation unit from **hexagon** to **a chosen
spatial layer**, then colour and label each polygon by the same statistic the
hex view already shows.

Key files:

- `app/ui.R` — the controls
- `app/server.R` — the reactives, the map, the popup/tooltip, the download
- `app/functions.R` and `app/functions_h3t.R` — the existing hex aggregation.
  `functions_h3t.R` builds the `(cell_id, value, n)` projection the map layer
  consumes; the polygon path wants the same shape keyed by `spatial_key`, so the
  rendering code has as little special-casing as possible.

Things worth deciding rather than assuming:

- **One layer at a time, or several?** Overlapping layers means an observation
  can belong to more than one polygon, so summing across layers double-counts.
  A single-select layer picker sidesteps this; if you allow multi-select, say
  clearly in the UI that the layers overlap.
- **Where the polygons are drawn from.** The app already renders PMTiles from
  `gs://calcofi-files-public/_spatial/` for the *overlay*. Those are for display;
  `spatial.geom` in the local DB is the same geometry as data. Reusing the
  PMTiles for the boundary and joining the summary on `spatial_key` is probably
  cheaper than shipping geometry to the client, but check that the PMTiles carry
  an id that matches `spatial_key` — they may only carry the per-layer `id`,
  in which case the join key is `(layer, id)`.
- **Empty polygons.** Most polygons in a layer contain no CalCOFI samples.
  Decide whether they render as "no data" or are omitted; do not let them read
  as zero.
- **The CPUE caveat carries over.** `bio_obs.std_tally` is a gear-standardized
  density only where a net tow supports it; elsewhere it is the published value
  in its own units (`cpue_unit`). Averaging across datasets with different units
  is meaningless — the existing app guards with `WHERE std_tally IS NOT NULL`,
  and a polygon summary needs at least as much care. Consider grouping by
  `cpue_unit` or restricting to one dataset.

## Context you will want

- The app now sees **the whole database**: `bio_obs` is 1,203,294 rows across all
  9 bio datasets (it was 459,286, ichthyo only) and `env_obs` is 18,884,137
  across all 5 env datasets (it was ~5.4M, bottle only). Both restrictions were
  removed on 2026-08-02.
- **`sample_spatial` is joined at the SAMPLE grain, not at obs** — 1.5M rows
  rather than 20M, a ~13x smaller point-in-polygon join for the same answer,
  because an observation's position is its sample's position.
- **Do not "simplify" the NaN filter out of `prep_db.R`.** Release v2026.08.02
  shipped 1,590 rows with `NaN` coordinates; `ST_Point(NaN, NaN)` is a real
  non-NULL geometry that passes `IS NOT NULL`, and its presence makes
  `ST_Intersects` return different counts at different thread counts, dropping
  valid unrelated pairs. `calcofi4db` 3.4.2 stops them being minted; the filter
  in `prep_db.R` protects against already-published releases.
- Deployment: `ssh calcofi`, then
  `git -C /share/github/CalCOFI/db-viz-hex pull --ff-only`,
  `docker exec -d rstudio bash -lc "cd /share/github/CalCOFI/db-viz-hex && Rscript prep_db.R"`,
  then `touch /share/github/CalCOFI/db-viz-hex/app/restart.txt`.
  The app is served at `/srv/shiny-server/db-viz-hex` (and the `int` / `int-app`
  aliases) as a symlink to `…/db-viz-hex/app`.

## Verification

- A polygon summary agrees with the equivalent hex summary over the same
  filter, to within what differing spatial units explain.
- Switching layers changes the map without a full reload, and clearing the
  selection returns to the hex view.
- A layer with overlapping polygons does not silently double-count.
- The raw-data download reflects the polygon selection.
