# Next two weeks — Betty's board, Rasmus's transect streams, stations not cells, one release, and the reply

Status: **proposed 2026-09-09**. Nothing below has run. The final deliverable is the reply on the
*Next Two Weeks Tasks* thread (§ The reply); everything before it is what has to be true, or filed, for
that reply to point at real things rather than promises.

## The ask (Ben, 2026-09-09)

> Write a plan with the final objective of drafting a response to the email thread "Next Two Weeks
> Tasks" for Betty, Rasmus and Erin with suggestions and explanations. Along the way apply any
> necessary GitHub issue comments/closing/opening, GitHub Project management, ctd-cast ingestion /
> climatology fixes, database releasing and consumer updates to ctd-transects, Explorer apps and
> documentation.

Plus: explain to Rasmus that the climatology moved into the release database (which version, and does
that explain what he sees); check whether the line transects over-simplify near the coast by keying on
the station *grid cells*; give Betty real GitHub issues on a project board that is actually maintained
(orgs/CalCOFI/projects/4 has been idle a year, and many issues across the org are stale); the nine
near-term tasks Ben listed for Betty, plus "exciting tasks and a sense of growth".

## Context, measured 2026-09-09

### The thread (Gmail `1a081fa6c2393fa1`, four messages, 2026-09-08)

| from | when (UTC) | what |
|---|---|---|
| Betty | 17:04 | "I don't have much left on my to do list … send [ideas] my way" |
| Erin | 17:36 | adds Rasmus: could CTD / database-transition work be Betty's next step? |
| Erin | 17:53 | two asks: (a) the **pooled** ZooDB data should show in the *data finder* (Linsey Sala has thoughts); (b) add **Kathy Barbeau's iron dataset** (EDI) to the CalOOS inventory and the data finder, "or maybe that's in there already" |
| Rasmus | 21:51 | (1) Betty should **increase the data streams on the transect plotter**: only temperature (mean & anomaly) when a cruise has *Preliminary CTD 1-m binned* only; salinity, oxygen and chl-a when it has *Preliminary CTD & Bottle 1-m* or *Final* — ideally sensor averages, but when one sensor is flagged bad, use the other alone. (2) "The contour lines are showing fewer small artifacts. Was this done through 10-m averaging and/or increased smoothing?" (3) Database: circle back later |

"Data finder" is Erin's name for **db-viz-station** (`calcofi.io/db-viz-station`, the capstone
Station Explorer Betty maintains; notes 2026-08-26). It is not the Explorer.

### What each product is at, this morning

| repo | state |
|---|---|
| workflows | `main` = origin; uncommitted: the 9/7 plan file (+131 lines), `.claude/calcofi_notes.md` (+1,448), and the whole `presentations/` deck build (two 18–23 MB `.pptx`, a `_to_delete/`, a "polished copy", `assets/` ×28, `build_update_2026-09-08.R`, `COWORK_PROMPT_2026-09-08.md`) |
| calcofi4db 4.7.0 | pushed; `NEWS.md` 4.7.0 = integrity gate; RELEASES.md `# Unreleased` carries it |
| calcofi4r 1.22.0 | **ahead of origin by 1** (the s2/cmake install note) |
| explore | pushed; six lenses; deck shots committed 9/8 |
| docs | pushed; `5d6d98e + Betty` — Betty is an author in `_quarto.yml` (bthuang@ucsd.edu); `provide.qmd` (126 lines) drafted from her Naming Conventions Doc and "reconciled against the registries 2026-09-08" |
| CalCOFI.github.io | pushed; PR #5 (Explorer card, 2026-08-28) still open — probably superseded by the landing re-cut |
| ctd-transects | pushed; last data refresh 2026-09-06 against v2026.09.06 |
| release | `latest.txt` = **v2026.09.06**; CTD ingest last ran **2026-08-25** (2 h 8 m); `release_database` 2026-09-06 (2 h 10 m) |

### GitHub, the inventory

- `gh` token scopes are `gist, read:org, repo, workflow` — **no `read:project`/`project`**, so the org
  project cannot be read or written from here until Ben runs `gh auth refresh -s read:project,project`
  (interactive). The board's public URL needs a login too.
- Handles: Betty `bhuang0022`, Erin `evsatt`; Rasmus is **not** a member of the CalCOFI org and no
  handle turned up — anything for him goes by email or Ben files it on his behalf.
- Betty's footprint: 4 commits in workflows (the 7/28 four-dataset ingest PR #72; the Farallon-to-ERDDAP
  PR #77, merged 9/4), ~30 in db-viz-station, 4 in db-viz-hex (the 9/6–9/7 redesign). Almost every
  commit is titled **"Add files via upload"** — she works through the GitHub web uploader, not a clone,
  which is what reverted 937 lines of `app.js` once (memory: review the merge base). That is the single
  most valuable growth item on the list and it costs one pairing hour.
- Open issues, by repo (the 41 in workflows are the ones that matter):

