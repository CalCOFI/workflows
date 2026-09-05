# WS-F · The release run that ships the catalog — staging, real, test, deploy, notes, tag, the flips

**Agent:** Sonnet · high, as the operator; **Ben on call** for auth, promotion and the IPT/EDI/registry steps.
**Wave 4**, after every wave-3 branch is merged and `devtools::test()` is green in calcofi4db, calcofi4r,
calcofi4py. **Plan:** `.claude/plans/2026-09-05 CalCOFI.io as a dataset catalog — one record per dataset with every endpoint, the front door re-cut around Datasets, and the portal registrations.md` § Phases; the `release-objects` skill; CLAUDE.md § "A staging run must be tested as a
staging run".

## Do

1. Pre-flight: `grep -n '"ducklake/releases' *.qmd` shows only env-var defaults; both staging prefixes set
   (`CALCOFI_RELEASE_PREFIX`, `CALCOFI_TABLES_PREFIX`); `# Unreleased` holds every WS entry; packages
   installed at the merged versions (calcofi4db 4.4.0, calcofi4r 1.19.0, calcofi4py 0.7.0).
2. Staging render of `release_database.qmd` → `datasets.json`, `eml/`, `stac/` present and valid;
   `test_release.qmd` on the staging prefix passes (including the new schema/URL/EML/STAC checks); the DwC-A
   and EDI notebooks render with uploads off.
3. Real run → promote → `gh_dispatch` fires (db-query, db-viz-station, ctd-transects, **CalCOFI.github.io
   refresh.yml**) → `deploy_consumers` → `publish_release_notes.R` → tag + GitHub release → the Zenodo DOI
   into the notes.
4. Verify the live catalog: `curl -sI https://calcofi.io/datasets/swfsc_ichthyo/` 200; the JSON-LD on it
   names the new version; `data.json` and the sitemap updated; `stac-browser` shows the new items;
   `check_brand.py` green.
5. Hand Ben the per-dataset upload checklist (IPT, EDI, CalOOS) with the manifests' hashes.

## Gates

`test_release` passed on staging AND real; no phantom object under the real prefix from staging; every
consumer reports the new version.

## Do not

Skip the staging run; touch `latest.txt` by hand; upload to any portal yourself.

## Hand back

The release version, the test result, the consumer versions table, the DOI, one *Measured* line.
