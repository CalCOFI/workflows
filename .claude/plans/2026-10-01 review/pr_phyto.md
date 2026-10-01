# Review: Betty's two phytoplankton PRs (2026-10-01)

Read-only review. Nothing was checked out, commented on or pushed. Verified by reading
`origin/phyto-names` and `origin/phyto-review` diffs, re-deriving the resolution order over
`taxon_worms.csv` old vs new, re-querying 63 distinct new AphiaIDs against the WoRMS REST API
(2026-10-01), and running the JS `calcofiToLatLon` port against `calcofi4db` (matches to 5 dp).

The two PRs answer one review: Pooh's phytoplankton review relayed via Erin (db-viz-station#16's
commit message, `app.js` comments, "2026-09-28") plus Betty's own follow-ups ("find common names
anywhere", "clean and readable, no shorthand"). There is no linked issue on either PR, no review
comment and no CI on workflows (db-viz-station `check` is green). Prior art: workflows#61 (the
ingest), #76 (region geometry, Q01), Q06/Q07 in `questions.csv`.

---

## 1. CalCOFI/workflows#119 "named codes no longer 'not identified further'; one rule for unknown species"

### Verdict

Approve in substance, request changes before merge. The data work holds up: every AphiaID I
re-checked (63 distinct ones, covering all 115 changed codes) exists in WoRMS with the recorded
name, rank and status; `species` / `taxa` / row order are untouched (384 = 384, same order); the
numbers in the PR body reproduce exactly (75 → 24 codes without an AphiaID, 300 → 296 distinct keys,
115 codes change key, none other); the genus-for-"cf./sp./spp." rule agrees with the existing
override rows 337 (*Phaeocystis* cf *pouchetti* → genus) and 231/597/40 (*Pterosperma*), and with how
`sio_mesopelagic-fish` already handles "Genus sp."; it adds a Q09 row and a RELEASES.md entry. What is
missing is (a) the ingest was never run, so the new AphiaIDs are not in `taxon_xref.csv` /
`taxon_lineage.csv` and the tracked sidecars are stale, (b) the "every row should be…" check is a
`datatable()`, not an assertion, and (c) the rule lives only in a hand-edited CSV plus a code comment,
with no reproducible acquisition script and no line in the taxon-reference skill. One real
taxonomic-coherence question (Ceratium/Tripos) needs Ben.

### Blockers

1. **Ingest and `check_dataset_taxon()` never run** (PR body: "Not run here"). Grep confirms none of the
   new AphiaIDs (235923, 235972, 149219, 178185, 149272, 163347, 109562 ...) is in
   `metadata/taxon_xref.csv`; 292 distinct ids in the cache, 262 in xref, 261 in lineage. The run
   fetches them and rewrites those two registries and the tracked
   `data/parquet/calcofi_phytoplankton/{manifest,metadata,relationships}.json`; none of that is in the PR.
   Rule: CLAUDE.md "Pipeline rules" (every data ingest ends with `write_parquet_outputs()` +
   `build_metadata_json()` + `sync_to_gcs()`; a red check is a hard stop) and `pipeline-targets`
   (invalidate first, confirm by `_output/*.html` mtime, not exit code). Fix: in a worktree/clean tree
   (the main tree has uncommitted work), `tar_invalidate(ingest_calcofi_phytoplankton)`,
   `tar_make(ingest_calcofi_phytoplankton)`, confirm `check_dataset_taxon` = 0 findings and the new
   class-level table lists exactly the 19 codes, then commit xref/lineage/sidecars to the branch.
   [Claude can fix] (about 45 min; WoRMS API fetches dominate).

### Should-fix

