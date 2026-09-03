# WS-B · Provider UUIDs — Ed Weber's ask; `cruise_uuid`, `sample.source_uuid`, the station crosswalk, a `cruise_key` integrity gate

**Agent:** Fable 5.1 · xhigh for the design memo, the spike and the reply (Wave 1); Sonnet · high for the
implementation after Ben answers Q5 (Wave 2; **calcofi4db 3.31.0**, after A0). Worktrees in `calcofi4db`
+ `workflows`.
**Plan:** umbrella § *The ask › 2*, § *Context › UUIDs*, § *Decisions › WS-B*; the reply draft in
`2026-09-03 Email drafts — …md` (refine it with the spike's numbers).

## Read first

- CLAUDE.md § "`cruise_key` is the cruise's designated month, resolved by date span" and § "Namespaced
  keys"; `docs/db.qmd` (key suffix conventions; "avoid UUIDs in output tables… `_source_uuid` stripped");
  `.claude/plans/2026-08-13 Task 12 naming conventions — …md` rows 31–33 (the `_source_*` leak).
- `ingest_swfsc_ichthyo.qmd` §§ UUID-first (l.235–260, 766–802) and emit-core (l.1395–1470: `ns_key()`
  embeds the UUID in `sample_key`); `calcofi4db::append_sample()` (15/16-column positional contract;
  add a 17th the same way `data_stage` was added); `resolve_cruise_key()`; `match_by_site_datetime()`
  / `match_nearest_by_depth()`; bottle emit-core (l.1425–1525) and the crab's `parent_sample_key` link
  to the ichthyo site row (`ingest_cdfw_dungeness-crab.qmd` l.670–690).
- `release_database.qmd`: `derived_tables <- "cruise"` (~l.1583), `core_single` / `gcs_prefix = NA`
  (CLAUDE.md: anything rebuilt in `con_wdl` must be in BOTH), `check_core_pk_unique()` (~l.1038),
  the freeze's `strip_provenance`.
- Memory `project_uuid_primary_keys` (why each table keys differently) and
  `project_identifier_standardization`.

## Phase 1 — design memo + spike (Fable)

1. Measure on the promoted release (`calcofi4r::cc_get_db("v2026.08.25")`): for root samples of
   `calcofi_bottle`, `calcofi_ctd-cast`, `sio_pic-zooplankton`, `calcofi_dic`, `cdfw_dungeness-crab`
   (already linked), `calcofi_mets` (underway: expect none) — how many match **exactly one** ichthyo
   `site` sample on `(cruise_key, site_key, order_occ)`; with `order_occ` NULL, on `(cruise_key,
   site_key)` + nearest datetime within 1 day; how many match none; how many are ambiguous. Report the
   table by dataset and decade.
2. Confirm the `cruise` shard/release columns and that `_source_*` reach the published parquet.
3. Write the memo as the *Decided* input for Q5: the three recommendations (no re-keying; `source_uuid`
   + documented `cruise_uuid`; `station_uuid` in the release if the spike is clean) with the numbers, and
   the integrity gate's exact SQL. Refine the reply to Ed with the numbers (keep it under 300 words).

## Phase 2 — implementation (Sonnet, after Q5)

1. `append_sample()`: optional trailing `source_uuid` (UUID; 17th column; NULL when absent) with the same
   DESCRIBE-arity guard; `.ensure_sample_schema()` adds the column; tests for 15/16/17.
2. Ichthyo arms pass `site_uuid` / `tow_uuid` / `net_uuid`; the `stopifnot()` block asserts
   `COUNT(source_uuid) = COUNT(*)` for the three grains.
3. `check_cruise_key_integrity(con)` → rows where (a) a sample with `source_uuid` has a `cruise_key` ≠ the
   `cruise` row reached through its ichthyo `site.cruise_uuid`, (b) `substr(cruise_key,1,7)` ≠
   `strftime(date_min,'%Y-%m')`… **no** — (b) is the *designated* month, which may differ from
   `date_min`'s month by design (5508BD); assert instead that the NODC part equals `ship_key`'s NODC and
   that `date_min ≤ … ≤ date_max` holds for every event keyed to the cruise. **Fails the release** in a
   new chunk after `check_core_pk_unique()`.
4. Strip `_source_uuid`, `_source_file`, `_source_row`, `_ingested_at` from the released `cruise`
   (freeze `strip_provenance` or the `derived_tables` build); `field_dictionary.csv` rows for
   `cruise_uuid` (public join key to NOAA's db) and `source_uuid`.
5. If approved: `match_station_occupation(con)` in the release stamps `sample.station_uuid`; a
   `station_uuid_method` column says how (`exact`, `nearest_datetime`); ambiguous ⇒ NULL, counted.
6. `RELEASES.md # Unreleased`: "The provider's own identifiers are columns, and the cruise key is
   checked against the cruise" — `**Consumers:**` additive. CLAUDE.md § keys; `docs/db.qmd` § keys
   (replace the "stripped" sentence with what is true).

## Gates

`devtools::test()` green; ichthyo re-render shows `source_uuid` populated; `check_cruise_key_integrity()`
returns zero rows on the current data (if not, the rows are findings for the reply, not something to
"fix" here); the release still passes `check_core_pk_unique()`.

## Do not

Re-key any table; mint UUID v5 for datasets without a source UUID; change `sample_key`; re-parent
bottle/CTD casts under ichthyo sites; send the email (Ben sends).
