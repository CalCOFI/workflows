# Docs revamp — one book, five audiences, the DMP's five phases as its spine, keys stated and measured, diagrams that zoom without Chrome

Status: **executed 2026-09-08** (Ben, 02:10 CEST: "proceed with the whole plan yourself", one session,
no subagents). Every slice below ran; what each produced, and where it deviated from the plan as
written, is in § Executed at the end. The plan's original text follows unchanged.

## The ask (Ben, 2026-09-08)

> Write a plan to revamp and revise the Documentation (`../docs`). Review the recently updated repos and
> all the processes folded into CLAUDE.md, memories/skills, `.claude/` notes, and the DMP action sheet's five
> phases — Ingest, Integrate, Publish, Visualize, Synthesis.

The book has to serve, at least: **data providers** current and future (Betty's *CalCOFI Naming
Conventions* Google Doc is the seed of that guide); **specific scientific teams** such as the CTD team
(PostgreSQL, `calcofi4py`, a starter workflow, `server-access.qmd`); the **data science team** curating
datasets (`metadata.qmd`, new 2026-09-07); the **general-interest public, marine scientists and data
scientists**; and language and structure that tie all of them into one explanatory document of every
CalCOFI.io offering and how the pieces interoperate.

Three specific complaints, each answered by a decision below:

1. **Inconsistencies.** The book started in the Postgres + Shiny era and now describes a pipeline of
   reproducible workflows into a parquet database read by DuckDB, even in the browser (the Explorer's six
   lenses). → D1, D2, D5, Appendix A.
2. **db-schema shows the schema but not every table, and it is not clear how keys are set up between
   tables, nor whether referential integrity and uniqueness are really maintained (UUIDs?).** → D6.
3. **Mermaid diagrams need zooming; Lightbox through Quarto hangs Chrome; the JS version Quarto bundles
   differs from current mermaid. Quarto's markdown + docx/pdf is loved, but should another tool be
   considered?** → D3, D4, D1.

## Context, measured 2026-09-08

### The book today

`CalCOFI/docs`, a Quarto **book** (`_quarto.yml`, `project.type: book`), 14 `.qmd` files / 3,200 lines,
13 in the sidebar. Last substantive touch per chapter (git):

| chapter | lines | last touched | state in one line |
|---|---:|---|---|
| `index.qmd` | 28 | 2026-09-07 | the **2022** architecture figure (`figs/sw_arch.svg`, PostGIS/API/Shiny prose) with a 2026 paragraph and the catalog-flow mermaid bolted on |
| `reports.qmd` | 10 | 2024-09-09 | two links (CINMS condition report, the UCSB capstone) |
| `apps.qmd` | 9 | 2026-07-01 | four links; no Explorer, no Station/Hexagon/Cruise/Contour/CTD apps |
| `maps.qmd` | 153 | 2026-07-01 | the H3T hexagon tile API, three mermaid diagrams; `api-h3t` was dropped from the landing cards 2026-07-28 as "too technical" |
| `db.qmd` | 645 | 2026-09-03 | rewritten to current practice (WS-H2): key conventions, core model, registries, DwC mapping; still carries a 75-line "Use Unicode for text" section and sort-order rules for `site_id`/`tow_id`/`net_id`, tables that no longer exist |
| `metadata.qmd` | 159 | 2026-09-07 | new; the provider Sheets and the five-step loop |
| `data-access.qmd` | 559 | 2026-09-05 | the DuckDB/R/Python/browser access chapter; current |
| `server-access.qmd` | 419 | 2026-08-26 | the CTD team's SSH + PostgreSQL chapter; current |
| `helpers.qmd` | 187 | 2026-07-01 | `cc_match_*()` wrappers; overlaps data-access |
| `api.qmd` | 78 | 2026-07-01 | the Plumber API, marked superseded, endpoint→replacement map |
| `portals.qmd` | 440 | 2026-09-07 | live gt tables from the record; current |
| `status.qmd` | 298 | 2026-07-01 | dated log by the *old* three contract components (Ingest / Visualize / Share) |
| `cite.qmd` | 202 | 2026-09-03 | **not in `_quarto.yml` `chapters:`** — `https://calcofi.io/docs/cite.html` answers **404** while `db.qmd` and `portals.qmd` link to it |
| `refs.qmd` | 13 | 2024-09-09 | three package citations |

Open issues on `CalCOFI/docs`: #5 *Document direct querying, helper functions, reproducibility* (open since
2026-05-15 — largely done by `data-access.qmd`, never closed), #4 *API documentation* (obsolete), #1
(2022). The landing card for docs (`products.yml` line 394) says *"data access, database, API, apps, maps
and reports"* — the API half of that sentence is retired.

### Build and diagrams

- `render_book.yml`: **macOS runner**, installs librsvg, TinyTeX, **`quarto install chromium`**, R deps, then
  one `quarto publish` of **html + docx + pdf + epub**. A failure in any format leaves the whole site
  stale; three consecutive deploys failed on 2026-09-07 because gt 1.3.0's Word export choked on `&` in
  a markdown cell the moment the release carried "Picoplankton & Bacteria" (memory
  `feedback_docs_book_gt_word_export`). ~15 min per run. Live tables read the release at render, so a
  **data** change can break the deploy and no local HTML render reproduces it.
- Chromium is there for one reason: mermaid → PNG for the pdf/docx. In `workflows`, `mermaid-format:
  png` wedged `ingest_spatial` for **3 h 15 m** on a 60 KB diagram and is disabled with a warning comment;
  the docs CI still takes that path for every non-HTML format.
- Versions: Quarto **1.8.25** bundles **mermaid 11.6.0** (`share/formats/html/mermaid/mermaid.min.js`);
  `mmdc` (mermaid-cli) **11.12.0** is installed here (`/opt/homebrew/bin/mmdc`) and already renders
  `diagrams/catalog_flow.mmd` for the 9/8 deck. Six `.mmd` sources in `docs/diagrams/` (`catalog_flow`,
  `db_doc`, `h3-pyramid`, `h3t-release`, `h3t-sequence`, `portals_metadata`); eight `{mermaid}` chunks
  across five chapters (maps 3, portals 2, db 1, index 1, metadata 1). **`lightbox` is not enabled in
  docs at all**; client-side mermaid SVGs cannot be zoomed.

### What the release publishes, and what the schema browser can show (v2026.09.06)

Sidecars fetched from `gs://calcofi-db/ducklake/releases/v2026.09.06/`:

