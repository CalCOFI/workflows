# Taxon id resolution: WoRMS ids for Farallon, and a generic fix across every taxa-bearing ingest

## Context

A consumer (`db-viz-hex::get_sp()`) matched taxa on `worms_id` and returned **zero rows for
every seabird and marine mammal**. The cause is upstream, in the release: of Farallon's
64,956 `obs` rows, **59,858 (92.2%) carry a taxon with no `worms_id` at all**. The consumer
was patched to fall back to `scientific_name`, which hides the symptom; this plan fixes the
data.

Verified against `data/releases/v2026.08.04/parquet/` and the live WoRMS/ITIS APIs:

| dataset | taxa | obs | obs with no `worms_id` | cause |
|---|---|---|---|---|
| `farallon_bird-mammal` | 128 | 64,956 | **59,858 (92.2%)** | 92 bird taxa keyed `itis:` — WoRMS never consulted |
| `cce-lter_zooscan` | 23 | 126,692 | 23,380 (18.5%) | 4 non-taxonomic classes (eggs/multiples/nauplii/others) |
| `sio_mesopelagic-fish` | 90 | 1,392 | 44 (3.2%) | 6 source column headers read `Bathophilus sp.` |
| `calcofi_phytoplankton` | 26* | 159,804 | 3,590 (2.2%) | 15 "other"/"undefined code" buckets + 1 junk row |
| other 5 taxa datasets | — | 850,450 | 0 | fine |

\* 394 `dataset_taxon` rows collapse to 26 distinct release taxa.

Three further defects surfaced while confirming this, each of which makes a wrong answer
look like a right one:

1. **`taxonomic_status` is fabricated.** All 2,090 keyed taxa read `accepted` — including the
   28 birds whose ITIS TSN is demonstrably *invalid*, and `GFSE`, whose own override note
   says "WoRMS status: unaccepted". `ensure_taxon_lineage()` stamps the literal string; it is
   never fetched. This is exactly the "not useful unless we know when it was last confirmed"
   problem, only worse — the value is asserted, not stale.
2. **28 Farallon birds have no lineage at all** (no rank, parent, kingdom, class, order or
   family) because their source TSN is deprecated in ITIS (`itis:174553` *Puffinus griseus* →
   accepted TSN 1255050 *Ardenna grisea*), and `.fetch_itis_chain()` does not follow
   `acceptedTSN`. Hierarchy rollups over these taxa silently match nothing.
3. **`metadata/taxon_override.csv` silently ignores most of its own rows** — see below.

### Confirmed: is `taxon_override.csv` generic?

**The file is generic; the code that applies it is not.** The schema
(`dataset_key, match_column, match_value, worms_id, itis_id, scientific_name, rank, review, note`)
is dataset-agnostic, but `.apply_overrides()` (`calcofi4db/R/taxa.R:131`) is called from
**exactly two hardcoded sites** — `taxa.R:175` (phyto, matching `ph$taxa`) and `taxa.R:230`
(bird-mammal, matching `bm$species_code`) — each passing a literal dataset name and a literal
match vector. The declared **`match_column` is never read anywhere in `R/`** (`grep` hits only a
comment and a test fixture). So a row added for `sio_mesopelagic-fish`, `cce-lter_zooscan`,
`swfsc_ichthyo`, `cce-lter_zoodb` or `cce-lter_euphausiids` is parsed and then dropped, with no
error. Same failure class as the unregistered-provider bug in `CLAUDE.md`. Making it genuinely
generic is part of this work.

### What WoRMS actually has (measured, not assumed)

`worrms::wm_record_by_external(tsn, type = "tsn")` is an **exact id crosswalk** — no fuzzy name
matching — and it returns the full record including `valid_AphiaID`, the real `status`, and
kingdom→genus classification. Probed against all 92 Farallon TSNs:

