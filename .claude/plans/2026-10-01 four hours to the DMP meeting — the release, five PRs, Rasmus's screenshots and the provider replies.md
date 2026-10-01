# Four hours to the DMP meeting: the release, five PRs, Rasmus's screenshots and the provider replies (2026-10-01)

**Window:** 13:45 to 17:30 CEST (04:45 to 08:30 PT). The meeting is "Ben, Betty, Mark, Erin – CalCOFI DMP" at 08:30 PT;
Mark is Mark Gold (UCSD). The next DMP call is Thu 10/8.

**Sources (read 2026-10-01).** Each was collected by a subagent; the full reports are in this session's
scratchpad (`gmail.md`, `tactiq.md`, `repos.md`, `pr_workflows_116.md`, `pr_workflows_117.md`, `pr_workflows_118.md`,
`pr_phyto.md`) and are copied next to this plan under `2026-10-01 review/`.
- **GitHub:** five open PRs, all from Betty (`bhuang0022`): workflows #116 (iron), #117 (marmam cetaceans), #118 (2022 eDNA),
  #119 (phytoplankton names), and db-viz-station#16 (phytoplankton review fixes). Also the issues updated since 9/24.
- **Gmail:** `ben@ecoquants.com`, 9/22 to today.
- **Tactiq:** 9/16 to today. Only the 9/23 DMP call was a CalCOFI meeting.
- **Local git:** every sibling repo, plus the paused release worktree.
- **Rasmus's 9/29 screenshots:** both diagnosed below against the source files.

---

## Where things stand

**Release.** v2026.09.24 is staged and passed in full: staging prefix, `test_release` 87 pass / 0 fail / 4 skip, both
client READMEs. The real run was stopped cleanly before freeze on 9/24.
- Nothing is on the real prefix, and `latest.txt` is still **v2026.09.11**, three weeks old.
- The worktree `~/Github/CalCOFI/workflows-release` (branch `release-2026-09-24`, at `5c61a19`) is intact.
- Disk has 182 GB free; about 115 GB is needed.
- `release_database.qmd:141` sets `release_version <- format(Sys.Date(), "v%Y.%m.%d")`, so a run today cuts **v2026.10.01**.

What v2026.10.01 would carry, all already merged:
- **CTD:** the corrected 2607 file and the four other station-truncated cruises repaired; provider flags on every CTD series;
  the 2607 sensor-2 flag; and the cruise-corrected DO that Rasmus asked for.
- **Datasets:** the `calcofi_ctd-derived` dataset (MLD, spice, sigma-theta); crab `cruise_key` cut from 97 NULLs to 1;
  picoplankton moved to `obs_bio`.
- **Climatology and catalog:** the climatology runs to the bottom rather than stopping at 500 m; `measurements.json` is now
  schema 1.1.
- **Packages and docs:** calcofi4db 4.17.1, and the corrected `provide.qmd`.

**Repos.**
- Nothing is unpushed anywhere. Local `workflows` is **26 behind** origin and `docs` is 3 behind (pull them).
- `workflows` has 18 worktrees and CalCOFI.github.io has 15, most of them merged. Cleanup can wait.

**Datasets in flight.** Five datasets sit in the three ingest PRs, and a sixth PR fixes 53 named phytoplankton taxa. That is
the "more datasets, faster" story.

