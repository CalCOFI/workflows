# Integrator notes — the dataset catalog, 2026-09-05 (coordinator session; not an agent brief)

Umbrella: `.claude/plans/2026-09-05 CalCOFI.io as a dataset catalog — one record per dataset with every endpoint, the front door re-cut around Datasets, and the portal registrations.md` (Decisions 1–17; § Workstreams). Artifact with the mockups:
https://claude.ai/code/artifact/5fe1fa4e-c124-4525-a27a-a4a978abf2ba (the spec for WS-P1).

## Waves and merge order
- **Wave 1** (parallel, own worktrees): R0 (calcofi4db + workflows), R1 (workflows), R2 (workflows). R1 and R2
  write registries and sidecars only; R0 owns every R function. Merge R0 first (**calcofi4db 4.1.0**), then
  R1, then R2; re-run `import_caloos_sheet.R` after R0's shapes are final if R1 landed first.
- **Wave 2** (after R0 merged and calcofi4db 4.1.0 installed): P1 (CalCOFI.github.io + one row in
  workflows/test_release.qmd), E1 (calcofi4db 4.2.0 + release_database.qmd), M1 (calcofi4db 4.3.0 +
  update_datasets-sitemap.qmd + CalCOFI.github.io/stac). Package bumps serialize: E1 → M1.
- **Wave 3**: P2 (six consumer repos + calcofi4r 1.19.0 + calcofi4py 0.7.0 + docs), E2 (calcofi4db 4.4.0 +
  publish_to-obis.qmd), E3 (publish_to-edi.qmd), M2 (forms + drafts; Ben executes).
- **Wave 4**: F — one operator, Ben on call.

## Mechanics (carried from 2026-09-03; still true)
- Push first, then spawn: worktree isolation branches from the last **pushed** commit.
- `.claude/worktrees/calcofi4db` and `calcofi4r` are symlinks to the sibling checkouts, so a render in ANY
  worktree loads the sibling's *checked-out* branch — **an agent that changes calcofi4db must not render**;
  the integrator renders after merging with the sibling checkout on the merged branch.
- A brief that needs Google auth (R2's push --execute, R1's optional Sheets read) stops and asks; the CSV
  export of the CalOOS sheet is public and needs no auth (`…/export?format=csv&gid=0`).
- Every WS: `# Unreleased` (RELEASES.md) and/or `NEWS.md` in the same commit; `tar_invalidate()` any .qmd
  it edits that must run; hand back one *Measured* line for the umbrella.
