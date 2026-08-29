# CalCOFI Explorer UI — rails & cards, naming, sorted pickers, browse by category, icons, tour, annotated feedback

**Status:** proposed 2026-08-29; Ben answered the open questions the same day (*Biology · Environment*; feedback to
Ben + Erin + Betty with an editable recipient list and public GitHub issues in `CalCOFI/explore`; the calcofi.org
icons were an example, not a requirement; **the phone must not fail**) and added four asks — per-figure PNG export,
two overlay layering bugs, year-strip zoom / month detail / a *cruises* mode, and icons + group labels on the
top-level choices — folded in as D19–D20, the D11/D12 additions and slice U6 · **Date:** 2026-08-29 ·
**Scale:** one repo (`CalCOFI/explore`), ~98 h in seven shippable slices; two small registry additions in
`workflows`/`calcofi4db` (a category registry, `category` + `variable` on `measurement_type.csv`, `taxa[]` in
`coverage.json`); one brand addition (`brand/v1/icons/`); one Apps Script endpoint. Extends `2026-08-28 CalCOFI
Explorer …` (Phases 1–2 shipped) and replaces its Phase 5 "tour + polish" line.

## The ask (Ben, 2026-08-29)

1. Panels that expand, float and collapse — pill labels when collapsed. Should the depth panel collapse itself
   when the selection has no depth axis (choosing an ichthyo taxon), or is a layout that changes by itself too
   disorienting? "Your take on the most fluid UI."
2. "taxon" / "variable" are not intuitive — they are "bio" and "env"; so "biology" / "environment"?
3. Every drop-down (variable, taxon, cruise) sorts by record count, which makes a specific item hard to find.
   Alphabetical by default; most/least records still easy to see, as a secondary thing.
4. The Station Explorer's "What CalCOFI measures" — the whole holding **by Category** or **by Dataset** — is much
   easier for seeing what exists.
5. Category icons: the station app's emoji work; calcofi.org's data pages have SVG icons; an SVG set for the
   categories (datasets would be over-complicated).
6. An About modal, a guided tour and a feedback button like the other apps — and the feedback should carry the
   current view's URL, a screenshot, and the user's annotations on it ("that spike is weird").
7. Download any figure — the time strip, the water column, a section, any panel — as a PNG.
8. Layering bugs: with Sections, the map's yellow line and station dots draw *over* the section card
   (`?lens=section&taxon=worms:217452&stage=larva&den=per_10m2&line=90&cruise=2009-04-OIFS`); the station dots
   draw over the timing panel; the ⚙ gear sits on top of the attribution ⓘ.
9. The year strip: the brush-to-filter is loved; add zoom into a period and back out, **month** detail when zoomed
   in, and a third mode beside *rows* / *mean ± se* — **cruises**, Gantt-like with the `YYYY-MM-NODC` codes —
   "but maybe that gets too busy?"
10. Icons on the top-level choices, and group labels — *Lens* (Stations · Hexagons · Cruises · Regions · Sections)
    and *Measurement* (taxon · variable)?

## Context — what the UI is today (read 2026-08-29; `explore` @ `af7f595`)

- **Layout** (`src/style.css:9`): a fixed CSS grid `290px 1fr 210px` × `1fr 140px` — the controls rail (left,
  full height), the map, the water-column strip (right, full height), the year strip (bottom, under the map).
  Nothing collapses. The section (`.section-panel`, 46 % of the map) and cruise-series (`.cruise-panel`, 34 %)
  panels are already **floating cards over the map**; the station coverage card grows *inside* the left rail
  (`App.tsx:509`) and pushes the export buttons off-screen; timing/SQL sits behind a gear. On a phone
  (`shots/dev2/phone_station.png`) the header wraps, the lens buttons clip, and the four blocks stack — the
  Phase-0 "phone-shaped" gate was a layout check, not a usable phone UI.
- **Layering**: the deck.gl overlay is added as a MapLibre control (`map.tsx:224`), so its canvas sits in
  MapLibre's control container above the map canvas; the section card, the timing panel and the legend are plain
  positioned `div`s with no `z-index`, so the line, the dots and the station markers paint *through* them (Ben's
  two screenshots). The legend (bottom-left) and the section card (bottom, full width) also occupy the same
  corner, and the ⚙ gear (bottom-right, 36 px up) collides with MapLibre's attribution ⓘ.
- **Vocabulary** (`App.tsx:448`): a `taxon | variable` segmented control drives `sel.realm` (`bio | env`), then
  `taxon` / `life stage` / `denominator` or `variable (79 in this release)`; `stat` = mean · median · **n rows**;
  `H3 res 3…7`; `layer`; `depth band 0–500 m (brush the strip)`; `⬇ download bundle · copy as SQL R Python`. The
  lens buttons are five plain words; the rail has no group headings except the `DENOMINATOR` `h4`.
- **Lists**: native `<select>`s. Taxa come from `sql/taxa.sql` `ORDER BY n DESC` and are **truncated to 400**
  (`App.tsx:145`) of the release's 1,212 (963 ichthyo, 124 farallon, 87 mesopelagic, 37 euphausiids, 33 zoodb,
  23 zooscan, 22 phyto, 6 cufes, 3 dungeness, 1 phyllosoma); env variables are the five unified ones first, then
  the rest by `n_obs` desc (`App.tsx:155`); section cruises `ORDER BY n_sta DESC` (`sql/section_cruises.sql`);
  the cruise lens list is chronological, newest first (`App.tsx:506`) — that one is fine. Option labels carry
  the count in parentheses; nothing shows "most vs least" except by reading numbers.
- **Year strip** (`charts.tsx::YearStrip`): Plotly, `dragmode: "select"`, `xaxis.fixedrange: true`, one bin per
  year from `sql/years.sql`; the brush sets `years=`; modes *rows* and *mean ± se*. No zoom, no month, no cruises.
  `sql/cruise.sql` already returns `t0`/`t1`/`n_sta`/`n`/`mean` per cruise of the slice (678 cruises in the bio
  realm), and every slice row carries `datetime`, `year`, `quarter` and `cruise_key`.
- **Help**: none — no about, no tour, no feedback. The URL is already the whole state (`src/state.ts`), and
  `?tour=off` already suppresses the opening morph, so the brand contract's screenshot rule holds.
- **What exists to borrow** (`db-viz-station/public/`): the "WHAT CALCOFI MEASURES" panel — `By Category |
  By Dataset` tabs, rows with counts that expand in place, click → select (`app.js:3045`); 12 categories in
  `CATEGORY_ORDER` with emoji in `CATEGORY_ICON` (`app.js:2268–2284`), classified by dataset (`DATASET_CATEGORY`)
  for bio and by a **keyword match on the variable name** (`contentKeywordGroup`) for env — the latter is the
  fragile part (it has had three false-positive fixes: `dic` in *Dictyochophyceae*, `par` in *Bonaparte's Gull*);
  a hand-rolled callout tour (`WALKTHROUGH_STEPS`, `app.js:4426`; ~200 lines of positioning) that auto-starts on
  the first visit and remembers dismissal in `localStorage`; a Google-Form feedback modal posted `no-cors`
  (`app.js:4374`; four text fields, **no attachment possible**); an About modal and two floating `?` / `ⓘ`
  buttons over the map. `db-viz-hex` uses `conductor` (shepherd.js under R) with two steps. `db-viz-station`'s
  own note: `html2canvas` throws on this CSS's `color-mix()`, so its PNG cards are drawn on `<canvas>`.
- **What the release already carries** (dev catalog cut from v2026.08.25): `dataset.category` + `dataset.color`
  (16 datasets → 10 categories: Physical Oceanography, Carbonate System, Meteorology & Sea State, Phytoplankton,
  Picoplankton & Bacteria, Zooplankton, Euphausiids (Krill), Fish Eggs & Larvae, Mesopelagic Fish, Seabirds &
  Marine Mammals); `taxon` with `rank`, `kingdom`/`phylum`/`class`/`order_taxon`/`family` (classes in the bio
  realm: Teleostei, Aves, Cephalopoda, Malacostraca, Mammalia, Copepoda …); `coverage.json` with `datasets[]`,
  `stations[]`, `years[]`, `variables[]` (per dataset × measurement type: `n_obs`, `n_roots`, year span, depth
  span) — **but no per-taxon entries and no category on env variables**. The station app's two env-only
  categories (Nutrients & Chemistry, Productivity & Pigments) exist nowhere in the release: they are variable-level,
  and `metadata/measurement_type.csv` has no `category` column (nor the `variable` crosswalk that
  `src/variables.ts` carries as a stopgap — same follow-up).
- **calcofi.org's icons** (`/data/oceanographic-data/`, `/data/marine-ecosystem-data/`, fetched 2026-08-29):
  inline SVGs, 512-px viewBox, black outline glyphs with a heavy ~2 px stroke: flask (Bottle), monitor-with-chart
  (CTD), pipe (Underway MET), a CO₂ cycle (DIC, POC/PON and TOC share it), dolphin (Marine Mammals), gull
  (Seabirds), egg cluster (Fish Eggs & Larvae), shrimp (Zooplankton *and* the Pelagic Invertebrate Collection),
  bacterium (Phytoplankton & Bacterioplankton), DNA (Genomics/eDNA), plus a raster `sun_arrows.png` for Primary
  Production. Ben: an example of the *kind* of thing, not a set to reuse — "nice, clean, consistent" is the bar.
- **The brand moved under this plan on 2026-08-29** (`CalCOFI.github.io@ef701ce`, docs `fe50c6a`, calcofi4db
  `ec7dcb7`, calcofi4r `795db73`, explore `554cfe2`): Ben asked for calcofi4py's theme picker on the explorer, and
  it was applied at the brand so every product changed at once — the toggle is now MDI `brightness-7` (a sun,
  while the page is dark) / `brightness-4` (a moon-in-sun, while light) fleet-wide. `theme.js iconize()` swaps
  the snippet's `🌓` for inline SVGs, `theme.css` exports the two masks as `--cc-icon-sun` / `--cc-icon-moon`,
  Quarto's (docs) and pkgdown's (the package sites) own toggles are dressed through those variables, and
  `brand/v1/README.md` gained a "Changes within v1" list. Two consequences for this plan: the fleet's one shared
  glyph is a **filled Material Design Icons** shape, which settles D15's idiom; and the explorer's header already
  renders brand SVGs inline with React owning the nodes (`App.tsx`), which is D16's pattern for the rest of the
  header cluster. Not switched: the Shiny apps' bslib `input_dark_mode()` (a web component theme.css cannot
  reach) — a calcofi4r follow-up outside this plan.