- **91/92 resolve.** The one miss is the trinomial `Pterodroma phaeopygia sandwichensis`
  (TSN 202225); its binomial resolves by name to `worms:405108`.
- 7 are unaccepted/superseded in WoRMS and must follow `valid_AphiaID`
  (`Sterna caspia` → `Hydroprogne caspia`, `Puffinus creatopus` → `Ardenna creatopus`, …).
- 90/91 return family-level classification directly.
- All 6 `sio_mesopelagic-fish` genera resolve once `" sp."` is stripped
  (`Nannobrachium` → junior synonym of `Lampanyctus`, AphiaID 125825).

WoRMS bird taxonomy does lag (it still calls these *Oceanodroma*, *Puffinus*, *Phalacrocorax*),
which is why **ITIS stays the key authority for birds** — `worms_id` is added as a
cross-reference column only.

## Decisions taken

- **Key on the authority's *accepted* id.** Deprecated ITIS TSNs are re-keyed
  (`itis:174553` → `itis:1255050`); the same rule applies to any WoRMS-keyed taxon whose real
  status turns out not to be accepted. Birds stay `itis:`; nothing flips to `worms:`.
- **Provenance is recorded, not lost** — new append-only `notes` + a `status_checked` date on
  `taxon` (below).
- **Backfill `itis_id` everywhere** (753 `worms:`-keyed taxa lack one) via `wm_external()`.
- **Leave the 19 genuinely non-taxonomic stubs unresolved**, but guard them so a *new*
  unresolved taxon fails loudly instead of hiding among them.

## Design

### 1. New: `calcofi4db/R/xref.R` — authority cross-reference

Mirrors the proven `fetch_taxon_lineage()` / `ensure_taxon_lineage()` pair in `R/lineage.R`
(cache-backed, offline on re-run, `na = ""`, scoped return).

```r
fetch_taxon_xref(itis_ids, worms_ids, names, cache_csv, refresh, sleep, verbose)
```
Resolution order per taxon, first hit wins:
1. `worrms::wm_record_by_external(tsn, type = "tsn")` — exact TSN → AphiaID
2. `worrms::wm_records_names(clean_taxon_name(name), marine_only = FALSE)` — name fallback
3. `worrms::wm_external(aphia, type = "tsn")` — reverse direction, fills `itis_id`

Always stores the **accepted** id (`valid_AphiaID` / ITIS `acceptedTSN`), the authority's
**real** `status`, and `checked_date`. Failures return `NULL` per taxon (never abort the batch),
matching `.fetch_worms_chain()`.

```r
ensure_taxon_xref(con, measurement_taxon, overrides, cache_csv = here("metadata/taxon_xref.csv"))
```
Notebook-facing wrapper called immediately **before** `ensure_taxon_lineage()`. Stages a
`_taxon_xref` table that `.taxon_norm_sources()` reads — the same staging contract
`ensure_taxon_lineage()` already uses for `_taxon_lineage_flat`, so every builder sees it and
tests can drive it entirely from a fixture CSV with no network.

**Registry `metadata/taxon_xref.csv`** (generated, reviewable, git-tracked — like
`taxon_lineage.csv`): `query_authority, query_value, source_name, worms_id, itis_id,
accepted_id, accepted_name, rank, status, checked_date, notes`.

### 2. New: `clean_taxon_name()` (exported, `R/xref.R`)

Regex normalizer for the recurring gotchas, applied to the **lookup name only**:

- open nomenclature: `" sp."`, `" spp."`, `" sp"`, `" cf. "`, `" cf "`, `" aff. "`, `" nr. "`
- qualifier prefixes: `"indistinguished "`, `"unidentified "`, `"undetermined "`, `"larval "`
- trailing variant letters (`"Pterosperma sp. a"`), parenthetical authorship, collapsed whitespace

**`ds_taxa_code` must not change.** For `sio_mesopelagic-fish` the code *is* the verbatim
column header (`taxa.R:213`) and is the join key from `obs`; cleaning is for the query only.
This generalizes the ad-hoc `name_query` column already baked into
`metadata/calcofi/phytoplankton/taxon_worms.csv`.

