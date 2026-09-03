---
name: measurement-bounds
description: "Declaring, validating and enforcing measurement bounds per dataset — check_measurement_bounds(), declare_measurement_bounds(), the out_of_range and undeclared findings, sentinel questions, drop_out_of_bounds(), supplemental tables, the release ratchet. Load when an ingest reports bounds findings or a release fails bounds_coverage."
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

> Moved out of the root `CLAUDE.md` on 2026-09-03 so it loads on demand; the hard rules stay resident there. Edit this file, not both.
