# Review: CalCOFI/workflows#117 "Ingest marmam-app cetacean data: sightings, sonobuoy, eDNA"

Author: Betty Huang (bhuang0022) · branch `ingest-marmam-cetaceans` (4 commits on merge-base 5c61a19, 2026-09-24) · reviewed 2026-10-01 against origin/main e23c88d, calcofi4db 4.17.1 (installed = checkout).
Read-only review; no comments posted, nothing checked out.

## Verdict

Strong, careful work, and closer to the house idiom than most first ingests. All three notebooks follow the established pattern: a `calcofi:` block with a single-file `output:` and `in_release: false`, a pinned-SHA source with `stamp_source_access()` and an archive to GCS, `cat()` not `message()`, the full taxon chain (`append_dataset_taxon` → `ensure_taxon_xref` → `ensure_taxon_lineage` → `resolve_dataset_taxon` → `check_dataset_taxon`), and an "Emit Core Tables" section built only from generic `append_*()` and `ns_key()`. `sample_key` is `dataset_key:type:id`, `geom` stays off `obs`, and `append_obs()` mints `hex_id`. Measurement types are registered and checked against declared bounds, and the run ends with `write_parquet_outputs` + `build_metadata_json` + `sync_to_gcs`. No bulk data is committed; the 16k lines of `_output/*_files/libs` match how main tracks other renders. The PR merges cleanly onto current main. The JSON sidecars are tracked as the rules require.

One blocker: the 13 new `taxon_override.csv` rows name dataset_keys that `in_release: false` keeps out of the release connection. `check_taxon_registries(halt = TRUE)` in `release_database.qmd` will stop the **next release** even though these datasets are held out.

Besides that there are a dozen should-fix items. Most are data-model or attribution calls that need Ben before these datasets ship, not before merge:
- effort status stored in `measurement_qual`
- eDNA PCR-negatives published as absences
- the eDNA time taken from ichthyo tows rather than the NCOG bottle cast
- zero/blank group sizes emitted as obs, which contradicts the proposed answer to Q13
- self-answered questions marked `answered`
- the sightings holding dropping out of the public catalog
- a missing `RELEASES.md` entry for registry rows that do ship

**Recommendation: request changes on the blocker plus the cheap Claude-fixable items (about 2–3 h), then merge with `in_release: false`. Hold release-readiness on the Ben/provider items.**

## Findings

### Blocker

**B1. New `taxon_override.csv` rows fail the next release's `check_taxon_registries()`.**
- Where: `metadata/taxon_override.csv:83-95` (13 rows for `sio_cetacean-sightings` and `sio_cetacean-edna`). The gate is `release_database.qmd:802-804` (`tx_over_all <- read_csv(taxon_override.csv)` → `check_taxon_registries(con_wdl, overrides = tx_over_all, …, halt = TRUE)`).
- Why: `check_taxon_registries()` (`calcofi4db/R/check.R:623`) takes "known" keys only from the `dataset_taxon` in `con_wdl` plus `measurement_taxon.csv`. The PR sets `in_release: false`, and `release_excluded_datasets()` drops those shards, so both dataset_keys become orphans. The release then halts with "taxon registries name dataset_key(s) nothing supplies". No dataset on main is both `in_release: false` and override-bearing, which is why this has not bitten before. CLAUDE.md says "`in_release: false` stages an ingest without releasing it (`release_excluded_datasets()` is the single source of truth)", and this check does not honour it.
- Fix [Claude can fix], about 30 min. Make the gate honour the exclusion, generically. In `release_database.qmd`, filter `tx_over_all` (and `tg_rules`, `mt_taxon_all`) with `!dataset_key %in% release_excluded_datasets(here())` before `check_taxon_registries()` / `report_taxon_overrides()`. Better still, add an `exclude =` argument to `check_taxon_registries()` in calcofi4db with a testthat fixture: a held-out key is not an orphan, and a typo still is. Do **not** remove the override rows; the ingests need them. Verify by rendering the `taxon_authority_coverage` chunk, or calling the function on a fixture.

### Should-fix