### 3. Make `taxon_override.csv` actually generic (`R/taxa.R`)

Rewrite `.apply_overrides()` to **dispatch on the declared `match_column`** against a named
list of candidate columns each arm exposes (e.g. bird-mammal offers `species_code`,
`common_name`, `scientific_name`), and call it from **every** arm of `.taxon_norm_sources()`
(`taxa.R:148-263`), not just phyto and bird-mammal. **Error loudly** when an override row names
a `dataset_key` or `match_column` no arm exposes — a typo must fail the ingest, not vanish.
This is what unblocks the 6 mesopelagic taxa and the 3 `(species group)` codes
(`DKSH`/`HYGU`/`XCMU`) via 9 reviewable override rows.

### 4. Re-key to the accepted id, with provenance (`R/taxa.R`)

`taxon_key_of()` (`taxa.R:40-58`) **stays byte-identical** — birds must still key `itis:` once
`worms_id` is populated. Re-keying happens upstream, in `.taxon_norm_sources()`, by replacing
`itis_id`/`worms_id` with the accepted id from `_taxon_xref` before `taxa.R:257` mints the key.
Each replacement emits a datestamped note:

```
2026-08-05: re-keyed itis:174553 (Puffinus griseus, source TSN) -> itis:1255050
            (Ardenna grisea, ITIS accepted)
```

The dataset's original code and name are already preserved in `dataset_taxon`
(`ds_taxa_code` / `ds_scientific_name`); the note records the *event*.

### 5. Two new `taxon` columns (additive)

Added to the `dplyr::select()` at `taxa.R:420-424` — the de-facto schema — and documented in
`metadata/core_dictionary.csv`:

| column | type | behavior |
|---|---|---|
| `notes` | VARCHAR | **Append-only.** Newline-delimited `YYYY-MM-DD: <text>` entries. Persisted in `taxon_xref.csv` so appends survive re-runs; never rewritten. |
| `status_checked` | DATE | **Rewritten** each time the authority re-confirms `taxonomic_status`. |

And `taxonomic_status` becomes the authority's **real** status instead of the hardcoded
`"accepted"` stamped at `lineage.R` (`ensure_taxon_lineage()`).

Additive columns are safe for `SELECT`-by-name consumers; the schema site regenerates.

### 6. Follow ITIS `acceptedTSN` for lineage (`R/lineage.R:64-79`)

`.fetch_itis_chain()` resolves an invalid TSN to its accepted TSN before requesting the
classification, so the 28 lineage-less birds get real ranks and parents. Parent chains stay
ITIS-native — `test-lineage.R:88-112` already asserts an ITIS-keyed taxon gets an ITIS parent,
and that assertion must keep passing.

### 7. Guard so this cannot silently return

New `check_taxon_ids(con, allow = ...)` in `calcofi4db/R/check.R`, called from a validation
chunk in `release_database.qmd` (next to the existing `core_parity` checks around line 441).
Reports per dataset: taxa and `obs` rows with no `worms_id`, no authority key, or no lineage.
**Fails the release** on anything outside an explicit allowlist of the 19 known non-taxonomic
stubs. Also drops the junk `calcofi_phytoplankton:NA` row (6 blank trailing rows in
`metadata/calcofi/phytoplankton/taxon_worms.csv`).

### 8. Tests (`calcofi4db/tests/testthat/`, all offline from fixtures)

Extend `test-taxa.R` / `test-lineage.R` and add `test-xref.R`:

