# WS-A2 · `cc_cite()` in calcofi4r 1.17.0 and calcofi4py 0.6.0

**Agent:** Sonnet · high. **Wave 2** (after A0 merges — needs the `dataset` columns `doi`, `license`,
`license_url`, `acknowledgement`, `citation_others` and `catalog.json` `citation`). Own worktrees in
both packages.
**Plan:** umbrella § *WS-A › cc_cite()*. Precedent to copy exactly: `calcofi4r::cc_density_sql()` ≡
`calcofi4py.density_sql()` with a shared byte-identical fixture (`calcofi4r/tests/testthat/fixtures/`,
copied into `calcofi4py/tests/fixtures/`).

## Contract (identical in both languages)

`cc_cite(x = NULL, version = "latest", format = c("text", "bibtex", "csl"), con = NULL)`

- `x`: `NULL` (every dataset in the release), a character vector of `dataset_key`, or a data frame /
  DataFrame carrying `dataset_key` (the distinct keys are used — so `cc_cite(my_query_result)` works).
- Returns the **release citation first**, then one entry per dataset in `dataset_key` order: `text` = a
  character vector (R) / list[str] (py); `bibtex` = one string; `csl` = a list of CSL-JSON items. Each
  dataset entry carries `citation_main`, and appends `License: <id>` (+ `license_url` when custom),
  `DOI` when present, `acknowledgement` when present. Unknown keys error naming the key.
- Source of truth: the `dataset` table of the connection (`con` or `cc_get_db(version)`) and
  `cc_catalog(version)$citation` (fall back to `calcofi4db`'s wording when a pre-A0 catalog has none, with a
  `source = "computed"` attribute like `cc_climatology()`).
- `bibtex`: with a DOI, `@misc` built from the fields **offline** (no network in the default path); an
  optional `resolve = TRUE` fetches `https://doi.org/<doi>` with `Accept: application/x-bibtex`.
- `citation("calcofi4r")` / the package `CITATION` file and `calcofi4py.__citation__` cite the software.

## Do

1. R: `R/cite.R`, roxygen with `@concept release`, `NAMESPACE`, `NEWS.md` "# calcofi4r 1.17.0" with the
   user-facing bullets; `DESCRIPTION` bump.
2. py: `src/calcofi4py/cite.py`, export in `__init__.py`, `CHANGELOG.md` "## 0.6.0", `pyproject.toml` bump,
   mkdocs page.
3. Fixtures: `fixtures/cite_text.txt`, `cite_bibtex.txt`, `cite_csl.json` generated from a small
   in-memory `dataset` table (three datasets: one with DOI + CC-BY-4.0, one custom license, one with an
   acknowledgement) — **byte-identical in both repos**; tests read the fixture and compare.
4. A pkgdown / mkdocs article "Citing CalCOFI data" that shows `cc_cite(result_of_a_query)`.
5. Tests for: `NULL`, keys, data frame, unknown key error, each format, pre-A0 catalog fallback.

## Do not

Touch `cc_get_db()` internals; add a network call to the default path; push a tag before A0's release
column names are final (the integrator says when).

## Hand back

Fixture paths, `devtools::test()` / `pytest` results, the NEWS/CHANGELOG entries, one example output.

## Done (Sonnet)

- **calcofi4r** `../calcofi4r-ws-a2` branch `ws-a2` @ `6e8ad16` (10 files, +789). **calcofi4py**
  `../calcofi4py-ws-a2` branch `ws-a2` @ `e7dceac` (10 files, +750). No version bump in either repo
  (DESCRIPTION stays 1.17.0, pyproject.toml stays 0.6.0) — the integrator's instruction overrides
  this brief's "DESCRIPTION bump" / "`pyproject.toml` bump" lines in *Do*, both packages already
  carried H1's target-version NEWS/CHANGELOG heading when this workstream started.
- `cc_cite(x = NULL, version = "latest", format = "text"|"bibtex"|"csl", con = NULL, resolve = FALSE)`
  — identical name and signature in both languages (the contract's own wording, "identical in both
  languages" with one signature, is what this follows — not the three separate `cite_text/bibtex/csl`
  names I mistakenly drafted first and caught before committing). `resolve` is the one extra kwarg the
  prose describes but the pseudocode signature omits.
