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

## Measured (Phase 1 spike, Sonnet)

**Scope of this pass:** measurements only (Phase 1 items 1–2, plus the two extra checks the
coordinator asked for — the `site.cruise_uuid` reconciliation and a runnable
`check_cruise_key_integrity()`). No design memo, no reply text, no implementation — that is for
the model assigned Phase 1's memo / Phase 2's code. Connection: `calcofi4r::cc_get_db("v2026.08.25")`
(read-only, cached local copy of the promoted release), plus two **local, read-only** files never
modified: `/Users/bbest/Github/CalCOFI/workflows/data/wrangling/swfsc_ichthyo.duckdb` (the
persisted wrangling DB from the 2026-08-25 ichthyo render — opened `read_only = TRUE`) and
`/Users/bbest/_big/calcofi/parquet/swfsc_ichthyo/*.parquet` (the staged shard). All SQL below was
run once, verbatim, on 2026-09-03.

### 1. Root-sample → ichthyo `site` match, by dataset × decade

**Method.** For each dataset's root samples (`sample_key = root_sample_key`), classify against
`swfsc_ichthyo` `sample_type = 'site'` rows:
- `matched_order_occ` — exactly one ichthyo site shares `(cruise_key, site_key, order_occ)`
  (ichthyo's own triple is unique — 0 duplicate `(cruise_key, site_key, order_occ)` groups, but 471
  duplicate `(cruise_key, site_key)` groups without `order_occ`, so `order_occ` is load-bearing for
  disambiguation, not redundant).
- `matched_nearest_datetime` — no `order_occ` triple match, but exactly one ichthyo site shares
  `(cruise_key, site_key)` **and** its `datetime` is within 1 day.
- `ambiguous` — more than one ichthyo site shares `(cruise_key, site_key)` (the `> 1 candidate`
  reading of "ambiguous" — independent of whether the datetimes would later disambiguate).
- `no_match` — no ichthyo site shares `(cruise_key, site_key)` at all, or the sole candidate's
  `datetime` is more than 1 day away.

```sql
WITH root AS (
  SELECT sample_key, dataset_key, cruise_key, site_key, order_occ, datetime
  FROM sample
  WHERE sample_key = root_sample_key
    AND dataset_key IN ('calcofi_bottle','calcofi_ctd-cast','sio_pic-zooplankton',
                         'calcofi_dic','cdfw_dungeness-crab','calcofi_mets')
),
ich AS (
  SELECT sample_key AS ich_sample_key, cruise_key, site_key, order_occ, datetime
  FROM sample
  WHERE dataset_key = 'swfsc_ichthyo' AND sample_type = 'site'
),
triple AS (
  SELECT r.sample_key, count(*) AS n
  FROM root r JOIN ich i
    ON r.cruise_key = i.cruise_key AND r.site_key = i.site_key AND r.order_occ = i.order_occ
  WHERE r.order_occ IS NOT NULL
  GROUP BY r.sample_key
),
pair AS (
  SELECT r.sample_key,
         count(*) AS n_pair,
         min(abs(epoch(r.datetime) - epoch(i.datetime))) AS min_abs_diff_sec
  FROM root r JOIN ich i
    ON r.cruise_key = i.cruise_key AND r.site_key = i.site_key
  GROUP BY r.sample_key
)
SELECT r.dataset_key,
  CAST(FLOOR(EXTRACT(year FROM r.datetime)/10)*10 AS INT) AS decade,
  CASE
    WHEN t.n = 1 THEN 'matched_order_occ'
    WHEN COALESCE(t.n,0) = 0 AND COALESCE(p.n_pair,0) = 0 THEN 'no_match'
    WHEN COALESCE(t.n,0) = 0 AND p.n_pair = 1 AND p.min_abs_diff_sec <= 86400 THEN 'matched_nearest_datetime'
    WHEN COALESCE(t.n,0) = 0 AND p.n_pair = 1 AND (p.min_abs_diff_sec IS NULL OR p.min_abs_diff_sec > 86400) THEN 'no_match'
    WHEN COALESCE(t.n,0) = 0 AND p.n_pair > 1 THEN 'ambiguous'
    ELSE 'ambiguous'
  END AS match_status,
  count(*) n
FROM root r
LEFT JOIN triple t ON r.sample_key = t.sample_key
LEFT JOIN pair p ON r.sample_key = p.sample_key
GROUP BY 1,2,3
ORDER BY 1,2,3
```

**Result — by dataset × decade** (every row's total ties back to that dataset's root-sample count;
grand total 220,294 = 35,644 + 19,242 + 3,255 + 77,795 + 2,015 + 82,343):

| dataset_key | decade | matched_order_occ | matched_nearest_datetime | ambiguous | no_match | total |
|---|---|---:|---:|---:|---:|---:|
| calcofi_bottle | 1940 | 0 | 0 | 0 | 911 | 911 |
| calcofi_bottle | 1950 | 0 | 7949 | 50 | 2636 | 10635 |
| calcofi_bottle | 1960 | 0 | 4821 | 3 | 990 | 5814 |
| calcofi_bottle | 1970 | 0 | 3141 | 4 | 1275 | 4420 |
| calcofi_bottle | 1980 | 71 | 3067 | 42 | 1412 | 4592 |
| calcofi_bottle | 1990 | 1905 | 1011 | 1 | 49 | 2966 |
| calcofi_bottle | 2000 | 2702 | 71 | 0 | 127 | 2900 |
| calcofi_bottle | 2010 | 2719 | 11 | 0 | 304 | 3034 |
| calcofi_bottle | 2020 | 226 | 0 | 0 | 146 | 372 |
| calcofi_ctd-cast | 1990 | 3328 | 122 | 0 | 29 | 3479 |
| calcofi_ctd-cast | 2000 | 5576 | 163 | 2 | 160 | 5901 |
| calcofi_ctd-cast | 2010 | 5216 | 32 | 0 | 770 | 6018 |
| calcofi_ctd-cast | 2020 | 1013 | 0 | 0 | 2831 | 3844 |
| calcofi_dic | 1980 | 0 | 0 | 0 | 41 | 41 |
| calcofi_dic | 2000 | 0 | 0 | 0 | 244 | 244 |
| calcofi_dic | 2010 | 0 | 0 | 0 | 2775 | 2775 |
| calcofi_dic | 2020 | 0 | 0 | 0 | 195 | 195 |
| calcofi_mets | 2000 | 0 | 0 | 0 | 10435 | 10435 |
| calcofi_mets | 2010 | 0 | 0 | 0 | 49448 | 49448 |
| calcofi_mets | 2020 | 0 | 0 | 0 | 17912 | 17912 |
| cdfw_dungeness-crab | 1940 | 0 | 0 | 0 | 146 | 146 |
| cdfw_dungeness-crab | 1950 | 0 | 0 | 0 | 663 | 663 |
| cdfw_dungeness-crab | 1960 | 0 | 21 | 0 | 237 | 258 |
| cdfw_dungeness-crab | 1970 | 0 | 11 | 0 | 290 | 301 |
| cdfw_dungeness-crab | 1980 | 0 | 122 | 1 | 295 | 418 |
| cdfw_dungeness-crab | 1990 | 0 | 18 | 13 | 2 | 33 |
| cdfw_dungeness-crab | 2000 | 0 | 88 | 0 | 104 | 192 |
| cdfw_dungeness-crab | 2010 | 0 | 1 | 0 | 3 | 4 |
| sio_pic-zooplankton | 1930 | 0 | 0 | 0 | 33 | 33 |
| sio_pic-zooplankton | 1940 | 0 | 0 | 0 | 1590 | 1590 |
| sio_pic-zooplankton | 1950 | 0 | 5921 | 45 | 9829 | 15795 |
| sio_pic-zooplankton | 1960 | 0 | 6276 | 2 | 10516 | 16794 |
| sio_pic-zooplankton | 1970 | 0 | 2544 | 6 | 4061 | 6611 |
| sio_pic-zooplankton | 1980 | 0 | 11960 | 554 | 252 | 12766 |
| sio_pic-zooplankton | 1990 | 0 | 7322 | 19 | 90 | 7431 |
| sio_pic-zooplankton | 2000 | 0 | 10363 | 124 | 247 | 10734 |
| sio_pic-zooplankton | 2010 | 131 | 7915 | 98 | 1016 | 9160 |
| sio_pic-zooplankton | 2020 | 516 | 19 | 0 | 892 | 1427 |
| sio_pic-zooplankton | NA (no datetime, 2 rows) | 0 | 0 | 0 | 2 | 2 |

