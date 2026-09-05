# WS-E2 · Generic `publish_to-obis.qmd` over the core — `R/dwc.R`, the ichthyo diff gate, retire the old notebook

**Agent:** Opus 5 · high. **Wave 3**, `calcofi4db` + `workflows` worktrees. **Needs:** E1 (the EML).
**Integrator order:** after M1; this is **calcofi4db 4.4.0**. **Plan:** `.claude/plans/2026-09-05 CalCOFI.io as a dataset catalog — one record per dataset with every endpoint, the front door re-cut around Datasets, and the portal registrations.md` § D-8 (the mapping table and the
`occurrenceStatus` rule), Decisions 10, 13; origin note `plans_todo/2026-09-03 Follow-on — generic
publish_to-obis over the core.md`.

## Goal

One Darwin Core Archive per biological dataset from the core, with the release's EML, validated, with a
manifest that says whether the published OBIS copy is current — and the ichthyo archive regenerated
identically before the old notebook goes.

## Read first

- `publish_ichthyo_to-obis.qmd` end to end (event hierarchy, eMoF sub-tables, `meta.xml` term maps, the zip);
  `publish_obis_template.qmd`; `publish_to-netcdf.qmd` / `publish_to-erddap.qmd` (the generic pattern:
  `dataset_key` loop, plan table up front, every output validated before written).
- The mapping table in the plan § D-8; `docs/db.qmd` § *Darwin Core / OBIS ENV-DATA mapping* (live);
  `metadata/{gear,life_stage,field_dictionary,measurement_type}.csv` (the ids: `dwc_samplingProtocol`,
  `nerc_l22`, `dwc_lifeStage`, `nerc_s11`, `dwc_term`, `nerc_p01`, `units_nerc_p06`).
- `obistools` (`check_eventids`, `check_extension_eventids`, `check_fields`, `check_eventdate`,
  `match_taxa`); the OBIS manual (`manual.obis.org`) on ENV-DATA and `occurrenceStatus`.
- CLAUDE.md § "obs_bio + obs_env are the observation store"; the D8 denominator (`density_per_10m2`,
  `density_per_1000m3`, `effort_class`).

## Do

1. `R/dwc.R`: `dwc_event(con, dataset_key)` (from `sample`: `eventID = sample_key`, `parentEventID`,
   `eventDate`, coordinates, depths, `sampleSizeValue/Unit` from the effort denominator, `samplingProtocol`
   from `gear.csv`, `locationID = site_key`), `dwc_occurrence(con, dataset_key)` (from `obs_bio`:
   `scientificNameID` WoRMS LSID via `taxon_key`, `lifeStage`, `organismQuantity/Type`,
   `occurrenceStatus`), `dwc_emof(con, dataset_key)` (`sample_measurement`, `obs_attribute`, the env rows on
   the same event; `measurementTypeID/UnitID` from the registries, empty when no exact concept),
   `dwc_meta_xml(term_maps)`, `dwc_archive(dir, eml_path)` → zip + `manifest.json` (`dataset_key, version,
   content_hash, ipt_resource, obis_dataset_id, uploaded_utc`).
2. **Absences honestly**: for a positive-only dataset, absent rows = `sample_root` tows sorted for the taxon
   with no positive row (the ichthyo rule); a dataset that records zeros keeps them as `absent`; document
   which rule each dataset uses in the plan table the notebook prints.
3. `publish_to-obis.qmd` (generic; `calcofi:` block; in `_targets.R`; writes files only): for each
   biological `dataset_key` in the release **whose taxa resolve to WoRMS** (Decision 21 — so not
   `cce-lter_picoplankton-bacteria`, not `sio_pic-zooplankton`), build, run the `obistools` checks (a failing dataset gets no zip
   and a finding), write `data/darwincore/{key}/{key}_{version}.zip`; the plan table up front.
4. **The ichthyo gate**: regenerate `swfsc_ichthyo` through the generic path and diff against the published
   archive (`ipt-obis.gbif.us/archive.do?r=calcofi_ichthyo`): event / occurrence / eMoF counts equal at the
   same release (77,188 / 463,655 / 610,816), the same `eventID`s, the same term set. Only then delete
   `publish_ichthyo_to-obis.qmd` (and its `_targets.R` exclude) and note the supersession in RELEASES.md.
4b. **Duplicates first.** For each candidate dataset list the OBIS records that already cover the same source —
   `api.obis.org/v3/dataset` by institution, title words and DOI, plus the OBIS-USA IPT listing and any record
   published through CCE-LTER/EDI — as a table (`dataset_key, obis_id, title, owner, records, published`) for Ben
   and the provider to resolve *before* an upload: a provider's own record is never duplicated; a historical
   CalCOFI record is retired or cross-referenced with its owner's agreement.
5. `registrations[]` (R0's record) reads the manifests: `published (vX)` / `stale — data changed in vY`.
6. Tests: fixture core → the three tables' shapes and the absence rule; `meta.xml` term coverage; no network.
   `NEWS.md` 4.4.0; `RELEASES.md # Unreleased`; `docs/portals.qmd` § OBIS gains the manual IPT upload steps.

## Gates

`obistools` checks pass for every emitted dataset; the ichthyo diff is exact; `devtools::test()` green.

## Do not

Upload to the IPT (Ben does, per dataset, after providers agree — Open question 9); invent a NERC id or a
licence; emit zeros as absences for a positive-only dataset; keep two OBIS notebooks.

## Hand back

The plan table (datasets, rule, counts, checks), the ichthyo diff result, the manifests, one *Measured* line.
