---
name: cruise-key
description: "cruise_key (YYYY-MM-NODC, the cruise's designated month) and the provider identifiers beside it — resolve_cruise_key() by date span, add_cruise_date_span(), create_cruise_key() after ship corrections, cruise_uuid / sample.source_uuid / station_uuid, complete_cruise_reference() and the check_cruise_key_integrity() gate with its ratchets. Load before keying events to cruises in any ingest, touching cruise/ship references, or when the cruise_key_integrity chunk fails."
---

# Cruise keys and provider identifiers

> Moved verbatim out of `CLAUDE.md` on 2026-09-08 so the rules stay in every session's context and the mechanics and incidents behind them load only when needed. `CLAUDE.md` summarizes each rule and names this skill.

## `cruise_key` is the cruise's designated month, resolved by date span

`cruise_key` is `YYYY-MM-NODC`, and the `YYYY-MM` is the month SWFSC *designates*
for the whole cruise — never the month a cast or tow happened to fall in. A
CalCOFI cruise routinely straddles a calendar boundary (5508BD ran 7 Aug – 25 Sep
1955; 184 of the 664 bottle cruises span two months), and the neighbouring month
is usually a **real** cruise of the same ship, so keying by event month moved
casts onto the wrong cruise with no FK ever failing: v2026.08.14 released 664
source bottle cruises as 799 keys and 5,941 of 35,644 casts on a key their own
source disagrees with. Seven more ingests had the same `format(date, '%Y-%m')`
rule (cufes, pic-zooplankton, euphausiids, zoodb, zooscan, phyllosoma,
picoplankton).

Since calcofi4db 3.20.0 the ichthyo ingest stamps each reference cruise's observed
`date_min`/`date_max` (`add_cruise_date_span()`, from its own tows; the `cruise`
shard carries them) and every other ingest keys events with
`resolve_cruise_key()` — **span containment first** (same ship, ± 3 days; no two
cruises of one ship overlap), then the **source's own designation** where it has
one (`cruise_ym_col`: bottle's `Cruise` = YYYYMM, zooscan's year/month), then the
event month as a last resort, recorded in `cruise_key_method`.
`derive_cruise_key_on_casts()` delegates to it. Two rules that fell out:
- **The reference wins when sources disagree.** Ichthyo designates the 9 Feb –
  29 Mar 1984 Jordan cruise 8403; the bottle database says 8402. Every dataset
  joins to the reference, so agreeing with it is what makes the join mean anything
  — the bottle notebook reports these disagreements rather than "fixing" them.
- **Do not drop a source cruise column as "derivable".** The bottle ingest deleted
  `Cruise` and re-derived it as `STRFTIME(datetime, '%Y%m')` in `casts_derived`
  for years; that was the bug.

A `cruise` reference without spans makes `resolve_cruise_key()` **error**, so an
ingest run against a stale ichthyo shard fails instead of quietly regressing to
the month rule.

## Provider UUIDs are columns; the cruise key is checked against the cruise

Ed Weber (SWFSC) asked that the release adopt NOAA's own UUIDs (2026-09-02). The
answer is not to re-key: `sample_key` / `cruise_key` stay the join keys of a
read-only frozen release (15 of 16 datasets mint no UUID at all, and a v5 UUID of
a natural key is that key with worse legibility). Instead the provider's own
identifiers are released as **typed columns beside the namespaced keys**:

- **`cruise.cruise_uuid`** (NOAA's CruiseId) was already released, 691/691
  populated — it is the public join key to NOAA's own CalCOFI database.
- **`sample.source_uuid`** (calcofi4db ≥ 3.32.0, `append_sample()`'s 17th,
  trailing, optional column) — the provider's own identifier for *that* event
  exactly as shipped: ichthyo's `site_uuid` / `tow_uuid` / `net_uuid`. NULL for
  the 15 datasets that mint none; the shards are unioned by name, so a column
  only one shard carries arrives NULL for the rest with no arm touched.
- **`sample.station_uuid` + `station_uuid_method`** (calcofi4db ≥ 3.32.0,
  `match_station_occupation()`, run at release) — the SWFSC station occupation
  *any* event belongs to, on every `sample` row: `self` for ichthyo's own
  site/tow/net; `parent` for a foreign row parented directly to an ichthyo site
  (the Dungeness crab's examined subsamples); `order_occ` / `datetime` for every
  other dataset's root, matched on cruise + station (+ occupation order, or a
  unique occupation within 24 h); otherwise NULL. The match is computed once per
  root sample and copied to every row under it via `root_sample_key`.
- **No `cruise_uuid` on `sample`.** It is a function of `cruise_key` (`cruise` is
  unique on both), so a 1.3M-row UUID column would be pure denormalization — join
  `cruise` once. The one place a real `cruise_uuid` ↔ `cruise_key` link matters
  beyond that join is `swfsc_ichthyo`'s own `site` table, and it does not survive
  past that notebook's emit-core step (its compat VIEW rebuild carries only
  `cruise_key`) — so **the check runs inside the ichthyo notebook**, before that
  rebuild, and its result (0 or not) travels in `manifest.json`
  (`mismatches$cruise_uuid`) for the release gate to read.
- **`create_cruise_key()` must run *after* ship corrections, never before.** The
  July 2019 Bold Horizon cruise shipped as `cruise_key = "2019-07-"` (an empty
  NODC segment — DuckDB's `CONCAT()` treats `NULL` as `''`) because
  `apply_data_corrections()` (which patches the source's blank `ship_nodc` for
  that ship) used to run 280 lines *after* `create_cruise_key()` in the ichthyo
  notebook. `create_cruise_key()` (calcofi4db ≥ 3.32.0) now refuses outright to
  mint a key from a blank/NULL `ship_nodc` or one that fails the `YYYY-MM-NODC`
  format, naming the ship — a reordering mistake fails loudly instead of shipping
  a bad key again; `resolve_cruise_key()`'s source/month steps carry the same
  guard.
- **The `cruise` reference is completed at release, not asserted.** `cruise` is
  the SWFSC ichthyo export's station-occupation cruise list, not a designation
  registry — bottle/CTD/METS/picoplankton key events to cruises (mostly
  1949–1950 and post-export years) the export has no station row for. Measured
  at v2026.08.25: 152 such `cruise_key`s, carried by 153,306 `sample` rows and
  3.8M `obs` rows, named no `cruise` row at all, and nothing failed — the FK was
  never declared. `complete_cruise_reference()` adds one row per missing key
  (`cruise_key_method = 'derived'`, `cruise_key_datasets` = the datasets that
  carry it; the 691 SWFSC rows get `cruise_key_method = 'swfsc'`), resolving
  `ship_key` from the key's own NODC segment — an unresolvable NODC is an error,
  not a silent skip. `check_cruise_key_integrity()` (a new `cruise_key_integrity`
  chunk in `release_database.qmd`, run after the completion + enrichment) is the
  hard gate: key format, `date_ym`/NODC agreement, the FK from `sample`/`obs`
  into `cruise`, `cruise_uuid` hygiene, and every event's date within its
  cruise's span (`tolerance_days`, default 31 — 99.97% of measured outside-span
  events fit; named exceptions for the handful that do not, e.g. seven
  `calcofi_ctd-cast` casts with corrupted timestamps) — plus three ratchets that
  may only ever be lowered: the derived-row count, span overlaps between two
  cruises of one ship, and the per-dataset `NULL cruise_key` backlog (largest for
  `calcofi_dic`, whose unmatched Niskins carry no cruise designation at all —
  `metadata/calcofi/dic/questions.csv` Q07).


