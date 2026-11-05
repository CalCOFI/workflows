---
name: preview-release
description: "The private-preview pathway for a held dataset — staged (in_release: false, parquet to the private bucket), a candidate release per dataset into gs://calcofi-preview (scripts/preview_candidate.sh), the preview build and link (scripts/build_preview.sh), the provider's decision in the form → consent/ record → the consent question in questions.csv and the provider's Sheet (scripts/pull_preview_consent.R) → check_dataset_consent() gating the public release → un-hold. Load before staging a provider's new dataset, running or debugging a candidate, building a preview, or changing anything about consent."
---

# From a staged ingest to the public database, by way of a private preview

The chapter is [Providing data](../../../../docs/provide.qmd) (calcofi.io/docs/provide.html,
"What happens next" and its figure); this skill holds the mechanics and the incidents.

## The pathway, one stage per gate

| stage | where it lives | the gate that holds the line |
|---|---|---|
| 1. **Staged** — the ingest PR renders with `in_release: false` | `ingest_{provider}_{dataset}.qmd`; sidecars in `data/parquet/{key}/`; parquet under the stage dir | `gcs_bucket_for_dataset()`: a held key's upload goes to `CALCOFI_PREVIEW_BUCKET` (`calcofi-preview`) or nowhere, never `calcofi-db` / `calcofi-files-public`; `release_excluded_datasets()` keeps it out of every public release step |
| 2. **Consent question** — the standing row `related_field = consent` in `metadata/{provider}/{dataset}/questions.csv` | written at staging (copy `sccoos/ifcb-ctd` Q17) | `scripts/build_preview.sh` refuses to build without it; `check_dataset_consent()` later reads it |
| 3. **Candidate release** — `release_database.qmd` once per dataset into the private bucket | `scripts/preview_candidate.sh <provider> <dataset> [short]`: `CALCOFI_RELEASE_BUCKET=calcofi-preview`, prefixes `ducklake-preview-<short>/{releases,tables}`, `CALCOFI_RELEASE_INCLUDE=<key>`, own `CALCOFI_STAGE_DIR` (parquet symlinked, `releases-staging/` its own) | the notebook refuses `CALCOFI_RELEASE_INCLUDE` into a public bucket; every public gate runs, held datasets ratcheted apart (`key_null_max[key]`, `DEPTH_SEAFLOOR_OVER_HELD[key]`); `latest.txt` of the root written by the script after a pass (`test_release.qmd` does not run on a candidate) |
| 4. **Preview** — calcofi.io + Explorer + Finder + the notebook, built against the candidate, served at `https://preview.calcofi.io/<key>/<token>/` | `PREVIEW_ACCESS=link PREVIEW_RELEASE_ROOT=ducklake-preview-<short> scripts/build_preview.sh <provider> <dataset> _output/ingest_<key>.html`; service in `preview/` (Cloud Run, 0.5.x) | each build is its own storage prefix; a build's data route serves only its own root; feedback stays in the bucket and in the private repo CalCOFI/feedback_private (`scripts/preview_feedback_issues.py`) |
| 5. **Decision** — the landing page's form (yes / not yet, name, email, citation and licence boxes pre-filled from the record) | `consent/{key}/{utc}_{email}.json`, written once, never overwritten | `scripts/pull_preview_consent.R --execute --push-sheets --commit` (timer on the mini) folds the newest decision into the consent row: `yes` → `answered`, the answer, `who`, `answered_date`; `not_yet` → a dated line in `context`; the row is pushed to the provider's Sheet tab and committed |
| 6. **Un-hold** — flip `in_release: false` → `true` in the notebook, promote the ratchet baselines into the public ones, re-render, next public release | the ingest PR | `check_dataset_consent(halt = TRUE)` in `release_database.qmd`: a dataset in a public run whose consent row is not `answered` + `yes` + `who` stops the release; a preview run exempts the datasets it includes |
| 7. **Retire the preview** — delete `datasets/<key>-<token>/` and the candidate root from the bucket; the consent record stays | by hand (`gcloud storage rm`) | — |

## Mechanics and traps (each cost hours)

- **Candidates run only from a checkout `origin/main` contains, after every sibling held
  dataset is merged.** `core_shard_paths()` lists every directory of the shared stage dir and
  excludes only the datasets this checkout knows as `in_release: false`; a checkout missing a
  sibling's notebook counts that sibling's shard into the union (`core_parity` then fails, or
  worse, passes with the sibling's rows in the candidate). `preview_candidate.sh` checks this.
- **The version is the date.** Two candidates on one day share `v<date>`; separate roots keep them
  apart in the bucket, the per-run `CALCOFI_STAGE_DIR` keeps `releases-staging/<version>` apart
  on disk. A failed attempt leaves `releases/v…/` in its root; delete it before the rerun.
- **Ratchets are per dataset for a held dataset.** `key_null_max` (NULL `cruise_key`, e.g. Process
  cruises that are not CalCOFI cruises) and `DEPTH_SEAFLOOR_OVER_HELD` (samples below the GEBCO
  seafloor) each take the count measured on the shard before the run; a missing entry is 0 and
  fails. Measure first (`check_depth_vs_seafloor()` on the shard alone; `cc_grid` membership;
  NULL counts), record with the question that explains it, never raise a public ratchet.
- **`assert_dataset_catalog()` probes the public bucket's URLs** — gated on `release_bucket ==
  "calcofi-db"`; `since_version` reads `calcofi-db`'s history. `# Unreleased` in RELEASES.md must
  be non-empty even for a preview.
- **Grid keys**: a shard rendered on another machine may carry the previous grid's keys
  (IFCB, 2026-11-03: ten retired keys failed the FK check). Render on the release machine with
  the installed `calcofi4r::cc_grid`.
- **Runtime**: about 4.5 h per candidate on the mini (IFCB, 2026-11-03); two at a time with
  `CALCOFI_DUCKDB_MEMORY_LIMIT=20GB` / 5 threads fit in 48 GB. Detach in tmux with stdin from
  `/dev/null` and a `.done` marker.
- **The preview build**: ship the notebook's `_files/` (unstyled otherwise); screenshots need
  ~30 s to settle and never `--disable-gpu` (WebGL blank); the Finder's DuckDB http secret is
  SCOPEd to the bucket (an unscoped token reached GitHub); the site's asset rewrite skips the
  URL base (`#37–#39`); DuckDB-WASM needs HEAD + Range on the data route (0.5.1).
- **Access modes**: `link` (default since 2026-11-03, token in the URL, Caddy vhost
  `preview.calcofi.io` → Cloud Run) or `iap` (Google sign-in, `access.csv`); README "Switching the
  mode". The calcofi-admin SA cannot deploy the service: Ben deploys from Cloud Shell.
- **Nothing of a held dataset reaches a public surface**: not the parquet, not the candidate, not
  the preview's screenshots or feedback, not a public GitHub issue. The notebook's render is not
  committed for a dataset whose provider has not released the data (sightings); a public-source
  dataset's render may be (Betty's PRs).

## History

- 2026-11-02/03 — sightings preview (plan `2026-11-02_private-preview-cetacean-sightings.md`): four
  gate fixes, IAP → link mode, branded host, landing page, Finder, private feedback (0.3 → 0.5.1).
- 2026-11-03/04 — IFCB candidate and preview from its own root; Betty's six EDI/ERDDAP datasets
  rendered by one agent each; `DEPTH_SEAFLOOR_OVER_HELD` (#236); `check_dataset_consent()`,
  `pull_preview_consent.R`, `preview_candidate.sh` written so the pathway is one loop and the
  consent reaches the Sheet, git and the release gate.
