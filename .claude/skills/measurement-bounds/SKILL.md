---
name: measurement-bounds
description: "Declaring, validating and enforcing measurement bounds per dataset — check_measurement_bounds(), declare_measurement_bounds(), the out_of_range and undeclared findings, sentinel questions, drop_out_of_bounds(), supplemental tables, the release ratchet — and why a provider quality flag outranks a bound: the CTD sensor-pair rule (combine_sensor_pair_sql(), drop 8/9, honour 1/2), flags before any derived value, and diffing a data fix against the release before re-staging. Load when an ingest reports bounds findings, a release fails bounds_coverage, or you touch anything that averages, pools, bins or summarizes measured values."
---

# Declared bounds are checked per dataset, at ingest time

**Every ingest that emits measurements calls
`calcofi4db::check_measurement_bounds()`, and every non-`ok` row is resolved
before the notebook is done.** The check is `calcofi4db` ≥ 3.10.0; it runs on the
per-dataset `{dataset}_measurement` (or on `obs` after the core is emitted) and
returns one row per measurement type with a `finding` string ready to paste into a
`questions.csv` `context` cell. `bounds_datatable()` renders it.

Two findings, and the second is the larger one:

- **`out_of_range`** — a bound is declared and the data breaks it. Nearly always
  an unconverted sentinel or a scaling error.
- **`undeclared`** — no bound, so nothing was checked. At v2026.08.07 this was
  **73 of 98 (dataset, type) pairs and 67% of all `obs` rows**; only
  `calcofi_ctd-cast` and one `calcofi_mets` type declared anything at all.

Resolve each one of two ways — "note it and move on" is not one of them:

1. **Declare the bound** with `declare_measurement_bounds()` (which sets bounds
   on types that already exist; `register_measurement_types()` only *appends*, so
   it cannot do this — that was the state of all 73). Bounds are
   deliberately **generous**: they catch the impossible, they do not police
   oceanography. If a bound would drop a value an oceanographer wants to see, the
   bound is wrong. **One-sided is fine and usually right** — `valid_min = 0` for a
   count, abundance or biomass is agreeable without knowing any ceiling, and it is
   what catches a negative sentinel.
2. **File a provider question** when the range is not ours to decide, with the
   `finding` as `context` and `status = proposed` carrying the bound you intend to
   apply. A value at exactly `-99`/`-999` is a sentinel until proven otherwise:
   raise it `high` rather than quietly declaring a bound that deletes it.

**Do not invent a bound to make the check quiet.** An `undeclared` type is a
visible finding; a wrong bound silently deletes real data. And do not set the
bound to the observed range — a bound describes what is physically possible, so it
must sit outside the data, or next season's legitimate record becomes a violation.

Enforcement is a **separate call**, `drop_out_of_bounds()`, so a bound must be
agreed before it can delete. It DELETEs rather than flags for the same reason the
`-99` sentinel is deleted: in a long-format table a row IS an assertion that a
value was measured, and there is no in-band way to mark one as not-a-value.

**Check the supplemental tables too, not just `obs`.** `obs_ctd_full` (~216M rows)
and `obs_mets_full` (~20M) are published, and checking `obs` alone certifies about
a third of the release. v2026.08.07 shipped an `obs_ctd_full` whose `ph` ran to
−2.98 — 5,963 values below the declared floor — *that the CTD ingest had already
removed from its own staged output*. The released bytes and the ingest's bytes
disagreed and nothing compared them, because every check looked at `obs`. Each
supplemental table derives from the same guarded per-dataset table as its `obs`,
so its owning ingest asserts `out_of_range == 0` on it rather than merely
reporting: a violation there means that derivation link has silently broken.
Cost is not a reason to skip it — 216M rows check in ~20 s, since the work is a
`GROUP BY` per type over one lazily-read column.

`release_database.qmd`'s `bounds_coverage` chunk is the **backstop, not the
mechanism**: it covers `obs` **and** every table in `supp_tbls`; `out_of_range`
fails the release outright, while `undeclared` is ratcheted by
`BOUNDS_UNDECLARED_MAX` (may only ever go down) so a *new* undeclared type fails
even though the backlog does not.

**Validate a proposed bound against every table the type appears in.** Two bounds
were declared here from `obs` alone and were immediately violated in
`obs_ctd_full` — `isus_v` at 0 (a −0.042 V sensor offset is normal, so the bound
was simply wrong and is now −1) and `dynamic_height` at ±50 (−2,884 dyn m is
genuinely impossible, so those 126 rows are correctly dropped). The observed range
in the headline table is not the observed range. Fix findings at the ingest — that is
the only place the provider can still be asked, and a release-time failure has
nowhere to put the answer. Raising the ratchet to make a release pass is how the
backlog reached 73.

