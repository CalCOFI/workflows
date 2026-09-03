# WS-Q checkpoint (stopped for offline laptop, mid-implementation)

Branch: `ws-q` (this worktree, `/Users/bbest/Github/CalCOFI/workflows/.claude/worktrees/agent-a1240c623d91d7d59`).
Worktree was merged to `5bb45ca` (the commit holding the briefs/agent rules) before this checkpoint —
confirmed `.claude/plans_todo/2026-09-03 WS-Q …md` and `.claude/agents/ws-sonnet-high.md` exist and are
unchanged from what this design is based on.

## Done

- Read the brief (`.claude/plans_todo/2026-09-03 WS-Q …md`), the umbrella § *Schema › Provider question
  sheets*, `questions_email.qmd`, `calcofi4db::read_questions()`/`questions_datatable()`
  (`../calcofi4db/R/questions.R`), CLAUDE.md § "The question registry convention", `metadata/provider.csv`.
- Confirmed **7 active providers** (via R, not naive `awk -F,` — `provider_name`/`notes` cells contain
  embedded commas that break a comma-split): `calcofi, swfsc, sio, cce-lter, cdfw, farallon, sccoos`.
  17 `questions.csv` files exist across 6 of those 7 (sccoos has no ingest yet — 0 files; still gets a
  placeholder + a sheet with just the README tab).
- Confirmed `googlesheets4` (1.1.2), `googledrive`, `yaml`, `testthat` are **already installed** — no
  package install needed at all; `librarian::shelf()` at the top of the script is enough.
- Confirmed the `sys.nframe() == 0` guard idiom works to separate "run as `Rscript`" (executes CLI) from
  "sourced by a test" (does not) — tested directly, see Next step for the pattern to paste in.
- Confirmed `googlesheets4::request_generate()` / `request_make()` expose the raw Sheets API for
  `sheets.spreadsheets.batchUpdate` (verified `"sheets.spreadsheets.batchUpdate"` is a real endpoint name
  via `gs4_endpoints()`) — this is how protected ranges + status dropdown validation get applied, since
  `sheet_write()` only writes cell values.
- Found emails to share sheets with: Ben `bebest@ucsd.edu` (per brief and `ingest_spatial.qmd` comment),
  Erin Satterthwaite `esatterthwaite@ucsd.edu` (per `.claude/plans/2026-06-10 CalCOFI.io Landing Page
  Redesign.md`).
