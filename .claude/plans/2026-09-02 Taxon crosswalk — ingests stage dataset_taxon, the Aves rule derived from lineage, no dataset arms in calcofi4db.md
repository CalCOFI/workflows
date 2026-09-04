# Taxon crosswalk — ingests stage `dataset_taxon`, the Aves rule derived from lineage, no dataset arms in calcofi4db

Status: **decided** (Ben, 2026-09-02 — see *Decided* below; runs on the laptop, the server
move is its own plan in `.claude/plans_todo/`). Revised the same day after Ben's review of the
first draft: no new table — `dataset_taxon` *is* the staged shape. Triggered by the review of workflows
PR #77 (Farallon bird/mammal → ERDDAP), where dropping `itis_id` from `bird_mammal_species`
would have un-keyed every seabird without an error anywhere.

## The ask (Ben, 2026-09-02)

> Having dataset-specific species lists nested inside an R helper function without even clear
> paths for editing/updating seems wildly fragile and confusing. We already have a bunch of
> species identification helper functions. And we explicitly use `"itis:"` prefix for birds and
> `"worms:"` prefix for all other taxa, so we need to be very clear about that (probably by
> looking for `class == "Aves"` or similar field, otherwise assume not a bird). With this PR
> review and updated ingest of ERDDAP source data, can we revise and clean up the process for
> this and future datasets?

and, on the first draft's proposed `taxon_vocab` table:

> Rather than creating a new table `taxon_vocab`, shouldn't you use `dataset_taxon` instead that
> is already unique by `dataset_key` and `ds_taxa_code` to crosswalk to the globally unique
> `taxon_key`?

Yes. `dataset_taxon` (`ds_taxon_key`, `dataset_key`, `taxon_key`, `ds_scientific_name`,
`ds_common_name`, `ds_taxa_code`; built by `build_dataset_taxon()`, unioned per shard by the
release's `core_shard_tables`, joined by every notebook's `append_obs()` SQL on
`(dataset_key, ds_taxa_code)`) is already the per-dataset vocabulary at exactly that grain. The
seven per-dataset tables are `dataset_taxon` rows *before* `taxon_key` is filled. The design
below stages `dataset_taxon` itself and fills `taxon_key` in place.

## Context — what exists (read 2026-09-02; calcofi4db 3.28.0)