**S1. No `RELEASES.md` `# Unreleased` entry, but the release content changes.**
- Where: `RELEASES.md` (untouched); `metadata/measurement_type.csv` gets 10 new rows plus an edit to the `behavior` row's `_source_datasets`.
- Why: the released `measurement_type` table is the **whole registry** (`release_database.qmd:446-465`, `CREATE TABLE measurement_type AS SELECT … FROM _measurement_type_reg`), not the shards. The next release therefore ships `acoustic_presence`, `edna_presence`, `group_size*`, `calf_count`, `call_type` and `transect_length` with no data behind them. Rule: "Every change that alters release content adds to `# Unreleased`". The PR body's checklist defers the entry to un-holding, which misses this.
- Fix [Claude can fix], 10 min: a short Unreleased note ("measurement_type gains 10 cetacean types registered by three staged-but-unreleased SIO ingests"). Or, [needs Ben decision], filter registry rows whose only `_source_datasets` are excluded datasets out of the released table.

**S2. Sightings emit obs rows with value 0 or NULL, contradicting the proposed answer to Q13.**
- Where: `ingest_sio_cetacean-sightings.qmd:628-636` (one obs per sighting, `s.group_size_best` as is) and `:687-693` (assertions "one obs per sighting" and "value total = Best total"); `metadata/sio/cetacean-sightings/questions.csv` Q13.
- Why: Q13's proposed answer reads "keep the sighting, publish no group_size for it" for Best = 0 (8 rows) or blank (2). The notebook publishes `measurement_value` 0 or NULL instead. measurement-bounds skill: "in a long-format table a row IS an assertion that a value was measured". A 0 group size also reads as an absence to `n_present`-style consumers.
- Fix [Claude can fix once Ben picks]:
  - Either filter `WHERE s.group_size_best > 0` in the obs SELECT and change the "one obs per sighting" assert to `nrow(d_sighting) - n_unc`, keeping the sighting `sample` rows;
  - or rewrite Q13's proposal to match the code. [needs Ben decision]

**S3. The sighting's effort status lives in `measurement_qual`.**
- Where: `ingest_sio_cetacean-sightings.qmd:633` (`s.effort_status` as `measurement_qual`); `metadata/measurement_qual.csv:17-18` (code_set `cetacean-sightings`, ON/OFF); `measurement_type.csv` `group_size._qual_column`.
- Why: `measurement_qual` is a dataset's quality-flag vocabulary. Consumers apply it through `cc_qual_ok_sql()`, which keeps everything for a dataset not in `CC_QUAL_EXCLUDE`, so OFF-effort rows pass any "ok" filter. Line-transect density needs on-effort sightings only. Off-effort is not "bad data", just a different sampling regime, so a flag column is the wrong carrier. Q12 already shows the two signals disagree on 23 rows.
- Fix [needs Ben decision]: keep `measurement_qual` NULL. Two candidate carriers for effort:
  - an `obs_attribute` row `effort_status` with `bin_label` ON/OFF;
  - or the sample hierarchy itself: an on-effort sighting has a transect parent, an off-effort one does not.

  Document whichever is chosen in `quality_control_md`.

**S4. eDNA PCR-negatives are published as absences for all seven species.**
- Where: `ingest_sio_cetacean-edna.qmd:366-373`; `measurement_qual.csv:29`; Q04 (proposed).
- Why: 65 PCR-negative samples × 7 species = 455 of the 916 zeros. Only 15 obs are presences. Whether a failed amplification counts as a true non-detection is the provider's call. A consumer applying `cc_qual_ok_sql()` keeps these rows because the dataset has no exclude list.
- Fix [needs provider/Betty answer → Ben decision]: until Q04 is answered, either emit obs only for `sequenced` samples (keeping the PCR-negative samples as `sample` rows, i.e. effort with no result), or add `sio_cetacean-edna = 'not sequenced PCR negative'` to `CC_QUAL_EXCLUDE` in calcofi4r/calcofi4py/db-query. Already held by `in_release: false`; this must be settled before release.