| PR | dataset(s) | core rows | in_release | review verdict |
|---|---|---|---|---|
| workflows#116 | `cce-lter_iron` (EDI knb-lter-cce.21.3, Barbeau) | 170 samples, 192 obs | yes | **no blockers**; 8 should-fix, incl. a malformed `flds_redefine.csv`, and parquet not on GCS (rendered with `CALCOFI_SKIP_GCS`) |
| workflows#118 | `calcofi_2022-edna` (GBIF DwC-A, Oct 2022 vertebrate eDNA) | 47 samples, 201 obs (really ASV-level rows), 423 sample_measurement | **yes, must become false** | **request changes, 5 blockers, ~1 day**: (1) `assay` is not a registered type, so `release_database.qmd:709-720` hard-stops the release; (2) the obs grain is undefined: 2–17 rows per filter × taxon, one per ASV with no ASV id, and the assay can't be paired with its read count; (3) `reads_raw_total` / `reads_filtered_total` are registered but have 0 rows, and they are the normalisers users need; (4) QC values are collapsed with `MIN()` across runs, and `otu_richness` reaches 395,809; (5) `sample_key` is built as `:sample:` while `sample_type = 'filter'`, which is not in `core_dictionary.csv` or the docs |
| workflows#117 | `sio_cetacean-sightings` / `-sonobuoy` / `-edna` (marmam-app @ `7bc0e18`) | 6,107 sightings + 1,980 effort; 962 deployments / 3,244 h; 133 samples / 931 detections | **false** (licence, citation) | **1 blocker**: the next release fails, see § #117; then 12 should-fix, half of them yours |
| workflows#119 | `calcofi_phytoplankton` taxa | codes without AphiaID 75 → 24; 115 codes re-keyed | yes | correct in substance (63 AphiaIDs re-verified against WoRMS); **blocker: the ingest was never re-run** |
| db-viz-station#16 | phytoplankton UI (Pooh's review) | 8 files | — | approve after fixes; it hand-commits CI-owned JSON |

**Merge order** (every conflict is append-both): #116 → #118 (only after `in_release: false` is set) → #117 → #119 → db-viz-station#16.
- **`metadata/dataset_status.csv`:** all three ingests touch it.
- **`RELEASES.md`:** #116 and #118.
- **`metadata/taxon_lineage.csv`:** #117 and #118.
- **Last step:** regenerate `_output/_data/workflows.yml` once, after the final merge.

---

## Rasmus's 9/29 screenshots: what the plotter shows is what the files say

Both screenshots are 2025-04 Bell M. Shimada (`2025-04-3322`), line 93.3, `preliminary_with_bottle`. Shard:
`ctd-transects/public/data/sections/93.3__2025-04-3322.json`. Raw file:
`~/_big/calcofi/ctd-cast/unzip/20-2504SH_CTDPrelim/db-csvs/20-2504SH_CTDBTL_001-116D.csv`.

1. **"DO average station-corrected" shows only stations 45–55.**
   - In the raw file, `OxAve_StaCorr` is non-null at exactly 093.3 045, 050 and 055 (514, 516 and 519 scans). It is
     empty at the other 11 casts on the line.
   - The provider's format document says station correction needs a ~500 m cast with roughly ten or more bottles (our
     ctd-cast Q17). On a preliminary cruise the bottle merge evidently covered only those three casts.
   - The plotter then shades the gap between them as one block.
   - **Data:** correct. **Display:** misleading, since one wide block reads as "the whole section".
2. **"Est. nitrate cruise-corrected" is depth-invariant (vertical stripes, 0–4 µmol/L to 500 m).**
   - In the raw file, `EstNO3_CruiseCorr` has **one distinct value per cast across 0–520 m** on all 14 line-93.3 casts:
     028.0 = 0.188, 040.0 = 0.0, 055.0 = 3.613, and so on.
   - `EstNO3_StaCorr` on the same casts rises 0.5 → 40 µM, as nitrate should.
   - The fault is not confined to this cruise. **Every cast is depth-constant on 2204SH (101 casts), 2307SR (56) and the
     final 9809NH (66)**, while the final 0903JD varies with depth on all 70 casts.
   - So in some provider files the cruise-corrected nitrate column holds a per-cast scalar (an intercept or offset?), not a
     profile. **This is a question for Rasmus and Kelsey**, not a plotter bug. It also means the release carries a bad
     series for those cruises.

**What we do:**
- **D1 (provider question).** File ctd-cast **Q38** with the per-cruise census of depth-constant
  `EstNO3_CruiseCorr` casts, and put it in today's reply to Rasmus.
- **D2 (pipeline guard).** Add an ingest check to `ingest_calcofi_ctd-cast.qmd`: a derived series that is constant over
  ≥ 50 m of a cast is a finding. Until Rasmus answers, drop `est_nitrate_cruise_corr` on those casts, per the
  flags-outrank-bounds rule.
  - **Lands in:** the *next* release, not today's.
  - **Before re-staging:** run the per-type diff against the release (measurement-bounds skill).