| repo | open | shape |
|---|---:|---|
| workflows | 41 | 12 from 2022–2024 (#1–#24) predate the pipeline; 15 SoW `publish:`/`ingest:` deliverables (#27–#65); 6 analytics/ERDDAP (#45–#53); 5 live data bugs (#73–#78) |
| db-viz-station | 4 | Betty's app: CI JSON bloat (#8), responsive (#7), bathymetry quality (#5), three files with no generating script (#3) |
| db-viz-hex | 2 | #5 reproducible downloads; #7 "TEST feedback" |
| CalCOFI.github.io | 3 | 2022–2023: analytics, feedback form, repo rename — all done |
| server | 6 | 2022–2024: ERDDAP, CKAN, IPT, backups, staging — ERDDAP done, rest superseded |
| calcofi4r | 6 | #10 matching helpers (done in 1.13+), #9 deprecated fn, 4 `cc_places` layer asks |
| apps | 10 | 2022–2024 Shiny era; superseded by the Explorer |
| api | 3 | 2023; the plumber API is not a product any more |
| capstone / prj-mgt / larvae-cinms / pollutants-app | 10 / 6 / 3 / 1 | 2020–2023 student and PM scaffolding |
| rCRUX, OceanView, eDNA_*, MURI/MBARI protocols | 13+10+2 | **other groups' repos — leave alone** |

Verified against v2026.09.06 this morning, so these can close with evidence: **#75** (cruise table
built from ichthyo alone — 0 of 839 referenced `cruise_key`s missing now), **#64** (hex summaries across
datasets — all 15 obs datasets carry `hex_id`), **#52/#53** (the ctd dedup and PK, fixed in the 5/14–5/20
cycle per `ctd_thin` notes), **#27** (SIO PIC zooplankton biovolume is `sio_pic-zooplankton`, released).
**#74** narrows rather than closes: Farallon `cruise_key` NULL on 931 of 69,661 obs rows, down from all
66,272. **#36/#38/#39/#40/#45** (X to ERDDAP) are answered by `publish_to-erddap` (45 datasets) — close
each with the ERDDAP id. **#73** (METS netCDF) — `publish_to-netcdf` ships `mets` and the full table;
close with the manifest line.

### The climatology finding Ben quoted is already closed

The non-determinism ("60 of 71 climatology partitions re-export with new hashes") was found 2026-09-05,
fixed in **calcofi4db 4.1.1** (`build_climatology(round_digits = 6)`; DuckDB's parallel `avg()` /
`stddev_samp()` flipped the last bits) and shipped in **v2026.09.06** (RELEASES.md § v2026.09.06:
"`climatology` re-exports byte-identically now … values differ from v2026.09.04's beyond the 6th decimal
only"). The `taxon` "three notes cells" half was the append-only cache notes and is also stated there.
Nothing to fix; the plan records it so it is not re-opened.

### What Rasmus actually saw on the transect plotter

`ctd-transects` commits since he last looked (he asked on 8/26; the thread is 9/8):

| date | change | effect on contours |
|---|---|---|
| 2026-08-24 `e1be830` | exclude CTD values flagged 8 / 9 | removes flagged spikes |
| 2026-08-31 `54918d5` | **5 m rounded bins → 10 m floor bins**; anomaly baseline = the release's `climatology` table (same 1993–2013 / ≥ 3-cruise definition, computed once at release, shared with the Explorer) — via `climatology_fallback.sql` until a release carried the table | the big one: `obs` is the *thinned* CTD series (10 m grid + inflection points + bottle depths), so at 5 m about a third of the casts landed in off-grid bins sampled exactly where the profile bends, and those bin means sat visibly off their neighbours (station 60, July: 14.27 °C between 15.39 and 15.04). Every 10 m bin holds every cast |
| 2026-09-01 `d080f9b` | offshore on the left; both rulers on one axis | layout only |
| 2026-09-04 / 09-06 refresh | reads v2026.09.04 → v2026.09.06, the first releases that **ship** `climatology` (v2026.09.04 introduced it; v2026.09.06 rounded it) | baseline identical in definition; values differ from the inline fallback at the 6th decimal |
| smoothing | **unchanged**: Plotly `zsmooth: "best"` since the first commit (2026-08-06); no contour-level or kernel change | none |

So the honest answer is: yes, 10 m averaging (and removing flagged values), no added smoothing. The
climatology moved into the release with **v2026.09.04**; that changed *where* the baseline is computed,
not what it is.

### The coast: the plotter keeps one cast per grid cell, and the cells hold several stations

`grid_key` is a point-in-polygon into the 218 `cc_grid` cells; the nearshore cells on the core lines
are ~2,350 km² boxes holding 2–4 real stations (memory `grid-key-cells-hold-several-stations`).
`build_sections.sql` line 82 does `QUALIFY row_number() OVER (PARTITION BY cruise_key, grid_key ORDER BY
downcast, datetime) = 1` — it keeps whichever station the ship reached first. Measured on v2026.09.06
(`sample`, `calcofi_ctd-cast`, cast occupations with the d/u pair collapsed):

| what | number |
|---|---:|
| occupations with a `grid_key`, 1993–2026 | 9,637 |
| (cruise, cell) pairs the plotter draws | 8,042 |
| occupations dropped by the one-per-cell rule | **1,595 (16.6 %)** |
| since 2004, line 90 · 83.3 · 86.7 · 93.3 | 26.1 % · 23.8 % · 17.8 % · 16.7 % |

The four inshore cells do almost all of it, and every one is occupied every cruise since 2004:

| cell | stations it holds | occupations per cruise |
|---|---|---:|
| `st30-ln90` | 90.30, 90.28, 90.27.7 (SCCOOS), 88.5/30.1 | 3.67 |
| `st35-ln86.7` | 86.7/35, 86.7/33, 86.7/32.5, 85.4/35.4, 85.4/35.8 | 3.22 |
| `st40-ln83.3` | 83.3/40, 83.3/39, 83.3/40.6, 83.3/42, 84.0/41.7 | 2.88 |
| `st25-ln93.3` | 93.3/26.4, 93.3/26.0, 93.3/26.7, 93.4/26.x, 91.7/26.4 | 2.69 |

The Explorer's Sections lens (`sql/section.sql`) *averages* the casts in a cell instead (its `n` > 1
there), and `build_climatology()` pools them into one baseline cell — three products, three different
answers within 30 km of the coast, where the gradient is steepest. Ben's concern is right, and the fix
is the one the memory already names: **key sections and the climatology on `sample.site_key`** (the
real line/station, `090.0 028.0`), keep `grid_key` for maps and hexes. The x-axis is already distance,
so 90.26.4 / 90.27.7 / 90.28 / 90.30 fall where they belong without any layout change.