**Totals by dataset:**

| dataset_key | matched_order_occ | matched_nearest_datetime | ambiguous | no_match | total | % matched |
|---|---:|---:|---:|---:|---:|---:|
| calcofi_bottle | 7623 | 20071 | 100 | 7850 | 35644 | 77.7% |
| calcofi_ctd-cast | 15133 | 317 | 2 | 3790 | 19242 | 80.3% |
| calcofi_dic | 0 | 0 | 0 | 3255 | 3255 | **0.0%** |
| calcofi_mets | 0 | 0 | 0 | 77795 | 77795 | **0.0%** (expected — underway, no site occupation) |
| cdfw_dungeness-crab | 0 | 261 | 14 | 1740 | 2015 | 13.7% |
| sio_pic-zooplankton | 647 | 52320 | 848 | 28528 | 82343 | 64.3% |

**Grand totals:** `matched_order_occ` 23,403 · `matched_nearest_datetime` 72,969 · `ambiguous` 964 ·
`no_match` 122,958 — sum 220,294 (checked against `sum(root counts)`).

**Reading the numbers:**
- `calcofi_mets` is 100% `no_match` as the brief expected — its root samples never carry a
  `site_key` (`0`/`77,795` populated), so `calcofi_mets` cannot join on `(cruise_key, site_key)` at
  all; the spike measured this rather than assuming it.
- `calcofi_dic` is also 100% `no_match`, but for a **different and unexpected** reason: `cruise_key`
  is **entirely NULL** on all 3,255 DIC root samples (`sample.cruise_key` is `VARCHAR`, populated on
  every other dataset checked here, 0/3,255 populated for DIC). This is not "no candidate found" —
  it is "the join predicate itself is never satisfiable," since `NULL = NULL` is never true in SQL.
  `sample.datetime` for DIC also looks like a month-level proxy in a sample of 10 rows (`2015-01-01`,
  `2014-04-01`, `2012-03-01`, …, several exactly on the 1st of the month), consistent with the
  existing memory note that only ~24.7% of DIC rows match a bottle cast at all. **This is a gap
  worth its own `questions.csv` row / design-memo mention** — DIC's root samples have no `cruise_key`
  to check against `check_cruise_key_integrity()` in the first place.
- `cdfw_dungeness-crab`'s 13.7% match rate looks low next to bottle/CTD, but the brief's own context
  says the crab dataset is "already linked" via `parent_sample_key` → the ichthyo site row for its
  310 examined subsamples — a **different, already-built** linkage that this generic
  `(cruise_key, site_key, order_occ)` method does not see (most crab root samples here are the 1,795
  sorting-log tows, most of which predate ichthyo's own UUID-keyed site table or were never
  co-occupied with an ichthyo net). Do not read 13.7% as "the crab link is weak" — it is measuring a
  different, complementary path.
- `sio_pic-zooplankton`'s `ambiguous` count is concentrated in 1980 (554 of 848) and 2000s (124+98) —
  worth a look before trusting `station_uuid` there without a tiebreak (nearest-depth or similar).

### 2. Released `cruise` table — columns, provenance leak, `cruise_uuid` coverage

```sql
DESCRIBE cruise;
SELECT count(*) n_total, count(cruise_uuid) n_uuid FROM cruise;
```

**`DESCRIBE cruise`** (14 columns): `cruise_uuid UUID`, `date_ym DATE`, `ship_key VARCHAR`,
`cruise_key VARCHAR`, `date_min DATE`, `date_max DATE`, `year INTEGER`, `month INTEGER`,
`ship_name VARCHAR`, `ship_nodc VARCHAR`, `ichthyo BIGINT`, `bottle BIGINT`, `ctd_cast BIGINT`,
`dic BIGINT`.

**`_source_uuid` / `_source_file` / `_source_row` / `_ingested_at`: NOT present** on the released
`cruise` table (all four `FALSE`). This contradicts the umbrella plan's § *Context › UUIDs* claim
that the release "leaks `_source_uuid`/`_source_file`/`_source_row`/`_ingested_at`" — as of
**v2026.08.25**, checked directly against the promoted release, they are already absent. (They
*are* present on the ichthyo ingest's own **wrangling** `cruise` table — see below — so the leak the
umbrella plan describes is real somewhere upstream of, or before, this release's freeze step; it
just is not observable in the v2026.08.25 published bytes. Phase 2 item 4 should re-check this
against whatever release the umbrella plan's authors actually looked at, or treat it as already
fixed for `cruise` and confirm no other released table carries these columns.)

**`cruise_uuid` coverage:** `n_total = 691`, `n_uuid = 691` — **100% populated**, 691/691 distinct.

### 3. `swfsc_ichthyo` `site.cruise_key` vs. the cruise row reached through `site.cruise_uuid`

**This could not be computed as literally specified, and that is itself the finding.**
`site.cruise_uuid` does not exist as a column in either artifact checked:

```sql
-- against /Users/bbest/_big/calcofi/parquet/swfsc_ichthyo/sample.parquet (the staged shard;
-- site/tow/net are one file, no separate site.parquet)
DESCRIBE SELECT * FROM read_parquet('/Users/bbest/_big/calcofi/parquet/swfsc_ichthyo/sample.parquet');
-- 17 columns: sample_key, sample_type, parent_sample_key, root_sample_key, dataset_key, grid_key,
-- site_key, cruise_key, order_occ, latitude, longitude, datetime, depth_min_m, depth_max_m,
-- tow_type, data_stage, geom — no cruise_uuid

-- against the persisted wrangling DB (read_only), which still has a separate `site` table:
-- duckdb::duckdb(dbdir=".../data/wrangling/swfsc_ichthyo.duckdb", read_only = TRUE)
DESCRIBE site;
-- 8 columns: site_uuid, order_occ, longitude, latitude, cruise_key, geom, grid_key, site_key —
-- no cruise_uuid here either
SELECT table_name, column_name FROM information_schema.columns WHERE lower(column_name) LIKE '%cruis%';
-- cruise.cruise_key, cruise.cruise_uuid, obs.cruise_key, sample.cruise_key, segment.cruise_key,
-- site.cruise_key  -- cruise_uuid exists ONLY on the cruise table itself, nowhere downstream
```

**Why:** `metadata/swfsc/ichthyo/flds_redefine.csv` maps the raw `station.cruise_id` column to
`cruise_uuid` at load time, and `ingest_swfsc_ichthyo.qmd` (l.301–308) calls
`calcofi4db::propagate_natural_key(child_tbl="site", parent_tbl="cruise", key_col="cruise_key",
join_col="cruise_uuid")` right after `create_cruise_key()` — its printed preview at l.311–315
(`select(site_uuid, cruise_uuid, cruise_key, order_occ)`) confirms `site.cruise_uuid` exists **at
that point in the render**. `propagate_natural_key()`'s source (checked directly,
`calcofi4db 3.28.0`) does an `UPDATE site SET cruise_key = (SELECT cruise.cruise_key FROM cruise
WHERE cruise.cruise_uuid = site.cruise_uuid)` and never drops any column — so the column is not
removed by that helper. No later step in the notebook (`ALTER TABLE ... DROP COLUMN`, a
`CREATE OR REPLACE TABLE site AS SELECT <narrower list>`, etc.) is visible via `grep`, and no
package function called on `site` between there and the emit-core section (`add_point_geom`,
`assign_grid_key`) touches columns generically. **Root cause not determined — out of scope for a
read-only spike** — but the practical fact stands: by the time a notebook finishes and the shard is
staged, `site`/`sample` carry only the already-resolved `cruise_key`, not the `cruise_uuid` that
produced it.