## The take

**Make the map the page and everything else a rail or a card that folds into a labelled pill — and never move the
layout in response to data.** The fluid feeling comes from three things: the map keeps its place and its size
unless *you* fold something; a folded panel is not gone but reduced to its state ("Depth 0–500 m", "Years
1949–2026", "Biology · Pacific sardine · larva · per 10 m²"), so the picture stays legible; and every panel change
is a 250 ms transition that reads as a response to your click. A layout that rearranges itself because the taxon
you picked has no depth axis is the opposite of fluid: you changed one thing and the room moved. The right response
to "no depth for this selection" is an honest empty state in the panel and a muted pill if it is folded — *signal,
don't move.* A generic window manager (dockview, golden-layout, react-mosaic) is the wrong tool: it turns a
map product into a workbench, costs 100–150 KB, fights touch, and makes every drag position state to persist.
Three rails with collapse/maximize/resize, plus floating cards for lens results, cover what the four apps' users
actually do, with one short URL parameter. The same rail/pill system *is* the phone layout (a bottom sheet and
edge pills), which is why the phone ships with it rather than after it.

On the words: **Biology · Environment**, because they are parallel nouns, match the schema's `realm = bio | env`
and calcofi.org's own split (*Marine Ecosystem Data* / *Oceanographic Data*), and do not lie the way "species"
(most picks are genera or families) or "ocean" (METS is weather) would. Inside them, *organism* and *variable*.
Group labels on the rail help — **Lens** and **Data** — and icons on the lens buttons help more than on anything
else, because a lens is a *shape* (dots, hexagon, track, polygon, curtain) and a glyph says it faster than a word.
Not "Measurement" for the second group: in this database a measurement is a value of a `measurement_type`, and a
taxon is not one; the word would collide with the schema, the docs and the bundle.

On the lists: alphabetical is the right default for finding, but counts are the right thing to *see* — so show the
count as a small proportional bar on every row (log-scaled, since counts run 1 → 480 k) and offer the sort as a
toggle. Then "which has the most / least" is visible in any order without a number being read.

On browsing: the station app's inventory is the best discovery surface in the fleet and it is built from exactly
the file the explorer already fetches before the engine is warm (`coverage.json`). Port it as a **Browse** tab
beside search, driven by registries rather than keyword matching, and it doubles as Task 14's inventory.

On the year strip: keep the brush as the filter and make zoom a *separate* gesture (wheel, pinch, double-click,
a *zoom to selection* handle) with a context bar for panning; let zoom *earn* detail — month bins under fifteen
years, cruise codes when a bar is wide enough. A cruise Gantt is readable when the lanes are ships: no two cruises
of one ship overlap, so the lanes never collide and the chart doubles as the cruise picker.

On help and feedback: a header cluster (`? ⓘ 💬 🌓`), a one-paragraph welcome on first visit (not an auto-started
ten-step tour), `driver.js` for the tour, and a feedback dialog whose screenshot is composited in the browser from
the map's WebGL canvases, the Plotly panels and the DOM, then annotated on a small canvas and posted to an Apps
Script endpoint — the same pattern as the usage log, with a Drive folder for the images and a public issue in
`CalCOFI/explore`. The view URL rides along in every submission, so "that spike" is reproducible by anyone who
opens the link. Every figure exports on its own, too — the same footer stamp on all of them.

## Decisions

### D11 · Panels → three docked rails that fold into state pills, floating cards for lens results, no data-driven re-layout, one stacking order

**Rails** (dock to the map's edges; push the map, never overlay it, at ≥ 1100 px):

| rail | side | content | folded pill shows |
|---|---|---|---|
| `select` | left, 320 px (resizable 260–440) | LENS · DATA · FILTERS · EXPORT groups (D12) | `⁚⁚ 🐟 Pacific sardine · larva · per 10 m² · ichthyo` (vertical text; lens + realm glyphs on top) |
| `depth` | right, 210 px | water-column strip (brush) | `Depth 0–500 m` — or `Depth · integrated tows` when the cut has no axis |
| `years` | bottom, 140 px | year strip (brush, zoom; D20) + mode toggle | `Years 1949–2026 ▂▃▅▇▅▃` (a 60-px sparkline of the histogram) |

Each rail header has **▸ fold**, **⤢ maximize** (the panel takes the map's box with a backdrop; ⤡ or `Esc`
restores — the year strip maximized becomes a proper time-series view with the se band, the depth strip a wide
profile with per-dataset lines), **⬇ export** (D19), and the left rail a drag gutter to resize. Folding animates
`grid-template-columns` / `-rows` (animatable in every current browser when the track count is constant) over
250 ms; `prefers-reduced-motion` disables it as the morph already does.

**Floating cards** (over the map, as the section and cruise panels already are): `section`, `cruise` series,
`station` coverage card (moves out of the left rail — it is a *map click result*, and today it pushes the export
row off-screen), `timing` (SQL & timing, opened from EXPORT — D12), and later Hovmöller. Cards have a title bar
with **▁ minimize** (to a pill in the map's top-left pill row: `st90-ln90 ×`), **⤢ maximize**, **⬇ export**, **×
close**, and are draggable within the map box (a 40-line pointer handler; no library). Positions and sizes are
**not** URL state — they live in `localStorage` per card and reset on a viewport change.

**Rules that make it feel stable:**

1. **Layout changes only on: a user's fold/maximize/drag, a lens change, or a breakpoint.** A selection change
   (organism, variable, years, depth, dataset pills) never opens, closes or resizes a panel. When the depth axis
   disappears (ichthyo has no tow depth in the release — Q08 filed), the depth rail shows its empty state
   ("Depth-integrated net tows — no water-column profile for this selection; the tow span will draw here once the
   release carries it") and, if folded, the pill reads `Depth · integrated tows` in the muted colour. When an axis
   *appears* (switching to Environment with the rail folded), the pill gets a single 600 ms highlight pulse.
2. **A lens owns its cards.** Sections opens the section card and closes the cruise card; Cruises the reverse;
   Stations/Hexagons/Regions open none. That is a mode change the user asked for, so it may move things — with the
   same 250 ms transition.
3. **Defaults by viewport, once per visit**: ≥ 1200 px all rails open; 900–1200 px the depth rail folded; < 900 px
   the phone layout (D18). `?tour=off` screenshots therefore show the defaults, and the brand checker keeps passing.
4. **URL carries folds and maximize, nothing else**: `hide=depth,years` · `max=section`. Two parameters, absent
   when default, so existing links are unchanged.
5. **DOM overlays always stack above the map's canvases** — the fix for both screenshots. One stacking scale in
   `style.css`, used by every overlay, nothing positioned without a level:

   | level | z | what |
   |---|---:|---|
   | map canvases | 0–2 | MapLibre + the deck.gl control, as MapLibre sets them |
   | map chrome | 5 | MapLibre navigation + attribution |
   | pills · legend · status | 10 | the map's own chrome |
   | floating cards | 20 (+1 for the card last touched) | section · cruise · station · timing |
   | maximized panel + backdrop | 30 | |
   | modals (welcome · about · feedback) | 40 | |
   | tour overlay | 50 | driver.js |

   And placement: the **legend moves to the map's top-left** under the pill row (today it is bottom-left, exactly
   where the section card lands, and shows through it); cards default to the bottom of the map box and **may not
   cover the legend, the attribution or each other by default**; the ⚙ gear leaves the map — *SQL & timing* is a
   card opened from **EXPORT → SQL & timing** (`?timing=1` still opens it), so the map's bottom-right belongs to
   MapLibre's attribution alone.

`src/panels.tsx`: `<Rail id side title summary folded onFold maximizable resizable exportable>` and `<FloatCard id
title minimized onMinimize draggable exportable>`; `src/state.ts` gains `hide: PanelId[]` and `max: PanelId | null`;
`src/style.css` `.main { grid-template-columns: var(--l) 1fr var(--r); grid-template-rows: 1fr var(--b) }` with a
folded track of 28 px and the z scale as custom properties. Pills are `<button aria-expanded>`; a maximized panel
traps focus and `Esc` restores.

### D12 · Names → **Biology · Environment**; *organism* and *variable* beneath them; group labels **Lens · Data · Filters · Export** with icons on the lens buttons; a wording pass on the rest

The left rail's skeleton (Ben's item 10, with one change of word):

```
LENS      [⁚⁚ Stations] [⬡ Hexagons] [⛵ Cruises] [▱ Regions] [⫼ Sections]
          hexagon size · boundary layer · line + cruise   ← only the row the chosen lens needs, right under it
DATA      [🐟 Biology] [🌊 Environment]
          organism ▾ · life stage ▾ · denominator · dataset pills · observations in view
FILTERS   years 1949–2026 · season · depth 0–500 m · datasets     ← state chips; the rails are where you brush
EXPORT    [Download data] [Copy code ▾] [Share ▾] · SQL & timing
```

- **Icons on the lens buttons, yes** — with the word kept: a dot grid (Stations), a hexagon (Hexagons), a ship
  on a track (Cruises), a polygon outline (Regions), a vertical curtain (Sections). A lens is a spatial shape, so
  a glyph communicates it faster than a noun, and the same five glyphs mark the header subtitle, the folded pill
  and the tour. Icons on the realm toggle, yes (fish · waves). Icons on *organism* / *variable* fields, no —
  they are inputs, not choices.
- **"Data", not "Measurement"**, for the second group. Everything under it answers *which data*: the realm, the
  organism or variable, the life stage, the denominator, the dataset pills. "Measurement" would be wrong twice:
  a taxon is not a measurement (its abundance is), and the word already has a precise meaning in this database
  (`measurement_type`, `measurement_value`, `sample_measurement`) that the schema site, the docs and the bundle's
  `data/reference/measurement_type.csv` all use. Runner-up: "Subject".
- **A lens's options live under the lens**, not in a separate group below the picker: choose Hexagons and the
  size row appears beneath the lens buttons; Regions the boundary layer; Sections the line and cruise. Options
  sit beside the thing they modify.

| today | proposed | why |
|---|---|---|
| `taxon` \| `variable` toggle | **🐟 Biology** \| **🌊 Environment** (icons from D15) | parallel nouns; = `realm`; = calcofi.org's split; "species"/"ocean" would be wrong for genera and weather |
| `taxon` (field) | **organism** — placeholder *search species, genus, family…*; "taxon" stays in the tooltip, the bundle and the URL (`?taxon=`) | plain word first, precise word available |
| `variable (79 in this release)` | **variable** — the count moves into the list header | |
| `life stage` · `denominator` | keep (`denominator` gets the hint *how counts are standardized*) | D8 vocabulary; the packages use it |
| `stat` mean · median · **n rows** | **summary** mean · median · **observations** | "rows" is database-speak; the legend, status chip and pills say *observations* too |
| `H3 res 3 4 5 6 7` | **hexagon size** ~60 · ~23 · ~8.5 · ~3.2 · ~1.2 km (H3 mean edge length; `res` stays in the URL) | nobody outside the team knows H3 resolutions |
| `layer` | **boundary layer** | |
| `depth band 0–500 m (brush the strip)` | a FILTERS state chip that links to the depth rail | one place to brush, one place to read |
| `⬇ download bundle` · `copy as SQL R Python` · ⚙ | **Download data (zip)** · **Copy code ▾** SQL / R / Python · **Share ▾** copy link / copy image / download PNG / send feedback · **SQL & timing** | one EXPORT group; adds share (D17); the gear comes off the map (D11) |
| lens subtitles | keep; they are Erin's ask from the renames thread | |

The URL does not change (`taxon`, `var`, `stat`, `res`, `layer` stay), so every link and bundle stays valid.

### D13 · Lists → one searchable combobox: A→Z by default, counts as bars, sort and group as toggles

Replace the native `<select>`s for organism, variable and cruise with one **combobox** (`src/picker.tsx`, WAI-ARIA
combobox/listbox pattern; headless — hand-rolled or `downshift`, no styled dependency):

- **Rows**: display name (organism: *common name — scientific* in italics; variable: description + units;
  cruise: key + ship + dates), a right-aligned **count with a proportional bar** (log scale, labelled once in the
  header as "observations, log scale"), and dataset colour dots (from `dataset.color`). The bar is what makes
  most/least visible in any order.
- **Sort key** for organisms = display name = common name when present, otherwise scientific name (the station
  app's `sortKey`, which also ignores leading articles); search matches both and, later, synonyms. Variables sort
  by description. Cruises **stay chronological, newest first** — a `YYYY-MM-NODC` key sorts that way by itself and
  it is what a cruise list should do; the section's cruise list changes from `n_sta DESC` to the same, with
  `n_sta` as its bar. (D20's Gantt becomes the visual cruise picker; the combobox stays for search.)
- **Header controls**: search box (typeahead, focus on open, `↑↓ Enter Esc`), **sort** `A–Z · most observations ·
  most recent`, **group** `none · category · dataset` (organisms also `class`: Teleostei, Aves, Mammalia,
  Cephalopoda, Malacostraca, Copepoda — from `taxon.class`). Env defaults to **grouped by category** — 84 names
  with `_ave_sta_corr` suffixes are not browsable flat, and the five unified variables land at the top of
  *Physical Oceanography* by name instead of by fiat. Bio defaults to flat A–Z with a letter jump strip.
- **Untruncated**: all 1,212 taxa render (a lazily mounted list; 1.2 k rows is fine without virtualization).
- **Before the engine is warm** the list still opens: counts and year spans come from `coverage.json` (D14 adds
  `taxa[]`); `taxa.sql`'s counts replace them when the slice answers. Today the organism list is empty until
  `obs_bio` (21.8 MB) has downloaded — on a cold visit that is ~6 s of a dead control.
- On phones the combobox opens as a full-screen sheet (D18).

### D14 · Browse → a *Browse* tab beside *Search* — by category or by dataset — from `coverage.json` and three registries

The same popover has two tabs. **Browse** is the station app's inventory generalized: a tree with counts, year
spans and dataset dots, click → select, no engine needed.

```
By category                         By dataset
🌊 Physical Oceanography   41 vars   ● Hydrographic Bottle     1949–2021  22 vars
   Temperature  bottle+CTD 1949–2026 ● CTD Cast Files          1993–2026  31 vars
   Salinity …                        ● Ichthyoplankton         1951–2025  963 organisms
🧪 Nutrients & Chemistry   13 vars   ● CUFES Fish Eggs         1996–2024  6 organisms
🐟 Fish Eggs & Larvae     969 orgs   …
   Pacific sardine — S. sagax  ichthyo · CUFES  1951–2025
```

Where the vocabulary lives — three small registry changes, so the app classifies nothing by keyword:

- **`metadata/category.csv`** (new; `category, order, icon, description, realm_default`): the single list of
  categories, lint-enforced the way `provider.csv` is (`build_workflows_index.R` errors on an ingest `category:`
  that is not registered; today the YAML strings are free text). 12 rows: the release's 10 plus *Nutrients &
  Chemistry* and *Productivity & Pigments*.
- **`metadata/measurement_type.csv`** gains **`category`** (env variables: Physical Oceanography · Nutrients &
  Chemistry · Carbonate System · Productivity & Pigments · Meteorology & Sea State) and **`variable`** (the
  bottle/CTD crosswalk `src/variables.ts` carries today — the 2026-08-29 follow-up in the parent plan). Read and
  written through `read_measurement_type()` / `declare_*()`, never bare `write_csv`.
- **`coverage.json`** (`calcofi4db::build_coverage()`): `variables[].category` and `.variable`, and a new
  **`taxa[]`** — one row per taxon: `taxon_key`, names, `class`, `datasets[]` (with `n_obs` each), year span,
  `life_stages[]` (~1,212 rows ≈ 100 KB, gzipped ~25 KB). This is also what makes D13's pre-warm list possible and
  what Task 14's "variable-based inventory" needs.
- Bio category = the dataset's `category`; a taxon in two datasets lists under both with per-dataset counts (as the
  station app does), and the `class` grouping is the taxonomic alternative.

Until the next release ships those columns, `src/categories.ts` ports the station app's `contentKeywordGroup()`
verbatim as the stopgap, with a comment naming the registry that replaces it, and the Browse tab reads it.

### D15 · Icons → a brand set in the toggle's idiom (Material Design Icons, filled, `currentColor`): one per category, per lens, per header and panel action; a sprite for React, CSS masks for everyone else; no dataset icons

- **The fleet already has one shared glyph, and it set the style.** Since 2026-08-29 the theme toggle is MDI
  `brightness-7` / `brightness-4` on every product — a filled 24-px Material Design Icons glyph drawn in
  `currentColor`, the family mkdocs-material (calcofi4py) is built on. A Lucide-style 1.75-px stroke set beside it
  would be a second idiom in the same header. So the category, lens and action icons follow the toggle: **MDI
  (Pictogrammers, Apache-2.0), the `-outline` variants where MDI offers them, on the 24-px grid, `fill:
  currentColor`**, with the bespoke marine glyphs drawn to that weight.
- **Delivery, both ways the toggle proved.** `brand/v1/icons/calcofi-icons.svg` — a sprite of `<symbol
  id="cat-…|lens-…|ui-…">` for `<use href>` and the React `<Icon name>` — and `brand/v1/icons.css`, exporting
  each glyph as a mask custom property (`--cc-icon-cat-fish` …) exactly as `theme.css` exports `--cc-icon-sun` /
  `--cc-icon-moon`, so db-viz-station, the calcofi.io cards, Quarto and pkgdown pages wear them with CSS alone.
  Listed in the README's "Changes within v1" (additive: no existing page changes).
- **Source.** MDI for what it has — thermometer / waves (Physical Oceanography), flask-outline (Nutrients &
  Chemistry), molecule-co2 (Carbonate System), white-balance-sunny + leaf (Productivity & Pigments),
  weather-partly-cloudy / weather-windy (Meteorology & Sea State), bacteria-outline (Picoplankton & Bacteria),
  egg-outline (Fish Eggs & Larvae), fish (Mesopelagic Fish), bird (Seabirds & Marine Mammals); dots-grid
  (Stations), hexagon-outline (Hexagons), vector-polygon (Regions); help-circle-outline, information-outline,
  message-text-outline, download, arrow-expand / arrow-collapse, chevron-*, close, cog-outline,
  share-variant-outline (the header and panel actions) — names confirmed against the MDI index when the sprite is
  built — and **bespoke, in the same weight**: diatom (Phytoplankton), copepod (Zooplankton), krill
  (Euphausiids), a fish larva beside the egg, a whale beside the gull, a ship on a dotted track (Cruises), a
  curtain (Sections). Checked side by side at 16 px before shipping; nothing copied from calcofi.org.
- **Where they show**: lens buttons, the Biology/Environment toggle, Browse headers, the folded select-rail
  pill, the legend title, the header subtitle, the About modal's dataset list, the calcofi.io cards, and — a
  one-file PR — `db-viz-station`'s `CATEGORY_ICON`, replacing the emoji so the two apps match. The header
  cluster and every rail/card action (▸ ⤢ ⬇ ×) use one **`.cc-icon-button`** style: the toggle's 2 rem flat
  button generalized, an additive class in `theme.css`.
- **Datasets** keep their `color` dot + `dataset_name_short`; no icons (agreed).

### D16 · Help → a header cluster help · about · feedback · theme; a welcome card on first visit; `driver.js` for the tour

- **Header, not floating buttons**: the explorer's `.cc-header` has room; floating `?`/`ⓘ` over the map
  (station app) collide with the legend and the attribution. Order at the right: `query · schema · docs` links,
  then **help** (the tour), **about**, **feedback** and the **theme toggle** — four `.cc-icon-button`s in the
  toggle's style (2 rem, flat, hover tint) with MDI glyphs (`help-circle-outline`, `information-outline`,
  `message-text-outline`, and the sun / moon-in-sun the brand already draws). The toggle is no longer the app's
  to draw: since `554cfe2` it renders brand v1's pair inline and theme.js only refreshes its title — the same
  pattern for the other three. On phones the links fold behind `⋯`.
- **First visit** (`localStorage.explore_welcome = 1` absent, `tour ≠ off`): a **welcome card** — one paragraph
  (one database, one frozen release, pick an organism or a variable, watch the grid regroup), **Take the tour** ·
  **Explore**. Not an auto-started multi-step tour: returning users on a new device, screenshot bots and the
  opening morph all argue against it. `?tour=on` forces the card for demos.
- **Tour**: `driver.js` (MIT, ~6 KB gz, no dependencies, overlay cut-out, keyboard, responsive) instead of another
  hand-rolled callout. Steps in `src/tour.ts`, anchored on `data-tour="…"` attributes (stable, independent of
  class names), with `before()` hooks that put the app in the state a step needs — the station app's pattern —
  e.g. the Lenses step plays the morph, the Sections step switches lens and switches back on exit, the Depth step
  unfolds the rail if it is folded. Ten steps (Appendix B). `prefers-reduced-motion` skips the morph step's
  animation.
- **About** (`ⓘ`): what it is; the release chip and *why one frozen release*; the datasets with category icons,
  provider and citation links (from `dataset`); credits; keyboard shortcuts; "better on a computer" (allowed —
  Ben — as long as nothing fails on a phone, D18); links to docs/schema/query. Shares the modal component with
  feedback.

### D17 · Share & feedback → the URL is the permalink; a composited screenshot; annotations on a canvas; an Apps Script endpoint with an editable recipient list and a public issue

**Share ▾** (in EXPORT and in the `💬` dialog): *Copy link* (the URL, folds and zoom included), *Copy image*,
*Download PNG* — the image is a **clean figure** of the whole view: the map + open panels with the pills and
status chip hidden and a footer baked in (legend title, release version, `© CARTO © OpenStreetMap`, the URL).
Slides and emails get provenance for free, and it is the same capture the feedback uses; per-panel figures are
D19.

**Capture pipeline** (`src/capture.ts`), in this order onto one canvas at `devicePixelRatio` (cap 2):

1. **Map**: MapLibre's WebGL canvas needs `preserveDrawingBuffer: true` (set in `MapView`; negligible cost) for
   `toDataURL`/`drawImage`; deck.gl's `MapboxOverlay` is `interleaved: false` (`map.tsx:220`), so its own canvas
   is drawn on top — or switch to `interleaved: true` and capture one canvas (decide in the spike).
2. **Plotly panels**: `Plotly.toImage(div, { format: "png", scale })` per open panel, drawn into place.
3. **DOM** (rails, legend, pills, header chip): `html-to-image` (`toCanvas`, MIT, ~12 KB) — it serializes to an
   SVG `<foreignObject>` and rasterizes in the browser's own engine, so `color-mix()` works (the thing that broke
   `html2canvas` in the station app); the brand logo `<img>` from calcofi.io is fetched as a blob first so it
   does not taint the canvas, and Google Fonts answer CORS.
4. Footer text drawn last (`src/export.ts`, shared with D19). Total ~1–2 MB PNG; downscale to ≤ 3 MB for the
   upload.

The **Screen Capture API** (`getDisplayMedia({ preferCurrentTab: true })`, one frame) is the pixel-exact
alternative with no compositing — at the price of a permission prompt and no iOS — kept as a "capture exactly what
I see" fallback only if the spike shows compositing gaps.

**Annotate** (`src/annotate.tsx`): the screenshot in a canvas with **arrow · circle · rectangle · pen · text**,
two colours (accent, warn yellow — both read on dark and light maps), undo, clear. Hand-rolled (~250 lines: a
shapes array, pointer events, redraw); marker.js is commercial, fabric is 300 KB, tldraw is an app. Touch works
(pointer events), which matters now that the phone is in scope.

**Feedback dialog** (`💬`): *What happened / what did you expect?* (one textarea), *email (optional)*, the
annotated screenshot with *edit* / *retake*, a checkbox *include screenshot* (on), and a plain sentence saying what
is sent (the text, the view URL, release, viewport, theme, the image — nothing else) and where it lands (a Sheet the
team reads, and a public issue on GitHub *without your email*). Buttons: **Send** · **Open as GitHub issue
myself** (secondary, for developers: `issues/new?title&body` prefilled with the URL, the image copied to the
clipboard to paste — zero backend, needs a GitHub account).

**Endpoint** — the usage-log pattern (`calcofi4r::cc_apps_script()`, `POST text/plain` JSON so the request stays
CORS-simple, a `GET` health check): a sibling **`cc_feedback_script()`** generating `Code.gs` for a web app bound
to a *CalCOFI app feedback* Sheet that, per submission:

1. writes the PNG to a Drive folder *CalCOFI app feedback/<app>/<ts>_<id>.png*;
2. appends a row to the Sheet's `feedback` tab (`ts, app, url, release, viewport, theme, text, email, image_url,
   issue_url, id`);
3. mails every address in the Sheet's **`recipients`** tab — one per row, Ben, Erin and Betty to start; **add or
   remove an address by editing a cell, no redeploy** — with the text, the URL, the image link and the issue link;
4. files a **public issue in `CalCOFI/explore`** (label `feedback`; title from the first line of the text; body =
   the view URL, the text, the release/viewport line, and the screenshot committed under `feedback/<id>.png` via
   the contents API so the issue can embed it — **never the email**, which stays in the Sheet). A `GITHUB_TOKEN`
   script property (fine-grained, `contents` + `issues` on that one repo) enables it; without it the script skips
   the step and the row says so.

Honeypot field + a per-hour cap in the script against spam; Apps Script's 50 MB POST limit and 100–1,500
mails/day are far above need. The Shiny apps can reuse the same script later (`cc_feedback_ui()`), which is why it
lives in `calcofi4r` beside the log script.

**Tracked**: `share`, `export` and `feedback` events through the existing GA4 leg (`content_group: explore`).

### D18 · Phone → ships with U1: map full-bleed, the select rail as a bottom sheet, strips as pills, a real-device gate

Ben: the phone very much matters; the About modal may say "better on a computer", but the app must not *fail* on a
phone — and today it does (`shots/dev2/phone_station.png`: the header wraps, the lens buttons clip, four blocks
stack). The rail/pill system *is* the phone layout, so it ships in the same slice:

- < 900 px: the map fills the viewport; the select rail becomes a **bottom sheet** with three detents (a peek row
  showing the selection pill and the lens strip · half · full); the depth and year rails are pills on the map's
  bottom edge that open as sheets; cards open as sheets; the combobox and Browse open full-screen; the header
  keeps logo, title, release chip and `? 🌓`, the rest behind `⋯`.
- Touch: sheet drag with pointer events and `touch-action: none` on the handle; deck picking on tap with a larger
  pick radius; the year strip's pinch-zoom (D20) and the annotator (D17) are pointer-event based already.
- **Gate**: `verify.mjs` at 390 × 844 asserts no horizontal overflow, every control reachable, the sheet's three
  detents and a lens switch; and a **real phone over the LAN** (`vite preview --host`) before 9/8 — the emulated
  viewport is a layout check, not a phone.

### D19 · Figures → every panel exports as PNG · SVG · CSV from its header, with the selection and release baked in

Every Plotly panel (year strip, water column, section, cruise series, later Hovmöller) and every card gets **⬇**
in its header (D11): **PNG** (`Plotly.toImage`, 2× scale, the panel's theme background — not transparent — and a
footer line with the selection, the unit, the release and `calcofi.io/explore` + the view URL), **SVG** (vector,
for papers; Plotly emits it natively), **CSV** (the panel's own table: `years.sql` / `depth_strip.sql` / section
cells / cruise rows — the same tables the bundle already writes). The station card, being several mini plots,
exports as PNG via the D17 DOM capture. A maximized panel exports at its larger size. `src/export.ts` holds the
footer stamp so the whole-view figure (D17) and the panel figures match. Filenames:
`calcofi_explore_<panel>_<lens>_<release>_<yyyymmdd>.<ext>`.

### D20 · Year strip → zoom in and out, month detail when zoomed, a *cruises* mode as a ship-lane Gantt whose labels appear on zoom

Three behaviours, kept apart so the gestures do not fight:

- **Filter = brush** (as now; the URL's `years=`). **Zoom = wheel / pinch on the x-axis**, **double-click =
  reset**, and a **⤢ *zoom to selection*** handle on the brush rectangle (with ✕ *clear*), so the common move —
  brush a decade, then look closer — is one click. When zoomed, a thin **context bar** under the axis shows the
  full 1949–2026 span with the window highlighted; drag it to pan. `yaxis.fixedrange` stays; `xaxis.fixedrange`
  becomes false with `scrollZoom`. The view window is URL state (`yview=2005-2012`) so a shared link or a feedback
  screenshot shows the same zoom; zooming never touches the filter.
- **Level of detail**: bins are **years** when the window is > 15 years, **months** at ≤ 15 years (`years.sql`
  gains `{{bin}}` = `year` | `(year, month(datetime))`; the slice has `datetime`), so zooming in reveals
  seasonality instead of fatter bars. A brush made at month resolution filters by month too — the URL form extends
  to `years=2015-04:2016-10` and `_filters.sql` compares `year*100 + month(datetime)`; the `season` chip in FILTERS
  (quarter pills, `q=`) is the cheap sibling for "spring cruises only".
- **Cruises mode** (third toggle, beside *rows* and *mean ± se*): a Gantt where each cruise is a bar from `t0` to
  `t1` (`cruise.sql` already returns them per slice), in **lanes by ship** (the NODC code in the key, the name
  from the `cruise`/`ship` reference; no two cruises of one ship overlap, so lanes never collide, and the lane
  order is the fleet's history — Jordan, New Horizon, Bell Shimada, Reuben Lasker, Sally Ride …), coloured by the
  summary stat, `n` as opacity. **Codes appear only when a bar is ≥ ~40 px wide** (zoom in; at full range it is a
  dense timeline that still reads), hover gives key · dates · stations · observations, and **click selects the
  cruise** — which makes the strip the cruise picker for the Cruises and Sections lenses, with the combobox kept
  for search. That is what keeps it from being busy: lanes stop overlap, zoom controls density, labels are earned.
  An optional fourth mode, **season** (12 month bins over all years, the station card's seasonality), is one
  `GROUP BY` and waits for a request.

## Architecture (what changes in `explore`)

```
src/state.ts      Sel += hide: PanelId[] · max: PanelId | null · yview · q  (URL: hide= max= yview= q=)
src/panels.tsx    Rail, FloatCard, PillRow, useDrag, useResize, Sheet (phone)  (D11, D18)
src/picker.tsx    Combobox: search | browse tabs, sort/group, bars             (D13, D14)
src/categories.ts category registry client + keyword stopgap                   (D14; deleted when the release carries category)
src/icons.tsx     <Icon name/> over the brand sprite (cat-*, lens-*, ui-*)     (D15)
src/help.tsx      Welcome, About, Modal                                        (D16)
src/tour.ts       driver.js steps + before() hooks                             (D16)
src/capture.ts    composite → PNG of the whole view                            (D17)
src/export.ts     footer stamp; PNG/SVG/CSV per panel; filenames               (D17, D19)
src/annotate.tsx  canvas annotator                                             (D17)
src/feedback.tsx  Share menu, Feedback dialog, POST to the endpoint            (D17)
src/charts.tsx    YearStrip: zoom, context bar, month LOD, cruise lanes        (D20)
sql/years.sql     {{bin}} year | month; cruise.sql feeds the Gantt             (D20)
src/style.css     the z-index scale; rail tracks as custom properties          (D11)
src/App.tsx       shrinks to composition; the left rail = LENS · DATA · FILTERS · EXPORT (D12)
```

New dependencies: `driver.js`, `html-to-image` (and `downshift` only if the hand-rolled combobox is not worth it).
Nothing for the rails, cards, sheet, drag, annotator or Gantt. Bundle impact < 25 KB gz.

Registry/pipeline changes (workflows + calcofi4db, one PR each): `metadata/category.csv` + the
`build_workflows_index.R` check; `measurement_type.csv` `category` + `variable`; `build_coverage()` `taxa[]` and
the two variable fields (+ tests); `RELEASES.md § Unreleased` ("coverage.json carries taxa and categories").
Brand: `brand/v1/icons/calcofi-icons.svg` + README. calcofi4r: `cc_feedback_script()` (+ test). db-viz-station:
swap `CATEGORY_ICON` to the sprite.

`scripts/verify.mjs` grows four checks: every panel state screenshots without overflow (fold/maximize each rail,
the phone sheet's detents at 390 × 844); the exported PNGs (whole view and one panel) are not blank (mean luminance
≠ background — catches a lost `preserveDrawingBuffer`); every tour step's selector resolves in the state its
`before()` produces; the year strip's zoom round-trips through `yview=`.

## Phases (each shippable on its own)

| slice | what ships | ~h |
|---|---|---:|
| **U0 · Words + lists** | D12 wording, group labels and lens icons (emoji placeholders until D15's sprite); the combobox with A–Z default, search, count bars, sort toggle, all 1,212 taxa; cruises chronological in both lists; hexagon sizes in km | 8 |
| **U1 · Rails, cards, z-order, phone** | D11: three rails with fold-to-pill, maximize, resize; station and timing become floating cards; cards minimize/drag; the z-index scale + legend/gear placement (the two layering bugs); `hide=`/`max=` in the URL; viewport defaults; reduced motion; D18 bottom sheet + pills with the device gate; verify screenshots per state | 26 |
| **U3 · Help** | D16: header cluster, welcome card, About modal, `driver.js` tour with ten anchored steps, `?tour=on|off` | 8 |
| **U6 · Year strip** | D20: wheel/pinch zoom, double-click reset, zoom-to-selection handle, context bar, `yview=`; month LOD + month filter + season chip; cruises Gantt by ship lane as the visual cruise picker | 12 |
| **U4a · Share + figures** | D17 capture spike (2 h, decides interleaved vs composite) → whole-view PNG, copy link/image; D19 per-panel PNG/SVG/CSV with the shared footer | 10 |
| **U4b · Feedback** | annotator, feedback dialog, `cc_feedback_script()` + deployment (Drive, Sheet with `recipients` tab, mail, public issue in `CalCOFI/explore`), tracking | 14 |
| **U2 · Browse + registries + icons** | D14 `category.csv` + `measurement_type.csv` columns + `build_coverage()` `taxa[]` (6 h, Integrate); Browse tab (6 h); D15 sprite + `icons.css` masks — MDI base + bespoke category, lens and action glyphs, `<Icon>`, `.cc-icon-button`, the station-app swap (8 h) | 20 |
| | **total** | **98** |

**Order**: U0 → U1 → U3 for 9/3 (42 h; a checkpoint, not a deadline — if the week runs short, U1's phone half
is the part to keep, since Ben ranked it first) → U6 → U4a → U4b for 9/8 → U2 (its registry half needs a release to
reach `coverage.json`, so it is the one slice with an external clock). The parent plan's Phase 5 (15 h) is absorbed
by U1/U3; the SoW Visualize line (113 h) now holds Phases 3–4 (50 h) + this (98 h), so if hours must go: the
season mode is already out, then the bespoke redraw (use MDI's nearest everywhere), then the SVG/CSV halves of
D19, then the GitHub-issue step of U4b.

### Measured (appended per slice as it ships)

- **U0 · shipped 2026-08-29, `explore@31388d5`.** D12 wording + groups (LENS · DATA · FILTERS · EXPORT, Biology ·
  Environment, organism / variable / summary / hexagon size / boundary layer, "rows" → "observations" in every label,
  tooltip and hint); lens + realm glyphs are `@mdi/js` paths rendered inline (`src/icons.tsx`, keyed by the sprite ids
  D15 names, so U2's sprite is a swap) rather than the emoji placeholders the row allowed; `mdiShip` does not exist, so
  Cruises wears a bespoke ship-on-track glyph and Sections a bespoke curtain from day one. D13 combobox
  (`src/picker.tsx`, hand-rolled, 190 lines): 1,212 organisms (was 400), search + ↑↓ Home End PageUp/Down Enter Esc,
  A–Z · most observations · most recent, group none · category · dataset · class, letter strip, log-scaled bars +
  dataset dots, `?native=1` fallback; the env list (79 variables) opens from `coverage.json` before the engine is
  warm and is grouped by category by default (the five unified variables sit in *Physical Oceanography* by name);
  the organism list still waits on `obs_bio` — `coverage.json` carries no `taxa[]` until U2's registry half.
  Cruise lists newest first in both lenses (the section's default cruise stays the one with most stations, so
  existing links draw the same section). Popovers and menus are `position: fixed` from the anchor's rect
  (`useAnchor`) because the rail's `overflow: auto` clipped the first version. Found on the way: 1,317 `obs_bio` rows
  have a NULL `taxon_key` — dropped from the list (they never matched a selection anyway). Verified: `npm run build`
  clean; `scripts/verify.mjs --only=u0` — 12 states at 1280 × 800, no overflow, every control in view, no page
  errors (`shots/u0/`).
- **U1 · shipped 2026-08-29, `explore@5a9d50a`.** D11 as specified: `src/panels.tsx` (Rail · MaxPanel · FloatCard ·
  PillRow · Sheet · Sparkline, 210 lines, no library); the three rails fold to state pills ("⁚⁚ 🐟 Pacific sardine ·
  larva · per 10 m²" vertical, "Depth 0–500 m" / "Depth · integrated tows" muted, "Years 1949–2026" + a 60-px
  sparkline), maximize with a backdrop + Esc (the years strip as a full-width series; the depth strip as a wide
  profile with one dotted median line per dataset from the new `depth_strip_ds.sql`), and the select rail resizes
  260–440 px on a gutter (localStorage). Station coverage and SQL & timing left the rail and the map's corner for
  floating cards; cards minimize to the map's top-left pill row, drag within the map box (position in localStorage
  per card, reset on a viewport change), and default to slots that cover neither the legend (moved top-left) nor
  the attribution; the ⚙ is gone. `hide=` / `max=` in the URL, written only when they differ from the viewport
  default (≥ 1200 px all open; 900–1200 depth folded — verified at 1000 × 700). The two layering bugs are fixed by
  one rule — `.map { z-index: 0 }` makes the map a stacking context, so MapLibre's z:2 control container (where the
  deck.gl canvas also lives) can never paint above a card — plus the scale in `:root` (`--z-pills 10 · --z-cards 20 ·
  --z-max 30 · --z-menu 35 · --z-modal 40 · --z-tour 50`). Depth-axis rule 1: the rail shows the honest sentence,
  the folded pill goes muted, and an axis *appearing* while folded pulses the pill once; nothing moves. Two things the
  plan did not know: Plotly's `responsive: true` only watches the window, so `usePlot` now has a `ResizeObserver`
  (and waits for a ≥ 40-px box — a rail mid-transition is 28 px and Plotly laid out `Infinity` into it); and the
  phone header overflowed 390 px, which made mobile Chrome zoom the whole page out to a 473 × 1024 layout viewport
  (the sheet was off-screen) — the title, chip and ⋯ now fit in 382 px. **D18** ships in the same commit: < 900 px the
  map is the page; the select rail is a bottom sheet with three detents (peek 104 px = selection + lens strip · half
  50 % · full 90 %; pointer drag with a flick, ↑↓ on the handle); depth and years are pills on the map's edge that
  open as sheets; a lens's card and a station's card open as sheets; the combobox is full-screen; the header keeps
  logo · title · chip · ⋯ · theme. Verified: `npm run build` clean; `scripts/verify.mjs --only="^(u1|p)_"` — 18
  desktop states at 1280 × 800 (folds by URL and by click round-tripping `hide=`, maximize + Esc round-tripping
  `max=`, Ben's two bug URLs, minimize → pill, a 300-px card drag staying in the box, 1000 px default, light) and 10
  phone states at 390 × 844 (peek 105 px · half 422 · full 760, a 300-px touch drag, Sections via the lens strip,
  the depth and years sheets, the full-screen organism picker, hexagons, light): no horizontal overflow, every
  control in view or in a scroll box, no page errors (`shots/u1/`). **Real-device gate: not yet run by a person** —
  `vite preview --host` is serving the GCS-dev build at `http://192.168.178.173:5179/` for a phone on the LAN; the
  emulated viewport is a layout check, not a phone, and that check is Ben's to tap through before 9/8.
- **U3 · shipped 2026-08-29, `explore@5fa0853`.** D16 as specified: the header cluster is four `.cc-icon-button`s in
  the toggle's style (help · about · feedback · theme; on a phone About and Feedback fold behind ⋯ with the links,
  and the title shortens to *Explorer* — the `?` button had pushed the bar to 422 px, which `overflow: clip` now hides
  but the map's width still reports); a one-paragraph welcome card on the first visit (`localStorage.explore_welcome`;
  `?tour=on` forces it, `?tour=off` never shows it — the brand screenshots keep passing); the About modal with the
  release chip, "why one frozen release", the 16 datasets (category glyph · colour dot · provider · years and
  observations from `coverage.json` · calcofi.org / source / cite), keyboard, credits and the allowed "better on a
  computer" line; `driver.js` 1.8 (6 KB gz) over `data-tour` anchors with ten steps and `before()` hooks — Lenses
  plays the morph to Hexagons (not under reduced motion), Depth and Years unfold a folded rail, the phone steps move
  the sheet — plus a snapshot/restore so lens, folds and sheet return to what they were; `?` starts it. Feedback is
  the D17 "open a GitHub issue myself" half for now (public `CalCOFI/explore` issue prefilled with the view URL,
  release, viewport, theme); U4b replaces it with the capture + annotate dialog. Two things found: driver's
  `scrollIntoView` scrolled the phone page — an `overflow: hidden` body is still programmatically scrollable, so it
  is `overflow: clip` now; and an anchor selector must pick the first *visible* match, because the phone keeps the
  hidden header buttons in the DOM ahead of ⋯. Verified: `npm run build` clean (bundle +17 KB gz for driver.js +
  help); `scripts/verify.mjs --only="^(u3|p3)_"` — welcome shown at `?tour=on`, not shown again after *Explore*,
  About with 16 dataset rows, the issue link, and `walkTour()`: all ten steps highlight an on-screen element with a
  popover on both 1280 × 800 and 390 × 844 (`shots/u3/u3_tour_00–09.png`, `p3_tour_00–09.png`).
