# WS-MF1 — the measurement-face registries: chem, method, scale, face, and the helpers (D1–D4, D7)

**Umbrella:** `.claude/plans/2026-09-11 Measurement faces — what it is, how it is taken and why it matters on every measurement page, agent-scaled.md` § D1–D4, D7, Appendix A, § Verification MF1. **Spec:** the artifact https://claude.ai/code/artifact/aefb4449-c780-4da9-8216-3cbe91530e03 — *The thing itself*, *From the water to the number*, *The familiar scale*. **Agent:** `ws-sonnet-high`. **Repos:** workflows (`~/Github/CalCOFI/.worktrees/workflows-ws-mf1`, branch `ws-mf1`) and calcofi4db (`~/Github/CalCOFI/.worktrees/calcofi4db-ws-mf1`, branch `ws-mf1`). **Wave 1 · ≈ 1.5 days.**

## Read first
- The umbrella's D1–D4, D7, F1–F5 and Appendix A (the five CSV headers and vocabularies — they are the contract MF2, MF3 and MF4 build against in parallel).
- The `metadata-registries` skill (the exact-match rule for controlled-vocabulary ids; never `write_csv()` a registry without `na = ""`; the `read_*` / `register_*` idiom) and `calcofi4db/R/` for `read_variable()` / `register_variables()` (the pattern to mirror).
- `.claude/plans/2026-09-11 measurement-faces-probe/`: `nvs_probe.json` (20 P01s with their S27/S25/S06/A05 links and `sameAs`), `chebi.json`, `build.py` (the cast's `how`, `scale`, `composition` blocks and the `STANDS` / `SCALE_ONLY` maps — your seed rows), `eov/*.txt`.
- calcofi.org's *Bottle sampling methods* and *CTD FAQ circa 2020* pages (read in a browser if a fetch returns an empty shell — F5), each dataset's `metadata/{provider}/{dataset}/dataset_meta.yml` and EML links, and `measurements.json` v2026.09.10 (`gs://calcofi-db/ducklake/releases/v2026.09.10/measurements.json`) for the key and series list.

## You own
`metadata/measurement_chem.csv`, `measurement_method.csv`, `measurement_scale.csv`, `measurement_face.csv` (new, filled), `measurement_why.csv` (new, **header only** — MF2 fills it); `calcofi4db/R/registry_measurement_face.R` (new), `tests/testthat/test-registry_measurement_face.R` (new), the roxygen and `NAMESPACE` lines for them. Not `DESCRIPTION`/`NEWS.md` (the integrator bumps).

## Do
1. **Helpers** — `read_measurement_{chem,method,scale,why,face}()` (typed, `na = ""` aware, comment header skipped as `variable.csv` does) and `register_measurement_{…}()` (append-or-update by the natural key, writes through the registry writer). A `validate_measurement_faces()` that returns findings: a row without `source`; a vocabulary value outside Appendix A; a `measurement_why` key with zero or two `rank = 1` rows; a `measurement_face` key absent from `measurement_type`; a `nerc_l22` that is not an L22 URI. Tests: one small fixture per rule (the testing rules in the root CLAUDE.md), `devtools::test()` green.
2. **`measurement_chem.csv`** — for every key whose P01 has an S27 with a ChEBI `sameAs`, one `the_thing` row `via = nerc_s27` (source = the S27 URI). For composition keys, component rows `via = registry` with a source: salinity's 15 solutes with TEOS-10 Table D.3 mass fractions (`mass_fraction`; source the TEOS-10 Manual page), DIC/alkalinity's CO₂/HCO₃⁻/CO₃²⁻ (source Dickson et al. 2007 SOP or the Wikipedia DIC article's definition), phaeopigment's pheophytin-a as `one_of`. The ammonium pair (`conjugate` NH₃). Never the DIC S27's CHEBI_27594.
3. **`measurement_method.csv`** — one row per series in `measurements.json` (94): platform, instrument, one-or-two-sentence principle **paraphrased** from the source (never pasted), steps, `wavelength_nm`, precision, BibTeX keys (list any new ones for MF6), `calcofi_org_url` + `text_fragment`, source and source_url. `nerc_l22` only on an exact concept (search L22 for SBE 43, SBE 3/4, Guildline 8410A, SEAL AA3, ISUS); empty otherwise. Where the source is the record's own `derivation`, say so in `source`.
4. **`measurement_scale.csv`** — the marks for every key with a face, each with a source; computed marks carry `how` (the function and its inputs) and a value recomputed by the build, not trusted from the csv; no mark set from the record's observed range.
5. **`measurement_face.csv`** — every one of the 89 keys: `face_kind`, `face_of` for the 20 stand-ins (the probe's `STANDS` map, checked), `stands_in_note` (short, the chip's words), source. The 16 scale-only and `uws_flow` rows present with `face_of` empty.

## Gates (stop and report)
- A key whose P01 you believe is wrong (not exact): do not change `measurement_type.csv` — list it for the integrator (the findings pass owns that file).
- A method you cannot source from calcofi.org, the dataset's EML or the record: leave `principle` empty with `source = "not found"`, never guess.
- `devtools::test()` red.

## Hand back
Branches + SHAs in both repos; row counts per registry and the `validate_measurement_faces()` output on the filled files; the list of new BibTeX keys for MF6; one *Measured* line for the umbrella.