- **regression**: a bird with both ids still keys `itis:` — `taxon_key_of(137133L, 176974L, is_bird = TRUE) == "itis:176974"`
- an `itis:`-keyed taxon carries a non-NULL `worms_id` after `ensure_taxon_xref()`
- a deprecated TSN re-keys to the accepted TSN **and** appends exactly one datestamped note
- a second run appends **no duplicate** note (append-only, idempotent)
- `clean_taxon_name()` table-driven cases (`"Bathophilus sp."` → `"Bathophilus"`, `"Phaeocystis cf pouchetti"` → `"Phaeocystis pouchetti"`, …)
- `ds_taxa_code` is unchanged by cleaning (guards the `obs` join)
- an override row for an unknown `dataset_key`/`match_column` **errors**
- `check_taxon_ids()` fails on an unresolved taxon outside the allowlist

Bump `calcofi4db` to **3.6.0** with a matching `NEWS.md` entry in the same change
(per `../CLAUDE.md`).

## Files to change

**`/Users/bbest/Github/CalCOFI/calcofi4db/`**
- `R/xref.R` *(new)* — `fetch_taxon_xref()`, `ensure_taxon_xref()`, `clean_taxon_name()`
- `R/taxa.R` — generic `.apply_overrides()` (131), every arm of `.taxon_norm_sources()` (148-263),
  accepted-id re-key before the key mint (257), `notes`/`status_checked` in the select (420-424)
- `R/lineage.R` — `.fetch_itis_chain()` follows `acceptedTSN` (64-79); stop stamping
  `taxonomicStatus = "accepted"`
- `R/check.R` — `check_taxon_ids()`
- `tests/testthat/test-xref.R` *(new)*, `test-taxa.R`, `test-lineage.R`
- `DESCRIPTION` + `NEWS.md` — 3.6.0

**`/Users/bbest/Github/CalCOFI/workflows/`**
- `ingest_farallon_bird-mammal.qmd` — add `ensure_taxon_xref()` before `ensure_taxon_lineage()`
  (currently line 377); same one-line insert in each of the other 8 taxa-bearing ingests
  (`calcofi_phyllosoma` 197, `calcofi_phytoplankton` 261, `cce-lter_euphausiids` 674,
  `cce-lter_zoodb` 535, `cce-lter_zooscan` 488, `sio_mesopelagic-fish` 436, `swfsc_cufes` 207,
  `swfsc_ichthyo` 1333, `cdfw_dungeness-crab` 625)
- `metadata/taxon_override.csv` — +9 rows (6 mesopelagic genera, 3 Farallon species groups)
- `metadata/taxon_xref.csv` *(new, generated)*
- `metadata/core_dictionary.csv` — document `notes`, `status_checked`
- `metadata/calcofi/phytoplankton/taxon_worms.csv` — drop 6 blank trailing rows
- `metadata/farallon/bird-mammal/questions.csv` — one `proposed` question on the species-code
  semantics the overrides assume (`CODO`/`SBCD` and `CSLI`/`CASL` each merge to one taxon;
  `PIWH` is genus-level; `LBCD` is a nomen dubium)
- `release_database.qmd` — `check_taxon_ids()` validation chunk near `core_parity` (~line 441)

## Verification

```r
# 1. package: red test is a hard stop
setwd("../calcofi4db"); devtools::document(); devtools::test(); devtools::install()
```

```r
# 2. re-run every taxa-bearing ingest. .qmd edits are NOT tracked — invalidate first,
#    and do not name the loop variable `t` (resolves to base::t). See CLAUDE.md.
setwd("../workflows")
tgts <- c("ingest_farallon_bird_mammal", "ingest_sio_mesopelagic_fish",
          "ingest_calcofi_phytoplankton", "ingest_cce_lter_zooscan", "ingest_cce_lter_zoodb",
          "ingest_cce_lter_euphausiids", "ingest_calcofi_phyllosoma", "ingest_swfsc_cufes",
          "ingest_swfsc_ichthyo")
for (tgt in tgts) targets::tar_invalidate(names = tidyselect::all_of(tgt))
for (tgt in tgts) targets::tar_make(names = tidyselect::all_of(tgt))
```
Confirm each actually ran — check `_output/*.html` mtime, not a hash comparison (an unchanged
hash means "did not run" just as readily as "ran and matched").