- **U6 · shipped 2026-08-29, `explore@ce4b85f`.** D20 as specified, the three gestures kept apart: brush = filter
  (`years=`, month-resolved as `years=2015-04:2016-10` once the strip is zoomed in; `_filters.sql` compares
  `year::INTEGER * 100 + month(datetime)` — `year` is a SMALLINT and `* 100` overflowed INT16 on the first run),
  wheel / pinch = zoom (`yview=`, in fractional years so the Gantt's date axis shares it; never the filter),
  double-click = reset (the strip with a real mouse; also the context bar and a ⤡ header button, because CDP
  synthesizes no `dblclick` from `clickCount: 2` and Plotly counts its own from mousedown timing — the button is
  what the check proves), ⤢ on the brush zooms to the selection and ✕ clears it, a context bar pans when zoomed.
  Level of detail: month bins at ≤ 15 years (`years.sql {{bin}}`, queried on demand) — the zoomed temperature
  series shows the seasonal cycle instead of fatter bars; the `season` chip (`q=`) is the quarter sibling.
  **Cruises mode**: one bar per cruise from `t0` to `t1` in lanes by ship (36 ships from the `cruise` reference,
  first-appearance order; no two cruises of one ship overlap), coloured by the summary stat with `n` as opacity;
  at 140 px a lane is ~3 px, so the labels hide ("35 ships", the ship in the hover) and reappear maximized; codes
  appear only where a bar is ≥ 40 px (a 3-week cruise needs a window under ~1 year on the strip), click picks the
  cruise. The first version looped: the label pass `relayout`s annotations, which fires `plotly_relayout` again —
  now only a changed set is written and only a zoom/pan re-labels. Verified: `npm run build` clean;
  `scripts/verify.mjs --only="^(u6|p6)_"` — 14 states: `yview=` by URL draws month bins (> 100 bars), wheel →
  `yview=`, double-click on the context bar and the reset button clear it, a brush → whole-year `years=` + the
  handle, zoom-to-selection keeps the filter, a brush at 5 years → month-resolved `years=`, the season chip,
  the Gantt (> 100 bars in 35 lanes, a labelled code at 0.8 years, a pick 2009-04-OIFS → 2008-04-31JD),
  maximized, light, the phone years sheet (`shots/u6/`). Not done: the optional *season* mode (12 month bins over
  all years) — "waits for a request", as the plan says.
- **U4a · shipped 2026-08-29, `explore@a38e596`.** The capture spike decided for **one `html-to-image` composite** of
  the app root: a `foreignObject` rasterized by the browser (so `color-mix()` works, Plotly's SVGs ride along as
  DOM) with both WebGL canvases as images — MapLibre needed `canvasContextAttributes.preserveDrawingBuffer` (its
  option name in v5), deck.gl 9 preserves its buffer by default — so neither `interleaved: true` nor the Screen
  Capture API fallback was needed; the brand's cross-origin `theme.css` only mattered for `skipFonts` (the fonts
  are the system stack). D19: every rail, card, maximized panel and phone sheet header has ⬇ PNG · SVG · CSV
  (`src/export.ts`; Plotly PNG at 2× on the theme background, SVG with the footer as text, the panel's own table
  — month rows when zoomed, the Gantt rows in cruises mode, per-dataset depth rows when maximized; the station
  card as a DOM capture — which came out blank until the cloned card was pinned at 0,0, since a positioned root
  keeps its `top/right` in the clone); the maximized panel exports at its size (2,476 × 1,412). Share ▾ has Copy
  link · Copy image · Download PNG · Send feedback; the footer stamp is shared (`selection · release ·
  calcofi.io/explore + URL`). `luminanceStats()` replaced the plan's "mean luminance ≠ background" check: a dark
  map and a blank dark canvas share a mean (42 vs 29), so the check is spread + non-background fraction. Verified:
  `npm run build` clean (bundle 732 KB gz, +28 KB over U0's start: driver.js ≈ 6, html-to-image ≈ 12, the rest is
  the app); `scripts/verify.mjs --only="^(u4|p4)_"` — whole-view captures in dark and light (sd 30 / 44, 45 % / 26 %
  non-background; `shots/u4/u4_capture_export.png`), 11 panel figures all non-blank / stamped / with rows and
  named to the pattern, the maximized size, the phone Share menu. Tracking is wired (`src/track.ts`) but the page
  carries no gtag yet — U4b adds the fleet's GA4 snippet.

