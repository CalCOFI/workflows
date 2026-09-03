# WS-C · Dungeness crab — examined samples only, UCSD Library deposit placeholder

**Agent:** Sonnet · high. **Wave 1**, worktree in `workflows`. Re-runs the crab ingest (0.4 min).
**Plan:** umbrella § *The ask › 4*, § *Context › Crab*, § *Decisions › WS-C*; Q6 for the placeholder.

## Read first

`ingest_cdfw_dungeness-crab.qmd`: the YAML (l.20–70), "Build Sorting Log" (l.418–475), the emit-core
prose and chunk (l.596–730; arms 1b and 2b are the sorting-log rows), the `stopifnot()` counts after
the appends, the write/publish section (l.1255–1300); `metadata/cdfw/dungeness-crab/questions.csv`
(Q08 longitude, Q03 duplicates, Q13 effort); `metadata/dataset_status.csv` (its row is stale);
memory `project_cdfw_dungeness_crab`. Measured today: `sample` = 310 subsamples + 2,011 tows; sorted
tows 216 (1984-05-17 → 2009-04-19), unsorted 1,795.

## Do

1. **Drop the unsorted rows from the core.** Arm 1b appends only `WHERE sorting_status = 'sorted'`
   (arm 2b already does). `dungeness_sorting_log` keeps all 2,011 as the notebook's working table and
   its inventory prose; the "sorted/unsorted becomes presence/absence of an `obs` row" paragraph is
   rewritten: an unexamined archived jar is a fact of the deposit's sorting log, not a sample of this
   dataset. Update `stopifnot()`s: `sample` = 526, `obs` unchanged.
2. YAML: `description` ("… and 216 archived samples from the 1949–2009 sorting log that were examined
   and found free of *M. magister* (1984–2009)"), `tables_owned` notes (526 events), and
   `link_data_source` per Q6 — default the placeholder
   `https://library.ucsd.edu/dc/search?q=CalCOFI+Dungeness+crab+megalopae` with the comment
   `# placeholder until the UCSD Library RDC deposit (2026-08-27) is minted — see Q14`.
3. `questions.csv` **Q14** (`open`, `normal`, who = Betty Huang / UCSD Library RDC): "DOI and object URL
   for the deposit?" — `proposed_answer`: on mint, add `doi:`, cite the DOI in `citation_main` with the
   deposit year, and point `link_data_source` at `dc/object/<ark>`. Update Q08's `context`: the deposit
   README says the sign was corrected; reconcile (negate, close Q08) once the zips are in Drive
   `cdfw/dungeness-crab/deposit/` — **Ben downloads them before 2026-09-26**; do not block on it.
4. `metadata/dataset_status.csv`: the row still says HELD OUT OF RELEASE — rewrite to the current state.
5. `RELEASES.md # Unreleased`: "The Dungeness crab dataset is the examined samples" — 2,321 → 526
   events; what a consumer sees change (`sample` rows, `coverage_temporal_observed` 1949 → 1984 start);
   the Library deposit and pending DOI.
6. `tar_invalidate(ingest_cdfw_dungeness_crab)`; render; confirm the sidecar diff (`manifest.json` row
   counts) and `_output` mtime; update the memory file.

## Gates

`sample` 526 / `obs` count unchanged / `obs` FK to `sample` intact; coverage measured 1984-05 → 2014-05;
`build_workflows_index.R` passes (the placeholder answers 200); `check_measurement_bounds()` unchanged.

## Do not

Touch `measurement_taxon.csv` / taxon code (WS-E owns it); negate the longitude before the deposit is
in hand; remove Q02's caveat.