- **D3 (ctd-transects).** Two display rules in `build_sections.py`:
  - A variable present at **fewer than 3 stations** of a section is not offered for that section. This is Rasmus's own
    9/23 rule for transects, applied per variable.
  - Where a `*_sta_corr` series is sparse, the selector offers the `*_cruise_corr` sibling first. After today's release,
    `oxygen_ml_l_ave_cruise_corr` exists.
  - Also skip whole transects with < 3 stations (his 9/23 ask, ctd-transects#8's sibling).
  - **Live today** if the release promotes, because the shards regenerate from it.

---

## Decisions only Ben can make (flag list)

Ordered by what blocks the most work today.

| # | decision | recommendation | blocks |
|---|---|---|---|
| **B1** | Cut the release now as **v2026.10.01**, the 9/24 content? Promote `latest.txt` automatically if all gates pass? | **Yes and yes.** It is the only way Rasmus sees the 2607 fix and cruise-corrected DO this week. The new PRs go in the next release (target: before 10/8). | Track A; the Rasmus reply; the deck's headline |
| **B2** | Ed Weber says SWFSC "agreed to use ICES ship codes, not NODC" | Keep NODC in `cruise_key`: the key is a published contract and every release and consumer depends on it. Add the ICES code as a typed column on `ship`/`cruise`, the same move as `cruise_key_alt` from 9/23. Reply that way, and offer the call he proposed. | ichthyo re-ingest (next week) |
| B3 | #117: emit zero or blank group sizes as obs rows? Effort ON/OFF in `measurement_qual`, or in `obs_attribute`? eDNA PCR negatives (455 of 916 zeros) published as absences? | No zero-size rows. Effort status goes to `obs_attribute`, because `cc_qual_ok_sql()` would keep OFF rows. PCR negatives are **non-detections, not absences**: hold them until the provider answers Q04. | #117 fixes |
| B4 | **One eDNA convention** across #117 (presence 0/1) and #118 (sequence reads, ASV-level today) | Grain: filter × taxon × assay. `edna_detected` (0/1) is the cross-dataset headline. Reads are an assay-specific type with a "not abundance" `derivation` note, and ship with the per-filter read totals as normalisers. Provider stays `calcofi` (the GBIF publisher) for #118. | #117, #118 |
| B5 | #117: possible double counting with `farallon_bird-mammal` sightings, same cruises, independent observer teams | Keep both, since they are independent observations; state it in both `dataset_meta.yml` descriptions. | — |
| B6 | #116: hold `chl_response_to_fe` out until Q01 (units, meaning) is answered? Key samples by `study_name + index_number` instead of `row_number()`? `sample_type`? | Hold it out; use the stable key; `sample_type = "bottle"`. | #116 fixes |
| B7 | #119: "Ceratium spp." (genus 109506) sits beside species keyed to *Tripos*; the same shape exists for Cladopyxis and Gonyaulax. Two genera counted together: key their lowest common ancestor, or the class? | Key the **accepted** genus (*Tripos*) and keep the source's "Ceratium" in `species` (verbatim) and as the display name. Use the **LCA**, not the class. | #119 fixes |
| B8 | Ammonium `qual = 4`: Rasmus (9/28, Google Sheet action item) says don't backfill early zeros; zero is valid | Concur; this is what the 2026-09 analysis found too. Close the question with his words. | — |
| B9 | UCSD Library (Ho Jung): your cruise-naming answer went only to Erin and Betty on 9/23; Christy (CDFW) is waiting on the Library URL | You send it today, from the drafted text. Erin's VPN issue makes her the slower path. | CDFW portal link |
| B10 | Kuali vendor review: a reply to Pilar is drafted in `.claude/plans_todo/2026-09-30 email - reply to Pilar …md`. It was not found in `ben@ecoquants.com`; it may be in the UCSD account. | Confirm it went (Mark and Erin are cc'd and will ask). | contract |
| B11 | SCCOOS quote: you asked Erin on 10/1 whether to cut Quote 1 by $433.25 to keep $65,625 | Wait for Erin, or settle it at the meeting. | — |

---

## The four hours

Times are CEST. **[C]** marks Claude work (subagent model in brackets) and **[B]** marks Ben. Tracks A–D run in parallel.

### Track A: the release (background, machine-bound). Starts as soon as B1 is "yes"

| time | step |
|---|---|
| 13:50 | **[C]** In `~/Github/CalCOFI/workflows-release`, rename the `# v2026.09.24` heading in RELEASES.md to `# v2026.10.01`, then launch in tmux with the 9/24 recipe: `CLOUDSDK_CORE_ACCOUNT=calcofi-admin@…`, `CALCOFI_DUCKDB_MEMORY_LIMIT=10GB`, `CALCOFI_DUCKDB_THREADS=2`, the spill dir/cap, real prefixes, named targets with `shortcut = TRUE`, and the memory guard. Record the resume fingerprint first. |
| ~15:45 | `release_database` frozen and uploaded; `test_release` plus both READMEs (calcofi4r knit, calcofi4py blocks). Pull the sibling checkouts before running them. |
| ~16:15 | If every gate passes: promote `latest.txt`, then `scripts/deploy_consumers.sh`, and dispatch ctd-transects, db-viz-station and the docs book. Commit and push the release worktree; note the stale ctd-cast meta row. |
| ~16:45 | Check the live consumers: calcofi.io/ctd-transects 2607 line 83.3 shows 10 stations; the cruise-corrected DO is selectable; storage.calcofi.io `latest`. Zenodo DOI. |

**Risk.** Running ingests (Track B) at the same time competes for memory. The phytoplankton and iron renders are light;
nothing heavier runs until the freeze is done. If the release cannot finish by 16:30, the meeting gets "frozen, gates
running" and promotion happens after.

### Track B: the five PRs. Each fix runs in its own worktree from the PR branch, never in the shared `workflows` tree

The work is parallel; the merges are serial, in this order.

| time | PR | step |
|---|---|---|
| 13:50 | all | **[C]** Pull `workflows` and `docs` main (fast-forward). |
| 13:50–14:40 | **#116 iron** [sonnet] | Fix: re-quote the 8 malformed rows of `flds_redefine.csv`; set the `category` for the new types via `declare_measurement_fields()`; drop `total_iron` if it has no values; remove the stale "NOT YET RUN" status; fix the bounds prose, the Q01 `related_field` typo and the citation author string. Apply the B6 decisions. **Re-render with GCS upload on Ben's machine**; it is light. Post the review comment, then squash-merge. |
| 13:50–16:00 | **#118 eDNA** [opus] | It does not fit in four hours whole, so split it. **Today:** set `in_release: false`. Register `assay`. Make `sample_key` follow `sample_type`, and register `filter` in `core_dictionary.csv` and docs `db.qmd` / `keys.qmd`. Aggregate obs to **filter × taxon × assay** with assay-specific types (`edna_reads_12s`, `edna_reads_dloop`), per B4. Fix the reads-total matching so the normalisers ship. Replace `MIN()` with a uniqueness assertion. Re-render. Post the comment, then merge after #116, resolving `RELEASES.md` and `dataset_status.csv` append-both. **Later, with Betty:** the other 12 should-fixes and the 9 provider questions (zero-detection filters, thresholds and controls, `otu_richness`, version 1.0 vs 1.2). Release it once they are answered. |
| 13:50–15:30 | **#117 marmam** [opus] | **Blocker first.** `check_taxon_registries(halt = TRUE)` (`release_database.qmd:802`) treats the 13 new `taxon_override.csv` rows for the held-out datasets as orphans. Filter the registries by `release_excluded_datasets()` before the check, add a calcofi4db test, and bump calcofi4db and NEWS. This touches `release_database.qmd` on **main**, not the running release worktree. Then the agent-fixable should-fixes: a `RELEASES.md` entry for the 10 new measurement types; `core_dictionary.csv` `sample_type` values; eDNA timing from the NCOG bottle cast rather than the ichthyo tow (CC1611, 16 untimed samples); and re-validating the crosswalk in the eDNA notebook. Apply the B3–B5 decisions. Merge with `in_release: false` kept. |
| 14:00–15:00 | **#119 phyto** [sonnet] | Apply B7. Then **re-run the phytoplankton ingest target** (`tar_invalidate`, then `tar_make` by name; confirm by the `_output` mtime) so `taxon_xref.csv` and `taxon_lineage.csv` and the sidecars are regenerated. Turn the "19 class-level codes" check into an allowlisted `stopifnot`. Commit the AphiaID verification as `libs/verify_phyto_aphia.R`. Correct "57" to 55 + 2 in the body, add the `RELEASES.md` note (obs rows unchanged; several codes now share a `taxon_key` per sample, so sum), and add the rule to the `taxon-reference` skill. Merge. |
| 15:00–16:00 | **db-viz-station#16** [sonnet] | After #119 merges: keep the PR's UI work. Drop the hand-committed `regions.json` / `variables.json` so refresh.yml stays their only writer. Remove `COMMON_NAME_ADDS`, since `taxon_common.csv` in #119 now carries them. File issues for the `build_vars.sql` fetch of workflows@main, `STATION_ON_LAND`, the "cells/L" label pending Q02, and the doubled-sample ingest bug (1202/1203 and the "CalCOFI 0704" columns). Merge, then dispatch refresh.yml after the release promotes. |

Each PR gets one review comment summarizing what was found, what was fixed (with commit hashes), and what was filed as
follow-up, in the style of the 9/23 round. Betty gets the reasoning, not only the diff.

### Track C: replies (Claude drafts in each thread; Ben sends)

| time | to | content |
|---|---|---|
| 14:00 | **Rasmus** (thread `1a081fa6c2393fa1`, promised "by Thursday") | (1) The screenshots, diagnosed as above. The DO comes from the bottle merge covering 3 casts. The cruise-corrected nitrate is depth-constant **in the source files** on 2504SH, 2204SH, 2307SR and 9809NH: is that column an offset? Attach the census. (2) Today's release carries the corrected 2607, the four repaired cruises and cruise-corrected DO; the plotter refreshes from it this afternoon, with a < 3-station rule. (3) Derived products: accept his defaults (MLD at +0.02 kg/m³ below 10 m; DCM from a 3 m running mean; integrated chl 0–200 m) and his new list (nitracline at 1 µM; hypoxic boundaries at 2.4 / 1.4 / 0.5 mL/L; pycnocline in TEOS-10; N²). Geostrophic: relative only, SCCOOS excluded, downcast; the speeds are being checked. Isopycnals are parked, as he allowed. Target: in the release before the 10/31 El Niño cruise. (4) Ammonium: concur, no `qual = 4` backfill (B8). |
| 14:20 | **Ed Weber** (`1a035889e1db4873`) | Thanks. We re-ingest from the new tables next week. The `LarvaeMeasured` merge of length and stage is welcome. 198202JD and 198212JD are dropped. The ship code goes per B2: offer the call. |
| 14:30 | **Kelsey** (unsent draft `r-5609354737494233360`) | Trim item 4 (Ben Gire answered the `*Q` question on 9/23). Say the 2607 fix ships today. Keep the asks for corrected 2507SR, 2511SR, 2601RL and 2604SH, and for the 2607 sensor-2 flag. Send. |
| 14:40 | **Ho Jung (UCSD Library)**, cc Erin | The cruise-naming answer (B9). |
| — | Christy (CDFW) | Nothing until the Library URL exists. |
| — | Rasmus / SOCCR meeting mid next week | Betty is scheduling it; nothing from Ben beyond availability. |

### Track D: Rasmus's display fixes (ctd-transects) and the ingest guard

| time | step |
|---|---|
| 14:30–15:30 | **[C, sonnet]** D3 in `ctd-transects/scripts/build_sections.py`: the < 3-station rule per variable and per transect, and `cruise_corr` offered first when `sta_corr` is sparse. Unit tests (`scripts/test_*.py`). PR, self-review, merge. The shards regenerate when the release dispatch runs. |
| 15:30–16:15 | **[C, sonnet]** D1 + D2: the Q38 row; the depth-constant-series finding in the ctd-cast ingest; a calcofi4db helper (`check_depth_constant_series()`) with a testthat fixture; the per-type release diff written up. **No re-stage today.** |

### 16:45–17:15: the deck, final pass

- **[C]** Rebuild `presentations/build_update_2026-10-01.R` with the live outcomes: the release version and gates, the
  merged PRs with hashes, and the replies sent.
- **[B]** Read through it once.
- Optional: hand it to Claude Desktop with `COWORK_PROMPT_2026-10-01.md` for polish.

---

## Not in the four hours (named, so they are not forgotten)

- **swfsc_ichthyo re-ingest** from Ed's new tables: a breaking `LarvaeMeasured` schema change, `NetDepth`, the Fish table,
  CUFES. About one day; file it as an issue today.
- **Derived products round 2**:
  - Rasmus's defaults and new products: calcofi4db#11 follow-ups, workflows #98–#103.
  - Explorer layers: explore#13.
  - The bottle-based climatology: ctd-transects#9.
  - The monthly vs seasonal toggle: #8.
- **The 9/23 DMP's own items**:
  - `cruise_key_alt`;
  - Explorer cmocean ramps and explore#12;
  - the CDFW crab answers into `questions.csv`;
  - expert review of the "why it matters" text.
- **Memory and performance issues**: calcofi4db#13 (budget on every connection), #14 (partition-aware uniqueness), and
  workflows#113 (per-archive ctd-cast).
- **IFCB** (Hou): would like the data on calcofi.io; turnaround is about a week after a cruise. Note it as a candidate dataset.
- **Worktree cleanup**:
  - 18 in `workflows` and 15 in `CalCOFI.github.io`;
  - June–August branches in calcofi4db, calcofi4r, db-query and db-schema.
  - Prune the merged ones once you're happy; nothing there is unpushed.

## Verification (how we know each piece is done)

- **Release:**
  - `gsutil cat gs://calcofi-db/ducklake/releases/latest.txt` = `v2026.10.01`;
  - `data/releases-staging/…/test_results.json` 0 fail;
  - calcofi.io/ctd-transects `index.json` names v2026.10.01;
  - the 2607 line-83.3 shard has 10 stations.
- **PRs:** `gh search prs --owner CalCOFI --state open` returns nothing; each closed PR carries a review comment.
- **Merge results:**
  - after #119, `check_dataset_taxon()` passes and codes without an AphiaID = 24;
  - after #117, the release's `check_taxon_registries` passes on main with the held-out rows present.
- **Display (D3):** on the 2504SH line-93.3 shard, `est_nitrate_cruise_corr` is withheld, or flagged depth-constant, and the
  DO selector offers cruise-corrected first.
- **Replies:** the Rasmus, Ed, Kelsey and Ho Jung threads each show a sent reply dated 10/01.

---

## Execution log (2026-10-01, CEST)

**Ben's decisions.** Release: start and promote if green. Ship codes: keep NODC and add an ICES column. PR decisions:
apply the recommended defaults (B3, B4, B6, B7) and merge, including the new PRs.

**Release**
- **13:36** launched (`~/_big/calcofi/logs/chain_release_20261001.sh`, tmux `rel1001`, guard `guard1001`).
- **13:58** it failed at `core_parity` ("every ingest shard must survive the union"). The PR agents had rendered 5 new
  datasets into the shared `~/_big/calcofi/parquet`.
- The 5 dirs were moved to `~/_big/calcofi/parquet_hold_20261001/`, and the release was **relaunched at 14:00**.
  **Move them back after `release_real_20261001.done`.**

**Merged** (each with a review comment from its agent):

| PR | commit | what it brings |
|---|---|---|
| ctd-transects#12 | `4615147` | withholds sparse and depth-constant variables; skips < 3-station sections; sta_corr → cruise_corr fallback |
| calcofi4db#16 | — | 4.17.2, `check_taxon_registries(exclude =)` — **not installed yet**; install after the release |
| workflows#117 | `e3bc0cc` | cetaceans; `in_release: false`; `edna_presence` |
| workflows#116 | `c45d590` | iron; uploaded to GCS |
| workflows#119 | `b989010` | phytoplankton; **GCS upload owed** from the private stage dir `~/_big/calcofi-pr119` |
| db-viz-station#16 | — | phytoplankton UI |
| workflows#118 | `30591bd` | 2022 eDNA; `in_release: false`; uploaded |

**Open:** docs#18, held until 2022 eDNA is released.

**Issues filed:** workflows #120–#126, calcofi4db#17, db-viz-station #17–#21.

**Gmail drafts** (Ben reviews and sends):
- Rasmus `r-8243084003701449543`: fill in its release line by recreating the draft;
- Ed Weber `r7823692443891958610`;
- Ho Jung `r-334118005899680652`;
- Kelsey: Ben's own draft `r-5609354737494233360`, untouched; it needs 2 hand edits.

**In flight:** the ctd-cast depth-constant guard (census + calcofi4db helper + Q38), as PRs; not to be merged before a
ctd-cast render.

**After the release:**
1. Move the held shards back.
2. Install calcofi4db 4.17.2.
3. Upload phytoplankton from `~/_big/calcofi-pr119`, after checking the manifest against main.
4. Commit the release worktree, and reconcile its `# v2026.10.01` RELEASES.md heading with main's `# Unreleased`.
   Main now also carries the entries for #116–#119.
5. Recreate the Rasmus draft with the release line.
6. Re-run the deck's STATUS block.

**Correction (14:40):** the § screenshots claim "every cast depth-constant on 2204SH, 2307SR and 9809NH" was
wrong for two of the three. My one-distinct-value test counted the missing code as constant: 9809NH is -99 throughout
(missing, and dropped by the ingest), and 2204SH is blank or -99. The census (workflows#127, calcofi4db#18):
`EstNO3_CruiseCorr` is depth-constant on 441 of 5,066 judged casts on 20 of 76 cruises. It covers every judged cast of
2304SH, 2504SH, 2301RL, 2307SR, 2105SH, 2411SR and 0810NH. Most of these are exact 0 (an unfilled column; 2307SR is 0
on all 56 casts). About 99 casts carry a non-zero per-cast value (2504SH: 65 casts > 0, 42 at 0). The question for
Rasmus and Kelsey is filed as **Q40** (Q38 and Q39 already existed).

**Release done (16:43).**
- **Gates:** `latest.txt` = v2026.10.01 (promoted 14:22:36Z); test_release 87 / 0 / 4; deploy_consumers done.
- **Consumers refreshed:** ctd-transects, db-viz-station and db-query.
- **Docs book:** dispatched 14:42Z.
- **Live check:** calcofi.io/ctd-transects line 93.3 / 2025-04 withholds `est_nitrate_cruise_corr` (constant with depth) and
  `oxygen_ml_l_ave_sta_corr` (3 of 15 stations), and offers `oxygen_ml_l_ave_cruise_corr`.
- **Published:**
  - release commit `5ccf712`, merged into main as `44b00e8`;
  - tag `v2026.10.01` + GitHub release; Zenodo DOI pending, and `publish_release_notes.R` re-runs when it lands.

**Post-release, done:**
- held shards restored;
- calcofi4db 4.17.2 installed;
- phytoplankton (#119) shards synced to `gs://calcofi-db/ingest/calcofi_phytoplankton/` (sizes match the manifest; the
  pre-#119 copy is at `~/_big/calcofi/parquet_phyto_pre119_backup`).

**Questions:**
- #128 (41 provider answers recorded) and #129 merged.
- Registries pushed to the CalCOFI / SWFSC / CDFW sheets; 19 comment threads verified intact; xlsx backups in the scratchpad.
- Not pushed yet: CCE-LTER and SIO (await Erin's review).

**Open PRs for later:**
- calcofi4db#18 + workflows#127: the depth-constant guard and Q40; do not merge before a ctd-cast render.
- docs#18: eDNA filter docs; merge at release.

---

## Release ledger: what is released, what goes out next, what is held (2026-10-01, 17:10 CEST)

The source of truth is `RELEASES.md`. `# v2026.10.01` lists what shipped; `# Unreleased` lists what is on main and not yet
released. A dataset whose notebook sets `in_release: false` never ships, whatever `# Unreleased` says, until the flag is
removed.

**1 · RELEASED, live in v2026.10.01** (`latest.txt`, promoted 16:22 CEST; tag + GitHub release; DOI pending)
- CTD: Kelsey's corrected 2607 file, plus the station-truncation repair on 2507SR, 2511SR, 2601RL and 2604SH; provider
  flags on every series; the 2607 sensor-2 flag (Q37); cruise-corrected DO (workflows #104–#106, #112).
- New dataset `calcofi_ctd-derived`: MLD, spiciness and sigma-theta over 9,630 casts (calcofi4db#11, workflows #107 #110).
- Dataset metadata: the 16 CalOOS proposals (#96); ZooDB regions Q05 (#97); crab `cruise_key` NULLs cut from 97 to 1
  (#111).
- `measurements.json` 1.1, with "why it matters" and an anomaly per depth band; the climatology runs to the bottom
  (#115); picoplankton moves to Biology.
- Packages: calcofi4db 4.17.1 at cut (EML licence link #10; STAC pending #15).
- Consumers rebuilt from it: ctd-transects (with today's display rules, #12), db-viz-station, db-query and the server
  apps; the docs book is rebuilding.

**2 · MERGED to main, ships in the NEXT release** (no further action needed)
- `cce-lter_iron` (#116): dissolved iron only, 170 samples; shards on GCS. The bioassay and total iron are held back until
  provider Q01 is answered.
- Phytoplankton names (#119): 118 codes re-keyed (*Tripos* and the lowest common ancestor); obs rows unchanged; shards on
  GCS; db-viz-station#16's labels assume it.
- The measurement-type registry rows added by the held eDNA and cetacean datasets: they ship in `measurement_type` with
  no data behind them.
- Provider answers recorded in `questions.csv` (#128, #129); metadata only.
- Requires calcofi4db ≥ 4.17.2 (installed): `release_database.qmd` now passes `exclude =` to
  `check_taxon_registries()`.

**3 · MERGED but HELD** (`in_release: false`): out of every release until the provider answers
- `sio_cetacean-sightings`, `-sonobuoy` and `-edna` (#117). Waiting on licence (Q01), citation (Q02) and the behaviour
  codebook (Q03). Un-holding is tracked in #121; Betty's items are in #120.
- `calcofi_2022-edna` (#118). Waiting on provider questions Q04–Q11 (ASV vs occurrence, controls, zero-detection
  filters, version). Tracked in #126. docs#18 merges together with it.
- To release one: answer the questions, remove `in_release: false`, re-render, and move its `RELEASES.md` entry into the
  release section.

**4 · OPEN, not merged**
- **calcofi4db#18 (4.17.3) + workflows#127**: the depth-constant guard and Q40.
  - What it does: drops `est_nitrate_cruise_corr` on 441 casts (and a few other series).
  - Before it can merge: install 4.17.3, then re-render ctd-cast (about 1 h; the fresh wrangling DB is now in main's
    `data/wrangling`), then merge.
  - It lands in the next release if it is done in time.
- **docs#18**: merges when 2022 eDNA is released.

**5 · NOT STARTED: candidates for the next release** (target before the 10/31 El Niño cruise)
- Derived products round 2, on Rasmus's defaults: MLD at 0.02 below 10 m, DCM from a 3 m running mean, integrated chl,
  nitracline, hypoxic boundaries, pycnocline, N²; geostrophic flow re-checked (#98–#103, explore#13).
- swfsc_ichthyo re-ingest from Ed's new tables: LarvaeMeasured, NetDepth, AphiaID, the true-zeros rule.
- `cruise_key_alt` + an ICES ship-code column; the bottle-based climatologies (ctd-transects#9); the monthly/seasonal
  toggle (#8).

**Housekeeping done (17:00).**
- All merged worktrees removed: `~/Github/CalCOFI/workflows-*` (4), `calcofi4db-crab109`, 41 under `.worktrees/`, and 6
  agent worktrees.
- 85 merged local branches deleted. The 3 behind open PRs are kept.
- **Kept, LOCAL-ONLY and never pushed (Ben to decide):**
  - workflows: `feat/measurement-type-membership` (06-26), `feat/station-portal-coverage` (07-03),
    `feat/test-release-dispatch-bump` (06-27), `ingest-euph-pico-meso` (07-29);
  - calcofi4db: `feat/measurement-type-dataset-membership`;
  - docs: `ws-f5`;
  - CalCOFI.github.io: `explore-card`.
- `plans_todo`: 27 completed briefs moved to `_done/`. Still active: the server pipeline, the M2 registrations, the Kuali
  pair, and WS-M6.
- The ctd-cast wrangling DB (27 GB, 9/24) was moved into main's `data/wrangling`. The stale 9/11 copy is kept as
  `*.sep11.bak`; delete it to free 27 GB.
