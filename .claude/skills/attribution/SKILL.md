---
name: attribution
description: "The attribution contract — check_dataset_citation() and its findings, metadata/license.csv, the citation_authority.json cache and the resolvers (EDI, NCEI, ERDDAP, DataCite), question-row exemptions, measured source_accessed, release_citation() / catalog citation / How to cite, .zenodo.json + CITATION.cff and the Zenodo DOI flow. Load before touching a dataset_meta citation/license/doi key, calcofi4db R/citation.R, the release citation, or the index build's citation gate."
---

# Attribution is a contract, checked like links

Every dataset in a release carries a citation that was **checked**, a license from a
**registry**, a **measured** `source_accessed`, and the release **cites itself**. Until
2026-09-03 none of that held: 8 of 16 `citation_main` were empty, 13 licenses were empty and
3 were the free text `"CC BY 4.0"`, `_ingested_at` was stripped at freeze so nothing recorded
when a source was read, and the integrated database had no citation of its own. The pieces
live in `calcofi4db/R/citation.R` (≥ 3.30.0) and are enforced twice: in
`scripts/build_workflows_index.R` (beside the link checks) and in `release_database.qmd`'s
`dataset_coverage` chunk.

## The rule for authors

A `dataset_meta` value is written **only with evidence** — a `# source: <url>, checked
<date>` YAML comment on the line. Where the source states nothing, the field stays empty and a
`questions.csv` row is filed (`status = proposed` with the value we intend, `related_table =
dataset`, `related_field` = the key, `who` = the PI). **Never invent a license.** `license` is
an SPDX-style id from `metadata/license.csv`; `custom` points `license_url` at the provider's
own terms (an EDI `intellectualRights`, a portal's Data Use Policy, an ERDDAP `.das` `license`
global, a data-sharing agreement); `acknowledgement` takes credit prose a source requires
(it used to be misfiled in `citation_others`, which is a **list of additional citations**);
`doi` is bare (`10.6073/pasta/…`, never `https://doi.org/…`); `contact` is a provider-chosen
URL or `mailto:`. **Do not** add `coverage_*` or `source_accessed` — both are measured.

EDI is not uniformly CC-BY (measured by WS-A1): phytoplankton is CC0-1.0, phyllosoma and
euphausiids carry bespoke non-commercial text (`custom`). Read the EML `intellectualRights`
(via DataONE's mirror — `https://cn.dataone.org/cn/v2/object/https%3A%2F%2Fpasta.lternet.edu%2Fpackage%2Fmetadata%2Feml%2F<scope>%2F<id>%2F<rev>` —
because portal.edirepository.org and pasta.lternet.edu answer 403 / a Cloudflare check to
automated fetches).

## `check_dataset_citation(ingest_yaml, network, cache_dir)` — one row per (dataset, finding)

Columns: `dataset_key, finding, detail, authority, authority_citation, checked, level, exempt,
question, field`. A clean dataset has a single `ok` row; a dataset with two problems has two
rows — never a summary.

| finding | level | means |
|---|---|---|
| `missing_citation` | error | `citation_main` empty |
| `no_year` | error | no 4-digit year in the string |
| `no_locator` | error | no DOI, no URL in the string, and `link_data_source` empty |
| `missing_license` | error | `license` empty **or** the literal `unknown` (`detail` says which) |
| `license_unregistered` | error | not an *active* id in `metadata/license.csv` (`"CC BY 4.0"`, a deprecated row) |
| `license_custom_no_url` | error | `custom` without an `http(s)` `license_url` |
| `doi_unresolved` | error | not a bare DOI, or `HEAD https://doi.org/<doi>` answered something other than 200/30x (redirects deliberately not followed: the DOI's own answer, not the landing page's) |
| `authority_drift` | warn | the fetched citation differs after `normalize_citation()` (lower-case, markup/entities stripped, then only `[a-z0-9]` kept — a trailing period or an upper-cased DOI is not drift; abbreviated author names are), or the DataCite SPDX license differs from the declared one. `detail` carries both strings |
| `authority_unavailable` | warn | a resolver applies but did not answer 200 (5xx, timeout, DNS); nothing cached, retried next run |

**Exemption.** An error is `exempt` while the dataset's `questions.csv` holds an `open` or
`proposed` row with `related_table = dataset` whose `related_field` is empty (covers every
finding) or names the finding's field (`citation_main`, `license`, `doi`). `question` carries
the label(s). `assert_dataset_citation(d)` stops on any non-exempt error, messages the
warnings and the exemptions, and is the one formatter both the index and the release call.

**Resolvers, by `link_data_source` (else by `doi`):**
- **EDI** — `packageid=<scope>.<id>.<rev>` → `https://cite.edirepository.org/cite/<scope>.<id>.<rev>?style=ESIP`
  (the ESIP string, verbatim). `scope=…&identifier=…` (no rev) → the newest revision found by
  asking the cite service for rev 1, 2, … until it stops answering 200 — PASTA's
  `listDataPackageRevisions` / search answer **403 to public access** (measured 2026-09-03), so
  the brief's `/package/eml/<scope>/<id>` route does not work from here.
- **NCEI** — the landing page's "Cite as:" block, minus `[indicate subset used]` and
  `Accessed [date]`; its DOI.
- **ERDDAP** — `<base>.das` `NC_GLOBAL` strings: `title`, `institution`, `creator_name`,
  `publisher_name`, `license` (free text, scheme `text`, never compared), and `citation` only
  when the dataset declares that global (neither Farallon nor CUFES does → `citation` NA).