- **Deviation from *Do* item 1:** tagged `@concept database`, not `@concept release`. calcofi4r's
  `inst/_pkgdown.yml` reference index has no "release" section — `has_concept()` buckets are read /
  analyze / visualize / data / database / analytics / brand / Other, and `cc_get_db()` /
  `cc_catalog()` / `cc_release_sources()` / `cc_climatology()` all carry `@concept database`.
  `@concept release` would have filed `cc_cite()` under "Other", next to nothing related.
- Text/bibtex/csl fixtures were not independently generated per-language and hoped into agreement —
  generated once from the R implementation (`Rscript` + `devtools::load_all()` against a synthetic
  3-dataset `dataset` table + a mocked `cc_catalog()`), written to
  `calcofi4r/tests/testthat/fixtures/cite_{text.txt,bibtex.txt,csl.json}`, then copied byte-for-byte
  into `calcofi4py/tests/fixtures/` (`cmp` clean on all three, re-verified after both implementations
  were final). The Python implementation was then hand-ported line-for-line from the R one and passed
  every test against those fixtures on the first run.
- Offline by default in both: `cc_catalog()` (hence `version`) is the one required network dependency
  every `cc_cite()` call already has (same as `cc_get_db()`) — no NEW network call on the default
  path. `resolve = TRUE` is the only opt-in one (`doi.org` BibTeX content negotiation), and a failed
  fetch falls back to the offline entry rather than erroring. Tests never hit the network: `con` is an
  in-memory DuckDB with a synthetic `dataset` table, and `cc_catalog()` is mocked
  (`testthat::local_mocked_bindings()` in R — the same pattern `test-database.R`/`test-release-sources.R`
  already use for same-package internals; `monkeypatch.setattr("calcofi4py.cite.cc_catalog", …)` in
  Python).
- **Measured:** `devtools::test()` on `calcofi4r-ws-a2` — **513 tests, 0 failed, 0 warnings** (1 skip,
  `CALCOFI_PG_TEST` gate, pre-existing/unrelated). `PYTHONPATH=src pytest` on `calcofi4py-ws-a2` using
  the main checkout's `.venv` (never `pip install`) — **42 passed, 3 skipped** (PG-credential gates,
  pre-existing/unrelated). Fixture triple confirmed byte-identical across repos via `cmp` (exit 0,
  three times).
- Added `curl` to calcofi4r's `Suggests:` (the offline default path never loads it; only
  `resolve = TRUE`'s `.cc_cite_doi_bibtex()` does, guarded by `requireNamespace()`, mirroring
  calcofi4db's own `curl -> Suggests` move at 3.30.0).
- Also added, beyond the brief's explicit *Do* list, since the contract paragraph named them and they
  were near-zero-cost: `calcofi4py.__citation__` (a software-citation string paralleling R's
  `citation("calcofi4r")`, which needed no new code — base R already reads it from `DESCRIPTION`), and
  a `docs/reference.md` mkdocstrings entry + `mkdocs.yml` nav item for the new `docs/citing.md` page
  (calcofi4r's vignette is `vignettes/citing-calcofi-data.Rmd`, auto-discovered by pkgdown's
  `articles` nav component — no config change needed there).
- **Example output** (`format = "text"`, synthetic fixture data):
  ```
  CalCOFI (2026). CalCOFI Integrated Database, release v2026.09.03 [Data set]. Scripps Institution
  of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife.
  https://doi.org/10.5281/zenodo.99999999

  Wang, X.J. et al. (2021). CalCOFI Dissolved Inorganic Carbon Data. NOAA National Centers for
  Environmental Information.
  License: CC-BY-4.0
  DOI: https://doi.org/10.25921/3w9f-jd72
  ```
- No `RELEASES.md` entry in `workflows` — this workstream changes only the two read packages, nothing
  about the release's own content (same call WS-Q made for its tooling-only change).
- Not done / left for the integrator: pushing tags (brief says explicitly not to, and asks the
  integrator to decide when); confirming the real `dataset` table's `citation_others` column shape
  against a live post-A0 release (A0's handback lists `doi, license, license_url, acknowledgement,
  contact, citation_others` — `cc_cite()` reads `citation_main, license, license_url, doi,
  acknowledgement, pi_names`; `citation_others` and `contact` were not part of this brief's field list
  and are unused here, left for a future `cc_cite()` enhancement if Ben wants "additional citations"
  surfaced too).
