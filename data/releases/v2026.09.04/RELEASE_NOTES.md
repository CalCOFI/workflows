# CalCOFI integrated database release v2026.09.04

**Release date:** 2026-09-04 · **promoted** (`latest.txt`)

## `dataset_taxon` says what the source claimed; the bird rule reads the classification; common names have one written order

Three things about taxa change under consumers, all from the taxon crosswalk plan
(`.claude/plans/2026-09-02 Taxon crosswalk — …md`, Phase 1, calcofi4db 3.29.0). None of them
moves a key for a taxon released today — the Phase 1 gate staged the Farallon vocabulary through
the new path and reproduced its v2026.08.25 `dataset_taxon` slice 156/156 rows, key for key.

- **`dataset_taxon` gains one column, `ds_source_json`** — a JSON object of whatever ids and rank
  the *source* supplied for that local taxon (`{"itis_id":174715}`,
  `{"worms_id":217452,"itis_id":161729,"gbif_id":2415428}`; NULL where it supplied nothing).
  It sits beside `taxon.worms_id` / `itis_id`, which are what the *authority* says, so the two
  can be audited against each other (`json_extract(ds_source_json, '$.itis_id')`). Nothing is
  dropped or renamed. The column is populated as each taxon-bearing ingest re-runs; a shard that
  predates it carries NULL.
- **Birds key `itis:` because their class is Aves, not because a source flag said so.**
  The rule is now stated once, in `calcofi4db::taxon_key_of()`: `itis:<tsn>` exactly when the
  taxon's class (from the cached WoRMS/ITIS lineage) is Aves and an accepted TSN resolves,
  otherwise `worms:<aphia>`, otherwise a dataset-local key the release refuses. Before, only the
  Farallon census carried an `is_bird` column, so an Aves taxon reaching the release through any
  other dataset would have keyed `worms:` and one species could have carried two keys. Every
  released bird already satisfies the new rule (113 of 113 `itis:` vocabulary taxa are class Aves;
  no `worms:` vocabulary taxon is), so no key changes; a bird with no accepted TSN would now key
  `worms:` with a note in `taxon.notes` rather than silently.
- **`common_name` follows one written precedence, applied at the release:** a human choice in
  `metadata/taxon_common.csv` (now tagged `source = "manual"`, 44 rows) > the CalCOFI species
  list's own name (`swfsc_ichthyo`) > WoRMS when it offers exactly one English vernacular > any
  other dataset's own name, in `dataset_key` order > empty. Until now the order was whichever
  ingest's shard happened to win the merge. **Consumers:** measured against v2026.08.25 with the
  new `apply_taxon_common()`, **50 of 2,125 taxa change `common_name`** — 48 that had none gain
  the vernacular their dataset publishes (20 `cce-lter_zoodb` group labels such as "COPEPODA
  CALANOIDA CALANIDAE", 8 `cce-lter_zooscan` operational classes, 20 `calcofi_phytoplankton`
  functional-group labels including "other" — see the open question below), and two are renamed
  by the tie-break for two codes of one dataset sharing a key: the code whose name *is* the
  taxon's accepted name wins, then `ds_taxon_key`. So `itis:562561` *Pterodroma sandwichensis*
  becomes "Hawaiian Petrel" (Farallon HAPE) rather than the old trinomial's "Dark-Rumped Petrel"
  (DRPE), and `worms:275218` *Syngnathus californiensis* becomes "Kelp pipefish" (ichthyo 792)
  rather than "Bay pipefish" (ichthyo 788, *S. leptorhynchus*, which carries the kelp pipefish's
  AphiaID in the species list — swfsc/ichthyo Q13). `worms:126175` *Sebastes* keeps
  "Rockfishes" under the same rule (Phase 0's plain `ds_taxon_key` order would have made it
  "Sunset rockfish"). Per rank: 44 manual, 790 `swfsc_ichthyo`, 186 WoRMS single, 175 other
  datasets, 930 empty.
- **`taxon_group` comes from a registry.** `metadata/taxon_group.csv` declares
  `calcofi:seabirds` = every observed taxon of class Aves, `calcofi:marine_mammals` = class
  Mammalia, and the eight phytoplankton functional groups by `ds_common_name`. **Consumers:**
  `calcofi:marine_mammals` loses the two sea turtles (*Chelonia mydas* `worms:137206`,
  *Lepidochelys olivacea* `worms:220293`) that the Farallon arm's "not a bird" rule put there;
  `calcofi:seabirds` is unchanged (94).

Two findings from the Phase 1 measurement that this entry does *not* fix, because each changes
released keys and needs a decision:

- **Phytoplankton species identity is collapsed in every release since the ingest.** The source
  vocabulary carries an AphiaID for 309 of its 393 codes (294 distinct — *Coscinodiscus
  curvatulus*, *Prorocentrum micans*, …), but `metadata/taxon_override.csv`'s six functional-group
  rows match on `taxa` and an override replaces the id a row already has, so 171 codes key the
  class Bacillariophyceae `worms:148899`, 144 key Dinophyceae `worms:19542`, 53 Coccolithophyceae,
  4 Dictyochophyceae: **22 distinct `taxon_key`s for 393 codes**, and the functional-group
  `taxon_group` rows hold one taxon each. The fix is the override rows (match the nine idless
  codes on `species_code`, not the group on `taxa`) or the override rule (fill, never replace),
  and it belongs with the phytoplankton ingest's move to `append_dataset_taxon()` (Phase 3).
- Rank 4 of the common-name order publishes `calcofi_phytoplankton`'s functional-group label as
  a `common_name` ("other" for 8 taxa, "undefined (code not in source definitions; Q05)" for 9).
  The label is what that ingest put in `ds_common_name`; whether it should be there is the
  ingest's question, not the precedence's.

## Farallon bird and mammal observations now come from ERDDAP

The `farallon_bird-mammal` ingest reads NOAA's ERDDAP tables (`CAC_FI_SBAS_tr` / `_obs` / `_sp` on
oceanview.pfeg.noaa.gov; workflows PR #77) instead of the March-2022 CCE-LTER DataZoo 255 export —
download-first into `data/cache/`, archived beside the DataZoo files under
`gs://calcofi-files-public/archive/farallon/bird-mammal/erddap/`, the fetch time stamped in the
ingest's `metadata.json` `sources[]` (the first ingest to measure its own `source_accessed`). The
behavior-code lookup is not on ERDDAP and stays DataZoo-sourced. Measured 2026-09-03 against the
DataZoo build that v2026.08.25 released:

- **Rows.** The two sources are identical for 1987–2018 (60,715 shared transects; every
  observation row equal). ERDDAP adds 2019, 2020 and 2022 (3,216 transects, 6,020 observation
  rows) and 490 more transects for January 2021, and carries **no observations at all for 2021**
  although it lists 956 transects for `CAC2021_1` and `CAC2021_7` — DataZoo had 625 rows for
  `CAC2021_7`. Taken as served, not patched from DataZoo; asked as farallon Q11 (high). `sample`
  60,715 → 64,421; `obs` 66,344 → 69,661; `obs_attribute` 82,418 → 87,813. `cruise_key`
  resolves on 98.1 % of transects (was 98.8 %): `CAC2022_8` joins `CAC2021_7` and `Fronts_0711`
  as NULL because the ichthyo cruise reference has no August-2022 cruise.
- **The vocabulary is declared by the ingest and resolved by the package** — the first dataset on
  the taxon plan's generic path (D3): `append_dataset_taxon()` stages ERDDAP's `_sp` codes, with
  DataZoo's ITIS TSN per code (committed once as
  `metadata/farallon/bird-mammal/species_itis_datazoo.csv`) riding along as `ds_source_json`, the
  audit value rather than the key's source; `check_dataset_taxon()` gates the render (0
  findings). For the 154 codes both lists share **every `taxon_key` is unchanged**, and the 126
  `taxon` rows already released agree on all eight compared fields (ids, name, rank, class,
  parent, kingdom, family); ERDDAP's scientific names are newer for 48 codes (*Hydrobates*,
  *Ardenna*, *Urile*, …), which changes `dataset_taxon.ds_scientific_name` only. The 28
  "Unidentified …" classes resolve through `metadata/taxon_override.csv` rows (Aves `itis:174371`
  / Mammalia `worms:1837`) instead of a fallback hard-coded in calcofi4db's farallon arm, and the
  37 existing farallon override rows match on `ds_taxa_code`.
