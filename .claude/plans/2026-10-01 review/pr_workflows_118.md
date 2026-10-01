# Review: CalCOFI/workflows PR #118 "CalCOFI 2022-edna eDNA ingest" (bhuang0022, `ingest/2022-edna-82`)

Reviewed read-only from `origin/ingest/2022-edna-82` (4 commits, base 5c61a19; main is e23c88d). Rules: workflows/CLAUDE.md + skills core-model, metadata-registries, measurement-bounds, taxon-reference, attribution, cruise-key, pipeline-targets. Idiom comparators: `ingest_cdfw_dungeness-crab.qmd`, `ingest_cce-lter_euphausiids.qmd`, `ingest_farallon_bird-mammal.qmd` on origin/main. Evidence about run results comes from the committed rendered `_output/ingest_calcofi_2022-edna.html` (its embedded datatables) because I do not have the source zip.

## Verdict

Request changes. The notebook is well structured and mostly follows the house idiom: it uses a correct `parentEventID` sample grain, `resolve_cruise_key()` with span containment (47/47 -> `2022-10-33UD`), the full taxon chain (all 19 taxa WoRMS-resolved, `check_dataset_taxon()` halting), the write_parquet_outputs/build_metadata_json/sync_to_gcs trio, bulk files under `cc_stage_dir()`, `cat()` throughout, and a valid CC-BY-4.0 licence/DOI/citation. But it has one hard release-stopper (the `assay` obs_attribute type is not in `measurement_type.csv`, so `release_database.qmd`'s "core FK validity" `stopifnot` fails), and the data model for the headline `obs` row does not hold up: `obs` has up to 17 rows per (sample, taxon) with no ASV or assay discriminator, and the assay cannot be paired to a read count. Two of the six "new" measurement types (`reads_raw_total`, `reads_filtered_total`) have zero rows even though the PR, RELEASES.md and the notebook say they ship, and the genomics-QC values are collapsed with `MIN()` across assay runs in a way that visibly produced an implausible `otu_richness` max of 395,809. The key convention (`sample_type`) is violated. None of this needs new calcofi4db code; ~1 working day plus two Ben decisions. No merge conflicts with origin/main.

## Blockers

**B1. `assay` (obs_attribute) is not registered in `measurement_type.csv` -> release hard-stops.**
- Notebook `ingest_calcofi_2022-edna.qmd:513-519` (append_obs_attribute, `'assay'`); `metadata/measurement_type.csv` has no `assay` row (only `behavior`, the farallon precedent, is registered; the 6 "new types" at :547 omit it). `release_database.qmd:709-711` asserts every `obs_attribute.measurement_type` is in `measurement_type`, then `stopifnot("core FK validity")` at :720. Also `relationships.json` declares that FK. The ingest's own `validate_for_release(strict = FALSE)` did not catch it, and the PR body's "PK/FK integrity pass" did not test it.
- Rule: metadata-registries (registries are the vocabulary; `register_measurement_types()`); measurement-bounds ("every non-ok row resolved").
- Fix: register `assay` (grain `attribute`, category `Genomics & eDNA`, no units, `is_canonical TRUE`, `_source_datasets calcofi_2022-edna`) via `register_measurement_types()`; add an in-notebook `stopifnot(all(dbGetQuery(con, "SELECT DISTINCT measurement_type FROM obs_attribute") %in% d_meas_type$measurement_type))` plus the same for `obs` and `sample_measurement`. [Claude can fix] (10 min)

**B2. `obs` grain is undefined: many rows per (sample, taxon), and the assay cannot be paired to a value.**
- Evidence (rendered obs preview, first 50 rows): 11 of 13 distinct (sample_key, taxon_key) pairs have 2-17 rows, e.g. `003_GEM_7_10m` x `worms:137094` (Delphinus delphis) has 17 rows (12, 73, 84, 1007, 392392, 579, ...); `002_Win_6_10m_02` x `worms:137094` = 58352 and 249. The source's `occurrenceID` is evidently one row per ASV/OTU (the DwC-A DNA-derived-data extension carries a sequence per occurrence), and 76 `eventID`s sit under 47 `parentEventID`s (up to two assays per filter). Emit Core (:495-519) keeps all rows, drops the ASV identity, and writes `assay` as an `obs_attribute` row keyed only by (dataset, sample_key, taxon_key, ..., bin_label) -- `obs_attribute` has no `obs_id`. Whenever a taxon is detected by both assays in one filter (obs 3/4, 5/6 above) a consumer cannot tell which read count is D-loop and which is MiFish; a join multiplies rows.
- Consequences: "201 detections" in the PR, RELEASES.md and notebook is really 201 ASV-level records; any consumer that counts rows or sums `value` per taxon/hex mixes ASVs and mixes two assays that are not comparable.
- Rules: core-model (tidy long; `obs` is the headline occurrence; "obs_attribute" is sub-occurrence detail); dc/farallon precedent (one headline row per sample x taxon x measurement_type).
- Fix options (pick one):
  (a) aggregate to one obs row per (filter, taxon, assay): `sequence_reads` = SUM of ASV reads, `obs_attribute` rows carry `count` = n_ASVs; encode the assay in the measurement type (`sequence_reads_dloop`, `sequence_reads_12s_mifish`) so no join is needed (recommended); or
  (b) keep ASV rows but add an ASV/OTU id and the assay as obs_attribute rows that are uniquely joinable (needs an obs_id-style key, i.e. a calcofi4db change -> no).
  Either way assert uniqueness: `stopifnot(!anyDuplicated(obs[, c(sample_key, taxon_key, measurement_type)]))` for the dataset. [needs Ben decision on (a) vs alternative; Claude can implement] (2-3 h incl. re-render)

**B3. Two registered "new" types have no data, and the notebook/PR/RELEASES.md say they ship.**
- Rendered sample_measurement has 423 rows = 9 types x 47 minus 2; `reads_raw_total` and `reads_filtered_total` are absent from both the bounds table and the data. The `emof_type_map` keys at :385-387 are the long FAIRe sentence strings and evidently do not exactly match the source `measurementType` text. The cat() at :408-411 reports "11 types" from `nrow(emof_type_map)`, not from the data. Prose at :416-422 ("All 11 types here ... already carry valid_min = 0"), `tbls_redefine.csv` ("11 measurement types"), RELEASES.md (lists both types), and `measurement_type.csv:216-217` all claim them. The release registry "ships wholesale" (dc comment, `ingest_cdfw_dungeness-crab.qmd:~596`), so two empty types would be published.
- Importantly these two are the normalisers a user needs to turn read counts into relative read abundance (see honesty section).
- Fix: match on a normalised/LIKE key (or read the distinct `measurementType` values and fix the map), `stopifnot(n_distinct(d_context$measurement_type) == nrow(emof_type_map))`, and make the cat() report the data. [Claude can fix] (1 h; needs the source zip locally)

**B4. Genomics-QC values are per assay run but are collapsed to the filter with `MIN()`.**
- `:396-402`: `MIN(TRY_CAST(measurementValue AS DOUBLE))` grouped by (parentEventID, measurement_type). The comment at :392-395 and :359-361 claims values are identical across the eventID children, "checked above for ammonia; same join logic covers all seven" -- only ammonia was checked, and there is no assertion in code. Raw/filtered reads and OTU counts are by nature per assay (per eventID). Rendered bounds table: `otu_richness` max = 395,809 (min 2) -- an OTU/ASV count in the hundreds of thousands is implausible for 201 detections and looks like a read total or a `MIN` over different assays' values.
- Rule: "never aggregate silently"; core-model: a measurement is one asserted value per grain.
- Fix: (1) assert `n_distinct(value) == 1` per (parentEventID, type) for the context types or carry the assay (assay-specific types, or key those four on the eventID/assay); (2) investigate `otu_richness` against the source; (3) drop `TRY_CAST` NULLs (see S1). [Claude can fix; needs the data] [needs provider/Betty answer on what otu_richness counts] (1-2 h)

**B5. `sample_key` violates the documented key convention; `filter` is not a registered event grain.**
- `:477`/`:479` build the key with `ns_key(ds_key, 'sample', ...)` while `sample_type` is `'filter'` (:478), yielding `calcofi_2022-edna:sample:001_Win_12_...`. `docs/keys.qmd:61`, `metadata/core_dictionary.csv:3` and the core-model skill: every `sample_key` is `dataset_key:sample_type:id`; every migrated ingest passes the same literal to both (`cast`, `bottle`, `tow`, `transect`, `subsample`). It is a published primary key, so fixing it after release changes every obs/obs_attribute/sample_measurement FK.
- Also `filter` is not in `core_dictionary.csv:4`'s sample_type vocabulary and not in `../docs/db.qmd:45` (list of event types); a docs update is required in the same change (docs-compendium rule).
- Fix: `ns_key(ds_key, 'filter', ...)` in all four arms (:477, :479, :496, :514, :523) and the join in :503; add `filter` to `core_dictionary.csv` and `../docs/db.qmd`/`keys.qmd`. [Claude can fix] (30 min). Whether `filter` is the right grain name vs `sample`/`subsample` [needs Ben decision]

## Should-fix

**S1. Two NULL-valued rows in `sample_measurement`.** Rendered: `chl_fluor` 47 rows / 46 values and `dna_concentration` 47 / 46 (a `TRY_CAST` failure becomes NULL). `:522-525` has no `WHERE measurement_value IS NOT NULL` (dc: `WHERE mv IS NOT NULL`). A row asserts a measured value. Also find out what the non-numeric string was (sentinel? "not applicable"?) and record it. [Claude can fix] (20 min)

**S2. Unit is never checked.** `:371-412` maps by `measurementType` text only and never reads `measurementUnit`, yet prose claims "exact unit match" for six reused types. Add `stopifnot` on `measurementUnit` per mapped type (umol/L for nutrients, ug/L for chl_fluor, mg/L oxygen, ng/uL DNA). [Claude can fix; needs source zip] (30 min)

**S3. Hand-written registry edits and unsorted rows.** The six new rows are appended at the end of `measurement_type.csv:213-218` instead of through `register_measurement_types()` (which sorts by `measurement_type`, `R/registry.R:144`), and `chl_fluor valid_min` was hand-edited instead of `declare_measurement_bounds()`. New rows have blank `is_canonical` (peers: TRUE) and blank `variable`. The notebook then rewrites the whole shared registry on every render (`:554-560`, `write_csv(..., na = "")`) -- a side effect on a file #116/#117 also edit. Use the helpers once (a one-off script/commit), and make the notebook only `stopifnot` the types exist (dungeness-crab idiom, `:595-605`). Next `register_measurement_types()` call by anyone else will otherwise produce a re-sort diff. [Claude can fix] (30 min)

**S4. `chl_fluor valid_min = 0` on a type shared with `calcofi_mets`, not validated against that dataset.** measurement-bounds skill: "validate a proposed bound against every table the type appears in" (the `isus_v` incident). `calcofi_mets` is "NOT YET RUN" with open units/sentinel questions (dataset_status), so nobody can check that a calibrated fluorescence never goes slightly negative. The rendered bounds table in the PR still shows `chl_fluor` as `undeclared` (render predates the registry change) while the prose says all types carry bounds. Options: leave undeclared and file a `proposed` question, or declare and re-render. [needs Ben decision] (10 min)

**S5. Bounds are checked only on `edna_context`, not on `obs`.** `sequence_reads` (obs, valid_min 0) and the new types are never run through `check_measurement_bounds()` on the emitted `obs`; the bounds table does not include `sequence_reads`. Add a check on `obs`/`sample_measurement` after Emit Core and assert `out_of_range == 0` and no `undeclared`. [Claude can fix] (15 min)

**S6. Notebook `dependency:` is wrong.** `:6-7` lists `ingest_calcofi_bottle`, but the notebook reads `swfsc_ichthyo`'s staged `ship`/`cruise`/`grid` (`:324-329`). euphausiids, dungeness-crab and farallon (and bottle itself) all declare `ingest_swfsc_ichthyo`. It works only transitively; it needlessly serialises behind bottle, and bottle `modifies: ship`. Fix: `- ingest_swfsc_ichthyo`. [Claude can fix] (2 min)

**S7. `validate_for_release()` printed "FAILED" with 7 unexplained errors and the PR says validation passed.** Rendered errors: sample.parent_sample_key (47), sample.site_key (47), taxon.itis_id (12), gbif_id/ncbi_id/inat_id (79), taxon.parent_taxon_key (1). All plausible and expected, but dungeness-crab shows the accepted idiom (a declared `nullable` tribble with counts and reasons that hard-fails on drift, `ingest_cdfw_dungeness-crab.qmd:1055-1150`), because "FAILED, but expected" hides real defects. Adopt it. [Claude can fix] (45 min)

**S8. Silent-failure regression is "fixed" but not asserted.** The eventDate bug (commit 9b1a0d9: `as_datetime()` -> NA for all 47 samples while the render stayed green) is the exact failure CLAUDE.md says to encode as a permanent assertion. `:228`/`:353-354` only `cat()` counts. Add `stopifnot(!anyNA(d_sample$datetime_start_utc))`, `stopifnot(n_ck == n_all)`, `stopifnot(n_sk == n_all)`. Also `flds_redefine.csv` says the timestamp is "already UTC" -- it is an offset timestamp converted to UTC by `%z`; reword. [Claude can fix] (10 min)

**S9. Stale/false metadata sidecar text.** `metadata_derived.csv:4` says `cruise_key` is "NULL for all 47 samples ... pending Q01"; Q01 is answered and 47/47 resolve. `dataset_status.csv` still says the GCS upload permission is "unconfirmed" though the rendered Upload chunk shows three rsync uploads. `metadata_derived.csv`, `flds_redefine.csv`, `tbls_redefine.csv` describe `edna_*` working tables that are not published (the shard is the 8 core tables). Correct the cruise_key line and the status note. [Claude can fix] (15 min)

**S10. `site_key`/`parent_sample_key` are NULL for all 47 samples.** The filters were collected at CalCOFI/GEMCAP stations from Niskin bottles at 10-100 m; Explorer sections key on `sample.site_key`, and no link is made to the cast/bottle (or ichthyo site) the filter came from. dungeness-crab matches stations via `swfsc_ichthyo` (306/310). At least derive `site_key` (and `order_occ`) with `match_by_site_datetime()` and set `parent_sample_key` to the bottle/cast sample if one exists for `2022-10-33UD`. [needs provider/Betty answer: which cast/bottle? locationID is kept "for QA" but not used] (2-3 h)

**S11. Dataset citation pins the wrong version.** `dataset_meta.yml:18-21` cites "Version 1.0" and `link_others` pins `&v=1.0` (:26), while the ingested archive is v1.2 (the comment at :14-17 acknowledges this and dismisses it). The citation should name the version actually ingested; and `citation_main` carries an "accessed via GBIF.org on 2026-09-19" date (source_accessed is measured, never authored; keep the string only if it is GBIF's verbatim citation form). `contact` (a required field per `dataset_meta_fields.csv`) is missing. `keywords_gcmd: []` with a TODO is acceptable. Re-fetch the GBIF citation for v1.2 or cite the concept DOI. [needs provider/Betty answer or Claude re-fetch] (20 min)

**S12. Rendered `_output` is stale vs the committed registry.** The HTML shows `chl_fluor` as `undeclared`, and the PR's later commits changed the registry; re-render after the fixes so `_output/ingest_calcofi_2022-edna.html` matches the committed code (CLAUDE.md: confirm render by `_output` mtime). [Claude can fix] (render ~5 min)

## Nits

- `:1248` rendered output prints `character(0)` x13 from `cat(glue(...{oob_tally}))` -- vectorised over a per-type list. Print `sum(unlist(oob_tally))`.
- `identificationRemarks`, `scientificName`-level confidence, per-ASV sequence/identifier are dropped (comment :491-494 calls remarks "a guess"). Provider-supplied identification confidence should either land in `obs_attribute` or be named in `flds_redefine.csv` as intentionally dropped with the reason. [needs provider answer on what the field holds]
- `UPDATE edna_sample SET ship_key = 'RL'` (:348) runs after `add_point_geom()`. CLAUDE.md/pipeline-targets: never UPDATE a table holding a CRS-tagged `geom`. It happened to pass; set `ship_key` in the staging `transmute()` (:222) instead. [Claude can fix]
- Notebook cites "Q02, RESOLVED" and "Q01 RESOLVED" in code comments and prose as design notes; fine, but Q01-Q03 are self-answered implementation decisions with blank `who`/`asked_date` -- none is a question to the data provider (see below). `status = answered` without a provider answer is acceptable for Q01 (evidence-based); Q02/Q03 are design choices and could be `wontfix`/notes.
- `build_taxon_group()` is not called (dc/farallon/euphausiids differ: farallon does, the other two do not); check whether `taxon_group` is built centrally in the release for cetaceans, otherwise `Delphinus`/`Tursiops` miss the `calcofi:marine_mammals` group in this shard.
- Overview prose says `~50` protocol-text measurementTypes; the render says 54. Do not hard-code (CLAUDE.md "never type a number" applies to docs, but the stale count is in `flds_redefine.csv` too).
- Dataset name `2022-edna` begins with a digit and is year-keyed; confirm against the naming guide (`../docs/naming.qmd`) -- fine if Ben has agreed.
- Source archive sync (`:152-156`) publishes the whole Drive folder, including the redundant raw GBIF occurrence-download zip, to `calcofi-files-public`. Intended? (CC-BY so no licence problem.)

## Check-list results (what passed)

- `calcofi:` YAML: target_name valid R symbol, single-file `output: data/parquet/calcofi_2022-edna/manifest.json` (not a directory), `in_release` not set (so released by default -- see merge notes), `tables_owned` complete, `questions_file` set, `dataset_meta` display trio present. Dependency wrong (S6).
- Ends with `write_parquet_outputs()` + `build_metadata_json()` + `sync_to_gcs(local_dir = dir_stage, sidecar_dir = dir_parquet)`; sidecars in git are small (manifest/metadata/relationships); no parquet in git; manifest has no absolute paths; bulk unzip goes to `cc_stage_path()`, not Drive.
- Taxa: `append_dataset_taxon()` -> `ensure_taxon_xref()` -> `ensure_taxon_lineage()` -> `build_taxon_reference()` -> `resolve_dataset_taxon()` -> `check_dataset_taxon(allow = character())`; `ds_taxa_code` = the source LSID (not a cleaned name), no override, no `common_name` abuse, no per-dataset arm in calcofi4db (the PR touches no calcofi4db code). Registries grew by 25 lineage rows (Delphinus genus, Paranthias genus) and one xref row.
- Core projection is in the notebook; `geom` only on `sample`; `hex_id` is populated on `obs` (res 10); `obs` is `bio` realm -> `obs_bio` at release; `cruise_key` via `resolve_cruise_key(require_in_cruise = TRUE)`, all 47 by `span`; ship `RL` = REUBEN LASKER 33UD verified against `ship`.
- Depth: 10-100 m filters, no NaN/negative; `seafloor_depth_m` is stamped at release.
- Provider `calcofi` and licence `CC-BY-4.0` exist in `provider.csv`/`license.csv`; no `coverage_temporal/spatial` or `source_accessed` authored. `RELEASES.md` has a `# Unreleased` section (needs wording fixes after B2/B3).
- All calcofi4db functions the notebook uses exist in the checked-out calcofi4db 4.17.1 (`load_prior_tables`, `core_output_tables`, `core_relationships`, `drop_out_of_bounds`, `bounds_datatable`, `check_dataset_taxon`, `append_*`, `ns_key`, `questions_datatable`; `cc_erd` is from calcofi4r). No version bump needed; no NEWS.md entry is required (no package change).
- `_output/ingest_calcofi_2022-edna_files/libs/*` (45 files, most of the +26.8k lines) follows main's convention (1,657 such files tracked); not an issue.
- Questions CSV parses; ids/labels well-formed; statuses valid (`answered`), priorities valid. The earlier registry-schema fix is in.

## What does the eDNA measurement mean, and is it honest?

`obs.measurement_type = sequence_reads`, `value` = the source's `organismQuantity` (organismQuantityType "DNA sequence reads"), unit `count`, `denominator none`. The registry description is candid ("semi-quantitative signal, not a specimen count -- kept separate from abundance"), and RELEASES.md repeats it. That is the right framing, but the surrounding data undercuts it:
1. Reads are PCR-amplified, primer- and library-depth-dependent; summing them across ASVs, filters, hexes or assays (B2) produces numbers that read as abundance. Unit `count` is the same unit used for real organism counts; downstream tools that sum or CPUE-normalise `count`-unit obs types (db-viz-hex, Explorer) need an explicit exclusion by measurement_type/`variable`. Verify before release that nothing treats `sequence_reads` as abundance.
2. The normalisers (`reads_filtered_total`, `reads_raw_total`) are absent (B3), so users cannot compute relative read abundance even if they want it.
3. Only positive detections exist; the sample set itself is derived from `occurrence.txt`, so any filter with zero detections is missing (the 47 are only filters that detected something), and a filter run on one assay but detecting nothing in it has no row. Presence/absence (and "not detected" as meaningful) is therefore not recoverable; negative/blank controls and detection thresholds are not described. State this in the `dataset_meta.yml` `description` and registry text, and ask the provider (below).
4. Consistency with #117: `sio_cetacean-edna` uses `edna_presence` (0/1, with `measurement_qual` = sequenced/not sequenced), also category "Genomics & eDNA". The two eDNA datasets use different semantics for the same family; a cross-dataset eDNA view must not sum `sequence_reads` with `edna_presence`.

## Overlap with #117 (marmam-app eDNA) and #116

- **No sample overlap with #117**: its eDNA is NCOG cetacean detections on 2014-2016 cruises (133 samples, 931 detections, 7 species, `in_release: false`, licence `unknown`); #118 is Oct 2022 only (cruise `2022-10-33UD`, 47 filters). Different provider key (`sio` in #117 vs `calcofi` here), different measurement (`edna_presence` vs `sequence_reads`), different taxon granularity: #118 keys the D-loop Delphinus assignment at genus (`worms:137015`) and also has `D. delphis` (137094), while #117 deliberately keys `Delphinus capensis` and `D. delphis` apart. Both share funding (ONR MURI N00014-22-1-2719). They are complementary, not duplicates; a future combined eDNA view needs a rank-mismatch note for Delphinus.
- **Provider consistency**: #117 is `sio` (tentative), #118 is `calcofi` (justified in prose: published as a CalCOFI program intercalibration product). CLAUDE.md: "`provider` is the organization curating the data". [needs Ben decision]
- **#116 (iron)**: shares `metadata/measurement_type.csv`, `metadata/dataset_status.csv`, `RELEASES.md`; no domain overlap.

## Shared files #118 touches (conflict surface)

`metadata/measurement_type.csv` (6 appended rows + 5 `_source_datasets` edits + `chl_fluor valid_min`), `metadata/taxon_xref.csv` (+1 row), `metadata/taxon_lineage.csv` (+25 rows), `metadata/dataset_status.csv` (+1 row), `RELEASES.md` (+17 lines under `# Unreleased`).

- `git merge-tree origin/main origin/ingest/2022-edna-82`: **clean**, no conflicts.
- #118 + #117: conflicts in `dataset_status.csv` (both append at the end) and `taxon_lineage.csv` (adjacent inserts: #117 adds Delphinidae/Ziphiidae lineages next to #118's Delphinus block). `measurement_type.csv` and `taxon_xref.csv` auto-merge. Resolution: keep both sides.
- #118 + #116: conflicts in `RELEASES.md` and `dataset_status.csv` (both append a section/row to `# Unreleased` / end of file). `measurement_type.csv` auto-merges.
- If S3 is done (re-sorting the 6 new rows into place), only 6 small hunks move in `measurement_type.csv`; still no conflict expected with the sorted inserts in #116/#117.

## Merge-order notes

1. Fix B1-B5 first (re-render + re-validate), because #118 is the only one of the three with no `in_release: false`; as written, merging #118 puts it into the next release candidate, whose `release_database.qmd` would hard-stop at the FK check (B1) and publish two empty types (B3). If it must merge earlier, set `in_release: false` in the `calcofi:` block meanwhile.
2. Then merge #118, then #116, then #117 (or any order); whoever merges second/third resolves trivial both-sides-kept conflicts in `RELEASES.md`, `dataset_status.csv` and `taxon_lineage.csv` (re-running `ensure_taxon_lineage()` after the merge is idempotent and will dedupe).
3. Before the release that includes #118, the client-package README gates (`calcofi4r` / `calcofi4py`) must still pass; nothing here changes their examples, but `sample_type = 'filter'` is new, so run the Explorer smoke test and check nothing enumerates sample types.

## Questions for the data provider (Nastassia Patin / Garret O'Donnell; relayed via Betty)

1. Does each `occurrenceID` correspond to one ASV/OTU (a distinct sequence)? Should reads be summed to one value per filter x taxon x assay, or is each ASV (e.g. D. delphis haplotypes) scientifically meaningful and to be kept?
2. Were reads filtered by a minimum-read or minimum-replicate threshold before publication (smallest published value is ~12 reads)? Were negative/field/extraction controls run, and were contaminant reads removed? What does `organismQuantity` exclude?
3. Are filters or assay runs with no detections omitted from the archive? Can the provider supply the full filter and assay-run list (47 filters x assays), with zero-detection runs, so absence can be represented?
4. What exactly does the "Total number of OTUs or ASVs assigned to taxa" value count, and is it per filter or per assay run (the Oct-2022 `otu_richness` ranges 2 to 395,809)? Are raw/filtered read totals and OTU counts per assay run (eventID)?
5. Where do the co-collected nutrients, dissolved oxygen (mg/L) and chlorophyll fluorescence come from: the CalCOFI bottle/CTD data matched to the filter, or independent measurements? If from the bottle file, we should link the filter to its bottle/cast instead of re-publishing the values. What are the methods, detection limits (ammonia has exact zeros) and which CTD cast/Niskin did each filter come from (`locationID` like `001_Win_12_Chlamax`)?
6. What is the unit and non-numeric convention for the two values that failed numeric parsing (one chl fluorescence, one DNA concentration)?
7. How reliable are genus-level assignments such as `Paranthias` (a tropical eastern-Pacific genus) and `Delphinus` (D-loop cannot separate D. delphis and D. capensis?) -- should these be published as genus-level, or flagged?
8. Which version is the canonical citation (v1.0 on the GBIF page vs the v1.2 archive in the Drive folder), and does the provider consider this a CalCOFI program dataset or an SIO lab dataset (affects `provider`)? Are the redundant GBIF raw-download zips meant to be public?
9. What does `identificationRemarks` hold (confidence/identity %)? We currently drop it.

## Estimated fix time

- Blockers B1-B5: ~4-5 h of Claude work (B2 design decision from Ben first; B3/B4 need the source zip), plus a ~10 min render.
- Should-fix S1-S12: ~3 h, mostly parallel; S10 (site_key / cast link) may be deferred to a follow-up if the provider cannot say which cast.
- Docs: `../docs/db.qmd` + `keys.qmd` + `core_dictionary.csv` for the `filter` grain, 30 min (same change).
- Total ~1 working day, plus the provider round-trip for Q1/Q3/Q4/Q5 (which can run in parallel and does not block the structural fixes).

## Ben decisions needed

1. Obs grain/assay representation (B2): assay-specific measurement types vs another scheme; and whether ASV rows are kept.
2. `sample_type` name for a water filter (B5): `filter` vs reuse `sample`/`subsample`.
3. `provider`: `calcofi` (this PR) vs `sio` (as #117).
4. `chl_fluor valid_min = 0` on the shared type (S4): declare vs leave undeclared + proposed question.
5. Oxygen: keep `oxygen_mg_l` (as now) or convert to the unified oxygen variable (1 mL O2/L = 1.429 mg/L); the PR's "no guessed conversion" argument ignores that the conversion is a standard constant.
