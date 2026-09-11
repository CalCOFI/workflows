# measurement-faces probe (2026-09-11)

The scripts and inputs behind the mockup *CalCOFI Measurement Faces*
(https://claude.ai/code/artifact/aefb4449-c780-4da9-8216-3cbe91530e03) and the plan
`../2026-09-11 Measurement faces — what it is, how it is taken and why it matters on every measurement page, agent-scaled.md`.
Everything was run against release v2026.09.10 (`~/_big/calcofi/releases/v2026.09.10/parquet` and
`gs://calcofi-db/ducklake/releases/v2026.09.10/measurements.json`). Scratch code: reference for the workstreams, not a deliverable.

| File | What |
|---|---|
| `nvs_probe.py` → `nvs_probe.json` | 20 P01 concepts from the NERC Vocabulary Server (JSON-LD, `_profile=nvs`), each with its S27/S25/S06/S26/P02/P06/P07/A05 links and their `owl:sameAs` (ChEBI, CAS, WoRMS, QUDT). Slow: ~15 s per concept with links. |
| `fetch_chem.py` → `chebi.json`, `wp.json` | ChEBI compound records (`/chebi/backend/api/public/compound/CHEBI:{id}/`: name, formula, charge, mass, definition, SMILES) and Wikipedia REST summaries (lead + revision). |
| `wd_cas.json` | Wikidata by CAS (P231): SMILES, formula, PubChem CID, ChEBI, P117 structure image (8 of 23 have one). |
| `mol/*.mol` → `draw2.py` → `svg/*.svg` | ChEBI's curated 2D molfiles (`/chebi/backend/api/public/molfile/{id}/`) drawn by RDKit 2026.03 (scratch venv, Python 3.12), black → `currentColor`. CO₂ was redrawn from SMILES (its molfile is vertical). |
| `chem_calc.json` | gsw (TEOS-10) freezing point and O₂ solubility, PyCO2SYS 1.8.3 carbonate speciation + the Bjerrum curve, all at the record's surface medians (bottle T 16.08, SP 33.472; DIC 2009.8, TA 2234.65). |
| `anom2.sql` → (single band, superseded) · `anom_bands.sql` → `anom_bands.csv`, `band_n.csv` | Yearly anomaly per depth band: `obs_env` ⋈ `climatology` on dataset_key, measurement_type, site_key, month(datetime), depth_bin; `qual_ok`; mean per cruise, then per year. The climatology stops at the 500 m bin. |
| `oni.txt` | NOAA CPC Oceanic Niño Index (`oni.ascii.txt`), fetched 2026-09-11; JJA 2026 = +1.80. |
| `eov/*.txt` | GOOS EOV specification sheets as text (`pdftotext -layout`), from the oceanexpert.org download behind each `goosocean.org/document/{id}`. |
| `build.py` + `template.html` → `data.json`, `measurement_faces.mockup.html` | The mockup: `build.py` assembles `data.json` (record numbers, structures, bands, alternatives, stands-in map); the template's inline JS is the reference implementation for WS-MF4. |

Rebuild: `uv venv --python 3.12 venv && uv pip install --python venv/bin/python rdkit gsw PyCO2SYS`, then
`venv/bin/python build.py` and inject `data.json` into `template.html` at `/*DATA*/`. `anom_bands.sql` has the release path expanded in it.
