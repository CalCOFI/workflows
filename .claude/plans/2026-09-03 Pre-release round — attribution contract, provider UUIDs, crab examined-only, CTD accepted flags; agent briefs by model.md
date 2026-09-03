# Pre-release round — attribution contract, provider UUIDs, crab examined-only, CTD accepted flags; agent briefs by model

Status: **decided** (Ben, 2026-09-03 — Q1–Q11 taken as recommended, with two overrides: the release DOI
comes from **Zenodo via a GitHub release of this repo tagged with the database version**, and the
database citation names the **three principal CalCOFI partners**; emails are **drafted only, never
sent**). Revised the same day with Ben's schema questions (§ *Schema*), the effort denominator on
ERDDAP, DwC/eMoF alignment, `docs/db.qmd`, the Explorer's cross-dataset averaging and provider
question sheets (WS-H, WS-Q). Runs before the next
DAG + release; sits beside the decided taxon plan (`2026-09-02 Taxon crosswalk — …md`) and the
todo server plan (`plans_todo/2026-09-02 Server pipeline — …md`). Each workstream has a
self-contained brief in `.claude/plans_todo/2026-09-03 WS-*.md` naming the agent model and effort.
**The CTD ingest (128 min) is not re-run this round** — § *Avoiding the CTD ingest* says how and why
that is safe. Email drafts for the four threads:
`plans_todo/2026-09-03 Email drafts — Erin attribution, Ed UUIDs, Rasmus a–f, crab deposit.md`.

## The ask (Ben, 2026-09-03)

Before running the full DAG and cutting a release, fold in what four email threads raise; split
the work across agents of sufficient but not excessive intelligence, concurrent where independent;
avoid the 1.5 h CTD ingest; draft the replies.

1. **Attribution to integrated data** (Erin, 2026-09-02, after a call with CCE-LTER's Mike Ohman
   and Kathy). Sort attribution out *before* the Explorer is broadly released. Her five: (1) the
   source beside the variable name and in the filter rail — "Source: CCE-LTER (name); Collection
   platform: CalCOFI"; (2) a formal citation per contributing dataset, carried with every downloaded
   row; (3) a "Cite this data" function that knows which datasets a query touched and emits their
   citations + the integrated citation; (4) a "Data Sources & Attribution" page; (5) other. Ben adds:
   prominent on every download *including figures*; the opening modal has the user agree to cite;
   a way to reach PIs and share derived products; `cc_cite()` in calcofi4r and calcofi4py from a
   query or a list of dataset keys; whether `citation_main` needs date-accessed fields and
   validation of author/title/year; what other `citation_*` fields exist; a `license` field.
2. **UUIDs** (Ed Weber, 2026-09-02, DMP thread). NOAA's internal CalCOFI db keys CruiseId,
   StationId, … on UUIDs; "I strongly prefer that you adopt mine." Compound natural keys are
   redundant information shoved together: they break when a ship is swapped, dates change or
   cruises bleed together, and the ship in the key can disagree with the ship column after a
   partial correction. Ben: carry Ed's UUIDs with provenance columns and use them where available;
   `cruise_key` already bit us once; do we propagate UUIDs everywhere, and is that a good idea?
3. **Input on the station app** (Erin → Rasmus, 2026-08-21 …). Ralf Goericke's O2 spike (already
   fixed in v2026.08.25: the flag now reaches every consumer). **Rasmus answered Ben's six
   questions on 2026-09-01** (forwarded 09-03): (a) the bottle `R_*` pre-QC columns should *not*
   inherit quality codes — they are **interpolated to standard depths**; a flagged depth should have
   been skipped by the interpolation (in decodr), and if every `T_degC` on a cast is bad there
   should be no `R_Temp`; "when we do any kinds of data interpolations … we should not use already
   interpolated data points from the bottle database"; (b) the RATHBURN CORE casts: not familiar,
   nothing logged on location suggests ancillary work, continue to exclude; (c) casts found only in
   `orig/` / preliminary files and not in the final data: exclude; (d) CTD codes 1/2 = use
   primary/secondary sensor, confirmed; (e) GEBCO vs recorded depth: expect mismatches back in
   time (manual depths, no DP, echo-sounder misreads, scattering layers) — do not flag unless the
   discrepancy is large; (f) cruise-designation disagreements: how many? on a NOAA boat follow the
   NOAA designation; are there summer/fall cases? Not answered: whether `P_qual` is pressure or
   phosphate (Ben G). Also in the thread: Pooh Venrick (08-28) finds the station app's
   "by Data Set" subheadings under Phytoplankton confusing (all one table) and suggests one heading,
   "Phytoplankton abundances by species" — Betty's app, noted for the Sources display.
4. **Dungeness crab deposit** (Betty → UCSD Library RDC, 2026-08-27). Two zips —
   `…megalopae_timeseries_2008-2014.zip` and `…sorting_log_1949-2012.zip` — each with README
   "Known Data Quality Notes" (a reversed longitude sign corrected, missing date components
   reconstructed, a duplicate column name). No DOI yet. Ben: placeholder link to the Library
   catalog; **keep only the samples that were actually searched for Dungeness crab**.

## What is already waiting in the code since v2026.08.25 (measured 2026-09-03)

`RELEASES.md # Unreleased` (33 uncommitted lines + four committed sections):