2. **The class-level check is a report, not an assertion.** `ingest_calcofi_phytoplankton.qmd` new chunk
   (lines ~288-299 of the branch): `class_only` is printed with `datatable()` and the comment says
   "every row should be one of those two kinds". A future lookup failure silently re-creates the exact
   bug this PR fixes. Rule: `taxon-reference` ("declare allowlisted classes one key at a time with a
   reason", `check_taxon_ids()`/`check_dataset_taxon()` pattern, and the notebook's own `local_allow`).
   Fix: add `class_allow <- tribble(~species_code, ~why, ...)` for the 19 codes (16 unidentified
   classes, 64/77/619 two-genus entries), then `stopifnot(length(setdiff(class_only$species_code,
   class_allow$species_code)) == 0)`; keep the datatable for review. [Claude can fix] (20 min).

3. **Acquisition/verification is not reproducible.** "Every AphiaID was checked against the WoRMS REST API
   on 2026-09-28" and the "resolution order simulated over all 384 codes" were done in scratch code;
   `taxon_worms.csv` has no generator (grep: only read by the notebook; the earlier hand-built cache
   was also offline). Rule: memory `feedback_acquisition_reproducible` (libs/{dataset} script, not
   scratchpad). Fix: commit `libs/resolve_phytoplankton_taxa.R` (name_query -> AphiaID via
   `AphiaRecordByAphiaID`/name lookups, the Calcidiscus/Rhabdosphaera by-id fills) or at least the
   verification snippet, so the 63 ids can be re-checked. [Claude can fix] (1-2 h if a real
   generator is wanted; 20 min for a verify-only script).

4. **The "one rule" is not recorded where rules live.** It is stated in a notebook comment, Q09 and
   RELEASES.md, but not in `.claude/skills/taxon-reference/SKILL.md` (which already carries the
   override and group-label rules for this very dataset) nor CLAUDE.md's Taxa section, and
   `clean_taxon_name()` (calcofi4db 4.17.1) still maps "Actinocyclus cf curvatulus" to the species
   query, i.e. the package default is the opposite of the new rule for "cf.". Rule: CLAUDE.md
   "rules here, stories in skills". Fix: one bullet in the skill ("an unidentified species of a named
   genus keys the genus as the source spells it; a cf. is a comparison, not an assertion; two genera
   counted together fall to the class until the provider says; known species + var./form/spore key
   the species") and a half-line in CLAUDE.md's Taxa section. Also state the unlisted fourth arm
   (known species with a "var. a", "spore", "-minute form" suffix keeps the species key: codes 43, 71,
   87, 100, 507, 521, 524, 531): the PR text lists "size classes, spores" under the genus rule, but
   `Chaetoceros compressus spore` (531) still keys the species. [Claude can fix] (15 min).

5. **Release-impact statement is thin.** RELEASES.md says "`obs` rows of the 115 codes change key; the
   release measures how many". The row count is knowable now (obs stays one row per measurement, so
   159,804 total is unchanged; only `taxon_key` moves) and the consumer-visible consequence is not
   said: several codes now share one `taxon_key` within the same sample (Oxytoxum 10 codes,
   Dinophysis 8, Chaetoceros 7, Nitzschia 8, Prorocentrum 7), so a consumer that counts rows per taxon
   rather than summing per sample double-counts; `obs.obs_id` stays unique (the only gate), so
   nothing will fail. Also the "57 older rows move from a species to its genus" is 55 to a genus
   plus 2 (codes 64, 77) that now fall to the class; the 115 = 53 + 55 + 2 + 5 arithmetic should be
   stated that way. Rule: RELEASES.md contract (release-run). Fix: add the two sentences and the
   exact measured count after the staging run. [Claude can fix] (15 min).

6. **Information loss on 64 and 77.** Both previously keyed a species (*Rhizosolenia phuketensis*,
   *Mastogloia woodiana*) and now key Bacillariophyceae along with all unidentified pennates. A
   general "lowest common ancestor" reading of the rule would key the shared family/order for a
   two-genus pair (Dactyliosolen + Guinardia are both Rhizosoleniaceae) rather than the class, which
   keeps "sp. -> genus" and "two genera -> LCA" as one principle. [needs Ben decision] (policy, 10 min
   to decide; Q09(c) already asks Venrick).

7. **Ceratium vs Tripos: the genus items are siblings, not ancestors, of the species items.** Rule 2
   keys "Ceratium spp." to the source's genus (worms:109506), while its 19 species-level
   *Ceratium* codes resolve to WoRMS's current *Tripos* species (e.g. 130 *Ceratium furca* -> Tripos
   furca, 837221 etc.). A hierarchy rollup on *Tripos* will not include the 6 Ceratium genus codes
   and vice versa. This is the deliberate "genus as the source spells it" choice, but the taxon
   hierarchy (taxon-reference: "hierarchy rollups silently match nothing") makes it a real
   consequence; the same shape exists for Cladopyxis -> Micracanthodinium and Gonyaulax catenata ->
   Peridiniella (species accepted elsewhere, genus kept as source spelled). [needs Ben decision]:
   keep as is and document, or key the genus items at the accepted-synonym genus when WoRMS has moved
   the species (Tripos).

8. **`taxon_common.csv` rows are hand-inserted** (worms:109921, worms:110328). Placement and format
   match the generated rows, and `warm_taxon_common.R` never overwrites hand names, so this is
   acceptable, but the PR says the script "would take [them] automatically": simplest is to run
   `Rscript scripts/warm_taxon_common.R` after the next release so the rows come from the generator
   with the true `checked_date`, or state in the PR that they were inserted by hand. Also see
   db-viz-station#16 item 4 (the same two names duplicated client-side). [Claude can fix] (10 min).