One thing in the way: `site_key` is not perfectly normalised. 28 CTD cast rows (14 keys) carry source
forms like `93.3    26.4`, `0093. 060.0`, `090.0 27.76`, `88.50 030.1` beside the canonical
`093.3 026.4`; ichthyo's 3,400 "odd" keys are legitimate negative stations (`011.7 -02.6`) and are fine.
A `normalize_site_key()` at ingest (pad line to `000.0`, station to `000.0`, keep the sign) and a release
check make `site_key` safe to key on.

### Rasmus's data-stream ask, against what the release carries

`sample.data_stage` already has the three tiers he describes (v2026.09.06):

| `data_stage` | cruises | years |
|---|---:|---|
| `final` | 113 | 1993–2021 |
| `preliminary_with_bottle` | 16 | 2021–2025 |
| `preliminary_without_bottle` | 5 | 2025–2026 |

and `obs` (thinned series) carries, for `calcofi_ctd-cast`: `temperature_ave`, `salinity_ave_corr`,
`salinity_1`, `salinity_2`, `oxygen_ml_l_ave_sta_corr`, `oxygen_ml_l_1`, `oxygen_ml_l_2`,
`fluorescence_v`, with per-sensor `measurement_qual` populated (383 / 473 / 1,940 / 94 flagged rows on
the four sensor series; the provider's own flags 0 good · 1 use-primary · 2 use-secondary · 8
questionable · 9 bad). What it does **not** carry, because `is_canonical = FALSE` in
`metadata/measurement_type.csv`: the per-sensor *corrected* series (`salinity_1_corr`, `salinity_2_corr`,
`oxygen_ml_l_1_sta_corr`, `oxygen_ml_l_2_sta_corr`) and any chlorophyll estimate
(`est_chlorophyll_a_sta_corr` / `_cruise_corr`); `btl_chlorophyll_a` exists but only at bottle depths.
The plotter today shows seven variables to every cruise and falls back to uncorrected `salinity_1` /
`oxygen_ml_l_1` on sensor-only cruises with a "prefer" note — the opposite of Rasmus's rule.

So his ask decomposes into: (a) an **app rule** (variables offered per `data_stage`); (b) an **ingest
change** (flip `is_canonical` on the four per-sensor corrected series and one chlorophyll estimate so
they reach `obs`; `libs/build_ctd_measurement_registry.R` owns the flag); (c) a **combination rule**
(mean of the two corrected sensors; if one is flagged 8/9, the other alone; honour 1/2 as the provider's
sensor choice) that belongs in calcofi4db/calcofi4r as a tested function, not inline SQL; and (d) three
questions only he can answer (§ D3).

### Erin's two asks

- **Pooled ZooDB.** `cce-lter_zoodb` has 351 unpooled tows (station-resolved, on the map) and 155
  pooled per-cruise regional composites (Lavaniegos & Ohman 2007) with **no position, no `grid_key`,
  no region geometry** (ingest Q05). They are in the release and on the dataset page, but no
  map-shaped product can place them. The fix is the one that worked for the Venrick phytoplankton
  regions (Q01, 2026-08-14): real polygons for the pooling regions → `sample_spatial` → the Explorer's
  Regions lens shows them; the data finder can then list them as "regional composites". Linsey Sala /
  Mark Ohman hold the region definitions.
- **Kathy Barbeau's iron.** Already in: `metadata/cce-lter/iron/dataset_meta.yml` (`cce-lter_iron`,
  status `archived`, EDI `knb-lter-cce.21.3`, DOI 10.6073/pasta/63c4…, 2002–2004, surface only), on
  `calcofi.io/datasets` under *not yet in the database*. Not ingested. It is small, complete and
  EDI-hosted — a good first end-to-end skills-loop ingest for Betty.

### Metadata and citations, the numbers

- 33 `dataset_meta.yml` sidecars; every one is missing at least one of `citation_main · license · doi ·
  pi_names · contact · acknowledgement · license_url`. Worst: the CalCOFI program datasets (`bottle`,
  `ctd-cast`, `mets` miss six of seven), the Stanford Hopkins trio, SCCOOS IFCB, JCVI NCOG, SWFSC ctd-noaa.
  Best: `cce-lter/euphausiids` (only `contact`), `zoodb`/`zooscan` (`citation_main`, `doi`, `contact`).
