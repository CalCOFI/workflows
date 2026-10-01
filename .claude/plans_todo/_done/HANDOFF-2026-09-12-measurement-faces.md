# Handoff — measurement faces, unbuilt as of 2026-09-12

The plan `.claude/plans/2026-09-11 Measurement faces …` and its seven briefs (`WS-MF1.md` … `WS-MF7.md`)
were written and committed on 2026-09-11 (`2b7b947`, refined in `ffd8794`) and **never dispatched**: the
session that filed them was pulled into the quality-flag correction (Rasmus's sensor-pair rule) and the
v2026.09.11 release, and stopped there. Nothing of D1–D10 is built. `https://calcofi.io/measurements/nitrate/`
carries the catalog v1 header, the NERC ids, the five stats and the flagged heads-up — no WHAT, no HOW,
no WHY, no structure, no EOV.

Verified unbuilt 2026-09-12: no `metadata/measurement_{chem,how,why,eov,scale,face}.csv`; no `ws-mf*` branch
in any repo; landing PRs #19–#23 are the catalog, the category fallback and the flag heads-up only.

## State the new session inherits

| | |
|---|---|
| promoted release | **v2026.09.11** (DOI 10.5281/zenodo.22714951); `measurements.json` **schema 1.0**, 89 measurements / 94 series / 5 datasets |
| workflows `main` | `ffd8794` — **1 commit unpushed** (the plan patch); Ben pushes this repo |
| calcofi4db | **4.14.0**, `9a2487fd` — **2 commits unpushed** (`9c0a711a`, `9a2487fd`), Ben's to push; branch from them |
| landing `main` | `6904faa`, pushed, Pages green |
| landing merged this week | #21 category fallback · #22 flagged count (`n_values − qual_ok_n`, matches the Explorer) · #23 "screened means" wording — **MF5 must build on these, not revert them** |
| species faces | **live**, and their fetcher `scripts/fetch_species_media.py` is the worked example MF4 mirrors |
| media layout | **version-free**: `species-media/taxa/{slug}/…` + one `species-media/taxa_media.json`. `measurement-media/` follows it: `measurement-media/keys/{key}/structure.svg` + one `measurement-media/measurements_media.json`, the sidecar's `release` field the only version in the layout. Keying media by `{release}` blanked every species page on 2026-09-11 — do not reintroduce it (landing `6904faa`). |
| probe assets | `.claude/plans/2026-09-11 measurement-faces-probe/` — `README.md` first; `nvs_probe.json`, `chebi.json`, `mol/`, `svg/`, `draw2.py`, `build.py`, `template.html`, `data.json`, `anom_bands.{sql,csv}`, `eov/`, `oni.txt`, `measurement_faces.mockup.html` |
| mockup | https://claude.ai/code/artifact/aefb4449-c780-4da9-8216-3cbe91530e03 |

## Deltas against the plan's own kickoff prompt (§ Kickoff, line ~264)

1. The bridge record is built from **v2026.09.11**, not v2026.09.10 (the plan predates the release).
2. The findings pass (F8) **is** merged on `main` in workflows; worktrees branch from `ffd8794` (and from
   calcofi4db `9a2487fd`, unpushed — pull locally, do not re-derive).
3. MF4's storage target is the version-free layout above, not `measurement-media/{release}/`.
4. MF3 adds `n_flagged` to the record; the landing page already computes it in `_plugins/measurements.rb`
   (#22). Reconcile — the record becomes the source, the plugin's arithmetic the fallback — do not ship both
   with different numbers.
5. D9 (picoplankton ↔ species catalog, MF7) still needs Ben's yes before it merges. Ask once, early.

## Also open, lower priority

- `species-media.yml` is `if: false` — the repo has no `GCP_SA_KEY`, so new taxa get no face until the
  fetcher is run by hand. Enabling it needs the calcofi-admin key as a repo secret.
- netCDF downloads are two releases behind: `netcdf/{dataset}/latest.txt` = `v2026.09.06`, and the
  v2026.09.11 record's 17 links point there (all 200, nothing broken). The publishers' v2026.09.11 netCDF
  run is not on the public bucket — find out whether it uploaded elsewhere or never ran.
- `species-media/v2026.09.10/` is a redundant 5,239-object / 161 MB copy, verified byte-size identical to
  `species-media/taxa/`. Delete it once Ben says so.
- Pre-existing red CI, unrelated: docs `render_book` (404 on the spo.nmfs.noaa.gov Matarese URL) and
  ctd-transects `test_missing_climatology_is_computed_inline`.
