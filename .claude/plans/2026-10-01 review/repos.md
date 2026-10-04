# CalCOFI Git & GitHub Survey — 2026-10-01

> **Correction (main session, 2026-10-01):** the "ahead" counts below are reversed. `workflows` is 26 commits **behind** origin/main and `docs` 3 behind; nothing is unpushed in any repo (verified with `rev-list --left-right --count @{u}...HEAD`).

## Executive Summary

- **Unpushed commits**: workflows repo has 26 commits ahead of origin/main. docs repo has 3 commits ahead.
- **At-risk worktrees**: workflows repo has 18 active worktrees; several from agent runs. workflows-crab109, workflows-ctd-derived-ingest, workflows-ctd-new-format, workflows-release are all worktrees of workflows.
- **Uncommitted work**: workflows (18 files), docs (10 files), explore (1 file), apps (1 file), calcofi4py (1 file).
- **Stale branches**: Multiple repos have branches from June-August not yet merged into origin/main.
- **Open issues**: 52 open issues updated since 2026-09-09, heavily weighted toward beta/enhancement tasks; 25+ labeled "betty" for user Betty Huang.
- **Recent releases**: workflows v2026.09.28 via automated observe script; calcofi4db v4.17.1 in sync.

---

## Git Repos: Status Table

| Repo | Branch | Changes | Ahead | Behind | Worktrees | Stash | Notes |
|------|--------|---------|-------|--------|-----------|-------|-------|
| analytics | main | 0 | 0 | 0 | 0 | 0 | Clean |
| api | main | 0 | 0 | 0 | 0 | 0 | Clean |
| api-h3t | main | 0 | 0 | 0 | 0 | 0 | Clean |
| api-h3t-py | main | 0 | 0 | 0 | 0 | 0 | Clean |
| apps | main | 1 (M) | 0 | 0 | 0 | 0 | ctd-viz/data/gebco_calcofi.tif modified; pr41_tmp local |
| CalCOFI.github.io | main | 0 | 0 | 0 | 15 | 0 | Many measurement/species-faces worktrees |
| calcofi4db | main | 0 | 0 | 0 | 6 | 0 | 1 stale branch (feat/measurement-type-dataset-membership, 2026-06-26) |
| calcofi4db-crab109 | crab-cruise-key-109 | — | — | — | — | — | Worktree of calcofi4db |
| calcofi4py | main | 1 (??) | 0 | 0 | 0 | 0 | Untracked: calcofi_ctd_casts_1996-2023.csv |
| calcofi4r | main | 0 | 0 | 0 | 0 | 0 | 1 stale branch (fix/match-column-rename, 2026-06-26) |
| capstone | main | 0 | 0 | 0 | 0 | 0 | Clean |
| ctd-transects | main | 0 | 0 | 0 | 0 | 0 | Clean |
| data | main | — | — | — | — | — | (not a git repo) |
| db-query | main | 0 | 0 | 0 | 0 | 0 | 2 stale branches (chore/bump, fix/column-rename, both 2026-06-26/27) |
| db-schema | main | 0 | 0 | 0 | 0 | 0 | 1 stale branch (fix/version-switch, 2026-06-26) |
| db-viz-hex | main | 0 | 0 | 0 | 0 | 0 | Clean |
| db-viz-station | main | 0 | 0 | 0 | 0 | 0 | 1 stale branch (fix/taxon-coverage-keying, 2026-08-13) |
| docs | main | 10 (M) | 3 | 0 | 4 | 0 | RELEASE_NOTES.md, catalog.json, 6 other data files modified; ahead of upstream |
| erddap | main | 0 | 0 | 0 | 0 | 0 | Clean |
| explore | main | 1 (??) | 0 | 0 | 1 | 0 | Untracked: smoke.png; 1 spike branch (bathy-layers, 2026-08-31) |
| hypoxia-story | main | 0 | 0 | 0 | 0 | 0 | Clean |
| larvae-cinms | master | 0 | 0 | 0 | 0 | 0 | Clean (uses master) |
| marmam-app | main | 0 | 0 | 0 | 0 | 0 | Clean |
| pollutants-app | main | 0 | 0 | 0 | 0 | 0 | Clean |
| SaferSeafood | main | 0 | 0 | 0 | 0 | 0 | Clean |
| server | main | 0 | 0 | 0 | 0 | 0 | 1 stale branch (feat/release-redirects, 2026-08-25) |
| uptime | explore-monitor | 0 | 0 | 0 | 0 | 0 | On non-main branch |
| workflows | main | 18 (??, M) | **26** | 0 | 18 | 0 | **UNPUSHED**: 26 commits ahead. 18 modified + untracked files; 18 worktrees (agent runs + explicit branches) |
| workflows-crab109 | crab-cruise-key-109 | — | — | — | — | — | Worktree of workflows |
| workflows-ctd-derived-ingest | ctd-derived-ingest | — | — | — | — | — | Worktree of workflows |
| workflows-ctd-new-format | ctd-new-format | — | — | — | — | — | Worktree of workflows |
| workflows-release | release-2026-09-24 | — | — | — | — | — | Worktree of workflows |

