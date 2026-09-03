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

> Moved out of the root `CLAUDE.md` on 2026-09-03 so it loads on demand; the hard rules stay resident there. Edit this file, not both.