| fact | value |
|---|---|
| tables in `catalog.json` | **23** — core 19; supplemental `obs_ctd_full`, `obs_mets_full`, `sample_root`; deprecated `obs` (a view in `catalog.views`) |
| tables in `metadata.json` (what db-schema's Tables/Columns tabs read) | **21** — `sample_root` and **`sample_spatial`** absent |
| why | `metadata/release_tables.csv` (the registry `merge_metadata_json()` overlays for release-built tables) lists `table cruise spatial spatial_attribute obs obs_bio obs_env sample obs_freq sample_measurement obs_ctd_full climatology` — it still names `obs_freq` (renamed `obs_attribute` in July) and never gained `sample_root` / `sample_spatial`; `release_columns.csv` does describe `sample_root`'s columns |
| db-schema default view | hides every `supplemental` table (toggle exists, off by default) — so `sample_root` is hidden by flag and `sample_spatial` by omission; that is the "I can't see some tables" |
| `relationships.json` | PKs declared for **11 of 23** tables (`core_relationships()` in calcofi4db `R/model.R`); **12 have none**: `climatology`, `dataset`, `lookup`, `obs_bio`, `obs_ctd_full`, `obs_env`, `obs_mets_full`, `sample_root`, `sample_spatial`, `spatial`, `spatial_attribute`, `taxon_group` |
| foreign keys | **88** rows; **60** have both ends in the release; **13 phantom tables** (`casts`, `ctd_cast`, `bottle`, `dic_sample`, `euphausiids_tow`, `zooplankton_tow`, `cufes_sample`, `phyllosoma_tow`, `phyto_sample`, `zoodb_sample`, `zooscan_sample`, `bird_mammal_transect`, …) come from `metadata/relationships_cross.csv` rows written for the pre-consolidation per-dataset tables; 4 released tables have no FK on either end (`lookup`, `obs_mets_full`, `region`, `spatial_attribute`) |
| `erd.mmd` | clean — `cc_erd()` draws the 23 released entities and 60 edges; the phantoms pollute only `relationships.json` / `relationships_all.csv` |

**What is actually enforced, today** (so the docs can say it rather than imply it):

| gate | where | what |
|---|---|---|
| `check_core_pk_unique()` | `release_database.qmd` `validate` chunk, **hard stop** since v2026.08.25 shipped 4,855 duplicate `sample_key`s | PK uniqueness on the core family + `taxon`, `dataset_taxon`, `cruise`, `ship`, `grid`, `dataset`, `measurement_type` |
| `check_cruise_key_integrity()` | `cruise_key_integrity` chunk (calcofi4db ≥ 3.32.0) | key format, `date_ym`/NODC agreement, **the FK from `sample`/`obs` into `cruise`**, `cruise_uuid` hygiene, event dates within the cruise span, three ratchets |
| `validate_for_release()` | `validate` chunk | NULLs in any `*_id`/`*_key`/`*_uuid` column, lat/lon/count ranges, empty tables, "completeness" — whose default expected tables are still `cruise, site, tow, net, larva, species` (dead names, so that check is a no-op) |
| `check_obs_pair_parity()` | `browser_objects` chunk | `obs_bio` + `obs_env` reproduce `obs` (counts, ids, hash) |
| `test_release.qmd` consumer contract | after upload, gates `latest.txt` | `obs.sample_key` resolves in `sample`, `measurement_type` in the registry, `hex_id` present where lat/lng — three ways (objects, view, pair) |
| `validate_fk_references()` | `/validate-ingest`, per notebook | FK orphans inside one ingest, before release |
| **nothing** | — | **no release-time check walks `relationships.json`**: the other ~55 declared FK edges (obs→grid, obs→taxon, sample→parent, obs_bio→sample_root, sample_spatial→spatial, …) are true by construction, not measured. That is the honest answer to "is referential integrity really maintained" — mostly yes, by the gates above and by the shape of the assembly; not proven per edge, and not documented anywhere a reader can see |

UUIDs: keys are **natural strings** (`cruise_key`, `sample_key`, `site_key`, `taxon_key`, `dataset_key`);
provider UUIDs are **released as typed columns** (`cruise.cruise_uuid` 691/691, `sample.source_uuid`,
`sample.station_uuid` + method) since v2026.09.04 — `db.qmd` says so correctly, except its callout still
says the two `sample` columns "land with the provider-UUID workstream". Ed Weber's argument for UUID PKs
(partial corrections leave a compound key inconsistent) is met differently in a *read-only frozen release*:
the key is minted after every correction (`create_cruise_key()` refuses a blank NODC), and the gate above
fails the release if a key and its parts disagree. The docs should say exactly that, once, in plain words.

### Betty's *CalCOFI Naming Conventions* against the registries

The Google Doc (`1WE6z26ATRQF5ERjzFM9Z7bC_z_XbvN86io1C_OQq4YY`, last edited 2026-09-07 23:21) is a one-page
summary plus full tables: general rules, identifiers (cruise, station/line, ship, net tow + tow-type code
list, taxon), time, space, variables and units by category, biological quantities, life stages, effort, an
NODC ship-code appendix, references. Empty **Audience** and **Purpose** lines at the top (Erin asked for
that section on 9/3). Open comment threads: Erin *"Add UUID?"* on Identifiers; Ben *"There's also an odd egg
phase, per ingest_swfsc_ichthyo"* on life stages. Measured disagreements with `metadata/`:

| the guide says | the record has |
|---|---|
| `ship_key` = 2-char CalCOFI code **[LEGACY]**; proposes `ship_code` = NODC **[AUTHORITATIVE]** | `field_dictionary.csv` row 4: **`ship_key` = "NODC ship code key; primary key of ship"**; `ship_nodc` also present; there is no `ship_code` |
| `depth` (m, positive down) | `depth_m` (`field_dictionary.csv` row 23); unit-suffix rule in `db.qmd` |
| `datetime_utc`, `datetime_local`, `utc_offset` | `datetime_start_utc` / `datetime_end_utc` (rows 26–27); no local-time field in the dictionary |
| `larvae_stage` codes `YOLK PREF FLEX TRNS POST`; `egg_stage` 1–11 | `life_stage.csv` holds lowercase words (`egg`, `larva`, `yolk-sac` …) with DwC + NERC S11 ids; the dictionary notes "ichthyo currently ships numeric stage" |
| `M2` = MOCNESS 10-m frame | `gear.csv`: `M2` = MOCNESS (3 m²); registry also has `OBLIQUE` (gear unrecorded), absent from the guide |
| `cruise_id` long form `1949-03-01-C-31CR` [LEGACY] | not in the dictionary; `cruise_id` is an *alias* of `cruise_key` there |
| references `calcofi.io/schema`, "calcofi.io §5.1" | `/schema` is a redirect to `/db-schema/`; §5.1 names nothing |

The 2026-08-13 Task-12 reply already found the deeper problem: **three normative statements of the
conventions** (`db.qmd`, `workflows/README_PLAN.qmd` § Primary Key Strategy, `CLAUDE.md`) and only the
agent file matched the database. `db.qmd` has since been fixed; `README_PLAN.qmd` still sits in the
workflows root with its January-2026 design (working DuckLake, `site_uuid`/`tow_uuid` PKs, `dataset.csv`).

### What the team asked for, in their words

- **9/3 data meeting** (Tactiq `5Jm0eqZ531Y3XvHmMtF8`): Erin — *"two conversations: one is about the
  database, the back end … this document's purpose is more like general guidance if somebody wanted to do
  something that aligned with what we do"*; *"I'm not convinced we can get every single dataset person on
  board with a UUID"*; asks Betty to add an audience-and-purpose section and organise fields as mandatory /
  optional / best practice. Ben — *"be specific about the audience and the purpose. One is documenting the
  fields in the integrated database available via apps, Python, direct SQL; the other is a recommendation
  for data providers"*; *"UUID is a best practice thing"*; *"we can maintain all the UUIDs and internally
  create a unique identifier from any original dataset."* Erin on the Explorer: *"the five-course meal — I
  first want to ask people about the individual courses"* (keep the modular apps for feedback).
- **8/24 meeting with Mark** (`fut0KEl3IqIJqstQpgGr`): Mark wants **status and projected completion dates
  per task and subtask**, shared so *"everybody's on the same page"*; Betty: the naming doc is Task 12,
  "finalized" pending edits; Ben mentioned a drafted paper on the integrated database (Drive: *paper4 —
  CalCOFI cruise consolidation manuscript draft v0.2*, 2026-08-21 — not read for this plan).

### Where the docs deliverables sit in the DMP and the SoW

DMP action sheet (`1r5xs4SzLlY1pDzdAYb5viW8Lg5v-410WfTGPBVsX3aM`, Status tab, Ben & Betty rows):

| task | phase | the documentation the sheet itself names |
|---|---|---|
| 11 cloud DB, internal + external | Integrate | *"Remaining for Q1: one consolidated access-guidance doc covering the internal and external paths"* |
| 12 naming conventions | Integrate | *official guide + legacy→standard mapping tables*; Betty drafts with audience-and-purpose, mandatory/optional/best-practice, an example table; Erin reviews; inventory Q1, circulated Q2, applied Q3 |
| 13 dataset nomenclature | Integrate | *governance document recording the front-matter conventions* (Q3) |
| 14 data inventory / entry point | Visualize | *"document the federated architecture and data-access paths (Q4)"* |
| 15 / 16 reports | Synthesis | Mark: mid-term report (end Y1); *"a clear, stand-alone, living document that serves as the source of our data management approach"* (end Y2) |

SoW 2026-09-01 → 2027-08-31 (Drive `1rXJNW27sAfw3CDvYOdmTz4TmJf5a4pR_`), documentation lines: **Q1 (due
2026-11-30)** access-guidance documentation (Task 11), naming inventory + first draft, quarterly status
report at `calcofi.io/docs/status`; **Q2** draft guide + mapping tables circulated, webinar 1 (product
showcase); **Q3** final guide agreed; **Q4** federated-architecture and data-access documentation, webinar
2 (technical deep-dives), Task 15 contributions and Task 16 seed. The book is where every one of those
lands, so the plan's slices are ordered by those quarters.

### The neighbouring documentation the book must link, not copy

| site | tool | holds |
|---|---|---|
| `calcofi.io/datasets/{key}/` | Jekyll, generated from `datasets.json` | one page per dataset: hero map, coverage, every endpoint, citation |
| `calcofi.io/db-schema/` | Jekyll + JS over the release sidecars | tables, columns, ERD, datasets, measurement types, per version |
| `calcofi.io/workflows/` | Quarto + `build_workflows_index.R` | every ingest / publish / release notebook rendered, with its questions |
| `calcofi.io/calcofi4r/` | pkgdown (Read / Analyze / Visualize / Data / Database / Analytics / Brand) + vignettes *bio-env-matching*, *citing-calcofi-data*, *ctd-temperature-anomalies* | R reference |
| `calcofi.io/calcofi4py/` | MkDocs Material (citing, `articles/ctd-qaqc.ipynb`, reference, changelog) | Python reference and the CTD QA/QC notebook |
| `calcofi.io/calcofi4db/` | pkgdown | the engine's reference |
| `storage.calcofi.io/…/RELEASES.md` + per-version `RELEASE_NOTES.md` | markdown | the database changelog |
| `calcofi.io/brand/v2/README` | — | the brand contract |
| `CalCOFI/server` `postgis/init/*.sql` (`10_roles`, `20_calcofi_db`, `30_calcofi_schemas`, `40_ctd`, `50_release_views`) | SQL | the CTD team's schema of record |
| landing `products.yml` sections | Jekyll | **Datasets · Explore (across / one) · Access · Build · Students** |

## Findings

- **F1 — Two eras share one book.** `index.qmd` opens on the 2022 figure and its PostGIS / API / Shiny
  narrative; `apps.qmd`, `reports.qmd`, `api.qmd` and `maps.qmd` are from that era; `db.qmd`,
  `data-access.qmd`, `metadata.qmd`, `portals.qmd`, `cite.qmd` are from this one. A reader cannot tell
  which is the system.
- **F2 — No audience structure.** Thirteen flat chapters; nothing says who a chapter is for. The landing
  page already has the audience sections the book lacks.
- **F3 — The keys are stated but not shown, and two tables are invisible.** `db.qmd` states the key
  rules well; the browser hides one table by flag and lacks another by omission; PKs are declared for
  11/23 tables; 28 of 88 FK rows name tables that do not exist; no gate walks the FK list. Nowhere can a
  reader see "PK, unique: yes, measured; FKs: 0 orphans" the way pgAdmin or DBeaver shows constraints.
- **F4 — Diagrams cannot be zoomed, and the only zoom path hangs Chrome.** Client-side mermaid (no
  lightbox) in HTML; Chromium-rendered PNG for pdf/docx in CI; two mermaid versions.
- **F5 — The build is monolithic and data-fragile.** Four formats in one publish; live gt tables; a `&`
  in a dataset name took the site down for a day.
- **F6 — The naming conventions still live in three places.** Betty's Doc (the provider guide), `db.qmd`
  (the database's rules), `README_PLAN.qmd` (stale design). Seven measured disagreements between the Doc
  and the registries (table above). Task 12's deliverable is precisely their reconciliation.
- **F7 — The DMP's five phases have no home.** `status.qmd` logs by the 2025 contract's three components;
  the SoW and the sheet use five; Mark asked for status and dates per task.
- **F8 — The CTD team's path is in three places.** `server-access.qmd` (accounts, tunnel, schema, flags),
  `calcofi4py`'s `ctd-qaqc.ipynb`, and `workflows/clean_ctd_cruise-var.qmd`; nothing says "start here"
  or how a flag accepted in PostgreSQL reaches the next release (`flag_accepted.parquet`).
- **F9 — Orphans and leftovers.** `cite.qmd` is unreachable (404): the brand-v2 commit dropped it from
  the nav, and re-adding it needs `calcofi4r` in `DESCRIPTION` `Remotes:` plus guards or CI breaks (A0);
  #5 is done but open; the docs card's description names the API; `db.qmd` keeps sort-order rules for
  tables that no longer exist and a 75-line PostgreSQL-only Unicode section; `index.qmd` and
  `metadata.qmd` declare the same `fig-catalog-flow` label; `data/portal.csv` is a hand copy the prose
  calls generated; `README.md` tells contributors to clone another project's repo; four rendered HTML
  files, `test.R`, `test.txt` and a 2.8 MB `webshot.png` are tracked (A6).
- **F10 — `data-access.qmd` teaches the table the next release removes.** 559 lines, no `obs_bio` /
  `obs_env`, three of five partition columns wrong, twelve hand-built parquet URLs across two chapters
  right after the sentence forbidding them (A2). `maps.qmd` is wrong about the service it documents
  (FastAPI, `h3_cell_to_parent`, the stale-inode deploy) and about H3 itself (A3).
- **F11 — The sidebar may fail the brand check.** It loads the mark, not the v2 horizontal lockup the
  contract and `check_brand.py`'s `lockup` probe require (A6) — verify against the weekly run.

## Decisions

Stated as decisions so a slice can start; Ben overrides any of them by saying so.

### D1 — Stay on Quarto, stay a *book*; fix the two things that hurt

| option | one site + one PDF/DOCX | R chunks reading the record | non-engineers edit | cross-refs, citations | who else uses it here |
|---|---|---|---|---|---|
| **Quarto book** (today) | yes — the "living document" Task 16 asks for is the PDF of this book | yes | yes (`.qmd`) | yes | workflows, packages' vignettes |
| Quarto website | no single document; per-page only | yes | yes | yes | — |
| MkDocs Material | no (plugins, brittle) | no (Jupyter articles only) | yes (`.md`) | weak | calcofi4py |
| Hugo | no | no | yes | weak | analytics site (memory: Hugo for new *static sites*) |
| Docusaurus / mdBook | no | no | JS-flavoured | weak | — |

The pain is not Quarto; it is (a) mermaid through Chrome and (b) four formats in one fragile publish.
D3 and D4 remove both without leaving Quarto. Betty and Erin can edit a `.qmd` in the browser via
`repo-actions: [edit]` (already on). The `docx` download stays for the report writers; the `epub` can go.

### D2 — Restructure into parts by audience, with the five phases as the spine

Quarto books support `part:` groupings in `chapters:`. The new table of contents (files in parentheses;
✚ new, ✎ rewritten, ↔ merged, ▸ moved, ✕ retired):

```
Start here                                    (index.qmd ✎)
  what CalCOFI.io is, in one figure (the new system diagram, D3) and one paragraph per phase:
  Ingest → Integrate → Publish → Visualize → Synthesize; "which door for you" audience matrix

Part I · Use the data              — public, marine scientists, data scientists
  Explore                                     (explore.qmd ✚ ← apps.qmd ✕, reports.qmd ✕)
  Access the data                             (data-access.qmd ✎ ↔ helpers.qmd, api.qmd's endpoint map)
  Cite this data                              (cite.qmd — wired into the nav)

Part II · Understand the database  — data scientists, app builders, anyone joining tables
  The database                                (db.qmd ✎: core model, reference tables, taxonomy, flags, depth)
  Keys and integrity                          (keys.qmd ✚ — split out of db.qmd; the measured section, D6)
  Naming conventions                          (naming.qmd ✚ — generated from the registries; Betty's prose; D7)
  Releases                                    (releases.qmd ✚ — versions, DOI, content addressing, RELEASES.md, what a release checks)

Part III · Contribute data         — providers, current and future
  Providing data to CalCOFI                   (provide.qmd ✚ — Betty's guide: audience/purpose, mandatory · optional · best practice, an example table)
  Metadata & the ingest loop                  (metadata.qmd, as is)
  Portals and archives                        (portals.qmd, trimmed to the record-driven sections)

Part IV · Work with the team       — the CTD team, the data team, builders
  Server access                               (server-access.qmd, as is)
  CTD QA/QC, start to release                 (ctd-qaqc.qmd ✚ — PG schema → flags → flag_accepted.parquet → the ingest → the release; links the calcofi4py article)
  Ingesting a dataset (the skills loop)       (ingest-loop.qmd ✚ — a public, condensed RUNBOOK: explore → metadata → ingest → validate → release)
  Products, brand and uptime                  (products.qmd ✚ — the three-slug contract, brand v2, status/analytics; short, mostly links)

Part V · The plan and the record   — Synthesis
  The data management plan                    (dmp.qmd ✚ — the five phases, tasks 1–24 with owner · status · date, read from docs/data/dmp_tasks.yml)
  Architecture                                (architecture.qmd ✚ — the federated system and every access path; Task 14 Q4 deliverable; the diagram from index at full size with its legend)
  Status                                      (status.qmd ✎ — dated log continues, sections keyed by the five phases from 2026-09 on)

Appendices
  A · The retired API                         (api.qmd ▸ appendix, one page)
  B · Glossary                                (glossary.qmd ✚ — cruise, cast, tow, net, site, grid, hex, realm, grain, release, holding, …)
  C · References                              (refs.qmd)

Retired outright: maps.qmd ✕ (the H3T explainer; the tile API served the Shiny hexagon app, which the
Explorer supersedes — Ben, 2026-09-08) with diagrams/h3-pyramid.mmd, h3t-sequence.mmd, h3t-release.mmd
and figs/int-app_map-compare-bio-env.png; maps.html aliases to explore.html.
```

Old → new: `apps` + `reports` → **Explore**; `helpers` + `api` (map) → **Access**; `db` → **Database**
+ **Keys and integrity** + part of **Naming**; `maps` → retired, alias to **Explore**; `api` → Appendix A.
Nothing is deleted from git history; retired pages redirect (Quarto `aliases:`) so old links keep working.

### D3 — Diagrams: mermaid sources stay, SVGs are pre-rendered by `mmdc`, Chrome leaves the build

- Every diagram lives as `diagrams/{name}.mmd` (already true for six). A script
  `libs/render_diagrams.sh` runs `mmdc -i diagrams/x.mmd -o diagrams/x.svg` for each, with the mermaid-cli
  version **pinned in `docs/package.json`** (11.12.0 today) so the book has exactly one mermaid version
  and it is the current one. SVGs are **committed**; CI does not run Node.
- Chapters embed `![caption](diagrams/x.svg){#fig-x .lightbox}`. `lightbox: true` in `_quarto.yml`
  gives zoom for every figure in HTML; librsvg (already installed in CI) rasterises the same SVG for
  pdf/docx. `quarto install chromium` and `QUARTO_CHROMIUM_HEADLESS_MODE` leave `render_book.yml`.
- `{mermaid}` chunks are allowed only for a diagram under ~10 nodes that is easier to read as text in the
  source; none of the existing eight qualifies except perhaps `metadata.qmd`'s. Labels are unique per book
  (`fig-catalog-flow` is declared twice today; the three includes of `catalog_flow.mmd` become one figure
  referenced from three chapters).
- Of the six sources, `catalog_flow.mmd` and `portals_metadata.mmd` stay; **`db_doc.mmd` is retired**
  (every node is stale, A4) in favour of `system.mmd` (S2); the three h3t diagrams go with `maps.qmd`
  (retired, see D2). So the book carries three diagrams: the system, the catalog flow, the portals'
  metadata flow — plus the curated core-family ERD below.
- The ERD: the book does **not** redraw the full 23-table ERD (db-schema does that per version). It shows
  one hand-curated **core-family ERD** (`sample`, `obs_bio`, `obs_env`, `obs_attribute`,
  `sample_measurement`, `cruise`, `grid`, `taxon`, `dataset`, `measurement_type`) with cardinalities, and
  links the browser for the rest.
- Mermaid's own pan/zoom (`svg-pan-zoom`) is a fallback for anyone who wants inline zoom without
  lightbox; not needed if lightbox works, so not planned.

### D4 — Build: HTML publishes alone; PDF/DOCX are a second, non-blocking job; live data is snapshotted

- `render_book.yml` splits into **`publish-html`** (Ubuntu, ~4 min, blocking; `quarto publish --to html`)
  and **`build-documents`** (pdf + docx, `needs: publish-html`, `continue-on-error: true`, uploads the
  files as workflow artifacts and commits them to `gh-pages/downloads/`). A gt/LaTeX failure never takes
  the site down; it fails a badge.
- `libs/pre-render.R` (exists, commented out in `_quarto.yml`) becomes real: it reads the promoted
  release's `catalog.json`, `metadata.json`, `relationships.json`, `integrity.json` (D6), `datasets.json`,
  the four registries and `RELEASES.md` **once**, and writes `data/*.json|csv`. Chapters read those files.
  The numbers become reviewable in a PR diff, the render is deterministic, and a table can be unit-tested
  with `gt::as_word()` / `gt::as_latex()` in `libs/check_tables.R` before a push (the memory's rule, made
  a script).
- `execute: freeze: auto` so a chapter re-executes only when its source or the snapshot changes.
- Link check: `libs/check_links.R` (ranged GET, never HEAD — the rule from `build_workflows_index.R`)
  over every external URL in the rendered HTML; runs in `publish-html`, warns on 5xx, fails on 404/410.
- Drop `epub` (nobody asked; one fewer format to break). Keep `docx` and `pdf`.
- **Pin what CI resolves**: a Quarto version in `quarto-actions/setup` (`1.8.25` today), an R version, and
  a real `DESCRIPTION` (title, authors, `Remotes: calcofi/calcofi4r`, every package a chunk loads) so
  `setup-r-dependencies` installs the same set every run; the pre-render snapshot replaces the hand-copied
  `data/portal.csv`, so no registry is ever copied into the docs repo by hand again. Render-time network
  fetches go through `pre-render.R` only, and a fetch failure **fails** the render instead of publishing a
  book that says the record is missing.

### D5 — Generated over authored: every table of fact reads the record

| chapter | reads |
|---|---|
| Explore | `products.yml` (the landing's cards, fetched raw) → one table per section with live/source/uptime links; the Explorer's six lenses from `explore/README.md`'s first paragraph is *authored* (one sentence each) |
| Access | `catalog.json` (version, tables, bytes), `versions.json`; code blocks are literal but the version string is substituted |
| Database | `metadata.json` tables + columns (the pgAdmin-style inventory: **all 23**, with supplemental/deprecated badges, row counts, bytes) |
| Keys and integrity | `relationships.json` + **`integrity.json`** (D6) |
| Naming | `field_dictionary.csv`, `measurement_type.csv`, `category.csv`, `life_stage.csv`, `gear.csv`, `provider.csv`, `license.csv`; legacy→standard mapping from the dictionary's `aliases` plus each ingest's `flds_redefine.csv` |
| Releases | `RELEASES.md` headings, `versions.json`, `release_policy.yml`, the Zenodo concept DOI |
| Portals | as today (`portal.csv`, `distribution.csv`, `distribution_observed.json`, `datasets.json`) |
| DMP | `docs/data/dmp_tasks.yml` — an authored mirror of the Sheet's Status tab (the Sheet is private; the YAML is the public record, updated with each quarterly status entry) |
| Status | `libs/status_git-logs.R` as today, sections by phase |

Prose explains; nothing that can be measured is typed.

### D6 — Keys and integrity: state the contract per table, and show the measured result

The chapter answers Ben's question in three layers, and needs four upstream fixes to be true:

1. **The rules** (moved from `db.qmd`): suffixes (`_key` string natural, `_id` integer, `_uuid` provider's,
   `_seq`), the four integration keys, why natural keys and not UUID PKs in a read-only release, and the
   plain-language answer to Ed: *provider UUIDs are preserved as columns and are the join back to the
   provider's database; the release's own keys are natural, minted after every correction, and a release
   whose key disagrees with its parts does not ship.*
2. **The contract per table** — a generated table with one row per released table: PK, FKs out, FKs in,
   nullable FK columns by design (`grid_key` on `obs`, `taxon_key` on env rows), the supplemental /
   deprecated flag, and the row count. Source: `relationships.json` after fix (b).
3. **The measurement** — per PK "distinct = rows", per FK "orphans = n", per release, from
   `integrity.json`, plus the list of gates and what each covers (the table in Context above, kept current).

Upstream, in order:

- (a) **`calcofi4db::core_relationships()` declares a PK for every released table** — `obs_bio`/`obs_env`
  (`obs_id`), `obs_ctd_full`/`obs_mets_full` (composite: `sample_key, depth_m, measurement_type` or
  `obs_id` if present — measure), `sample_root` (`root_id`), `sample_spatial` (`root_sample_key,
  spatial_key`), `spatial` (`spatial_key`), `spatial_attribute` (composite), `taxon_group` (`group_key,
  taxon_key`), `climatology` (`dataset_key, grid_key, month, depth_bin, measurement_type`), `dataset`
  (`dataset_key`), `lookup` (measure). Composite PKs need `check_core_pk_unique()` to accept a vector.
- (b) **`relationships_cross.csv` loses or marks its phantom rows** — the 28 rows whose `table` or
  `ref_table` is a pre-consolidation per-dataset table. Prefer a `released` column set `false` (the rows
  document how each ingest resolved its keys, which the notebooks still cite) and have
  `merge_relationships_json()` emit only released rows into the sidecar.
- (c) **`check_release_relationships()`** (calcofi4db) walks the merged `relationships.json` on the frozen
  tables: PK distinct-vs-rows and FK orphan counts per edge (NULLs excluded), writes
  `integrity.json` beside `catalog.json`, **errors on any PK violation or any orphan on a non-nullable
  edge**, reports nullable-edge orphans. `test_release.qmd` adds a contract row that `integrity.json`
  exists and is all-clear. `validate_for_release()`'s dead `expected_tables` default goes.
- (d) **`release_tables.csv`** gains `sample_root` and `sample_spatial`, drops `obs_freq`; **db-schema**
  reads `integrity.json` to show a Keys column on the Tables tab (PK ✓ measured · FK orphans 0) and marks
  PK/FK/nullable on the Columns tab — the DBeaver view Ben misses — and shows supplemental tables by
  default with their badge (hidden was a v2026.07 choice for a 44-table release; at 23 it hides more than
  it helps).

### D7 — One naming-conventions chapter, generated; Betty's Doc is the drafting venue, the chapter the record

- `naming.qmd` is the **database's** conventions (Ben's "documenting the fields in the integrated
  database"): rules prose + generated tables from the registries, one section per registry, with the
  legacy→standard mapping tables Task 12 promises (from `aliases` and every `flds_redefine.csv`).
- `provide.qmd` is the **provider's** guide (Erin's "general guidance if somebody wanted to align"):
  audience and purpose up front; fields as **mandatory** (what · when · where: the sample event, its time
  in UTC, its position, its depth, the measured quantity with units and bounds, the taxon with a
  scientific name and, when possible, a WoRMS/ITIS/GBIF id), **optional** (cruise and station designations,
  gear, effort, life stage, quality flags), **best practice** (a stable identifier per row you can hand us
  again — a UUID if you run a database, never required; a license; a citation; a contact); an example
  table with its columns; the tow-type and NODC code lists *linked* to the registries rather than copied.
  Betty authors the prose in her Doc; the chapter's tables are generated; the seven disagreements above are
  settled in the registries first (`ship_key` stays and the guide drops `ship_code`; `depth_m`;
  `datetime_start_utc`; life stages as the registry's words with the ichthyo numeric codes mapped in
  `life_stage.csv`; `M2` corrected; `OBLIQUE` added; `cruise_id` recorded as a legacy alias). Ben's "odd egg
  phase" comment becomes a `life_stage.csv` row or an ichthyo question; Erin's "Add UUID?" is answered by
  the best-practice tier.
- `README_PLAN.qmd` moves to `.claude/plans_done/2026-01 README_PLAN (design intent).md` after its two
  still-true paragraphs (the Drive ↔ GCS layout, the naming of GCS prefixes) are folded into
  `architecture.qmd` — the 8/13 email's recommendation, executed.
- Task 13's governance document is `naming.qmd` § *Dataset keys and names* (provider slug registry,
  `dataset_key = provider_dataset`, the `calcofi:` front-matter as the single source of truth) plus a
  one-paragraph decision record with the date it was agreed and who agreed.

### D8 — The five phases are the book's spine and the status page's sections

`index.qmd` walks Ingest → Integrate → Publish → Visualize → Synthesize in one paragraph each, naming the
product and the chapter for each; `dmp.qmd` holds the task table; `status.qmd`'s next entry (Q1,
2026-11-30) uses the five headings and every later one does too. The old three-component entries stay as
history.