---

## Uncommitted Work Detail

### High-priority (unpushed + uncommitted):

**workflows** (26 commits ahead + 18 changes)
- Modified: .claude/calcofi_notes.md, _output/ingest_cce-lter_picoplankton-bacteria.html, _output/ingest_swfsc_ichthyo.html
- Untracked: 6 .claude/plans/* files and directories

**docs** (3 commits ahead + 10 changes)
- Modified: data/release/{RELEASE_NOTES.md, catalog.json, dataset.csv, datasets.json, integrity.json, measurements.json, metadata.json, relationships.json}
- All in data/release/ (generated files, likely from the last promote step)

### Lower-priority uncommitted:

- **apps**: ctd-viz/data/gebco_calcofi.tif (M)
- **calcofi4py**: calcofi_ctd_casts_1996-2023.csv (??)
- **explore**: smoke.png (??)

---

## Local Branches Not in origin/main (Stale/At-Risk)

| Repo | Branch | Date | Subject |
|------|--------|------|---------|
| apps | pr41_tmp | 2026-08-21 | Add files via upload |
| CalCOFI.github.io | explore-card | 2026-08-28 | products: CalCOFI Explorer card (interim) |
| calcofi4db | feat/measurement-type-dataset-membership | 2026-06-26 | metadata.json: data-derived measurement_type → dataset(s) |
| calcofi4r | fix/match-column-rename-v2026.06.26 | 2026-06-26 | match.R: rename columns for schema |
| db-query | chore/bump-default-version-dispatch-only | 2026-06-27 | bump version: dispatch-only + fix YAML |
| db-query | fix/column-rename-v2026.06.26 | 2026-06-26 | queries: rename columns for schema |
| db-schema | fix/version-switch-and-measurement-filters | 2026-06-26 | app.js: fix staleness & measurement filter |
| db-viz-station | fix/taxon-coverage-keying | 2026-08-13 | feat: say "pooled by region" |
| docs | ws-f5 | 2026-09-11 | db.qmd: species pages get a face (D10) |
| explore | spike/bathy-layers | 2026-08-31 | spike: Phase 0 measurements (throwaway) |
| server | feat/release-redirects | 2026-08-25 | erddap: mount erddap2.css (brand contract) |
| workflows | ingest-euph-pico-meso | 2026-07-29 | Merge origin/main into ingest-euph-pico-meso |
| workflows | feat/station-portal-coverage | 2026-07-03 | design: expand grid_key+hex_id, ERDs, table counts |
| workflows | feat/test-release-dispatch-bump | 2026-06-27 | test_release: dispatch bump-default-version |
| workflows | feat/measurement-type-membership | 2026-06-26 | release: derive measurement_type membership |

---

## Worktrees

### workflows (parent repo)

18 worktrees active:
- 9 in `/Users/bbest/Github/CalCOFI/.worktrees/workflows-ws-*`: ws-m1, ws-m2, ws-m5, ws-mf1–mf3, ws-mf6–mf7
- 4 explicit checkouts: workflows-crab109 (crab-cruise-key-109), workflows-ctd-derived-ingest, workflows-ctd-new-format, workflows-release (release-2026-09-24)
- 5 agent worktrees: agent-* in .claude/worktrees/

**Candidates for cleanup**:
- ws-m1, ws-m2, ws-m5, ws-mf1–mf3, ws-mf6–mf7 — if branches are merged into origin/main, these can be removed.
- workflows-release (release-2026-09-24) — if this release is finalized & promoted, may be stale.

### CalCOFI.github.io (parent repo)

15 worktrees active in `/Users/bbest/Github/CalCOFI/.worktrees/`:
- CalCOFI.github.io-round-2, -species-faces, -ws-m0, -ws-m0b, -ws-m3, -ws-mcat, -ws-mf4, -ws-mf5, -ws-mflag, -ws-mflag2, -ws-r1, -ws-r2, -ws-r3, -ws-r4, -ws-r5

**Status**: Many are feature branches for round-2 faces work (Sept). Likely candidates for cleanup if rounds are merged.

### calcofi4db (parent repo)

6 worktrees active (not enumerated in detail), including calcofi4db-crab109.

### docs (parent repo)

4 worktrees active.

### explore (parent repo)

1 worktree active.

---

## Recent Commits: workflows & calcofi4db

### workflows origin/main (since 2026-09-24)

| Commit | Date | Author | Message |
|--------|------|--------|---------|
| e23c88d | 2026-09-28 | github-actions[bot] | observe: what the portals say now + regenerated sitemap |
| 5c61a19 | 2026-09-24 | Ben Best | Merge PR #115 test-release-clim-depth |
| 158fd8b | 2026-09-24 | Ben Best | test_release: climatology contract follows calcofi4db 4.15.0's depth rule |

**Current state**: workflows main is 26 commits ahead of origin/main. Last 3 commits from origin are automated (observe, PR merge). User has unpushed work.

### calcofi4db origin/main (since 2026-09-24)

No commits. Package is at v4.17.1 (DESCRIPTION & installed version match).

---

## GitHub Issues (Open, Updated ≥ 2026-09-09)

### Summary by Repository

| Repo | Open Count | Key Issues |
|------|-----------|-----------|
| workflows | 18 | #113 CTD archive memory, #82 ingest cce-lter_iron, #81 ZooDB regions, #80 citation emails, #74 farallon bird-mammal cruise_key |
| CalCOFI.github.io | 1 | #12 Landing/catalog corrections (betty) |
| ctd-transects | 5 | #10–6 hydrographic derived products, climatology options, geostrophic velocity, spice sections |
| explore | 2 | #13 hydrographic products, #12 sections summary value (feedback, assigned bhuang0022) |
| db-viz-station | 4 | #8 responsive design, #7 tray/tabs responsive, #5 bathymetry data quality, #3 committed data files |
| calcofi4db | 2 | #14 export_release_parquet() OOM on obs_ctd_full, #13 get_duckdb_con() memory budget |
| calcofi4r | 1 | #17 vignettes by community (betty, assigned bhuang0022) |
| apps | 1 | #42 CARTO basemaps watermark (API key required) |

**Total**: 34 issues across 8 repos.

### Issues Labeled "betty" (Betty Huang Focus)

| Issue | Repo | Title | Status |
|-------|------|-------|--------|
| #91 | workflows | climatology: seasonal baseline + bottle-database option | ingest, assigned bbest |
| #87 | workflows | CTD: per-sensor corrected series + chl estimate canonical | ingest, assigned bbest |
| #86 | workflows | sections/climatology key on site_key, not grid cell | assigned bbest |
| #85 | workflows | Product showcase: six clips + webinar | **assigned bhuang0022** |
| #84 | workflows | Holdings triage: owner + next step | **assigned bhuang0022** |
| #83 | workflows | Review 10 staged DwC-A + 3 EDI; agree deposit order | **assigned bhuang0022** |
| #82 | workflows | ingest cce-lter_iron (EDI knb-lter-cce.21.3) | **assigned bhuang0022** |
| #81 | workflows | ZooDB pooled composites: region geometry with Linsey | **assigned bhuang0022** |
| #80 | workflows | Provider citation/licence gap emails | **assigned bhuang0022** |
| #65 | workflows | share: live recorded webinars / showcase | should-complete, **assigned bhuang0022** |
| #62 | workflows | publish: phytoplankton & bacterioplankton to EDI | should-complete, publish, **assigned bhuang0022** |
| #44 | workflows | publish: seabirds to OBIS | should-complete, publish, **assigned bhuang0022** |
| #43 | workflows | publish: marine mammals to OBIS | should-complete, publish, **assigned bhuang0022** |
| #42 | workflows | publish: zooplankton to EDI | should-complete, publish, **assigned bhuang0022** |
| #24 | workflows | register datasets with ODIS (JSON-LD) | **assigned bhuang0022** |
| #17 | workflows | Reproduce State of CA Current figures | **assigned bhuang0022** |
| #12 | CalCOFI.github.io | Landing/catalog corrections | **assigned bhuang0022** |
| #8 | explore | Explorer review: five feedback | **assigned bhuang0022** |
| #7 | db-viz-station | responsive design | enhancement, betty, **assigned bhuang0022** |
| #5 | db-viz-station | bathymetry.json data quality | bug, betty, **assigned bhuang0022** |
| #3 | db-viz-station | committed data files without scripts | bug, betty, **assigned bhuang0022** |
| #17 | calcofi4r | vignettes by community | betty, **assigned bhuang0022** |

**Total "betty" assigned to bhuang0022**: ~17 issues, spanning workshops publication, holdings, EDI/OBIS publishes, explorer review, db-viz-station bugs.

---

## Flags & Recommendations

### A. UNPUSHED COMMITS (High Priority)

1. **workflows**: 26 commits ahead of origin/main
   - Action: Review what's in those 26 commits before pushing. Check `.claude/calcofi_notes.md` and the plans files.
   - Risk: If local changes are lost or a hard reset happens, 26 commits could be orphaned.

2. **docs**: 3 commits ahead of origin/main
   - Action: Push after confirming the data/release/* changes are intentional (likely from last release promotion).
   - Risk: Stale release metadata if not pushed.

### B. UNCOMMITTED WORK (Moderate Priority)

1. **workflows** (18 changes)
   - Mostly plan files (.claude/plans/*) and output HTMLs.
   - Action: Decide whether to commit plans/notes or stage them elsewhere.

2. **docs** (10 changes, all data/release/*)
   - These are typically generated at release-promote time.
   - Action: Either commit or verify they're intended as ephemeral.

3. **explore** (smoke.png), **apps** (gebco_calcofi.tif), **calcofi4py** (CSV):
   - May be test outputs or data files.
   - Action: Clarify before committing large binary files.

### C. STALE BRANCHES (Low Priority — Cleanup Candidates)

Most branches from June–August should be reviewed for PR merge status:

- **calcofi4db#13, calcofi4r#10, db-query#11, db-schema#6** (all 2026-06-26) — probably from a coordinated schema migration; check if PRs are merged.
- **db-viz-station#3** (2026-08-13) — taxon coverage keying fix; check status.
- **docs/ws-f5** (2026-09-11) — species faces feature; check if live.

### D. WORKTREES

**workflows repo has 18 active worktrees**:
- Check which branches are merged into origin/main; remove stale ones with `git worktree remove`.
- Agent worktrees in `.claude/worktrees/` may be auto-cleanup or from unfinished agent runs.

**CalCOFI.github.io has 15 worktrees**:
- Similar review recommended for cleanup post-faces-round-2.

### E. GITHUB BOARD STATE

The project board query failed (gh auth scope issue likely). Recommend:
- Run `gh project item-list 5 --owner CalCOFI --format json` manually to audit board state.
- 17 "betty" issues assigned to bhuang0022 spanning Q4 deliverables (publication, showcase, explorer review).

---

## Recommendations Summary

1. **Push workflows' 26 commits** after review (likely safe; mostly merge commits + auto-generated observe updates).
2. **Push docs' 3 commits** after confirming release metadata is current.
3. **Review & clean worktrees** in workflows (~18) and CalCOFI.github.io (~15) if branches are merged.
4. **Triage uncommitted work** in workflows; move plans to memory/MEMORY.md if not code-relevant.
5. **Chase merged PRs** on stale June–August branches across calcofi4db, calcofi4r, db-query, db-schema.
6. **Audit CalCOFI.io board** (project 5) manually for betty/bhuang0022 workload & next priorities.