## Layout, drawn

Desktop, everything open (≥ 1200 px):

```
┌ ⭘ CalCOFI Explorer  ⁚⁚ Stations — what has been collected where  [release v2026.08.25]   query schema docs  ?  ⓘ  💬  🌓 ┐
├──────────────────────┬─────────────────────────────────────────────────────────────┬──────────────┤
│ LENS                 │ [st90-ln90 ×]  [SQL & timing ×]                              │ DEPTH  ⬇ ⤢ ▸ │
│ [⁚⁚ Stations][⬡ Hexagons][⛵ Cruises][▱ Regions][⫼ Sections]                        │  0 ┬───────  │
│ DATA                 │ [mean · Pacific sardine · larva · per 10 m² ▬▬▬▬▬ 5–95 %]    │    │ ▒▒▒▒    │
│ [🐟 Biology][🌊 Environment]                                                        │100 │ ▒▒▒▒▒   │
│ organism             │                                                             │    │  ▒▒▒▒   │
│ [Pacific sardine — Sardinops sagax  ▾]        map (MapLibre + deck.gl)             │    │   ▒▒    │
│ life stage [larva ▾]  denominator ◉ per 10 m² ○ per 1000 m³ ○ raw                   │…   │    ▒    │
│ ichthyo larva 7,420 · ichthyo egg 5,906 · CUFES egg 49,572 ⚠  · 6,158 observations  │500 ┴───────  │
│ FILTERS  years 1949–2026 · season all · depth 0–500 m · datasets all                │              │
│ EXPORT  [Download data] [Copy code ▾] [Share ▾] · SQL & timing                      │              │
│                      │ ┌ st90-ln90 · line 90 station 90 ──────────── ▁ ⤢ ⬇ × ┐      │              │
│                      │ │ ● bottle  ▂▃▅▂▁  136,060 obs · 1950–2021           │      │              │
│                      │ │ ● CTD     ▁▂▇▅▃  304,515 obs · 1993–2026           │      │              │
│                      │ └────────────────────────────────────────────────────┘  ⓘ  │              │
│                      ├─────────────────────────────────────────────────────────────┤              │
│                      │ YEARS ⬇ ⤢ ▸  ▂▃▅▇▅▃▂▁▂▃▅▇▅▃▂▁▂▃▅▇▅▃▂   [rows | mean ± se | cruises]        │
│                      │              ────────────────[▒▒▒▒▒▒]──────── context bar when zoomed       │
└──────────────────────┴─────────────────────────────────────────────────────────────┴──────────────┘
```

