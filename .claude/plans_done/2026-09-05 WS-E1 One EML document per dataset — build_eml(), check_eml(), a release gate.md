# WS-E1 · One EML document per dataset — `build_eml()`, `check_eml()`, a release gate

**Agent:** Opus 5 · medium. **Wave 2**, `calcofi4db` + `workflows` worktrees. **Needs:** R0 (the record),
R2 (the sidecar fields). **Integrator order:** after R0; this is **calcofi4db 4.2.0**. **Plan:** `.claude/plans/2026-09-05 CalCOFI.io as a dataset catalog — one record per dataset with every endpoint, the front door re-cut around Datasets, and the portal registrations.md` § D-8,
Decision 13.

## Goal

`eml/{dataset_key}.xml` in every release, valid EML 2.2, built from the record + the sidecar, so the DwC-A
(E2), the EDI package (E3), ERDDAP's globals and the JSON-LD derive from one document.

## Read first

- `workflows/publish_ichthyo_to-obis.qmd` § *Create EML Metadata* (the `EML` package usage, `write_eml()`,
  `eml_validate()`, the ulink licence trick) — the worked example to generalise.
- The field-by-field mapping in the plan § D-8 (title, abstract, creator/contact/metadataProvider, pubDate,
  keywordSet, intellectualRights, coverage geographic/temporal/taxonomic, methods/sampling, project/funding,
  dataTable[] with attributeList, alternateIdentifier, additionalMetadata).
- `metadata/gear.csv` (`dwc_samplingProtocol`), `metadata/license.csv`, `releases/{v}/metadata.json`
  `columns{}` (units, descriptions for `attributeList`), `coverage.json` `taxa[]`.
- EDI's EML best practices (`ediorg.github.io/data-package-best-practices`) for what EDI's evaluate checks.

## Do

1. `R/eml.R`: `build_eml(record, sidecar, meta, coverage, release)` → an `EML::eml` list + `write_eml()`;
   `check_eml(path)` = `eml_validate()` + the EDI-required elements present (title, abstract ≥ 20 words,
   creator with organization, contact with email, pubDate, intellectualRights, geographic + temporal coverage,
   ≥ 1 dataTable with attributes when the dataset has tables). Absent optional fields are omitted, never
   filled with placeholders; a missing required field is a finding.
2. `release_database.qmd`: write `eml/{key}.xml` for every dataset after `datasets.json`; `check_eml()`
   errors fail the release; `sidecar_urls` lists the folder; `RELEASE_REQUIRED_OBJECTS` gains `eml/`.
3. `publish_to-erddap.qmd`: `title`, `summary`, `creator_*`, `license`, `keywords`, `infoUrl` (the
   dataset page URL) rendered from the same record fields (a small helper `erddap_globals(record)`).
4. Tests: fixture record + sidecar → EML validates; each required-element finding has a red test; the
   ichthyo fixture reproduces the elements the old notebook wrote (title, abstract, methods, coverage).
5. `NEWS.md` 4.2.0; `RELEASES.md # Unreleased`.

## Gates

`devtools::test()` green; a staging render writes 16 valid EML files; `eml_validate()` passes on all.

## Do not

Type any metadata string into R code (every string comes from the record or a registry); render in the
calcofi4db worktree (integrator renders); build the DwC-A or the EDI package (E2, E3).

## Hand back

The `swfsc_ichthyo` EML (path), the required-element table for the 16, `NEWS.md` text, one *Measured* line.