### Nits

- RELEASES.md and PR body say "53 real names"; `taxa = "other"` code 232 (*Danasphaera indica*) has a
  real binomial but is allowlisted as "source label 'other' - no name to resolve" and is excluded from
  the new check. Pre-existing; worth one line in Q09 or the allowlist reason.
- Code 399: slip fix *Actinocyclus octonarius* resolves to the autonym variety (162770,
  rank Variety, status unassessed), because WoRMS sends the species 149164 to it as a synonym. That is
  WoRMS's accepted record, fine, but it is the only Variety-ranked key besides the one Forma (390);
  mention it as expected.
- `ds_scientific_name` in `dataset_taxon` is `scientific_name_accepted`, not what the source supplied
  (the verbatim `species`). With this PR's "species stays verbatim" principle the release still never
  carries the source's own name; see db-viz-station#16 item 3 for why that matters.
- Q09 `proposed_answer` hard-codes the code list; if the cache changes, Q09 drifts. Fine for now.
- Docs: no chapter states phytoplankton taxon policy (`../docs` db.qmd lines 145-153 describe
  `taxon`/`dataset_taxon` generically; status/portals mention phytoplankton only in passing), so no
  chapter is *made false*. A one-sentence "unidentified taxa key the coarsest rank the source
  names" in db.qmd's `dataset_taxon` bullet would be the right home once item 4 is decided
  [Claude can fix, 10 min]. No calcofi4db change is required (4.17.1 installed; override rules need
  >= 3.33.0, `append_dataset_taxon` >= 4.0.0).

### Checked and fine

- Registry hygiene: all edited CSVs parse (readr/base R, 0 problems), blanks are empty (`na = ""`
  convention kept), `questions.csv` Q09 has all 13 fields, unique global id
  `calcofi_phytoplankton_09`, `status = proposed` carries a `proposed_answer`, `who = Venrick`,
  `label` follows the Q-number.
- Override rules: `taxon_override.csv` untouched; group rows still `ds_common_name`-matched and now
  skipped for every code that has an AphiaID; no code-matched override was needed. 4 code overrides
  (231, 597, 40, 337) are excluded from the new table, correctly.
- No group-label-as-common-name: only two species common names added, no group labels.
- `taxon_group` cannot break: no `taxon_key` ends up holding codes of two different functional groups
  (checked old and new), which matters for db-viz-station#16's group totals.
- Coverage: `aphia_id` strings are unique per rank position; every `Genus` key is the real accepted
  genus (Pseudo-nitzschia 149151, Nitzschia 149045, Odontella 148963 etc.); homonym exclusions in the
  PR body hold up.

---

## 2. CalCOFI/db-viz-station#16 "Phytoplankton review fixes"

### Verdict

Good, careful work; approve after a few fixes, with one real merge-order hazard. The SQL change is
sound: the old `count(*)` really counted zeros (85% of the 159,804 rows are 0), the new presence-based
`n_obs` / `sum_value`, per-sample summation across multi-code taxa, `value > 0` exclusion of the open
-1/-13 codes (Q07), and the coarse-group rollup are all well reasoned, documented in the SQL, and
`check_data_contract.py` was extended in the same change (CI `check` is green, `node --check` on
`app.js` passes). The JS projection port matches `calcofi4db::cc_calcofi_to_lonlat` exactly. Problems
are: it commits two CI-owned data files built from an older release; it hard-codes things the
release should supply; and several statements are true only after workflows#119 is released.

### CI-owned files (the question you asked)

`public/data/regions.json` and `public/data/variables.json` are both in refresh.yml's `git add` list,
which rewrites them on every release dispatch, every Monday 09:00 UTC and on manual run. The PR
hand-commits both, built from v2026.09.11. They must be committed because `check.yml`'s
`check_data_contract.py` now requires the new columns (`source_order`, `taxon_group`, `source_names`,
`groups`, `sum_value`, `sample_years`), so CI would be red without them; this is the right call, but:

- Merge-base is already `origin/main` tip (9d4de3d, 2026-09-28 refresh), so there is **no conflict
  today**. A refresh landing before merge (next Monday or any release dispatch) produces a JSON
  conflict that must be resolved by regenerating, never by hand-merging.
