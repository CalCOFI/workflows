# WS-A0 · Attribution contract — `check_dataset_citation()`, `metadata/license.csv`, `source_accessed`, `release_citation()`

**Agent:** Fable 5.1 · xhigh. **Wave 1**, own worktree in `calcofi4db` + `workflows`. **Blocks:** A1 (needs the
registry and the check to run against), A2/A3 (need the column names). **Integrator order:** merge after
E-Ph1 (calcofi4db 3.29.0); this is **3.30.0**.
**Plan:** `.claude/plans/2026-09-03 Pre-release round — …md` § *Decisions › WS-A* and § *Context › Attribution*.

## Goal

Every dataset in a release carries a citation that was checked, a license from a registry, a measured
`source_accessed`, and the release cites itself — enforced where links already are (the index build) and at
release time, without re-running any ingest.

## Read first

- `calcofi4db/R/wrangle.R`: `ingest_yaml_to_dataset_df()` (~l.2425) and `.dataset_entry()` (~l.2480) — the
  two places `dataset_meta` keys become columns; `build_metadata_json()` / `merge_metadata_json()`.
- `workflows/scripts/build_workflows_index.R` — the link-shape check and the ranged-GET liveness probe
  (`curl::new_handle(range = "0-0")`, 404/410/451 error, 5xx warn, `CALCOFI_SKIP_LINK_CHECK`). Mirror it.
- `workflows/release_database.qmd`: chunks `dataset_coverage` (where `coverage_*_observed` land on
  `dataset`), `release_notes_narrative`, the `catalog.json` write (~l.1860) and `sidecar_urls` (~l.2070).
- `calcofi4db::publish_release_notes()` — the generated appendix; add a "How to cite" section there.
- `workflows/metadata/category.csv`, `provider.csv` — registry precedents (shape, `status`, notes column).
- CLAUDE.md § "Coverage is measured, never asserted", § "RELEASES.md is not optional", the
  `release-objects` skill. `docs/db.qmd` for the field conventions.
- Verified resolvers: `https://cite.edirepository.org/cite/knb-lter-cce.254.4?style=ESIP` (200, full
  citation with DOI); ERDDAP `…/tabledap/<id>.das` globals `license` / `institution` / `creator_name` /
  `title`; NCEI landing pages carry the DOI; `https://api.datacite.org/dois/{doi}`.

## Do

1. **`metadata/license.csv`** — `license,name,url,status,notes`: `CC-BY-4.0`, `CC0-1.0`, `CC-BY-NC-4.0`,
   `CC-BY-SA-4.0`, `US-PD` (US Government work, 17 U.S.C. § 105), `custom` (requires `license_url`),
   `unknown` (fails the index unless a `questions.csv` row is open on it). `read_license_registry()`.
2. **Columns** (additive; nothing renamed): `ingest_yaml_to_dataset_df()` + `doi`, `license_url`,
   `acknowledgement`, `contact`; `.dataset_entry()` + those and `citation_others`. `citation_others` is a
   list of additional citations; `acknowledgement` is prose. Normalize the three existing `"CC BY 4.0"`
   values to `CC-BY-4.0` in their notebooks (dic, crab, mesopelagic) so the check passes before A1 runs.
3. **`check_dataset_citation(ingest_yaml, network = TRUE, cache_dir = here("metadata"))`** → one row per
   dataset: `dataset_key, finding, detail, authority, authority_citation, checked`. Findings:
   `ok` · `missing_citation` · `no_year` (no 4-digit year) · `no_locator` (no DOI, no URL in the string, no
   `link_data_source`) · `license_unregistered` · `license_custom_no_url` · `doi_unresolved` (HEAD on
   `https://doi.org/<doi>` not 30x/200) · `authority_drift` (a fetched citation differs after
   whitespace/punctuation normalisation; `detail` carries both strings) · `authority_unavailable`
   (resolver exists, fetch failed — 5xx/timeout). Resolvers, by `link_data_source` / `doi`: EDI
   (`packageid=<scope>.<id>.<rev>` or `scope=…&identifier=…` → cite service; when `rev` is absent, the
   newest via `https://pasta.lternet.edu/package/eml/<scope>/<id>`), ERDDAP (`.das` globals),
   NCEI (DOI on the landing page), DataCite for any DOI. Cache every fetch in
   `metadata/{provider}/{dataset}/citation_authority.json` (`{authority, url, citation, license,
   creator, title, checked}`) so re-runs cost nothing; **never write into a notebook's YAML** — the
   authority is a proposal, the author's string is the record.