`R/taxa.R` `.taxon_norm_sources()` is a **seven-arm switch on hard-coded table names and column
shapes** — the exact pattern calcofi4db 3.0.0 deleted from `R/model.R` for the core projection,
for the same reason (CLAUDE.md: "the projection lives in the ingest notebook that owns the
dataset, never in calcofi4db; the package holds only generic shapes"). The arms were written
after that cleanup, in the taxon consolidation, and survived it.

| arm | reads | id column | notes |
|---|---|---|---|
| `species` | `species` (ichthyo) | `worms_id`, `itis_id`, `gbif_id` | `ds_prefix = "calcofi"` |
| `phyto` | `phyto_taxon` | `aphia_id` | overrides on `taxa` |
| `zoodb` / `zooscan` | `{x}_taxon` | `aphia_id` + denormalised lineage | |
| `euphausiids` | `euphausiids_taxon` | `worms_id` (via `standardize_species()`) | |
| `mesopelagic` | `mesopelagic_fish_taxon` | `worms_id` (via `standardize_species()`) | code IS the name |
| `bird_mammal` | `bird_mammal_species` | `itis_id` | `is_bird`, `is_mammal`, `is_unidentified`, `include_flag` |
| `measurement` | `metadata/measurement_taxon.csv` | either | cufes / phyllosoma / crab |

Each arm reshapes its table into the *same* normalised frame, which `build_dataset_taxon()`
then writes out as `dataset_taxon`. So the package already has the one shape; it just refuses to
let the notebook hand it over directly.

Six things are wrong, and PR #77 tripped the first:

1. **The contract is implicit.** `.read_cols()` fills a requested column the table lacks with
   `NA` "so downstream binds align". Rename or drop a column in the notebook and the taxonomy
   changes silently. PR #77 drops `itis_id`, `is_unidentified`, `include_flag`; the notebook
   renders green and `check_taxon_ids()` fails the *release*, weeks later.
2. **The bird rule is a flag, not a fact.** `taxon_key_of(worms_id, itis_id, is_bird)` keys
   `itis:` when the *caller* says so; only the farallon arm ever does, from a source boolean.
   Aves reaching the release through any other dataset keys `worms:`, so one species could carry
   two keys.
3. **Dataset-specific fallbacks are code.** "unidentified bird → Aves `itis:174371`, unidentified
   mammal → Mammalia `worms:1837`" and the `include_flag` filter live in the arm. They belong in
   `taxon_override.csv`, which exists for exactly this and already holds 37 farallon rows.
4. **Groups are code.** `build_taxon_group()` hard-codes phyto functional groups and
   `calcofi:seabirds` / `calcofi:marine_mammals` off the farallon arm's `is_bird`.
5. **Three hard-coded dataset lists** that adding a dataset must edit and that never error when
   forgotten: `.prio` in `build_taxon_reference()`, `.TAXON_ARM_DATASETS` (what
   `taxon_override.csv` rows are validated against), and `merge_taxon_shards(priority = …)` in
   `R/shards.R`.
6. **`build_dataset_taxon()` is a rebuild, not a fill.** It re-derives every row from the arms,
   so an ingest cannot stage the crosswalk and have the package resolve it; it can only leave a
   table with the right name and hope.

What is **right** and stays: the generic resolvers. `ensure_taxon_xref()` (exact id crosswalk
both ways, `wm_records_name()` on `clean_taxon_name()` as the name fallback, accepted-id
re-keying, real `taxonomic_status` + `status_checked`, append-only `notes`, cached in
`metadata/taxon_xref.csv`); `ensure_taxon_lineage()` (classification chains, cached in
`metadata/taxon_lineage.csv`, ancestors as first-class taxa); `taxa_rank_reference()`;
`apply_taxon_common()`; `prune_taxon_shard()`; `check_taxon_ids()` as the release gate;
`taxon_override.csv` with its declared `match_column`. `_taxon_lineage_flat` already carries
`class` per requested id — the Aves fact is *already fetched*; it just does not decide the key.

## The take

**The ingest appends its rows to `dataset_taxon` with `taxon_key` empty; the package fills
`taxon_key` from the authorities; the key rule reads the classification, not a flag.** No new
table, no new release plumbing, no dataset name in the package. Same move as calcofi4db 3.0.0
for the core: ingest declares, package validates and resolves, release unions.

## Decisions

### D1 · `append_dataset_taxon()` — the ingest stages `dataset_taxon` rows; the package fills `taxon_key`

`append_dataset_taxon(con, dataset_key, df, ds_prefix = dataset_key)` writes this dataset's rows
into `dataset_taxon` (replacing any rows it already holds for that `dataset_key`):

| column | required | meaning |
|---|---|---|
| `ds_taxa_code` | yes; unique within dataset; non-NA | the code `obs` stores — verbatim, never cleaned |
| `ds_scientific_name` | yes (NA allowed for an operational class) | the source's name; the lookup query after `clean_taxon_name()` |
| `ds_common_name` | no | |
| `worms_id`, `itis_id`, `gbif_id`, `rank` | no; ids integer | what **the source supplied** — hints to resolution; stored together as `ds_source_json` (below) |

It **errors** on a missing required column, an **unknown column**, a duplicate or NA code, an id
that does not coerce to integer. A dropped column is a hard stop at ingest, not an NA at release.
It sets `ds_taxon_key = "<ds_prefix>:<ds_taxa_code>"`, `dataset_key`, and `taxon_key = NULL`.

**Release schema change, one additive column (Ben, Q1):** `dataset_taxon` gains
**`ds_source_json`** — a JSON object of whatever ids / rank the source supplied, e.g.
`{"itis_id": 174715}` or `{"worms_id": 217452, "itis_id": 161729, "gbif_id": 2415428}`;
`NULL` when the source supplied nothing. One column rather than four keeps the published table
narrow; it answers "what did the source claim?" beside `taxon.worms_id` / `itis_id` ("what does
the authority say?"), so the D3 audit is `json_extract(ds_source_json, '$.itis_id')` against
`taxon.itis_id`. `append_dataset_taxon()` builds it from the optional id columns, so the notebook
never writes JSON by hand. Nothing is dropped, so no consumer breaks (CLAUDE.md: dropping a
column changes the release schema under consumers). DuckDB writes it as a JSON-typed VARCHAR
in parquet; `calcofi4r` / db-query read it with `json_extract` where they need it.

The seven per-dataset tables (`bird_mammal_species`, `phyto_taxon`, …) may survive as notebook
working tables; the package stops reading them. `standardize_species()` /
`standardize_species_local()` stay as optional name→AphiaID pre-resolvers an ingest may run to
fill `worms_id` before staging; they are no longer needed, because `ensure_taxon_xref()`'s name fallback does
the same job for a row with no id, cached.

### D2 · The Aves rule is derived from the lineage, not declared by the source

Stated once, in `taxon_key_of()`'s roxygen and CLAUDE.md, and tested:

> A taxon keys **`itis:<tsn>` exactly when its class is Aves and an accepted TSN resolves**;
> otherwise **`worms:<aphia>`**; otherwise the dataset-local fallback `<dataset_key>:<code>`,
> which `check_taxon_ids()` refuses unless allow-listed.

`is_bird` disappears from `.taxon_row_template()`, `taxon_key_of()` and every caller. The
generic steps, in order, all reading `dataset_taxon` rows for the dataset:

1. `append_dataset_taxon()` — declare (D1).
2. `ensure_taxon_xref()` — resolve ids: `taxon_override.csv` first (it wins), then the exact
   crosswalk for whichever source id the row carries (from `ds_source_json`) (TSN→AphiaID, AphiaID→TSN), then the name
   fallback for rows with neither. Result staged in `_taxon_xref` as today.
3. `ensure_taxon_lineage()` — **two passes**, both cached: (a) the classification by the
   resolved AphiaID where present, else by TSN — this yields `class`; (b) for rows whose class is
   Aves and whose TSN resolved, the **ITIS chain**, so `parent_taxon_key` ancestry is `itis:` all
   the way up (as today). A bird with no TSN after step 2 keys `worms:` and gets a datestamped
   `notes` line — visible, not silent.
4. `resolve_dataset_taxon()` (the renamed `build_dataset_taxon()`) — mints `taxon_key` from
   `(worms_id, itis_id, class)` and **UPDATEs it onto the staged rows** instead of rebuilding
   the table. `build_taxon_reference()` writes `taxon` from the resolved ids + lineage;
   `build_taxon_group()` from the registry (D4).

Why lineage and not the source's `type` / `is_bird`: the flag is one dataset's opinion and only
one dataset has it. Class Aves from the authority is the same fact for every dataset, and it is
already in the cache.

### D3 · Farallon on ERDDAP — ids resolved by name through the generic path; DataZoo's TSNs ride in `ds_source_json` as an audit value, not the key's source

`CAC_FI_SBAS_sp` carries `species`, `type`, `common_name`, `scientific_name` and no ids. The
rewrite stages `ds_taxa_code = species`, `ds_scientific_name = scientific_name`,
`ds_common_name = common_name`, and — from a one-time committed copy of the DataZoo
`allspecieslist.csv` TSN column, `metadata/farallon/bird-mammal/species_itis_datazoo.csv`,
joined on code — `itis_id`, which lands in `ds_source_json`. Step 2 then resolves by the exact TSN crosswalk where a DataZoo
TSN exists (91 of 92 bird TSNs did, in the xref work) and by name where it does not (WoRMS holds
the *old* bird names as unaccepted synonyms with a `valid_AphiaID`, so *Puffinus griseus* →
*Ardenna grisea*; the AphiaID→TSN crosswalk gives the accepted TSN; D2 keys it `itis:`).

The audit is then `SELECT … FROM dataset_taxon d JOIN taxon t USING (taxon_key) WHERE
json_extract(d.ds_source_json, '$.itis_id')::INTEGER IS DISTINCT FROM t.itis_id` — rendered
in the notebook; every row is either a
deprecated-TSN re-key already logged in `taxon.notes`, an override row with a note, or a
provider question. Never a silent pick.

Three rows the source forces, none automatic:
- **`SBIG` appears twice** in `_sp` ("Mew Gull", "Short-billed gull"). `append_dataset_taxon()`
  refuses the duplicate; the notebook keeps one row (*Larus brachyrhynchus*) and says why.
- **`MEGU`** is in `_obs` (pre-2021 Mew Gull records) and absent from `_sp`. Same bird under the
  pre-split code, so the notebook adds a `MEGU` row with that name plus a `questions.csv` row
  asking Farallon Institute to confirm. `check_dataset_taxon()` (D6) makes forgetting it fail.
- **Unidentified classes** (whatever `is_unidentified` marked) become `taxon_override.csv` rows
  → Aves `itis:174371` / Mammalia `worms:1837`, replacing the arm's hard-coded fallback.
  `include_flag`'s job (which codes are not taxa) is the notebook's: exclude before staging, and
  list what was excluded.

### D4 · Groups come from a registry and from the lineage, not from an arm

`metadata/taxon_group.csv`: `taxon_group_key, description, rule, rule_value, dataset_key,
match_column, match_value`. Two rule kinds:
- `class` — every released taxon whose `class == rule_value`: `calcofi:seabirds` = Aves,
  `calcofi:marine_mammals` = Mammalia. Cross-dataset by construction; no dataset column.
- `dataset_taxon` — by `(dataset_key, match_column, match_value)` against `dataset_taxon`, the
  same matcher `taxon_override.csv` uses: the phytoplankton functional groups on
  `ds_common_name`.

`build_taxon_group()` reads the registry; a rule naming an unknown `dataset_key` or column
errors, like overrides do.

### D5 · No hard-coded dataset lists; `common_name` has one written precedence

`.prio`, `.TAXON_ARM_DATASETS` and `merge_taxon_shards(priority = …)` are deleted.
`taxon.scientific_name` / `rank` / classification come from the lineage (the authority). The
set a `taxon_override.csv` row may claim becomes "the `dataset_key`s present in
`dataset_taxon` ∪ `measurement_taxon`", so the existing "unknown dataset_key errors" check
keeps working with no list to maintain. Adding a dataset touches zero lines of the package.

**`common_name`** today: the arms' `.prio` picks which dataset's string wins, then
`release_database.qmd` calls `apply_taxon_common()` to fill what is still empty from
`metadata/taxon_common.csv` — a cache of WoRMS English vernaculars that is filled
automatically only when WoRMS returns exactly one name, and by hand otherwise (1,184 rows,
953 of them still unnamed). Nothing states the order. It becomes one `COALESCE`, applied
centrally in the release (so a name change never needs an ingest re-run), in this order:

1. a **human choice** in `taxon_common.csv` (`source = "manual"`; the existing column
   distinguishes it from an automatic single-vernacular fill) — the override;
2. the **ichthyo species list** (`dataset_taxon.ds_common_name` where
   `dataset_key = 'swfsc_ichthyo'`) — CalCOFI's own curated names;
3. **WoRMS**, when it offers exactly one English vernacular (`source = "worms_single"`);
4. any **other dataset's** `ds_common_name`, in `dataset_key` order (this is where the seabird
   and marine-mammal names come from — WoRMS holds almost no bird vernaculars);
5. empty. Never a guess.

**Decided (Ben, Q2): this order.** `apply_taxon_common()` grows the ranked sources and reports
how many names each rank supplied; the count of taxa whose released name changes under the
new order is measured in Phase 0 against the fixture and appended below.

### D6 · The ingest asserts its own crosswalk — `check_dataset_taxon()`

New, called after step 4 and before `append_obs()`:
- every `ds_taxa_code` the dataset's `obs` rows reference exists in `dataset_taxon` (MEGU);
- every `dataset_taxon` row has an authority `taxon_key`, or is in the ingest's own `allow =`
  list with a comment (zooscan operational classes, phyto "undefined code");
- every row whose class is Aves keys `itis:` (the D2 rule, checked where it is cheap to fix).

Returns the report frame, `halt = TRUE` by default. `release_database.qmd`'s `check_taxon_ids()`
+ `TAXON_LOCAL_ALLOW` stay as the backstop; the release allowlist should shrink to what no
ingest could own.

### D7 · PR #77 sequencing — request changes now; I do the Farallon migration, Betty reviews (Ben, Q3)

Post the review as drafted (request changes; Betty holds edits per Ben's point 3). Land Phase 1
in calcofi4db, then **I** rebase `ingest-farallon-erddap` onto it — `append_dataset_taxon()`
from ERDDAP + the DataZoo TSN column, download-first, the audit chunk, the three D3 rows,
`check_dataset_taxon()`, a rendered notebook with sidecar diffs, `questions.csv` and
`RELEASES.md` rows — as commits on her branch so the PR keeps her authorship of the ERDDAP
switch, and **Betty reviews** the diff. Reviewing a well-formed PR (commit messages, one change
per commit, sidecar diffs as evidence) is the git lesson.

## Which notebooks change, and what has to re-run

Ten ingests build taxon shards (`build_dataset_taxon()` or `ensure_measurement_taxon()`):

| ingest | today's vocabulary source | change |
|---|---|---|
| `swfsc_ichthyo` | `species` table (worms/itis/gbif ids) | `append_dataset_taxon(ds_prefix = "calcofi")` from `species`; ids as `ds_*_id` |
| `farallon_bird-mammal` | `bird_mammal_species` | PR #77 rebased: ERDDAP `_sp` + DataZoo TSN column (D3) |
| `calcofi_phytoplankton` | `phyto_taxon` | `append_dataset_taxon()`; functional groups → `taxon_group.csv` (D4) |
| `cce-lter_zoodb`, `cce-lter_zooscan` | `{x}_taxon` | `append_dataset_taxon()`; zooscan operational classes in `allow =` |
| `cce-lter_euphausiids`, `sio_mesopelagic-fish` | `{x}_taxon` after `standardize_species()` | `append_dataset_taxon()` (the pre-resolver may stay or go) |
| `swfsc_cufes`, `calcofi_phyllosoma`, `cdfw_dungeness-crab` | `measurement_taxon.csv` | **no notebook edit** — the measurement arm stays, but they re-run for the new `dataset_taxon` columns |

The other seven (`bottle`, `ctd-cast`, `dic`, `mets`, `pic-zooplankton`,
`picoplankton-bacteria`, `spatial`, `ship-ices`) carry no taxa and are untouched.

**What re-runs.** A `.qmd` edit or a calcofi4db bump does not invalidate a target (CLAUDE.md), so
the ten are `tar_invalidate()`d explicitly; the caboose chain follows by dependency. Measured on
the laptop from the 2026-08-25 run: the ten ingests ≈ 15 min, `release_database` 29,
`test_release` 6, `publish_to_netcdf` 15, `publish_to_erddap` 2, `deploy_consumers` 11 —
**≈ 1 h 20 min for the taxon change, on the laptop** (Ben, 2026-09-02). A *full* `tar_make()`
is ≈ 3 h 30 min, of which `ingest_calcofi_ctd_cast` is 128 min; it is not required by this
change. Running everything on the server is its own plan:
`.claude/plans_todo/2026-09-02 Server pipeline — run the full workflows DAG on the CalCOFI server.md`.
The parity gate (Phase 0 fixture) is what says the re-run changed only what D1–D5 intend.

## Decided (Ben, 2026-09-02)

- **Runs on the laptop.** The taxon change re-runs ten ingests plus the caboose, ≈ 1 h 20 min.
  The "18 h" in the first draft was my build time, not pipeline time. The server move is
  `.claude/plans_todo/2026-09-02 Server pipeline — …md` (Q4 dedicated `pipeline` service +
  100 GB disk; Q5 push straight to `main` with a `[pipeline]` prefix; Q6 finish the Shared
  Drive migration).
- **Q1** — not four columns: one **`ds_source_json`** on the released `dataset_taxon` (D1).
- **Q2** — `common_name` precedence exactly as written in D5.
- **Q3** — I do the Farallon phase; Betty reviews (D7).

- **Decided (Ben, 2026-09-04) — the phytoplankton override collapse.** The taxon is keyed by the finest
  WoRMS AphiaID the source supplies; the functional-group labels (`taxa`: "diatom, centric", …) belong to
  `taxon_group` only; a group label is never a `common_name`, and the group itself is not renamed. Rule for
  the package (D2 step 2): **an override row never replaces an id the source supplied** — a row matched on
  a non-code column (`taxa`) applies only where the source id is NA; a row matched on the dataset's own
  code applies always. Expected effect: ~290 of 393 phytoplankton codes regain species/genus keys (22 keys
  → ~294). Ben: "That was a seriously faulty ingest to miss that."

## Architecture (what changes)

```
calcofi4db
  R/taxa.R
    append_dataset_taxon()      NEW  stage rows, taxon_key NULL; errors on shape deviation (D1)
    check_dataset_taxon()       NEW  ingest-time gate (D6)
    resolve_dataset_taxon()     build_dataset_taxon() renamed: fills taxon_key in place (D2.4)
    taxon_key_of(worms, itis, class)   is_bird → class (D2)
    .taxon_norm_sources()       reads dataset_taxon only; seven arms, .prio, .TAXON_ARM_DATASETS deleted
    build_taxon_group()         reads metadata/taxon_group.csv (D4)
  R/common_names.R apply_taxon_common()   ranked sources, per-rank counts (D5)
  R/shards.R  merge_taxon_shards()   priority list deleted (D5)
  R/lineage.R ensure_taxon_lineage() two-pass: class first, ITIS chain for Aves (D2)
  R/xref.R    ensure_taxon_xref()    overrides → exact crosswalk on ds_*_id → name; no is_bird branch
  tests/testthat/test-taxa.R   shape contract, Aves rule (bird+TSN, bird−TSN, mammal), overrides, group rules, common-name order, parity
workflows
  metadata/taxon_group.csv             NEW registry (D4)
  metadata/taxon_override.csv          + unidentified fallbacks (D3)
  metadata/farallon/bird-mammal/species_itis_datazoo.csv  NEW (D3)
  ingest_*.qmd × 7                     append_dataset_taxon() + check_dataset_taxon(); farallon download-first
  release_database.qmd                 parity gate during migration; TAXON_LOCAL_ALLOW shrinks; ranked common names
  RELEASES.md  # Unreleased: dataset_taxon gains ds_source_json; common_name precedence; farallon on ERDDAP
  CLAUDE.md § Shared taxonomy refs; RUNBOOK.md; ingest template
```

## Phases (each shippable on its own)

| phase | what | gate | est. |
|---|---|---|---|
| 0 | **Parity fixture + name-change count.** Dump the promoted release's `taxon`, `dataset_taxon`, `taxon_group` to `tests/testthat/fixtures/taxon_parity_v<version>/`; compute how many `common_name`s the D5 order would change. | exists; count reported for Q2 | 1.5 h |
| 1 | **calcofi4db 3.29.0.** D1 / D2 / D4 / D5 / D6 helpers; staged `dataset_taxon` rows read *beside* the seven arms (coexistence); `cc_data_dir()`. Tests per rule. | `devtools::test()` green; farallon staged through D1 reproduces the fixture's farallon slice key-for-key | 6.5 h |
| 2 | **Farallon on ERDDAP** (PR #77, me; Betty reviews). Download-first, D3 rows, DataZoo TSN column, audit chunk, `check_dataset_taxon()`, rendered notebook. | farallon `dataset_taxon` = fixture except the documented D3 rows; `obs.taxon_key` NULL count unchanged | 4 h |
| 3 | **The other six + delete the arms.** `append_dataset_taxon()` in ichthyo, phyto, zoodb, zooscan, euphausiids, mesopelagic; `taxon_group.csv`; delete the arms and the three lists; **calcofi4db 4.0.0**; the ten ingests + caboose re-run on the laptop (≈ 1 h 20: `tar_invalidate()` the ten, `tar_make()`, confirm `_output/*.html` mtimes). | release-time parity: `taxon` / `dataset_taxon` (pre-existing columns) / `taxon_group` identical to the fixture, except the Q2-approved name changes | 6 h |
| 4 | **Docs.** CLAUDE.md § taxonomy; RUNBOOK; ingest template's `TODO-taxonomy` becomes the four calls; `/ingest-new` scaffold. | reads true against the code | 1.5 h |

≈ 19.5 h of my build time (the pipeline itself is ≈ 1 h 20 on the laptop). Phases 1 + 2 fix
PR #77 properly; 3 is what makes the next dataset free.

## Measured (appended per phase as it ships)

- **Phase 0 (2026-09-03, calcofi4db `ws-e` @ f78a368, Sonnet after four 529s on Fable/Opus):** fixture
  `tests/testthat/fixtures/taxon_parity_v2026.08.25/` — `taxon` 2,125 · `dataset_taxon` 1,910 ·
  `taxon_group` 151 rows, generator `data-raw/build_taxon_parity_fixture.R`, `test-taxon-parity.R` 19/19.
  **D5 common-name order changes 49 of 2,125 taxa (2.3 %)**: `other:calcofi_phytoplankton` 20,
  `other:cce-lter_zoodb` 20, `other:cce-lter_zooscan` 8, `swfsc_ichthyo` 1 — mostly taxa with NO name today
  because those arms never wired `ds_common_name` through. "Manual" reconstructed as filled names that are
  not `source == "worms" & n_candidates_en == 1` (`taxon_common.csv` has no literal tag yet — Phase 1 adds
  it). Open for Phase 1: `worms:126175` has two ichthyo codes (genus "Rockfishes" vs "Sunset rockfish");
  D5 needs an intra-dataset tie-break (fixture used `ds_taxon_key` ascending).
- **Phase 1 (2026-09-03, calcofi4db `ws-e` @ c36d60a, workflows `ws-e-ph1b` @ a013108, Fable):** farallon
  staged through `append_dataset_taxon()` reproduces the v2026.08.25 `dataset_taxon` slice 156/156 and its
  127 `taxon` rows on eight fields; 113/113 `itis:` vocabulary taxa are Aves and 0 `worms:` ones are;
  `taxon_group` differs only by the two turtles leaving `marine_mammals`; the merge priority list was inert;
  D5 changes 50 of 2,125 names (44 manual / 790 ichthyo / 186 WoRMS single / 175 other / 930 empty);
  tests 1,260 → 1,378. **Found:** phytoplankton releases 22 keys for 393 codes because six `taxa`-matched
  override rows replace species ids — decision needed before Phase 3.
- **Phase 2 (2026-09-03, workflows `ws-e-ph2` on Betty's `ingest-farallon-erddap`, Fable; calcofi4db 3.31.0
  unchanged):** farallon staged from ERDDAP `_sp` (241 codes; 164 staged, 49 observed codes excluded) with
  DataZoo's TSNs as `ds_source_json` (`metadata/farallon/bird-mammal/species_itis_datazoo.csv`, 200 codes /
  159 TSNs, from the archived `allspecieslist.csv`). Gate: **`taxon_key` 153/154 identical** to the
  v2026.08.25 slice on the codes both hold, the one change the documented `MEGU` re-key
  (`itis:176832` *L. canus* → `itis:1192602` *L. brachyrhynchus*, with `SBIG`); 126/126 `taxon` rows
  identical on eight fields; only-in-fixture `CSLI`, `XAMU` (unreferenced, retired upstream); 10 new codes
  (`CHSP GUMU LOTU MABO NABO SBIG SCMU TOSP UNLP UNMT`). `obs.taxon_key` NULL on the 65,855 shared rows
  1,177 → 727: 450 rows gained a key through the nine staged ERDDAP-only codes, 53 changed key (`MEGU`),
  **0 lost**; `check_dataset_taxon()` 0 findings; audit 96 agree / 68 explained (26 deprecated re-keys,
  41 override rows, 1 no-source-TSN). Override rows 37 → 75 (`match_column` → `ds_taxa_code`; 28 + 2
  unidentified classes; `SBIG`/`MEGU`; six ERDDAP-only birds whose TSN the generic path could not carry).
  **Found:** (a) `.apply_xref()` branch (c) fills only `worms_id` for a name-resolved row, so a bird with no
  source id can never key `itis:` without an override even when WoRMS links the TSN (`GUMU`, `MABO`,
  `NABO`) — D3's "name → AphiaID → TSN → itis:" hop is not implemented; (b) ERDDAP `_obs` has no 2021 rows
  (DataZoo had 625; farallon Q11); (c) ERDDAP now labels `CODO` "Delphinus sp." and `XCMU`
  "Synthliboramphus craveri" where the overrides key *D. delphis* and the genus (Q10).
