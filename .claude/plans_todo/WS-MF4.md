# WS-MF4 — the landing fetcher: NVS → ChEBI → RDKit, the leads and the ONI, into measurements_media.json (D1, D8)

**Umbrella:** `.claude/plans/2026-09-11 Measurement faces — what it is, how it is taken and why it matters on every measurement page, agent-scaled.md` § D1, D2, D8, Appendix A (media shape), § Verification MF4. **Spec:** the artifact https://claude.ai/code/artifact/aefb4449-c780-4da9-8216-3cbe91530e03 — the structures, the chain, the ion bar and Bjerrum inputs. **Agent:** `ws-opus-medium`. **Repo:** CalCOFI.github.io (`~/Github/CalCOFI/.worktrees/CalCOFI.github.io-ws-mf4`, branch `ws-mf4`). **Wave 1 · ≈ 1 day.**

## Read first
- The umbrella's D1, D2, D8, F1–F3 and Appendix A. The species-faces fetcher's brief (`.claude/plans_todo/WS-F2a.md`) and, if merged, `scripts/fetch_species_media.py` — mirror its cache, resumability, rate limits, User-Agent and bucket layout.
- `.claude/plans/2026-09-11 measurement-faces-probe/` `nvs_probe.py` (the NVS JSON-LD profile, the parts to follow), `fetch_chem.py` (ChEBI compound endpoint), `draw2.py` + `build.py`'s `svg()` (molfile → RDKit → `currentColor` → tight `viewBox`; CO₂'s vertical molfile redrawn from SMILES), `oni.txt`.
- `scripts/fetch_release.sh`, `.github/workflows/refresh.yml` (where the media JSON lands), `.gitignore`.

## Before you start
Create the worktree from CalCOFI.github.io `main` **only after the species-faces PR (branch `species-faces`, integrator
session "workflows-e5") has merged**. `scripts/fetch_release.sh` will then carry a species-media block near its end: append
your measurement-media block after it, never edit theirs. Upload only under `gs://calcofi-files-public/measurement-media/`.

**Met 2026-09-11:** species-faces merged to main as `3a49931` (PR #20). In `scripts/fetch_release.sh` the species-media block sits after the
measurements block and before `versions.json`: put the measurement-media block right after the species-media block.

## You own
`scripts/fetch_measurement_faces.py`, `scripts/check_measurement_faces.py`, `.github/workflows/measurement-media.yml` (weekly + dispatch), the lines in `scripts/fetch_release.sh` and `.gitignore`, `requirements-media.txt` (rdkit pinned) if the species fetcher has none.

## Do
1. Walk `measurements.json` (1.0 or 1.1): for each key, the P01 (or `face.face_of`'s P01, or the `chem[]` rows in 1.1) → NVS (`?_profile=nvs&_mediatype=application/ld%2Bjson`), following S27, S25, S06, A05, P06, P07, P02 one hop; record pref label, definition, and `sameAs` (ChEBI, CAS, WoRMS, QUDT).
2. For each ChEBI id: the compound record (name stripped of markup, formula, charge, mass, definition) and the molfile → RDKit SVG (BW palette, text as paths, `currentColor`, tight `viewBox`, a linear molecule drawn horizontal); **never store ChEBI roles**.
3. Wikipedia: the lead of each title named by `why[kind = wikipedia]` (two sentences, revision id, CC BY-SA 4.0); the ONI table → `strong_el_nino` (any 3-month ONI ≥ +1.5) and `latest`.
4. Write `measurements_media.json` (Appendix A) to `gs://calcofi-files-public/measurement-media/{release}/` and `_data/` locally; per-URI cache on disk, resumable, NVS ≤ 2 rps, a contact User-Agent on every request.
5. `check_measurement_faces.py`: every structure traces to an S27 `sameAs` or a registry row; every lead has a revision; no `roles` key anywhere; every SVG parses and uses no colour but `currentColor`.

## Gates (stop and report)
- NVS or ChEBI refuses the run (403/429 persisting past back-off).
- An S27 whose ChEBI is not the thing measured (as DIC's carbon atom): skip it, list it; the registry decides.

## Hand back
Branch + SHAs; the `--only` diff against the probe for the eleven cast keys; the full-run coverage (structures, chains, leads) and runtime; one *Measured* line.