- Confirmed `questions_email.qmd`'s "[link]" placeholder (in `.claude/plans_todo/2026-09-03 Email drafts
  …md` §2, the Ed draft) is exactly what the brief's "link back" step should fill from
  `metadata/questions_sheets.yml`.
- **Written and committed** (this checkpoint): `metadata/questions_sheets.yml` — placeholders
  (`sheet_id: ~, url: ~, created: ~`) for all 7 active providers, with a header comment explaining the
  contract and that `push … --execute` fills it in (needs Ben's auth).
- No test suite convention exists for standalone `scripts/*.R` in this repo (checked `find . -iname
  "test*"`) — decided to add `scripts/test_sync_questions_sheets.R`, a plain `testthat::test_that()`
  script runnable via `Rscript scripts/test_sync_questions_sheets.R` (testthat works standalone outside a
  package; no new pattern to invent, just no precedent to copy).

## Next step — the exact design to implement (not yet written to disk)

Write `scripts/sync_questions_sheets.R` with this function split. **Pure / network-free (unit test
these in `scripts/test_sync_questions_sheets.R` with a fake sheet as a data.frame, per the brief):**

- `qs_editable_cols()` → `c("answer","status","answered_date","who")`
- `qs_tab_name(provider, dataset)` → `paste0(provider, "_", dataset)` (= `dataset_key`)
- `qs_read_csv_raw(path)` → calls `calcofi4db::read_questions(path)` **only to validate** (throws on bad
  vocab/dup labels), then does its own `readr::read_csv(path, na = "", col_types =
  cols(.default = col_character()))` and returns *that* — because `read_questions()` re-sorts rows by
  priority, and pushing/pulling should preserve the **file's own row order** so a pull doesn't reorder
  `questions.csv` and create noise diffs. (Column order is already fine from `read_questions()`/raw
  read — confirmed every file's header matches `QUESTION_COLS`' order exactly.)
- `qs_stamp_asked_dates(df, today = Sys.Date())` → for rows with blank/NA `asked_date`, sets it to
  `format(today, "%Y-%m-%d")`; returns `list(df=, n_stamped=, stamped_ids=)`. This is how "`asked_date`
  is stamped by the *first* push" gets implemented — idempotent (blank only once).
- `qs_apply_pull(csv_df, sheet_df, path)` — the core merge, pure:
  1. `sheet_df` has columns `id, answer, status, answered_date, who` (simulates a `range_read()`).
     Normalize `""` → `NA` (Sheets returns empty string, not NA).
  2. If `sheet_df$id` has any id not in `csv_df$id`, `stop()` naming the unknown id(s) — defensive; the
     `id` column is protected so this should never happen, but a silent add must not happen either.
  3. For each matched id, diff old vs new on the 4 editable columns; collect
     `diffs` = data.frame(id, label, field, old, new, note).
  4. Validate: any non-NA pulled `status` not in `calcofi4db::question_statuses()` → `stop()` **naming
     the row** (`id`/`label`, not just the file — read_questions()'s own error only names the file, so
     this is a deliberate improvement, matches brief wording "errors, naming the row").
  5. Auto-flip: where pulled `answer` is non-empty and pulled `status` is `NA`/`""`/`"open"`, set
     `status <- "answered"`, record in `flips`, add a `note` to that diff row, and the caller emits a
     `warning()` listing the flipped ids.
  6. Return `list(df = <csv_df with only matched-id editable cells replaced>, diffs = <data.frame>,
     flips = <character ids>)`. Unmatched-in-sheet ids in `csv_df` pass through untouched — this is what
     makes "no row lost on a second push" true: push always re-serializes the **full** current `csv_df`
     (which nothing here ever drops rows from), so a second push after a pull cannot lose a row.
- `qs_write_questions_csv(df, path)` → `readr::write_csv(df, path, na = "")` then
  `calcofi4db::read_questions(path)` to re-read/validate immediately (same "write then re-read to trip
  the validator right away" pattern as `register_measurement_types()` in `calcofi4db/R/registry.R`).
- `qs_contiguous_ranges(idx0)` — pure: sorted 0-based column indices → list of `{start, end}` (end
  exclusive) contiguous runs, for building minimal protected-range column spans. Hand-verified example:
  `idx0 = c(0,1,2,3,5,6,8,11,12)` (the 9 protected columns when editable = `status(4), answer(7),
  answered_date(9), who(10)` out of the 13 `QUESTION_COLS`) → `[0,4), [5,7), [8,9), [11,13)` (4 ranges,
  not 9 individual ones).
- `qs_protection_requests(sheet_id, col_names, editable_cols = qs_editable_cols())` — pure builder of
  Sheets API `addProtectedRange` request objects: one per contiguous run of protected columns (full
  column, all rows, via `qs_contiguous_ranges()`), **plus** one per contiguous run of *editable* columns'
  **header row only** (`startRowIndex=0, endRowIndex=1`) — so a provider can edit `answer`/`status`/
  `answered_date`/`who` data cells but can't rename those headers (the pull matches by column name).
- `qs_validation_request(sheet_id, col_names, nrow_data, values = calcofi4db::question_statuses())` —
  pure builder of one `setDataValidation` request (`ONE_OF_LIST`, `showCustomUi=TRUE`, `strict=TRUE`) over
  the `status` column's data rows only.
- `qs_readme_content(provider_short)` — small data.frame (Field/Description or similar) for the README
  tab: column meanings, `open|proposed|answered|wontfix` / `blocker|high|normal|low` vocab, and **"the
  CSV in the CalCOFI GitHub repo (`calcofi/workflows`, `metadata/{provider}/{dataset}/questions.csv`) is
  the record — edits to `answer`/`status`/`answered_date`/`who` here are pulled back into it; edits to
  any other column are not saved."**

**Network-touching orchestration (write carefully, cannot be tested without Ben's auth — say so in
comments):**

- `qs_provider_registry()` → `read.csv(here("metadata/provider.csv"))`, filter `status == "active"`.
- `qs_dataset_paths(provider)` → `Sys.glob(here(glue("metadata/{provider}/*/questions.csv")))`.
- `qs_load_sheets_yml(path)` / `qs_save_sheets_yml(x, path)` → thin `yaml::read_yaml()`/`write_yaml()`
  wrappers over `metadata/questions_sheets.yml`.