Two rails folded — the pills carry the state, the map gets the room:

```
├──┬────────────────────────────────────────────────────────────────────────────────────────────┬──┤
│▸ │ [st90-ln90 ×]                                                                              │◂ │
│⁚⁚│ [mean · Pacific sardine · larva · per 10 m² ▬▬▬▬ 5–95 %]                                   │D │
│🐟│                                                                                            │e │
│P │                                                                                            │p │
│a │                                   map, full width                                          │t │
│c │                                                                                            │h │
│i…│                                                                                        ⓘ  │0 │
│  ├────────────────────────────────────────────────────────────────────────────────────────────┤– │
│  │ ▸ Years 1949–2026 ▂▃▅▇▅▃▂                                                                  │5…│
└──┴────────────────────────────────────────────────────────────────────────────────────────────┴──┘
```

Phone (D18, in U1):

```
┌ ⭘ Explorer [v2026.08.25]        ? ⋯ 🌓 ┐
│                                        │
│               map, full-bleed          │
│  [mean · sardine · larva ▬▬▬]          │
│                                        │
│  [Depth 0–500 m]  [Years 1949–2026]    │  ← pills on the map's bottom edge → sheets
├════════════════════════════════════════┤
│ ⁚⁚ 🐟 Pacific sardine · larva · per 10 m²│  ← bottom sheet, peek detent (drag up: half, full)
│ [⁚⁚][⬡][⛵][▱][⫼]                        │
└────────────────────────────────────────┘
```