- **Three things the source forced.** `SBIG` appears twice in `_sp` ("Mew Gull", "Short-billed
  gull") and is staged once, as *Larus brachyrhynchus*. `MEGU` — 71 observations, absent from
  `_sp` — is the pre-2021 code for the same bird and now keys **`itis:1192602`** with `SBIG`
  rather than DataZoo's *Larus canus* `itis:176832` (WoRMS has no record for *L. brachyrhynchus*,
  so the key rests on ITIS alone; 53 `obs` rows change key; farallon Q10). Nine ERDDAP-only codes
  the observations use gain a key — `GUMU` `itis:177011` (270 `obs` rows), `UNLP` (91), `SCMU`
  `itis:1192605` (36), `LOTU` `worms:137205` (26), `TOSP` `itis:1255031` (16), `CHSP` as the ITIS
  subspecies `itis:1255264` (11), `NABO`, `MABO`, `UNMT` — so on the 65,855 `obs` rows both
  builds share `taxon_key` is NULL on 727 where it was NULL on 1,177 (450 gained, none lost); six
  are excluded as gear, fish or land birds (`CRAB FISH TUNA VEVE RAPT WIWA`) and 28 unreferenced
  ERDDAP-only codes wait for the provider's include flag (Q10). `CSLI` and `XAMU`, DataZoo rows no
  observation ever used, are gone (`CASL` and `GUMU`/`SCMU` carry those observations).
- **Consumers:** this dataset's `obs` gains 2019–2020 and 2022 and loses 2021; `dataset_taxon`
  156 → 164 rows, `ds_source_json` populated (123 rows carry a DataZoo TSN);
  `calcofi:seabirds` 94 → 99 taxa (`itis:176832` leaves, six enter). The transect-level columns
  ERDDAP lacks (start/stop positions, bottom depth, Julian date) never reached the core `sample`
  table, so nothing released loses a column.

Two of the 123 Farallon cruises reach the release as transects with no observation at all —
2021-01-33UD (490 transects) and 2022-10-33UD (260) — because ERDDAP serves their effort but none of
their sightings (Q11, high). They are allowed by name in `release_database.qmd`'s orphan-cruise ratchet
rather than dropped: the effort is real as published, and a sample with no observation row never enters
an Explorer denominator. The allowance falls to zero when Farallon Institute answers.

## Phytoplankton taxa are keyed to species again