- **16 `dataset_meta.proposed.yml` files** (one per released dataset) written by the CalOOS-sheet import
  on 2026-09-05 are **still awaiting review** — that is the transition Ben describes, half done: the
  holdings are in, the proposals for the 16 integrated datasets are not merged.
- The provider Sheets exist (7, folder `1Tryjfd76TNU4nVPPSQiyQCy03uo0hlx6`, `metadata` tab on each,
  `holdings` tab on the calcofi Sheet); `scripts/sync_dataset_meta_sheets.R` pushes/pulls; the CalOOS
  working sheet (`1eyvhdzA5YwuDxH8tBld2-h_odKA1KYt_RXI3loI0OaU`) is still where Erin and Betty type.
- 17 holdings (`metadata/holdings.csv`, generated): 10 `external`, 7 `archived`; none `planned`.
- Staged, not deposited: **10 DwC-A** at `gs://calcofi-db/publish/dwca/` (phyllosoma, phytoplankton,
  euphausiids, zoodb, zooscan, dungeness-crab, bird-mammal, mesopelagic-fish, cufes, ichthyo) and
  **3 EDI packages** (`bottle`, `ctd-cast`, `mets`).
- Vignettes: calcofi4r **4** (`calcofi4r`, `bio-env-matching`, `citing-calcofi-data`,
  `ctd-temperature-anomalies`); calcofi4py **1** (`ctd-qaqc`). No zooplankton, ichthyoplankton,
  seabird/mammal, or "reproduce a State of the California Current figure" article in either.

## Findings

- **F1** The climatology hash churn is closed (4.1.1, v2026.09.06). Rasmus's smoother contours are the
  10 m floor bins plus flag 8/9 removal; smoothing never changed; the release-hosted climatology
  (v2026.09.04) is the same definition in a new place.
- **F2** The over-simplification is real and measurable: 16.6 % of CTD occupations never reach the
  plotter, concentrated in four inshore cells that each hold 3–4 stations occupied every cruise. The
  Explorer averages what the plotter drops; the climatology pools both. Nobody keys on the station.
- **F3** `site_key` needs normalising before anything keys on it (28 CTD rows, 14 keys).
- **F4** Rasmus's tiered-variable rule is implementable: the tiers, the sensor pairs and the flags are
  in the release; the corrected per-sensor series and a chlorophyll estimate are one registry flag and
  an ingest re-run away.