**Consequence for Phase 2 item 3(a):** `check_cruise_key_integrity()`'s check "(a)" as worded in this
brief ("a sample with `source_uuid` has a `cruise_key` ≠ the `cruise` row reached through its
ichthyo `site.cruise_uuid`") cannot run against current artifacts and, if `source_uuid` is
implemented per Phase 2 item 2 as `site_uuid`/`tow_uuid`/`net_uuid` (**not** `cruise_uuid` — that is
what the brief itself specifies), it never will: `source_uuid` on a site row is `site_uuid`, and
there would still be no `cruise_uuid` column to rejoin through unless the ichthyo ingest is changed
to *keep* `site.cruise_uuid` (e.g. carry it through as an 18th `append_sample()` column, or thread it
into a helper column read only by this check). **This is a real open question for the design memo,
not something a Sonnet-tier spike should resolve unilaterally.**

**Best available proxy, run instead — referential integrity of `site.cruise_key` against the
released `cruise` table:**

```sql
SELECT count(*) n_site_rows,
       count(*) FILTER (WHERE c.cruise_key IS NULL) n_orphan_cruise_key
FROM sample s
LEFT JOIN cruise c ON c.cruise_key = s.cruise_key
WHERE s.dataset_key = 'swfsc_ichthyo' AND s.sample_type = 'site'
```

**Result: `n_site_rows = 61,104`, `n_orphan_cruise_key = 0`** — every ichthyo site row's `cruise_key`
resolves to a real `cruise` row in the release. This is a *weaker* check than the brief intends (it
cannot catch a case where `site.cruise_uuid` pointed at one cruise but `site.cruise_key` was somehow
stamped from a different one — a divergence between the join and the propagation, which is exactly
what "(a)" is meant to guard against), but it is what the current artifacts support, and it is clean:
**0 mismatches / 0 orphans.**

### 4. Proposed `check_cruise_key_integrity()` SQL — run once, with its result

Per the brief's own revision of item 3 ("(b) … assert instead that the NODC part equals `ship_key`'s
NODC and that `date_min ≤ … ≤ date_max` holds for every event keyed to the cruise"), plus the
proxy for "(a)" from §3 above:

```sql
-- (a) proxy — every dataset's cruise_key must resolve to a real cruise row
--     (the true UUID rejoin needs site.cruise_uuid to survive the ichthyo pipeline; see §3)
SELECT s.dataset_key, count(*) n
FROM sample s
LEFT JOIN cruise c ON c.cruise_key = s.cruise_key
WHERE s.cruise_key IS NOT NULL AND c.cruise_key IS NULL
GROUP BY 1 ORDER BY 1;

-- (b) NODC part of cruise_key must match the cruise row's own ship_nodc,
--     and every event's own datetime must fall within [date_min, date_max] of its cruise_key
SELECT s.dataset_key,
       count(*) AS n_checked,
       count(*) FILTER (WHERE split_part(s.cruise_key, '-', 3) <> c.ship_nodc) AS n_nodc_mismatch,
       count(*) FILTER (
         WHERE CAST(s.datetime AS DATE) < c.date_min OR CAST(s.datetime AS DATE) > c.date_max
       ) AS n_outside_date_span
FROM sample s
JOIN cruise c ON c.cruise_key = s.cruise_key
WHERE s.cruise_key IS NOT NULL
GROUP BY 1 ORDER BY 1;
```

**Result of (a) — orphan `cruise_key` (no matching `cruise` row at all), by dataset:**

| dataset_key | n orphans |
|---|---:|
| calcofi_bottle | 135827 |
| calcofi_ctd-cast | 3563 |
| calcofi_dic | 1 |
| calcofi_mets | 13452 |
| cce-lter_picoplankton-bacteria | 463 |

These are **excluded from the (b) `JOIN`** below (an `INNER JOIN`, so they never reach the NODC/span
check) and are a separate, large finding on their own: **153,306 sample rows across 5 datasets carry
a `cruise_key` that names no cruise in the release's own `cruise` reference table at all.** This
was not something Phase 1 item 1 asked about, but it is squarely what "(a)" is meant to catch and
is far bigger than the two findings below. **Flag for the design memo — this number alone may be
reason enough that the gate needs a grace path or a `questions.csv` row before it can fail the
release outright**; the spike does not attempt a root cause (candidates worth checking first: cruises
excluded from `cruise` because `date_ym` or `ship_key` was NULL at cruise-key-build time — recall
`create_cruise_key()` warns but does not stop on such rows — or these are cruises for which the
`cruise` reference itself never carried an ichthyo/bottle/ctd_cast/dic count > 0 and got pruned
somewhere upstream).

**Result of (b) — NODC-part mismatch + outside-date-span, by dataset (over the 1,289,181 rows with a
non-orphan `cruise_key`):**

| dataset_key | n_checked | n_nodc_mismatch | n_outside_date_span |
|---|---:|---:|---:|
| calcofi_bottle | 794549 | 1922 | 12215 |
| calcofi_ctd-cast | 15679 | 0 | 76 |
| calcofi_dic | 6 | 0 | 0 |
| calcofi_mets | 64343 | 0 | 3029 |
| calcofi_phyllosoma | 1815 | 0 | 28 |
| calcofi_phytoplankton | 241 | 4 | 0 |
| cce-lter_euphausiids | 7062 | 0 | 10 |
| cce-lter_picoplankton-bacteria | 8338 | 0 | 3 |
| cce-lter_zoodb | 395 | 0 | 10 |
| cce-lter_zooscan | 1062 | 19 | 3 |
| cdfw_dungeness-crab | 682 | 0 | 45 |
| farallon_bird-mammal | 60010 | 0 | 948 |
| sio_mesopelagic-fish | 102 | 0 | 0 |
| sio_pic-zooplankton | 77256 | 100 | 571 |
| swfsc_cufes | 44519 | 0 | 5049 |
| swfsc_ichthyo | 213122 | 210 | 0 |
| **total** | **1289181** | **2255** | **21987** |

**So: as literally specified, `check_cruise_key_integrity()` does NOT return zero rows on the
current data** — per the Gates section, these are findings for the reply/design memo, not something
this spike fixes. Traced both down to root cause (still read-only — no data touched):

- **`n_nodc_mismatch = 2,255` is caused by exactly ONE malformed cruise, not 2,255 independent
  problems.** `cruise_key = '2019-07-'` (trailing dash, **empty NODC segment**) for the 2019-07 Bold
  Horizon cruise (`ship_key = 'BH'`, `ship_nodc = '39C2'`, `cruise_uuid =
  bba5e398-02eb-ef11-a09e-2cea7fa0979c`, `date_min/max = 2019-07-11 / 2019-07-26`). Verified: `cruise`
  has 691 rows / 691 distinct `cruise_key`s (no fan-out), and exactly one of them fails
  `split_part(cruise_key,'-',3) = ship_nodc`. That one cruise_key is referenced by 1,922
  `calcofi_bottle`, 210 `swfsc_ichthyo`, 100 `sio_pic-zooplankton`, 19 `cce-lter_zooscan` and 4
  `calcofi_phytoplankton` sample rows — 1922+210+100+19+4 = 2255, exactly. The wrangling DB's own
  `ship` table has `ship_nodc = '39C2'` for `BH` with byte-identical `ship_key` (checked via
  `hex(ship_key)` on both sides — `4248` = `"BH"` in both `cruise` and `ship`), so
  `create_cruise_key()`'s `ship_key` join should have resolved it; why the persisted `cruise_key`
  ended up with an empty NODC segment anyway is **not determined by this spike** — worth a targeted
  look before Phase 2, since it is a genuine cruise_key defect (not a "designated month differs from
  event month" case), just narrow (1 of 691 cruises).
- **`n_outside_date_span = 21,987` is overwhelmingly a narrow, expected artifact of how `date_min`/
  `date_max` are computed, not 21,987 independent errors.** `cruise.date_min`/`date_max` are stamped
  **only from ichthyo's own tows** (per CLAUDE.md § `cruise_key`), so any other dataset's event that
  happens a few days before/after ichthyo's own net-in-water window on the same cruise will trip this
  check even though the cruise designation itself is correct — e.g. `calcofi_bottle:bottle:100095`
  (cast 1951-09-26) keyed to `1951-10-31BD` whose ichthyo-only span is `1951-10-02`–`1951-10-06`.
  Measured the distribution of `days_outside`:

  ```sql
  WITH j AS (
    SELECT s.dataset_key,
      CASE
        WHEN CAST(s.datetime AS DATE) < c.date_min THEN date_diff('day', CAST(s.datetime AS DATE), c.date_min)
        WHEN CAST(s.datetime AS DATE) > c.date_max THEN date_diff('day', c.date_max, CAST(s.datetime AS DATE))
        ELSE 0
      END AS days_outside
    FROM sample s JOIN cruise c ON c.cruise_key = s.cruise_key
    WHERE s.cruise_key IS NOT NULL
  )
  SELECT count(*) FILTER (WHERE days_outside > 0 AND days_outside <= 31) AS within_31d,
         count(*) FILTER (WHERE days_outside > 31 AND days_outside <= 365) AS within_1y,
         count(*) FILTER (WHERE days_outside > 365) AS over_1y
  FROM j
  ```

  Result: **21,980 of 21,987 (99.97%) are within 31 days** of the ichthyo-observed span (median 1–3
  days per dataset). Only **7 rows exceed 31 days**, and all 7 are `calcofi_ctd-cast` and look like
  genuine data errors, not span-definition artifacts:

  | sample_key | cruise_key | datetime | cruise date_min–date_max | days_outside |
  |---|---|---|---|---:|
  | calcofi_ctd-cast:cast:9908_067d | 1999-08-32NM | 1997-01-01 01:12:39 | 1999-08-07 – 1999-08-23 | 948 |
  | calcofi_ctd-cast:cast:9908_067u | 1999-08-32NM | 1997-01-01 01:15:29 | 1999-08-07 – 1999-08-23 | 948 |
  | calcofi_ctd-cast:cast:9908_069d | 1999-08-32NM | 1997-01-04 17:08:53 | 1999-08-07 – 1999-08-23 | 945 |
  | calcofi_ctd-cast:cast:9908_069u | 1999-08-32NM | 1997-01-04 17:34:54 | 1999-08-07 – 1999-08-23 | 945 |
  | calcofi_ctd-cast:cast:9908_070d | 1999-08-32NM | 1997-01-05 00:20:21 | 1999-08-07 – 1999-08-23 | 944 |
  | calcofi_ctd-cast:cast:9908_070u | 1999-08-32NM | 1997-01-05 00:57:24 | 1999-08-07 – 1999-08-23 | 944 |
  | calcofi_ctd-cast:cast:1307_021u | 2013-07-32NM | 2012-12-31 00:00:00 | 2013-07-06 – 2013-07-21 | 187 |

  Six of the seven are the same cast-pair triple (`9908_067`, `9908_069`, `9908_070`, each `d`+`u`)
  stamped `1997-01-0x` while keyed to cruise `1999-08-32NM` — off by almost exactly 2.5 years; the
  seventh (`1307_021u`) is off by ~6 months. **Not investigated further — the CTD ingest is not being
  re-run this round (umbrella § *Avoiding the CTD ingest*) — but these 7 are worth a `questions.csv`
  row or a note for whoever next touches `ingest_calcofi_ctd-cast.qmd`, since they look like a real
  cast-timestamp bug, not a cruise-key bug.**

**Net for the design memo / reply:** `check_cruise_key_integrity()` as specified would fail the
release today on 153,306 orphan-`cruise_key` rows (untriaged, dominates everything else), 2,255 rows
that are one real malformed `cruise_key` (`2019-07-`, root cause open), and 21,987
outside-date-span rows of which all but 7 are a span-definition artifact (ichthyo-only `date_min`/
`date_max` vs. every other dataset's own legitimate sampling window) rather than a data error. None
of this was "fixed" here per the Gates section's own instruction — it is numbers for Q5 / the reply
and for whoever writes Phase 2's actual gate (which will need at minimum a documented tolerance
band for (b), and a plan for the orphan-`cruise_key` rows before "(a)" can fail the release as
worded).

## Decided (Phase 1 memo, Fable · xhigh, 2026-09-03)

The spike's measurements stand and were not re-run. Everything below that carries a number not in
the Measured section was measured once, read-only, on `calcofi4r::cc_get_db("v2026.08.25")` on
2026-09-03 (scripts `ws_b_memo_queries{,2}.R` in the session scratchpad; SQL reproduced where a
number is load-bearing). Two things were **traced in code**, not measured: where `site.cruise_uuid`
goes (D2) and why `2019-07-` exists (D3). Phase 2 is the checklist at the end; the questions to file
are in it as ready-to-paste rows.

### D1 · Provider UUIDs are columns; the namespaced keys stay the integration PK (Q5, unchanged)

- **No re-keying, no minted UUIDs.** `sample_key` / `cruise_key` remain the join keys of a read-only
  frozen release; Ed's "business logic enforces entry" is met by `check_cruise_key_integrity()` (D5),
  not by PK choice. 15 of 16 datasets mint no UUID; a v5 UUID of a natural key is that key with worse
  legibility. Umbrella § Decisions › WS-B holds.
- **`cruise.cruise_uuid`** (Ed's CruiseId) is already released, 691/691 populated, and is the public
  join key to NOAA's database — `field_dictionary.csv` row 3 still says "internal to swfsc source;
  cruise_key is the public join key", which is the sentence to replace.
- **`sample.source_uuid`** (new, typed `UUID`, 17th positional column of `append_sample()`, NULL
  everywhere but ichthyo): the provider's own identifier for *that* event — `site_uuid` on a site
  row, `tow_uuid` on a tow, `net_uuid` on a net. The shards are unioned `BY NAME`
  (`calcofi4db/R/shards.R` l.55–90), so a column only ichthyo's shard carries arrives NULL for the
  other 15 with no arm touched.
- **`sample.station_uuid`** (new, `UUID`) + **`station_uuid_method`** (`VARCHAR`) — approved on
  the numbers in D8: the SWFSC station occupation an event belongs to, on **every** `sample` row
  (ichthyo's own rows carry their site; the others carry the match), computed in the release.
- **No `cruise_uuid` on `sample`.** It is a function of `cruise_key` (`cruise` is unique on both), so a
  1.3 M-row UUID column would be pure denormalization; a consumer joins `cruise` once. The brief's
  Phase 2 item 3(a) needed it only to run the UUID check in the release — D2 puts that check where
  the two columns still coexist.
- **Item 4 (strip `_source_*` from `cruise`) is verify-only.** The spike showed the released
  `cruise` carries none of them; `freeze.R` l.495 strips them. Keep a one-line assertion, drop the
  work.

### D2 · Where `site.cruise_uuid` is lost — traced, and what the UUID check becomes

The chain in `ingest_swfsc_ichthyo.qmd`, verified line by line:

1. `metadata/swfsc/ichthyo/flds_redefine.csv` l.40 maps `station.cruise_id` → `site.cruise_uuid`
   (type `uuid`); `ingest_dataset()` loads it (chunk `load_tbls_to_db`, l.230).
2. Chunk `propagate_cruise_key` (l.299–316) stamps `site.cruise_key` **from** `site.cruise_uuid`
   (`propagate_natural_key()` is an `UPDATE`; it drops nothing). Both columns coexist from here on.
3. `add_point_geom()`, `assign_grid_key()`, `standardize_site_key()`, `enforce_column_types()`
   (chunks `mk_site_pts` l.909, `update_site_from_grid` l.1032, `enforce_types` l.1272) are all
   `ALTER … ADD COLUMN` / `UPDATE` — nothing drops a column.
4. Chunk `emit_core` (l.1347): the three `append_sample()` arms (l.1395–1425) project the 15-column
   contract from `site s` — `s.grid_key, s.site_key, s.cruise_key, …` — **no UUID slot exists**, so
   neither `site_uuid` (except embedded in `sample_key` text) nor `cruise_uuid` reaches `sample`.
5. Same chunk, l.1538–1558: `compat <- list(site = compat_event_sql(ds_key, "site", "site_uuid", NULL,
   c(order_occ, longitude, latitude, cruise_key, geom, grid_key, site_key)), …)`, then for each:
   `DROP TABLE site` and `CREATE OR REPLACE VIEW site AS <compat SQL>`. The VIEW's column list is
   **exactly the 8 columns the spike's `DESCRIBE site` returned** (`site_uuid` recovered from
   `split_part(sample_key, ':', 3)` + those 7). The comment above it says so: "lossy for the rest
   (net.side, tow.tow_number, the legacy site columns) — which the release drops anyway. The real
   tables are DROPped". `write_parquet` (l.1575) writes `sample.parquet`, not `site`.

So the column is not lost by accident: the source table is deliberately discarded after the core is
emitted, and the core has nowhere to put it. The persisted wrangling DB shows the VIEW.

**Decision — the UUID check runs inside the ichthyo notebook, and its result travels in the
manifest.** In `emit_core`, *before* the compat block (after the `stopifnot()` at ~l.1508), assert:

```sql
SELECT COUNT(*) AS n_mismatch
FROM site s JOIN cruise c ON c.cruise_uuid = s.cruise_uuid
WHERE s.cruise_key IS DISTINCT FROM c.cruise_key
   OR s.cruise_key IS NULL
```

= 0 (hard `stopifnot()`), plus `COUNT(source_uuid) = COUNT(*)` per grain on `sample`, and
`n_mismatch` written to `manifest.json` `mismatches$cruise_uuid` beside `ships`/`cruise_keys`
(`write_parquet` chunk, l.1578). `check_cruise_key_integrity()` (D5) reads
`data/parquet/swfsc_ichthyo/manifest.json` and fails if the entry is missing or non-zero, so the
release verifies the fact without holding the column. Rejected: an 18th `append_sample()` column
(`cruise_uuid`) — carries a derived value on 1.3 M rows to serve one check; a `site_cruise.parquet`
side table — a fourth artefact for a 61,104-row fact that is `cruise.cruise_uuid` joined on
`cruise_key` anyway. The spike's proxy (every ichthyo `site.cruise_key` resolves to a `cruise` row,
61,104/61,104) stays in the gate as the FK check.

### D3 · `2019-07-` — root cause (traced) and fix

`create_cruise_key()` (`calcofi4db/R/wrangle.R` l.28–83) builds
`CONCAT(year, '-', month, '-', s.ship_nodc)`; DuckDB's `CONCAT` treats NULL as `''`. In the ichthyo
notebook it runs in chunk `create_cruise_key` (l.264) — **281 lines before** chunk
`apply_corrections` (l.545), whose `apply_data_corrections()` correction 1 (`wrangle.R` l.1036–1046)
is precisely `UPDATE ship SET ship_nodc = '39C2' WHERE ship_name = 'BOLD HORIZON' AND (ship_nodc IS
NULL OR ship_nodc = '')`. The source `shiplookup.shipnodc` is blank for Bold Horizon
(`flds_redefine.csv` l.33), so the key was minted as `2019-07-`, the correction then patched the ship
row, and the key was never re-derived. That is why the spike found `ship.ship_nodc = '39C2'` beside
a key with an empty NODC, and why the interim-ship path never fired: `ensure_interim_ships()` handles
*unmatched* ship codes, not a matched ship with a blank code. Three guards saw it and none stopped:
`create_cruise_key()` warns only on a NULL key (this one is not NULL); `collect_cruise_key_mismatches()`
labels it `malformed` in the manifest; `release_database.qmd` l.1112–1127 **warns** and its own
comment records `# cruise_key: 2019-07-`. Downstream every ingest inherited it through
`resolve_cruise_key()` step 1 (`cr.cruise_key` verbatim) — bottle 1,922, ichthyo 210, PIC 100,
zooscan 19, phyto 4 = 2,255 rows — while CTD (keys from the archive name via
`convert_cruise_key_format()`, l.1894) and METS (filename) minted the *correct* `2019-07-39C2`,
which is why two of the 152 orphan keys are Bold Horizon's: the same cruise under two spellings.

**Fix (Phase 2, ichthyo re-renders anyway):** (i) move `apply_data_corrections(con)` ahead of
`create_cruise_key()` (correction 2 only appends `species` rows; order-independent); (ii)
`create_cruise_key()` **stops** when any cruise's ship has a NULL/empty `ship_nodc` or the minted
key fails `^\d{4}-(0[1-9]|1[0-2])-[A-Z0-9]{4}$` — today it cannot fail; (iii) the same guard in
`resolve_cruise_key()` steps 2–3, which `CONCAT` `s.ship_nodc` the same way; (iv) the release warning
becomes part of the hard gate (D5). After the fix the reference row is `2019-07-39C2`, the 2,255
rows re-key when their ingests re-run, and the two Bold Horizon orphan keys converge. The source
defect (blank NODC) is a question for Ed (row in the checklist).

### D4 · Completing the `cruise` reference — the rows, their method, their spans

**What is missing, measured.** 843 distinct `cruise_key` values in `sample`, 691 in `cruise`:
**152 orphan keys** carry 153,306 `sample` rows and **3,804,612 `obs` rows**. By dataset (keys /
rows): bottle 132 / 135,827; ctd-cast 25 / 3,563 (events 2016-11 → **2026-07**: the 2025-04 export
lags CTD by over a year); mets 11 / 13,452; picoplankton 2 / 463; dic 1 / 1. By decade (keys):
1940s 27, 1950s 65, 1960s 12, 1970s 14, 1980s 7, 2000s 1, 2010s 6, 2020s 20. By ship: Horizon 21,
Black Douglas 21, Crest 21, Agassiz 19, Sally Ride 14, Paolina T 12, E. W. Scripps 7, Scofield 5,
Jordan 5, Baird 5, Stranger 4, Shimada 4, New Horizon 4, Lasker 4, Oceanus 2, Bold Horizon 2,
McArthur 1, Ellen B. Scripps 1. **Every NODC resolves in `ship`** (0 unknown, 0 interim); 121 of
152 keys lie more than 45 days from any reference cruise of the same ship (genuinely absent from the
export — the early SIO fleet and the post-export years), 31 lie 4–45 days from one (each is either a
designation disagreement or a real short cruise; adjudicated per key, not by rule). Largest:
`1987-05-32NM` 7,466 rows and `1988-09-32NM` 7,438 (bottle only), `2019-11-32OC` 3,735 (four
datasets), `2020-07-33P4` 3,637, `1950-03-31BD` 2,659. No ingest writes a `cruise_new` delta
(`grep cruise_new` matches nothing; only `ship` is in any `modifies:`), so nothing could ever have
added them.

**Decision — day one, the release completes the reference; the durable form follows.**

- **`complete_cruise_reference(con)`** (calcofi4db, `R/keys.R`), called in `release_database.qmd`
  immediately before the `cruise` enrichment (l.1157, whose `LEFT JOIN cruise_ref` keeps every row):
  one row per distinct non-NULL `sample.cruise_key` absent from `cruise`, with `cruise_key`,
  `ship_key` (the `ship` row whose `ship_nodc` is the key's NODC — **error** if none), `date_ym` (the
  key's month), `date_min`/`date_max` (min/max event date over that key's `sample` rows),
  `cruise_uuid` NULL, **`cruise_key_method = 'derived'`**, **`cruise_key_datasets`** (comma list).
  The 691 SWFSC rows get `cruise_key_method = 'swfsc'` and their datasets likewise. Ratchet
  `CRUISE_DERIVED_MAX = 152L` (only down). The FK check then holds by construction and `cruise`
  stays unique on `cruise_key` (`check_core_pk_unique()` already covers it).
- **Why `derived`, not `source`/`month`.** The brief asks for the ingest's `cruise_key_method` on
  the row. The release cannot supply it: `sample` does not carry the method, and the ingests that
  designate (bottle `Cruise` = YYYYMM, CTD archive name, METS filename, pico `cruise_ym`) each also
  have a fallback that mints a key no source designated (bottle/pico step 3 month rule; METS's
  year+month for files without a ship suffix). Labelling all 152 `source` would be a claim the release
  cannot check. **Next cycle** the designating ingests declare `modifies: [ship, cruise]` and write
  a `cruise_new` delta carrying their own `cruise_key_method` (`source` / `month`); the release then
  labels rows from deltas with that value, keeps `derived` as the backstop that must add **zero**
  rows, and ratchets `month` to zero. This needs one bug fixed first: the `_new` merge
  (`release_database.qmd` l.311–345) takes the PK as the table's **first column by ordinal
  position**, which for `cruise` is `cruise_uuid` — NULL on a delta row, so `WHERE cruise_uuid NOT IN
  (…)` is NULL and no row would ever insert. It must use `core_relationships(tables)$primary_keys`.
- **The best completion is Ed's.** NOAA's CalCOFI database has a cruise table independent of
  stations; a full export (CruiseId, ship, designated month, start/end) turns every `derived` row
  into a `swfsc` one with a `cruise_uuid`. Asked in the reply and filed as an ichthyo question.

**Spans.** `date_min`/`date_max` on the 691 SWFSC rows stay **ichthyo-observed** — they are what
`resolve_cruise_key()` keyed every ingest against (± 3 d), and widening them at release time is
circular (an event mis-keyed by the month rule widens the span that would then capture more events)
and would not be the span the ingests used. `derived` rows carry their own event span. Measured
support: other datasets' events widen 326 of 676 ichthyo spans, by at most 29 days (p99 13 d); under
all-dataset spans only **3 pairs** of cruises of one ship overlap, each explained — `2012-07-32I1` /
`2012-08-32I1` by 3 transit days (Farallon transects keyed 08 start 07-28, METS keyed 07 runs to
07-30); `2015-10-32OC` is **METS's own `1510` filename designation** for the cruise every other
dataset keys `2015-11-32OC` (identical spans 10-28 → 11-13; METS does not use
`resolve_cruise_key()`, its notebook says so at l.585); `2025-01-33UD` / `2025-02-33UD` is 6 CTD
casts dated 2025-01-19 inside a `2502` archive (a CTD question, with D7). Tolerance for the gate:
**31 days** (99.97% of events inside; the 7 CTD casts of D7 outside).

### D5 · `check_cruise_key_integrity()` — what fails on day one, what comes after

`calcofi4db::check_cruise_key_integrity(con, tolerance_days = 31L, known_outside_span = …,
manifest_ichthyo = …)` returns one tibble (`check`, `dataset_key`, `n`, `mode`, `finding`) and
**stops** on any `mode = 'fail'` row with `n > 0`. Called in a new `cruise_key_integrity` chunk
right after `check_core_pk_unique()` (l.1038) and after `complete_cruise_reference()`.

| # | check | mode | today (v2026.08.25) | zero after |
|---|---|---|---:|---|
| 1 | `cruise_key` matches `^\d{4}-(0[1-9]\|1[0-2])-[A-Z0-9]{4}$` on `cruise`, `sample`, `obs` | fail | 1 key / 2,255 rows | D3 |
| 2 | `cruise.date_ym` = the key's `YYYY-MM` | fail | 0 | — |
| 3 | key's NODC = `ship.ship_nodc` of `cruise.ship_key` | fail | 1 key / 2,255 rows | D3 |
| 4 | every non-NULL `sample.cruise_key` / `obs.cruise_key` exists in `cruise` | fail | 152 keys / 153,306 + 3,804,612 rows | D4 |
| 5 | `swfsc` rows have a unique non-NULL `cruise_uuid`; `derived` rows NULL | fail | 0 | — |
| 6 | event date within `[date_min − 31 d, date_max + 31 d]` of its cruise (SWFSC rows; derived rows are their own span) | fail, minus `known_outside_span` | 7 rows (all CTD) | D7 allowlist now; CTD re-run later |
| 7 | ichthyo `manifest.json` `mismatches$cruise_uuid` present and 0; `COUNT(source_uuid) = COUNT(*)` on ichthyo site/tow/net | fail | n/a until the ichthyo re-render | D2 |
| 8 | event spans of two cruises of one ship overlap by > 3 days | ratchet `CRUISE_SPAN_OVERLAPS_MAX = 2L` | 3 pairs (1 within transit tolerance) | METS → `resolve_cruise_key()`; CTD Q |
| 9 | `derived` rows in `cruise` | ratchet `CRUISE_DERIVED_MAX = 152L` | 152 | `cruise_new` deltas; Ed's cruise table |
| 10 | root samples with NULL `cruise_key`, per dataset | ratchet (`CRUISE_KEY_NULL_MAX`: dic 3,255 · pic 5,087 · crab 1,639 · bottle 49; mets and ctd 0) | as listed | D6 for dic; the others are open questions |

Checks 1–5 and 7 are hard from the first run; 6 is hard with the seven named keys as exceptions
(named, not counted, so an eighth fails); 8–10 are ratchets in the release notebook, never raised.
The literal spike SQL (§4) is the body of checks 3, 4 and 6.

### D6 · DIC's NULL `cruise_key` is a projection gap, and the source can fill it

All 3,255 DIC root samples have `parent_sample_key IS NULL` — they are the Niskins that matched no
bottle cast — and `ingest_calcofi_dic.qmd` l.714/730 takes `cruise_key` **only** from the matched
cast (`c.cruise_key`), so an unmatched DIC row has none by construction (the 7 DIC samples under a
cast, and the matched `obs`, carry it). 1,926 of the 3,255 (59%) have a datetime on the 1st of the
month, so the row's own date is month-precision and unsafe for span matching. But the source carries
`EXPOCODE` (WOCE: NODC ship code + cruise start date `YYYYMMDD`) and `Ship_Name`
(`metadata/calcofi/dic/flds_redefine.csv` l.2–3): `ship_key` from the NODC prefix, then
`resolve_cruise_key()` on the expocode's start date against the reference (span first, then the
expocode's month as `cruise_ym_col`), so every DIC row carries the cruise its provider designated
whether or not a Niskin matched. Filed as dic Q07 (proposed). Until it lands, check 10's ratchet
holds the count at 3,255.

### D7 · The seven CTD casts are timestamps, not keys

CTD keys every cast from its **archive name** (`19-9908NM_…` → `1999-08-32NM`,
`convert_cruise_key_format()` at l.1894), never from the cast date, so `cruise_key` is right by
construction and the timestamps are the defect: `9908_067/069/070` (`d` + `u`) carry 1997-01-01 to
1997-01-05, `1307_021u` carries `2012-12-31 00:00:00`; all seven are `data_stage = final`. Not fixed
this round (umbrella § Avoiding the CTD ingest); check 6 names the seven keys with the question id
so the release passes and an eighth cast cannot hide behind them. Proposed answer to file: the
archive is the cruise identity; the seven timestamps are set NULL (or corrected from the cast header
if Ben G finds the right value) when the CTD ingest next runs.

### D8 · The `station_uuid` rule, decided on the numbers

Beyond the spike's 23,403 exact / 72,969 nearest / 964 ambiguous / 122,958 none, measured:

- Of the 964 ambiguous (> 1 ichthyo occupation of the station on the cruise, no `order_occ` match):
  **92** have exactly one candidate within 6 h, **845** more exactly one within 24 h, **29** stay
  ambiguous (bottle 11, ctd 2, crab 1, pic 15). Ichthyo's own `(cruise_key, site_key, order_occ)`
  is unique, and `order_occ` is populated on 61,104/61,104 sites but on only 11,194/35,644 bottle,
  1,457/82,343 PIC and 4/2,015 crab roots — so datetime carries the match for the old data.
- Of the single-candidate rows without an `order_occ` match: 19,576 bottle / 165 ctd / 178 pic /
  1 crab within 6 h; 495 / 152 / 52,142 / 260 in 6–24 h; then 521 / 102 / 51 / 1 in 24–36 h, and
  150 / 2 / 14 / 0 beyond 36 h. The 6–24 h band is PIC's bulk (its tow times sit hours from the
  ichthyo site's first tow); the 24–36 h band (675 rows) is the one to re-measure before widening.
  330 single-candidate roots (bottle 180, ctd 8, crab 2, pic 140) meet an ichthyo site with **no
  datetime** — 3,169 of 61,104 sites have no tow time — and stay NULL.
- Date-only timestamps are rare (bottle 454, pic 155 at midnight), so a date-level rule is not needed.

**Rule.** `match_station_occupation(con, tolerance_hours = 24)` in the release, over `sample`:

1. `self` — ichthyo rows: the root site's `source_uuid` (every ichthyo site/tow/net).
2. `parent` — a root that *is* an ichthyo site through `parent_sample_key` (the crab's 310
   subsamples): the parent's `source_uuid`.
3. `order_occ` — exactly one ichthyo site shares `(cruise_key, site_key, order_occ)`.
4. `datetime` — exactly one ichthyo site at `(cruise_key, site_key)` has a datetime within 24 h of
   the root's (whether it is the only candidate or the only one inside the window).
5. otherwise NULL (`station_uuid_method` NULL), counted per dataset and reason.

The root's value is copied to every row under it (`root_sample_key`), so `obs.sample_key → sample`
answers "which SWFSC station occupation" at any grain. Expected coverage of root samples: bottle
27,785/35,644 (78.0%), ctd 15,450/19,242 (80.3%), pic 53,800/82,343 (65.3%; the rest are pre-1951
or no ichthyo occupation), crab 274/2,015 (13.6%, plus the 310 subsamples by `parent`), mets 0 (no
`site_key`), dic 0 until D6. Implementation follows `add_sample_seafloor()`'s rebuild (DuckDB cannot
`UPDATE` a table with a CRS-tagged `geom`), and — the v2026.08.25 lesson — the match table is
asserted unique on `root_sample_key` **before** the join and `sample` is asserted unchanged in row
count and unique on `sample_key` after it. Not on `obs` (additive later if a consumer needs the
`GROUP BY`).

### D9 · What the docs must stop saying

`docs/db.qmd` l.35 gives `cruise_key = 'YYMMKK'` (it has been `YYYY-MM-NODC` since 2026-06) and
l.46 says "Avoid UUIDs in output tables: use `_source_uuid` … (stripped in frozen releases)". True
sentences for WS-H (owner of the `db.qmd` rewrite): *provider UUIDs are released as typed columns
where the provider mints them — `cruise.cruise_uuid` (NOAA CruiseId), `sample.source_uuid`
(SWFSC site/tow/net), `sample.station_uuid` (the SWFSC station occupation any event belongs to);
the namespaced string keys remain the primary keys; `_source_*` provenance columns are stripped at
the freeze.* The CLAUDE.md § keys paragraph is Phase 2's (this WS owns it).

## Phase 2 checklist (decided; Sonnet · high, calcofi4db 3.31.0 after A0)

Order matters: 1–4 are the package, 5–7 the ichthyo notebook, 8–10 the release, 11–13 registries,
docs and notes. Every rule gets its testthat test **before** the code; `devtools::test()` green is
the gate at each step; `DESCRIPTION` is not bumped by the agent.

1. **`append_sample()` — 17th column `source_uuid`** (`calcofi4db/R/model.R` l.325). Extend the
   DESCRIBE-arity guard to `c(15L, 16L, 17L)`; 17 ⇒ `data_stage` + `source_uuid`; `NULL::UUID` when
   absent; `.ensure_sample_schema()` (l.123) adds `source_uuid UUID` in the DDL and via
   `ALTER TABLE … ADD COLUMN IF NOT EXISTS` (as `data_stage` at l.145). Tests in
   `tests/testthat/test-append_sample.R`: 15/16/17-column arms; 17 with a `UUID`-typed expression
   round-trips; 18 columns is a named error; a 15-column arm leaves the column NULL.
2. **`create_cruise_key()` refuses a blank NODC** (`R/wrangle.R` l.28): after the `UPDATE`, `stop()`
   if any `cruise` row's ship has `ship_nodc IS NULL OR ship_nodc = ''` or the key fails
   `^\d{4}-(0[1-9]|1[0-2])-[A-Z0-9]{4}$`; message names the ship. New
   `tests/testthat/test-create_cruise_key.R`: happy path; blank NODC errors (regression for
   `2019-07-`); missing ship_key still warns. **`resolve_cruise_key()`** (`R/cruise.R` l.141): steps
   2–3 join `ship` with `s.ship_nodc IS NOT NULL AND s.ship_nodc <> ''`; test in
   `test-resolve_cruise_key.R` that a blank-NODC ship yields NULL + method NULL, never `YYYY-MM-`.
3. **`R/keys.R` (new)** — `complete_cruise_reference(con, sample_tbl = "sample", cruise_tbl = "cruise",
   ship_tbl = "ship")` per D4 (adds `cruise_key_method`, `cruise_key_datasets`; returns the added
   rows); **`check_cruise_key_integrity(con, tolerance_days = 31L, known_outside_span = character(),
   manifest_ichthyo = NULL, ratchets = list(...))`** per D5 (the ten checks; `stop()` on a failing
   hard check; returns the tibble); **`match_station_occupation(con, tolerance_hours = 24)`** per D8.
   New `tests/testthat/test-keys.R` with one fixture per branch: reference completion (row added,
   method/datasets/spans right, unknown NODC errors, existing rows untouched); each integrity check
   on a fixture that violates only it (malformed key, `date_ym` mismatch, NODC mismatch, orphan key,
   `swfsc` row without UUID, event 32 d outside vs 30 d inside, allowlisted key passes but an
   unlisted one fails, overlap > 3 d vs ≤ 3 d, manifest missing / non-zero); station matching
   (`self`, `parent`, `order_occ`, unique-within-24 h, two candidates both inside ⇒ NULL, one of two
   inside ⇒ match, no datetime ⇒ NULL, children inherit the root, row count and `sample_key`
   uniqueness preserved). `NEWS.md` entry under the version the integrator assigns.
4. **`_new` merge keys on the real PK** — not in the package: `release_database.qmd` l.324–329
   replaces the ordinal-first `pk_col` with `core_relationships(base_tbl)$primary_keys[[base_tbl]]`
   (fall back to ordinal-first with a warning for tables outside the spec). No behaviour change
   today (`ship_new`'s first column is `ship_key`); it is the prerequisite for `cruise_new`.
5. **Ichthyo notebook — order and guard** (`ingest_swfsc_ichthyo.qmd`): move the `apply_corrections`
   chunk (l.540–551) to before `create_cruise_key` (l.264); keep the uniqueness `stop()` there.
6. **Ichthyo notebook — `source_uuid`**: the three `append_sample()` arms (l.1395–1425) gain a 16th
   `NULL::VARCHAR AS data_stage` and 17th `s.site_uuid` / `t.tow_uuid` / `n.net_uuid` `AS
   source_uuid`; the `stopifnot()` block (~l.1508) adds `COUNT(source_uuid) = COUNT(*)` for
   `sample_type IN ('site','tow','net')` and the D2 `cruise_uuid`-vs-`cruise_key` assertion
   (**before** the compat block at l.1538, while `site.cruise_uuid` still exists).
7. **Ichthyo notebook — manifest**: `mismatches$cruise_uuid <- <the D2 count as a one-row tibble>`
   in the `write_parquet` chunk (l.1578), beside `ships` / `cruise_keys`.
8. **Release — reference completion + gate**: in `release_database.qmd`, call
   `complete_cruise_reference(con_wdl)` immediately before the enrichment at l.1157; new chunk
   `cruise_key_integrity` after `check_core_pk_unique()` (l.1038) calling
   `check_cruise_key_integrity()` with `known_outside_span = c(<the 7 ctd-cast keys of D7>)` (each
   commented with the ctd-cast question id) and the ratchets `CRUISE_SPAN_OVERLAPS_MAX = 2L`,
   `CRUISE_DERIVED_MAX = 152L`, `CRUISE_KEY_NULL_MAX = c(calcofi_dic = 3255L, "sio_pic-zooplankton" =
   5087L, "cdfw_dungeness-crab" = 1639L, calcofi_bottle = 49L)` (mets and ctd-cast have none and are
   deliberately absent, so a first NULL there fails; measure at run time and tighten); delete the
   warn-only format block at l.1112–1127 (the gate subsumes it). `cruise` is already in
   `derived_tables` and the `gcs_prefix = NA` list (l.1583, l.1643), so the completed table ships.
9. **Release — `station_uuid`**: call `match_station_occupation(con_wdl)` in `depth_coverage` after
   `add_sample_seafloor()` (both rebuild `sample`; seafloor first so the rebuild count assertion is
   the last thing that touches the table), before `check_core_pk_unique()`; report the per-dataset
   method table with `datatable()`. `sample` is in `core_spec` (`gcs_prefix = NA`), so the columns
   ship; `test_release.qmd` gains one consumer-contract query that joins `obs → sample.station_uuid
   → sample (ichthyo site)` and asserts ≥ 25,000 bottle casts resolve.
10. **WS-F coordination (write into the F brief at merge):** the fix in step 5 changes ichthyo's
    `cruise` shard (one key), so F's "reference-shard hash unchanged ⇒ skip is safe" gate will
    correctly say *not safe*. Re-run the cheap dependents that carry `2019-07-` (bottle, PIC,
    zooscan, phytoplankton; ≈ 1.5 min each beyond what F already re-runs) — check 4 makes this
    mandatory, not optional; CTD may still be skipped by argument: it keys from archive names, holds
    0 rows of `2019-07-`, and its shard is byte-identical either way (verify with the manifest
    `content_hash` after the run). Also re-run METS if there is time: keying its cruise through
    `resolve_cruise_key()` removes the `2015-10-32OC` overlap (D4) — otherwise the ratchet holds it.
11. **Registries**: `metadata/field_dictionary.csv` — new rows `source_uuid` (UUID, identifier, "the
    provider's own identifier for this event as shipped (SWFSC site/tow/net UUID); NULL where the
    source mints none"), `station_uuid` (UUID, identifier, "SWFSC station-occupation UUID (= ichthyo
    `site_uuid`) this event belongs to; the row's own site for ichthyo, matched for other datasets;
    see `station_uuid_method`"), `station_uuid_method` (VARCHAR: self | parent | order_occ |
    datetime), `cruise_key_method` (VARCHAR on `cruise`: swfsc | derived), `cruise_key_datasets`
    (VARCHAR); replace `cruise_uuid`'s note (row 3) with "NOAA CruiseId; public join key to NOAA's
    CalCOFI database; released on `cruise`". No write helper exists for this file — append with
    `readr::write_csv(na = "")` and run `check_registry_na_strings()` on the result.
    `metadata/relationships_cross.csv`: add `sample,station_uuid,sample,source_uuid` (logical FK,
    note "SWFSC station occupation; NULL when unmatched"). The `questions.csv` rows below.
12. **Docs**: CLAUDE.md — a § "Provider UUIDs are columns; the cruise key is checked against the
    cruise" (D1, D2's "the check runs where the columns are", D3's ordering rule, D4's completion,
    the ratchet names); hand WS-H the D9 sentences for `docs/db.qmd` rather than editing it.
13. **`RELEASES.md # Unreleased`** — paste (adjust the counts to the run):

    > ## The provider's own identifiers are columns, and the cruise key is checked against the cruise
    >
    > Ed Weber asked (2026-09-02) that the integrated database adopt NOAA's UUIDs. It carries them
    > now as typed columns beside the namespaced keys it joins on: `sample.source_uuid` — the SWFSC
    > station, tow or net UUID exactly as the export ships it (NULL for the 15 datasets that mint
    > none); `sample.station_uuid` + `station_uuid_method` — the SWFSC station occupation any event
    > belongs to (ichthyo rows: their own site; bottle, CTD, PIC and crab roots matched on cruise +
    > station + occupation order, or on a unique occupation within 24 h — 78% of 35,644 bottle and
    > 80% of 19,242 CTD casts; the rest are pre-1951 or cruises the export has no stations for);
    > `cruise.cruise_uuid` documented as the public join key to NOAA's database. The `cruise`
    > reference is completed by the release (691 → 843 rows: 152 cruises the bottle, CTD, METS and
    > picoplankton sources designate that the SWFSC export has no stations for — 1949–1950 and
    > 2016–2026 mostly — stamped `cruise_key_method = 'derived'` with the datasets that carry them),
    > so every `sample.cruise_key` now names a cruise; before this 153,306 sample rows and 3.8 M
    > observations keyed cruises the reference lacked, and nothing failed. The Bold Horizon July 2019
    > cruise had been released as `2019-07-` (the source ship lookup has no NODC code for it and the
    > correction ran after the key was minted; 2,255 rows in five datasets) and is `2019-07-39C2`.
    > `check_cruise_key_integrity()` fails the release on a malformed key, a key naming no cruise, a
    > NODC that is not the cruise's ship, a `date_ym` that disagrees with the key, an ichthyo site
    > whose `cruise_uuid` and `cruise_key` disagree, or an event more than 31 days outside its
    > cruise's span (seven CTD casts with 1997 and 2012 timestamps in 1999 and 2013 archives are
    > named exceptions, ctd-cast Q32). **Consumers:** additive — three new columns on `sample`, two
    > on `cruise`, 152 new `cruise` rows; `cruise_key` values change only for Bold Horizon 2019-07.