v2026.08.25 released **22** distinct `taxon_key`s for the **393** `calcofi_phytoplankton` codes.
The source (Venrick's Definitions sheet, resolved to WoRMS in the ingest's `taxon_worms.csv`)
supplies an AphiaID for 309 of them — 294 distinct species, genera and varieties — and six
`metadata/taxon_override.csv` rows matched on the functional-group label (`taxa`: "diatom,
centric" → Bacillariophyceae, "dinoflagellate, thecate" → Dinophyceae, …) replaced the id of
*every* code in their group, so 302 species-resolved codes keyed their **class**. 124,586 of
159,804 phytoplankton observations (78 %) carried a class-level `taxon_key`, and nothing said so:
the override rows were doing exactly what they declared. "That was a seriously faulty ingest to
miss that" (Ben, 2026-09-04).

**The rule now (calcofi4db 3.33.0): an override never replaces an id the source supplied,
unless it names the row by the dataset's own code.** A registry row matched on a non-code column
(`ds_common_name`, `ds_scientific_name`; the arm's `taxa`) applies only where the source supplied
no `worms_id` / `itis_id`; a row matched on `ds_taxa_code` applies always. The functional group
is what `taxon_group` is for; the species keeps its key. `resolve_dataset_taxon()` reports how
many rows each override was *skipped* for, and `release_database.qmd` shows the same table
(`report_taxon_overrides()`) beside the authority-coverage gate, with `check_taxon_registries()`
now failing the release on a registry row naming a dataset nothing supplies.

Measured on a **rendered** `ingest_calcofi_phytoplankton.qmd` (2026-09-04, the migrated
notebook against calcofi4db 3.33.0): **393 codes → 309 distinct `taxon_key`s**, up from 22 —
299 `worms:` (the source's own AphiaIDs exactly as supplied and all WoRMS-accepted; the 6 class
keys for the 70 codes the source could not resolve; the 3 genus keys of the code-matched
override rows) + the 10 allow-listed local codes (Q05). **302 codes change key**, every one a
code the source had resolved; 91 are unchanged, and no code is added or lost. The ten override
rows matched 376 vocabulary rows, applied to 74 and were skipped for 302 — a skip is the rule
working, and it is now reported rather than silent. The `taxon` shard grows 50 → **542** rows
(287 vocabulary taxa + 195 lineage ancestors), `taxon_group`'s phytoplankton memberships 24 →
**311**, and of the 159,804 phytoplankton `obs` rows (0 with a NULL `taxon_key`) **124,586**
carry a different key than v2026.08.25 released.

One thing the collapse had been hiding: code 600 "*Actinocyclus*, uncertain species." was
resolved in `metadata/calcofi/phytoplankton/taxon_worms.csv` to AphiaID 196347 — *Actinocyclus*
Ehrenberg 1831, a **nudibranch** genus (Animalia / Mollusca / Gastropoda) — a homonym of the
centric diatom *Actinocyclus* C.G. Ehrenberg 1837 (148944, Chromista / Heterokontophyta /
Bacillariophyceae). Every diatom code keyed the same class, so a wrong genus was invisible. The
source file is fixed and the code keys `worms:148944` on its own; the code-matched override row
that stood in for the fix is dropped.

Two smaller rules landed with it:

- **A group label is never a `common_name`.** "other" (×9), "undefined (code not in source
  definitions; Q05)" (×9), "coccolithophore", "silicoflagellate" and ZooScan's "eggs",
  "multiples", "nauplii", "others" reached `taxon.common_name` through the "any other dataset's
  name" rank: a functional-group label is the `ds_common_name` of every code in the group.
  `apply_taxon_common()` refuses any `taxon_group.csv` label and the label of any dataset-local
  key — 24 taxa lose a name that was not one. The group's own name in `taxon_group` is unchanged.
- **A bird with no source id keys `itis:` through name → AphiaID → linked TSN.** The generic
  path now carries the TSN WoRMS links to a name-resolved AphiaID; Farallon's `GUMU`, `MABO` and
  `NABO` resolve without their override rows (`SCMU`, `TOSP`, `CHSP` still need theirs — WoRMS
  links no TSN). No released key changes.

**Consumers:** `dataset_taxon.taxon_key` changes for 302 of the 393 `calcofi_phytoplankton`
codes and, through it, `obs.taxon_key` / `obs_bio.taxon_key` on ~124,600 phytoplankton
observations (class key → species or genus key); `taxon` gains 482 rows (287 phytoplankton
vocabulary taxa + 195 ancestors); `taxon_group`'s phytoplankton memberships grow from 24 to
311 rows, so a consumer that grouped phytoplankton by class-level `taxon_key` should group by
`taxon_group` (the functional groups) or `taxon.class` instead; `taxon.common_name` becomes NULL
for the 24 taxa that carried a group or operational-class label.

## Every taxon-bearing ingest stages its own vocabulary

Until now, seven datasets' taxon vocabularies were read by a `switch()` arm inside `calcofi4db`
that knew each source table's name and column shape — `species`, `phyto_taxon`, `zoodb_taxon`,
`zooscan_taxon`, `euphausiids_taxon`, `mesopelagic_fish_taxon`, `bird_mammal_species`. That is
the pattern calcofi4db 3.0.0 deleted from the core projection, for the reason it deleted it: the
contract was implicit, so renaming or dropping a column in a notebook changed the taxonomy
**silently**. Dropping `itis_id` from the Farallon species table would have un-keyed every
seabird — 92 % of that dataset's observations — with no error anywhere.

The vocabulary is now **declared by the ingest that owns the dataset and resolved by the
package** (`append_dataset_taxon()` → `ensure_taxon_xref()` → `ensure_taxon_lineage()` →
`resolve_dataset_taxon()` → `build_taxon_reference()` / `build_taxon_group()` →
`check_dataset_taxon()`). The declaration is explicit and a deviation is a hard stop at ingest
time rather than an `NA` at release; the ids the source supplied ride along in
`dataset_taxon.ds_source_json`; the key authority is read from the **classification**, not from a
source flag. **calcofi4db 4.0.0 deletes the seven arms**, so there is one copy of each dataset's
taxonomy and adding a dataset touches zero lines of the package.

Each migrated ingest was rendered and its `dataset_taxon` slice compared, code for code, with the
one v2026.08.25 released:

| dataset | codes | `taxon_key` identical | changed | other difference |
|---|---|---|---|---|
| `swfsc_ichthyo` | 1,167 | 1,167 | 0 | — |
| `calcofi_phytoplankton` | 393 | 91 | **302** | the section above |
| `cce-lter_zoodb` | 33 | 33 | 0 | — |
| `cce-lter_zooscan` | 23 | 23 | 0 | — |
| `cce-lter_euphausiids` | 37 | 37 | 0 | one row leaves (below) |
| `sio_mesopelagic-fish` | 90 | 90 | 0 | — |
| `farallon_bird-mammal` | 164 | 164 | 0 | migrated earlier, re-checked |

`ds_scientific_name` and `ds_common_name` are unchanged on every shared code, no code is added or
lost, `check_dataset_taxon()` reports 0 findings for each, and each dataset's `obs.taxon_key` NULL
count is unchanged (0 for ichthyo, phytoplankton, zoodb, zooscan and euphausiids; 1 for
mesopelagic fish — `UnidentifiedFish`, as before).

Three things the migration settles rather than preserves:

- **A dataset's own codes decide which taxa key locally, one at a time.** ZooScan's four
  operational bioclasses (eggs, multiples, nauplii, others — Q03) and the ten phytoplankton codes
  the Definitions sheet never defines (Q05, plus the source's own "other") are declared in the
  notebook with a reason each, so a genuinely unresolved taxon fails the render instead of hiding
  among them. The release-time allowlist stays as the backstop.
- **`cce-lter_euphausiids:euphausiidae` (`worms:110671`) leaves `dataset_taxon`.** It was minted
  by the composite-measurement crosswalk from `metadata/measurement_taxon.csv`'s rows for the old
  single-`Abundance` export, and no observation ever referenced it — the BTEDB export is species-
  and life-stage-resolved and `obs` joins on the numeric `taxon_id`. A staged dataset's
  `measurement_taxon` rows are no longer read as a vocabulary, so the unreferenced row goes.
- **A functional-group label is what the source *calls* a row, so it is `ds_common_name`.**
  Phytoplankton's `taxa` column lands there, which is the column `taxon_group.csv` matches on and
  the column the six functional-group override rows now match on — the group is a group, not a key.

`swfsc_cufes`, `calcofi_phyllosoma` and `cdfw_dungeness-crab` are unaffected: their taxa live in
`measurement_type` names, and that path is untouched.

**Consumers:** additive except the phytoplankton re-keys described in the section above. No
column is added or removed, and no other dataset's `taxon_key` changes.

## Every dataset carries a checked citation and a registered license, and the release cites itself

Nothing validated attribution before this release: 8 of 16 datasets shipped `citation_main`
empty and 13 shipped `license` empty (the other 3 were the free text `"CC BY 4.0"`), nothing
compared any of it to the source, no consumer could tell when a source had been read, and the
integrated database itself had no citation. Attribution is now a contract checked like links
(`calcofi4db::check_dataset_citation()`, 3.30.0), enforced by the workflows index build and by
the `dataset_coverage` chunk of the release, with the network half behind the same
`CALCOFI_SKIP_LINK_CHECK` as the link probe:

- **Structural, always:** `citation_main` non-empty with a year and a locator (a DOI, a URL in
  the string, or `link_data_source`); `license` an active id in the new registry
  **`metadata/license.csv`** (`CC-BY-4.0`, `CC0-1.0`, `CC-BY-NC-4.0`, `CC-BY-SA-4.0`, `US-PD`,
  `custom` — which requires `license_url` — and `unknown`); `doi` bare. An error blocks unless
  the dataset's `questions.csv` holds an `open`/`proposed` row on `related_table = dataset`
  naming the field, so a gap is either fixed or on record with the provider — never silent.
- **Against the source's own authority:** EDI's cite service, an NCEI landing page's "Cite as",
  an ERDDAP `.das`, DataCite (`rightsList` SPDX id, doi.org content negotiation), a `HEAD` on
  every declared DOI. Fetches are cached in `metadata/{provider}/{dataset}/citation_authority.json`
  (7 written: phyllosoma, phytoplankton, euphausiids, dic, farallon, mesopelagic-fish, cufes);
  a difference is reported as `authority_drift` with both strings and **never written into the
  YAML** — the author's string is the record. Today: 4 datasets `ok`, 14 findings exempt under
  the `proposed` rows WS-A1 filed plus one new one (mets Q31: its citation has no year and
  calcofi.org states no publication date), 2 drift warnings (dic abbreviates the NCEI author
  names; mesopelagic-fish differs from DataCite's APA form in initials and `[Dataset]`).
- **`source_accessed` is measured, never asserted.** Each dataset's `source_accessed` (DATE) +
  `source_accessed_method` land on `dataset`: an ingest's own `stamp_source_access()` record
  (`download` / `file_mtime`, via `build_metadata_json(sources = )`) when it has one, else the
  last commit of its `manifest.json` sidecar (`sidecar_commit`). Measured now: 15 datasets
  2026-08-25 (the v2026.08.25 pipeline run, commit 3ee7479) and cdfw_dungeness-crab 2026-09-03
  (its examined-only re-run) — the date the ingest last ran, which is the honest bound until
  ingests stamp their downloads.
- **The release cites itself:** *CalCOFI (YYYY). CalCOFI Integrated Database, release
  vYYYY.MM.DD [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California
  Department of Fish and Wildlife. https://doi.org/…* — `catalog.json` gains `citation` and
  `concept_doi` (Zenodo `10.5281/zenodo.22281994`; the version `doi` is written in by
  `publish_release_notes()` once the GitHub release tag mints it, catalog re-uploaded, objects
  untouched, `versions.json` records carry `doi`), and every `RELEASE_NOTES.md` appendix gains a
  **How to cite** section: the release line, then each dataset's `citation_main` · license.
  `.zenodo.json` and `CITATION.cff` at the repo root (generated by
  `scripts/build_citation_files.R`: the three partners as creators, every dataset's PIs as
  contributors, CC-BY-4.0 for the record while the code stays MIT) replace Zenodo's auto-filled
  "initial Zenodo release" metadata at the next tag.

**Consumers:** additive only. `dataset` gains `doi`, `license_url`, `acknowledgement`, `contact`
(from the YAML; empty where unset), `source_accessed`, `source_accessed_method`; `license` values
are SPDX ids (`CC-BY-4.0`, not `CC BY 4.0`); `metadata.json` `datasets[]` carries the same keys
plus `citation_others` as an array; `catalog.json` gains `citation`, `concept_doi` (and `doi`
once minted). Nothing is renamed or dropped.

## Every dataset's citation, license and DOI now carries the evidence for it, or a filed question

Eight of sixteen datasets shipped `citation_main` empty and thirteen shipped `license` empty, with
nothing checked against the source. Filled from each dataset's own authority (EDI's cite service +
its EML `intellectualRights`, ERDDAP `.das` globals, NCEI/DataCite landing pages, the DataZoo/
zoodb/zooscan portal policy panels), never invented: **calcofi_phytoplankton** and
**calcofi_phyllosoma** gained their EDI citation + DOI + license (CC0-1.0 and `custom`
respectively — reading the actual EML `intellectualRights` matters: EDI packages are *not*
uniformly CC-BY-4.0, and assuming so would have mislabeled both); **cce-lter_euphausiids** gained
its EDI citation + DOI + `custom` license + an `acknowledgement` field (new key, additive) carrying
the EML's required credit text; **cce-lter_zoodb** and **cce-lter_zooscan** gained a `custom`
license from their portals' Data Use Policy panels and had the NSF credit prose that was sitting in
`citation_others` moved into the new `acknowledgement` field (`citation_others` is reserved for
*additional* citations, not credit prose); **farallon_bird-mammal** and **swfsc_cufes** gained a
`custom` license pointing at their ERDDAP `.das`/data-sharing-agreement source. `calcofi_dic`,
`sio_mesopelagic-fish` and `cdfw_dungeness-crab` had their free-text `"CC BY 4.0"` normalized to
the SPDX id `CC-BY-4.0`; `dic` and `mesopelagic-fish` also gained a bare `doi:` field pulled from
their existing citation strings.

Where the source states nothing, the field stays empty rather than guessing, and a `proposed`
`questions.csv` row carries the value we'd apply once confirmed: a formal citation for zoodb (Q10),
zooscan (Q06), farallon (Q09), cufes (Q06) and pic-zooplankton (Q08, plus its license); a license
for cce-lter_picoplankton-bacteria (Q06); a citation year/URL, `US-PD` license and `pi_names` for
swfsc_ichthyo (Q10–Q12, the citation proposal reflecting the CSV export we actually ingest, dated
2025-03-24); a `CC-BY-4.0` license and `pi_names` for calcofi_bottle (Q10–Q11), calcofi_ctd-cast
(Q28–Q29, naming both Rasmus Swalethorp and Benjamin Gire) and calcofi_mets (Q29–Q30) — calcofi.org
states no license for any of its three datasets. 14 `questions.csv` rows filed across 10 files, all
`status = proposed`, `related_table = dataset`.

New additive `dataset_meta` keys used here: `doi`, `license_url`, `acknowledgement` — the columns
themselves (`ingest_yaml_to_dataset_df()` / `.dataset_entry()`) and `calcofi4db::
check_dataset_citation()` are WS-A0's, not yet merged onto this branch, so that check was not run;
`Rscript scripts/build_workflows_index.R` passes with and without `CALCOFI_SKIP_LINK_CHECK=1`
(22 links, 22 OK). No `dataset_name` / `category` / `color` / `coverage_*` changed, and no ingest
was re-run — `release_database.qmd` reads this YAML directly.

## `obs_bio` and `obs_env` are the observation tables; `obs` is a view and will be dropped in the next release

Until now the release shipped every observation row twice: `obs` (26,261,931 rows, 401 MB in 16
objects partitioned by `dataset_key`, plus a 200 MB single-file twin) and the browser-shaped pair
`obs_bio` + `obs_env` (the same rows, 22 + 287 MB) — and the copy that carried the effort
denominator was the *supplemental* one. `obs` partitioned by `dataset_key` answered no consumer's
question: an app wants one variable (`obs_env` is one ≤ 10 MB object per `measurement_type`) or the
whole bio realm (`obs_bio` is one 26 MB file), and it wants the gear and effort of the row's own
sample beside the count, not a join to `sample_measurement` on every query. So the pair becomes the
physical store and `obs` becomes a view (pre-release plan D-S1, calcofi4db 3.31.0):

- **`obs_bio` / `obs_env` gain `sample_key`, `measurement_prec` and `hex_id`** (keeping `value`,
  `root_id`, `hex7`), so each is a strict superset of `obs` under a name mapping — `realm` is the
  table, `value` is `measurement_value`. Without `sample_key` a consumer could reach only the root
  sample and lost the net / bottle grain. Both are **core** tables now (in the ERD, in
  `cc_get_db()`'s default set); `sample_root` stays supplemental. Measured on the v2026.08.28 staging
  release: `obs_bio` 21.8 → 25.6 MB, `obs_env` 286.7 → 317.2 MB (84 objects).
- **`obs` still ships this once**, and `catalog.json` marks it `deprecated: true`,
  `replaced_by: ["obs_bio", "obs_env"]`, `removed_in: "next"`; the catalog's new top-level **`views`**
  map carries `obs` → the UNION ALL that reconstructs its 18 columns under their original names
  (`SELECT obs_id, 'bio' AS realm, … value AS measurement_value … FROM {{obs_bio}} UNION ALL … FROM
  {{obs_env}}`). `calcofi4r::cc_get_db()` (1.17.0), `calcofi4py.cc_get_db()` (0.6.0) and db-query's
  `__TBL:obs__` create `obs` from that view, so `FROM obs` keeps working; the deprecated objects are
  read only where the view's sources are not loaded.
- **The gate**: `release_database.qmd` fails unless the pair reproduces `obs` per `(realm,
  dataset_key)` — row count, distinct `obs_id`s, an order-independent signature of every non-depth
  column — with no non-NULL depth changed (`check_obs_pair_parity()`; 15 groups, all equal on the
  staging release); `test_release.qmd` runs every `obs` contract row three ways (the deprecated
  objects, the view, the pair) and asserts the view's row counts and column order equal `obs`'s.
- **One deliberate difference.** A bio row whose depth is NULL in `obs` carries its sample's span
  through the pair — the tow's `depth_min_m`–`depth_max_m` — so through the view 482,250
  `swfsc_ichthyo` rows (100 % of that dataset; every other dataset's NULLs stay NULL because no
  span exists on `sample` either) now have a depth where `obs` had none. A non-NULL depth is never
  changed.

**Consumers:** read `obs_bio` / `obs_env` directly (`value`, no `realm`; effort and densities inline)
before the **next release**, when the `obs` objects are dropped and only the view remains. Through
`cc_get_db()` `SELECT * FROM obs` now returns columns in the table's order (`dataset_key` third)
where the remote view over the hive partitions returned it last; a direct reader of
`releases/{v}/parquet/obs/…` or `obs.parquet` (ERDDAP deploy, netCDF publish, the PostgreSQL
`release.*` views) is unaffected this release and must move to the pair or the catalog view by the
next. Known direct readers of `obs` to migrate: db-query (8 files), `apps/` (7), db-viz-station (5),
ctd-transects (2), db-viz-hex (2), `libs/publish_netcdf.R`, `scripts/render_release_views.R`.

### ERDDAP gains the effort denominator (D-S3)

`publish_to-erddap.qmd`'s `{dataset_key}` grain (`sql_obs()`) read `obs` + `taxon` + `sample`: a bare
count, no effort, no density — the reason erddap.calcofi.io looked "woefully absent" next to
CoastWatch's `erdCalCOFIlrvcnt`/`erdCalCOFIlrvstg` (`volume_sampled`, `standard_haul_factor`,
`percent_sorted`, `larvae_10m2`, `larvae_1000m3`), whose effort sat on the separate, un-joinable
`{dataset_key}_sample` grain. It now reads `obs_bio` (bio datasets) or `obs_env` (env datasets) —
each `dataset_key` is cleanly one realm (measured on the H1-schema rebuild of staging v2026.08.28: no
dataset splits bio/env) — **through the release catalog**
(`calcofi4r::cc_release_sources(catalog, "obs_bio"/"obs_env")`, resolved via
`libs/publish_netcdf.R`'s `cc_release_catalog()`), never a hand-built `releases/{v}/parquet` path.
Every existing column is kept; `tow_type`, `std_haul_factor`, `prop_sorted`, `volume_sampled_m3`,
`density_per_10m2`, `density_per_1000m3`, `effort_class`, `units` and `qual_ok` are added, already
computed onto the pair at release time — no join to `sample_measurement` here.

- **Falls back cleanly when a release predates D-S1.** The promoted v2026.08.25 has no `obs_bio`/
  `obs_env` in its catalog, so `HAS_OBS_PAIR` is `FALSE` and the grain reads the deprecated `obs`
  objects as before (verified live against v2026.08.25's real catalog — `cc_release_sources()`
  correctly errors "not in the catalog" and the notebook `cat()`s the fallback rather than failing).
- **New `datasets.xml` attributes**: `long_name`/`units`/`comment` on the new columns (the density
  and `effort_class` comments paraphrase `calcofi4r::cc_density_sql()`'s own documentation);
  `flag_values`/`flag_meanings` on `measurement_qual`, matched from `metadata/measurement_qual.csv`'s
  `code_set` (today only `bottle` and `ctd` are registered — matched by substring against
  `dataset_key`, so `swfsc_ichthyo` and the rest correctly get none rather than an invented one);
  `sdn_parameter_urn` from a `nerc_p01` column in `metadata/measurement_type.csv`, keyed by
  measurement_type name so it only ever lands on a `_sample` grain's pivoted effort column (never on
  a long `measurement_type`/`measurement_value` pair, which mixes quantities) — **inert today** (H2
  has not landed `nerc_p01` yet), mechanism verified with a synthetic value.
- **Investigated and NOT migrated**: `libs/publish_netcdf.R` itself has no literal `obs` reference
  (it is generic release-catalog plumbing, called with whatever table name a caller passes); the
  actual `obs` reads RELEASES.md flagged live in `publish_to-netcdf.qmd` (`CREATE TABLE obs AS …` and
  `obs_parts <- cc_release_partitions("obs", RELEASE)`, keyed by `dataset_key` from the partition
  path). Migrating it is **not mechanical**: `obs_bio` is a single unpartitioned file and `obs_env`
  is partitioned by `measurement_type`, not `dataset_key`, so the "read this dataset's one partition"
  strategy the whole ~800-line notebook is built around no longer holds for any env dataset (it would
  have to scan all 84 `obs_env` objects per dataset instead of one). Left for a dedicated follow-on.
  `scripts/render_release_views.R` also has no literal `obs` reference — its table names come from
  `../server/postgis/init/50_release_views.sql` (a sibling repo outside this brief); today it still
  resolves `obs` fine since the deprecated objects ship this release.

## The boundary layers describe themselves (`spatial_layers.json`)

The release gains one sidecar beside `coverage.json`: the boundary-layer registry
(`metadata/spatial_layers.csv` — the 19 drawable layers, their PMTiles archives, default symbology
and provenance) joined with what only the release knows: each layer's feature count, bbox, its
distinct names (the Explorer's by-name palette) and how many root samples fall inside it
(`sample_spatial`). The CalCOFI Explorer's Layers card reads this instead of hard-coding the layer
list, so a row Erin adds to the registry reaches the app at the next release with no code change
(calcofi4db 3.28.0 `build_spatial_layers()`). Not a table: `catalog.json` and consumers of the
parquet are untouched.

## The seafloor stamp runs anywhere, and an unexplained NULL fails the release

`seafloor_depth_m` is sampled from GEBCO 2025, and until now that meant one laptop's local
933 MB tile (`CALCOFI_GEBCO_TIF`'s default) — a machine without it could not run the release at
all. The same grid is now published as a streamable Cloud-Optimized GeoTIFF
(`gs://calcofi-db/bathymetry/gebco_2025_sub_ice_n90_w180_e90_cog.tif`), and the `depth_coverage`
chunk falls back to it over `/vsicurl/` range reads when no local file is present
(calcofi4db 3.27.0 `sample_seafloor()` accepts URL sources).

With that, a NULL `seafloor_depth_m` stops being one undifferentiated count: every NULL is now
classified (`calcofi4db::check_seafloor_nulls()`) as *no coordinates*, *NaN coordinate*,
*outside the GEBCO source tile* (all three are the owning ingest's `questions.csv` material —
at v2026.08.25 they were 1,360 ichthyo positions east of −90° plus 71 METS rows with no
latitude), or *inside the tile and still NULL* — which can only be a regression in the sampling
itself and now **fails the release**. Consumers see no schema change.

Alongside (not release content, but the same D29 change): `gebco_2025_calcofi.tif`, the crop
`calcofi4r::cc_bathy()` serves, was re-cut from lon −127 → −116.8 × lat 29.3 → 38.4 to
**lon −165 → −100 × lat 15 → 56** (Int16 COG) so all 360,568 released positions that fell outside
it — 24.7 %, silently reading `NA` depth — now sample a real value; `cc_bathy_depth()` warns
about the remainder instead of keeping quiet (calcofi4r 1.16.0).

## One climatology for every anomaly

Two products drew the same section — line 90, July 2026, temperature — and disagreed by the whole
signal: [ctd-transects](https://calcofi.io/ctd-transects/) showed +1 to +3.9 °C through the upper
100 m, the [Explorer](https://calcofi.io/explore/?lens=section) looked like nothing. The ocean was
not the reason. Each product computed its own baseline: ctd-transects a 1993–2013 monthly mean at 5 m
over *one arbitrary cast per grid cell*; the Explorer a mean over **all calendar months** of whatever
year range the slider held — a map of the seasonal cycle (line 90 surface: January 15.2, July 18.3,
annual 16.8 °C), which hid 1–1.5 °C of the winter and spring warmth outright; and
`calcofi4r::cc_climatology()` a third copy. The Explorer also painted +2 °C **blue**: Plotly's built-in
`RdBu` runs blue → red, the reverse of the ColorBrewer scale its name suggests.

The release now ships **`climatology`** (`calcofi4db::build_climatology()` ≥ 3.26.0): a plain mean of
the env realm of `obs` per **dataset × station × calendar month × 10 m floor depth bin × measurement
type** over **1993–2013** (Rasmus Swalethorp's CCIEA window; both phases of the 1997–99 ENSO inside it,
ends before the 2014–16 heatwave; stamped on every row as `clim_yr_min`/`clim_yr_max`), kept only where
**≥ 3 distinct cruises** contribute (`n_cruises` — a floor in observations is met by one cruise's four
casts in a nearshore cell), with `clim_n` and `clim_sd`. Partitioned by `measurement_type` like
`obs_env`. Why 10 m and not 5: `obs` carries the *thinned* CTD series (10 m grid + inflection points),
so at 5 m the off-grid bins held a third of the casts, sampled exactly where the profile bends, and
their means sat visibly off their neighbours' (station 60, July: 14.27 °C between 15.39 and 15.04).
ctd-transects, the Explorer's Sections lens and `cc_climatology()` all subtract this table now; a cell
that is absent has no baseline and its anomaly is blank, never zero. Under it the three products agree:
July 2026 on line 90 is +1.3 to +1.4 °C in the upper 50 m and +0.6 °C at 200–500 m by every reading.

**Consumers:** additive — one new default table with FKs to `grid`, `dataset` and `measurement_type`;
`cc_climatology()` returns the table's cells (with `n_cruises`) when the release has one and bins depth
by 10 m floor bins (was 5 m rounded) — `cc_transect_section()` follows. Not yet fixed: both section
products key a station on `grid_key`, and nearshore cells hold 2–4 real stations (`st30-ln90` = 90.30,
90.28, 90.27.7, 88.5/30.1); `sample.site_key` is the station and the sections will move to it.

## `coverage.json` carries taxa and categories, and `measurement_type` says which category and variable a type belongs to

The explorer's organism list waited on a 22 MB download and its variables were grouped by a keyword rule
ported from the station app. `coverage.json` (`calcofi4db::build_coverage()` ≥ 3.25.0) now carries
`taxa[]` — one row per taxon of the bio realm with names, rank, class, `n_obs`, year span, life stages and
its datasets — and `variables[].category` / `.variable` from two new `metadata/measurement_type.csv`
columns: **`category`** (one of the twelve in the new **`metadata/category.csv`** registry, which
`build_workflows_index.R` now enforces on every ingest's `category:`) and **`variable`** (the
cross-dataset crosswalk: the bottle's `temperature` and the CTD's `temperature_ave` are one variable).
Both are set with `calcofi4db::declare_measurement_fields()`, never a bare `write_csv`.

**Consumers:** additive — `coverage.json` gains keys, `measurement_type` gains two nullable columns.

## The release now cuts browser-shaped objects, and effort travels with every bio observation

Four new tables and one sidecar, built at release time by calcofi4db 3.24.0 for the CalCOFI Explorer
(plan `2026-08-28 CalCOFI Explorer …`, D4/D8), and available to every consumer:

- **`obs_bio`** (supplemental, one ~22 MB object) — the bio realm of `obs`, slim, with `root_id`,
  `year`/`quarter`/`depth_bin`, `units`, `qual_ok` (`cc_qual_ok_sql()` evaluated at release), the gear
  and effort of the observation's own sample (`tow_type`, `std_haul_factor`, `prop_sorted`,
  `volume_sampled_m3`), and **two canonical densities derived once and named** —
  `density_per_10m2` (areal: `count × std_haul_factor / prop_sorted` for C1/CB/CV/PV tows, published
  per-m² × 10) and `density_per_1000m3` (volumetric: `count / prop_sorted / volume_sampled × 1000` for
  any tow with a volume, published per-1000 m³ as is) — plus `effort_class`
  (`count_with_effort` 482 k rows, 1 dataset · `raw_count_no_effort` 355 k, 5 datasets ·
  `density_as_published` 155 k · `other_unit` 263 k). Areal and volumetric are never converted into
  each other. The expression is `calcofi4r::cc_density_sql()` ≡ `calcofi4py.density_sql()` ≡ the
  explorer's `sql/density.sql`, fixture-pinned byte for byte. `hex7` is one `UBIGINT` H3 cell at res 7;
  coarser parents are bit arithmetic (`h3_parent_sql()`), so a browser needs no `h3` extension.
- **`obs_env`** (supplemental, hive-partitioned by `measurement_type`: 84 objects, ≤ 10 MB each, 287 MB
  in all) — the env realm with the same columns, so one variable is one fetch.
- **`sample_root`** (supplemental) — one row per root sampling event with a dense, deterministic
  integer `root_id`; the join key the three objects share, and the cruise tracks.
- **`sample_spatial`** (core) — exact per-root-sample polygon membership for every polygon layer of
  `spatial`, computed once, chunked per layer (≈1 M memberships over 15 polygon layers; the four
  maritime-limit/port layers are lines and points and hold nothing). Replaces the per-app spatial join
  that exhausted the 16 GB server.
- **`coverage.json`** — n obs and root samples by dataset, dataset × station × year, dataset × year and
  dataset × variable (181 KB): the explorer's first paint and Task 14's variable-based inventory.

`metadata/measurement_type.csv` gains **`denominator`** (`area` | `volume` | `none`) so the vocabulary
is registry-owned. The default view of a taxon is the denominator that covers the most datasets *with
effort* — never largest-n (`cc_default_stage()` / `cc_default_denominator()`): Pacific sardine opens as
larva · per 10 m² · swfsc_ichthyo (6,158 rows; 1,262 manta rows excluded, available per 1000 m³), not
one number averaged over 62,898 rows in three units.

**Missing effort is an ingest task, and is now filed** — `swfsc_cufes` Q05 (pump volume), `calcofi_phyllosoma`
Q05 (volume filtered, proposed), `sio_mesopelagic-fish` Q08 (VolFilt, proposed), `farallon_bird-mammal` Q08
(transect area → a per-km² denominator, proposed), `cdfw_dungeness-crab` Q13; until they land those rows are
`raw_count_no_effort` and the app says so. **Also found by the cut:** every `swfsc_ichthyo` tow/net sample
has `depth_max_m = NULL`, so a net tow cannot be drawn as the integrated span it is (`swfsc_ichthyo` Q08).

**Consumers:** `cc_get_db()` gets `sample_spatial` by default; `obs_bio`/`obs_env`/`sample_root` are
`supplemental = TRUE` (opt in). `test_release.qmd` gains seven contract rows over the new objects.

## The Dungeness crab dataset is the examined samples

`cdfw_dungeness-crab` published its 1949–2009 sorting log's full 2,011 rows as effort-only `sample`
rows — 216 examined (sorted, each with a zero-valued *M. magister* absence `obs`) and 1,795 never
looked at. An unexamined archived jar is a fact of the deposit's sorting-log inventory, not a sample
of this dataset, so the 1,795 unsorted rows are now dropped from the core entirely rather than
carried as "sample row, no `obs`" — that shape was indistinguishable from every other reason a
sample might carry no observation. `sample` drops from 2,321 to **526** events (310 sorted
2008–2014 time-series subsamples + the 216 examined sorting-log tows); `obs` (1,456) is unchanged,
since the sorting log's absence rows were already scoped to examined tows only.
`coverage_temporal_observed` moves from a 1949 start (the full log's span) to the true examined
span, **1984-05-17 to 2014-05-03**; `coverage_spatial_observed`'s westward extent tightens from
164.1°W to 132.25°W, since the sorting log's most extreme west/north rows were all unsorted.

The California Digital Collections / UCSD Library Research Data Curation program deposited this
dataset on 2026-08-27, ahead of a minted DOI. `link_data_source` carries a placeholder Library
search URL (`https://library.ucsd.edu/dc/search?q=CalCOFI+Dungeness+crab+megalopae`, answers 200)
with a YAML comment marking it as a placeholder; `metadata/cdfw/dungeness-crab/questions.csv` Q14
tracks the DOI/object-URL ask, with the swap to `citation_main` + `link_data_source` proposed for
when it mints. The deposit's README reportedly corrects the sorting log's one positive-longitude
row (Q08) — that row is one of the dropped unsorted rows regardless, so it does not affect what
ships here; the sign fix will be applied once the deposit zips are in hand.

**Consumers:** `sample` row count and the dataset's temporal/spatial coverage change as above; no
schema change.

## The bottle's reported (`r_*`) series are interpolated, and say so

The bottle's six pre-QC `r_*` measurement types (`r_ammonium`, `r_depth`, `r_dynamic_height`,
`r_oxygen_umol_kg`, `r_salinity_sva`, `r_temperature`) carried an empty `derivation` and
`is_canonical = TRUE`, so nothing on the released type itself said they were anything other than
another canonical series a consumer could compare or interpolate from. Rasmus Swalethorp (SIO CTD
data team) confirmed 2026-09-01 (`metadata/calcofi/bottle/questions.csv` Q09): the `r_*` columns
are values *already* interpolated to standard depths in decodr, pre-QC and unflagged by design —
"when we do any kinds of data interpolations ... we should not use already interpolated data points
from the bottle database." `measurement_type.csv` now records that as `derivation` on all six types
and flips `is_canonical` to `FALSE`; `release_database.qmd` gates the release on no `r_*` type ever
carrying a `variable` crosswalk entry (the mechanism a consumer would use to compare it across
datasets in the first place).

**Consumers:** `is_canonical` flips TRUE → FALSE on `r_ammonium`, `r_depth`, `r_dynamic_height`,
`r_oxygen_umol_kg`, `r_salinity_sva`, `r_temperature` — any query selecting the default/canonical
`measurement_type` set for `calcofi_bottle` stops returning these six; they remain in `obs` under
an explicit `measurement_type` filter, now documented as pre-QC and not for further interpolation.

## Accepted CTD QC flags have a bridge to the release (unrun this round)

`ingest_calcofi_ctd-cast.qmd` gains an `apply_accepted_flags` chunk: it downloads the CTD team's
nightly-snapshotted, curator-accepted flag ledger (`gs://calcofi-db/qc/ctd/flag_accepted.parquet`,
from the PostgreSQL `ctd.flag` table — see `CLAUDE.md` § *The CTD team's PostgreSQL database*),
joins each flag to the scan it names via `(archive, _source_file, cast_key, depth_m)`, and
overwrites `ctd_measurement.measurement_qual` for the match; `release_database.qmd` gains a
warn-only `qc_flags_pending` chunk reporting the gap between the snapshot and what the last CTD
ingest render applied. **This chunk ships unrun**: the snapshot is a 600-byte header-only parquet
(0 accepted flags, last modified 2026-08-19) — the CTD team has not accepted a flag through the
ledger yet, and the CTD ingest is not re-run this round (128 min; see the "Avoiding the CTD
ingest" plan). It takes effect at the next CTD ingest render.

## Rasmus's other CTD/bottle answers become registry facts

`metadata/calcofi/bottle/questions.csv` Q09 (R_* quality-code inheritance) is `answered` — R_*
stays unflagged, and the P_qual-vs-phosphate half is split into its own row (Q12, still open, for
Ben G). `metadata/calcofi/ctd-cast/questions.csv`: Q27 (Rathburn core-station casts) is `answered`
— continue to exclude; Q09 (sensor-selection codes 1/2) is `answered` on the codes' meaning
(matches `metadata/measurement_qual.csv`), leaving the averaged-canonical-type propagation policy
as unimplemented follow-on work, not a further provider question; two new rows record answers that
were emailed 2026-08-24 but never filed — Q30 (the `orig*`/`uncorrected/` exclusion and
`separate_runs/` retention, answered) and Q31 (the seafloor-vs-GEBCO "large discrepancy" threshold,
proposed at > 500 m or > 25% beyond the deepest neighbouring cell, per the ratchet in `CLAUDE.md`
§ *Depth is a coordinate*).

## `measurement_type` carries the controlled-vocabulary ids a portal export needs

A CalCOFI measurement has always said what it is in CalCOFI's own words — `nitrate`, `umol/L`.
Every export to a portal that speaks Darwin Core or OBIS ENV-DATA then had to guess the
corresponding controlled term, and `publish_ichthyo_to-obis.qmd` did not guess: it wrote
`measurementTypeID = NA_character_` on all three of its extended-measurement blocks, because
there was nowhere in the repo for the id to live. Now there is, and it is the same registry the
release publishes (pre-release plan decision D-S2; `calcofi4db::declare_measurement_fields()`
sets them, never a bare `write_csv()`).

- **`measurement_type` gains `nerc_p01` and `units_nerc_p06`** — full NERC concept URIs for
  OBIS/DwC eMoF's `measurementTypeID` (BODC Parameter Usage Vocabulary P01) and
  `measurementUnitID` (P06). **115 of 200 types carry a P01 id; 174 of 200 carry a P06 unit id**
  (resolved against the live NVS SPARQL endpoint, 2026-09-03, deprecated concepts excluded).
- **Empty means "no concept says exactly this", never "not looked at".** An id is written only
  on an *exact* vocabulary match: a concept every one of whose stated facets — quantity, matrix,
  phase, method — this registry or the dataset's documented protocol actually supplies. A generic
  concept is an exact match at coarser specificity (`TEMPPR01`, *Temperature of the water body*,
  for a QC'd bottle temperature); one that adds a facet nobody recorded is not, which is why PAR
  is empty (`IRRDUV01` pins it to a cosine-collector radiometer) and shortwave/longwave radiation
  are empty (P01 separates downwelling from upwelling; the mets registry says only "radiation").
  `nerc_uri_prefixes()` rejects a P06 URI pasted into the P01 column.
- **The 85 types with no P01 are mostly not gaps.** **29** are taxon-bearing abundance, biomass or
  size types, where P01 encodes the taxon *in the concept* and CalCOFI carries it in `taxon_key` —
  a per-type id there would be wrong, not missing. **8** are event-level effort and sub-occurrence
  attributes (`std_haul_factor`, `prop_sorted`, `volume_sampled`, the two displacement-volume
  biomasses, `settled_volume_ml`, `stage`, `behavior`) that BODC does not model as parameters.
  The remainder split three ways: **derived or raw-instrument series** the vocabulary does not
  describe (`dynamic_height`, `specific_volume_anomaly`, `r_salinity_sva`, the `pred_*` model
  outputs, the `est_*` corrected estimates, the `*_v` sensor voltages, `dic_valve`,
  `unknown_measurement_1`/`_2`); **quantities P01 simply lacks** (dynamic height, specific volume
  anomaly, and the `c14_*` production types whose mgC/m³/half-light-day time base P06 has no unit
  for); and **quantities under-documented at the source**, which is where the useful questions are —
  the transmissometer (wavelength and path length unrecorded), `atm_pressure_slc_mb` (P01's
  sea-level-corrected concepts all name a barometer), `wave_height` / `wave_period` (P01 has only
  *significant* height and WMO-coded period), `long_wave_rad` / `short_wave_rad` (up- or
  downwelling not recorded), `het_bacteria` and `picoeukaryotes` (the flow-cytometry gating is not
  recorded), and `bottom_depth` (P01's sea-floor depth concepts all name an echo sounder).
- **One finding worth a provider's eye.** `r_ammonium` and `btl_ammonium` take P01 `AMONZZXX`
  (ammonium, NH4+) because their source columns say ammonium; the QC'd `ammonia` is left **empty**,
  because its source column is the bottle database's `NH3uM`, "Micromoles Ammonia per liter of
  seawater", and P01 keeps ammonia (NH3) and ammonium (NH4+) as separate concepts. The three are
  the same measurement, so one of the two source labels is wrong — visible now instead of resolved
  by assumption. Relates to `calcofi_bottle` Q05.

## Two new vocabulary registries: `metadata/life_stage.csv` and `metadata/gear.csv`

Neither is released as a table; both are the reference an export reads, and both follow the same
exact-match rule.

- **`life_stage.csv`** covers all **23** distinct `obs.life_stage` values, with the DwC `lifeStage`
  label and the NERC S11 concept URI where one exists (**10 of 23**), plus `life_stage_parent` for
  a substage S11 does not carve (`furcilia F1`–`F7` roll up to `furcilia`, `calyptopis C1`–`C3` to
  `calyptopis`). Two values are recorded as **not life stages at all**: euphausiid `damaged`
  (specimens too damaged to stage — `occurrenceRemarks`) and ichthyo `invert` (a provenance flag
  for the merged SWFSC invertebrate counts). `phyllosoma` has no S11 concept. And the release
  ships both `larva` (ichthyo) and `larvae` (euphausiids) for the same concept — a normalization
  gap on the euphausiid vocabulary, now visible in the registry rather than in the data alone.
- **`gear.csv`** covers all **11** `sample.tow_type` codes with a `dwc_samplingProtocol` sentence
  and the NERC L22 device URI where one is exact (**4 of 11**): `C1` → *1-metre ring net*, whose
  L22 concept states the same 1-m diameter **and** 0.8 m² mouth area the SWFSC lookup does;
  `CB` and `DC` → the generic *Bongo net* (L22 is a device catalogue, so the 600 m `DC` protocol
  does not change the device); `MT` → *Manta net*. `CV` and `PV` (the CalVET / PairoVET vertical
  egg nets) have no L22 concept at all, and `OBLIQUE` on the crab dataset is a tow geometry with
  the gear unrecorded.

## `field_dictionary` says which Darwin Core term each canonical field publishes as

`dwc_term` holds the full DwC term URI for the **12 of 57** fields one term means exactly
(`decimalLatitude`, `decimalLongitude`, `locationID`, `footprintWKT`, `eventDate`,
`scientificName`, `vernacularName`, `lifeStage`, `organismQuantity`, `sampleSizeValue`,
`measurementType`, `measurementValue`); a field Darwin Core *splits* (`depth_m` →
`minimum`/`maximumDepthInMeters`) or has no term for stays empty, and `docs/db.qmd`'s new
"Darwin Core / OBIS ENV-DATA mapping" section carries the constructions no single term can
express — `scientificNameID` from `taxon_key`, the `eventID`/`parentEventID` hierarchy from
`sample_key`/`parent_sample_key`, `organismQuantityType` from the density denominator.

Fixed on the way: `libs/build_field_dictionary.R` calls itself re-runnable but had drifted four
rows behind the CSV (`seafloor_depth_m`, `date_min`, `date_max`, `cruise_key_method` were added by
hand), so running it would have silently deleted them. It is true again.

**Consumers:** additive only — two columns on the released `measurement_type` table, and two new
files under `metadata/` that no release table reads. Nothing is renamed or dropped.

## The provider's own identifiers are columns, and the cruise key is checked against the cruise

Ed Weber asked (2026-09-02) that the integrated database adopt NOAA's UUIDs. It carries them now
as typed columns beside the namespaced keys it joins on: `sample.source_uuid` — the SWFSC site,
tow or net UUID exactly as the export ships it (NULL for the 15 datasets that mint none);
`sample.station_uuid` + `station_uuid_method` — the SWFSC station occupation any event belongs to
(ichthyo's own site/tow/net rows: their own site, `self`; a foreign row parented directly to an
ichthyo site, e.g. the Dungeness crab's examined subsamples: `parent`; every other dataset's root
sample: matched on cruise + station + occupation order (`order_occ`), or on a unique occupation
within 24 h (`datetime`) — measured at v2026.08.25, 78.0% of 35,644 bottle casts and 80.3% of
19,242 CTD casts resolve; the rest are pre-1951 or cruises the export has no stations for);
`cruise.cruise_uuid` documented as the public join key to NOAA's database (it already shipped,
691/691 populated — only its `field_dictionary.csv` note was wrong).

The `cruise` reference is completed by the release (691 → 843 rows: 152 cruises the bottle, CTD,
METS and picoplankton sources designate that the SWFSC export has no stations for — 1949–1950 and
2016–2026 mostly — stamped `cruise_key_method = 'derived'` with the datasets that carry them,
`cruise.cruise_key_datasets`), so every `sample.cruise_key` now names a cruise; before this,
153,306 sample rows and 3.8M observations keyed cruises the reference lacked, and nothing failed.
The Bold Horizon July 2019 cruise had been released as `cruise_key = "2019-07-"` (the source ship
lookup has no NODC code for it, and the correction that patches it used to run *after* the cruise
key was minted; 2,255 rows in five datasets) and is now `2019-07-39C2`
(`metadata/swfsc/ichthyo/questions.csv` Q14).

`calcofi4db::check_cruise_key_integrity()` fails the release on a malformed `cruise_key`, a key
naming no `cruise` row, a NODC that is not the cruise's ship, a `date_ym` that disagrees with the
key, an ichthyo site whose `cruise_uuid` and `cruise_key` disagree, or an event more than 31 days
outside its cruise's span (seven `calcofi_ctd-cast` casts with 1997 and 2012 timestamps inside
1999 and 2013 archives are named exceptions — `metadata/calcofi/ctd-cast/questions.csv` Q32) — plus
three ratchets (derived-row count, span overlaps between two cruises of one ship, and the
per-dataset `NULL cruise_key` backlog, largest for `calcofi_dic`, whose unmatched Niskins carry no
cruise designation at all — `metadata/calcofi/dic/questions.csv` Q07). **Consumers:** additive —
`source_uuid` + `station_uuid` + `station_uuid_method` on `sample`, `cruise_key_method` +
`cruise_key_datasets` on `cruise`, 152 new `cruise` rows; `cruise_key` values change only for Bold
Horizon 2019-07.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `climatology` | 768,880 | partitioned |
| `cruise` | 842 |  |
| `dataset` | 16 |  |
| `dataset_taxon` | 1,917 |  |
| `grid` | 218 |  |
| `lookup` | 26 |  |
| `measurement_type` | 200 |  |
| `obs` | 26,265,248 | deprecated → `obs_bio`, `obs_env` (objects removed in next) |
| `obs_attribute` | 458,184 |  |
| `obs_bio` | 1,258,665 |  |
| `obs_env` | 25,006,583 | partitioned |
| `region` | 4 |  |
| `sample` | 1,469,155 |  |
| `sample_measurement` | 589,603 |  |
| `sample_spatial` | 929,664 |  |
| `ship` | 49 |  |
| `spatial` | 13,206 |  |
| `spatial_attribute` | 148,461 |  |
| `taxon` | 2,614 |  |
| `taxon_group` | 441 |  |
| `obs_ctd_full` | 271,394,164 | supplemental |
| `obs_mets_full` | 19,927,416 | supplemental |
| `sample_root` | 421,454 | supplemental |

**23 tables, 348,657,010 rows, 2.47 GB.**

**Datasets (16):** `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 61 pass / 0 fail / 4 skip (consumer-contract suite, 2026-09-04T18:24:14Z).

**Software:** calcofi4db 4.0.2, calcofi4r 1.18.0.

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.09.04 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://doi.org/10.5281/zenodo.22310858

Cite the source datasets you use alongside the release:

- `calcofi_bottle` — CalCOFI. (2023). CalCOFI Bottle Database 194903-202105. CalCOFI.org. · *license pending*
- `calcofi_ctd-cast` — CalCOFI. (2023). CalCOFI CTD Cast Files. CalCOFI.org. · *license pending*
- `calcofi_dic` — Keeling, C.D.; Lueker, T.J.; Emanuele, G.; Dickson, A.G.; Martz, T.R.; Wolfe, W.H.; Mau, A. (2025). Discrete profile dissolved inorganic carbon, total alkalinity, water temperature and salinity measurements for CalCOFI (NCEI Accession 0301029). NOAA NCEI. https://doi.org/10.25921/3w9f-jd72 · CC-BY-4.0
- `calcofi_mets` — CalCOFI. Underway (METS) TSG/Meteorology Data. CalCOFI.org. · *license pending*
- `calcofi_phyllosoma` — CalCOFI - Scripps Institution of Oceanography and T. Koslow. 2017. Data pertaining to lobster phyllosoma, Panulirus interruptus, collection methods, locations, identification and staging (1951-2008, months of July and August) ver 4. Environmental Data Initiative. https://doi.org/10.6073/pasta/9e38121ebb26f1b59b7b39b2eff844fa · custom (https://portal.edirepository.org/nis/metadataviewer?packageid=knb-lter-cce.188.4)
- `calcofi_phytoplankton` — CalCOFI - Scripps Institution of Oceanography, California Current Ecosystem LTER, and E. Venrick. 2023. Temporal and spatial changes of the abundance and species composition of phytoplankton in the California Current from samples collected aboard CalCOFI cruises from summer 1996 through 2022. ver 4. Environmental Data Initiative. https://doi.org/10.6073/pasta/60edabfbfd85c623fce05822befaa071 · CC0-1.0 (https://creativecommons.org/publicdomain/zero/1.0/)
- `cce-lter_euphausiids` — Ohman, M.D. 2022. California Current Ecosystem Euphausiid data, Brinton and Townsend Euphausiid Database (BTEDB) ver 1. Environmental Data Initiative. https://doi.org/10.6073/pasta/4a92a0044bcd1523a4f994ece874a57d · custom (https://portal.edirepository.org/nis/metadataviewer?packageid=knb-lter-cce.313.1)
- `cce-lter_picoplankton-bacteria` — Landry, M. (2004-2023). Picoplankton and Bacteria Abundance (CalCOFI Cruise). CCE LTER. · *license pending*
- `cce-lter_zoodb` — *citation pending* · custom (https://oceaninformatics.ucsd.edu/zoodb/)
- `cce-lter_zooscan` — *citation pending* · custom (https://oceaninformatics.ucsd.edu/zooscandb/)
- `cdfw_dungeness-crab` — Rogers-Bennett, L.; Jones, E.; Klemmedson, A. (2026). CDFW Dungeness Crab Megalopae from archived CalCOFI plankton samples (1949-2014). California Department of Fish and Wildlife, published through CalCOFI / Scripps Institution of Oceanography.
 · CC-BY-4.0
- `farallon_bird-mammal` — *citation pending* · custom (https://oceanview.pfeg.noaa.gov/CalCOFI/app/resources/docs/Data_Sharing_Agreement_FarallonInstitute.pdf)
- `sio_mesopelagic-fish` — Koslow, J. Anthony (2016). CalCOFI Trawl Data. In California Cooperative Oceanic Fisheries Investigations (CalCOFI): Acoustic and Trawl Data. UC San Diego Library Digital Collections. https://doi.org/10.6075/J0BZ64DH
 · CC-BY-4.0
- `sio_pic-zooplankton` — *citation pending* · *license pending*
- `swfsc_cufes` — *citation pending* · custom (https://coastwatch.pfeg.noaa.gov/erddap/tabledap/erdCalCOFIcufes.das)
- `swfsc_ichthyo` — NOAA Fisheries SWFSC. CalCOFI Ichthyoplankton Database. · *license pending*

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.09.04")
```
```python
con = calcofi4py.cc_get_db("v2026.09.04")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.09.04/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