4. **The index enforces it** (`build_workflows_index.R`): error on `missing_citation`, `no_year`,
   `no_locator`, `license_unregistered`, `license_custom_no_url`, `doi_unresolved` **unless** the dataset's
   `questions.csv` holds an `open`/`proposed` row with `related_table = dataset`; warn on
   `authority_drift` / `authority_unavailable`. The shape half always runs; the network half obeys
   `CALCOFI_SKIP_LINK_CHECK`.
5. **`source_accessed`, measured.** `source_accessed_from_git(dir_parquet)` = the last commit date of
   `data/parquet/{p}_{d}/manifest.json` (`method = "sidecar_commit"`). `stamp_source_access(files | urls)`
   for future ingest runs (`method = download | file_mtime`), folded into `metadata.json` `sources[]` by
   `build_metadata_json(sources =)`; the release prefers `sources[]` when present. Both land on `dataset`
   as `source_accessed` (DATE) + `source_accessed_method` in the `dataset_coverage` chunk. Not asserted
   in any YAML.
6. **`release_citation(version, date, doi = NULL)`** — decided wording: *CalCOFI (YYYY). CalCOFI
   Integrated Database, release vYYYY.MM.DD [Data set]. Scripps Institution of Oceanography, NOAA
   Fisheries, and California Department of Fish and Wildlife. https://doi.org/<doi>* (the db-schema
   URL until the DOI exists). Into `catalog.json` as `citation` (+ `doi` when known); into every
   `RELEASE_NOTES.md` appendix as "How to cite" (the release string, then each dataset's
   `citation_main` + license). **Zenodo:** `.zenodo.json` at the repo root (title, creators = the three
   partners as organisations, `contributors` = the PIs from `pi_names`, license CC-BY-4.0,
   `related_identifiers` → the GCS release URL and db-schema, keywords) and `CITATION.cff`
   (`type: dataset`, same creators, `version`, `doi` placeholder); `zenodo_doi_for_tag(tag)` queries
   `https://zenodo.org/api/records?q=…` for the record of this repo's tag and returns the version +
   concept DOIs; `publish_release_notes()` calls it and writes the DOI into the notes, `versions.json`
   and the catalog's `doi` (the catalog is re-uploaded; objects untouched). The tag + GitHub release
   themselves are WS-F's step.
   **Measured 2026-09-03 (Ben enabled Zenodo):** tag `v2026.09.03-alpha` → GitHub pre-release "initial
   Zenodo release" → Zenodo version DOI `10.5281/zenodo.22281995`, **concept DOI `10.5281/zenodo.22281994`**
   (cite the concept DOI for "all versions", the version DOI for a release). Without `.zenodo.json`
   Zenodo auto-filled title "CalCOFI/workflows: initial Zenodo release", license `mit-license` (from
   `LICENSE`), creators "Ben Best" and "bhuang0022" — exactly what `.zenodo.json` must override: title
   "CalCOFI Integrated Database", `upload_type: dataset`, creators = the three partners (organisational
   names, ROR ids where Zenodo accepts them), `contributors` = PIs from `pi_names` + Ben/Betty as
   `DataCurator`, `license: cc-by-4.0` for the record (the code stays MIT in `LICENSE`; say so in the
   description), `version` = the tag, `related_identifiers` = the GCS release URL (`isSupplementTo`),
   db-schema (`isDocumentedBy`). Ben's README badge is the GitHub-linked one (`zenodo.org/badge/447789885.svg` → `latestdoi/447789885`, resolving to the newest version DOI) — keep it; the **concept DOI** goes in `CITATION.cff`, `release_citation()`'s "all versions" form and the docs cite page. Release tags
   are `vYYYY.MM.DD` (the alpha tag is the only exception); `zenodo_doi_for_tag()` searches
   `https://zenodo.org/api/records?q=related.identifier:"…/tree/<tag>"` and falls back to listing the
   concept's versions.
