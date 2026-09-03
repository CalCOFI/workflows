# WS-DG checkpoint (laptop going offline — resume from here)

Branch `ws-dg` in worktree `.claude/worktrees/agent-aa242c9f7d3da421a`. Fast-forwarded to
`5bb45ca` (the commit holding the briefs) before starting — confirmed `.claude/plans_todo/2026-09-03
WS-DG …md` and `.claude/agents/ws-sonnet-high.md` exist. **No file edits made yet — pure research.**
Nothing to commit in `workflows` or `calcofi4db` (no calcofi4db worktree created yet either).

## Done (research only, not yet written to any file)

- Read the WS-DG brief in full, and umbrella §§ "The ask › 3", "Context › Rasmus's answers", "WS-D",
  "WS-G", "Decided" Q7/Q8/Q10/Q11.
- Read `.claude/plans_todo/2026-09-03 Email drafts — …md` — draft 3 (Rasmus) is already ~90% written;
  only missing piece is the 14-cruise table with ship names (item (f)), everything else in that draft
  is done and should NOT be rewritten.
- **bottle `questions.csv`** (`metadata/calcofi/bottle/questions.csv`): Q09 is exactly item (a)
  (R_* inheriting quality codes / P_qual meaning); Q05 is the related r_ammonium question named in the
  brief. Both currently `proposed`.
