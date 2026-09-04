---
name: taxon-reference
description: "How CalCOFI taxa reach the release — taxon/dataset_taxon/taxon_group, worms: vs itis: keys, ensure_taxon_xref() then ensure_taxon_lineage(), measurement_taxon.csv and taxon_override.csv, rank and lineage traps, the check_taxon_ids() gate. Load before editing taxon code in an ingest, calcofi4db/R/taxa.R or a taxon metadata CSV."
---

# Shared taxonomy references

Shared taxonomy refs (built by `calcofi4db/R/taxa.R`, replacing the ~7 per-dataset
taxon tables): **`taxon`** (one row per taxon, `taxon_key` = lowercase authority
prefix `worms:<id>` — or `itis:<id>` for birds/Aves — + `worms_id`/`itis_id`/
`gbif_id`/`ncbi_id`/`inat_id`, `parent_taxon_key`, lineage), **`dataset_taxon`**
(per-dataset vocabulary → `taxon_key` crosswalk; `obs` resolves `taxon_key` by
joining it on `(dataset_key, ds_taxa_code)`), **`taxon_group`** (groupings). Built
by `build_taxon_reference()` / `build_dataset_taxon()` / `build_taxon_group()`.
Coarse/composite taxa (cufes eggs, phyllosoma stages, euphausiid family, phyto
functional groups, seabirds/mammals) resolve to real WoRMS/ITIS ids via the
reviewable `metadata/measurement_taxon.csv` + `metadata/taxon_override.csv`.

## The four calls: the ingest declares, the package resolves (calcofi4db ≥ 4.0.0)

There are **no per-dataset arms in `calcofi4db`**. 4.0.0 deleted all seven — the
`species` (ichthyo), `phyto_taxon`, `zoodb_taxon`, `zooscan_taxon`,
`euphausiids_taxon`, `mesopelagic_fish_taxon` and `bird_mammal_species` readers — for
the reason 3.0.0 deleted the core-projection `switch()` arms: the contract was
implicit, so a column renamed or dropped in a notebook changed the taxonomy silently
(dropping `itis_id` from the Farallon species table would have un-keyed every seabird,
92 % of that dataset's observations, with no error anywhere).

A taxon-bearing ingest calls these, in this order, **before `append_obs()`** —
`ingest_farallon_bird-mammal.qmd` is the worked example, and
`.claude/skills/templates/ingest_template.qmd` carries the commented skeleton:

1. **`append_dataset_taxon(con, dataset_key, df, ds_prefix = dataset_key)`** — the
   declaration. `ds_taxa_code` (the code `obs` stores, **verbatim**) and
   `ds_scientific_name` are required; `ds_common_name`, `worms_id`, `itis_id`,
   `gbif_id`, `rank` are optional and are what **the source supplied**, stored
   together as `ds_source_json`. A missing or unknown column, a duplicate or NA code,
   or an id that does not coerce to an integer is an **error at ingest**. `ds_prefix`
   is the `dataset_key` except for the shared CalCOFI species list (`"calcofi"`).
2. **`ensure_taxon_xref()`** then 3. **`ensure_taxon_lineage()`** — in that order; the
   lineage fetch must ask about the accepted id, and its `class` is what decides the
   key authority.
4. **`resolve_dataset_taxon()`** (+ `build_taxon_reference()`,
   `build_taxon_group(con, read_taxon_group_rules(...))`, and `prune_taxon_shard()` where
   the connection holds a broader hierarchy) — fills `taxon_key` **in place** on the
   staged rows, so every other column comes back byte-identical and a re-run over
   unchanged inputs is a no-op.
5. **`check_dataset_taxon(con, dataset_key, codes =, allow =)`** — the ingest asserts its
   own crosswalk: every code the observations reference is staged, every staged row keys
   an authority id unless `allow`-listed **one key at a time with a reason**, every Aves
   taxon keys `itis:`. Halts the render.

An ingest that has **not** migrated errors at `resolve_dataset_taxon()`, naming the
working table it left in the connection. The **composite-measurement path is untouched**:
`swfsc_cufes`, `calcofi_phyllosoma` and `cdfw_dungeness-crab` resolve through
`metadata/measurement_taxon.csv` exactly as before, and a dataset that stages has its
`measurement_taxon` rows ignored as a vocabulary (this is what removed the unreferenced
`cce-lter_euphausiids:euphausiidae` row).

A `taxon_override.csv` `match_column` is now one of `dataset_taxon`'s own `ds_taxa_code` /
`ds_scientific_name` / `ds_common_name`. The arms' column names (`taxa`, `species_code`,
`species_id`, `taxon_id`) went with the arms.


