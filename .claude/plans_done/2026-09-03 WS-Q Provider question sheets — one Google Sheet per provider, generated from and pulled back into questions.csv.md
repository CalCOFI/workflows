# WS-Q · Provider question sheets — one Google Sheet per provider, generated from and pulled back into `questions.csv`

**Agent:** Sonnet · high. **Wave 1**, `workflows` worktree. Needs Ben once for Google auth
(`googlesheets4::gs4_auth()` as bebest@ucsd.edu, or the `calcofi-admin` service account with the sheets
shared to it) — stop and ask at that point.
**Plan:** umbrella § *Schema › Provider question sheets*; the Ed draft in the email-drafts file links the
SWFSC sheet.

## Read first

`questions_email.qmd` (how the 17 files are read with `read_questions()`, joined to `pi_names`, drafted
per provider); `calcofi4db::read_questions()` / `questions_datatable()` (the vocabulary: `open | proposed |
answered | wontfix`; `blocker | high | normal | low`; the `id`/`label` convention); CLAUDE.md § "The question
registry convention"; `metadata/provider.csv` (7 active providers); memory `reference_excel_track_changes_applescript`
is *not* the pattern here — Sheets, not Excel.

## Contract

- **One Sheet per provider** (`CalCOFI integrated database — questions for <provider_short>`), one tab per
  dataset (`swfsc_ichthyo`, `swfsc_cufes`, …) plus a `README` tab explaining the columns, the statuses,
  and that the CSV in GitHub is the record. Sheet ids live in `metadata/questions_sheets.yml`
  (`provider: {sheet_id, url, created}`), committed.
- **Push** (`Rscript scripts/sync_questions_sheets.R push [provider]`): every row of every `questions.csv`
  for the provider, columns in the CSV's order; the sheet's editable columns are **`answer`, `status`,
  `answered_date`, `who`** (data validation on `status`); every other column is written by the push and
  protected (a protected range). Rows are keyed on `id`; a push never deletes a row a provider has edited.
- **Pull** (`… pull [provider]`): read the four editable columns back; write into the CSV through the
  same validation `read_questions()` applies (an invalid status errors, naming the row); `asked_date`
  is stamped by the *first* push; a pulled `answer` with `status` still `open` is flipped to `answered`
  with a warning. Dry-run by default, `--execute` writes; the diff is printed.
- **Link back**: `questions_email.qmd` drafts gain the provider's sheet URL; `questions_datatable()`
  callers may show it (not required).

## Do

1. `scripts/sync_questions_sheets.R` (googlesheets4 + googledrive; `librarian::shelf()`), the yml, a
   `README` tab template.
2. Create the seven sheets (Ben's Drive folder for CalCOFI; share with Ben, Erin; the provider is shared
   by Ben when the email goes out), push all 17 files, verify a round-trip: edit one answer in the
   swfsc sheet by hand, pull, see the CSV diff, revert.
3. CLAUDE.md § question registry: two sentences on the sheets and the four-column rule.

## Gates

Round-trip proven; `read_questions()` passes on every CSV after a pull; no row lost on a second push.

## Do not

Change any question text from the sheet side; move the source of truth for questions out of git.