- Reading a Google Sheet from a session: the Drive connector's `read_file_content` **truncates long cells** (it
  is a summary view); the CSV export URL and `googlesheets4::range_read()` return full cells (verified
  2026-09-05: the CalOOS sheet's longest abstract, 1,546 chars, is complete in both). The sync scripts
  use googlesheets4 and need no change.
- Fable 529s: wait and retry, do not switch model. A message to a completed agent resumes it.

## Checkpoints (agent → branch @ sha → next step)
- 2026-09-05 · R0 + R1 + R2 (one session; R1/R2 as Sonnet subagents in the same working tree, not
  worktrees) → calcofi4db `catalog-datasets-4.1.0` @ 80910f49; workflows `dataset-catalog-phase0`
  (this commit). Merged in the intended order inside the session: R0's shapes first, R1's registries
  and holdings, R2's migration and sheet script; R0 folded R1's `keywords_gcmd` into the sidecars,
  the rest of the CalOOS proposals stay in `dataset_meta.proposed.yml`. The `metadata` tabs are live
  on the six provider sheets and the `holdings` tab on the calcofi sheet (17 rows), pushed as the
  calcofi-admin service account (scripts/lib_google_auth.R — no interactive auth anywhere now);
  `pull` reads back with zero changes. sccoos has holdings but no sheet (skipped).
  **Staging render done 14:48 CEST** (release_database 1 h 03 + test_release 10 min; 64/4/0; catalog rows
  pass) → calcofi4db `catalog-datasets-4.1.0` @ 4179e8ee (netCDF fallback fix), workflows
  `dataset-catalog-phase0` (staging `exists` verification + production-history `since_version`).
  Ben: no production release for the sidecars alone. **Next:** merge both branches to main, install
  4.1.0 wherever the pipeline runs, then Wave 2 (P1, E1, M1) reads `datasets.json` from the next release.
  Separate fix wanted: `build_climatology()` hash non-determinism (60/71 partitions re-upload on every
  re-cut).
- Lessons: an `.nz()` helper name collided with netcdf.R's; `$` partial matching on record lists
  (dataset_name → dataset_name_short) silently passed a red test — use `[[ ]]`; the migrated sidecars
  sit at a uniform 2-space indent while generated/hand-written ones sit at 0, so the sync script now
  detects the indent; EDI's portal starts refusing ranged GETs after ~150 requests in a day (warn, not fail).
- 2026-09-05 ~15:20 · both mains fast-forwarded to Phase 0 (calcofi4db 4179e8ee, workflows 1bee2d7). **Wave 2
  spawned** in worktrees under `/Users/bbest/Github/CalCOFI/.worktrees/`: P1 (Opus; landing repo branch
  `dataset-catalog-pages`, reads the staging `datasets.json` until a promoted release carries one), E1 (Opus;
  `eml-4.2.0` in calcofi4db + workflows), M1 (Opus; `stac-4.3.0` in calcofi4db + workflows, `stac-browser` in
  the landing repo, `stac/` only), plus two fixes: `climatology-determinism` (Sonnet; 4.1.1) and
  `sheets-followup` (Sonnet; sccoos Sheet, CalOOS question rows). Merge order for calcofi4db: 4.1.1 → 4.2.0 →
  4.3.0 (NEWS headings pre-assigned). No agent installs the package or renders; the integrator does both after
  merging. Ben: no production release for the sidecars alone — the next data change carries datasets.json.
- 2026-09-05 ~17:40 · **Wave 2 merged** (calcofi4db main 4.3.0 @ 29e53dad: 4.1.1 climatology, 4.2.0 EML, 4.3.0 STAC/
  observe/sitemap + the record follow-ups from P1; workflows main 3cc849e; CalCOFI.github.io main b51db1a = pages +
  /stac/; explore main aa8aa7f = cat-genomics). Full calcofi4db suite green; index gate 16/16; nothing pushed.
  **Wave 3 spawned** in worktrees: P2 (Sonnet; branches `dataset-page-links` in db-schema, db-query, explore,
  db-viz-station, db-viz-hex, ctd-transects, calcofi4r 1.19.0, calcofi4py 0.7.0, docs, analytics, uptime +
  workflows `publish_to-erddap.qmd`), E2 (Opus; calcofi4db `dwc-4.4.0` + workflows `obis-generic`), E3 (Sonnet;
  workflows `edi-publish`), M2 (Sonnet; workflows `registrations-drafts`). Merge order: E2's 4.4.0 after P2's
  calcofi4r/calcofi4py bumps are independent; RELEASES.md text comes back in hand-backs (agents do not edit it).
- 2026-09-05 evening · **Pushed** (Ben, "push ready repos, including landing page"): calcofi4db, workflows, explore,
  CalCOFI.github.io — calcofi.io deployed with the catalog (`/datasets/`, `/data.json`, `/datasets/sitemap.xml`,
  `/stac/` all 200), rendering the staging record through the `DATASETS_RELEASE_URL` bridge. The workflows-site deploy
  had failed on every push since 2026-09-03 (no calcofi4db on the runner) — fixed in `jekyll-gh-pages.yml`
  (setup-r-dependencies + `calcofi/calcofi4db`, link check skipped on the runner). **Wave 3 merged + pushed:** E3
  (`publish_to-edi.qmd`), M2 (registration drafts, `portal.csv` ioos-catalog → FGDC WAF), P2 (12 repos on
  `dataset-page-links`: workflows publish_to-erddap.qmd, db-schema, db-query, explore, db-viz-station, db-viz-hex,
  ctd-transects, calcofi4r 1.19.0, calcofi4py 0.7.0, docs portals.qmd, analytics, uptime). Not yet: E2 (running);
  db-viz-hex is a server-side Shiny app (deploy-consumers skill, not a push); calcofi4r 1.19.0 / calcofi4py 0.7.0
  are on main, untagged; the ERDDAP `datasets.xml` regeneration (publish_to-erddap.qmd) runs with the next release.