**`questions.csv` rows to file** (columns: `label,id,question,context,status,priority,
proposed_answer,answer,asked_date,answered_date,who,related_table,related_field`; labels are the
next free on **main at merge** — A1 took ctd-cast Q28/Q29 and ichthyo Q10–Q12, DG took ctd-cast
Q30/Q31 on their branches, so the labels below assume those land first):

- `metadata/calcofi/dic/questions.csv` — `Q07,calcofi_dic_07,"Every DIC bottle that shares no
  Niskin with the bottle database reaches the release with no cruise_key (3,255 of 3,262 DIC samples;
  1,926 of their datetimes sit on the 1st of the month). Is EXPOCODE (NODC ship code + cruise start
  date) the intended cruise designation for every row, including those a Niskin match never
  found?","cruise_key is projected only through the matched bottle cast (ingest l.714); the
  unmatched majority carries none, so the cruise_key integrity gate holds them in a ratchet
  (CRUISE_KEY_NULL_MAX dic = 3255).",proposed,high,"Derive ship_key from the EXPOCODE's NODC prefix
  and resolve cruise_key against the SWFSC cruise reference by the EXPOCODE start date
  (calcofi4db::resolve_cruise_key, span first, then the expocode month), so every DIC row carries the
  cruise its provider designated; the row's own month-precision datetime is not used for the
  match.",,2026-09-03,,Ben Best,dic_sample,expocode`