## Risks and what bounds them

- **Custom combobox accessibility** — follow the WAI-ARIA combobox pattern exactly (roles, `aria-activedescendant`,
  `↑↓ Home End Enter Esc`, typeahead) and keep a native `<select>` fallback behind `?native=1` for a release.
- **Capture fidelity** — WebGL buffers, two canvases, fonts, a cross-origin logo. Bounded by the 2-hour spike in
  U4a with the non-blank assertion in `verify.mjs`, and by the Screen Capture API as the documented fallback.
- **Zoom vs brush gestures** — drag brushes, wheel/pinch zooms, double-click resets, the context bar pans: one
  gesture, one meaning; tested on a trackpad, a mouse and a phone in U6, and the brush stays the only thing that
  changes the filter.
- **The cruise Gantt getting busy** — bounded by ship lanes (no overlap by construction), labels only at ≥ 40 px,
  and zoom; if it still is, the mode stays but the strip defaults to *rows*.
- **Phone** — the gate is a real device, not the emulated viewport; 390 × 844 in `verify.mjs` catches overflow
  regressions on every build; the sheet is the only new gesture surface.
- **Feedback abuse / privacy** — honeypot + hourly cap; the email never leaves the Sheet; the dialog says what is
  sent and that the issue is public; images are app pixels, not the user's screen.