- **Hazard:** if `latest.txt` moves (release containing #119) and refresh.yml runs *before* this PR
  merges, refresh rebuilds with the OLD scripts, and then merging this PR would overwrite the fresh JSONs
  with the v2026.09.11 build. Merge #16 before the release (see order) or regenerate after merge.
- After merge, manually dispatch `refresh.yml` once and confirm the committed JSONs are reproduced
  byte-for-byte apart from `version.json` `built` (this validates that the scripts, not the laptop,
  produce the committed data; `build_vars.sql` fetches a CSV over HTTPS inside the CI DuckDB CLI).
  `version.json` is not in the diff, so the `?v=<release>` cache-buster does not change: returning
  visitors can pair new `app.js` with a `regions.json` cached up to 10 min (max-age=600). `app.js`
  degrades for old files (`DS_REGION_PRESENCE`), so this is a nit, not a bug.

### Blockers

None for correctness. (The merge-order hazard above is a process blocker, handled by order.)

### Should-fix

1. **`build_vars.sql` reads another repo's `main` over HTTPS and hard-codes the dataset.**
   `scripts/build_vars.sql` (`src_order` temp table): `read_csv('https://raw.githubusercontent.com/
   CalCOFI/workflows/main/metadata/calcofi/phytoplankton/taxon_worms.csv')` with
   `'calcofi_phytoplankton' AS dataset_key`, and `row_number() OVER ()` as the list order. It works
   today (and #119 does not disturb it: `species`, `taxa` and row order are identical in the PR,
   verified), but the refresh now depends on workflows@main at run time, on file order, and on a
   dataset literal. Rule: db-viz-station CLAUDE.md "Derive dataset labels and links from the release
   instead of hardcoding" (issue #11, PR #12) and workflows' own principle that the release is the
   interface. Fix: have the release carry them: `dataset_taxon` gets `ds_sort` (source order) and
   `ds_source_name` (verbatim `species`), set in `ingest_calcofi_phytoplankton.qmd`'s `d_vocab` (today
   `ds_scientific_name` = `scientific_name_accepted`, so the source's own name never reaches the
   release); then `build_vars.sql` selects them with no URL. Short-term: pin the URL to a tag/commit
   and add a contract check that all 384 codes are found (the current `LEFT JOIN` silently yields NULL
   order for a code missing from the CSV). [needs Ben decision] (schema addition to the release;
   2-3 h across both repos; short-term pin 15 min [Claude can fix]).

2. **Parsing strings that were written for humans.** `tgrp` takes the group from
   `taxon_group.description` via `regexp_extract(description, ':\s*(.+)$')`, and
   `WHERE description NOT ILIKE '%undefined%'`. The group is already machine-readable
   (`taxon_group_key` = `calcofi_phytoplankton:diatom_centric`, `match_value` = "diatom, centric").
   Fix: use `taxon_group.match_value` (and the key's `undefined_...` suffix) instead of the free text,
   so a reworded description cannot silently null a group. [Claude can fix] (30 min).

3. **Hard-coded 20-cell exception table in the client.** `app.js` `STATION_ON_LAND` encodes
   per-cell decisions with sample counts ("5,156 samples at 080.0 051.0") that were true on
   v2026.09.11 and now live in JS, and `calcofiToLatLon` is a second implementation of
   `cc_calcofi_to_lonlat()` (matches today; will drift if the projection changes). It also moves
   **every** station marker and the coordinates shown in station panels / compare lists for **all 16
   datasets**, which the PR title and body present as a phytoplankton fix. Rule: db-viz-station
   CLAUDE.md ("Data never follows the marker", already documented) plus keep logic with the data.
   Fix: compute `lat_nominal`/`lon_nominal` in `build_stations.sql` (DuckDB has the same
   projection arithmetic, or emit from calcofi4db) and the on-land override as a small CSV in
   `metadata/`; at minimum say in the PR body that the whole map changes. [needs Ben decision]
   (scope: keep client port now, plan the build-time move; 1-2 h to move).

4. **Duplicated common names.** `COMMON_NAME_ADDS` (sea sparkle, ocean night light) duplicates
   workflows#119's `taxon_common.csv` rows. It is guarded (`!v.common_name`) so it self-retires, but
   nothing reminds anyone to delete it. Fix: add `// remove when v>= the release carrying #119` with a
   data-contract assertion that fails once the release supplies the names, or drop it and merge #119
   + release first. [Claude can fix] (10 min).

5. **Labels that are only true after #119 is released.** `TAXON_GROUP_NAMES` calls the two catch-all
   classes "Unidentified diatoms/dinoflagellates" and the comment says the classes "hold the source's
   'indistinguished ...' rows and 'pennate sp. 1'-style unknowns". On v2026.09.11 the classes also hold
   53 *named* codes (Pseudo-nitzschia, Calcidiscus, Ditylum ...), which is the bug #119 fixes. Also
   `isSppTaxon`'s comment "39 of the 40 phytoplankton genus rows are '<Genus>, uncertain species' or
   'spp.'" goes stale: after #119 there are ~55 more genus-keyed codes (cf., combined pairs, size
   classes), so "spp." now also labels e.g. "Ceratium kofoidii + C. boehmii", and the
   `GENUS_QUALIFIER` exception list (one `Liriogramma` entry) has not been rechecked. Rule: say what
   is true. Fix: update the comments and re-derive the "complex" exception list after the first
   release with #119; until then the user-visible "Unidentified" is mildly overstated.
   [Claude can fix] (30 min after release).

