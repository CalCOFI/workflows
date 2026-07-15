## TODO

- RENAMEs: the colloquial name "datacheck" in db-viz-cruise runtime JS keys / CSV-download name / code comments (identifiers & paths were changed); image filenames like *int-app*.png; NEWS.md, historical plans, your libs/calcofi_notes.md; rendered Quarto .html (need a re-render); uptime history/graphs + site display-names (keeps history slugs intact).
- crosswalk: calcofi.org + erddap (coastwatch + oceanview) + EDI + OBIS + other (ZooDB, ...): and compare extent temporal + spatial, row count
- schema:
  redundant `{date}`: `v{date} - {date}`
  why starred `*v2026.06.07` when newer `v2026.06.08` available?
  what generalizable patterns can we employ from schema, eg across bio or env data capture? for tbls w/combined datasets perhaps add dataset column to capture which dataset contributed
- review [CalCOFI - EcoQuants Quote, 2025-10 to 2026-06\\_v2.docx - Google Docs](https://docs.google.com/document/d/1rU6TrhVeHsUsVInNgIY7bcMk7TWfumyy/edit#heading=h.ct1c5e8orm6z)
  crosswalk deliverables to actual
- check GDrive and GCS sync on server, per [rclone](https://github.com/CalCOFI/server/tree/main/rclone)
- [ ] ∆ repo names: schema -> db-schema; query -> db-query; all repos + nav items DB Schema | DB Query
- [ ] homepage: refresh int-app; default all apps to light mode; archive some (Copernicus, Larval, Viz, Dashboard, API) with accordion; 
      mv Hypoxia Story to students; 
      add "uptime" link to ea card
      add "usage" link to ea card -> dedicated usage repo Google Analytics per output; 
      mv services (ERDDAP, file server, h3 tile, uptime) to own section w/out screens
      retire pg_tileserv (and update docs/ to pmtiles usage)
      - [Claude: Automating website analytics tracking with Github Actions](https://claude.ai/chat/107e346a-7f07-451e-a624-58777c0b13b4)
      - [Gemini: Automate GA4 Usage Data Pipeline](https://gemini.google.com/app/7c7a5dc67af69fc5)
      - [run_report_with_dimension_exclude_filter.py · googleanalytics/python-docs-samples](https://github.com/googleanalytics/python-docs-samples/blob/main/google-analytics-data/run_report_with_dimension_exclude_filter.py)
      add api-h3t-py to services
- [ ] Check that upptime catches app error messages (eg 500 vs not found 404)
- [ ] Drop vestigial `calcofi4db::get_working_ducklake()`
  Admin "Working DuckLake" (calcofi4db::get_working_ducklake()) — despite the name, it's a
  plain DuckDB file, not a true DuckLake (no ATTACH … TYPE ducklake anywhere). If used,
  finalize_ingest() materializes parquet into it (CREATE TABLE AS SELECT * FROM read_parquet(…)),
  which would duplicate the data inside the .duckdb. But in the current pipeline it's vestigial:
  (a) none of the 4 ingests call finalize_ingest, (b) gs://calcofi-db/ducklake/working/ is empty
  (no object there), and (c) release_database doesn't read it — it builds an in-memory DuckDB
  with VIEWs over local parquet. So there's nothing to reset.
- [ ] see below `### /btw are the h3t json files being compressed between server and browser? or …`
- publish inverts dataset to OBIS from `ingest_swfsc_ichthyo.qmd` and filter properly for existing `publish_ichthyo_to_obis`
- re-run with Ed's latest ichthyo updates. Should've failed b/c not capturing new CSV files, so need to fix.
- [ ] after rclone finishes sync, targets invalidate and run all QMDs (redo/overwrite = F) and git commit
- [ ] cleanup buckets, share w/ UCSB datascience
  - missing `calcofi-db/ingest/_spatial`
    (but see `calcofi-db/ducklake/releases/v2026.04.03/parquet/_spatial.parquet`)
- [ ] note missing relationships: *_summary tables, grid, places, segments
- [ ] rename `swfsc_inverts` to `swfsc_invert` including `ingest_swfsc_inverts.qmd` -> `ingest_swfsc_invert.qmd`
- `ingest_calcofi_ctd-cast.qmd` needs a sync to GCS for just the used CSV files so saved in GCS `archive/`, not just GCS `_sync/`
- check db validation:
  https://calcofi.io/workflows/release_database.html#validate
  ```
  Warning: cruise_key format violations: 1 rows
  Validation FAILED:
  - Table 'casts' has 298 NULL values in required column 'grid_key'
  - Table 'casts' has 49 NULL values in required column 'ship_key'
  - Table 'casts' has 49 NULL values in required column 'cruise_key'
  - Table 'ctd_measurement' has 3773585 NULL values in required column 'ctd_cast_uuid'
  - Table 'ctd_measurement' has 3773585 NULL values in required column 'cruise_key'
  - Table 'dic_measurement' has 12683 NULL values in required column 'cast_id'
  - Table 'dic_measurement' has 12721 NULL values in required column 'bottle_id'
  - Table 'dic_sample' has 3305 NULL values in required column 'cast_id'
  - Table 'dic_sample' has 3326 NULL values in required column 'bottle_id'
  - Table 'dic_summary' has 12592 NULL values in required column 'cast_id'
  - Table 'dic_summary' has 12611 NULL values in required column 'bottle_id'
  - Table 'site' has 2084 NULL values in required column 'grid_key'
  - Table 'species' has 170 NULL values in required column 'gbif_id'
  ```
  

## 2026-07-15 schema: env-bio consolidation;

PROMPT: Implement @design_env-bio-consolidation.md. This will require rewriting all the ingest notebooks. The CLAUDE.md, README.md and .claude/skills should also be updated. Now that we're consolidating tables we need improved reporting on rows and percentage contributions of each dataset to each table in the db-schema, ideally in a visually compelling simplified way (think stacked bar with color coding and dataset label on hover). I am also noticing that the cards at https://calcofi.io/workflows/ for each ingest are reporting incorrect statically defined temporal extents -- these should come from the database, not from outdated QMD frontmatter. We will need to re-render all QMD notebooks to HTML. I want the DAG to be added to the bottom of the workflows index page (like ../../MarineSensitivity/workflows/) with color coding and subgraphs by type.

----

I've now mapped all five surfaces: the ingest notebooks, calcofi4db, release_database.qmd, the db-schema site, and the workflows-index/DAG machinery. A few key findings shape the plan:

- **Phase 1 is already done** — v_obs_env/v_obs_bio/v_obs views in release_database.qmd (chunk obs_views, L260–360) are the exact blueprint for materializing obs/sample/etc. So this task is design-doc Phases 2–4.
- **`calcofi4db` has no test suite yet** and the new build_*_reference()/append_*() family naturally lands in a new R/model.R. Notebooks today call write_parquet_outputs() + build_metadata_json() + sync_to_gcs() (not finalize_ingest()).
- **The stacked-bar reporting is already 90% plumbed** — metadata.json v1.2 already carries contributions[table].by_dataset[].{rows,pct,provider_dataset} + erd_legend colors; the missing piece is the chart in db-schema/app.js. Crucially, it only becomes visually meaningful after consolidation, because today almost every table is single-dataset — but obs/sample will be genuinely multi-dataset.
- **The DAG pattern is fully portable** from MarineSensitivity/workflows (tar_mermaid() + color_dag() + a #dag section). Temporal extents are static YAML today; the fix is a SELECT dataset_key, min/max(datetime) FROM v_obs persisted into the release metadata.json, read by build_workflows_index.R.

This is a large multi-repo epic with some genuinely branching decisions that change effort and risk substantially. Let me confirm the four that shape the whole plan before I design further.

←  ☒ Cutover  ☒ Execution  ☒ Consumers  ☒ Chart  ✔ Submit  →

**Cutover** How should the ingest notebooks adopt the new core model (obs / sample / obs_freq / sample_measurement)? This is the design doc's Phase 2 vs Phase 3 distinction and drives most of the effort.

❯ 1. Phased (Recommended) ✔       ┌───────────────────────────────────────────────────────────┐
  2. Full cutover now             │ Step 1: calcofi4db::build_sample_reference()/append_* +   │
  3. Centralized only             │   CREATE TABLE obs/sample/... in release_database.qmd     │
                                  │ - parity assertions (counts match per-dataset)            │
                                  │ Step 2: rewrite each ingest_*.qmd to append_obs()/        │
                                  │   append_sample()/... ; per-dataset tables -> VIEWs       │
                                  └───────────────────────────────────────────────────────────┘

**Execution**

Should I actually execute the pipeline + cut a new GCS release as part of this, or deliver the code/notebook changes ready for you to run? (CTD ingest alone is ~216M rows / hours, and the release uploads to gs://calcofi-db.)

❯ 1. Code-ready, you run (Recommended)
     I implement all code, notebook edits, docs, tests, and the db-schema/index changes, and run what's cheap to verify locally (unit tests, a small notebook or two). You run the full tar_make(), the heavy CTD render, and the freeze+GCS release when ready.
  2. I run everything ✔
     I also run targets::tar_make() end-to-end (incl. the multi-hour CTD notebook), render all 14 notebooks to HTML, freeze, and upload a new versioned release to gs://calcofi-db. Requires GCS credentials to be available in this environment.
  3. I run all but CTD + upload
     I run tar_make/render for all datasets except the heavy CTD notebook, and stop short of the GCS upload. You do the CTD render and the release upload.

**Consumers**

Does this effort include repointing the downstream consumers to read the new obs/sample tables, or keep them working via compatibility VIEWs and defer?

❯ 1. Compat VIEWs, defer apps (Recommended)
     Keep every per-dataset table name (bottle_measurement, ctd_cast, site/tow/net, etc.) as a VIEW over obs/sample so calcofi4r + db-viz-hex + station portal + db-viz-cruise keep working unchanged. Repoint them to obs/sample as a separate follow-up (design Phase 4). Keeps this epic self-contained to the workflows/calcofi4db/db-schema surface.
  2. Also repoint calcofi4r + apps ✔
     Additionally update calcofi4r read helpers to expose obs/obs_freq/sample/obs_ctd_full, and repoint build_stations.sql, db-viz-hex prep, and db-viz-cruise to GROUP BY over obs. Larger multi-repo surface in this same effort.

**Chart**

For the db-schema contribution reporting (stacked bar, color-coded, dataset on hover), where should it live?

❯ 1. Tables/Datasets cards (Recommended)  │ obs        [██bottle██|█ctd█|dic|██ichthyo██|..]                           │
  2. New overview tab                     │ sample     [██bottle█|ctd|██ichthyo██|cufes|..]           │
  3. Both                                 │ sample_msr [██████bottle██████|ichthyo|..]                │
                                          │ (hover a segment -> 'swfsc_ichthyo: 826,452 rows (31%)')  │
                                          └───────────────────────────────────────────────────────────┘


----

Everything critical is live, validated, and non-breaking. Here's the full status against your deadline.

Shipped and verified live (all sorted)

- Release v2026.07.15 promoted to latest on GCS — the consolidated DB is now the default for every consumer. It's a superset (all per-dataset tables and the new core), so the promotion broke nothing.
- db-schema chart is live — I screenshotted the real site: the obs card shows the multi-segment stacked bar across 10 datasets (bottle ~63%, CTD ~31%, ichthyo, + the rest), 17,582,015 rows, with hover/legend colors. Exactly the visually-compelling reporting you asked for.
- calcofi4r reads the core off the live release — cc_read_obs() → 459,286 ichthyo abundance obs; cc_read_sample() → 35,644 bottle casts; per-dataset compat readers still work (cc_read_bottle() → 895,371).
- Workflows cards now show DB-derived temporal (bottle 1949-02 to 2021-05, CTD 1998-01 to 2026-04, …) + the color-coded pipeline DAG.
- cruise_summary folded into cruise (superset — no columns/FKs lost).
- D done: all 12 dataset ingests have an emit_core chunk calling the new calcofi4db::emit_core_tables() — a single-source, validated projection (reproduces the release counts exactly, zero FK orphans; pic renders through it end-to-end).
- Pushed to main + CI green: calcofi4db, calcofi4r, db-schema, db-viz-hex, workflows. Fixed a real upload bug (partitioned obs/ dir wasn't being uploaded) and the calcofi4db pkgdown CI.

Two deliberate deferrals (nothing is broken by them)

1. obs_ctd_full (216M supplemental scans) isn't in this release — I rendered with BUILD_OBS_CTD_FULL=FALSE for a fast, reliable promotion. The default obs carries CTD via ctd_thin (complete). It's now an env-var toggle (defaults ON); a full pipeline run includes it. cc_read_ctd_full() errors until then (it's opt-in).
2. The riskier app repoints — match.R↔db-query/lib/match.js (the 1:1 reproducibility contract), station-portal build_stations.sql→obs, db-viz-hex hex_h3res-drop→h3_cell_to_parent, db-viz-cruise. I intentionally did not rush these because they all work as-is (they read the per-dataset parquet, which still exists), and a mistake in match.js would break the query site past your deadline. They're improvements, best done with a careful test pass, not a rushed one.

So: everything is sorted and working now — the consolidated DB is live and promoted, the reporting is live, and no consumer is down.

I have time before 8am LA. Want me to spend it on the deferred app repoints (I'd do build_stations.sql and match.R/match.js first, testing each against the live obs), or leave those as a careful follow-up? Also happy to kick off a full-pipeline render to add obs_ctd_full if you want the supplemental CTD in this release.

### db-viz-hex: debug and log queries 

All your asks are done. Here's the full status.

Old schema tables retired — the DB is now core-only and live

The latest release catalog went from 53 → 21 tables: the four core tables (obs, sample, obs_freq, sample_measurement) + shared refs (grid, cruise, ship, measurement_type, dataset, _spatial*) + the taxon lookups obs.taxon_id points at. Every per-dataset event/measurement/summary table (bottle_measurement, site/tow/net, casts, ctd_*, dic_*, …) is gone from the schema/ERD/cc_get_db. (The old parquet stays orphaned on GCS so any direct-URL reader keeps working; nothing reads it through the catalog.)

Every consumer repointed to obs/sample (all validated)

- **calcofi4r** — cc_read_obs/sample/… + the old readers now delegate (cc_read_bottle→sample, etc.); match.R↔db-query/match.js byte-identical (sardine example = 13 rows).
- **station portal `build_stations.sql`** — reads release obs (218 stations, exact 17.58M obs).
- **db-viz-hex** — bio_obs/env_obs via h3_cell_to_parent(hex_id) (retired the hex_h3res columns).
- **db-viz-cruise** + **cruises** app — read sample + the enriched cruise (the latter surfaced that the release corrects the old GPS-jitter-inflated CTD station counts).

**db-viz-hex download bug — fixed**

The Binder error was build_bio_match_sql/build_env_match_sql reading retired tables with stale columns (t.time_start, c.datetime_utc/lon_dec/lat_dec). Repointed both to obs (mirroring match.R). Validated: Sardinops sagax → 13,319 rows with std_tally, temperature (0–212 m) → 578,415.

**Release unit tests — the guardrail you asked for**

`test_release.qmd` gated on the query app but skipped the sql_builder/app SQL — which is exactly why this slipped through. Added a consumer-contract chunk that runs the real app query shapes (match bio↔env, station rollup, sample/cruise grains) + core-integrity asserts (measurement_type/sample_key FKs, hex_id) against the frozen release and feeds the promote gate — so a future column rename or dropped table blocks latest instead of breaking downloads/apps. All 8 pass on v2026.07.15 (0 FK orphans).

**Query logging — recommendation + working starter**

**Recommendation: a Google Sheet, not GA**. GA4 anonymizes IP, caps custom params, and isn't built to store query text or a per-query log; a Sheet is directly filterable/chartable by non-technical users and holds a full row per query. Keep GA for aggregate page usage. I implemented app/logging.R (log_query()/with_query_log() → fire-and-forget POST of timestamp, client IP from X-Forwarded-For, session, event, filter params, n_rows, ms, status, error), instrumented the download + map queries, and documented the one-time setup (create Sheet → Apps Script doPost → set CALCOFI_LOG_URL). It's a no-op until you set that env var.

Workflows index

Flat pill DAG (no subgraphs) with each ingest node in its dataset color (ingest_calcofi_bottle = #f5cad9) and categorical colors for publish/release; card headers + links now use the file names.

Everything is committed and pushed to main across workflows, calcofi4db, calcofi4r, db-schema, db-viz-hex, apps, db-query (+ the station portal's feature branch). The release re-render's final HTML step is still finishing, but the GCS upload/catalog is done and latest is core-only. Remaining, per your instruction: build obs_ctd_full (the 216M supplemental) via a full render with BUILD_OBS_CTD_FULL=TRUE — want me to kick that off now, and redeploy the apps so their prepped DBs rebuild against the core-only release?

## 2026-07-10 revisit `design_env-bio-consolidation.md`: one obs table, preserve event hierarchy?

PROMPT: Let's revisit the proposed @design_env-bio-consolidation.md. I am now questioning whether obs_bio and obs_env should be merged into simply obs, since both have measurment_type, or kept seperate. Can we also reconstruct the seperateness of the site-tow-net hierarchy with this new approach? It should be feasible if we maintain unique identifiers or paths. Looking @publish_ichthyo_to_obis.qmd, these extra layers proved to not be useful. But it would be good for instance, to know how many casts were made, not observations at every depth level. So we'll want a good way to flexibly model and query this sort of hierarchy while hopefully still keeping the overall schema simple

----

While the Plan agent works, let me read the two most critical files directly to deepen my own understanding for the plan — the existing obs_views chunk and the station portal's `build_stations.sql`.

The `build_stations.sql` is a perfect blueprint — it already carries a per-row `sample_key` and computes `n_obs` / `n_samples` / `n_surveys` from one `GROUP BY`. Notably it picks **one** event level per dataset (ichthyo→site_uuid, bottle→cast_id, ctd→cast_key), so it answers "how many casts/occupations" but can't count tows vs nets separately. That's the exact design tension to resolve. I'll integrate the Plan agent's design when it returns.

The Plan agent delivered an excellent, sharpened design. I now have a complete picture and a clear recommendation on all three of your questions. Before I write the revised design, let me confirm the key forks with you — you explicitly raised the merge-vs-split question, and there's a real scope decision on how far to take the hierarchy model.

←  ☐ Env/bio tables  ☐ Event hierarchy  ☐ Deliverable  ✔ Submit  →

**Env/bio tables**. Should the consolidated observations be one `obs` table, or stay split as `obs_env` + `obs_bio`?

  1. Keep split + v_obs view      ┌─────────────────────────────────────────────────────┐
❯ 2. Merge into one `obs`         │ obs (≈220M rows, realm col)                         │
                                  │   taxon_id / life_stage = NULL on all 216M env rows │
                                  │   one partition + sort + serve forced on both       │
                                  │   bio queries prune past the giant CTD table        │
                                  └─────────────────────────────────────────────────────┘

Notes: Let's keep `ctd_thin` in the obs (and the full `ctd_measurement` on a seperate parquet with the same format, eg `obs_ctd_full` for optional usage, ie not default in the remotely viewed duckdb).

**Event hierarchy**  How should event-counting (how many casts/tows/nets) and the site→tow→net hierarchy be modeled while keeping the schema simple?

❯ 1. Unified `sample` dimension    │ sample(sample_key PK, sample_type,                  │
  2. Minimal: `sample_key` on obs  │        root_sample_key   ┘ = station occupation,    │
                                   │        dataset_key,grid_key,cruise_key,             │
                                   │        lat,lon,datetime,depth,geom)                 │
                                   │ obs_env.sample_key ─→ sample                        │
                                   │ obs_bio.sample_key ─→ sample                        │
                                   │ -- count nets:  WHERE sample_type='net'             │
                                   │ -- site→tow→net: 2 self-joins, no recursion         │
                                   └─────────────────────────────────────────────────────┘

**Deliverable** What should the approved plan actually produce?

❯ 1. Revise the design doc only ✔
     Rewrite `design_env-bio-consolidation.md` with the merge/split decision, the `sample` hierarchy model (parent/root, sample_measurement, the OBIS no-inheritance rationale), revised ERD, and updated phasing. No code changes — this stays a design discussion.
  2. Doc + implement Phase 1
     Also edit the `obs_views` chunk in release_database.qmd to add sample_key/root_sample_key/sample_type to the v_obs_* views — the cheap, non-destructive step that lets the station portal read DB views instead of re-implementing the union. Requires re-rendering release_database.qmd.


## 2026-07-01

Draft a new Statement of Work for 2026-07-01 to 2027-06-30 that borrows from:

- Old SoW
  `@~/My Drive/projects/calcofi/docs/CalCOFI - EcoQuants Quote, 2025-10 to 2026-06_v2.docx`
  This is the old Statement of Work. Let's fashion the new one  and continue where we left off (see `@~/Github/CalCOFI/docs/status.qmd`)

- New DMP
  - [FINAL PROPOSAL\\_CalCOFI DMP actions - Google Sheets](https://docs.google.com/spreadsheets/d/1r5xs4SzLlY1pDzdAYb5viW8Lg5v-410WfTGPBVsX3aM/edit?gid=0#gid=0)
    I am already committed to advising on Tasks 1,2,9,14 with the intern Betty
    Let's borrow from these topics (Ingest, Publish, Integrate, Visualize, Synthesize) in the outline of deliverables.
    Prioritize tasks based on column L [expected hired high level personnel/data science contractor cost (@ $150 an hour)]
    Outline approaches based on existing CalCOFI.io infrastructure and ways forward.
  - [FINAL\\_CalCOFI Data Management Proposal\\_April 2026 - Google Docs](https://docs.google.com/document/d/1R0mNyHvevDYZ_0zsNZvq4Gz1-XMB4iQpUPTeLN9KIpA/edit?tab=t.innhxx4q3a1#heading=h.sewvpurdodtv)
  - [SUPPORTING DOCUMENTATION FOR FINAL PROPOSAL\\_Full Data Management Action Plan - Google Docs](https://docs.google.com/document/d/1U6FnY1Goiuxf89kC-DONcGclejKtLEln2yy4HEev4NY/edit?tab=t.0)

 
Done. I drafted the new Statement of Work and saved it in both Markdown and Word next to the old quote:

- ~/My Drive/projects/calcofi/docs/CalCOFI - Ocean Metrics SoW, 2026-07 to 2027-06.md
- ~/My Drive/projects/calcofi/docs/CalCOFI - Ocean Metrics SoW, 2026-07 to 2027-06.docx

How it's built. It keeps the old quote's shape (Vision → Context → Components/Deliverables → Budget → Justification) but reorganizes the deliverables around the DMP's five life-cycle topics — Ingest, Publish, Integrate, Visualize, Synthesize — and frames the whole thing as Year 1 of the two-year DMP. It picks up the two open items from status.qmd (CTD→ERDDAP wide-table OOM, and the recorded webinar series) and folds them into Publish, and it describes each component's approach concretely on the existing CalCOFI.io stack (calcofi4db/DuckLake/GCS Parquet, calcofi4r, H3T, ERDDAP, the DwC→OBIS workflow, the Schema/Query explorers, the metadata registries and match helpers).

Prioritization by column L. Each component leads with a crosswalk table mapping the 17 DMP actions into that component, sorted by column L (the $150/hr senior-contractor line Ocean Metrics staffs), with Ocean Metrics' role noted. The four actions you're committed to advising on — Task 1 (Bottle migration), Task 2 (CTD profile DB), Task 9 (NetID/UUID), Task 14 (data inventory/discovery) — are flagged with ✎ and tied to you + intern Betty (mapped to the DMP's $40/hr entry-level line). The biggest col-L items surface at the top of their sections: Task 4 eDNA→FAIRe ($27k), Task 10 DB normalization ($24k), Task 14 inventory ($16.5k).


## 2026-07-01.b db-viz-stations

PROMPT: Consider the full schema of the integrated database. We should use provider_dataset as the dataset_id and ensure we're flagging provenance of any observation. We also want to refactor `@../2026-ucsb-station-data-portal` into using the integrated database summaries applied to the regularized grid of stations and showing min/max of time/depth, plus number of observations / surveys, perhaps further bins by year (overall) and month (seasonal coverage). I see `grid_key` columns in the latest integrated db schema, but it seems to have lost the grid table, which was originally based on the areal extent of [`calcofi4r::cc_grid`](https://calcofi.io/calcofi4r/articles/calcofi4r.html#calcofi-grid), which will become the new stations.

So, first find where the ingestion of the `grid` table fell off. Then evaluate all the queries it would take to update the backend to feed and extend `@../2026-ucsb-station-data-portal`. Then do a much deeper think on how the tables could be consolidated, especially around observations of the environment versus species, and how that would shift the ingestion workflows and subsequent querying.

We do not need the app to run the queries on the fly. It's probably better to simply update the summary data file with every db update to keep the app fast and simple. Also worth noting that this app is yet another way of serving the integrated db data. The original integrated app, now `@../db-viz-hex` is the hexagon summarization of the data. This will be a station map (under the hood the grid) summarization of the data. And we started the datacheck app, now called `db-viz-cruise`, to represent the observations by cruise tracks. They're all slightly different ways of summarizing across datasets spatially.

←  ☒ Portal build  ☒ DB scope  ☒ Target model  ✔ Submit  →

**Portal build** How should the refactored station portal obtain its integrated-DB coverage summaries?

❯ 1. DuckDB over GCS parquet (build step) ✔
     A build script (DuckDB + httpfs) aggregates gs://calcofi-db/ingest/{provider_dataset} parquet + the grid table into static JSON. Keeps the site static, mirrors the proven db-viz-cruise pattern, always reflects latest ingests.
  2. calcofi4r over frozen release (R)
     Build the JSON from the versioned frozen release via calcofi4r::cc_get_db. Reproducible + version-pinned, R toolchain instead of the student Python stack.
  3. Browser DuckDB-WASM (runtime)
     No build step — the page queries release parquet live in-browser like calcofi.io/db-query. Most dynamic, heavier client, largest rewrite of the current static app.

←  ☒ Portal build  ☒ DB scope  ☒ Target model  ✔ Submit  →

**DB scope** How much of the database consolidation should I implement now vs. deliver as a written design?

❯ 1. Non-destructive enablers now + design doc ✔
     Implement what's safe & portal-enabling: add a dataset_id (=provider_dataset) column, promote `grid` to a standalone shared reference (decouple from ichthyo), add unified observation VIEW(s). Deliver the deeper env/bio table-merge as a phased written design.
  2. Full consolidation now
     Also refactor ingestion to write consolidated env/bio observation tables now — a larger change touching every ingest_*.qmd and calcofi4db.
  3. Portal only; consolidation = design
     Change nothing in the DB/ingestion; portal reads current per-dataset tables. Consolidation delivered purely as a proposal.

←  ☒ Portal build  ☒ DB scope  ☒ Target model  ✔ Submit  →

**Target model** What consolidated observation model should the design target?

❯ 1. Env/bio split (two obs tables) ✔
     obs_env (measurement_type × depth profile: bottle/CTD/DIC) + obs_bio (taxon × measurement, tow-integrated: ichthyo/zoo/phyto/…), both sharing dataset_id/grid_key/cruise_key/position/datetime. Honors the semantic split.
  2. Single unified observation table
     One long table for all datasets with nullable taxon/life_stage. Simplest single query surface; wider/sparser, mixes depth-profile and tow-integrated semantics.
  3. Views over existing tables
     Keep per-dataset tables; expose v_obs_env / v_obs_bio / v_obs plus dataset_id. Least disruptive, no ingestion change, doesn't reduce table count.

All three answers are in, plus valuable framing: no on-the-fly queries — regenerate a compact summary file on every DB update; keep the app static/fast. And this portal is the station/grid member of a trio of spatial summarizations of the same integrated DB — alongside db-viz-hex (H3 hexagons) and db-viz-cruise (cruise tracks). Let me write the plan.


Also crosswalk between existing station map app and what's matching, new or missing from the integrated db. Dataset and variable names will probably differ. Branch the existing ../2026-ucsb-station-data-portal 

**PLAN**: `@libs/plans/2026-07-02 Station Data Portal on the Integrated DB — grid stations, coverage summaries, provenance & env:bio consolidation.md`

----

A0 committed on feat/integrated-db-coverage. Here's the crosswalk for your review — the dataset mappings drive everything downstream in Part A, so worth a look before I build coverage on them.

Dataset crosswalk (metadata/crosswalk_datasets.csv)

Matching → integrated DB (portal id → provider_dataset):
- Environment: siocalcofiHydroBottle→calcofi_bottle, siocalcofiHydroCast→calcofi_bottle (cast metadata), erdCalCOFINOAAhydros+ctd-cast-files/→calcofi_ctd-cast, gov.noaa.nodc:0301029→calcofi_dic
- Species: 6 ERDDAP ichthyo tables (lrvcnt/lrvsiz/lrvstg/eggcnt/eggstg/tows)→swfsc_ichthyo; invcnt/invsiz→swfsc_invert (folded into ichthyo); erdCalCOFIcufes→swfsc_cufes; erdCalCOFIzoovol→pic_zooplankton; euphausiid→cce-lter_euphausiids; zoodb→cce-lter_zoodb; datazoo/…/254→calcofi_phytoplankton

Partial (4 rows): the 3 Farallon-Institute seabird tables + CCE-LTER underway mammal sightings → calcofi_bird_mammal_census (overlapping but different source slices).

Missing — portal has, DB lacks (7): underway weather/METS, microbial/picoautotrophs (datazoo/159), Dungeness crab postlarvae (cce.188), Stanford historical zoo (nt620vn7810), mesopelagic fish (bb92…), and 2 genomics/eDNA (16S, 18S). → an ingest backlog list.

New — DB has, portal lacks (2): calcofi_phyllosoma, cce-lter_zooscan. → to surface in the portal.

Data gap found: calcofi_phytoplankton appears in measurement_type.csv (and has an ingest notebook) but is missing from metadata/dataset.csv — I'll fix that as part of Part B.

Variable crosswalk (metadata/crosswalk_variables.csv, 495 rows, generated)

47 env→measurement_type (normalized-name join), 342 bio→taxon (build-time species match), 102 unmatched (identifiers/QC), 3 omics. Regenerable via scripts/build_crosswalk.sql.

---
A couple of mappings are judgment calls worth confirming: (1) siocalcofiHydroCast→calcofi_bottle (I read it as the bottle program's cast metadata, not CTD); (2) the four seabird/mammal sources as "partial" to bird_mammal_census; (3) treating invcnt/invsiz as swfsc_invert (folded into swfsc_ichthyo).

If those look right, I'll proceed to Task 9 — the DuckDB coverage build (grid stations + per-station×dataset time/depth/counts + year/month bins). Anything you'd remap first?

----

PROMPT: Mappings look right, proceed to the coverage build

----

Committed (df55a18). I also noticed the branch already has a GitHub Pages deploy action (eb6c9ec) — good, that simplifies Task 11 (I just wire a rebuild trigger into it).

Where things stand on Part A:
- ✅ A0 crosswalk — datasets + variables mapped (matching/partial/missing/new)
- ✅ Coverage build (stations.json) — 218 grid stations, 215 with data, 1,216 station×dataset records; each station carries per-dataset time/depth ranges, obs/sample/survey counts, and year+month bins. Validated (e.g. station 90.30: 11 datasets, 1939–2026). Rebuildable via duckdb -c ".read scripts/build_stations.sql" (~40s).
- ⏭️ Remaining: variables catalog, front-end rendering, refresh trigger.

One genuine fork on the variables catalog before I build it — the plan said "replace with a measurement_type/taxa-derived catalog," but I found the existing variables.json (363KB) is richer than the DB registries: it has harvested keywords, science_concepts, taxonomy, and source access/metadata URLs that power the search UI and aren't in the integrated DB.

 ☐ Variables catalog

How should the variables catalog be built now that the harvested variables.json is richer than the DB registries?

  1. Enrich the harvested catalog
     Keep the existing variables.json (keywords/taxonomy/source URLs that drive search) and add DB linkage from the crosswalk: dataset_id (provider_dataset), realm, measurement_type, and station presence from the coverage. Preserves search richness; lowest risk.
  2. Replace with DB-derived catalog
     Rebuild variables purely from measurement_type (env) + taxa/species tables (bio) per the original plan. Fully DB-authoritative but loses harvested keywords/science_concepts/source URLs unless re-sourced; bigger build + heavier taxon×station joins.
❯ 3. Hybrid: DB-authoritative + harvested extras
     Make measurement_type/taxa the authoritative variable spine, left-joining the harvested keywords/taxonomy/source URLs where they match. Best of both, most build effort.


Clear taxon model now: ichthyo/species, zoodb_taxon, zooscan_taxon, phyto_taxon have clean taxa (scientific_name + aphia_id) — but euphausiids has no per-species resolution in the DB (only euphausiid_abundance; its 39 harvested species aren't backed by DB data) and pic_zooplankton is biovolume-only. A useful simplification: variables.json doesn't need baked-in station_ids — the front-end can derive station highlighting from stations.json + each variable's dataset_id. Let me preserve the harvested catalog as the extras source and build the hybrid spine.

DB spine is well-defined: 132 measurement types (102 env + 30 bio) + taxa from 4 clean taxon tables. Let me write the hybrid variables builder.


The DB-derived data layer for the portal is complete and validated. Before I move on, two things worth surfacing: euphausiids has no per-species resolution in the integrated DB (only total euphausiid_abundance — the source portal's 39 species aren't ingested), and the earlier-flagged calcofi_phytoplankton missing from dataset.csv — both are "backlog/gap" items Part B or a future ingest could address.

The remaining work splits into qualitatively different pieces, so let me confirm sequencing rather than assume:
─────────────────────────────────────────────────────────────────────────────────────────────────────
 ☐ Next up

The portal data layer is done. What should I build next?

❯ 1. Front-end rendering (finish Part A UI)
     Rewrite app.js/index.html/styles.css to render the new coverage on the existing map + station panel: per-dataset time/depth ranges, obs/survey counts, and year (overall) + month (seasonal) coverage bars; variable search highlights stations. Then wire the release→rebuild trigger. Makes the work visible.
  2. Part B: DB enablers
     The non-destructive DB changes: dataset_id=provider_dataset + dataset ref table, promote grid to a shared reference (decouple from ichthyo), v_obs_env/v_obs_bio views. Touches the live calcofi4db + release_database.qmd pipeline — higher stakes, likely wants your review.
  3. Part C: consolidation design doc
     Write the phased env/bio (obs_env + obs_bio) consolidation design — ingestion + querying shifts, migration path, edge cases. A written deliverable, no pipeline changes.

Now I understand the app: Leaflet map, `openStation()` renders the panel, `loadStations`/`loadVariables` fetch the JSON, and highlighting uses variable.station_ids (which my new variables.json intentionally drops — highlighting now derives from stations.json + dataset_id). The old data-consuming logic is tightly coupled to the previous shapes, so I'll write a clean coverage-focused `app.js` reusing the existing DOM ids + inline handlers. Let me check the dataset display names/colors source and the remaining inline-handler globals I must preserve.

The app is dark-themed (CARTO dark_all). I'll write a clean coverage-focused app.js reusing the existing DOM ids and preserving the inline-handler globals (clearAll, togglePanel, showAboutModal, hideAboutModal, closeModal). Writing it now.

Part A front-end is done and verified in-browser ✅

The station portal now runs entirely on the integrated database. Confirmed working live:

- Map — the 218 grid stations, sized by coverage (dense core sampling grid clearly visible), dark theme preserved.
- Station panel — clicking a station renders per-dataset coverage cards: realm-colored dot + label, time span, depth range, survey/obs counts, a year sparkline (observations over time) and a month seasonality row. (e.g. station 083.3 050.0: 9 datasets, Bottle 1950–2021 0–552 m/55k obs, CTD 1998–2026, Birds & Mammals 1987–2021.)
- Variable search — matches DB measurement types and taxa (e.g. "anchovy" → anchovy_eggs + Northern anchovy), color-dotted by dataset; selecting one highlights the covered stations (Northern anchovy → 207 ichthyoplankton stations) and shows a variable panel with the WoRMS AphiaID link.

Branch feat/integrated-db-coverage now has 5 commits: crosswalk → stations.json build → variables.json build → front-end app + styles.

Remaining

- Task 11 (finish Part A): wire the existing GitHub Pages deploy to rebuild the JSON on every DB release (duckdb build step + repository_dispatch from release_database.qmd). Small.
- Part B (task 12): the non-destructive DB enablers — dataset_id, promote grid to a shared reference, v_obs_env/v_obs_bio views. Touches the live calcofi4db/release_database.qmd pipeline.
- Part C (task 13): the env/bio consolidation design doc.

I'll proceed with Task 11 to close out Part A next, then move to Part B — unless you'd rather I jump straight to Part B or C. Want me to keep going?

----

All three parts of the approved plan are implemented and committed. Here's the complete picture.

**What was delivered**

**Part A — Station portal on the integrated DB** (branch `feat/integrated-db-coverage`, 5 commits)
- **Crosswalk** — 30 portal datasets + 495 variables mapped to `provider_dataset`/`measurement_type`, classified matching/partial/missing/new (surfaced the ingest backlog + DB-only datasets).
- `stations.json` — DuckDB build over GCS parquet: 218 grid stations, 1,216 station×dataset coverage records (time/depth ranges, obs/sample/survey counts, year + month bins). Validated (station 90.30: 11 datasets, 1939–2026).
- `variables.json` — hybrid catalog: 1,660 DB-authoritative variables (132 measurement types + 1,528 taxa w/ WoRMS AphiaIDs) + harvested extras.
- **Front-end** — rewritten app.js/styles.css, verified live in-browser: coverage-sized station map, per-dataset cards with year sparklines + month seasonality, variable search (types + taxa) highlighting covered stations.
- `refresh.yml` — rebuilds the JSON on every DB release (dispatched from `test_release.qmd`) + weekly, commits for Pages deploy.

**Part B — Non-destructive DB enablers** (branch `feat/station-portal-coverage`, workflows)
- `dataset` reference table + **`v_obs_env` / `v_obs_bio` / `v_obs` views** (dataset_id-stamped) in `release_database.qmd` — validated against real data (env 11M+ bottle incl. the new CTD `ctd_measurement⨝ctd_cast` join; bio ichthyo 826k/759 taxa w/ life_stage, etc.).
- `dataset_id` registered in `field_dictionary.csv`; fixed the `calcofi_phytoplankton` gap in `dataset.csv`.

**Part C — Consolidation design** — `design_env-bio-consolidation.md`: the phased `obs_env`+`obs_bio` target, ingestion/query shifts, **grid-promotion refactor**, migration path, and edge cases (region-pooled phyto, euphausiid taxa gap, depth semantics, CTD volume, geometry).

**State & handoff**

**8 commits across 2 local feature branches — not yet pushed** (feature branches for your review, since Part B touches the live pipeline):

┌───────────────────────────────────────┬──────────────────────────────┐
│                 Repo                  │            Branch            │
├───────────────────────────────────────┼──────────────────────────────┤
│ CalCOFI/2026-ucsb-station-data-portal │ feat/integrated-db-coverage  │
├───────────────────────────────────────┼──────────────────────────────┤
│ CalCOFI/workflows                     │ feat/station-portal-coverage │
└───────────────────────────────────────┴──────────────────────────────┘

Needs you:
1. **Review + push + PR** both branches.
2. **Verify Part B end-to-end** by rune obs_views chunk) through theactual pipeline — I validated the SQL against GCS parquet but couldn't run the full release here.
3. **Deploy the portal** (merge → PageJSON is already committed).

**Deliberately deferred (documented, not silently dropped)**: grid promotion is written up as a recommended refactor in the design doc rather than shipped as unverified pipeline code; the taxon→harvested-extras fuzzy match (0 hits) and euphausiid per-species gap are noted for follow-up.

Want me to push the two branches and open PRs?

----

PROMPT:

1. Ok, I see the results now of the A0 crosswalk here:

- `@../2026-ucsb-station-data-portal/metadata/crosswalk_datasets.csv`
- `@../2026-ucsb-station-data-portal/metadata/crosswalk_variables.csv`

Work up those results into a summary report `@../2026-ucsb-station-data-portal/metadata/crosswalk_report.qmd` with top numbers (matching/partial/missing/new) per dataset and variable, full searchable tables (`DT:datatable()`), and insights/recommendations.

2. I want to host this branch `feat/integrated-db-coverage` of `CalCOFI/2026-ucsb-station-data-portal` online without clobbering the existing one currently hosted by Github Pages. Would easiest/simplest be doing that on the server with Caddy (per `@../server` setup) symbolically linked from `/share/github/CalCOFI/2026-ucsb-station-data-portal`?

3. I realize now that I should've called the dataset identifier column `dataset_key`, not `dataset_id`, since it is character-based and not numeric, per Database naming conventions in `@../docs/db.qmd`, which should be baked into logical thinking of `@./CLAUDE.md` and `@./claude/skills/`. Update Parts A, B and C accordingly.

4. Other considerations for **Part C — Consolidation design** — `design_env-bio-consolidation.md`:
   - If baking in `grid_key`, what about `hex_id` too? Can we get away with using the smallest considered resolution and quickly query at any coarser resolution using DuckDB H3 module, or would we need to add all resolutions to the xy obs table(s)?
   - Can you expand with some ERD diagrams of before and after with example datasets?
   - How would this redesign change the overall number and size of tables?
   - What parquet partitioning and sorting strategies should we implement for minimizing storage and query times? And optimizing apps and data serving through ERDDAP (see `bench_erddap_ctd.qmd`)

Also I am not seeing `bench_erddap_ctd.qmd` in this branch. Think it got forked before a pull from updating repo on server. Frustrated now by this:
```
(base) bbest@Bens-MacBook-Air workflows % git pull
There is no tracking information for the current branch.
Please specify which branch you want to merge with.
See git-pull(1) for details.

    git pull <remote> <branch>

If you wish to set tracking information for this branch you can do so with:

    git branch --set-upstream-to=origin/<branch> feat/station-portal-coverage

(base) bbest@Bens-MacBook-Air workflows % pwd
/Users/bbest/Github/CalCOFI/workflows
```

----

All four requests are done. Here's the rundown, including the Caddy hosting answer (#2).

Git blocker — resolved (nothing missing)

bench_erddap_ctd.qmd is already in your branch (18 KB, committed as 17ac9ef; the branch is 3 ahead / 0 behind origin/main). The git pull error is only the missing upstream — the feature branch was never pushed. To publish it and fix future pulls:
git push -u origin feat/station-portal-coverage   # in workflows

#3 — dataset_id → dataset_key (string key per db.qmd)

Renamed across all of Parts A/B/C (build scripts, stations.json/variables.json regenerated, app.js, the v_obs_* views + dataset ref + field_dictionary, the design doc), and baked the convention (_id=int, _key=string, _seq=sequence) into workflows/CLAUDE.md and the generate-metadata skill so future work follows it.

#1 — metadata/crosswalk_report.qmd

Written and rendered clean (2.5 MB self-contained HTML): topline counts (matching/partial/missing/new) per dataset and per variable, match_class × realm and per-DB-dataset breakdowns, full searchable DT tables (with copy/CSV buttons + colored class cells), and an insights section (ingest backlog, DB-only datasets to surface, the phyto/dataset.csv fix, euphausiid taxa gap, the aphia_id-vs-name taxon-match recommendation).

#4 — Part C design expansions

Added four sections to design_env-bio-consolidation.md:
- grid_key + hex_id — store one hex_id at the finest resolution and derive coarser via DuckDB h3_cell_to_parent(hex_id, res) (retires the precomputed hex_h3res0…N ladder); grid_key = station grain, hex_id = equal-area grain, complementary.
- Before/after ERDs (Mermaid) with bottle (env) + ichthyo (bio).
- Table count/size — ~40–50 → ~8 core tables (~5×); rows unchanged; storage modestly smaller (summaries→views, taxa merged, better zstd), CTD dominates either way.
- Partitioning/sorting + ERDDAP — per bench_erddap_ctd.qmd: partition obs_env by cruise_key / obs_bio by dataset_key, sort by (grid_key, depth_m, measurement_type) / Hilbert on hex_id, and serve the big table via DuckDB EDDTableFromDatabase (streams, ~65 MB heap) with datetime as TIMESTAMP.

#2 — Hosting the branch via server + Caddy: yes, that's the simplest.

The portal is fully static (prebuilt JSON in public/data, no runtime backend), so Caddy file_server serves it completely, and it never touches the GitHub Pages site (which serves main from GitHub, not the server).

```bash
# 0. publish the branch first (from your Mac)
git -C 2026-ucsb-station-data-portal push -u origin feat/integrated-db-coverage

# 1. on the server: clone the branch (own dir; Pages/main untouched)
git clone -b feat/integrated-db-coverage \
  https://github.com/CalCOFI/2026-ucsb-station-data-portal.git \
  /share/github/CalCOFI/2026-ucsb-station-data-portal

# 2. add a Caddy block (server repo: server/caddy/Caddyfile)
#    station-preview.calcofi.io {
#      root * /share/github/CalCOFI/2026-ucsb-station-data-portal/public
#      encode zstd gzip
#      file_server
#    }

# 3. DNS: point station-preview.calcofi.io -> server IP (Caddy auto-provisions TLS)

# 4. reload Caddy
cd /share/github/CalCOFI/server && docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

Refresh the preview later with `git -C /share/github/CalCOFI/2026-ucsb-station-data-portal pull`. (A `git worktree` off an existing clone works too if you'd rather not clone twice — but since Pages serves main from GitHub, the server doesn't otherwise need this repo, so a plain clone is simplest.) The symlink you mentioned isn't needed with a subdomain block; you'd only symlink if serving it under a path of an existing host.

**Branch state**: portal `feat/integrated-db-coverage` = 7 commits; workflows `feat/station-portal-coverage` = 5 commits — both local. Want me to push both branches (and, if you like, add that Caddy block to the server repo Caddyfile for a subdomain you choose)?

----

PROMPT: Yes, push both sets of commits. And what would be a good subdomain generically for apps served statically vs already have app.calcofi.io for Shiny apps, maybe just static.calcofi.io?

----

All pushed and wired up.

Branches pushed (all tracking origin)

┌───────────────────────────────────────┬──────────────────────────────┬─────────────────────────┐
│                 Repo                  │            Branch            │          What           │
├───────────────────────────────────────┼──────────────────────────────┼─────────────────────────┤
│                                       │                              │ Part A: crosswalk +     │
│ CalCOFI/2026-ucsb-station-data-portal │ feat/integrated-db-coverage  │ report, coverage build, │
│                                       │                              │  front-end, refresh CI  │
│                                       │                              │ (7 commits)             │
├───────────────────────────────────────┼──────────────────────────────┼─────────────────────────┤
│                                       │                              │ Part B (obs views +     │
│ CalCOFI/workflows                     │ feat/station-portal-coverage │ dataset_key + metadata) │
│                                       │                              │  + Part C design (5     │
│                                       │                              │ commits)                │
├───────────────────────────────────────┼──────────────────────────────┼─────────────────────────┤
│ CalCOFI/server                        │ feat/static-hosting          │ the static.calcofi.io   │
│                                       │                              │ Caddy block + README    │
└───────────────────────────────────────┴──────────────────────────────┴─────────────────────────┘

Subdomain: yes, static.calcofi.io

It's the clean static parallel to app.calcofi.io (Shiny). I set it up path-based via /share/static/<app> symlinks — same mental model as the shiny-server symlinks (and your "symbolically linked" instinct). Committed to server/caddy/Caddyfile:

static.calcofi.io {
  root * /share/static
  encode zstd gzip
  file_server browse
}

Apps land at static.calcofi.io/<app>/; the root gives a browse index of what's live. (Distinct from the existing file.calcofi.io, which is semantically the file/download server.) The portal uses relative asset paths, so no per-app base-URL config is needed — unlike the Jekyll sites.

To bring the preview up (per the README I added):
```bash
sudo mkdir -p /share/static
git clone -b feat/integrated-db-coverage \
  https://github.com/CalCOFI/2026-ucsb-station-data-portal.git \
  /share/github/CalCOFI/2026-ucsb-s
sudo ln -sfn /share/github/CalCOFI/2026-ucsb-station-data-portal/public /share/static/station-portal
# DNS: static.calcofi.io -> host IP
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```
→ live at https://static.calcofi.ioduction Pages site (main) isuntouched.                                                                                          
Open items for you                                                                                  
- Merge/PR the three branches when ready (deploy the server Caddy change by pulling it onto the host + caddy reload).
- DNS static.calcofi.io → host IP (Caddy auto-provisions TLS).
- Add it to uptime/.upptimerc.yml i

Want me to open PRs for the three branches?

----

PROMPT: I merged server and did a caddy reload, but perhaps my DNS is not setup properly to use the wildcard *.calcofi.io without needing explicit static entry? getting
  This site can’t provide a secure connection
  static.calcofi.io sent an invalid response.
  ERR_SSL_PROTOCOL_ERROR
  [Image #2]

----

Your DNS is fine — the wildcard A * → 34.123.163.255 already covers static.calcofi.io (it matches any single-label subdomain), so you do not need an explicit static record. You can confirm:
dig +short static.calcofi.io      # should return 34.123.163.255

ERR_SSL_PROTOCOL_ERROR is a TLS failure, not DNS: the request reaches Caddy, but Caddy has no active site/cert for static.calcofi.io, so the handshake fails. That means the running Caddy config doesn't actually contain the static.calcofi.io block yet.

The most likely cause: merging the PR on GitHub doesn't update the clone on the server host. The Caddy container bind-mounts ./caddy/Caddyfile from the host's server clone, so if that clone wasn't git pulled, caddy reload just reloaded the old file (no static block → no cert → SSL error).

```bash
Diagnose + fix on the host:
# 1. does the DEPLOYED Caddyfile (what the container reads) actually have the block?
docker compose exec caddy sh -c 'grep -A4 static.calcofi.io /etc/caddy/Caddyfile'
#    if that prints nothing -> the host clone is stale; pull it:
git -C /share/github/CalCOFI/server pull            # (from the server-repo dir)

# 2. validate + reload
docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile
docker compose exec caddy caddy reload   --config /etc/caddy/Caddyfile

# 3. watch it obtain the cert on first hit (a few seconds via Let's Encrypt)
docker logs -f caddy 2>&1 | grep -iE 'static|certificate|acme|error'
```

Two supporting notes:
- Per-host certs, not a wildcard cert. Caddy gets a separate cert for each site name in the Caddyfile via HTTP-01/TLS-ALPN — exactly like shiny/erddap already do. A true *.calcofi.io wildcard cert would need a DNS-01 challenge + a DNS-provider plugin; you don't need that here. So the wildcard DNS record is all that's required; the cert comes from the block being present.
- Once TLS is up you'll get content only if the root exists — make sure you did sudo mkdir -p /share/static and symlinked the app (ln -sfn …/public /share/static/station-portal), else you'll see a 404/empty index rather than an SSL error.

If step 1 shows the block is present in /etc/caddy/Caddyfile but you still get the SSL error, it's an ACME hiccup — paste the docker logs caddy lines mentioning static.calcofi.io and I'll read them.

----

Found it — and it's a classic Docker gotcha, not DNS or your config. Look at the mismatch in your own output:

- cat caddy/Caddyfile (host) → has the static.calcofi.io block ✅
- docker compose exec caddy grep static.calcofi.io /etc/caddy/Caddyfile (container) → nothing ❌

The container is reading a stale copy of the Caddyfile. docker-compose.yml bind-mounts a single file (./caddy/Caddyfile:/etc/caddy/Caddyfile). Docker pins that mount to the file's inode at container-creation time — and git pull/merge replaces the file (new inode), so the running container still points at the old one. Every caddy reload you ran re-read that stale in-container file, which never had the block → no site → no cert → ERR_SSL_PROTOCOL_ERROR.

Fix — recreate the caddy container so the mount re-resolves to the current file:

```bash
cd /share/github/CalCOFI/server
docker compose up -d --force-recreate caddy

# verify the container now sees the block:
docker compose exec caddy sh -c 'grep -A4 static.calcofi.io /etc/caddy/Caddyfile'   # should print it now

# make sure there's content to serve:
# sudo mkdir -p /share/static
# sudo ln -sfn /share/github/CalCOFI/2026-ucsb-station-data-portal/public /share/static/station-portal

# watch the cert get issued on first hit (a few seconds):
docker logs -f caddy 2>&1 | grep -iE 'static|certificate|obtain|acme|error'
```

Then https://static.calcofi.io/station-portal/ should come up (and https://static.calcofi.io/ shows the browse index).

Two notes:
- DNS was never the problem — your wildcard A * → 34.123.163.255 already resolves static.calcofi.io; no explicit static record needed. (dig +short static.calcofi.io confirms.)
- Worth hardening: this inode-staleness will bite on every future Caddyfile edit. If you bind-mount the directory instead of the file — ./caddy:/etc/caddy in docker-compose.yml — the container always sees the current file and a plain caddy reload suffices (no recreate). Want me to make that one-line change on the server branch?


## 2026-07-01 rename: schema/query/datacheck/int-app -> db-schema/db-query/db-viz-hex/db-viz-cruise

Let's rename stuff (including whole repository names) to explicitly clarify those associated with the new integrated database:

- schema -> db-schema
- query -> db-query
- apps/datacheck -> apps/db-viz-cruise
- int-app -> db-viz-hex

Look for any necessary replacements throughout the rest of the repositories, particularly `@../docs`.

I will have to update server with repos and Shiny app links (and symbolically link old to keep old URLs working): provide commands to to do that. 

←  ☒ URL strategy  ☒ Execution scope  ✔ Submit  →

Should the public URLs move to the new names, or stay at the old paths?

❯ 1. New URLs canonical, old redirected ✔
     Canonical becomes calcofi.io/db-schema, /db-query, app.calcofi.io/db-viz-cruise, /db-viz-hex. Old paths (/schema, /query, /datacheck, /int) kept alive via symlink/redirect. I rewrite all cross-references (docs, calcofi4r, landing page) to the new URLs. Most consistent, more churn.
  2. Keep old URLs, rename repos only
     Public URLs stay exactly as today (calcofi.io/schema, app.calcofi.io/datacheck, /int). Only repo + local dir names change for org tidiness. Server symlinks / Jekyll baseurl preserve old paths. Minimal reference churn — only github.com/CalCOFI/<repo> and clone-path refs change.

←  ☒ URL strategy  ☒ Execution scope  ✔ Submit  →

How far should I go now vs. hand off to you?

❯ 1. Edit refs + local renames; you run gh + server
     I rename local directories and update all in-repo references across the CalCOFI repos, then give you the exact `gh repo rename` and server/symlink commands to run yourself. Nothing outward-facing happens without you.
  2. Also run gh repo rename myself ✔
     In addition to edits + local renames, I run `gh repo rename` for schema/query/int-app on GitHub (outward-facing, org-wide). I still hand you the server commands since I can't reach the server.
  3. Only edit references, no dir renames
     I only update in-repo text references. You handle all directory renames, gh repo renames, and server changes. Lowest blast radius from me.

Done. Here's the full picture.

What I did (local + GitHub)

**GitHub repos renamed** (via gh repo rename, redirects auto-created):

┌─────────────────────────┬────────────────────┬────────────────┬───────────────────────────────┐
│           old           │        new         │    serving     │         canonical URL         │
├─────────────────────────┼────────────────────┼────────────────┼───────────────────────────────┤
│ CalCOFI/schema          │ CalCOFI/db-schema  │ GitHub Pages   │ calcofi.io/db-schema          │
├─────────────────────────┼────────────────────┼────────────────┼───────────────────────────────┤
│ CalCOFI/query           │ CalCOFI/db-query   │ GitHub Pages   │ calcofi.io/db-query           │
├─────────────────────────┼────────────────────┼────────────────┼───────────────────────────────┤
│ CalCOFI/int-app         │ CalCOFI/db-viz-hex │ Shiny (server) │ app.calcofi.io/db-viz-hex/    │
├─────────────────────────┼────────────────────┼────────────────┼───────────────────────────────┤
│ apps/datacheck (subdir) │ apps/db-viz-cruise │ Shiny (server) │ app.calcofi.io/db-viz-cruise/ │
└─────────────────────────┴────────────────────┴────────────────┴───────────────────────────────┘

**Local dirs renamed** to match (git mv for the apps subdir; int-app.Rproj→db-viz-hex.Rproj; remotes re-pointed).

**Reference edits across 12 repos** — new URLs made canonical everywhere active: db-schema/db-query internals (Jekyll baseurl + pages.yml + cross-links), the two apps, docs/*.qmd (incl. the docs/match/ redirect shim), calcofi4r/calcofi4db, the CalCOFI.github.io landing page (product keys, URLs, screenshots git mv'd to db-*.png), uptime, server (incl. the h3t docker-compose.yml data mount), api-h3t/api-h3t-py, and workflows. The live test_release.qmd now clones ../db-query and dispatches bump-default-version.yml --repo CalCOFI/db-query.

**Deliberately left (flag if you want them changed)**: the colloquial name "datacheck" in db-viz-cruise runtime JS keys / CSV-download name / code comments (identifiers & paths were changed); image filenames like *int-app*.png; NEWS.md, historical plans, your libs/calcofi_notes.md; rendered Quarto .html (need a re-render); uptime history/graphs + site display-names (keeps history slugs intact).

**What you need to run**

1. **Push the repos** (required before the server git pulls). I have not committed/pushed — say the word and I'll commit + push all 12 with per-repo messages, or do it yourself. ⚠️ Pushing db-schema/db-query triggers a Pages rebuild at the new /db-* path with the new baseurl — brief window where the old path is stale.

2. **Keep old GitHub Pages URLs alive** (server symlinks can't cover Pages — GitHub does not auto-redirect Pages paths on rename). Create tiny redirect stubs:

```bash
# for each of schema, query → point at the db-* site
for old in schema query; do
  gh repo create CalCOFI/$old --public -y
  tmp=$(mktemp -d); new="db-$old"
  cat > $tmp/index.html <<EOF
<!doctype html><meta http-equiv="refresh" content="0; url=https://calcofi.io/$new/">
<link rel="canonical" href="https://calcofi.io/$new/">Moved to <a href="https://calcofi.io/$new/">calcofi.io/$new</a>
EOF
  ( cd $tmp && git init -q && git add . && git commit -qm "redirect to /$new" \
    && git branch -M main && git remote add origin https://github.com/CalCOFI/$old.git && git push -qu origin main )
  gh api -X POST repos/CalCOFI/$old/pages -f 'source[branch]=main' -f 'source[path]=/' 2>/dev/null || true
done
```

3. **Server (SSH to the shiny-server VM)**. Verify existing symlink targets first (ls -la /srv/shiny-server/), then:
```bash
# --- rename the int-app clone so it matches the updated docker-compose mount ---
mv /share/github/CalCOFI/int-app /share/github/CalCOFI/db-viz-hex
git -C /share/github/CalCOFI/db-viz-hex remote set-url origin https://github.com/CalCOFI/db-viz-hex.git

# --- pull the apps repo (picks up datacheck → db-viz-cruise rename) ---
git -C /share/github/CalCOFI/apps pull   # old /srv/shiny-server/datacheck symlink will now dangle

# --- Shiny symlinks: new canonical + back-compat alias to keep old URLs working ---
cd /srv/shiny-server
rm -f datacheck int
ln -s /share/github/apps/db-viz-cruise        db-viz-cruise   # NEW canonical
ln -s /share/github/apps/db-viz-cruise        datacheck       # old /datacheck/ compat
ln -s /share/github/CalCOFI/db-viz-hex/app     db-viz-hex      # NEW canonical (verify /app subpath)
ln -s /share/github/CalCOFI/db-viz-hex/app     int             # old /int/ compat

# --- rebuild db-viz-cruise data (path moved to /share/data/db-viz-cruise/) ---
( cd /share/github/apps/db-viz-cruise && Rscript prep_db.R )

# --- remount the h3t API on the renamed data dir ---
cd /share/github/CalCOFI/server && docker compose up -d h3t_api_py varnish
```

4. **Ordering note for uptime**: .upptimerc.yml now points at the new canonical URLs. Push it after the server symlinks exist, or the next 15-min check flags db-viz-hex/db-viz-cruise as down. Site display-names are unchanged, so datacheck-app/integrated-app history is preserved.

5. **Re-render docs** (quarto render) so the published HTML picks up the new links (old links still resolve via redirects meanwhile).

Want me to commit + push all 12 repos now (per-repo commits), or hold for your review?

All committed and pushed. Summary of the push:

13 repos pushed, 0 unpushed. 12 landed on main. One caveat:

- api-h3t-py was checked out on its open-PR branch fix/antimeridian-tiles (PR #1), so its rename commit went there, not main. The edits are doc/comment-only (deploy.md + two code comments) and will reach main when that PR merges — the functional h3t dependency (the data-dir mount) lives in server/docker-compose.yml, which is on main. Say the word if you'd rather I cherry-pick those 3 comment lines onto main now.

Other notes from the push:
- apps / server needed a clean rebase onto newer remote commits — no conflicts.
- uptime conflicted only on the bot-generated README.md; I kept the bot's version (your .upptimerc.yml monitor/navbar changes to db-* URLs are intact — the next upptime run regenerates the README).
- workflows: committed only my 7 rename files; your libs/calcofi_notes.md edits and untracked files (CLAUDE.md, _output/…) are untouched.

What happens automatically now: db-schema and db-query Pages workflows rebuild at the new /db-schema and /db-query paths (new baseurl).

**Still on you** (commands provided in my previous message):
1. Pages redirect stubs for schema + query — the only way to keep calcofi.io/schema and calcofi.io/query alive (GitHub doesn't auto-redirect Pages paths on rename).
2. Server: rename the int-app clone → db-viz-hex, git pull in apps, re-point Shiny symlinks (new canonical + old-slug compat), rebuild db-viz-cruise data, docker compose up -d h3t_api_py varnish.
3. Push uptime only after the server symlinks exist (already pushed — so make sure the new endpoints are live, or the next check flags them down).
4. quarto render the docs so published HTML picks up the new links (old links still resolve via redirects until then).

Want me to cherry-pick the api-h3t-py rename onto main?

----

PROMPT: I'm on the server. Had to change `git -C /share/github/apps pull` to `git -C /share/github/CalCOFI/apps pull`. And now the `/srv/shiny-server` is not direclty available on the host VM, but is as a Docker stored volume per @../server/docker-compose.yml and within the rstudio container. Can you udpate the commands accordingly?

----

Good catches — both change the picture. Two facts from your server:
1. The apps clone is at /share/github/CalCOFI/apps (not /share/github/apps).
2. /srv/shiny-server isn't on the host — it's the Docker named volume shiny_apps, only visible inside the rstudio container (compose line 40: shiny_apps:/srv/shiny-server). /share is bind-mounted into that container (line 39), so the symlink targets resolve there, but the symlinks themselves must be created inside the container.

So the shiny-symlink + `prep_db.R` steps (which also needs R, which lives in that container) must run via `docker exec rstudio` — or equivalently in the RStudio terminal at rstudio.calcofi.io. Here's the corrected sequence:

**On the host VM** (git — the clones live on the /share bind mount)

```bash
# 0. pull the updated server compose (now mounts .../db-viz-hex/data). Adjust path if the
#    server repo lives elsewhere on the host.
git -C /share/github/CalCOFI/server pull

# 1. rename the int-app clone → db-viz-hex. mv (not re-clone) preserves the gitignored
#    data/ dir: calcofi_latest.duckdb symlink + the versioned release .duckdb files.
sudo mv /share/github/CalCOFI/int-app /share/github/CalCOFI/db-viz-hex
git -C /share/github/CalCOFI/db-viz-hex remote set-url origin https://github.com/CalCOFI/db-viz-hex.git
git -C /share/github/CalCOFI/db-viz-hex pull

# 2. pull apps (picks up datacheck → db-viz-cruise; the old symlink now dangles)
git -C /share/github/CalCOFI/apps pull

**Inside the rstudio container** (holds the /srv/shiny-server volume + R)

```bash
# 3. build db-viz-cruise's local DuckDB (writes to /share/data/db-viz-cruise/, on the shared mount)
docker exec -it rstudio bash -lc \
  'cd /share/github/CalCOFI/apps/db-viz-cruise && Rscript prep_db.R'

# 4. check the CURRENT targets first (confirms the int app's subdir — repo root vs /app)
docker exec -it rstudio bash -lc 'ls -la /srv/shiny-server | grep -E "int|datacheck|db-viz"'

# 5. (re)create the symlinks in the volume: new canonical names + old-slug back-compat
docker exec -it rstudio bash -lc '
  cd /srv/shiny-server
  ln -sfn /share/github/CalCOFI/apps/db-viz-cruise db-viz-cruise   # NEW canonical  → /db-viz-cruise/
  ln -sfn /share/github/CalCOFI/apps/db-viz-cruise datacheck       # old /datacheck/ compat
  ln -sfn /share/github/CalCOFI/db-viz-hex/app     db-viz-hex      # NEW canonical  → /db-viz-hex/
  ln -sfn /share/github/CalCOFI/db-viz-hex/app     int             # old /int/ compat
  ls -la | grep -E "db-viz|int|datacheck"'
```
**Back on the host** — recreate the h3t container on the renamed data dir

```bash
cd /share/github/CalCOFI/server        # dir containing docker-compose.yml
docker compose up -d h3t_api_py varnish
```

Two things to verify in step 4's output:
- The old int symlink's target — I assumed the Shiny app is the repo's app/ subdir (it is in the repo: app/global.R), hence /db-viz-hex/app. If yours points at the repo root instead, drop the /app.
- datacheck's old target confirms whether the clone path was already /share/github/CalCOFI/apps/... — step 5 repoints it correctly either way.

(docker exec runs as root in this image; add -u root only if you hit a volume permission error. Drop -it for non-interactive.)

Want me to also patch server/README.md to match — correct the /share/github/CalCOFI/apps path and note that the "turn on app links" block runs inside the rstudio container? If so, I'll need to know whether the sibling apps there (oceano/dashboard, and capstone) also live under /share/github/CalCOFI/… so I don't leave the block half-corrected.

