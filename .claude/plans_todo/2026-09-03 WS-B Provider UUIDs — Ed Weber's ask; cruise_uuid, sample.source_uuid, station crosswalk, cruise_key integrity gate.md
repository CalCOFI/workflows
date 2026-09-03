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