**Lineage is not free — call `ensure_taxon_lineage()` before the builders.**
`build_taxon_reference()` takes `rank` / `parent_taxon_key` / classification from
a DwC-shaped hierarchy table named `taxon` in the connection. Exactly one ingest
built one (`swfsc_ichthyo`, via `build_taxon_hierarchy()`), so every other
dataset's taxa reached the release with a key and a name and **nothing else** —
0 ranks, 0 parents, no classification — and hierarchy rollups ("all Decapoda")
silently matched nothing with no error anywhere.
`ensure_taxon_lineage(con, mt_taxon, tx_over, cache_csv = here("metadata/taxon_lineage.csv"))`
fetches each taxon's WoRMS (or ITIS, for Aves) classification, caches it in
`metadata/taxon_lineage.csv` so re-runs cost no API calls, and stages it as that
same `taxon` table — plus the flattened `kingdom`/`phylum`/`class`/`order_taxon`/
`family`, which no dataset ever populated. Ancestors become `taxon` rows too, so
`parent_taxon_key` chains resolve; `prune_taxon_shard()` keeps the transitive
parent closure when trimming a shard. `ncbi_id`/`inat_id` stay declared-but-NULL:
no source supplies them, and dropping the columns would change the release schema
under consumers.

**The key authority and the id columns are different questions — call
`ensure_taxon_xref()` before the lineage fetch.** Birds key `itis:` because WoRMS
bird taxonomy lags (it still says *Oceanodroma*, *Puffinus*, *Phalacrocorax*), and
that rule is right. But nothing populated the `worms_id` **column** for them, so a
consumer joining on `worms_id` matched **zero rows for every seabird and marine
mammal** — 59,858 of the Farallon census's 64,956 `obs` rows, 92.2% of the
dataset, with no error anywhere.
`ensure_taxon_xref(con, mt_taxon, tx_over, cache_csv = here("metadata/taxon_xref.csv"))`
crosswalks TSN→AphiaID with `worrms::wm_record_by_external(type = "tsn")` — an
**exact id crosswalk, not a name match** (91 of the 92 Farallon bird TSNs resolve
through it) — backfills `itis_id` the other way via `wm_external()`, and falls
back to `wm_records_name()` on `clean_taxon_name()` output for taxa carrying
neither id. Three things to keep straight:
- **A key must be an *accepted* id; a cross-reference is whatever the authority
  links.** A deprecated ITIS TSN is re-keyed (`itis:174553` *Puffinus griseus* →
  `itis:1255050` *Ardenna grisea*) and the event lands in the append-only
  `taxon.notes`; the TSN `wm_external()` returns for an AphiaID is stored verbatim.
- **`clean_taxon_name()` output is the lookup query, never `ds_taxa_code`.** For
  `sio_mesopelagic-fish` the local code *is* the verbatim spreadsheet header
  (`Bathophilus sp.`) and is the join key from `obs` — rewriting it orphans every
  observation of that taxon.
- **`taxonomic_status` was fabricated.** It was the literal string `"accepted"`
  stamped by `ensure_taxon_lineage()` onto all 2,090 taxa, including 28 whose ITIS
  TSN is demonstrably deprecated. It is now fetched, and carries `status_checked` —
  read the two together, a status with no check date is not a fact.

`release_database.qmd`'s `taxon_authority_coverage` chunk gates this:
`check_taxon_ids()` **fails the release** on a dataset-local `taxon_key` that is
not in its explicit allowlist, so the 18 genuinely non-taxonomic classes (zooscan
eggs/multiples/nauplii/others, phyto "other"/"undefined code") are declared one
key at a time and a new unresolved taxon cannot hide among them.