6. **Open provider questions are asserted in the UI.** The region card and panel print "Mean cells/L"
   unqualified while Q02 (units: "cells/L?") is `open, high` and Q07 (the -1/-13 codes) is `proposed`;
   the SQL header documents both, the UI does not. Also the SQL comment (rightly) records an
   **upstream duplication**: cruises 1202/1203 appear in two workbooks and the 2007 sheet has two
   columns both labelled "CalCOFI 0704", folded into 12 samples with two rows per code, so their sums
   (and the means) are doubled. That is an ingest bug that belongs to workflows (Q06 area), not a
   comment in a SQL file. Fix: add "(units pending provider confirmation)" to the card/legend
   and file a workflows question/issue for the 12 doubled samples. [needs Betty/Venrick answer]
   for Q02; [Claude can fix] for the wording and issue text (30 min).

### Nits

- `regionEntryFor` does a linear `.find()` over taxa per call and is called per variable per region
  during render/hover; index it once (`REGION_TAXA_BY_KEY`). 
- `innerHTML` templates interpolate `r.region_key`, `description`, `station_codes` straight from
  release data; trusted today, but `esc()` them as the other panels do.
- Panel text duplicates the same four-region description in three places (banner, card, panel).
- `build_regions.sql` now shows `n_samples` 103 (NE) vs 102 (the others) in `regions.json`; the
  ingest says 409 = 4 x 103. Worth one sentence in the SQL comment on where the missing sample goes.
- CLAUDE.md additions are good (rule, mechanism, what is true); keep.

### Brand contract basics

The light theme work uses CSS custom properties and `ccThemeNow()`, honours the existing
`cc:theme` event (calls `map.invalidateSize()` on change) and keeps dark unchanged. New hard-coded
colours live in the `MAP_INK` palette and a handful of `:root[data-theme=light]` tokens
(`--accent #00629b`, `--text #182b49`, `--muted #4b5560` ...): they are the UCSD-blue brand values and
have contrast >= 4.5:1 for text per the PR's own "contrast fixes". `?tour=off` and `?theme=` paths
were not touched. I did not render the page (read-only); a screenshot pass with `?theme=light&tour=off`
and a keyboard check of the new fold buttons (`aria-expanded` + `hidden`, good) is still worth doing.
The CARTO `key=` is unchanged and pre-existing.

---

## Merge order

1. **workflows#119**: fix items 1-5 (ingest run, assertion, skill line, wording), merge. Data-only; it
   changes nothing live until a release.
2. **db-viz-station#16**: merge next, *before* the release that carries #119 (so the release's
   `refresh.yml` dispatch regenerates the JSONs with the new scripts and the hand-built v2026.09.11
   JSON is never merged on top of a fresher one). Then dispatch `refresh.yml` manually to confirm
   reproducibility. Accept that "Unidentified diatoms" is slightly overstated until the release.
3. **Release** (with #119 in `# Unreleased`) -> `test_release` (incl. the package README gates) ->
   promote `latest.txt` -> `scripts/deploy_consumers.sh` (refresh dispatch rebuilds both files from
   the new release; then re-check the group labels and genus "spp." comments, #16 item 5).
4. Follow-ups: #16 item 1 (release carries source order + verbatim name), #119 item 6/7 decisions,
   Q09/Q02 answers from Venrick.

If #16 is delayed past the release, instead check out `origin/main`'s `public/data` into the branch
and let the refresh regenerate before merging.

## Estimated fix time

- workflows#119: Claude-fixable items 1-5, 8: about 2.5-3 h including the staging ingest run (the
  ingest itself is the slow bit). Decisions needing Ben (items 6, 7): 15-20 min.
- db-viz-station#16: Claude-fixable items 2, 4, 5 (5 after the release), 6 wording: about 1.5 h.
  Item 1/3 are design moves (2-3 h) that can follow the merge.
- Total to a mergeable state for both: about 4 h Claude time plus 2 short Ben decisions.