- **ctd-cast `questions.csv`** (`metadata/calcofi/ctd-cast/questions.csv`, labels Q01–Q27, all present,
  next free label **Q28**):
  - **(b)** = **Q27** (Rathburn core casts) — `proposed` today, has a full `proposed_answer` already
    matching Rasmus's "continue to exclude". → flip to `answered`.
  - **(c)** archive folder conventions (`orig*`/`uncorrected/` excluded, `separate_runs/` kept):
    **grepped every questions.csv for "separate_runs" — ZERO matches anywhere in the repo.** This was
    only ever an *emailed* question (see `.claude/calcofi_notes.md` ~line 2389, the six-item list from
    the Aug 24 draft), never filed as a registry row — unlike (a) and (b) which WERE filed (bottle Q09,
    ctd-cast Q27; calcofi_notes.md explicitly says "Provider questions filed: bottle Q09 …, ctd-cast
    Q27 …" — only those two). Q08 ("reorganized/duplicated CTD source folders … which copy is
    canonical") is a DIFFERENT, adjacent question (`dedup_ctd_raw`/workflows#52 heuristic, not the
    orig/uncorrected exclusion) — do not conflate. **Decision: file a NEW row Q28
    (`calcofi_ctd-cast_28`) documenting the orig*/uncorrected/separate_runs rule, filed already
    `answered`** (status=answered, answer = the rule + Rasmus's 2026-09-01 confirmation,
    answered_date=2026-09-01, who=Rasmus Swalethorp), since the goal is "Rasmus's answers become
    registry facts" and there is nothing to promote otherwise. Mention this substitution explicitly in
    the hand-back (brief assumed a row existed; none did).
  - **(d)** codes 1/2 = use primary/secondary, confirm `measurement_qual.csv` agrees: **confirmed** —
    `metadata/measurement_qual.csv` already has `ctd,1,use_primary,...` / `ctd,2,use_secondary,...`
    documented and TRUE. The best-matching row is **Q09** ("How should sensor-level quality flags
    propagate onto the averaged canonical variables?", status `open`, priority `blocker`) — its context
    ALREADY says the code meaning was "CONFIRMED and explained 2026-08-01 by CTD Data Files.pdf", so
    Rasmus's (d) is an independent/external re-confirmation of the same fact, not new info. But Q09's
    real ask (the propagation POLICY — should canonical averages prefer the named sensor over
    averaging) is NOT resolved by that confirmation. **Decision: mark Q09 `answered`** per the brief's
    literal instruction (append Rasmus's 2026-09-01 confirmation to `answer`/`who`/`answered_date`),
    but the `answer` text should be honest that the propagation-policy implementation is a separate
    follow-on (do not silently drop that nuance). Considered splitting a new row for the propagation
    policy (mirroring how brief handles bottle Q09/P_qual) but the brief didn't explicitly ask for that
    split here — lean toward NOT inventing an extra row unless there's time; note the conflation in the
    hand-back either way.
  - **(e)** seafloor/GEBCO threshold question: **grepped "seafloor"/"gebco" across every questions.csv
    — ZERO matches anywhere.** None exists. Brief explicitly says "file one if none exists" for this
    one, so: **file new row Q29** (`calcofi_ctd-cast_29`), `status = proposed`, `priority` normal-ish,
    `proposed_answer` = "> 500 m or > 25% beyond the deepest neighbouring GEBCO cell earns a
    questions.csv row; everything else stays in the check_depth_vs_seafloor ratchet report only" (Q11
    threshold, per umbrella Decided). Leave `status = proposed` (asking Rasmus to confirm the
    threshold back — draft 3 already asks this literally: "does that sound right to you?").
- **`metadata/measurement_qual.csv`**: confirmed ctd code_set rows 0/1/2/8/9 already documented
  correctly (use_primary/use_secondary at 1/2) — no edit needed there, just cite it as evidence in Q09.
- **`metadata/measurement_type.csv`** r_* rows confirmed: `r_ammonium`, `r_depth`, `r_dynamic_height`,
  `r_oxygen_umol_kg`, `r_salinity_sva`, `r_temperature` — all `is_canonical = "TRUE"` (stored as the
  literal string "TRUE"/"FALSE" in this CSV), `derivation` empty, `variable` already empty for all six
  (so the WS-G item-2 release gate "no r_* may carry a variable" should currently pass with 0
  violations — good, still add the `stopifnot()` gate per the brief). Column order: measurement_type,
  description, units, valid_min, valid_max, valid_depth_min_m, valid_depth_max_m, derivation,
  is_canonical, _source_column, _source_table, _source_datasets, _qual_column, _prec_column, grain,
  denominator, category, variable.
- **`calcofi4db::declare_measurement_fields()`** (installed version 3.28.0; source at
  `../calcofi4db/R/registry.R` lines 330–393): currently only accepts `category`/`variable` — hardcoded
  `cols <- intersect(c("category", "variable"), names(fields))` and later
  `for (cl in c("category", "variable")) if (!cl %in% names(d)) d[[cl]] <- NA_character_`. **Needs a
  small package change**: generalize to also accept `derivation` (character) and `is_canonical`
  (currently stored as literal "TRUE"/"FALSE" strings in the CSV — read as character by
  `read_measurement_type()`, so treat as character like `category`/`variable`, not logical, to avoid
  a round-trip type mismatch). Plan: change the two hardcoded vectors from `c("category", "variable")`
  to a parameter or an expanded literal `c("category", "variable", "derivation", "is_canonical")`,
  update roxygen docs, and add a testthat case in `tests/testthat/test-registry.R` (check what test
  file already covers `declare_measurement_fields`/`declare_measurement_bounds` for the pattern to
  mirror). **This package change has NOT been started** — no `../calcofi4db-ws-dg` worktree created
  yet. Per rules of engagement: `git -C ../calcofi4db worktree add ../calcofi4db-ws-dg -b ws-dg`, edit,
  add test, `devtools::test()`, but do NOT bump DESCRIPTION version and do NOT install.
- **`libs/pg_ctd.R`** + `server/postgis/init/40_ctd.sql` + `server/scripts/pg_flag_snapshot.R` fully
  read to understand the flag_accepted.parquet schema and the exact join-key convention:
  - `flag_accepted.parquet` columns (from `pg_flag_snapshot.R`'s SELECT): `flag_id, archive, path,
    study, cruise_key, data_stage, cast_dir, row_num, cast_id, depth, date_time_utc, variable,
    qual_code, qual_label, is_bad, proposed_value, rule_key, reason, status, created_by, created_at,
    reviewed_by, reviewed_at, review_note`. `variable` is a `ctd.scan` **column name** (lowercase
    source header, e.g. `salt1_corr`, `ox1um_stacorr`) — NOT a `measurement_type` name.
  - **Crosswalk exists**: `metadata/measurement_type.csv`'s `_source_column` for rows where
    `_source_datasets` contains `calcofi_ctd-cast` gives exactly this PG `variable` → `measurement_type`
    mapping (e.g. `salt1_corr` → `salinity_1_corr`, `ox1` → `oxygen_ml_l_1`). Already dumped the full
    ~52-row mapping in this session (visible in transcript, not re-saved to a file — cheap to
    regenerate with `python3 -c "..."` over the CSV, already run once).
  - **archive/path identity**: PG's `ctd.file.archive` = the zip filename (e.g.
    `20-1104SH_CTDFinalQC.zip`), `ctd.file.path` = the member path inside the zip, e.g.
    `20-1104SH_CTDFinalQC/db_csvs/separate_runs/20-1104SH_CTDBTL_031-035ID.csv`. Confirmed exact
    equivalence with the ingest's own convention: `libs/pg_ctd.R::pg_ctd_discover_files()` derives
    `archive = paste0(dir_unzip, ".zip")` and `path = rel` (relative to `dir_ext`) — this is BYTE
    IDENTICAL to what `ingest_calcofi_ctd-cast.qmd`'s `d_csv` chunk (~line 838) computes as
    `path_unzip` (renamed `_source_file` at ~line 1210). So `archive` can be reconstructed in the
    ingest as `paste0(str_extract(`_source_file`, "^[^/]+"), ".zip")` and joined directly to the
    snapshot's `archive` + `path` (`path` == `_source_file` exactly).
  - **Row-level identity problem**: `_source_file` is retained on `ctd_raw` (kept through dedup at
    ~line 1728–1763) but is EXPLICITLY DROPPED when `ctd_cast`/`ctd_measurement` are built — see
    `cast_cols <- setdiff(raw_cols, c(meas_cols, qual_cols, "depth_m", "_source_file"))` at ~line
    2027–2030, and the `ctd_measurement` pivot (~line 2187–2231) reads only from `ctd_raw` and carries
    forward only `ctd_cast_uuid, depth_m, measurement_type, measurement_value, measurement_qual,
    ctd_measurement_uuid, cruise_key` — no `_source_file`. **Therefore the new chunk MUST operate on
    `ctd_raw` directly, before the `ctd_measurement` pivot**, i.e. inserted between "## De-duplicate
    ctd_raw" (ends ~line 1763, `_source_file` finalized by dedup) / "## Save Checkpoint" (ends ~1949)
    and "## Measurement Column Registry" (~1951) / "## Split into Tidy Tables" → "### ctd_measurement"
    pivot (~2073–2333). Concretely: **new `## Apply Accepted QC Flags` section right after "## Save
    Checkpoint" (line 1949) and before "## Measurement Column Registry" (line 1951)** — this is late
    enough that `ctd_raw` is fully deduped/keyed (cruise_key resolved, ship_key validated) and early
    enough to land before the qual columns (`temp1q`, `salt1q`, `ox1q`, …) are read into the pivot, so
    setting/overriding those raw `*Q` columns on `ctd_raw` flows straight through into
    `ctd_measurement.measurement_qual` via the existing `qual_expr` logic (~line 2206–2210) with NO
    other code change needed downstream.
  - **Row-level join key** (since `row_num` from the source CSV line order does not survive dedup /
    resorting in `d_bind`): use **`(archive, path=_source_file, cast_id, depth)`** — `cast_id` and
    `depth` (`= depth_m` after rename, need to confirm exact column name on `ctd_raw`: brief/context
    calls it `depth_m`; PG's snapshot calls it `depth` — check `ctd_raw`'s actual column name before
    writing the chunk, likely `depth_m` given dedup_key uses `depth_m`) are intrinsic identifiers of a
    physical scan and survive dedup, unlike a raw line-order artifact. Assert the joined match is
    1:1 (no fan-out) as a light extra safety check beyond the brief's literal ask.
  - `variable` needs mapping via the `_source_column` crosswalk to know WHICH `*_qual` column on
    `ctd_raw` to update (e.g. PG `variable = "salt1_corr"` → measurement_type `salinity_1_corr` — but
    note `salinity_1_corr` has **no** `_qual_column` in the registry dump above (blank) — only the
    *_1/*_2 uncorrected sensor types (`salinity_1`, `oxygen_ml_l_1`, etc.) and a handful of others carry
    a `_qual_column` (`salt1q`, `ox1q`, `temp1q`, `temp2q`, `sig_theta_ts1q`, `sig_theta_ts1q`, `fluor_q`,
    `isusq`, `p_hq`, `pr_q`, `parq`). A flag on a **_corr/_cruisecorr/_stacorr/*Ave* derived variable
    that has no qual column of its own** cannot be written back onto `ctd_raw` as a `*Q` column update
    (there isn't one) — for those, the chunk must instead join directly against the pivoted
    `ctd_measurement.measurement_qual` (post-pivot) rather than `ctd_raw`. **This means the single
    "operate on ctd_raw before pivot" plan is insufficient for every `variable` — need a hybrid: for
    PG variables that map to a `_source_column` WITH a `_qual_column`, update `ctd_raw`'s `*Q` column
    (flows through the pivot); for PG variables that map to a `_source_column` WITH NO qual column
    (derived/averaged types), the new chunk must run a SECOND, later pass directly against
    `ctd_measurement.measurement_qual` after the pivot (i.e., split the new chunk into two pieces, or
    just do the whole thing post-pivot against `ctd_measurement` uniformly for simplicity — the
    ADVANTAGE of doing it uniformly post-pivot is one code path instead of two, at the cost of needing
    a `_source_file`-preserving join column reintroduced onto `ctd_measurement`.** **RECOMMENDATION for
    next resumption: prefer the single uniform post-pivot approach** — carry `_source_file` (and
    `cast_id`) through into `ctd_measurement` as an extra column (added to the `SELECT` in the pivot
    loop just like `cruise_key` already is added after the fact via the `UPDATE ... FROM ctd_cast`
    pattern at ~line 2310–2321), OR simpler: keep a side table `ctd_raw_keys` (ctd_cast_uuid,
    depth_m, `_source_file`) built once before the pivot and joined into the new flag-application
    chunk placed AFTER the `ctd_measurement` pivot (so both `ctd_cast_uuid`+`depth_m`→`_source_file`
    and `measurement_type`→`_source_column` crosswalks are available together, one clean join,
    updating `ctd_measurement.measurement_qual` directly by `(measurement_type, ctd_cast_uuid,
    depth_m)` matched via `_source_file`+`cast_id`+`depth` -> archive/path). This avoids the two-path
    split. **Not yet written — this is the design to implement next.**
- **`release_database.qmd`**: not yet located the exact "measurement_type load" chunk to add the
  r_*-no-variable `stopifnot()` gate, nor the insertion point for the new `qc_flags_pending` chunk.
  Note: this file was touched by another already-merged commit (spatial_layers/seafloor stuff, lines
  ~808–835 and ~1500–1520 and ~1860 and ~2072) — unrelated to WS-DG, already fast-forwarded in, do not
  revert it.
- **Server cron check (item D3)**: NOT YET RUN. Need `ssh calcofi 'crontab -l; ls -l /share/logs | tail'`
  (read-only). Not attempted yet this session.
- **Bottle notebook report fix (item G4)**: NOT YET LOCATED. Need to find chunk `derive_cruise_key` in
  `ingest_calcofi_bottle.qmd` (1708 lines total, not yet opened this session) and fix the DOUBLE-vs-
  integer YYYYMM comparison bug (684 rows shown today → should show 14 genuine cruises / 829 casts).
  Also need to pull the actual 14-cruise table + ship names from the last **rendered** HTML's widget
  JSON per the brief ("Reproduce the 14-row table from the rendered HTML's widget JSON") — need to find
  `_output/ingest_calcofi_bottle.html` (or similar) and extract the DataTables JSON, then join to the
  `ship` table (need `calcofi4r::cc_get_db("v2026.08.25")` — installed per the umbrella's WS-DG note) to
  get ship names for the draft-3 email table.
- **QC finding for Ben G (item G3)**: NOT YET WRITTEN. Needs release SQL (no ingest render) — bottle
  casts where every `temperature` value is flagged 8/9 AND `r_temperature` rows exist for that cast;
  count + `cruise_key`/`cast` list. Plan: use `calcofi4r::cc_get_db("v2026.08.25")` (installed) against
  the promoted release, per the brief.
- **`n_flags_pending` chunk (item D2)**: NOT YET WRITTEN. Small `release_database.qmd` chunk: rows in
  snapshot minus rows the `calcofi_ctd-cast` shard reflects (via `metadata.json`'s
  `n_flags_applied` — need to check whether `build_metadata_json()` already supports arbitrary extra
  fields, or whether that needs a small addition too — NOT YET CHECKED).
- Explored `explore/src/variables.ts`, `explore/sql/section*.sql`, ctd-transects SQL for `r_` usage per
  WS-G item 2 — **NOT YET DONE** (no `../explore` or `../ctd-transects` repo access attempted this
  session).

## Next step (resume here)

1. Re-verify current time / laptop online, `cd` into the worktree, `git status` (should still be clean,
   nothing committed).
2. Decide + implement the CTD flag-application chunk design (see "RECOMMENDATION" above: single
   post-pivot join against `ctd_measurement`, carrying `_source_file`+`cast_id`+`depth_m` through the
   pivot via a small keys side-table). Insert as new `## Apply Accepted CTD QC Flags` section
   (chunk label `apply_accepted_flags`) — best insertion point is **after the `ctd_measurement`
   Sentinel/bounds/UUID/orphan-removal block ends (~line 2333, right before "### ctd_summary")**, since
   that is the true "per-cast [and per-scan] staging" endpoint and it is unambiguously "before
   `write_parquet_outputs()`" (~line 3674). Confirm exact `depth_m` column name on `ctd_raw`/
   `ctd_measurement` before writing SQL (dedup_key already told us `ctd_raw` has `depth_m`;
   `ctd_measurement` pivot SELECTs `depth_m` directly too — so column name is confirmed `depth_m`
   throughout, good).
3. Write the download-first fetch (size/etag-compare skip logic) into `data/cache/ctd-cast/
   flag_accepted.parquet`, from `https://storage.googleapis.com/calcofi-db/qc/ctd/flag_accepted.parquet`.
   Print `n flags · n scans affected · n unmatched` with `stop()` on any unmatched flag; zero-flags
   message: `"0 accepted flags in snapshot (last modified …)"` using the HTTP Last-Modified header or
   GCS object metadata (check what's easiest via `httr`/`curl` already used elsewhere in this repo —
   grep for an existing download-with-skip-if-unchanged helper before writing a new one; the brief's
   "download-first … skip when unchanged: compare size/etag" strongly implies a helper already exists
   somewhere in this repo or calcofi4db — CHECK `calcofi4db::download_and_unzip` neighbors / any
   `download_if_changed()`-style helper before hand-rolling).
4. Add `RELEASES.md # Unreleased` entry ONLY IF the chunk would apply ≥ 1 flag when run (it will not,
   since the snapshot is 0 rows today) — so per the brief, **no RELEASES.md entry from item D1 this
   round**. Do NOT skip the entry required by WS-G item 5 though (the r_* interpolation registry
   change) — that DOES get a `# Unreleased` entry regardless.
5. `release_database.qmd`: locate the `measurement_type` load chunk (grep `read_measurement_type\(here\(` or
   similar) and add the `stopifnot()` gate that no `r_*` type carries a non-empty `variable`. Add the
   `qc_flags_pending` chunk (warn-only) somewhere sensible near other QC/report chunks — reads the same
   snapshot parquet + `calcofi_ctd-cast`'s `metadata.json` `n_flags_applied` (need that field added to
   `build_metadata_json()` output by the ingest chunk in step 2, or computed separately).
6. File the `metadata/calcofi/bottle/questions.csv` Q09 answer (item G-a): status `proposed` →
   `answered`, `answer` = Rasmus's verbatim (a) text, `answered_date=2026-09-01`,
   `who=Rasmus Swalethorp`; leave the P_qual half open per the brief (consider whether Q09 needs
   splitting — brief explicitly allows it: "split it into its own row if Q09 conflates them" — Q09's
   `related_field` is `O_qual;P_qual;R_Oxy_umol/Kg`, and its question conflates R_* inheritance (now
   answered) with the P_qual meaning (still open) — SHOULD split: create bottle Q10-ish new row for the
   P_qual-only question, next free label in bottle's questions.csv — check its max label first, was not
   checked this session). Also append Rasmus's confirmation as related context to bottle Q05.
7. File ctd-cast Q27 → `answered` (item G-b), Q09 → `answered` with caveat (item G-d), file new Q28
   (item G-c, "answered" from creation) and Q29 (item G-e, "proposed" from creation) as planned above —
   **use R (`calcofi4db::read_questions()` to validate + `readr::write_csv(..., na = "")` to write,
   never a bare edit)** since `read_questions()` is installed (v3.28.0) and validates vocabulary/label
   format immediately — much safer than hand-editing the CSV text. There is no `write`/`append` helper
   in `calcofi4db::questions.R` (checked — only `read_questions()`/`questions_datatable()` exist), so
   direct `dplyr::bind_rows()` + `readr::write_csv(d, path, na = "")` is correct and matches the
   package's own documented pattern for this file type; re-read with `read_questions()` immediately
   after to self-validate (mirrors `register_measurement_types()`'s "write, re-read, validate" idiom).
8. The `declare_measurement_fields()` package change (see "Done" above) — create
   `../calcofi4db-ws-dg` worktree, generalize `cols <- intersect(c("category","variable"), names(fields))`
   (registry.R ~line 361) and the `for (cl in c("category","variable"))` default-column-creation loop
   (~line 374) to also cover `derivation`/`is_canonical`, update roxygen `@param fields`, add a
   testthat case (find `tests/testthat/test-registry.R`, mirror the existing
   `declare_measurement_fields` test), `devtools::test()` (NOT `devtools::install()`). Then use the
   local worktree's function (via `devtools::load_all("../calcofi4db-ws-dg")` or by sourcing) — or, if
   time-constrained, just call `declare_measurement_fields()` from the INSTALLED 3.28.0 package for the
   `category`/`variable`-shaped columns it already supports and note in the hand-back that
   `derivation`/`is_canonical` still need the package change before the ingest can call it too (i.e.
   for THIS round it's fine to write `metadata/measurement_type.csv`'s `derivation`/`is_canonical`
   columns via a small one-off R script that mimics exactly what the generalized
   `declare_measurement_fields()` will do, PROVIDED the package change is still made and tested in the
   worktree per the brief's explicit instruction "never a bare write_csv()" — the one-off script must
   still go through the same read/write/na="" discipline, ideally by literally calling the
   worktree's patched function via `devtools::load_all()`, not by hand-rolling the CSV mutation
   separately, to avoid the two implementations drifting).
9. Set the six `r_*` rows' `derivation` and `is_canonical = FALSE` via the (now-generalized)
   `declare_measurement_fields()`.
10. `RELEASES.md # Unreleased`: add the "bottle's reported (r_*) series are interpolated" entry with a
    `**Consumers:**` line (WS-G item 5).
11. Fix `ingest_calcofi_bottle.qmd`'s `derive_cruise_key` chunk (item G4) — NOT YET LOCATED, open the
    file and grep `derive_cruise_key`.
12. Extract the 14-cruise/829-cast table + ship names from the rendered bottle HTML's widget JSON (or,
    if that HTML predates the fix and still shows 684, may need to reconstruct the 14-row table
    directly via a one-off DuckDB/R query over the release parquet rather than trusting stale HTML —
    reconsider at resume time) and finish Draft 3 in the email-drafts file (only the "I'll send the 14
    as a table" sentence needs the actual table appended).
13. QC finding for Ben G (item G3) via `calcofi4r::cc_get_db("v2026.08.25")`.
14. Server cron check via `ssh calcofi` (read-only).
15. Grep `explore/src/variables.ts`, `explore/sql/section*.sql`, ctd-transects SQL for `r_` usage
    (report only, per WS-G item 2).
16. Commit everything on `ws-dg` (workflows) and `ws-dg` (calcofi4db worktree, if created), following
    the CLAUDE.md attribution footer (Co-Authored-By + Claude-Session line) from the system reminder at
    the top of this task.
17. Hand back per the brief's "Hand back" section + the rules of engagement's standard hand-back list.

## Open questions for whoever resumes (not yet escalated to Ben — flag in final hand-back too)

- Whether Q09 (ctd-cast, codes-1/2) should be split like bottle Q09 is being split for P_qual, since
  its `answered` status per the brief's literal instruction leaves the propagation-policy question
  (should canonical averages prefer the named sensor) formally closed even though nothing implements
  that yet. Leaning toward: mark `answered` per brief, but write the `answer` text to explicitly carve
  out the propagation-policy as still-open follow-on work (not a new row) — cheapest way to honor both
  "the brief is the spec" (answered) and honesty (don't silently drop the real unresolved part).
- Whether filing brand-new Q28/Q29 (rather than "the question" the brief presumed existed) needs a Ben
  check-in — decided NOT to stop-and-report over this, since it's squarely "make the reasonable call
  and keep going" territory (documenting Rasmus's answers as registry facts is the explicit goal of the
  workstream, and the alternative — silently dropping (c) and (e) because no pre-existing row exists —
  defeats that goal more than filing new rows would misrepresent anything). State this clearly in the
  hand-back so Ben can override if he disagrees.