**Lineage ancestors are first-class taxa, and rank ordering is not one dataset's
job.** Two gaps that looked unrelated turned out to share a cause — a taxon was
treated as second-class because of *how it entered the release* rather than what
it is:
- `rank_order` came from a `taxa_rank` table built by an inline vector inside
  `build_taxon_hierarchy()`, which only `swfsc_ichthyo` calls. It existed in that
  one connection and nowhere else, so **100% of ITIS-keyed taxa** and 252
  WoRMS-keyed ones released with the column NULL. It is now
  `calcofi4db::taxa_rank_reference()` — the single vocabulary, covering both
  authorities' rank sets (including `Section`/`Subsection`, which WoRMS nests
  *below* Infraorder for decapods, not between order and family as in botany).
- `.lineage_flat()` emitted one row per *requested* id, so an ancestor arrived
  with a key, a name, a rank and no classification — 430 of ichthyo's taxa at or
  below family rank had neither `family` nor `kingdom`, in both authorities
  alike. It now emits one row per distinct taxon, deriving each node's
  classification from its own ancestors-or-self. No API call: the chains already
  contain them.

When asserting coverage, **split by rank position**. `family` is legitimately
NULL above family rank (a phylum has no family) and `kingdom` is NULL for
`worms:1` Biota (rank Superdomain, above Kingdom). A blanket non-NULL assertion
is wrong and will be "fixed" by someone inventing data.

Ancestor ids are topped up by `ensure_taxon_lineage()`, not `ensure_taxon_xref()`
— the xref step must run *first* (so the lineage fetch asks about the accepted
id) and therefore only ever sees the dataset's own vocabulary. `.apply_xref()`
takes `rekey = FALSE` there: an ancestor's key comes from the chain it was
fetched in, so its ids may be filled but never replaced.

**An override never replaces an id the source supplied** (Ben, 2026-09-04;
calcofi4db ≥ 3.33.0, `.apply_overrides()` / `report_taxon_overrides()`). A
`taxon_override.csv` row exists for the rows the source could *not* resolve, so:
- a row matched on a **non-code** column (`ds_common_name`, `ds_scientific_name`;
  the phyto arm's `taxa`) applies **only** to vocabulary rows whose source supplied
  no `worms_id` / `itis_id` (nothing in `ds_source_json`);
- a row matched on the dataset's own **code** (`ds_taxa_code`; the arms'
  `species_code` / `species_id` / `taxon_id`) is a statement about that one row and
  applies **always** — and wins over a non-code row on the same vocabulary row,
  whatever order the registry lists them in.

v2026.08.25 released **22** `taxon_key`s for **393** phytoplankton codes: six
`taxa`-matched rows ("diatom, centric" → Bacillariophyceae, …) replaced the AphiaID
of every species in their group, so 287 species-resolved codes keyed their class.
The functional group is a `taxon_group.csv` rule, not a key. `resolve_dataset_taxon()`
messages what each override matched / applied / skipped and stages it as
`_taxon_override_report`; `report_taxon_overrides(con, tx_over)` recomputes the
same table from `dataset_taxon` (+ `ds_source_json`) at release — `n_skipped` is
`NA` with `source_json_known = FALSE` for a shard that predates the column, never a
wrong zero. A skip is the rule working; it is reported so it is never silent.

**A group label is never a `common_name`.** `apply_taxon_common()` rank 4 (other
datasets' `ds_common_name`) refuses any `match_value` of a `dataset_taxon` rule in
`taxon_group.csv` (pass `group_rules = read_taxon_group_rules(...)`) and the label of
any dataset-local key — "diatom, centric", "other", "undefined (code not in source
definitions; Q05)", zooscan "nauplii" were being published as the common name of
every taxon in the group (24 taxa on the v2026.08.25 fixture). Counted as
`other_excluded_label`; the group's own name in `taxon_group` is untouched.

**A bird with no source id keys `itis:` through name → AphiaID → linked TSN.**
`.apply_xref()` branch (c) fills `worms_id` from the name match *and* takes the TSN
`wm_external()` links to that AphiaID (`ensure_taxon_xref()` fetches it in a third
pass, cached); the class from the WoRMS chain says Aves, so `taxon_key_of()` keys
`itis:`. Until 3.33.0 only `worms_id` was filled, so Farallon's `GUMU` / `MABO` /
`NABO` needed override rows for a hop the authorities already answered. A TSN the
row carries is never replaced; a name WoRMS links no TSN to (`SCMU`, `TOSP`, `CHSP`)
still needs its row.

> Moved out of the root `CLAUDE.md` on 2026-09-03 so it loads on demand; the hard rules stay resident there. Edit this file, not both.