- **Registry lag** — `category` on env variables reaches `coverage.json` only with the next release; the keyword
  stopgap is copied from the station app, which has already paid for its false positives, and carries the comment
  that deletes it.
- **Panel state and the brand checker** — folds are URL/localStorage only; `?tour=off` shows the defaults, so
  `check_brand.py` and the card screenshots are unaffected.
- **Scope creep in U1** — floating *rails* were considered and rejected (every drag is state; a rail off its edge
  loses its meaning); if a user asks for it, the answer is "maximize", not "float".

## Decided (Ben, 2026-08-29)

1. Feedback mails Ben + Erin + Betty — a `recipients` tab in the Sheet, editable without a redeploy; GitHub
   issues public in `CalCOFI/explore`, never carrying the email (D17).
2. No licence question: the calcofi.org icons were an example; draw one clean, consistent set (D15).
3. *Biology · Environment* (D12).
4. The phone matters: "better on a computer" may appear in About, but nothing may fail on a phone — D18 moves into
   U1 with a real-device gate.
5. Icons and group labels on the top-level choices: yes — **Lens** with five lens glyphs, and **Data** (not
   *Measurement*, which already names a different thing in this database) over Biology · Environment (D12).
6. The theme picker: calcofi4py's sun / moon-in-sun — asked for the explorer, applied at the brand so the whole
   fleet changed at once (executed 2026-08-29, five repos); it fixed the icon idiom for D15 and the header
   pattern for D16.

