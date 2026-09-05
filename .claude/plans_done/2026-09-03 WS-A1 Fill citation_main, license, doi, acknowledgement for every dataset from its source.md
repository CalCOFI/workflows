# WS-A1 · Fill `citation_main`, `license`, `doi`, `acknowledgement` for every dataset from its source

**Agent:** Sonnet · high. **Wave 1** (start now against the spec; re-run `check_dataset_citation()` once A0
merges). Touches only `ingest_*.qmd` front-matter and `metadata/{p}/{d}/questions.csv`. No ingest re-runs:
`release_database.qmd` reads the YAML directly.
**Plan:** umbrella § *Context › Attribution* (the coverage table) and § *WS-A*.

## The rule

A value is written only with **evidence**: a `# source: <url>, checked 2026-09-..` YAML comment on the
line. Where the source states nothing, the field stays empty and a `questions.csv` row is filed
(`status = proposed` with the value we intend, `related_table = dataset`, `who` = the PI or contact in
the umbrella's Q1). **Never invent a license.** Normalize `"CC BY 4.0"` → `CC-BY-4.0` (SPDX ids from
`metadata/license.csv`, or the list in the A0 brief until it exists). `acknowledgement` takes the credit
prose now in `citation_others` (zoodb, zooscan); `citation_others` becomes a YAML list of additional
citations (methods papers), or is removed where empty.

## Per dataset (state at v2026.08.25 → where to look)

| dataset | citation | license | do |
|---|---|---|---|
| calcofi_phytoplankton | empty | empty | EDI cite service `knb-lter-cce.254.4?style=ESIP` (verified: "CalCOFI - Scripps Institution of Oceanography, California Current Ecosystem LTER, and E. Venrick. 2023. … ver 4. EDI. https://doi.org/10.6073/pasta/60edabfbfd85c623fce05822befaa071"); `doi` from it; EDI packages are CC-BY-4.0 unless the EML `intellectualRights` says otherwise — read the EML |
| calcofi_phyllosoma | empty | empty | EDI `knb-lter-cce.188.4` — same path |
| cce-lter_euphausiids | empty | empty | EDI `identifier=313` — resolve the newest revision, same path |
| cce-lter_zoodb, cce-lter_zooscan | empty | empty | DataZoo / zoodb portal pages for a stated citation and terms; else `proposed` row to Mark Ohman / Linsey Sala; move the NSF text to `acknowledgement` |
| cce-lter_picoplankton-bacteria | has | empty | DataZoo dataset 159 terms; else `proposed` (Landry) |
| farallon_bird-mammal | empty | empty | ERDDAP `CAC_FI_SBAS_obs.das`: `creator_name` Sarah Ann Thompson, `institution`, `title`; `license` there points at a data-sharing-agreement PDF → `license: custom`, `license_url` = that PDF; citation `proposed` to Sydeman/Thompson (Q03 in its questions.csv already asks attribution) |
| swfsc_cufes | empty | empty | ERDDAP `erdCalCOFIcufes.das`: title/institution; license text "may be used and redistributed for free…" → `custom` + `license_url` = the .das; citation `proposed` (NOAA SWFSC, Ed Weber / Noelle Bowlin) |
| sio_pic-zooplankton | empty | empty | no portal; `proposed` row to Linsey Sala (SIO PIC); `link_data_source` stays empty (CLAUDE.md rule) |
| swfsc_ichthyo | has (no year/URL) | empty | year + URL (`link_calcofi_org`) so `no_locator` clears; `license` proposed `US-PD`; `pi_names` (Ed Weber) — Q1 row |
| calcofi_bottle, calcofi_ctd-cast, calcofi_mets | has | empty | calcofi.org states no license: `proposed` `CC-BY-4.0` rows to Rasmus (one per dataset); `pi_names` proposed (Rasmus; Ben G for CTD) |
| calcofi_dic | has | CC BY 4.0 | normalize; `doi: 10.25921/3w9f-jd72` |
| sio_mesopelagic-fish | has | CC BY 4.0 | normalize; the Library object may carry a DOI — check `https://library.ucsd.edu/dc/object/bb9217084g`; the 2013 paper stays in `link_others` / `citation_others` |
| cdfw_dungeness-crab | has | CC BY 4.0 | normalize only — WS-C owns the rest |

## Do

1. Fill as above; keep each notebook's YAML valid (`yaml::read_yaml()` on the front-matter of all 16).
2. File the `questions.csv` rows with `read_questions()`-valid vocabulary (`open|proposed|answered|wontfix`;
   `blocker|high|normal|low`); `label` = next `Qnn`.
3. Run `Rscript scripts/build_workflows_index.R` (with network) — it must pass; once A0 is merged, run
   `calcofi4db::check_dataset_citation()` and paste its table into the hand-back.
4. `RELEASES.md # Unreleased`: one short paragraph under A0's heading listing which datasets gained a
   citation / license / DOI and which are `proposed` awaiting the provider.

## Do not

Change any `dataset_name` / `category` / `color`; add `coverage_*`; edit `metadata/measurement_type.csv`;
touch the taxon or emit-core sections; run any ingest.

## Hand back

The 16-row before/after table (citation · license · doi · acknowledgement · questions filed), the exact
`questions.csv` rows, and the `questions_email.qmd` render for the providers who owe an answer.