```r
# 3. reassemble the release
targets::tar_invalidate(names = tidyselect::all_of("release_database"))
targets::tar_make(names = tidyselect::all_of("release_database"))
```

```sql
-- 4. assert against the NEW release parquet (duckdb CLI, in the release parquet dir)
-- a. no bio obs left without a worms_id outside the 19 allowlisted stubs
SELECT o.dataset_key, count(*) FROM obs.parquet o
  LEFT JOIN 'taxon.parquet' t USING (taxon_key)
 WHERE o.taxon_key IS NOT NULL AND t.worms_id IS NULL GROUP BY 1;
-- expect: only calcofi_phytoplankton (~3,590) and cce-lter_zooscan (~23,380). Farallon = 0.

-- b. Farallon birds are reachable by worms_id, and still keyed itis:
SELECT count(*) FILTER (WHERE t.worms_id IS NOT NULL) has_worms,
       count(*) FILTER (WHERE t.taxon_key LIKE 'itis:%') keyed_itis, count(*) n
FROM 'dataset_taxon.parquet' dt JOIN 'taxon.parquet' t USING (taxon_key)
WHERE dt.dataset_key = 'farallon_bird-mammal';
-- expect has_worms 125 of 128 (3 species groups resolve to genus via override -> 128)

-- c. lineage repaired: no Farallon taxon without a family, except the 3 species groups
SELECT count(*) FROM 'dataset_taxon.parquet' dt JOIN 'taxon.parquet' t USING (taxon_key)
WHERE dt.dataset_key='farallon_bird-mammal' AND t.family IS NULL;   -- was 31

-- d. status is no longer a fabricated constant, and is dated
SELECT taxonomic_status, count(*), min(status_checked), max(status_checked)
FROM 'taxon.parquet' GROUP BY 1;                       -- expect >1 distinct status

-- e. re-keying left nothing dangling
SELECT count(*) FROM 'obs.parquet' WHERE taxon_key IS NOT NULL
  AND taxon_key NOT IN (SELECT taxon_key FROM 'taxon.parquet');           -- 0
SELECT count(*) FROM 'taxon.parquet' WHERE parent_taxon_key IS NOT NULL
  AND parent_taxon_key NOT IN (SELECT taxon_key FROM 'taxon.parquet');    -- 0
```

```bash
# 5. consumers — the reported bug, end to end
ssh calcofi
docker exec -d rstudio bash -lc 'cd /share/github/CalCOFI/db-viz-hex && Rscript prep_db.R'
touch /share/github/CalCOFI/db-viz-hex/app/restart.txt
# then in the app: pick a seabird (e.g. Common Murre) and confirm it returns rows
# through the worms_id path with ck_children = TRUE — the scientific_name fallback
# should no longer be doing the work.
```

## Risks

- **Re-keying changes `taxon_key` for ~28 taxa** (possibly more once real WoRMS statuses come
  back — the count is reported by the run, not assumed). Every consumer caching `taxon_key`
  must re-prep. `obs`/`obs_attribute` regenerate from `dataset_taxon` at emit time, so a full
  ingest + release re-run is mandatory, not optional.
- **`swfsc_ichthyo` is the heavy one** (1,149 taxa, and the only notebook calling
  `prune_taxon_shard()`); the `itis_id` backfill adds ~753 one-time cached `wm_external()`
  calls across all datasets. Run it once, commit `metadata/taxon_xref.csv`, and re-runs are free.
- **Do not re-enable `mermaid-format: png`** to inspect the ERD — it wedges headless Chrome
  indefinitely (`CLAUDE.md`).
- `worrms`/`taxize` are `Suggests`, not `Imports`; every new call site keeps the existing
  `requireNamespace(..., quietly = TRUE)` guard so a fixture-driven test runs without them.