No open questions remain; the next step is U0.

## Kickoff prompt (a new session — Fable at xhigh; cwd `~/Github/CalCOFI/workflows`, so CLAUDE.md and the memory index load)

> Read `.claude/plans/2026-08-29 CalCOFI Explorer UI — rails & cards, naming, sorted pickers, browse by
> category, icons, tour, annotated feedback.md` in full. Every decision (D11–D20) and the "Decided" section are
> settled — do not re-open or re-derive them. Implement slice **U0**, then **U1** (the rails, the floating cards,
> the z-index scale, and the phone bottom sheet — U1 is not done without the phone half), then **U3**, in
> `~/Github/CalCOFI/explore`, exactly as specified. Before each slice, read the files it touches; when the plan
> and the code disagree, say so and follow the code's reality rather than silently redesigning. Verify the way
> the plan says: `npm run build`, puppeteer screenshots of every panel state at 1280 × 800 and 390 × 844 driven by
> `scripts/verify.mjs` (the Claude-in-Chrome tab never paints — never verify through it), and the phone on a
> real device over the LAN before calling U1 done. Keep every URL key unchanged; never move the layout in
> response to data; render brand icons inline the way `App.tsx` renders the theme toggle. Commit each slice on
> `main` when its checks pass, do not ask before pushing, and append the measured results under that slice's row in the
> plan.

## Appendix A — categories, lenses, icons (the `category.csv` draft + the lens glyphs)

| order | category | realm | icon (sprite id) | source of the glyph |
|---:|---|---|---|---|
| 1 | Physical Oceanography | env | `cat-physical` thermometer + wave | MDI `thermometer` / `waves` |
| 2 | Nutrients & Chemistry | env | `cat-nutrients` flask | MDI `flask-outline` |
| 3 | Carbonate System | env | `cat-carbonate` CO₂ | MDI `molecule-co2` |
| 4 | Productivity & Pigments | env | `cat-productivity` sun + leaf | MDI `white-balance-sunny` + `leaf` |
| 5 | Meteorology & Sea State | env | `cat-meteorology` cloud-sun / wind | MDI `weather-partly-cloudy` / `weather-windy` |
| 6 | Phytoplankton | bio | `cat-phytoplankton` diatom | bespoke |
| 7 | Picoplankton & Bacteria | bio | `cat-picoplankton` bacterium | MDI `bacteria-outline` |
| 8 | Zooplankton | bio | `cat-zooplankton` copepod | bespoke |
| 9 | Euphausiids (Krill) | bio | `cat-krill` krill | bespoke |
| 10 | Fish Eggs & Larvae | bio | `cat-ichthyo` egg + larva | MDI `egg-outline` + bespoke larva |
| 11 | Mesopelagic Fish | bio | `cat-fish` fish | MDI `fish` |
| 12 | Seabirds & Marine Mammals | bio | `cat-birds-mammals` gull + whale | MDI `bird` + bespoke whale |

| lens | icon (sprite id) | source |
|---|---|---|
| Stations | `lens-stations` a dot grid | MDI `dots-grid` |
| Hexagons | `lens-hexagons` a hexagon | MDI `hexagon-outline` |
| Cruises | `lens-cruises` a ship on a dotted track | bespoke |
| Regions | `lens-regions` a polygon outline | MDI `vector-polygon` |
| Sections | `lens-sections` a vertical curtain | bespoke |

Realm: `realm-bio` (MDI `fish`), `realm-env` (MDI `waves`). Header and panel actions: `ui-help`
(`help-circle-outline`), `ui-about` (`information-outline`), `ui-feedback` (`message-text-outline`), `ui-download`,
`ui-expand` / `ui-collapse` (`arrow-expand` / `arrow-collapse`), `ui-fold` (`chevron-*`), `ui-close`, `ui-sql`
(`cog-outline`), `ui-share` (`share-variant-outline`); the theme pair stays in `theme.css`. MDI names are confirmed
against the index when the sprite is built. Datasets map to categories through their existing
`calcofi.dataset_meta.category`; env variables through the new `measurement_type.category`.

## Appendix B — tour steps (`src/tour.ts`, `data-tour` anchors)

1. `welcome` — one integrated database, one frozen release (the chip), the map is the CalCOFI grid.
2. `lenses` — Stations · Hexagons · Cruises · Regions · Sections; the morph plays (skipped under reduced motion).
3. `realm` — Biology or Environment: one organism or one variable at a time.
4. `picker` — search or browse by category / dataset; A–Z, bars show how much data.
5. `denominator` — life stage, denominator, dataset pills: nothing is averaged across them (D8), the ⚠ pill.
6. `depth` — brush the water column to slice the map (unfolds the rail if needed).
7. `years` — brush to filter; wheel to zoom in and double-click out; rows · mean ± se · cruises (click a bar to
   pick a cruise).
8. `map` — hover, click a station for its coverage card; fold panels into pills for more map.
9. `export` — download the data with the exact SQL and R/Python; copy code; every panel's ⬇; share a link or a
   picture.
10. `feedback` — 💬 sends the view, a screenshot and your annotations to the team (and a public issue).

## Appendix C — sources

- `explore/src/{App,charts,map}.tsx`, `state.ts`, `style.css`, `sql/{taxa,years,cruise,section_cruises}.sql`,
  `shots/dev2/*.png`, Ben's two screenshots of 2026-08-29 03:58 (section line over the card; dots over timing).
- `db-viz-station/public/{index.html,app.js}` — inventory panel, `CATEGORY_*`, `WALKTHROUGH_STEPS`,
  `FEEDBACK_ENDPOINT`; `db-viz-hex/app/global.R:563` (Conductor).
- `CalCOFI.github.io/brand/v1/README.md` (`?tour=off`, screenshots); `calcofi4r/R/{brand,analytics}.R`
  (`cc_tour_enabled`, `cc_apps_script`).
- Dev catalog `~/_big/calcofi/explore-spike/data2/explore-dev/` — `dataset`, `taxon`, `obs_bio`, `coverage.json`
  (counts above); `metadata/measurement_type.csv` header; ingest `calcofi:` blocks (`category`, `color`).
- https://calcofi.org/data/oceanographic-data/ and …/marine-ecosystem-data/ (inline SVGs, fetched 2026-08-29).