- `metadata/calcofi/ctd-cast/questions.csv` — `Q32,calcofi_ctd-cast_32,"Seven final casts carry
  timestamps far outside their cruise: 9908_067, 9908_069 and 9908_070 (down + up) in the 9908NM
  archive are dated 1997-01-01 to 1997-01-05 (the cruise ran 1999-08-07 to 08-23), and 1307_021u in
  1307NM is dated 2012-12-31 00:00:00 (2013-07-06 to 07-21). Is the archive the correct cruise and
  the header timestamp wrong, and do you hold the right times?","Found by the release's cruise_key
  integrity gate (event > 31 d outside its cruise's span; 21,980 of 21,987 outside-span events are
  within 31 d, these seven are 187–948 d). CTD keys every cast from its archive name, so cruise_key
  is right by construction; the seven are named exceptions in release_database.qmd until the CTD
  ingest re-runs.",proposed,normal,"Treat the archive as the cruise identity; set the seven
  timestamps NULL (or to the header value Ben G supplies) when the CTD ingest next runs, keeping the
  casts on their cruise.",,2026-09-03,,Ben Best,ctd_cast,datetime_start_utc`
- `metadata/swfsc/ichthyo/questions.csv` — `Q13,swfsc_ichthyo_13,"shiplookup.shipnodc is blank for
  BOLD HORIZON (BH). We patch it to 39C2 on load, but until 2026-09 the patch ran after the cruise key
  was minted, so the July 2019 Bold Horizon cruise was released as cruise_key '2019-07-' with an empty
  NODC segment (2,255 rows across five datasets). Can 39C2 be added to shiplookup at source, and is
  39C2 the code NOAA uses for Bold Horizon?","calcofi4db::apply_data_corrections() correction 1;
  ingest_swfsc_ichthyo.qmd chunk order fixed and create_cruise_key() now refuses a blank
  NODC.",proposed,normal,"Fixed on our side (correction precedes the key; the key builder refuses an
  empty NODC); adding the code at source retires the patch.",,2026-09-03,,Ben Best,ship,ship_nodc`
- `metadata/swfsc/ichthyo/questions.csv` (recommended, the D4 ask) — `Q14,swfsc_ichthyo_14,"152
  cruises designated by the bottle, CTD, METS and picoplankton sources have no station rows in the
  ichthyo export and so no CruiseId: 92 from 1949–1959 (Horizon, Black Douglas, Crest, Agassiz,
  Paolina T.), 20 from 2020–2026 (Sally Ride, Lasker, Shimada), and e.g. 1987-05 and 1988-09 New
  Horizon. Could you export the full cruise table (CruiseId, ship, designated month, start and end
  dates) independent of station rows?","Measured on v2026.08.25: 153,306 sample rows and 3.8 M
  observations keyed these cruises; the release now completes the reference itself
  (cruise_key_method = 'derived') and would replace those rows with yours.",open,high,,,2026-09-03,,
  Ben Best,cruise,cruise_uuid`