- `gs_ensure_spreadsheet(provider, short, entry)` → if `entry$sheet_id` set, `googlesheets4::as_sheets_id()`
  it; else `googlesheets4::gs4_create(glue("CalCOFI integrated database — questions for {short}"), sheets
  = "README")`.
- `gs_push_provider(provider, sheets_yml_path, execute = FALSE, share_with = c("bebest@ucsd.edu",
  "esatterthwaite@ucsd.edu"))`:
  - Always: `qs_read_csv_raw()` + `qs_stamp_asked_dates()` each dataset's file, print a plan table
    (tab, n rows, n asked_date to stamp). **Dry run stops here — no network at all**, by design (keeps
    `push` dry-run safe/offline, matches `pull`'s dry-run which *does* need a read).
  - `--execute`: `gs_ensure_spreadsheet()` (writes `sheet_id`/`url`/`created` into the yml + shares with
    `share_with` **only the first time**, i.e. only when `entry$sheet_id` was `NULL` going in);
    `sheet_write()` the README tab; for each dataset tab, check `pl$tab %in%
    googlesheets4::sheet_names(ss)` **before** writing — if the tab is new, `sheet_write()` then apply
    `qs_protection_requests()` + `qs_validation_request()` via one `batchUpdate`; if the tab already
    existed, `sheet_write()` only (values overwrite in place; do **not** re-add protection/validation —
    `sheet_write()` doesn't clear existing protected ranges, so re-adding on every push would pile up
    duplicate `ProtectedRange` objects each run). If `n_stamped > 0`, also `qs_write_questions_csv()` the
    stamped df back to the local CSV.
  - **Known unverified risk, flag to Ben explicitly**: the "only protect on tab creation" rule means if
    the column layout (`QUESTION_COLS`) ever changes, the *existing* sheet's protection/validation goes
    stale and needs a manual fix (delete + recreate the tab, or add a `--reprotect` mode later). Not
    needed for the initial 17-file rollout.
- `gs_pull_provider(provider, sheets_yml_path, execute = FALSE)`:
  - `stop()` if no `sheet_id` yet ("push --execute first").
  - Per dataset tab: `googlesheets4::range_read(ss, sheet=tab, col_types="c")`, subset to
    `id` + `qs_editable_cols()`, run `qs_apply_pull()`, print the diff (`as.data.frame(res$diffs)`) and
    any auto-flips **always** (dry run or not — brief: "the diff is printed"); `--execute` additionally
    calls `qs_write_questions_csv(res$df, path)` when there were changes.
- `.main(args = commandArgs(trailingOnly = TRUE))` — parses `<push|pull> [provider] [--execute]`
  (`flags <- args[grepl("^--", args)]`, `pos <- args[!grepl("^--", args)]`, same style as
  `scripts/thin_releases.R`); provider omitted ⇒ loop `intersect(qs_provider_registry()$provider,
  names(qs_load_sheets_yml(...)))` (i.e. all 7). Guard the call: `if (sys.nframe() == 0) .main()` so
  `source()`-ing the file for tests does not run the CLI (verified this idiom works, see Done).

**`scripts/test_sync_questions_sheets.R`** — `source()` the main script (CLI guarded, so sourcing is
safe), then `testthat::test_that()` blocks covering at minimum:
1. `qs_stamp_asked_dates()` stamps only blank rows, is idempotent on a second call.
2. `qs_apply_pull()`: a changed `answer`/`status`/`who`/`answered_date` produces the right diff rows;
   an unknown `status` value `stop()`s and names the row; an `answer` present with `status` still
   `"open"` (or blank) auto-flips to `"answered"` with a recorded flip + warning; an id in `sheet_df` not
   present in `csv_df` errors.
3. **"No row lost on a second push"** as an explicit integration-style pure test: build a 3-row
   `csv_df` fixture, simulate a pull that changes 1 row via `qs_apply_pull()`, assert `nrow(result$df)
   == 3` and the other 2 rows are byte-identical to the input.
4. `qs_write_questions_csv()` round-trips through a `tempfile()` and the result still passes
   `calcofi4db::read_questions()` (the brief's gate: "`read_questions()` passes on every CSV after a
   pull").
5. `qs_contiguous_ranges()` against the hand-verified `c(0,1,2,3,5,6,8,11,12)` example above.
6. `qs_protection_requests()` / `qs_validation_request()`: pure shape assertions (right `sheetId`, right
   column index math, right number of ranges) — no network, but real regression coverage for the API
   request math since that part can't be exercised live before Ben runs it.

Then: **CLAUDE.md** § "The question registry convention" — append two sentences (per the brief) after
the existing `status`/`priority` paragraph, roughly: *"Each provider also gets a Google Sheet
(`metadata/questions_sheets.yml`, one tab per dataset, `scripts/sync_questions_sheets.R push|pull`) —
the CSV stays the record; the sheet's `answer`/`status`/`answered_date`/`who` columns are pulled back
into it, everything else is protected."* Also add the two-sentence link in `questions_email.qmd`'s per-
provider draft loop (read `metadata/questions_sheets.yml`, print the tracker URL under the `Subject:`
line, gracefully falling back to "(not yet created)" when `sheet_id` is still `~`).

**`RELEASES.md`**: check whether this counts as release-content-affecting — it does not (it's process
tooling around `questions.csv`, not release schema/data), so no `# Unreleased` entry is needed unless the
umbrella plan says otherwise on a re-read.

## Open questions / what Ben must do (none of this can be done without Google auth)

1. **Run the actual sheet creation + first push.** Once `scripts/sync_questions_sheets.R` exists (next
   session), Ben runs, in an R session that can complete an interactive OAuth (or has the
   `calcofi-admin` service account key set via `googlesheets4::gs4_auth(path=...)`):
   ```r
   googlesheets4::gs4_auth()   # or gs4_auth(path = "<calcofi-admin service account json>")
   ```
   then, from `workflows/`:
   ```sh
   Rscript scripts/sync_questions_sheets.R push swfsc --execute   # mint + populate one sheet first, verify it looks right
   Rscript scripts/sync_questions_sheets.R push --execute         # the remaining 6 providers
   ```
   This fills in `metadata/questions_sheets.yml`'s `sheet_id`/`url`/`created` for real — **that file must
   be committed after this run** (it's currently placeholders only).
2. **Prove the round-trip** (the brief's explicit gate): in the SWFSC sheet, hand-edit one `answer` (and
   leave `status` however it lands, to also exercise the auto-flip), then:
   ```sh
   Rscript scripts/sync_questions_sheets.R pull swfsc            # dry run — confirm the diff shown is exactly that one edit
   Rscript scripts/sync_questions_sheets.R pull swfsc --execute  # writes metadata/swfsc/*/questions.csv
   git diff metadata/swfsc                                        # eyeball it, then revert per the brief ("edit... revert")
   git checkout -- metadata/swfsc                                 # or: undo the hand-edit in the sheet and pull again
   ```
3. **Sharing**: confirm `bebest@ucsd.edu` + `esatterthwaite@ucsd.edu` are the right two to auto-share
   with (matches the brief: "share with Ben, Erin; the provider is shared by Ben when the email goes
   out" — i.e. the *provider* itself is NOT auto-shared by the script, only Ben/Erin; Ben shares outward
   manually when he sends the email).
4. Nothing else is blocked — once auth + the round-trip are done, `questions_email.qmd`'s drafts should
   already show the real sheet URLs (this session's next step wires that read), and CLAUDE.md /
   `metadata/questions_sheets.yml` are ready to commit on `ws-q` alongside the script.

## Files touched so far (this branch, `ws-q`)

- `metadata/questions_sheets.yml` (new) — 7 provider placeholders, committed.
- `.claude/plans_todo/_checkpoint_ws-q.md` (new, this file) — committed.

Not yet written: `scripts/sync_questions_sheets.R`, `scripts/test_sync_questions_sheets.R`, the
`CLAUDE.md` two-sentence addition, the `questions_email.qmd` sheet-URL line.
