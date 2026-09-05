# WS-DG · CTD accepted flags reach the ingest (written, not run); Rasmus's answers a–f become registry facts and one measured reply

**Agent:** Sonnet · high. **Wave 1**, worktree in `workflows` (one small calcofi4db helper may be needed —
hand it to the integrator rather than bumping). **No CTD or bottle ingest run** (umbrella § *Avoiding the
CTD ingest*).
**Plan:** umbrella § *The ask › 3*, § *Context › Rasmus's answers*, § *WS-D*, § *WS-G*; Q7/Q8/Q10/Q11.

## D · the flag chunk

1. `ingest_calcofi_ctd-cast.qmd`: after the per-cast staging and before `write_parquet_outputs()`, a
   chunk `apply_accepted_flags`: download-first
   `https://storage.googleapis.com/calcofi-db/qc/ctd/flag_accepted.parquet` → `data/cache/ctd-cast/`
   (skip when unchanged: compare size/etag), read the ledger's key columns (see `libs/pg_ctd.R` and
   `CalCOFI/server postgis/init/*.sql` for `ctd.flag`: `(archive, path, scan…)` + IODE code), join to
   the staged scans, set `measurement_qual` where a flag is `accepted`, print `n flags · n scans
   affected · n unmatched` (unmatched ⇒ `stop()`, a flag that finds no scan is a broken bridge). Zero
   flags prints "0 accepted flags in snapshot (last modified …)". Document that the chunk first runs at
   the next CTD ingest (`RELEASES.md` only when it has applied ≥ 1 flag).
2. `release_database.qmd`: a small `qc_flags_pending` chunk — rows in the snapshot minus rows the
   `calcofi_ctd-cast` shard reflects (the ingest writes `n_flags_applied` into its `metadata.json`);
   `cat()` + `datatable()`, **warn only**.
3. Read-only check that the server cron (`pg_flag_snapshot.sh`) is alive: the snapshot is 600 B, last
   modified 2026-08-19. `ssh calcofi 'crontab -l; ls -l /share/logs | tail'` — report, do not fix.

## G · Rasmus's answers (2026-09-01) into the registries

Verbatim answers are in the umbrella § *The ask › 3*. File each with `answered_date = 2026-09-01`,
`who = Rasmus Swalethorp`, using the `read_questions()` vocabulary:

- (a) `metadata/calcofi/bottle/questions.csv` **Q09** → `answered` (no inherited codes; interpolated to
  standard depths; a bad depth should have been skipped by decodr; a cast whose `T_degC` are all bad
  should have no `R_Temp`; never interpolate from `R_*`). The `P_qual` half stays **open** for Ben G —
  split it into its own row if Q09 conflates them. **Q05** (r_ammonium) gains the same context.
- (b) `metadata/calcofi/ctd-cast/questions.csv` **Q27** → `answered`, keep excluding.
- (c) find the question on `orig*` / `uncorrected/` / `separate_runs/` (grep `separate_runs`); →
  `answered`: superseded exports excluded; `separate_runs/` stays (inside FinalQC, not a superseded copy).
- (d) find the codes-1/2 question → `answered`; confirm `metadata/measurement_qual.csv` says the same.
- (e) the seafloor rows (grep `seafloor` / `GEBCO` in every `questions.csv`; file one if none exists) →
  `proposed` with Q11's threshold; the ratchet stays report-only.
- (f) answered by the measurement below.

Then:

1. **`r_*` types** (`r_ammonium`, `r_depth`, `r_dynamic_height`, `r_oxygen_umol_kg`, `r_salinity_sva`,
   `r_temperature` — all `is_canonical = TRUE`, empty `derivation`): set `derivation` = "reported value
   interpolated to standard depth (pre-QC, decodr); carries no quality code by design; not an input for
   further interpolation" and `is_canonical` per Q10. Use `calcofi4db::declare_measurement_fields()` if it
   accepts these columns; if not, add the two columns to it (a small package change for the integrator)
   — never a bare `write_csv()`.
2. A release gate in `release_database.qmd` next to the `measurement_type` load: no `r_*` type may carry
   a `variable`; `stopifnot()`. Grep `explore/src/variables.ts`, `explore/sql/section*.sql`,
   `ctd-transects` SQL for `r_` — report.
3. **QC finding for Ben G** (release SQL, no ingest): bottle casts where every `temperature` value is
   flagged 8/9 and `r_temperature` rows exist — count, list of `cruise_key`/`cast`.
4. **Fix the bottle notebook's report** (`ingest_calcofi_bottle.qmd`, chunk `derive_cruise_key`): compare
   `CAST(cruise AS INTEGER)` (or `printf('%06d')`) to the key's `YYYYMM`, not the DOUBLE's string — 684
   rows shown today, 14 genuine. Edit only; it renders at the next bottle run. Reproduce the 14-row
   table from the rendered HTML's widget JSON (the umbrella lists them) joined to `ship` for names, and
   put it in the Rasmus draft.
5. `RELEASES.md # Unreleased`: "The bottle's reported (`r_*`) series are interpolated, and say so" —
   registry-only change, `**Consumers:**` `is_canonical` flips if Q10 says so.

## Hand back

The questions.csv diffs, the `r_*` registry diff, the `n_flags_pending` chunk output on the current
snapshot (0), the cron status, the QC-finding count, and the finished Rasmus reply with the 14 cruises
and ship names filled in.
