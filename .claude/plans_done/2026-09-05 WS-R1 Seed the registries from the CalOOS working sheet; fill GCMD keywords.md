# WS-R1 · Seed the registries from the CalOOS working sheet; fill GCMD keywords

**Agent:** Sonnet · high. **Wave 1**, `workflows` worktree. **Needs:** R0's registry column shapes (copied into
this brief); merge after R0 and re-run the import if R0 changed a shape. **Plan:** `.claude/plans/2026-09-05 CalCOFI.io as a dataset catalog — one record per dataset with every endpoint, the front door re-cut around Datasets, and the portal registrations.md` § Context › *The CalOOS
working sheet*, D-1, D-9, Decision 16.

## Goal

Nothing anyone typed into the CalOOS sheet is re-typed: its 41 rows become `holdings.csv` rows,
`distribution.csv` rows and **proposals** in the descriptive sidecars; and every integrated dataset gets GCMD
keywords.

## Read first

- The sheet: `https://docs.google.com/spreadsheets/d/1eyvhdzA5YwuDxH8tBld2-h_odKA1KYt_RXI3loI0OaU/export?format=csv&gid=0`
  (public; 41 rows × 35 columns; tab *CalCOFI list*). Its comment threads are in the plan § Context.
- `metadata/holdings.csv`, `metadata/distribution.csv` (R0's shapes), `metadata/license.csv`,
  `metadata/provider.csv`; the 16 notebooks' `calcofi.dataset_meta` blocks (or the sidecars, if R2 landed).
- `release/v2026.09.04/metadata.json` `datasets{}` for `link_data_source` / `link_calcofi_org`.
- GCMD Science Keywords (`https://gcmd.earthdata.nasa.gov/KeywordViewer/`, Earth Science › Oceans /
  Biological Classification); the 12 categories in `metadata/category.csv` and the dataset's
  `measurement_types` are the evidence for each keyword.

## Do

1. `scripts/import_caloos_sheet.R`: read the CSV export; normalise; **match** each row to a `dataset_key`
   by *Data Access URL* against `distribution.csv` + `link_data_source` + the CoastWatch mirror map in the
   plan (Appendix B); unmatched → **a holding sidecar** `metadata/{provider}/{dataset}/dataset_meta.yml` with a minted
   `dataset_key` (`{provider}_{dataset}`; new providers into `provider.csv`: JCVI, Cal Poly, Stanford Hopkins
   Marine Station), `status` from *Ongoing v. archived* + *Priority*, `module` = *Catalog Module Title*, lead
   name/email/affiliation as `creators[]`/`contact`, `doi`, `link_data_source` = access URL (plan § D-11);
   `holdings.csv` is generated from them by R0's builder, never hand-edited.
2. For matched rows write `distribution.csv` rows (`kind = mirror|source`, the CalOOS module URL as a
   `caloos` row where present) and **proposals** into the sidecar (R2's file, else a
   `metadata/{p}/{d}/dataset_meta.proposed.yml`): `creators[]`/`contact` from the lead columns;
   `license` id proposal (*"Public domain (CC0)"* → `CC0-1.0`, confirmed against the source ERDDAP `.das`
   `license` global); `citation_main` from *Preferred citation* when present; `keywords` = *Tags*;
   `funding`, `associated_parties[]` (role from the column), `quality_control_md`, `maintenance`
   (frequency, ongoing/archived, continuous). Each proposal carries `# source: caloos-sheet row N, 2026-09-05`.
   Never overwrite a non-empty value; print the diff.
3. **GCMD keywords** for the 16: 2–5 per dataset, exact GCMD strings, from the category + measurement types;
   a keyword nobody can justify from the data is not written. Into the sidecar (or notebook YAML if R2 has
   not landed) under `keywords_gcmd`.
4. **`metadata/category.csv`**: add the row *Genomics & eDNA* (`order` 13, `realm` bio, `icon` `cat-genomics`,
   description: metabarcoding and environmental DNA — ASV tables, eDNA-derived abundance and density); widen
   *Nutrients & Chemistry* (organic carbon and nitrogen, nitrate isotopes, trace metals) and *Phytoplankton*
   (adds imaging flow cytometry). Home the genomics/eDNA holdings there. The icon itself is P1's (added to
   the sprite via `explore/scripts/build_icons.mjs`, MDI `dna`); until then `cat-other` renders.
5. Report: rows matched / holdings created / proposals written / conflicts (a sheet value disagreeing with
   the record — e.g. the sheet's *archived* on a dataset the release says is ongoing) as a table in the
   hand-back, and as `questions.csv` rows where a provider must decide.

## Gates

`Rscript scripts/build_workflows_index.R` passes (registries validate); the import is idempotent (a second
run writes nothing); every holding's `link` answers 2xx or is `TBD` with a note.

## Do not

Edit the Google Sheet; write a licence without evidence; drop a sheet row because it looks like a duplicate
(record it as a mirror); touch any R function in calcofi4db.

## Hand back

The match table (41 rows → key | holding), the conflict list, the keyword table, one *Measured* line.