- **F5** The org's GitHub is two things at once: an active pipeline with a real issue stream
  (#73–#78) and a graveyard of 2022–2024 scaffolding. Betty cannot be handed a board on top of that
  without a triage first, and the triage needs `project` scope Ben has to grant.
- **F6** Betty's most limiting habit is the web uploader; her most recent work (db-viz-hex redesign,
  PR #77) shows she can carry a feature end to end.
- **F7** Erin's iron ask is already answered by the catalog; her ZooDB ask is a geometry task, not a UI
  task.
- **F8** The CalOOS → Sheets transition stalls on 16 unreviewed proposal files, not on tooling.
- **F9** Nothing in the last two releases regenerated the CTD ingest (last run 8/25); the
  `apply_accepted_flags` chunk has never run against a non-empty ledger; any new `_CTDPrelim.zip`
  drops since then are not in the release. A CTD re-run is due regardless of D3.
- **F10** Uncommitted work in workflows (deck build, plan, notes) and one unpushed calcofi4r commit
  are a day old; commit before anything else so the two weeks start clean.

## Decisions

### D1 — What we tell Rasmus, and that the climatology is his to trust

Say it as § What Rasmus actually saw: 10 m floor bins (the release's `depth_bin` grain, needed because
the thinned series' off-grid 5 m bins were sampled at inflection points), flagged 8/9 values removed,
baseline now the release's `climatology` table (since v2026.09.04, shared by the Explorer and
`calcofi4r::cc_climatology()`, rounded to 6 dp since v2026.09.06), smoothing unchanged. Then state F2
plainly as something *we* found while answering him, with the fix and the release it lands in (D2).
**Recommendation:** do not oversell; the caveat is what earns the trust.

### D2 — Sections and the climatology key on the station (`site_key`), the cell stays for maps

- calcofi4db: `normalize_site_key()` applied in every ingest that mints one (`ns_key`-adjacent helper,
  tested on the 14 CTD variants and the ichthyo negatives); `check_site_key_format()` in the release
  gates. `build_climatology()` grains on `dataset_key × site_key × month × depth_bin × type`, keeps
  `grid_key` as a denormalised column, drops nothing else; PK in `core_relationships()` follows;
  `RELEASES.md # Unreleased` states the grain change and that inshore baselines move (the +/−1 °C the
  memory measured on line 90 station 30). `cc_climatology()` reads either grain (`site_key` when
  present).
- ctd-transects: `build_sections.sql` partitions on `(cruise_key, line, station)` parsed from `site_key`,
  filters `line = {line}` exactly (88.5/30.1 stops leaking into line 90), joins the baseline on
  `site_key`; SCCOOS stations get their own x positions; `station_bathymetry.csv` gains rows for them
  (script exists, `build_station_bathymetry.R`).
- explore: `sql/section.sql`, `section_clim.sql`, `section_cruises.sql` group on `site_key`-derived
  station; the section's n-weighted pooling across datasets is unchanged.
- **Alternative rejected:** keep `grid_key` and only stop dropping casts (average like the Explorer).
  It hides a 15–30 km gradient under one bar and still mis-keys 88.5/30.1 onto line 90.

### D3 — Rasmus's streams: app rule + one registry flip + a tested combination function; three questions first

Ask Rasmus (in the reply) before building: (1) for `final` / `preliminary_with_bottle`, is the
provider's `salinity_ave_corr` / `oxygen_ml_l_ave_sta_corr` already the sensor average he wants, or should
we recompute from `salinity_1_corr` / `salinity_2_corr` (and `oxygen_ml_l_{1,2}_sta_corr`) applying "one
sensor flagged → use the other" and honouring flags 1/2? (2) which chlorophyll: `est_chlorophyll_a_sta_corr`
(bottle-fitted, sensor resolution) or `btl_chlorophyll_a` (discrete)? (3) on `preliminary_without_bottle`,
hide salinity/oxygen entirely (his words) or show uncorrected with a badge? **Recommendation, stated as
ours:** temperature only on sensor-only cruises; recompute the average ourselves from the corrected pair
so the flag rule is explicit and tested (`calcofi4db::combine_sensor_pair()` + calcofi4r/py twins);
`est_chlorophyll_a_sta_corr` as "chlorophyll-a (estimated)"; `fluorescence_v` stays labelled volts.
Betty owns the ctd-transects side (SQL + `app.js` gating on `shard.data_stage`, which the badge already
reads); Ben the registry flip + ingest re-run; the release carries it.

### D4 — GitHub: triage first, then a live board, then Betty's issues

1. Ben: `gh auth refresh -s read:project,project`.
2. Read project 4. If it is a classic-style board with no fields, **create a new org Project
   "CalCOFI.io"** (Status · Owner · Area = ingest/metadata/publish/apps/docs/packages · Size · Target
   week), link workflows, explore, docs, CalCOFI.github.io, ctd-transects, db-viz-station, db-viz-hex,
   calcofi4r, calcofi4py; close project 4 with a note pointing here. If project 4 is salvageable, reuse it.
3. Triage, with one comment each and never a silent close: close the verified-done set (§ Context:
   #27, #36, #38, #39, #40, #45, #52, #53, #64, #73, #75; CalCOFI.github.io #1–#3; server #4; calcofi4r
   #10), narrow #74; close the 2022–2024 pre-pipeline set in workflows (#2–#4, #9–#18, #22) with
   "superseded by <product>" (each names the Explorer lens / calcofi4r fn / docs page that now answers
   it — #17 *State of the CC figures* stays open and becomes Betty's vignette arc); close apps (10), api
   (3), server (#3, #5, #6, #8, #9), prj-mgt (6), capstone (10), larvae-cinms (3), pollutants-app (1) as
   superseded; **propose archiving** capstone, prj-mgt, api, larvae-cinms, pollutants-app (Ben decides;
   archiving is reversible). Never touch rCRUX, OceanView, eDNA_*, MURI/MBARI.
4. Label `betty` + milestone **`2026-09 sprint`** on each of Betty's issues (§ Appendix A); every issue
   has *why it matters*, *done when*, *first step*, *who to ask*, and a size.

### D5 — Betty's two weeks: four review tasks, four build tasks, two arcs

The review tasks are Ben's list; the build tasks are where the growth is. Ordering for the reply:
start with what unblocks others (provide.html, the 16 proposals), then the two pieces with a partner
(Rasmus's streams, Linsey's regions), then the solo builds (iron ingest, vignettes), and the two arcs
that outlast the sprint. Full catalogue in Appendix A; the arcs:

- **Arc 1 — CalCOFI's publisher of record.** Review and *deposit* the 10 DwC-A and 3 EDI packages
  (#42–#44, #62 become hers), register the sitemap/JSON-LD with ODIS and Google Dataset Search (#24),
  run the provider-metadata campaign through the Sheets, and own the quarterly "what changed in the
  catalog" note. Visible, external, hers.
- **Arc 2 — the scientists' on-ramp.** One vignette per community in calcofi4r **and** calcofi4py
  (ichthyoplankton larval index per 10 m² with the positive-only trap stated; zooplankton biovolume +
  ZooDB/ZooScan; CTD sections and anomalies in Python to mirror the R one; seabirds/mammals OBIS-shaped;
  the crab megalopae series), each reproducing one *State of the California Current* figure (#17). The
  set is the skeleton of a data-descriptor paper on the integrated database with Betty as an author.

Plus the one-hour habit change: a clone, a branch, a PR, a review — first PR is the provide.qmd edit.

### D6 — One release, staged first, in the second week

Contents: integrity gate (already Unreleased) · `site_key` normalisation + check (D2) · climatology on
`site_key` (D2) · CTD ingest re-run with the canonical flips (D3), the `apply_accepted_flags` chunk on
whatever the ledger holds, and any new `_CTDPrelim.zip` drops · `cce-lter_iron` if Betty's ingest lands
in time (`in_release: false` otherwise) · ZooDB region geometry if Linsey's polygons arrive. Run per the
`release-run` skill: staging prefixes both set, `test_release.qmd` green, `latest.txt` promoted, then
`scripts/deploy_consumers.sh` (ctd-transects refresh dispatch, Explorer `smoke_release.mjs`, the docs
book, db-viz-station refresh). Target **v2026.09.2x**, after Rasmus answers D3's questions; if he has not
by day 8, ship D2 without D3 and keep D3 for the next cut.

### D7 — Housekeeping today

Commit the 9/7 plan + notes; in `presentations/` keep `build_update_2026-09-08.R`, `COWORK_PROMPT_*.md`,
`assets/` and **one** `.pptx` (the polished one, 19 MB; the June deck is already tracked at 0.6 MB),
delete `_to_delete/` and the "copy", add `presentations/*/` (the unpacked dir) to `.gitignore`;
push calcofi4r. Close or merge CalCOFI.github.io PR #5.

### D8 — Erin's asks answered in the reply, not deferred

Iron: "already listed, Betty ingests it" with the link. ZooDB: "needs the region polygons, Betty + Linsey,
then it appears in the Explorer's Regions lens and the finder lists the composites."

### D9 — The reply

One message from Ben to the thread (reply-all), plain text, three short sections (Rasmus / Betty /
Erin), every task a link to an issue on the board, provider outreach explicitly held until Erin is back,
and the three questions for Rasmus numbered. Draft in § The reply; sent after the issues exist so the
links are real.

## Slices, in order

| # | slice | owner | depends on | size |
|---|---|---|---|---|
| 0 | D7 housekeeping commits; `gh auth refresh -s read:project,project` | Ben (+ me) | — | 20 min |
| 1 | D4 triage: comments + closes with evidence; archive proposals listed for Ben | me | 0 (scope) | 1 h |
| 2 | D4 board: read project 4, decide reuse/new, fields, link repos | me → Ben confirms | 1 | 30 min |
| 3 | Betty's issues (Appendix A) filed, labelled, on the board; two `question`s for Rasmus filed in ctd-transects by Ben | me | 2 | 1 h |
| 4 | D2 calcofi4db: `normalize_site_key()` + check + `build_climatology(site_key)` + NEWS + tests; RELEASES Unreleased | me (Sonnet-high brief) | — | 3 h |
| 5 | D2 consumers: ctd-transects SQL + bathymetry rows; explore section SQL ×3; `cc_climatology()` | me | 4 | 3 h |
| 6 | D3 registry flips + `combine_sensor_pair()` + twins; CTD ingest re-run (2 h) | me | Rasmus's answers | 4 h |
| 7 | D6 staging release → tests → promote → `deploy_consumers.sh` | me, Ben watches | 4–6 | 3 h wall |
| 8 | D9 send the reply | Ben | 3 | 10 min |
| 9 | Betty's sprint runs; Friday check-in on the board | Betty, Ben | 8 | 2 weeks |

Slice 8 does not wait for 4–7: the reply goes out once the issues exist (day 1), and names the release
as "the next cut, target the week of the 21st".

## Verification

- Triage: every closed issue has a comment naming the evidence (a query, a URL, a commit); `gh issue
  list --state closed --search "closed:>=2026-09-09"` per repo matches the list here.
- Board: every `betty`-labelled issue appears with Status/Owner/Size set; Betty can edit it (org member).
- D2: `stopifnot(all(grepl("^-?[0-9]{3}\\.[0-9] -?[0-9]{3}\\.[0-9]$", sample$site_key)))` passes on the
  staged release; `climatology` has `site_key`, its PK is unique (integrity.json ok); the plotter's shard
  for line 90 / 2026-07 has stations 26.4, 27.7, 28, 30 as separate columns; the Explorer's section n at
  station 30 is 1 per cruise.
- D3: on a `preliminary_without_bottle` cruise the variable picker offers temperature only; on a `final`
  cruise a synthetic fixture with sensor 2 flagged 9 yields sensor 1 alone (testthat + pytest).
- Release: `test_release.qmd` 0 fail; `verify_release_objects.R` 0 problems; `latest.txt` = new version;
  ctd-transects `index.json.release` and the Explorer's release chip match within the hour.
- Reply: every link resolves (issues, board, docs, Explorer, slides).

## The reply (draft for Ben to send; «…» filled in after slice 3)

Subject: Re: Next Two Weeks Tasks

Hi Betty, Rasmus, Erin —

Three parts: what changed on the transect plotter and why (Rasmus), a concrete list for Betty with a
board behind it, and Erin's two questions.

**Rasmus — the calmer contours, and one thing we found while checking.**
Two changes, no added smoothing. (1) Since 8/31 the sections are 10 m floor bins instead of 5 m rounded
bins. The database carries a thinned CTD series (a 10 m grid plus the depths where each profile bends,
plus bottle depths), so at 5 m about a third of the casts fell into off-grid bins sampled exactly at the
inflection points, and those bin means sat visibly off their neighbours — that was most of the speckle.
(2) Since 8/24 values the CTD files flag 8 or 9 are excluded. The renderer's smoothing has been the same
since the first version. Separately, the anomaly baseline is now a `climatology` table computed once
inside each database release (since v2026.09.04; the Explorer and the R/Python packages subtract the
same table) — same definition as before, 1993–2013 monthly means at ≥ 3 cruises, so that is not what you
saw. What I did find: the plotter keys stations on the CalCOFI grid *cell*, and the inshore cells hold
several stations (the "station 30" cell on line 90 holds 90.30, 90.28, 90.27.7 and 88.5/30.1). The
plotter kept whichever the ship reached first — 16.6 % of occupations never drew, almost all within
30 km of the coast. The next release keys on the real station, so those appear as their own columns
(the x-axis is already distance), and the climatology baseline moves with it. Target: week of the 21st.

On the data streams — yes, and the pieces are in place: the database already tags every cast as
Final / Preliminary CTD & Bottle / Preliminary CTD-only, and carries both sensors with their flags.
Betty will own the plotter side and I'll do the ingest side. Three questions for you first:
1. For Final and CTD & Bottle cruises, is the file's own average (`Salt_ave_corr`, `Ox_ave_sta_corr`)
   what you want, or should we recompute the mean from the two corrected sensors, using one alone when
   the other is flagged 8/9 (and following the 1/2 "use primary/secondary" flags)? I'd propose the
   latter, so the rule is explicit and tested.
2. Chlorophyll: the bottle-fitted estimate at sensor resolution (`EstChl_StaCorr`), or the discrete
   bottle values? Fluorescence stays labelled as volts.
3. On CTD-only preliminary cruises: hide salinity/oxygen entirely (as you wrote), or show the
   uncorrected sensor with a badge?

**Betty — the list, with an issue for each on the board: «board URL».**
Start with the two that unblock other people:
- Review/edit the provider guide, calcofi.io/docs/provide.html («issue») — it is your Naming
  Conventions Doc reconciled with the registries; make it yours, as a pull request in CalCOFI/docs
  (I'll pair for an hour on clone → branch → PR so this and everything after goes that way).
- The metadata transition («issue»): the CalOOS sheet's rows were imported on 9/5; 16 proposal
  files for the integrated datasets are waiting for your review before they become the record, then
  the `metadata` tab in each provider Sheet (Drive folder «link») is where we collect from now on.
  calcofi.io/docs/metadata.html describes the loop; edit it where it is wrong.
Then, with a partner:
- Transect plotter data streams with Rasmus («issue»), per his answers above.
- ZooDB pooled composites with Linsey Sala («issue»): they need the region polygons (as we did for
  Venrick's phytoplankton regions); with those they show in the Explorer's Regions lens and the
  finder can list them.
Then on your own:
- Ingest Kathy Barbeau's iron dataset from EDI («issue») — small and complete, a full run of the
  explore → metadata → ingest → validate loop; it is already a listed holding on calcofi.io/datasets.
- Provider citation gaps («issue»): draft the emails now (every dataset is missing at least one of
  citation / licence / DOI / PI / contact / acknowledgement); we send after Erin is back.
- Review the Explorer («issue»; use Help → Send feedback for anything visual, PRs welcome), the
  landing page and dataset catalog («issue»), and the 10 OBIS + 3 EDI packages staged for deposit
  («issue») — you would be the one who submits them.
- calcofi4r / calcofi4py vignettes by community («issue»): ichthyoplankton, zooplankton, CTD in
  Python, seabirds/mammals — each reproducing one State of the California Current figure. That set is
  the outline of a data paper on the integrated database with you as an author.
- The rest of the holdings («issue» = the triage tab in the calcofi Sheet), in the order you and
  Erin set.
The update deck from Monday: «slides URL». New since you last looked: calcofi.io (landing + dataset
pages), calcofi.io/explore (six lenses), calcofi.io/docs (you're an author now).

**Erin —** the iron dataset is already in the inventory and on calcofi.io/datasets as a holding
(EDI knb-lter-cce.21.3); Betty ingesting it puts it in the apps. Pooled ZooDB needs geometry before
any finder can show it — see Betty's item with Linsey.

Friday check-ins on the board; anything blocked, write it on the issue.

Ben

## Appendix A — Betty's issues (repo · title · why · done when · size)

| # | repo | title | why it matters | done when | size |
|---|---|---|---|---|---|
| B1 | docs | Provider guide: review `provide.qmd` as a PR | it is her Doc, made the record; first branch+PR | PR merged; her Doc says "superseded by" | S |
| B2 | workflows | Merge the 16 `dataset_meta.proposed.yml` into the record | ends the two-sheets period | 0 proposed files; `sync_dataset_meta_sheets.R push` clean | M |
| B3 | workflows | Metadata collection moves to the provider Sheets' `metadata` tabs | one place per provider | CalOOS sheet marked read-only with a pointer | S |
| B4 | ctd-transects | Variables per `data_stage`, sensor-pair rule (with Rasmus; Ben does ingest) | Rasmus's ask; the CTD team's product | D3 verification | M |
| B5 | workflows | ZooDB pooled composites: region geometry with Linsey Sala (Q05) | 155 samples nobody can map | polygons in `spatial`, `sample_spatial` rows, Regions lens shows them | M |
| B6 | workflows | Ingest `cce-lter_iron` (EDI 21.3) | Erin's ask; first solo loop run | in a release; dataset page live | M |
| B7 | workflows | Provider citation/licence gap emails (draft now, send after Erin) | 33 sidecars incomplete | one draft per provider in the Sheet folder | S |
| B8 | explore | Explorer review with PRs | second pair of eyes (deck ask) | ≥ 5 feedback items or PRs | S |
| B9 | CalCOFI.github.io | Landing + catalog corrections | same | PR | S |
| B10 | workflows | Review the 10 DwC-A + 3 EDI packages; deposit plan | Arc 1 | per package: ok / issue; first deposit scheduled | M |
| B11 | calcofi4r + calcofi4py | Vignettes by community (+ missing functions, parity table) | Arc 2; #17 | 2 vignettes per package merged | L |
| B12 | workflows | Holdings triage: next three ingests | `holdings` tab | three rows with owner + next_step | S |
| B13 | workflows | ODIS + Google Dataset Search registration (#24) | Arc 1 | both index calcofi.io/datasets | S |
| B14 | db-viz-station | #3, #5, #8 on her own app | her app, real bugs | issues closed | M |
| B15 | workflows | Product showcase: 5-minute lens videos + a webinar (#65) | SoW share item; visible | 6 clips on the landing ship's log | M |

## Appendix B — what the plan does not do

- Does not touch the CTD team's PostgreSQL or the `flag_accepted` bridge beyond running the chunk.
- Does not change `grid_key`, `hex_id` or any map product; only sections and the climatology re-key.
- Does not deposit to OBIS/EDI; that stays a deliberate manual act (Betty proposes, Erin/Ben approve).
- Does not archive any repo without Ben saying so.

## Executed 2026-09-09 (slices 0–5; 6–7 pending)

- **Slice 0.** Plan + deck build committed (`bfa2433`); calcofi4r pushed; `gh auth refresh -h github.com -s read:project,project`.
- **Slice 1.** ~75 issues closed with evidence comments (workflows, CalCOFI.github.io, server, calcofi4r, apps, api, capstone, larvae-cinms, pollutants-app, prj-mgt, db-viz-hex); #74 retitled (931 NULL cruise_keys); #73 status noted (thinned METS netCDF published, full not); PR CalCOFI.github.io#5 closed. Nothing archived (Ben's call).
- **Slice 2.** Project 4 "Management" closed with a pointer; **project 5 "CalCOFI.io"** created (Status · Area · Size · Owner · Target week; ten repos linked), 38 items with fields set.
- **Slice 3.** Betty's issues: docs#14, workflows#79 #80 #81 #82 #83 #84 #85, ctd-transects#1, explore#8, CalCOFI.github.io#12, calcofi4r#17; existing #17 #24 #42 #43 #44 #62 #65 and db-viz-station #3 #5 #7 #8 labelled `betty` + milestone `2026-09 sprint`. Ben's: workflows#86 (site_key grain), #87 (CTD canonical flips, waits on Rasmus), ctd-transects#2, explore#9.
- **Slice 4.** calcofi4db (working tree, **uncommitted — shares the tree with the reference-layers session's 4.8.0**): `R/site_key.R` (`site_key_sql()`, `normalize_site_key()`, `check_site_key_format()`), `append_sample()` normalises `site_key` (exactly the 28 CTD rows change on v2026.09.06, nothing else), `build_climatology()` grained on `site_key` via `sample` with `grid_key` = modal cell, PK + export sort key follow, `obs_bio`/`obs_env` gain `site_key`; NEWS under 4.8.0; 550 tests green; installed. calcofi4r **1.23.0** pushed (`38286fc`): `cc_climatology()` computes on `site_key`.
- **Slice 5.** ctd-transects PR #3 and explore PR #10 (branches `site-key`), to merge after the release. `release_database.qmd` calls `check_site_key_format()` before the PK gate and counts stations by `site_key`; `RELEASES.md # Unreleased` carries the section — both **uncommitted** in the shared tree.
- **Slice 8 (moved up).** The reply is Gmail draft `r-306959493649294701` on the thread, with every link live; Ben sends.
- **Pending.** Slice 6 (D3) waits on Rasmus's three answers; slice 7 (staged release → promote → `deploy_consumers.sh`, then merge the two PRs) after the reference-layers work commits. Measured on the way: 709 of 9,705 `site_key`s straddle a grid-cell edge; the ichthyo "odd" keys are legitimate negative stations.

## Executed 2026-09-10 (slice 6, early — Rasmus answered the same day)

- Rasmus (thread, 2026-09-09 18:57 UTC): recompute the sensor mean ourselves with the flag rule (yes); chlorophyll and nitrate from the corrected **sensor** estimates at both correction levels, oxygen likewise; sensor-only preliminary cruises stay temperature-only; raise the floor to **5 cruises**; show the baseline's n; explore a monthly-vs-seasonal toggle; later a bottle-database baseline at observed depths.
- Ben stopped the other session's staging run (minutes into the CTD render) so the run carries all of it: `libs/build_ctd_measurement_registry.R` gains `corr_types` (ten types canonical; the thinned depth set is unaffected — RDP runs on temperature / salinity_ave_corr only; the builder's round-trip assertion was a latent bug, fixed); `release_database.qmd` `min_cruises = 5L`; RELEASES.md section; `docs/db.qmd` ≥ 5; ingest prose. Commit `bc66596`. calcofi4db **4.11.0** `combine_sensor_pair()` + SQL twin (`652805a1`, fix `edf633ee`). Issues: ctd-transects#1 carries the plotter work (Betty), workflows#91 the seasonal / bottle-baseline design (Ben).
- Relaunch: the other session's staging command with `tar_invalidate(c(release_database, test_release))`. After promotion: merge ctd-transects#3 and explore#10, close #86/#87, refresh the ctd-transects shards.