The whole failure mode here is a constraint that *looks* enforced. `valid_min` was
emitted as a netCDF variable attribute and displayed on the schema site for months
while nothing compared a value to it, and `ranges` sat in `/validate-ingest`'s
`--checks` list with no section implementing it.

## A flag outranks a bound, and flags come first

**Bounds answer "is this physically possible?", never "is this good?".** Every
provider that flags its data has already answered the second question, and that
answer wins: a value flagged questionable or bad never enters anything we derive —
an average, a sensor-pair mean, the `climatology`, an anomaly, an interpolation, a
published summary statistic. Consumers get the same rule through
`cc_qual_ok_sql()` / `qual_ok_sql()` / `qualOkSQL()`; the pipeline must hold itself
to it wherever it computes a value, because a derived value carries no flag and
nothing downstream can undo what went into it.

**The CTD sensor pairs** (`TempAve`, `SaltAve_Corr`, `OxAve_StaCorr`,
`OxAveuM_StaCorr`) are rebuilt in `ingest_calcofi_ctd-cast.qmd` § Combine the Sensor
Pairs by Their Flags with `calcofi4db::combine_sensor_pair_sql()` — the rule Rasmus
Swalethorp set for this project (thread "Next Two Weeks Tasks", 2026-09-09): drop a
sensor flagged **8** (questionable) or **9** (bad); a **1**/**2** selects the
primary/secondary alone; otherwise the mean, one alone when the other is missing,
nothing when neither survives. The order matters: `-99` sentinels and out-of-bounds
values are removed first (an absent sensor reads like a 9), then the CTD team's
accepted flags (`flag_accepted.parquet`) are written onto the sensor rows, then the
pairs are combined, then the ingest asserts that no average includes a flagged
sensor. The file's own averages are never kept where a sensor exists — they are not
trustworthy (below) — and a corrected series inherits its sensor's flag column
(`libs/build_ctd_measurement_registry.R` § 4: `salt1_corr` → `salt1q`,
`ox1_sta_corr` → `ox1q`, `est_*` → `fluor_q` / `isusq`), because a bottle correction
changes the value, not the sensor's health.

**The incident (2026-09-11).** From 2026-08-07 the ingest "repaired" the averages by
the registry bounds alone (question Q21's proposed answer): a sensor counted as valid
whenever its value was physically possible. So a sensor the source flagged 8 or 9 was
averaged in whenever it stayed within −2…40 °C or 0…45 PSU — 1,425 temperature and
6,001 salinity averages in v2026.09.10 — and the accepted flags were applied *after*
the averaging, so they never reached it. Neither was noticed because the rule looked
enforced: it had bounds, a report and a `stopifnot`. The same day a second repair
("recompute where the shipped average disagrees with its in-bounds sensors") was
extended from temperature/salinity to oxygen by a dry run whose per-cruise breakdown
had dropped the oxygen column; it rewrote 2.65 M oxygen averages before a
series-by-series diff against the release caught it. Ben then settled both: Rasmus's
rule is the authority, for oxygen too, and an average is written wherever a surviving
sensor exists (≈ 1.1 M ml/L and 3.5 M µmol/kg oxygen averages the source never
shipped).

**Diff every fix against the release before re-staging.** For each `measurement_type`
the fix can touch: rows changed, filled, removed and the largest change, against the
released parquet (`~/_big/calcofi/releases/<v>/parquet/`). A breakdown that leaves a
series out is not a dry run; a count ten times the prediction is a stop, not a
curiosity. The 2026-09-11 dry run of the flag rule (probe:
`~/_big/calcofi/logs/dry_pairs.sql`) predicted per average: temperature 34,923
changed / 238 filled / 1,434 removed; salinity 39,276 / 811 / 1,141; oxygen ml/L
2,656,233 / 1,135,319 / 5,866; oxygen µmol/kg 4,274 / 3,529,141 / 780.

**Where flags are still weak.** The source flags are sparse (1,635 temperature and
10,154 salinity scans flagged 8/9 in v2026.09.10; no 1/2 codes survive into the
per-sensor series) and missed every failure the averages hid (the halved salinity,
the 35–40 °C surface bins). Rebuilding the averages from the sensors is what fixes
those, not the flags; single-sensor faults that stay in bounds and unflagged (a
corrected salinity sensor reading 19 PSU down to 509 m on one 2007-11 cast) are the
CTD team's to flag in the ledger. `build_measurements_catalog()`'s `observed{}`
quantiles are still computed over flagged values too (within bounds only) — the
measurement-faces plan's WS-MF3 moves them inside `qual_ok`.

> Moved out of the root `CLAUDE.md` on 2026-09-03 so it loads on demand; the hard rules stay resident there. Edit this file, not both.