| section | content | calcofi4db |
|---|---|---|
| browser-shaped objects | `obs_bio`, `obs_env`, `sample_root` (supplemental), `sample_spatial` (core), `coverage.json`; `measurement_type.denominator`; two canonical densities; effort questions filed | 3.24.0 |
| coverage taxa + category/variable | `coverage.json` `taxa[]`; `measurement_type.category` / `.variable`; `metadata/category.csv` enforced by the index | 3.25.0 |
| `climatology` | 1993–2013 monthly × 10 m × station × type, ≥ 3 cruises | 3.26.0 |
| seafloor stamp anywhere + NULL gate | `/vsicurl/` COG fallback; `check_seafloor_nulls()` fails the release on an inside-tile NULL | 3.27.0 (uncommitted in `release_database.qmd`) |
| `spatial_layers.json` | the 19-layer registry + counts/bbox/names/memberships as a sidecar | 3.28.0 (uncommitted) |

Also pending for the same release: the **taxon crosswalk** (decided: `dataset_taxon` gains
`ds_source_json`; common-name precedence; Farallon on ERDDAP via PR #77 — 3 commits, 1 file, no
review yet) and **ichthyo Q09** (zero vs unsorted tow, `proposed`). Uncommitted: `release_database.qmd`
(the two rows above), `CLAUDE.md` (§ Bathymetry; since compacted into skills by another session),
the notes file, five `_output/*.html`. Packages on main: calcofi4db 3.28.0, calcofi4r 1.16.0,
calcofi4py 0.5.0. The Explorer still reads its dev catalog (`VITE_RELEASE_PREFIX:
explore-dev/releases` in `explore/.github/workflows/pages.yml`) until a release ships the objects.

## Avoiding the CTD ingest

Measured from `_targets/meta` (run of 2026-08-25):

| target | min | | target | min |
|---|---|---|---|---|
| `ingest_calcofi_ctd_cast` | **128.1** | | `ingest_calcofi_mets` | 5.2 |
| `release_database` | 28.8 | | `ingest_sio_mesopelagic_fish` | 3.1 |
| `publish_to_netcdf` | 14.8 | | `ingest_cce_lter_euphausiids` | 2.0 |
| `deploy_consumers` | 11.2 | | `ingest_calcofi_bottle` | 1.4 |
| `test_release` | 5.9 | | the other 12 ingests | ≤ 1.5 each, 6.3 together |
| `publish_to_erddap` | 1.6 | | **total** | **210.9** |

**Every ingest except `ingest_spatial` and `ingest_ices.dk_ship-ices` declares
`dependency: ingest_swfsc_ichthyo`** (for the `cruise` / `grid` / `ship` reference shards), and
`dic` depends on `bottle`. The taxon work re-runs ichthyo, which changes its output hash, so a
plain `tar_make()` marks all fourteen dependents outdated and rebuilds CTD for 128 min to produce
byte-identical shards. Nothing in this round needs CTD's outputs to change:

- **WS-A** fills live in the notebooks' YAML, which `release_database.qmd` reads directly
  (`ingest_yaml_to_dataset_df(read_ingest_yaml())`); `source_accessed` is measured at release time
  (below), not stamped by the ingest.
- **WS-B** `sample.source_uuid` is ichthyo's (which re-runs anyway); the station crosswalk is
  computed in the release over `sample`, which the release already rebuilds and exports locally.
- **WS-C** re-runs the crab (0.4 min). **WS-E** re-runs its ten (≈ 10 min measured).
- **WS-D** is the one thing that would need CTD, and the accepted-flag snapshot is **600 bytes —
  a header-only parquet, zero flags, last modified 2026-08-19**. The chunk is written, not run;
  the release reports the pending count (0) instead.
- **WS-G**'s `r_*` changes are registry rows (`measurement_type.csv` loads wholesale); the bottle
  notebook's report fix and the answered questions are edits that render next time bottle runs.

**The run recipe (WS-F):** `tar_invalidate()` only the changed ingests, `tar_make(names =
all_of(changed))`, then `tar_make(names = all_of(caboose), shortcut = TRUE)` (targets 1.12.0;
`shortcut` skips upstream checks and builds exactly the named targets). **Gate that makes the skip
honest:** before the caboose, compare the content hashes of ichthyo's `cruise`, `grid`, `ship`
tables in `data/parquet/swfsc_ichthyo/manifest.json` against the committed previous manifest —
identical ⇒ every skipped dependent's shards are what a re-run would produce; different ⇒ stop
(the skip is not safe; run the dependents). Cost: ≈ 12 min ingests + ≈ 62 min caboose ≈ **1 h 15**.
Afterwards targets still lists the skipped ingests as outdated; the next full run (server plan)
clears that. **Durable fix (server plan, not now):** split ichthyo's reference shards into their own
target so the fourteen dependents stop invalidating on an ichthyo *data* change.

## Context — what exists today for each thread

