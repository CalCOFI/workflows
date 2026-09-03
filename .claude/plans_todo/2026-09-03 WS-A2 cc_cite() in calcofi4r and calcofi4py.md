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