### D9 — Sequence: wire the 404 first, then the skeleton, then the chapters by contract quarter

Nothing waits on everything. The first commit fixes `cite.qmd` in the nav and the docs card's description;
the skeleton lands next so every later chapter has a home.

## Slices

| slice | what | depends on | size | model / agent | lands by |
|---|---|---|---|---|---|
| **S0 · Hotfix** | `_quarto.yml` gains `cite.qmd` **with** `DESCRIPTION` `Remotes: calcofi/calcofi4r` and `tryCatch` guards on its live chunks, and its dead `cc_cite()` apologies removed; the duplicate `fig-catalog-flow` label; the sidebar logo → the v2 lockup if `check_brand.py` fails it; untrack the four HTML files, `test.R`, `test.txt`, `webshot.png`; fix `README.md`'s clone URL; close docs #5; the docs card description in `products.yml`; `db.qmd`'s `source_uuid`/`station_uuid` callout, the `site_id`/`tow_id`/`net_id` lines, the `#erd?v=v2026.05.19` deep link, the "publish_to-obis is planned" sentences; `apps.qmd`'s dead `shiny.calcofi.io/oceano` link | — | S | ws-sonnet-high | now |
| **S1 · Build** | D3 + D4: `package.json` + `libs/render_diagrams.sh` + committed SVGs; `lightbox: true`; `pre-render.R` snapshot + `data/`; `freeze: auto`; split CI; `libs/check_tables.R`, `libs/check_links.R`; drop epub | S0 | M | ws-sonnet-high | Sept |
| **S2 · Skeleton** | D2 parts in `_quarto.yml`; new empty chapters with a `::: callout-note` "being written" body; `aliases:` for retired pages; `index.qmd` rewritten around the five phases; the new system diagram (`diagrams/system.mmd` — ship → source files → ingest notebooks → release → catalog/EML → portals & apps & packages, with the PG working store beside it) | S1 | M | ws-opus-medium | Sept |
| **S3 · Integrity (upstream)** | D6 (a)–(d): calcofi4db PKs + `check_release_relationships()` + `integrity.json`; `relationships_cross.csv` `released` column; `release_tables.csv`; `test_release` contract row; db-schema Keys column and default visibility. Needs a staging run (`CALCOFI_RELEASE_PREFIX=ducklake-staging/releases`, `CALCOFI_TABLES_PREFIX=ducklake-staging/tables`) and a real one | — | L | ws-fable-xhigh (package + gate), ws-sonnet-high (db-schema) | Oct, with the next release |
| **S4 · Part II** | `db.qmd` trimmed; `keys.qmd` (D6 layers 1–3); `releases.qmd`; `naming.qmd` generated from the registries with the legacy→standard mapping (Task 12 Q1 *inventory*) | S2, S3 for the measured section (the chapter renders "not yet measured" until `integrity.json` exists) | L | ws-opus-medium | **Q1, 2026-11-30** |
| **S5 · Part I + IV access** | `explore.qmd`; **`data-access.qmd` rewritten around `obs_bio`/`obs_env` and the catalog resolvers** — every parquet URL comes from `cc_release_sources()` / `release_sources()` / the snapshot, the partition table is generated from `catalog.json`, `qual_ok` documented, the sardine example executed once and its coverage caveat read from `dataset.coverage_temporal`; absorbs helpers + the endpoint map (Task 11's *"one consolidated access-guidance doc covering the internal and external paths"* = Access + Server access, cross-linked from a two-column table on `index.qmd`); `server-access.qmd`'s stack table gains the h3t origin container and loses its hand-built URLs; `ctd-qaqc.qmd`; `ingest-loop.qmd`; `products.qmd` | S2 | L | ws-opus-medium (access), ws-sonnet-high (the rest) | **Q1** |
| **S6 · Part III** | `provide.qmd` from Betty's Doc (Betty writes, Ben/Erin review; the seven registry reconciliations first, in `workflows`); `portals.qmd` trim | S4's naming tables | M | Betty + ws-sonnet-high | draft Q1 → circulated **Q2** → final **Q3** |
| **S7 · Part V** | `dmp.qmd` + `docs/data/dmp_tasks.yml` (seeded from the sheet's Status tab, tasks 1–24); `architecture.qmd`; `status.qmd` Q1 entry by phase, with `libs/status_git-logs.R` reading its repo list from `products.yml` instead of a seven-repo literal; retire `README_PLAN.qmd` | S2 | M | ws-sonnet-high | dmp/status **Q1**; architecture **Q4** (Task 14) |
| **S8 · Appendices + glossary + webinar hooks** | `maps.qmd` retired with its three diagrams and the `int-app` screenshot, `maps.html` aliased to `explore.html`; `api.qmd` → appendix; `glossary.qmd`; a *Learn* row on `explore.qmd` for the two recorded webinars (Q2, Q4) when they exist | S2 | S | ws-sonnet-high | Q2 |
| **S9 · Upstream, landing page** | `products.yml`: the Shiny app cards (`db-viz-hex` and the other server-hosted apps Ben names) get `status: superseded`, `superseded_by: explore` with the replacing lens in the description, following the `oceano` precedent; the uptime and analytics slugs stay (the apps keep serving); `deploy-consumers` and the h3t API become legacy maintenance. Ben decides the exact card list; the docs table follows | — | S | Ben + ws-sonnet-high | with S5 |

Model choices follow `.claude/agents/`: contract-changing work (S3) on Fable; multi-file rewrites on
established patterns (S2, S4) on Opus; single-chapter and script work on Sonnet. Betty owns the provider
guide's prose throughout; the agent only generates its tables and wires the page.

## Per-chapter specs (the new and rewritten ones)

**`index.qmd` — Start here.** ≤ 60 lines. One sentence on what CalCOFI.io is (*an open, versioned,
integrated database of CalCOFI's observations and the products around it*); the system diagram; five
short paragraphs, one per phase, each ending in the chapter and product that realise it; the audience
matrix (*I want to … → go to …*, one row per audience above); the release line (version, DOI, datasets,
rows — from the snapshot). No 2022 figure; it moves to `architecture.qmd` as "where this started".

**`explore.qmd` — Explore.** The Explorer first (six lenses, one sentence each, the URL-is-the-view rule,
the feedback button, *Cite this data*), then the datasets catalog (`calcofi.io/datasets/`) and the
schema/query explorers, then **the other apps as a generated table that reads `status` /
`superseded_by` from `products.yml`** — so a superseded app reads *superseded by the Explorer (hexagons
lens)* and a live one keeps its row. Ben's decision (2026-09-08): the Shiny apps, `db-viz-hex` included,
are superseded by the Explorer; the chapter says so only once the cards say so (upstream item below), so
the book never contradicts the landing page. Erin's "individual courses" concern is met by naming, on
each superseded row, the lens that replaces it.

**`data-access.qmd` — Access the data.** Keep the current structure; absorb `helpers.qmd` as a section
(*Matching biology to environment*) and `api.qmd`'s endpoint→replacement table as a collapsed callout;
add a top table *two databases, two paths* (public release: browser / R / Python / SQL; working PostgreSQL:
SSH tunnel, CTD team) that is the Task 11 guidance in one screen; every code block's version string
substituted from the snapshot; the quality-flag section stays.

**`db.qmd` — The database.** What stays: core model, `obs_bio`/`obs_env` + view, reference tables,
taxonomy, flags, depth, registries, coverage, citation contract, DwC/OBIS mapping, spatial tips. What
moves out: naming conventions → `naming.qmd`; key conventions and relationships → `keys.qmd`; release
versioning → `releases.qmd`. Decide the Unicode section's fate from Appendix A. Add the **table inventory**
(all 23 with badges, rows, bytes, "since" version) — the pgAdmin-style list.

**`keys.qmd` — Keys and integrity.** D6's three layers; the core-family ERD SVG; the gate table; a
worked example of walking `sample`'s adjacency list and joining `obs_bio` to `sample_root`.

**`naming.qmd` — Naming conventions.** D7; sections: tables and columns (rules); identifiers (the four
keys, suffixes); fields (`field_dictionary.csv`, with DwC terms); measurement types by category (with
units, bounds, NERC ids); life stages; gear; providers, licenses, dataset keys and names (Task 13);
legacy → standard mapping tables; *how to propose a change* (a PR to `metadata/` or a question row).

**`releases.qmd` — Releases.** Version = date; what a release contains (catalog, sidecars, parquet
objects); content addressing and what `since` means; consolidated vs retired versions and how to pin one;
the DOI per release and the concept DOI; `RELEASES.md` as the changelog with the last three headings
rendered; what a release checks before it ships (the gate table, shared with `keys.qmd` via an include).

**`provide.qmd` — Providing data to CalCOFI.** D7's provider guide. Ends with *what happens next*: the
ingest loop, the questions Sheet, the dataset page, the DOI.

**`ctd-qaqc.qmd` — CTD QA/QC, start to release.** For Rasmus, Ben G., Kelsey, Betty: the three schemas in
one figure; the flag ledger's life cycle (propose → accept → `flag_accepted.parquet` nightly → the CTD
ingest applies it as `measurement_qual` → the next release); the `calcofi4py` article and the
`clean_ctd_cruise-var.qmd` notebook as the two starting points; the two preliminary tiers and what reaches
the release; the pg_duckdb bridge for reading a release from psql. Links `server-access.qmd` for accounts.

**`ingest-loop.qmd` — Ingesting a dataset.** The RUNBOOK made public and short: the five skills, the
artifacts each writes, `in_release: false`, what `/validate-ingest` checks, how a question reaches a
provider. For the data team and any future contractor.

**`products.qmd` — Products, brand and uptime.** One table of every product with its section, uptime and
usage links (generated from `products.yml`), the three-slug contract in three sentences, brand v2 in one
paragraph with the link, how to add a product (the brand-contract skill's checklist, condensed).

**`dmp.qmd` — The data management plan.** The five phases with the tasks under each (owner, status,
target date, the deliverable and where it lives — a chapter, a repo, a Sheet), read from
`data/dmp_tasks.yml`. Mark's ask, on a page.

**`architecture.qmd` — Architecture.** The federated system: sources on Drive → GCS; the pipeline;
the release store; the catalog record and the portals; the apps and packages; the PostgreSQL working store;
the server stack; where each URL is served from. The 2022 figure beside the 2026 diagram as *then and
now*. This is Task 14's Q4 document; its skeleton and the diagram land in S2 so it grows rather than
appears.

**`glossary.qmd`.** Terms a provider or a new reader trips on: cruise, cast, bottle, tow, net, site, line
and station, grid cell, hex, realm, grain, measurement type, life stage, sample vs observation, release,
holding, sidecar, catalog, provider, dataset key. Each entry ends with the chapter that says more.

## Verification

- `quarto render` locally to HTML with zero warnings; `libs/check_tables.R` passes `as_word()` and
  `as_latex()` on every gt chunk; `build-documents` produces the pdf and docx; the pdf shows every SVG.
- `https://calcofi.io/docs/cite.html` answers 200; every retired page's old URL answers 200 via alias.
- `libs/check_links.R`: no 404/410 in the rendered book; `CalCOFI.github.io/scripts/check_brand.py` passes
  for docs **including the `lockup` probe**.
- `grep -rn "parquet/" *.qmd` shows no hand-built release path; `grep -rn "obs\b" data-access.qmd` finds
  `obs` only where the view is being explained.
- Lightbox opens every diagram; no `chromium` string remains in `render_book.yml`; `package.json` pins
  mermaid-cli and `diagrams/*.svg` match `diagrams/*.mmd` (a CI step re-renders and `git diff --exit-code`).
- After S3's release: `integrity.json` present, all PKs distinct, zero orphans on non-nullable edges;
  db-schema lists **23** tables by default; `keys.qmd` shows the measured table.
- Walkthroughs, one per audience, before Q1 closes: Betty follows `provide.qmd` against a dataset she
  knows; Rasmus or Ben G. follows `ctd-qaqc.qmd` from an empty laptop; Erin reads Start here and Part I
  cold; a data scientist outside the team runs `data-access.qmd`'s Python path. Each walkthrough files
  what stopped them as a docs issue.
- The Q1 status entry (2026-11-30) cites the chapters that satisfy Task 11's guidance doc and Task 12's
  inventory, with URLs.

## Decisions taken (Ben, 2026-09-08)

1. **Book, not website.** The single PDF/DOCX is the living document; D4 keeps it from blocking the site.
2. **The DMP mirror is `docs/data/dmp_tasks.yml`**, an authored copy of the private Sheet's Status tab,
   refreshed with each quarterly status entry. The docs build never depends on Google auth.
3. **db-schema shows supplemental tables by default**, badged (D6 d).
4. **Betty drafts in the Google Doc until the guide is agreed (Q3)**; then `provide.qmd` is the record and
   the Doc is frozen with a link to it. To confirm with Betty and Erin on 9/8.
5. **`maps.qmd` is retired outright**, not kept as an appendix: the Explorer computes hexagons in the
   browser, and the Shiny apps it documented as consumers — `db-viz-hex` included — are superseded by the
   Explorer. The H3T service stays running for the superseded apps as legacy maintenance (S9); its
   explainer leaves the book, and `maps.html` aliases to the Explore chapter.

## Kickoff prompts

**S0 + S1 (Sonnet).** *Read `.claude/plans/2026-09-08 Docs revamp ….md` § D3, D4, S0, S1. In
`../docs`: add `cite.qmd` to `_quarto.yml` chapters after `data-access.qmd` and confirm
`https://calcofi.io/docs/cite.html` renders after deploy; close CalCOFI/docs#5 with a comment pointing at
data-access.html; fix the two `db.qmd` lines named in S0. Then the build: `package.json` pinning
`@mermaid-js/mermaid-cli@11.12.0`, `libs/render_diagrams.sh`, render and commit the six SVGs, switch every
`{mermaid}` chunk to an SVG figure with `.lightbox`, `lightbox: true`; `libs/pre-render.R` writing
`data/` from the promoted release and the registries, `freeze: auto`; split `render_book.yml` into
`publish-html` (Ubuntu) and `build-documents` (pdf + docx, non-blocking, artifacts + `gh-pages/downloads/`);
`libs/check_tables.R` and `libs/check_links.R`; drop epub. Verify per § Verification bullets 1–4. Do not
touch chapter prose beyond the two S0 lines.*

**S3 (Fable).** *Read § D6 and S3 of the same plan and `workflows/CLAUDE.md` §§ "Release tables are
content-addressed", "Provider UUIDs…". In `calcofi4db`: `core_relationships()` declares a PK for every
released table (measure the composites before declaring them); `check_core_pk_unique()` accepts composite
keys; new `check_release_relationships()` writes `integrity.json` and errors on any PK violation or
non-nullable orphan; `validate_for_release()` drops the dead `expected_tables` default; tests with small
fixtures for each rule; NEWS + version bump. In `workflows`: `relationships_cross.csv` gains `released`
(false on the 28 phantom rows), `merge_relationships_json()` emits released rows only, `release_tables.csv`
gains `sample_root` and `sample_spatial` and drops `obs_freq`, `release_database.qmd` calls the new check
after `cruise_key_integrity`, `test_release.qmd` gains the contract row, `RELEASES.md` § Unreleased gets
the entry. Stage first with both staging prefixes; verify `integrity.json` and that the real prefix is
untouched. Then db-schema: Keys column, Columns tab PK/FK marks, supplemental shown by default with badge.*

**S2 + S4 (Opus), after S1.** *Read the plan §§ D2, D5, D7, S2, S4, § Decisions taken and the per-chapter
specs. Build the parts skeleton with aliases (`maps.html`, `apps.html`, `reports.html` → `explore.html`;
`helpers.html` → `data-access.html`), delete `maps.qmd`, its three diagrams and the `int-app` screenshot,
rewrite `index.qmd`, draw `diagrams/system.mmd`, then Part II: trim `db.qmd`,
write `keys.qmd` (render "not yet measured" until `integrity.json` exists), `releases.qmd`, and
`naming.qmd` generated from the registries with the legacy→standard mapping built from
`field_dictionary.csv` aliases and every `metadata/*/*/flds_redefine.csv`. Every number comes from
`data/`; every table is checked by `libs/check_tables.R`.*

## Appendix A — chapter audit (reviewing agent, 2026-09-08, condensed; `file:line` refer to `CalCOFI/docs` at `b2440d2`)

Ground truth: `workflows/CLAUDE.md`, `RELEASES.md`, `metadata/*`, the frozen `v2026.09.06` sidecars,
`calcofi4r/NAMESPACE` (1.22.0), `products.yml`, `brand/v2/README.md`, `server/caddy/Caddyfile`,
`uptime/.upptimerc.yml`, `db-viz-hex/app/functions_h3t.R`, `scripts/deploy_consumers.sh`.

### A0 — two structural facts

- **`cite.qmd` was removed from `chapters:` by the brand-v2 commit `9083a87` (2026-09-04)** — its diff
  shows `-    - cite.qmd` beside the logo edits. `_book/` holds `cite.qmd` copied as a resource, no
  `cite.html`. Four live links point at it: `db.qmd:390`, `portals.qmd:224`, `portals.qmd:436`,
  `metadata.qmd:159`. **Re-adding it alone will break CI**: `cite.qmd:25` does
  `librarian::shelf(calcofi4r, DBI, …)` — `calcofi4r` is GitHub-only and absent from `DESCRIPTION`, so
  `shelf()` tries CRAN and fails; `:27` `cc_get_db()` and `:82` `dbReadTable()` open a live release
  connection with no `tryCatch`. S0 must add `Remotes: calcofi/calcofi4r` to `DESCRIPTION` and guard the
  chunks the way `portals.qmd` does.
- **No chapter mentions the Explorer.** `apps.qmd` (9 lines) omits it and 14 other `products.yml` cards,
  while `portals.qmd:438` promises "the Explorer, Station and Hexagon Explorers, CTD Transects" at
  `apps.qmd` and `metadata.qmd:147` sends readers to the Explorer's feedback button.

### A1 — per chapter (what it is, how stale, live chunks)

| chapter | audience as written | staleness | live chunks |
|---|---|---|---|
| `index.qmd` | first visitor | body paragraph unchanged since 2024-09-09, describes 2022; `:12` links `github.com/CalCOFI/scripts` (no such repo), says ingest is by "R scripts", the API feeds Shiny apps, PostGIS will do the areas of interest, calcofi4r is "Read / Analyze / Visualize" (1.22.0 has 119 exports across catalog, cite, release_sources, qual, postgres, interpolate, brand, feedback, analytics) | none; mermaid `:21` |
| `reports.qmd` | none | one commit, 2024-09-09 | none |
| `apps.qmd` | end users | `:7` `shiny.calcofi.io/oceano` — **retired 2026-09-07**, `products.yml:186-197` `superseded_by: explore`, the 308 redirect exists only on `app.calcofi.io` (Caddyfile:184-196), so this link is dead; `:9` capstone at the legacy host and `status: archived` | none |
| `maps.qmd` | "the curious oceanographer and the developer" | written 2026-04, URL renames only since; see A3 | none; three mermaid |
| `db.qmd` | engineers/analysts | rewritten 2026-09-03 (WS-H2); two 2024 islands (§ Naming header, § *Use Unicode for text* `:83-157` — a PostgreSQL `psql -l` transcript listing `gis`, `lter_core_metabase`, `template_postgis`, sqlalchemy/RPostgres snippets, nothing about the release) | none; mermaid `:299` (`db_doc.mmd`, see A4) |
| `metadata.qmd` | providers + data team (stated `:3-6`) | new 2026-09-07 | `:38-61` reads `dataset_meta_fields.csv` from **GitHub `main`**, not the release |
| `data-access.qmd` | analysts | frozen 2026-08-25, **before the `obs_bio`/`obs_env` release**; see A2 | none — every example is static; nothing verifies the printed URLs |
| `server-access.qmd` | the CTD team (accounts named `:53-57`) | 2026-08-26; `:15` says "public releases (`v2026.08.14` …)"; `:38` stack table maps Varnish to h3t and omits the `h3t_api_py` origin container | none |
| `helpers.qmd` | R users leaving the API | unchanged since 2026-05-18; `:20` "calcofi4r ≥ 1.2.0"; `:137` joins `bottle` to `cast_condition` (neither exists); `:186-187` "recursive walk of `taxon.parentNameUsageID`" — the column is `parent_taxon_key`; `:68-75` is a hand-pasted tibble | none |
| `api.qmd` | API users | unchanged since 2026-05-15; `:47` "direct SQL against `ctd_cast` / `ctd_thin`" (neither exists) | none |
| `portals.qmd` | data managers + providers (parts read as internal runbook: EDI/OBIS credential steps) | most active chapter, five commits 2026-09-07 | three: `:44-86` `here("data/portal.csv")` — a **hand-copied snapshot** of `workflows/metadata/portal.csv` with no sync, while `:38-42` tells the reader it is generated; `:273-339` and `:368-419` fetch `latest.txt` + `datasets.json` live with `tryCatch` fallbacks |
| `status.qmd` | program stakeholders | newest entry 2026-07-01; `:17,:25,:27` "44 tables" / `v2026.06.08` (retired) read as present tense; `libs/status_git-logs.R:11` hard-codes `date_beg <- "2025-07-01"` and `:16-18` seven repos, omitting explore, db-schema, db-query, db-viz-station, ctd-transects, api-h3t-py, calcofi4py, uptime, analytics | none |
| `cite.qmd` | anyone publishing | orphaned (A0); `:40-44`, `:62-64`, `:161-169` still apologise that `cc_cite()` "is not yet on an installed calcofi4r" — it is exported at 1.22.0, so the whole `cite-r-fallback` chunk and the prose are dead weight; `:73-76`, `:84-88` warn the release may lack the attribution columns — `v2026.09.06` `dataset` carries `doi`, `license_url`, `acknowledgement`, `contact`, `source_accessed`, `source_accessed_method` | six (`cc_get_db()`, `cc_catalog("latest")`, `dbReadTable("dataset")`, …) |
| `refs.qmd` | — | 2024-09-09; inert R chunk `:3-7` | — |

### A2 — the largest gap: `obs_bio` / `obs_env` and hand-built paths (`data-access.qmd`)

- **Neither `obs_bio` nor `obs_env` appears in 559 lines.** The bucket tree `:27-45`, table list `:70-76`,
  partition section `:155-225`, R/Python `:227-332`, browser `:334-384` and the 95-line worked example
  `:462-556` all teach `obs` as the physical store — whose objects drop in the **next** release.
- `:70-76` and `:157` say `obs`, `obs_ctd_full`, `obs_mets_full` are partitioned by `dataset_key`. Measured:
  `obs` → `dataset_key` (16) ✓; **`obs_ctd_full` → `cruise_key` (134 objects)**, **`obs_mets_full` →
  `cruise_key` (49)**, **`obs_env` → `measurement_type` (84)**, **`climatology` → `measurement_type`
  (71)**. Three of five partition columns wrong, two partitioned tables unlisted.
- `:284-306` teaches the `cc_qual_ok_sql()` predicate; the pair now ships a materialised **`qual_ok`**
  column that no chapter mentions.
- **Ten hand-built `v2026.08.25/parquet/…` URLs** (`:134, :148, :149, :198, :219, :475-478, :501`, four of
  them `s3://…/obs/**/*.parquet` globs) twelve lines after `:56-57` states "never build a `parquet/` path by
  hand"; `server-access.qmd:338, :348` add two more (`v2026.08.14`). All cited versions are consolidated so
  they resolve — the rule is stated in three chapters and violated in two.
- `:30` "`latest.txt` … e.g. v2026.08.25" (two releases behind); `:104` links `RELEASES.md` but nothing
  states its editorial contract.
- Duplicated with `helpers.qmd`: three near-identical "Run it from anywhere" tables (`helpers:118-125`,
  `data-access:396-403`, prose) and two copies of the sardine example whose caveat "environmental data ends
  2021-05" (`helpers:86-89`, `data-access:439-443`) is asserted in two places and measured in neither —
  the release measures it in `dataset.coverage_temporal`.

### A3 — `maps.qmd` (H3T) is wrong in the particulars

- `:147-150`, `diagrams/h3t-sequence.mmd`, `:59, :60, :117`: "Plumber API" — production is **`api-h3t-py`,
  FastAPI** (`deploy_consumers.sh:114` restarts `h3t_api_py`).
- `:40`, `:98-107`: the template placeholder `hex_h3res{{res}}` and `WHERE scientific_name = …` — the code
  emits `h3_cell_to_parent(hex_id, {{res}})` and filters `taxon_key IN (…)` (`functions_h3t.R:14-19, :60-64,
  :88-92`); per-resolution columns are the pre-core design the release abandoned.
- `:38` + `h3-pyramid.mmd`: H3 edge lengths shifted one resolution (res 1 "~1106 km" is res 0's; "~158 km"
  is res 2 not 3; "~22 km" res 4 not 5; "~3.2 km" res 6 not 7; res 10 is ≈ 66 m, not 7.5 m); `:17` "equal
  area" overstates (±20 %).
- `:80-82` "asks `/h3t/meta` … no purge command": db-viz-hex derives the release from the DuckDB path
  (`global.R:262-302`), and `deploy_consumers.sh:10-25` documents the exact stale-inode failure this
  paragraph says cannot happen; the real deploy is a container restart **plus** a Varnish ban.
- `:137-139` + `h3t-release.mmd`: "a working DuckDB database … publishes a versioned DuckDB file" — there is
  no working DuckLake; the release is parquet + `catalog.json`; the DuckDB file is h3t's own consumer
  artefact.
- `:5` links `shiny.calcofi.io` as "the interactive app"; `:7`, `helpers:82, :105`, `data-access:394, :413,
  :456`: six `[Integrated App](https://app.calcofi.io/db-viz-hex)` — the name `products.yml:2-4` forbids and
  a URL Caddy 308s to `/hex/`. `figs/int-app_map-compare-bio-env.png` keeps the retired name and is an
  un-themed 2026-04 shot.

### A4 — `db.qmd` particulars (beyond what D6/D7 already fix)

- `diagrams/db_doc.mmd` (`:299-303`) is the stalest artefact in the book: `calcofi4db: create_db.qmd`
  (deleted), redefine CSVs under `calcofi4db: ingest/…` (they are `workflows/metadata/…`), an `API
  Endpoint /db_tables /db_columns` node with a `click` to `api.calcofi.io` (retired), a *Database
  Comments*-in-Postgres subgraph, `publish_{dataset}_{portal}.qmd` (they are `publish_to-{portal}.qmd`), a
  `click` to a **personal** Drive folder. Retire it; `system.mmd` (S2) replaces it.
- `:167-175` core-model table omits `sample_root` and files `climatology` under reference tables; omits
  `obs_bio`/`obs_env` from the tier table although `:182-209` calls both core; `:208` is the only mention of
  `root_id`/`hex7`; the pair's columns (`year`, `quarter`, `depth_bin`, `units`, `effort_class`, `qual_ok`)
  are listed nowhere.
- `:31` files `hex_id` as "a source counter or surrogate" (it is an H3 cell index). `:72-77` callout on
  `source_uuid`/`station_uuid` "land with the provider-UUID workstream" — they ship. `:79-81` sort orders
  for `site_id`/`tow_id`/`net_id` — tables that do not survive to the release; the release's own sequential
  key, `root_id`, is undocumented. Nothing explains that `cruise` has **842** rows, not 691 —
  `complete_cruise_reference()` adds one row per key the SWFSC export lacks (`cruise_key_method =
  'derived'`).
- `:390` and `:440-441` say citation/license/doi live in the **notebook YAML**; `metadata.qmd:28-30` says
  `dataset_meta.yml` — the two chapters contradict each other, and `check_dataset_meta_split()` errors on
  the former.
- `:426-427` names `coverage_temporal_observed` / `coverage_bbox` as columns on the released `dataset`
  table — the table's columns are `coverage_temporal` / `coverage_spatial` (measured values under the
  plain names).
- `:399, :403` "metadata.json schema 1.1" (shipped: **1.2**, with undocumented `contributions` and
  `erd_legend`); `:404-417` example uses `v2026.05.14` and a `bottle` table; `:481-488`
  `cc_describe_table("bottle")`, `cc_db_catalog(tables = c("bottle", "ichthyo"))` — no such tables;
  `:471` deep-links `#erd?v=v2026.05.19` — **retired**; `:454-456` sample citation says v2026.08.25 with a
  `zenodo.NNNNNNN` placeholder — the real DOI is in `catalog.json`.
- `:499-501` lists an NCEI publisher (none exists; netCDF is unlisted); `:506-508`, `:600-601` say a generic
  `publish_to-obis.qmd` "is planned rather than built" while `portals.qmd:151-167` documents the built one —
  **a direct contradiction**. `:510-523` ERDDAP paragraph is current.
- Taxonomy `:227-251` is right; omits `ncbi_id`/`inat_id` on `taxon` and the 2026-09-04 override rule.
  `:356-390` registry table lacks nine of CLAUDE.md's registries (`dataset_meta.yml`,
  `dataset_meta_fields.csv`, `dataset_status.csv`, `distribution.csv`, `distribution_observed.json`,
  `portal.csv`, `holdings.csv`, `taxon_group.csv`, `questions_sheets.yml`).

### A5 — documented nowhere

The per-table key/FK/uniqueness contract and where to read it (`relationships.json` gets one clause at
`db.qmd:605`, `relationships_all.csv` none) · the gates and ratchets (`check_cruise_key_integrity`,
`check_obs_pair_parity`, depth, bounds, `check_taxon_ids`, `check_dataset_citation`, the ratchet
constants) · `test_release.qmd`'s consumer contract and `test_results.json` · the Explorer and its six
lenses, the Sources line, `?modal=sources`, the CSV `dataset_key` column · the release process, the
`# Unreleased` rule that stops a release, the concept + version DOIs, `publish_release_notes.R` · the brand
contract · the ingest skills loop and `in_release: false` as an engineering flag · the release sidecars
the bucket tree omits (`coverage.json`, `coverage_stations.json`, `datasets.json`, `datasets/`, `eml/`,
`erd.mmd`, `grid.geojson`, `spatial.geojson`, `spatial_layers.json`, `stac/`, `relationships_all.csv`,
`test_results.json`) · where `ship` (49 rows) and `spatial`/`region` come from
(`ingest_ices.dk_ship-ices.qmd`, `ingest_spatial.qmd` — not datasets) · the bathymetry artefacts ·
`climatology` as a table a consumer subtracts.

### A6 — mermaid, brand, build residue

- Eight `{mermaid}` chunks, all `%%| file:` includes; six `.mmd`, all used; **`catalog_flow.mmd` included
  three times and `index.qmd:22` + `metadata.qmd:112` both declare `#| label: fig-catalog-flow`** — a
  duplicate cross-reference label. No `lightbox` anywhere. No `mermaid-format` set, so HTML is client-side
  and **every non-HTML format goes through the Chromium the workflow installs** — the hang path, eight
  diagrams × three formats per push. Nothing pins mermaid (Quarto is unpinned in CI, so the bundle is
  whatever ships that day); `db_doc.mmd`'s `classDef hidden display: none` and `~~~` links,
  `catalog_flow.mmd`'s labelled dotted edges and `&` fan-out, `h3-pyramid.mmd`'s `{{res}}` inside a label
  are all version-sensitive.
- **Brand**: `_quarto.yml:57-58` loads the **mark** (`logo_calcofi.svg` / `_light`); `brand/v2/README.md:19,
  :152` require the **horizontal lockup** (`logo_calcofi_h*.svg`), and `check_brand.py`'s `lockup` probe
  looks for `img[src*="logo_calcofi_h"]` — a `shots: themed` v2 product must pass it. The `title: docs`
  beside a mark is the v1 pattern. Verify against the weekly check before assuming; fix in S0 if it fails.
  Cookie chain, fonts, favicon are correct.
- **Residue tracked in git**: `apps.html`, `index.html`, `maps.html`, `reports.html`, `test.R`, `test.txt`,
  `webshot.png` (2.8 MB), unused `figs/contrib.rocks.svg`. `README.md:27` tells a contributor to clone
  **`ioos/bio_data_guide.git`**. `DESCRIPTION` is package boilerplate ("What the Package Does", `YOUR-ORCID-ID`,
  `ben@ecoquants.com`) and lacks `glue`, `jsonlite`, `purrr`, `tidyr`, `tibble`, `DBI`, `calcofi4r`.
  `libs/manual-updates.R` (Mar 2025) is the only thing that refreshes `figs/sw_arch.svg` and
  `refs/packages.bib`. `libs/post-render.R` deletes any root directory matching `_files|site_libs`.
- **Build**: `render_book.yml` pins nothing (Quarto, R, packages); four consecutive failures 2026-09-07
  (`34110115747`, `34136142730`, `34136193445`, `34136615485`) all from docx/pdf escaping of live table
  content; earlier instances 2026-05-18 (shields badge broke LaTeX), 2025-01-28 (four commits on the Chrome
  env var), 2024-11-22 (qpdf). Four chunks fetch the network at render (`portals.qmd:283, :287, :376-382`,
  `metadata.qmd:46`), guarded, so a degraded render **publishes** a book saying "no datasets.json yet" with
  no alert. No link check, though `build_workflows_index.R` already has the probe to reuse.


## Executed (2026-09-08, 01:30–04:00 CEST)

| slice | done | deviations, findings |
|---|---|---|
| S0 hotfix | `cite.qmd` back in the nav (it had been dropped by the brand-v2 commit; live 404 → 200), the v2 lockup in the sidebar, `DESCRIPTION` real, residue untracked, `README` clone URL, the five `db.qmd` fixes, `apps`/`reports` dead links, docs #1/#4/#5 closed, the docs card's description | — |
| S1 build | `package.json` pins mermaid-cli 11.12.0; `libs/render_diagrams.sh` → committed SVGs; `libs/pre-render.R` snapshots the release sidecars, the `dataset` table (through the catalog, with `duckdb`), fourteen registries, sixteen field crosswalks and `products.yml` under `data/`; `render_book.yml` is two Ubuntu jobs (html blocking with `libs/check_links.R`; pdf + docx non-blocking → the rolling `documents` release the sidebar links); Quarto 1.8.25 and R 4.5.1 pinned; epub dropped; `libs/check_formats.sh` | **no `freeze: auto`** — Quarto's freeze hashes the source, not `data/`, so a snapshot change would never re-execute a chunk. mermaid's `foreignObject` labels are invisible to librsvg and each word is a tspan with a leading space that librsvg strips: plain SVG text + `xml:space="preserve"` in the script. `calcofi4r` left `DESCRIPTION` (GitHub-only, needless in CI once `cite.qmd` reads the snapshot). |
| S2 skeleton | five parts + appendices; `index.qmd` Start here; `diagrams/system.mmd`; `explore.qmd` replaces `apps`/`reports` (aliased with `maps.html`) with the apps table generated from the cards | — |
| S3 integrity | calcofi4db **4.7.0** (`check_release_relationships()`, PKs for the twelve tables, the dead completeness default gone, five tests) pushed; workflows: the `relationship_integrity` chunk after `browser_objects`, `test_release` contract row, `release_tables.csv` (+`sample_root`, +`sample_spatial`, −`obs_freq`), thirteen measured edges in `relationships_cross.csv`, `RELEASES.md` § Unreleased; db-schema: `integrity.json` fetched, a keys line per table card (✓ measured / ✗ / declared), a key column on Columns, supplemental shown by default, four pure helpers with tests | **Measured on v2026.09.06: 23 PKs, 57 FKs, all ok.** The cleaned `relationships.json` and the new `integrity.json` were computed on the local copy and uploaded beside the promoted release's catalog (sidecars, not data). **One edge deliberately undeclared:** `obs_mets_full.sample_key → sample` resolves for 73,607 of 2,168,850 keys (18,990,343 orphans) — workflows #78. No real release was cut; the gate runs at the next one. `CLAUDE.md` was not edited: another session had it mid-refactor into skills (uncommitted); one sentence pointing at `integrity.json` belongs under its keys section when that lands. |
| S4 Part II | `db.qmd` trimmed (naming/keys/versioning/relationships out; the PostgreSQL-only Unicode section gone; the core table rewritten around the pair; the nine missing registries; schema 1.2; the 23-table inventory generated); `keys.qmd` (rules, the UUID answer, the core ERD, the contract per table and the measured tables, the gate table, worked SQL); `naming.qmd` (every registry as a table, the dataset nomenclature, the legacy crosswalk per dataset as HTML tabs); `releases.qmd`; `_gates.qmd` shared | `datetime` is the released `sample` column, not the dictionary's `datetime_start_utc` — three chapters corrected. |
| S5 Part I + IV | `data-access.qmd` rewritten around `obs_bio`/`obs_env` with no hand-built path, the two-paths table (Task 11), the partition table generated, `qual_ok`, the matching helpers absorbed (`helpers.qmd` retired, aliased), the API map collapsed; `server-access.qmd` paths and stack row; `ctd-qaqc.qmd`, `ingest-loop.qmd`, `products.qmd` | The matching example is not executed at render (calcofi4r is not in CI); its coverage caveat is read from `dataset.coverage_temporal`. |
| S6 Part III | `provide.qmd` — Betty's guide in the book's voice with audience and purpose, mandatory / optional / best practice, an example table, what happens next, and the seven reconciliations (registry wins; `M2`'s size flagged for SWFSC); `portals.qmd` left as is (current; the EDI/OBIS steps are useful to the data team) | Betty and Erin still own the prose; the Doc stays the drafting venue until Q3. |
| S7 Part V | `data/dmp_tasks.yml` (tasks 1–23 from the Sheet) + `dmp.qmd` with the SoW's quarters; `architecture.qmd` (Task 14's document, with the URL table and then-and-now); `status.qmd` gains a 2026-09-08 baseline entry by phase; `libs/status_git-logs.R` reads its repo list from the cards | — |
| S8 appendices | `glossary.qmd`; `api.qmd` one page; `maps.qmd` retired with its diagrams and the `int-app` shot; `helpers.qmd` retired | — |
| S9 landing | `db-viz-hex` and `db-viz-cruise` cards `status: superseded`, `superseded_by: explore` (the Shiny apps; `ctd-viz` stays — DMP Task 21 is the CTD viewer; `pollutants` stays) | — |
| the lightbox (Ben, 02:50) | replaced for diagrams by `libs/diagram.js` + vendored `svg-pan-zoom`: every `.cc-diagram` figure becomes an inline SVG with +/−/reset, drag, and a fullscreen button; wheel-zoom only in fullscreen; pdf keeps the static image | the first cut resized every rect in the SVG (a regex on all `width=`), fixed to the root element only. |