7. Tests (`tests/testthat/test-citation.R`): one fixture per finding; the resolver parsers on saved
   responses (no network in tests); `release_citation()` byte-pinned; `source_accessed_from_git()` on a
   temp repo.
8. `RELEASES.md # Unreleased`: "Every dataset carries a checked citation and a registered license, and
   the release cites itself" — what was wrong (8 of 16 empty, 3 licenses, nothing checked), what is
   true now, the new columns, `**Consumers:**` additive. CLAUDE.md: a short § "Attribution is a
   contract, checked like links" (if CLAUDE.md is being compacted into skills, put the mechanics in a
   new `attribution` skill and leave the rule in CLAUDE.md).

## Gates

- `devtools::test()` green; `Rscript scripts/build_workflows_index.R` with `CALCOFI_SKIP_LINK_CHECK=1` and
  without; before A1 lands the check reports exactly the 8 empty citations and 13 empty licenses.
- A staging render of `release_database.qmd` is **not** required here; F verifies `dataset.parquet`.

## Do not

- Parse authors/titles out of free text; invent a license; write authority strings into YAML; add
  `coverage_*` keys; rename or drop a `dataset` column; bump calcofi4db before E-Ph1 is merged.

## Hand back

The finding table for the 16 datasets, the new column list, the `RELEASES.md` entry text, and one
*Measured* line for the umbrella plan.

## Measured (WS-A0, Fable, 2026-09-03)

- Pre-A1 YAML (4ba51f2), structural half: **8 `missing_citation`, 13 `missing_license`, 3
  `license_unregistered`** (`"CC BY 4.0"`: dic, crab, mesopelagic), 2 `no_year` (mets, ichthyo), 2
  `no_locator` (crab, ichthyo) — the gate's 8 + 13, plus the free-text licenses.
- Merged YAML (A1 + C), network on: **0 blocking**, 4 `ok` (phyllosoma, phytoplankton, euphausiids,
  crab), **14 exempt** under A1's `proposed` rows + one new (mets **Q31**: no year, calcofi.org states
  no publication date), **2 `authority_drift` warnings** (dic vs NCEI "Cite as": abbreviated author
  names; mesopelagic vs DataCite APA: initials + `[Dataset]`). 7 `citation_authority.json` caches.
- Resolvers: EDI cite service 200 with a revision; **PASTA `listDataPackageRevisions` and search
  answer 403 to public access** (the brief's newest-revision route) → newest found by probing the
  cite service (rev+1 answers 400). NCEI landing page carries "Cite as" + DOI; ERDDAP `.das` has
  no `citation` global for Farallon/CUFES; DataCite `rightsList` is empty for EDI DOIs, SPDX
  `cc-by-4.0` for NCEI; doi.org content negotiation needs the redirect followed (302 →
  data.crosscite.org). Zenodo: the tree-identifier query works only URL-encoded (bare `"` → 400);
  `related_identifiers` scheme `url`, relation `isSupplementTo`, resource_type `software`; without
  `.zenodo.json` the version came from the tag.
- `source_accessed` (sidecar_commit): 15 datasets 2026-08-25 (3ee7479, the v2026.08.25 run), crab
  2026-09-03 (b0cd895) — "when the ingest last ran", not the download date.
- Zenodo's legacy `.zenodo.json` creator schema has no ROR field → none written.
