# WS-MF3 — measurements.json 1.1: the anomaly in every band, the registries carried, the climatology to the bottom (D6, D8)

**Umbrella:** `.claude/plans/2026-09-11 Measurement faces — what it is, how it is taken and why it matters on every measurement page, agent-scaled.md` § D6, D8, Appendix A, § Verification MF3. **Spec:** the artifact https://claude.ai/code/artifact/aefb4449-c780-4da9-8216-3cbe91530e03 — *The record's own history* (small multiples, one shared scale, one-cruise years faded and clipped). **Agent:** `ws-opus-medium`. **Repos:** calcofi4db (`~/Github/CalCOFI/.worktrees/calcofi4db-ws-mf3`, branch `ws-mf3`) and workflows (`~/Github/CalCOFI/.worktrees/workflows-ws-mf3`, branch `ws-mf3`). **Wave 1 · ≈ 1 day.**

## Read first
- The umbrella's D6, D8, F6, F7 and Appendix A (the 1.1 record shape). The `release-run` and `release-objects` skills (what the release writes, the `gcs_prefix = NA` rule).
- `calcofi4db/R/catalog_measurements.R` (`build_measurements_catalog()`), `R/climatology.R` (`build_climatology()`, `depth_max_m = 500L`), `inst/schema/measurements.schema.json`, their tests.
- `.claude/plans/2026-09-11 measurement-faces-probe/` `anom_bands.sql` and `anom_bands.csv` (the per-band series you must reproduce exactly for temperature, salinity, oxygen_umol_kg, nitrate, chlorophyll_a), `band_n.csv`.
- MF1's registry headers (Appendix A) — build against fixture CSVs in `tests/testthat/fixtures/` if MF1 has not landed.

## You own
`R/catalog_measurements.R`, `R/climatology.R`, `inst/schema/measurements.schema.json` (→ 1.1, additive), their tests; in workflows the `build_measurements_catalog()` call in `release_database.qmd` (passing the five registries) and one `RELEASES.md` `# Unreleased` bullet each for schema 1.1 and the deeper climatology. Not `DESCRIPTION`/`NEWS.md`.

## Do
1. **Anomaly per band** — for every key whose record carries `climatology: true`: per band of the record's `depth_bands` edges with values and a climatology match, the yearly series `[year, anom, n_cruises, n_values]` (mean per cruise, then per year; `qual_ok`; join on dataset_key, measurement_type, site_key, month, depth_bin), the 1984–2021 trend over years with `n_cruises ≥ 2` (slope per decade + intercept), extremes over those years, `ymax` shared across the key's bands from those years, `spark_band` = the band with the most values, `deeper[]` = bands with values and no climatology. A unified key merges its series' rows before aggregating (say so in the roxygen).
2. **Registries carried** — `face`, `chem`, `method` (per series), `scale` (computed marks recomputed here with their `how`, never read as numbers), `why` (ranked) per key, from the five `read_measurement_*()` helpers; absent registries leave the fields out (1.0 consumers unaffected).
3. **Observed inside `qual_ok`** — `observed{}` (min, p05, p50, p95, max) is computed over values that are in bounds AND `qual_ok`, the range a careful reader would use (CLAUDE.md: a provider flag outranks a bound; `measurement-bounds` skill); add `n_flagged` (`n_values − qual_ok_n`) per series and per key so the page's heads-up reads it from the record instead of computing it. A fixture test holds a flagged extreme and asserts it is outside `observed{}` and counted in `n_flagged`.
4. **Schema 1.1** — additive; the test validates a record built from a fixture release and a record without the new fields.
4. **Climatology to the bottom** — `depth_max_m` defaults to the deepest bin that passes the existing ≥ 3-cruise rule; measure the table's rows and bytes before and after on v2026.09.10, and run the Explorer's post-release smoke (`explore/scripts/smoke_release.mjs`) against a staged table to show the section lenses unchanged. If any lens changes, keep 500 as the release's argument and report.
5. **Reproduce the probe** — the five variables' per-band series equal `anom_bands.csv` (to 4 decimals); a test holds a two-band, one-cruise-year fixture.

## Gates (stop and report)
- A per-band series that does not reproduce the probe: find which side is wrong before changing either.
- The deeper climatology breaks a consumer: stop at 500 and report the diff.
- `devtools::test()` red.

## Hand back
Branches + SHAs; the climatology before/after numbers; one 1.1 key from v2026.09.10 (oxygen_umol_kg); tests run; one *Measured* line.