**Attribution.** Every ingest's `calcofi.dataset_meta` carries `citation_main` (16/16 declare
it; **8 empty**: phyllosoma, phytoplankton, euphausiids, zoodb, zooscan, farallon, pic-zooplankton,
cufes), `license` (12 declare; **3 non-empty**: dic, crab, mesopelagic — "CC BY 4.0", free text),
`pi_names` (12), the three link fields, and two use `citation_others` as *acknowledgement* prose
(zoodb, zooscan: "Plankton sample analysis supported by NSF grants…"). `ingest_yaml_to_dataset_df()`
puts all of these on the release `dataset` table; `.dataset_entry()` drops `citation_others` from
`metadata.json`. Nothing validates any of them — `build_workflows_index.R` checks link shape and
liveness only. Consumers: db-schema shows **Cite:** + a license chip; db-viz-station reads
`datasets_meta.json` (name, link, citation, licence, PI); the Explorer's About modal lists
datasets with a hover-only "cite", its download bundle writes `CITATION.md` per dataset in the
selection, its figure footer stamps selection · unit · release · URL but **no dataset**, and its
Welcome modal asks for nothing. No `cc_cite()` in either package; no citation for the integrated
database itself. Authoritative citations *are* fetchable: EDI's cite service
(`https://cite.edirepository.org/cite/knb-lter-cce.254.4?style=ESIP` → the full citation with
DOI, verified), ERDDAP `.das` globals (`license`, `institution`, `creator_name`, `title`;
Farallon's license is a data-sharing-agreement PDF), NCEI landing pages (DOI). Nothing records
*when* a source was retrieved: `_ingested_at` is stripped at freeze.

**UUIDs.** Since 2025-04 the ichthyo export ships `cruises_uuids`, `station_uuids`, `tow_uuids`,
`net_uuids`; the ingest keys `site`/`tow`/`net` on them and the core `sample_key` for those grains
*embeds* them (`swfsc_ichthyo:site:<site_uuid>`). The release `cruise` table carries
**`cruise_uuid`** (= Ed's CruiseId) beside `cruise_key`, `date_min`/`max`, `ship_key` — and, per the
2026-08-13 Task 12 plan, leaks `_source_uuid`/`_source_file`/`_source_row`/`_ingested_at` that
`docs/db.qmd` says are stripped. `sample` has no UUID column; only the crab ingest links to a
SWFSC station occupation (`parent_sample_key` → the ichthyo site row); bottle and CTD casts root
on themselves. The 2026-08 `cruise_key` failure was exactly Ed's failure mode — a compound key
*derived* from an event's month instead of *looked up* from the cruise entity — and calcofi4db
3.20.0 (`resolve_cruise_key()`: the `cruise` reference is the authority, span first) already moved
to the discipline he asks for.

**Rasmus's answers, measured against the registries.** Bottle Q09 (`proposed`) asked exactly (a);
Q05 (r_ammonium vs ammonia) is related; ctd-cast Q27 (`proposed`) is (b). The six `r_*` types in
`measurement_type.csv` are **`is_canonical = TRUE` with an empty `derivation`** — nothing says they
are interpolated. For (f), the bottle notebook's "casts whose resolved cruise month differs from
the source designation" table shows **684 rows, but 670 are the DOUBLE-designation formatting trap**
(`198809.0` vs `198809`); the genuine disagreements are **14 cruises, 829 casts, 1953–1989, all
resolved by date span**: five on David Starr Jordan (31JD; 1975-05, 1975-07, 1975-11, 1981-07,
1984-03 = 535 casts), one on New Horizon (1989-07), the rest on 1950s–60s SIO ships; summer/fall
cases exist (1967-06 · 158 casts, 1975-07 · 9, 1981-07 · 71, 1989-07 · 12, 1975-11 · 125).

**Crab.** The notebook emits 310 examined subsamples (24 megalopae in 15 vials, 2008-04 → 2014-05)
**plus all 2,011 sorting-log tows as `sample` rows** — 216 sorted (each with a zero-valued
*M. magister* `obs`; **1984-05-17 → 2009-04-19**) and 1,795 unsorted with no `obs`. `dataset` =
2,321 samples. `link_data_source` is empty; `citation_main` has no DOI; `dataset_status.csv` still
says HELD OUT OF RELEASE (stale since 2026-08-14). The `+138.483` longitude is NULLed here (Q08)
while the deposit README says it was sign-corrected.


## Schema — Ben's questions, answered from the staging release (v2026.08.28, canonical layout)

| table | rows | MB | objects | partition | tier |
|---|---|---|---|---|---|
| `obs` | 26,261,931 | 401 | 16 | `dataset_key` | core |
| `obs_bio` | 1,255,348 | 22 | 1 | — | supplemental |
| `obs_env` | 25,006,583 | 287 | 84 | `measurement_type` | supplemental |
| `sample_root` | 419,543 | 11 | 1 | — | supplemental |
| `sample_spatial` | 925,762 | 7 | 1 | — | core |
| `obs_ctd_full` / `obs_mets_full` | 271 M / 20 M | 1,365 / 251 | 134 / 49 | `cruise_key` | supplemental |

**Are `obs_bio` + `obs_env` duplicates of `obs`?** In rows, exactly: 1,255,348 + 25,006,583 =
26,261,931. In columns they are a *reshaped superset*: they add `root_id`, `year`/`quarter`/`depth_bin`,
`units`, `qual_ok`, the gear + effort of the row's own sample (`tow_type`, `std_haul_factor`,
`prop_sorted`, `volume_sampled_m3`), the two canonical densities, `effort_class` and `hex7`; they
**drop `realm`, `sample_key`, `measurement_prec`, `hex_id`** and rename `measurement_value` → `value`.
So today the release ships the observation rows twice (401 + 309 MB of 2.4 GB), and the copy that
carries the effort denominator is the *supplemental* one.

**Decision D-S1 (Ben's instinct, staged over two releases).** The bifurcated pair becomes the physical
store; `obs` becomes a view.
- **This release:** `obs_bio` / `obs_env` gain the four missing columns (`sample_key` — without it a
  consumer can only reach the *root* sample, losing the net/bottle grain; `measurement_prec`; `hex_id`;
  `realm` is implied by the table) so each is a strict superset of `obs` under a name mapping
  (`value` ↔ `measurement_value`, kept as `value` because every Explorer template reads it); both are
  promoted to **core**; `obs` still ships but the catalog marks it `deprecated: true, replaced_by:
  [obs_bio, obs_env]` and carries **`views: { obs: <SQL> }`** — the UNION ALL that reconstructs `obs`
  under its original names. `cc_get_db()` (R and Python) and db-query's `__TBL:` resolver create the
  view from the catalog, so `FROM obs` keeps working; `test_release.qmd`'s 12 `obs` rows are duplicated
  against the pair so the contract covers both.
- **Next release:** the `obs` objects are dropped; only the view remains. The deprecation window is
  what keeps a consumer migration (db-query 8 files, `apps/` 7, db-viz-station 5, ctd-transects 2,
  db-viz-hex 2) off this release's critical path.
- **Why by `measurement_type` for env and one file for bio.** DuckDB-WASM cannot list a directory, but
  it reads an explicit https file list with `hive_partitioning = true` (the catalog provides the list —
  that is how the Explorer reads `obs_env` today). The axis is what matters: one variable = one ≤ 10 MB
  fetch, one taxon = one 22 MB file. `obs` by `dataset_key` served no consumer's question.

**DwC / OBIS ENV-DATA + eMoF (De Pooter et al. 2017).** The 2026-07 design already took eMoF as the
model for `sample_measurement` ("the OBIS net-level eMoF made a first-class table") and the model maps
one-to-one; what is missing is the *vocabulary*, not the shape:

| CalCOFI core | Darwin Core / ENV-DATA | gap |
|---|---|---|
| `sample` (adjacency list `parent_sample_key`) | **Event core** (`eventID`, `parentEventID`, `eventDate`, `decimalLatitude/Longitude`, `minimum/maximumDepthInMeters`, `samplingProtocol`, `sampleSizeValue/Unit`, `samplingEffort`) | `tow_type` → `samplingProtocol` needs a gear vocabulary; `sampleSize*` = the effort denominator |
| `obs` bio rows | **Occurrence** (`occurrenceID`, `eventID`, `scientificNameID` = WoRMS LSID from `taxon_key`, `lifeStage`, `organismQuantity` + `organismQuantityType`, `occurrenceStatus` present/absent — the zeros) | `organismQuantityType` **is** the denominator (individuals per 10 m², per 1000 m³); `lifeStage` needs S11 ids |
| `sample_measurement` | **eMoF on events** (`measurementType/Value/Unit` + `measurementTypeID/UnitID` NERC P01/P06) | `measurementTypeID` is NULL in `publish_ichthyo_to-obis.qmd`; P06 units partly mapped |
| `obs_attribute` | **eMoF on occurrences** (length, count per bin) | same |
| `obs` env rows | **eMoF on the bottle / depth event** | same |

**Decision D-S2.** Keep the relational long tables as the physical model (they *are* eMoF, and they are
what parquet, DuckDB, ERDDAP and PostgreSQL want); add the controlled-vocabulary ids to the registries
so every portal export is faithful without hand mapping: `measurement_type.csv` + `nerc_p01`
(measurementTypeID) and `units_nerc_p06` (measurementUnitID); `field_dictionary.csv` + `dwc_term`
(only `latitude`/`longitude` mention DwC today); a `metadata/life_stage.csv` with S11 ids; a
`tow_type` → gear vocabulary. Then `publish_ichthyo_to-obis.qmd` generalises to `publish_to-obis.qmd`
over the core for every bio dataset (the `publish_obis_template.qmd` scaffold exists) — **a follow-on
plan**, not this release; this release ships the registry columns and the mapping in `docs/db.qmd`.

**Decision D-S3 — the effort denominator reaches ERDDAP.** `publish_to-erddap.qmd`'s `{dataset_key}`
grain reads `obs` + `taxon` + `sample` (`sql_obs()`, l.260): counts with no effort and no density,
while effort sits on the separate `{dataset_key}_sample` grain that ERDDAP cannot join — which is why
erddap.calcofi.io looks "woefully absent" beside CoastWatch's `erdCalCOFIlrvcnt` (`volume_sampled`,
`standard_haul_factor`, `percent_sorted`, `larvae_10m2`, `larvae_1000m3`). The bio grain is rebuilt
from **`obs_bio`** so every row carries `tow_type`, `std_haul_factor`, `prop_sorted`,
`volume_sampled_m3`, `density_per_10m2`, `density_per_1000m3`, `effort_class`, `units`, `qual_ok`,
with ERDDAP variable attributes (`long_name`, `units`, `flag_values`/`flag_meanings` for
`measurement_qual`, NERC ids as `sdn_parameter_urn` once D-S2 lands). The env grain reads `obs_env`.

**Explorer copy vs behaviour (Ben).** The statistics already pool across datasets: `slice` holds every
dataset unless a pill filters, `_filters.sql` keeps one life stage and one denominator and drops rows
that denominator cannot be derived for, and `station.sql` / `hex.sql` average the survivors. So "nothing
averaged across denominators, datasets or stages" (App.tsx:730, help.tsx:70, tour.ts:37) is wrong on
the middle term. It becomes: **"averaged across datasets that share this life stage and denominator;
never across denominators or life stages"** — and the Sources line (WS-A3) lists every pooled dataset,
which is the attribution consequence of pooling.

**Release DOI (Ben).** Zenodo through the GitHub integration: `release_database.qmd`'s promotion step
(after `test_release` passes) tags this repo `vYYYY.MM.DD` and creates a GitHub Release whose body is
`RELEASE_NOTES.md` and whose assets are `catalog.json`, `metadata.json`, `RELEASES.md`; Zenodo archives
the repo at that tag and mints a version DOI under one concept DOI. The record is the *release record*
(code + catalog + notes; the parquet stays on GCS and is verifiable through the catalog's sha256s).
The DOI arrives minutes later, so `publish_release_notes.R` fetches it from Zenodo's API by tag and
re-renders the notes and `versions.json` — notes are not data. `.zenodo.json` + `CITATION.cff` carry
the metadata; the creators are the three partners as organisations. Ben enables the repo on Zenodo
once. Citation: *CalCOFI (YYYY). CalCOFI Integrated Database, release vYYYY.MM.DD [Data set].
Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife.
https://doi.org/10.5281/zenodo.NNNNNNN*

**Provider question sheets (Ben, for Ed and everyone).** `questions_email.qmd` already drafts one email
per provider from the 17 `questions.csv` files (152 rows open or proposed today; swfsc_ichthyo: 6 open,
2 proposed, none ever `asked`). The provider-facing view becomes **one Google Sheet per provider**
(so Ed sees swfsc: ichthyo + cufes), generated from the CSVs and pulled back: the CSV in git stays
the source of truth for the question; the sheet is the source of truth for `answer`, `status`,
`answered_date`, `who` once a provider types there (WS-Q).

## Decisions proposed (confirmed by Ben, 2026-09-03)

### WS-A · Attribution is a contract, checked like links

- **`citation_main` stays the display string**; validation is structural + authoritative, not a
  parser: `calcofi4db::check_dataset_citation()` requires a non-empty string with a 4-digit year
  and a DOI or URL (or a `proposed` `questions.csv` row naming the gap); where the source
  *exposes* a citation (EDI cite service, DataCite / doi.org content negotiation, ERDDAP `.das`)
  it fetches it, caches it in `metadata/{provider}/{dataset}/citation_authority.json` with a
  `checked` date and **reports drift as a `proposed` value — never overwrites**. Shape half in
  `build_workflows_index.R` always; network half behind `CALCOFI_SKIP_LINK_CHECK`.
- **New `dataset_meta` keys, all additive on `dataset`:** `doi` (bare; `doi.org` must resolve);
  `license` becomes an **SPDX id validated against `metadata/license.csv`** (`CC-BY-4.0`,
  `CC0-1.0`, `CC-BY-NC-4.0`, `US-PD` for NOAA government work, `custom` requiring `license_url`,
  `unknown` which fails the index unless a `questions.csv` row is open); `license_url`;
  `acknowledgement` (the credit prose now misfiled in `citation_others`; `citation_others` keeps
  its column and becomes a list of *additional citations*); `contact` (Q3).
- **`source_accessed` is measured, never asserted.** Now: at release time from git — the last
  commit date of `data/parquet/{p}_{d}/manifest.json` (method `sidecar_commit`), so no ingest has to
  re-run. Later: `stamp_source_access()` at the point an ingest reads its sources
  (`download` = the date the bytes came down; `file_mtime` for Drive-archived files) folded into
  `metadata.json` `sources[]`; the release prefers it when present. Both land on `dataset` beside
  `coverage_*_observed`.
- **One citation for the integrated database**: `release_citation(version)` → `catalog.json`
  `citation`, a "How to cite" section in every `RELEASE_NOTES.md` appendix (release + each
  dataset's `citation_main`), `CITATION.cff` here; a per-release DOI is a question for Erin (Q2).
- **`cc_cite()`** in calcofi4r + calcofi4py, fixture-pinned: input a character vector of dataset
  keys, a data frame carrying `dataset_key`, or nothing (all); output dataset citations + the
  release citation as text (default), BibTeX (doi.org content negotiation when a DOI exists, else
  `@misc` from the fields) or CSL-JSON.
- **Explorer**: the Welcome modal's primary action becomes the agreement (Q4; `?tour=off` still
  suppresses it or screenshots break); a **Sources** line in the SELECT rail under the pills
  (provider · dataset · license chip · copy citation); figure PNG/SVG footers gain a third line
  naming the datasets; **Cite this data** in EXPORT (text/BibTeX for the datasets in view + the
  release); a **Data Sources & Attribution** modal from the header and `?modal=sources`; **Register
  a product** through the feedback → Apps Script → public-issue pipeline, label `derived-product`.
- Other consumers get the additive columns: db-schema (doi, license link), ctd-transects footer,
  `docs/cite.qmd` as the canonical page, package docs; db-viz-station is Betty's (a note, with
  Pooh's phytoplankton-heading point).

### WS-B · Adopt the provider's UUIDs as columns; keep the namespaced keys as the integration PK

- **No re-keying.** This is a read-only frozen integration, so Ed's "business logic enforces
  entry" is met by **release gates**, not PK choice; a UUID v5 of a natural key is that key with
  worse legibility; 15 of 16 datasets mint no UUID. "Propagate everywhere?": no.
- **Carry the provider's UUID where one exists, typed UUID, first-class:** `cruise.cruise_uuid`
  (exists — document, add to `field_dictionary.csv` as the public join key to NOAA's db) and
  **`sample.source_uuid`** (new, additive; ichthyo site/tow/net; NULL elsewhere).
- **Station occupations are the crosswalk.** Ed's StationId = ichthyo `site_uuid`. Spike first:
  how many bottle / CTD / PIC / crab root samples match exactly one SWFSC occupation on
  `(cruise_key, site_key, order_occ)` ± time; how many none; how many ambiguous. If clean, Phase 2
  adds **`sample.station_uuid`** computed in the release (the matched occupation's `site_uuid`,
  NULL when unmatched) — a column, not a re-parenting.
- **`check_cruise_key_integrity()` fails the release** when a SWFSC-sourced sample's `cruise_key`
  differs from the `cruise` row for its `cruise_uuid`, or when a key's `YYYY-MM` / NODC disagree
  with that row's `date_min` / `ship_key` — Ed's "ship in the key ≠ ship column", made impossible.
- Strip `_source_*` / `_ingested_at` from the released `cruise`.
- Reply to Ed drafted for Ben: agree on principle; what is already true; what is added; Task 12 is
  about *names*, not compound PKs; ask whether NOAA has a station-UUID → bottle `cast_id` crosswalk.

### WS-C · The crab dataset is the examined samples

- `sample` = 310 subsamples + the **216 sorted** log tows (zero-valued `obs`); the **1,795
  unsorted rows are dropped**. Coverage becomes 1984-05 → 2014-05, measured. Description,
  `tables_owned` notes, `stopifnot()` counts, `dataset_status.csv`, memory follow.
- `link_data_source` = placeholder Library search
  (`https://library.ucsd.edu/dc/search?q=CalCOFI+Dungeness+crab+megalopae`, answers 200) with a
  YAML comment (Q6); **Q14** in `questions.csv` (open; on mint: `doi:`, the DOI in `citation_main`,
  `link_data_source` → `dc/object/<ark>`). Ben downloads the deposit zips before **2026-09-26**
  into Drive `cdfw/dungeness-crab/deposit/`; the ingest then negates the longitude as the deposit
  did and closes Q08.

### WS-D · Accepted CTD flags reach the ingest (written now, run next cycle)

- `ingest_calcofi_ctd-cast.qmd` gains the chunk: download-first read of
  `gs://calcofi-db/qc/ctd/flag_accepted.parquet` into `data/cache/`, apply as `measurement_qual`
  on matching scans, print the count; zero is a printed no-op. Not run this round (§ above).
  `release_database.qmd` reports `n_flags_pending` = accepted flags in the snapshot minus flags
  applied (warn, not fail). Check the server cron is alive (snapshot untouched since 08-19).

### WS-G · Rasmus's answers become registry facts and one measured reply

- (a) Bottle Q09 → `answered`; the six `r_*` types get `derivation` = "reported value interpolated
  to standard depth (pre-QC, decodr); carries no quality code by design; never an input to further
  interpolation", `is_canonical` → **FALSE** (Q10); a release gate: no `r_*` type may appear in a
  `variable` crosswalk; ctd-transects / Explorer sections verified to use CTD profiles or bottle
  QC'd depths, never `r_*`; one measured QC finding for Ben G: casts where every `temperature` is
  flagged 8/9 yet `r_temperature` is present. `P_qual` stays open (Ben G).
- (b) ctd-cast Q27 → `answered`, keep excluding. (c) the `orig*` / `uncorrected/` rule → `answered`
  on its question; `separate_runs/` stays (inside FinalQC, not superseded). (d) codes 1/2 →
  `answered`. (e) the seafloor ratchet stays report-only; the "large discrepancy" threshold that
  earns a `questions.csv` row is proposed (Q11) and asked back.
- (f) Fix the bottle notebook's report (compare integer `YYYYMM`, not the DOUBLE string) and reply
  with the 14 / 829 numbers, the Jordan cases (NOAA designation = the reference, as we do) and the
  summer/fall list; ask whether the nine SIO-ship cases should follow the bottle designation
  instead (our rule: the reference wins for every dataset; the bottle's own designation survives
  on its cast table).

### WS-E · Taxon crosswalk — already decided; only the agent assignment is new
### WS-F · The release run — last, sequenced, one operator, CTD skipped; ends with the tag + GitHub release
### WS-H · Schema: `obs` deprecated in favour of the bifurcated pair; DwC/NERC ids in the registries; effort on ERDDAP; `docs/db.qmd`
### WS-Q · Provider question sheets — one Google Sheet per provider, generated from and pulled back into `questions.csv`

## Agents — who runs what, in which wave

| WS | brief | model · effort | why this level | est. |
|---|---|---|---|---|
| A0 | citation contract: calcofi4db + `release_database.qmd` + index checks | **Fable 5.1 · xhigh** | a wrong shape silently mislabels 16 datasets' provenance; registry + tests | 8 h |
| A1 | fill `citation_main` / `license` / `doi` / `acknowledgement` per dataset from its source | **Sonnet · high** | per-dataset lookups with an evidence rule; unknowns become `questions.csv` rows | 4 h |
| A2 | `cc_cite()` calcofi4r + calcofi4py, fixture parity | **Sonnet · high** | mirrors `cc_density_sql()` / `density_sql()` | 5 h |
| A3 | Explorer attribution UI | **Opus 5 · medium** | multi-file TSX on established patterns | 10 h |
| A4 | other consumers, `docs/cite.qmd`, package docs | **Sonnet · high** | small additive edits across repos | 3 h |
| B | design memo + reply + spike → `source_uuid`, integrity gate, strip provenance | **Fable 5.1 · xhigh** (design + spike) → **Sonnet · high** (impl after Q5) | key semantics across every dataset; the reply goes to a collaborator | 3 + 2 + 6 h |
| C | crab examined-only + deposit placeholder | **Sonnet · high** | one notebook, counts to assert | 3 h |
| DG | CTD flag chunk + pending report; Rasmus's a–f filed, `r_*` registry, the (f) report fix, QC finding | **Sonnet · high** | registry edits + two SQL measurements | 4 h |
| E | taxon plan Phases 0–4 | **Fable 5.1 · xhigh** (Ph 0–1; Ph 2 PR #77 on Betty's branch) → **Opus 5 · medium** (Ph 3) → **Sonnet · high** (Ph 4) | per the decided plan | 19.5 h |
| H1 | `obs` → view: superset columns on `obs_bio`/`obs_env`, catalog `views[]` + `deprecated`, resolvers in calcofi4r/py/db-query, `test_release` rows | **Fable 5.1 · xhigh** | a schema pivot every consumer sits on | 8 h |
| H2 | DwC/NERC ids in the registries; `docs/db.qmd` rewrite; the DwC mapping page | **Opus 5 · medium** | vocabulary lookups need judgment; fill only exact matches | 6 h |
| H3 | ERDDAP bio grain from `obs_bio` with effort + densities + attributes | **Sonnet · high** | one notebook, a known target shape (CoastWatch's) | 3 h |
| Q | provider question sheets: push/pull script, one Sheet per provider | **Sonnet · high** | googlesheets4 + the existing `read_questions()` contract | 4 h |
| F | changed-ingests run → hash gate → caboose with `shortcut` → staging → real → test → deploy → notes → tag + GitHub release → DOI into notes → Explorer prefix flip | **Sonnet · high** operator, Ben on call | steps are written; judgment is "stop and report" | 5 h + wall |

**Waves.** Wave 1, concurrent, each in its own worktree: A0 · A1 · B-design+spike · C · DG · E-Ph0/1 ·
H1 · Q. Package bumps serialize through one integrator: **E-Ph1 (calcofi4db 3.29.0) → A0 (3.30.0) →
H1 (3.31.0) → B-impl (3.32.0)**; H2/H3 follow H1; A1/C/DG touch only notebooks and registries. Wave 2: A2 and A3 (need A0's column
names — start from the spec, degrade when a column is absent), E-Ph2 (PR #77, Betty reviews),
B-impl (after Q5). Wave 3: E-Ph3, A4. Wave 4: **F**, once every `# Unreleased` entry is in and
`devtools::test()` is green in all three packages; then the Explorer deploy (flip
`VITE_RELEASE_PREFIX` to `ducklake/releases`), consumer deploys, `publish_release_notes.R`. E-Ph4
docs can trail F. Every WS adds its `# Unreleased` entry in the same commit as its change and
`tar_invalidate()`s any `.qmd` it edits that must run.

## Architecture (what changes, by repo)

```
calcofi4db
  R/citation.R   NEW  check_dataset_citation(), release_citation(), stamp_source_access(), read_license_registry(), source_accessed_from_git()
  R/wrangle.R    ingest_yaml_to_dataset_df(): + doi, license_url, acknowledgement, contact; .dataset_entry(): + citation_others
  R/keys.R       NEW  check_cruise_key_integrity(), match_station_occupation(); freeze strips _source_* from cruise
  R/model.R      append_sample(): optional trailing source_uuid (17th col, like data_stage)
  R/taxa.R …     per the taxon plan
workflows
  metadata/license.csv                        NEW registry (SPDX id, name, url)
  metadata/{p}/{d}/citation_authority.json    generated cache (EDI / DataCite / ERDDAP)
  metadata/measurement_type.csv               r_* derivation + is_canonical (WS-G)
  ingest_*.qmd × 16                           dataset_meta fills (A1); ichthyo source_uuid (B); crab (C); ctd-cast flag chunk (D); bottle report fix (G)
  release_database.qmd                        dataset_coverage: + source_accessed; catalog citation; RELEASE_NOTES "How to cite"; check_cruise_key_integrity(); station_uuid; n_flags_pending; no r_* in variable
  scripts/build_workflows_index.R             check_dataset_citation() beside the link checks
  CITATION.cff · RELEASES.md # Unreleased (one entry per WS) · CLAUDE.md § Attribution + § Keys
calcofi4r 1.17.0 / calcofi4py 0.6.0           cc_cite(); catalog views[] → CREATE VIEW obs; tests/fixtures/cite_*.txt byte-identical
workflows (H/Q/Z)                              catalog.json views[] + deprecated; obs_bio/obs_env + sample_key/measurement_prec/hex_id, core;
                                               measurement_type.csv nerc_p01/units_nerc_p06; field_dictionary.csv dwc_term; metadata/life_stage.csv;
                                               publish_to-erddap.qmd bio grain from obs_bio; .zenodo.json + CITATION.cff; scripts/sync_questions_sheets.R;
                                               release tag + gh release in the promotion step; publish_release_notes.R fetches the Zenodo DOI
db-query                                       lib/release.js resolves a catalog view
docs                                           db.qmd rewritten (keys incl. UUIDs, core + browser objects, DwC/eMoF mapping, registries, citation)
explore                                       help.tsx (agree, Sources modal), App/ui (Sources line), export.ts (footer line 3), feedback.tsx (register a product); pages.yml prefix flip at F
docs · db-schema · ctd-transects              cite.qmd; db.qmd § keys; doi / license link; footer cite
```

## Decided (Ben, 2026-09-03 — "go with your initial recommendations", with the overrides noted)

- **Q1 (A) ✔ registry as proposed.** License registry as proposed? Who confirms the licence for the calcofi.org datasets
  (bottle, ctd-cast, mets — none stated; proposed `CC-BY-4.0`) and for ichthyo (proposed `US-PD`)?
  A1 files these as `proposed` rows for Rasmus / Erin / Ed.
- **Q2 (A) ✔ overridden: Zenodo, not the Library; three partners named** (§ Schema › Release DOI). Original: "CalCOFI (YYYY). CalCOFI Integrated Database, release
  vYYYY.MM.DD [Data set]. Scripps Institution of Oceanography & NOAA SWFSC.
  https://calcofi.io/db-schema/?v=…" — and ask Erin for a per-release DOI (Zenodo, or the UCSD
  Library that just took the crab deposit)?
- **Q3 (A) ✔ `contact` column + one front door + register-a-product via the feedback pipeline.** a `contact` column per dataset (provider-chosen URL/mailto via
  `questions.csv`) **plus** one CalCOFI front door on the Sources page, and "Register a product"
  through the existing feedback pipeline as public issues — or a Google Form Erin owns?
- **Q4 (A) ✔ the primary button's label, not a hard gate.** Wording, and whether it is a hard gate or the primary
  button's label.
- **Q5 (B) ✔ approved (drafts only).** Approve `sample.source_uuid` now and `station_uuid` after the spike's numbers; strip
  `_source_*` from `cruise`; send the reply to Ed as drafted?
- **Q6 (C) ✔ the placeholder search URL.** The Library search URL as the placeholder, or leave `link_data_source` empty (CLAUDE.md
  rule) with the pending deposit in `link_others` + `description`? Download the zips by 09-26.
- **Q7 (D) ✔ chunk ships unrun.** Confirm no flag has been accepted yet (snapshot 600 B since 08-19) and that the
  server cron still runs; the chunk ships unrun.
- **Q8 (G) ✔ draft only.** Send the Rasmus reply as drafted (14 / 829; Jordan; summer/fall)?
- **Q9 (F) ✔ laptop with `shortcut`.** Laptop run with the `shortcut` recipe (≈ 1 h 15), or promote the server plan first?
- **Q10 (G) ✔ `is_canonical` → FALSE.** `r_*` types: `is_canonical` → FALSE (they are interpolated, per Rasmus), or keep TRUE
  and rely on `derivation` alone?
- **Q11 (G) ✔ 500 m / 25 %.** The "large discrepancy" threshold below which a sample deeper than GEBCO is a report
  only: proposed **> 500 m or > 25 % beyond the deepest neighbouring cell** earns a `questions.csv`
  row; everything else stays in the ratchet report.

## Measured (appended per WS as it ships)

- 2026-09-03 · target durations and the dependency graph above; `flag_accepted.parquet` = 600 B;
  bottle designation disagreements = 14 cruises / 829 casts (of 684 reported rows); crab sorted
  tows 216, 1984-05-17 → 2009-04-19.
- 2026-09-03 · Ben enabled Zenodo: tag `v2026.09.03-alpha` → pre-release → version DOI
  10.5281/zenodo.22281995, concept DOI 10.5281/zenodo.22281994 (auto-metadata: MIT, creators = GitHub
  contributors — `.zenodo.json` in A0 overrides). README badge added (origin/main aa2e950, merged).
- 2026-09-03 · wave 1a hand-backs: A1 (EDI licences are not uniform: phyto CC0-1.0, phyllosoma/euphausiids
  custom; 14 proposed rows), C (526 events, 1984-05 → 2014-05), DG (r_* non-canonical; cron alive, 0
  accepted / 579 proposed flags; QC finding 0 casts), Q (script + 18 tests, waits on gs4_auth), E Ph0 (49 of
  2,125 names change under D5), B spike — **corrections to this plan:** the released `cruise` carries no
  `_source_*` columns (WS-B item dropped); `sample.cruise_key → cruise` is not an FK and **153,306 rows key
  a cruise the reference lacks**, plus one malformed key `2019-07-` (2,255 rows) and 7 CTD casts up to
  948 days outside their cruise span; DIC root samples have no `cruise_key` at all. WS-B Phase 2 starts
  by completing the `cruise` reference.
