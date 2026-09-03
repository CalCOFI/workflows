# WS-F · Release run — changed ingests, the ichthyo reference-shard gate, caboose with `shortcut`, staging, promote, deploy, Explorer prefix flip

**Agent:** Sonnet · high as operator; Ben on call. **Wave 4** — starts only when: E-Ph1–3, A0, A1, B-impl,
C, DG are merged; `devtools::test()` green in calcofi4db / calcofi4r / calcofi4py; every WS has its
`# Unreleased` entry; the packages are reinstalled (`remotes::install_github()` or `install()` from the
sibling repos). Laptop unless Q9 says server.
**Rule:** on any red gate, **stop and report** — never "fix and continue". Load the `release-objects`
and `deploy-consumers` skills first; CLAUDE.md § Commands (targets traps: `tar_invalidate()` before a
`.qmd` edit counts; `eval(bquote(...))` in scripts; never a loop variable named `t`).

## 1 · Changed ingests only

```r
changed <- c("ingest_swfsc_ichthyo", "ingest_farallon_bird_mammal", "ingest_calcofi_phytoplankton",
             "ingest_cce_lter_zoodb", "ingest_cce_lter_zooscan", "ingest_cce_lter_euphausiids",
             "ingest_sio_mesopelagic_fish", "ingest_swfsc_cufes", "ingest_calcofi_phyllosoma",
             "ingest_cdfw_dungeness_crab")        # the taxon ten (+ crab is in it) — confirm against WS-E/C
known <- targets::tar_meta()$name
for (tgt in intersect(changed, known))
  eval(bquote(targets::tar_invalidate(names = tidyselect::all_of(.(tgt)))))
eval(bquote(targets::tar_make(names = tidyselect::all_of(.(changed)))))   # ichthyo first by dependency
```

Confirm each `_output/ingest_*.html` mtime moved and `data/parquet/*/manifest.json` changed for each.
Expected ≈ 12 min.

## 2 · The gate that makes skipping CTD honest

Compare the content hashes of ichthyo's **`cruise`, `grid`, `ship`** tables in
`data/parquet/swfsc_ichthyo/manifest.json` (the per-table `data_hash` / file hashes) with the previous
committed manifest (`git show HEAD:data/parquet/swfsc_ichthyo/manifest.json`). **Identical ⇒ proceed**
(every skipped dependent — ctd-cast 128 min, bottle, dic, mets, pico, pic-zooplankton — would re-produce
its shards byte-for-byte). **Different ⇒ stop**: report which table and why; the dependents must run.

## 3 · Staging release

```sh
CALCOFI_RELEASE_PREFIX=ducklake-staging/releases CALCOFI_RELEASE_LAYOUT=canonical \
  Rscript -e 'eval(bquote(targets::tar_make(names = tidyselect::all_of(c("release_database","test_release")), shortcut = TRUE)))'
```

Gates on the staging output: `obs_bio`/`obs_env` are core with `sample_key`/`measurement_prec`/`hex_id`,
`obs` is `deprecated` and the catalog has `views.obs` (H1); `promote_unreleased()` is skipped under staging but the `# Unreleased`
section must be non-empty; **`dataset.parquet` carries the new citation/license/doi/source_accessed
columns for `calcofi_ctd-cast` and `calcofi_bottle` although their ingests did not run** (A0 reads
YAML); `check_dataset_citation()` zero errors; `check_cruise_key_integrity()` zero rows;
`check_taxon_ids()` passes; the taxon parity fixture (E-Ph0) matches except the approved name changes;
`n_flags_pending` = 0; `test_release` contract suite passes; `spatial_layers.json`, `coverage.json`
present. Diff the staging `catalog.json` table list against v2026.08.25: only the intended additions.

## 4 · Real release

Unset the staging vars; `tar_make(names = all_of(c("release_database","test_release",
"publish_to_netcdf","publish_to_erddap","deploy_consumers")), shortcut = TRUE)` (≈ 62 min). Then
`Rscript scripts/publish_release_notes.R <version>`, `scripts/verify_release_objects.R <version>`,
`scripts/build_release_redirects.R` + Caddy reload, `build_versions_json` sanity.

## 4b · Tag, GitHub release, DOI

After `test_release` promotes `latest.txt`: commit the run's tracked outputs, then
`git tag -a v<version> -m "database release v<version>"`, `git push --tags`, and
`gh release create v<version> --title "CalCOFI Integrated Database v<version>" --notes-file
data/releases/v<version>/RELEASE_NOTES.md data/releases/v<version>/catalog.json
data/releases/v<version>/metadata.json RELEASES.md`. Zenodo (enabled on the repo by Ben, once) archives
the tag; wait for the record (`calcofi4db::zenodo_doi_for_tag()` polls, ≤ 10 min), then
`Rscript scripts/publish_release_notes.R <version>` writes the DOI into the notes, `versions.json` and
the catalog. If Zenodo has not minted within the wait, stop and report — the release is still valid,
the DOI is added by re-running the script later.

## 5 · Consumers

- Explorer: flip `VITE_RELEASE_PREFIX` from `explore-dev/releases` to `ducklake/releases` in
  `explore/.github/workflows/pages.yml`, deploy, run `scripts/verify.mjs` on the live URL; screenshots.
- calcofi4r 1.17.0 / calcofi4py 0.6.0 tags (A2); db-schema default version gate (after promotion);
  `deploy-consumers` skill for the Shiny apps; `docs` re-render (A4's cite page reads the new release).

## 6 · Afterwards

targets still lists the skipped ingests as outdated — record that in the umbrella's *Measured* with the
wall time per step, and note for the server plan: split ichthyo's reference shards into their own target.