- **DataCite** — for any DOI (declared or the authority's own): `api.datacite.org/dois/<doi>`
  `rightsList[].rightsIdentifier` (SPDX, upper-cased to the registry form; EDI DOIs carry none)
  plus, when the DOI is the primary authority, doi.org content negotiation
  (`Accept: text/x-bibliography; style=apa`, following the redirect to data.crosscite.org).
- No resolver for calcofi.org pages, DataZoo, zoodb/zooscan, a private collection export or
  the UCSD Library search placeholder — those stay structural-only (`authority` NA).

**Cache.** `metadata/{provider}/{dataset}/citation_authority.json`: `authority, url,
citation, license, license_scheme, creator, title, checked, doi, doi_status`. Written only on
success; read on every run (also when `network = FALSE`, so drift still reports); `refresh =
TRUE` refetches. **Nothing is ever written into a notebook's YAML** — the authority is a
proposal, the author's string is the record. Tracked in git like `taxon_lineage.csv`.

**Tests** (`calcofi4db/tests/testthat/test-citation.R`): one fixture per finding; the parsers
(`parse_edi_cite`, `parse_erddap_das`, `parse_ncei_landing`, `parse_datacite`,
`parse_doi_bibliography`) on saved responses under `fixtures/citation/`; the whole network
path driven by an injected `fetch` that serves those files; `release_citation()` byte-pinned;
`source_accessed_from_git()` on a temp repo. No test touches the network.

## `source_accessed` is measured

`resolve_source_accessed(dirs)` per dataset: the ingest's own `stamp_source_access(files,
urls)` record — `download` (the date the bytes came down) or `file_mtime` (Drive-archived
files) — written by `build_metadata_json(sources = )` as `metadata.json` `sources[]`, newest
stamp wins; else `source_accessed_from_git()` = the last commit of
`data/parquet/{p}_{d}/manifest.json` (`sidecar_commit`), the file every ingest rewrites when it
runs. Both land on `dataset` as `source_accessed` (DATE) + `source_accessed_method`.
Measured 2026-09-03: 15 datasets → 2026-08-25 (commit 3ee7479, the v2026.08.25 run), the crab →
2026-09-03 (its re-run). That is "when the ingest last ran", the honest bound until ingests
call `stamp_source_access()` at their download step — the next ingest to touch its Acquire
chunk should.

## The release cites itself

`release_citation(version, date, doi, all_versions)`: *CalCOFI (YYYY). CalCOFI Integrated
Database, release vYYYY.MM.DD [Data set]. Scripps Institution of Oceanography, NOAA Fisheries,
and California Department of Fish and Wildlife. https://doi.org/<doi>* — the db-schema URL
(`https://calcofi.io/db-schema/?v=<version>`) until the DOI exists; the concept-DOI form
(`10.5281/zenodo.22281994`, no release in the title) for "all versions".
- `catalog.json`: `add_release_citation(catalog)` at the catalog write → `citation` +
  `concept_doi`; `doi` once minted.
- `RELEASE_NOTES.md`: every appendix has **How to cite** — the release line, then
  `- \`dataset_key\` — citation_main · license (license_url)` per dataset, *citation pending*
  where empty (the gap is the finding; hiding it here would hide it from the reader).
- **Zenodo.** Ben enabled the GitHub integration (tag `v2026.09.03-alpha` → version DOI
  `10.5281/zenodo.22281995`, concept `10.5281/zenodo.22281994`). Without `.zenodo.json` the
  record was "CalCOFI/workflows: initial Zenodo release", MIT, creators = GitHub contributors.
  `scripts/build_citation_files.R` (`write_citation_files()`) generates `.zenodo.json` (a
  *dataset* record: the three partners as creators, every dataset's PIs from `pi_names` as
  `DataCollector`, Ben/Betty as `DataCurator`, `cc-by-4.0` with the description saying the code
  stays MIT, `isSupplementTo` the GCS release, `isDocumentedBy` db-schema; `version` omitted so
  the tag fills it — measured) and `CITATION.cff` (concept DOI). Re-run it when `pi_names`
  change, and with `<version> <date>` immediately before WS-F tags a release. ROR ids are not
  in Zenodo's legacy `.zenodo.json` creator schema, so none are written.
- **The DOI arrives after the tag.** `publish_release_notes()` (also `test_release.qmd` and
  `scripts/publish_release_notes.R`) calls `zenodo_doi_for_tag(version)` — the record whose
  `related_identifiers` carries `https://github.com/CalCOFI/workflows/tree/<tag>` (query
  URL-encoded; the bare quoted query answers 400), else the concept's `all_versions=true`
  listing matched on `metadata.version` — and, the first time it answers, writes `doi` +
  `citation` into the local and published `catalog.json`, rebuilds `versions.json`
  (`build_versions_json()` carries `doi`; it takes `consolidated` from
  `metadata/release_policy.yml`, so a rebuild cannot drop the flags), and cites the DOI in the
  notes. Objects are untouched. The tag + GitHub release are WS-F's step.

## What "entering the contract" cost, so the next dataset knows

- WS-A1 filled 16 notebooks from evidence and filed 14 `proposed` rows; the check then found
  one gap A1 had not: `calcofi_mets`'s citation has no year and calcofi.org states no
  publication date (Q31, access-year form proposed). Two drift warnings are real: dic
  abbreviates the NCEI author names, mesopelagic-fish differs from DataCite's APA form in
  initials and `[Dataset]`; adopting the authority strings is the author's call.
- `CALCOFI4DB_DIR=<checkout>` makes `build_workflows_index.R` and
  `build_citation_files.R` `load_all()` a development checkout instead of the installed
  package — the index needs 3.30.0.