**S5. eDNA time and cruise come from the ichthyo net-tow visit, not the NCOG bottle cast; 16 samples get no time.**
- Where: `ingest_sio_cetacean-edna.qmd:209-261` (`station_visit` = every ichthyo `sample` row, matched ±25 days around the 15th of the cruise month); the 16 CC1611 samples have NULL `datetime`.
- Why: NCOG eDNA is filtered from CTD-rosette Niskin bottles. CLAUDE.md: records lacking a cast FK use `match_by_site_datetime()` then `match_nearest_by_depth()`. Here they are matched to ichthyo site/tow/net rows instead, whichever is nearest the 15th. That is the net time, not the water-sampling time, and there is no depth match. CC1611 has CTD and bottle casts in the release (the crosswalk itself says so), so matching against `calcofi_bottle` / `calcofi_ctd-cast` would give those 16 samples a real time. It would also allow a `parent_sample_key` to the bottle sample at that depth (cross-dataset parenting has precedent in the crab's subsamples).
- Fix:
  - [Claude can fix], about 45 min: match on `site_key` + cruise against `calcofi_bottle` casts, then `match_nearest_by_depth()` to the bottle; declare the dependency.
  - [needs Ben decision]: whether to set the cross-dataset parent.

**S6. Questions marked `answered` were answered by us, but `who` names the PIs.**
- Where: `metadata/sio/cetacean-sightings/questions.csv` Q14; `metadata/sio/cetacean-sonobuoy/questions.csv` Q04 (both `answered`, "RESOLVED 2026-09-27 from the release", `who` = Hildebrand / Baumann-Pickering).
- Why: metadata-registries: `proposed` means "we have already built or reasoned an answer and want it confirmed", and `who` is who answers. These answers are well evidenced, but the provider never gave them, and the Sheet sync (`pull` writes answer/status/who) would show them as provider statements. `dataset_status.csv` repeats "Q14 answered" and "Q04 answered".
- Fix [needs Ben decision on convention; then Claude can fix], 10 min:
  - either set `status = proposed`, move the evidence into `proposed_answer`, and clear `answer`;
  - or keep `answered` with `who = Betty Huang (from release data)` and say so in the answer.

**S7. The sightings holding leaves the public catalog until it is released.**
- Where: `metadata/holdings.csv` (row `sio_cetacean-sightings` hand-deleted); `metadata/sio/cetacean-sightings/dataset_meta.yml` (`status: external` removed, per its header comment).
- Why: `holdings.csv` is GENERATED by `write_holdings_csv()` ("edit the sidecar, never this file"). Removing `status` drops the dataset from holdings. `in_release: false` keeps it out of the release `dataset` table. The EDI 262 holding therefore stops appearing on calcofi.io's dataset surfaces until un-held. `read_dataset_sidecar()` accepts `status: ingested`, an option the PR did not use.
- Fix [needs Ben decision]: either keep `status: external` (or `ingested`) on the sidecar until `in_release` flips, regenerating `holdings.csv` with `write_holdings_csv()` rather than by hand; or accept the gap.

**S8. `behavior` mixes vocabularies in one shared type.**
- Where: `ingest_sio_cetacean-sightings.qmd:655-675`; `measurement_type.csv` `behavior` row (now `farallon_bird-mammal;sio_cetacean-sightings`).
- Why: Farallon's `behavior` `bin_label`s are words (Flying, Feeding). These are bare numeric codes ("1", "34", "31") whose codebook is open (Q03, `open/high`). A consumer grouping `obs_attribute` by `behavior` gets uninterpretable codes beside labels. This is the same mistake as inventing a value: an empty label is better than a meaningless one.
- Fix [needs Ben decision]: hold the behaviour rows back until Q03 is answered (keep them in the archived source), or emit them under a dataset-specific type (`behavior_code`) until mapped.

**S9. The `core_dictionary.csv` `sample_type` vocabulary is stale.**
- Where: `metadata/core_dictionary.csv:4` lists `site, tow, net, cast, bottle, underway, transect, region_pool`. This PR adds `sighting`, `deployment`, `scan`, `water`.
- Why: `build_metadata_json(metadata_derived_csv = core_dictionary.csv …)` writes that description into these datasets' `metadata.json`, and `../docs/db.qmd:45` enumerates the same list. The docs-compendium rule says a change that alters what a chapter states updates it.
- Fix [Claude can fix], 10 min: extend the description now. Add the four types to `db.qmd:45` when `in_release` flips (or now, marked "staged").

**S10. eDNA quietly depends on the sightings dataset's metadata.**
- Where: `ingest_sio_cetacean-edna.qmd:255` (`metadata/sio/cetacean-sightings/cruise_label_crosswalk.csv`) and `:332` (`…/species_codes.csv`).
- Why: the sightings notebook validates every crosswalk key (`:385-393`: label year-month + ship NODC). eDNA reuses the file without that check, and targets does not know about the coupling.
- Fix [Claude can fix], 15 min: repeat the minted-key `stopifnot` in eDNA, or move the crosswalk and species list to a shared `metadata/sio/_cetacean/` with a small helper in `libs/`.

**S11. Funding attribution is probably the app's grant, not the data's.**
- Where: all three `dataset_meta.yml` files: `funding: "Office of Naval Research, Award N00014-22-1-2719"` (source: marmam-app `more_info_page.Rmd`).
- Why: an FY22 ONR award cannot have funded 2004–2012 sonobuoy work or 2004–2021 surveys. It is most likely the grant that built the Shiny app. The attribution rule says to write a value only with evidence for what it claims.
- Fix [needs provider/Betty answer]: blank `funding` (or label it "marmam-app development") and add it to the open citation/licence questions.

**S12. Bulk outputs staged inside OneDrive; manifests hand-edited afterwards.**
- Where: commit 6136135 rewrote `data/parquet/sio_cetacean-*/manifest.json` `path` entries from `C:/Users/bhuan/OneDrive/Documents/_big/calcofi/parquet/...` to basenames.
- Why: CLAUDE.md: "Bulk inputs and outputs live under `cc_stage_dir()` … never in Google Drive"; the same eviction and conflict-copy hazards apply to OneDrive. On Windows, `~` resolves into OneDrive-redirected Documents, so the default stage dir lands there. The hand edit is harmless (main manifests mix absolute and relative paths), but a manifest should be what `write_parquet_outputs()` wrote.
- Fix [needs Betty]: set `CALCOFI_STAGE_DIR` outside OneDrive (e.g. `C:/calcofi_stage`). [Claude can fix]: have `write_parquet_outputs()` record paths relative to the stage dir (calcofi4db, with a test), so nobody edits manifests by hand.

**S13. eDNA representation diverges from #118.**
- #117 publishes `edna_presence` (0/1 per sample × species, `obs`).
- #118 (`calcofi_2022-edna`) publishes `sequence_reads` (`obs`) plus sample-level genomics QC.
- Both are `Genomics & eDNA`. There is **no data overlap** (NCOG 2014-02 → 2016-11, 133 samples, cetacean screen, vs. the October 2022 vertebrate DwC-A, 47 filters), but cetaceans can occur in both, keyed to the same `worms:` taxa.
- Why: a consumer asking "where was humpback eDNA detected" must currently union two measurement types with different semantics.
- Fix [needs Ben decision]: pick a cross-dataset convention. For example, every eDNA ingest also emits `edna_presence` (#118 derived as `sequence_reads > 0`), with reads as the dataset-specific detail.

**S14. Possible double counting with `farallon_bird-mammal`.**
- Why: both datasets publish cetacean sightings from the same CalCOFI cruises by independent observer teams (EDI 262 Hildebrand vs. EDI 255 Sydeman). Cross-dataset sums of `obs_bio` by taxon and cruise (taxa.json `n_obs`, the Explorer) will count some animals twice.
- Fix [needs Ben decision]: a docs/Explorer note at release time, possibly a `taxa.json` per-dataset breakdown rather than a pooled count.

### Nits

- **N1.** Sonobuoy depth is set to `0::DOUBLE` (`ingest_sio_cetacean-sonobuoy.qmd:410,417`). A hydrophone is not at the surface (DIFAR is typically 30 / 120 m). Use NULL unless the provider gives the setting. [needs provider answer]
- **N2.** `UPDATE` after `add_point_geom()`:
  - Where: `ingest_sio_cetacean-sightings.qmd:421-424`; `ingest_sio_cetacean-edna.qmd:236-260`; `ingest_sio_cetacean-sonobuoy.qmd:284-288`.
  - The geometry is untagged `GEOMETRY`, so this is legal, and `match_cruise_by_track()` does the same. But the crab and phytoplankton notebooks deliberately do spatial last ("nothing has to UPDATE a table that has geometry on it").
  - Fix: reorder. [Claude can fix]
- **N3.** The sonobuoy cruise check is looser than the sightings one (`ingest_sio_cetacean-sonobuoy.qmd:293-295`): `pct > 90`, while the actual match is 3244/3244. Ratchet it to `== 100`, or add the sightings-style assertion that an unresolved label has no ichthyo occupation. [Claude can fix]
- **N4.** `link_data_source` points at `tree/main`, but the notebooks pin `7bc0e18`. Point it at `tree/7bc0e18…/data/...` so the link names the bytes read. [Claude can fix]
- **N5.** Two proposed answers describe actions the code does not take:
  - sonobuoy Q10 (positioning no-station deployments from the cruise track);
  - sightings Q13 (see S2).

  Phrase them as "would", or implement. [Claude can fix]
- **N6.** Sonobuoy lines 76, 82, 86 and 92 are kept as recorded (Q06), so `site_key`s such as `082.0 …` exist on no CalCOFI line. Fine while Q06 is pending; note it for `match_station_occupation()` at release.
- **N7.** The declared-NULL tables measure `grid_key` / `cruise_key` counts rather than asserting them (`ingest_sio_cetacean-sightings.qmd:733-757`, `ingest_sio_cetacean-edna.qmd:404-416`). That is a report, not a contract.
- **N8.** `transect_length` (km) could carry `units_nerc_p06` ULKM (check the exact match). `edna_presence` and `acoustic_presence` correctly leave `nerc_p01` empty.
- **N9.** The sightings `abstract` (from the CalOOS sheet) says "2004 to 2015", while `description` says 2004–2022. Reconcile.
- **N10.** The rendered `_output/*.html` embeds Windows paths (`C:/Users/bhuan/...`). They disappear when Ben re-renders.
- **N11.** Sonobuoy has no effort `sample_measurement` (minutes recorded per hour: `hour_span`, Q07). Worth adding once Q07 is answered, since presence per hour without effort is hard to compare.

## Questions for the data providers (Hildebrand / Baumann-Pickering / Dinasquet)

1. Licence and citation for sonobuoy and eDNA (Q01/Q02). Does the EDI 262.2 custom licence cover the 2004 and 2016–2022 sightings? Will the lab publish an EDI revision covering 2004–2022 with effort?
2. The behaviour codebook (sightings Q03): codes 0–9, 31–38 and combinations.
3. eDNA (Q04/Q07): does "not sequenced PCR negative" mean no cetacean DNA (a true absence) or a failed reaction? Which assay or marker was used, and were only these seven species screened?
4. eDNA time (Q06): NCOG cast and bottle numbers or sampling times per sample, especially the 16 CC1611 samples.
5. Sonobuoy hydrophone depth setting(s) per deployment type (DIFAR / omni).
6. Funding: is ONR N00014-22-1-2719 the data's funding or the marmam-app's? What funded 2004–2021 surveys and the 2004–2012 acoustics?
7. Does the Whale Acoustics Lab visual team overlap with the Farallon Institute observers on the same cruises (shared sightings or independent)?
8. Effort for 2022+ (Q07), and whether sonobuoys were analysed after 2012 (Q12).
9. eDNA depths of 515 m and 170 m (Q09).

## Merge-order notes

- **#117 vs main:** `git merge-tree` is clean (main has moved to e23c88d since the merge base).
- **Shared files with #118** (calcofi 2022-edna): `metadata/dataset_status.csv` **CONFLICT** (both append at the end; keep both rows). `metadata/taxon_lineage.csv` **CONFLICT** (generated cache; resolve by keeping the union of rows, or re-run `ensure_taxon_lineage()`). `metadata/measurement_type.csv` and `metadata/taxon_xref.csv` auto-merge (sorted rows at different positions). #118 also edits `RELEASES.md`; once #117 adds S1's entry, expect a trivial conflict there too.
- **Shared files with #116** (cce-lter iron): `metadata/dataset_status.csv` **CONFLICT** (append-at-end); `metadata/measurement_type.csv` auto-merges.
- **Generated files #117 touches:** `_output/_data/workflows.yml` (`build_workflows_index.R`; regenerate after the last merge rather than hand-merging), `metadata/holdings.csv`, `metadata/taxon_lineage.csv`, `metadata/taxon_xref.csv`.
- **Suggested order:** #116 → #118 → #117 last, since #117 needs the B1 fix and its registry diff is the largest. Rebase each onto the previous one, resolving `dataset_status.csv` by keeping all rows, then run `Rscript scripts/build_workflows_index.R` once at the end.
- **Before any release after merging:** B1 must be in, or the release halts at `taxon_authority_coverage`. Ben's machine has no staged parquet for these three shards; the GCS copies came from Betty's Windows render. They are held out, so this only matters when `in_release` flips: then run them through `targets` locally first.

## Estimated fix time

| Bucket | Items | Time |
|---|---|---|
| Claude, no decision needed | B1 (with a calcofi4db test), S1, S9, S10, N2–N5 | ~2–2.5 h |
| Claude, after Ben decides | S2, S3, S5, S6, S7, S8, S13 | ~2–3 h |
| Provider or Betty | S4 (Q04), S11, S12 (stage dir), N1, questions above | async |
| Release-readiness (un-holding) | licence/citation answered, S3/S4/S8 settled, docs `db.qmd` sample types, RELEASES.md entry flipped | ~1 h once answers arrive |
