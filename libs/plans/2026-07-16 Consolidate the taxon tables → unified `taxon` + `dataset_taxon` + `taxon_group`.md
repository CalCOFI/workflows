# Taxon + attribute schema cleanup: `taxon`/`dataset_taxon`/`taxon_group`, `obs_attribute`, supplemental tier

> (The env–bio consolidation — `obs`/`sample`/`obs_freq`/`sample_measurement`/
> `obs_ctd_full` — shipped in `v2026.07.15`. This is the follow-on schema cleanup,
> revised per the user's detailed direction.)

## Context / problem

`cc_get_db()` on `v2026.07.15` lists **53 tables**; the ERD advertises 22. Two
causes: (1) the published release was frozen **before** release_database.qmd's
`core_keep` retire filter (L1067) landed, so a clean re-freeze already takes
53 → ~21; (2) even at ~21 the **taxon area is a mess** — 7 per-dataset taxon
tables (`species`, `taxon`, `taxa_rank`, `phyto_taxon`, `zoodb_taxon`,
`zooscan_taxon`, `bird_mammal_species`), each a different schema and id space,
that duplicate (Appendicularia is a separate row in `zoodb_taxon` **and**
`zooscan_taxon` at the same AphiaID 146421). `obs.taxon_id` is a `VARCHAR` holding
a *different dataset-local id per dataset* (ichthyo `species_id`, zoodb/zooscan
`taxon_id`, bird `species_code`, NULL elsewhere), so it collides across datasets,
FKs into nothing, and `calcofi4r/R/match.R` + `db-query/lib/match.js` resolve
**only ichthyo** (`CAST(taxon_id AS INTEGER)=species.species_id`). The design doc
called for a unified `taxa` that was never built. The station portal
`build_vars.sql` already hand-rolls a taxa UNION keyed on `aphia_id`, confirming
the need.

## Target model (revised)

### 1. `taxon` — one authoritative row per taxon

- `taxon_key` VARCHAR PK = **all-lowercase** authority prefix + `:` + id.
  **`worms:<worms_id>` for everything, except birds (class = Aves) →
  `itis:<itis_id>`** (e.g. Great Cormorant → `itis:174715`, not `worms:137179`).
- Explicit integer crosswalk cols `worms_id`, `itis_id`, + placeholders
  `gbif_id`, `ncbi_id`, `inat_id`.
- `scientific_name`, `common_name` (one best), `rank`, `rank_order` (fold in
  `taxa_rank`), `taxonomic_status`, `parent_taxon_key` (self-FK; keep WoRMS
  ancestor rows for hierarchy traversal), lineage
  `kingdom/phylum/class/order/family` (needed for the Aves rule + grouping).

### 2. Resolve **all** taxa — no lazy NULLs (do the lookups)

Per the user: coarse/composite taxa get resolved to real WoRMS/ITIS ids via
**explicit, reviewable crosswalk CSVs** (ids filled in now; unit-tested). The
"taxon-in-the-type-name" cases are **decomposed** so `obs.taxon_key` is populated
and `measurement_type` is clean — normalization *and* queryability:

| dataset | today (un-normalized) | resolved to |
|---|---|---|
| **euphausiids** | one type `euphausiid_abundance`, taxon NULL | **Euphausiidae** `worms:110671`; `measurement_type='abundance'` |
| **cufes** | `sardine_eggs / anchovy_eggs / hake_eggs / jack_mackerel_eggs / squid_eggs / other_fish_eggs` | `taxon_key` = *Sardinops sagax / Engraulis mordax / Merluccius productus / Trachurus symmetricus / squid (Teuthida) / coarse fish (Teleostei)*; `life_stage='egg'`; `measurement_type='abundance'` |
| **phyllosoma** | `total_phyllosoma` + `phyllosoma_stage_1..11` | `taxon_key` = *Panulirus interruptus*; `total_phyllosoma`→`obs` (`abundance`, `life_stage='phyllosoma'`); `phyllosoma_stage_N`→`obs_attribute` (`measurement_type='stage'`, `value=N`, `count`=value) |
| **phyto** (90 NULL-aphia coarse groups) | `diatom, centric/pennate`, `dinoflagellate, thecate/athecate`, `coccolithophore`, `silicoflagellate`, `other/undefined` | WoRMS class: diatoms→**Bacillariophyceae** `worms:148899`, dinoflagellates→**Dinophyceae**, coccolithophores→**Coccolithophyceae/Prymnesiophyceae**, silicoflagellates→**Dictyochophyceae**; `other/undefined`→coarse fallback (Chromista) flagged in CSV |

Crosswalk CSVs live under `metadata/{provider}/{dataset}/measurement_taxon.csv`
(raw_measurement_type → scientific_name, worms_id/itis_id, canonical
measurement_type, life_stage) and a shared `metadata/taxon_coarse.csv` for the
functional-group→WoRMS-class mappings. Coarse "other/squid/other_fish" choices
are marked `review=TRUE` for a human pass. **Phyto obs are also projected into
`obs`** (grid_key NULL, region-pooled) now that its taxa resolve — leaving phyto
out would be the lazy path.

### 3. `dataset_taxon` — per-dataset vocabulary crosswalk (provenance)

- `ds_taxon_key` VARCHAR PK = **lowercase** prefix + `:` + local id, using a
  known-list prefix where one exists: `calcofi:{species_id}` (ichthyo/invert
  share the CalCOFI species list), else `{dataset_key}:{code}` (e.g.
  `cce-lter_zoodb:3`, `calcofi_bird_mammal_census:anmu`).
- `dataset_key`, `taxon_key`→`taxon`, `ds_common_name`, `ds_scientific_name`,
  `ds_taxa_code` (raw local id as VARCHAR).

### 4. `taxon_group` — groupings (was the vague "taxon_list")

- `taxon_group_key` VARCHAR = **lowercase** prefix + `:` + group
  (`calcofi:forage_fish`, `calcofi_phytoplankton:diatom_centric`).
- `description`; **many `taxon_key` per `taxon_group_key`** (membership rows).
- Seed from dataset-provided groupings (phyto functional groups, bird/mammal
  `is_bird`/`is_mammal`/`is_fish` flags); curated `calcofi:*` groups added later.

### 5. `obs_freq` → **`obs_attribute`** (generalized sub-occurrence grain)

Rename + generalize `obs_freq` to hold *any* sub-occurrence attribution —
length-frequency, stage-frequency, **behavior** — folding in
`bird_mammal_behavior` (drop that lookup table). Columns: `obs_attribute_id` PK,
`dataset_key`, `sample_key`→sample, `taxon_key`→taxon, `life_stage`,
`measurement_type`→measurement_type (the attribute: `body_length`/`stage`/
`behavior`), `value` (DOUBLE — bin_value / stage no.), `label` (VARCHAR —
`preflexion`, `Flying`…), `count` (INTEGER), `measurement_qual`. Bird/mammal
behavior becomes `measurement_type='behavior'`, `label=`{Flying,Feeding,…},
`count`=n. (Per-occurrence *scalars* like zooscan `feret_diameter` stay in `obs`,
not here — `obs_attribute` is for distributions/breakdowns within an occurrence.)

### 6. `measurement_type`: decompose composites + add `grain`

- Remove the composite entries (`*_eggs`, `phyllosoma_stage_*`, `total_phyllosoma`,
  `euphausiid_abundance`) — replaced by clean canonical types + the crosswalk.
- Add a **`grain` column** (`obs` | `sample` | `attribute`) so the schema site
  and validation know which grain each type serves (`abundance`/`biomass`/env →
  obs; `volume_sampled`/`std_haul_factor` → sample; `body_length`/`stage`/
  `behavior` → attribute). `measurement_type` stays the single shared vocabulary
  lookup for `obs`, `sample_measurement`, **and** `obs_attribute`.

### 7. Supplemental tier for `obs_ctd_full` (generate + host, hide by default)

`obs_ctd_full` (216M CTD scans) is **generated, uploaded to GCS, and tagged to
this DB version**, but is an ancillary dataset-specific table — **excluded from
the ERD diagram and the default table list**, surfaced only for deep-dive users:

- release_database.qmd: new `supplemental_keep` set (just `obs_ctd_full`); upload
  its parquet; add a **`supplemental` boolean** to `catalog.json` `tables` and to
  `metadata.json`; **exclude it from `erd.mmd`** and the ERD table set.
- `calcofi4r::cc_get_db(..., supplemental = FALSE)` — new arg; default drops
  `supplemental` rows before building views. `supplemental=TRUE` includes them.
- `db-schema` site (`app.js`): render supplemental tables in the Tables tab with
  a distinct badge, **filtered out of the ERD** (which reads `erd.mmd`).

### Final table inventory (≈15 default + 1 supplemental)

`obs, sample, obs_attribute, sample_measurement` (core) · `grid, cruise, ship,
measurement_type, dataset, region` (refs) · `taxon, dataset_taxon, taxon_group`
(taxa) · `lookup` (ichthyo life-stage labels) · `_spatial`/`_spatial_attr`
(internal). **Supplemental:** `obs_ctd_full`. Dropped: the 7 per-dataset taxon
tables, `taxa_rank`, `bird_mammal_behavior`, all per-dataset event/measurement
tables (already retired by `core_keep`).

## Rollout

**Code-ready** (established convention): I implement + unit-test + light
render/verify; the user runs the heavy `tar_make()` / `obs_ctd_full` re-freeze /
GCS upload. Cut a new release (`v2026.07.16`), repoint consumers, let
`test_release.qmd` gate promotion, then promote `latest.txt` + redeploy apps.
Consumers pinned to `v2026.07.15` keep working; `latest` flips only after the gate.

---

## Workstreams

**WS1 — `calcofi4db` engine + tests.** Extend `R/taxonomy.R` (reuse
`standardize_species_local()`, `build_taxon_hierarchy()`): `taxon_key_of(worms_id,
itis_id, class)` (Aves→itis rule; regression fixture = cormorant `itis:174715`);
`build_taxon_reference()` (UNION + dedup on `taxon_key`, fold `rank_order`, apply
the coarse/composite crosswalks); `build_dataset_taxon()`; `build_taxon_group()`.
In `R/model.R`: rename `taxon_id`→`taxon_key` in the obs/obs_freq DDL + append
fns + arm helpers (L58-88, L158-196, L535-611); rename `.ensure_obs_freq_schema`/
`append_obs_freq`/`obs_freq`→**`obs_attribute`** with the generalized columns
(`value`/`label`/`count`). Tests: `taxon_key_of`, Appendicularia dedup
(zoodb+zooscan→one `worms:146421`), cufes/phyllosoma decomposition, phyto coarse
resolution. `document()` + `install()`.

**WS2 — `release_database.qmd`.** Call the three builders; rewrite bio `obs` arms
(L439-485) + the attribute arm (L493-504) to resolve `taxon_key` via crosswalks
and split composites (cufes→egg abundance; phyllosoma total→obs, stages→
obs_attribute; euphausiids→Euphausiidae; **add phyto arm**); fold behavior into
`obs_attribute`. Rebuild `measurement_type` from the CSV incl. `grain`; drop
composite entries. Update `core_keep` (add `taxon,dataset_taxon,taxon_group`;
drop the 7 taxon tables + `taxa_rank` + `bird_mammal_behavior`; `obs_freq`→
`obs_attribute`); add `supplemental_keep={obs_ctd_full}` + `supplemental` flag in
catalog/metadata; exclude it from `erd.mmd`. Extend parity checks (taxon FK,
dedup, decomposition sum-parity: cufes egg totals, phyllosoma stage sum ==
total). Update `relationships_cross.csv`, release notes, metadata.json filters.

**WS3 — consumers (repoint).** `calcofi4r/R/match.R` ⟷ `db-query/lib/match.js`
(byte-lockstep, CI-verified): `taxon_id`→`taxon_key`; replace the ichthyo-only
join with `JOIN taxon ON taxon_key`; rebuild `cc_match_ichthyo_by_taxon(worms_id)`
from unified `taxon` (`worms_id`+`parent_taxon_key`); bump `match.js` VERSION.
`db-query/lib/options-sources.js`: species picker from `taxon`. `db-viz-hex`
`prep_db.R`+`app/global.R`: `keep_tables`→`obs,sample_measurement,taxon,
dataset_taxon`; bio_obs joins `obs.taxon_key→taxon`; picker + `taxa_tree_builder`
from `taxon`. Station portal `build_vars.sql` L27-37 → `SELECT FROM taxon`.
`calcofi4r::cc_get_db()` gains `supplemental=FALSE`. `apps/querychat/global.R`
schema-doc strings (legacy) noted.

**WS4 — metadata + docs.** New crosswalk CSVs (`measurement_taxon.csv` per
cufes/phyllosoma/euphausiids, shared `taxon_coarse.csv`); `measurement_type.csv`
(+`grain`, composites removed); `field_dictionary.csv` (register `taxon_key`,
`ds_taxon_key`, `taxon_group_key`, `worms_id`/`itis_id`/`gbif_id`/`ncbi_id`/
`inat_id`, `obs_attribute` cols, `supplemental`). Update `workflows/CLAUDE.md`,
`design_env-bio-consolidation.md`, `db-schema` docs (mention the supplemental
tier), memory `project_obs_consolidation.md`.

**WS5 — release + deploy (user runs heavy steps).** `v2026.07.16`: full
`tar_make()` + `obs_ctd_full` re-freeze + GCS upload → `test_release.qmd` gate →
promote `latest.txt` → redeploy `db-viz-hex`/`db-viz-cruise`, refresh station
portal, rebuild `db-query`/`db-schema` Pages.

---

## Verification

- **Unit** (`devtools::test()` in calcofi4db): cormorant `itis:174715`;
  Appendicularia → one `worms:146421` (zoodb & zooscan both resolve to it); cufes
  `sardine_eggs`→(Sardinops sagax, egg, abundance); phyllosoma stage-sum ==
  total; phyto coarse groups → WoRMS classes; `obs_attribute` behavior fold.
- **End-to-end (local, no re-ingest):** render `core_tables`+`core_parity`
  against `data/parquet/*`; parity `stopifnot`s pass; **every non-NULL
  `obs.taxon_key`/`obs_attribute.taxon_key` FKs `taxon`** (no NULLs for
  euphausiids/cufes/phyllosoma/phyto anymore). Confirm fresh `catalog.json` lists
  only the default set (~15) with `obs_ctd_full` flagged `supplemental=TRUE`, and
  `erd.mmd` omits it.
- **Consumers:** `match.R`/`match.js` emit identical SQL and a non-ichthyo dataset
  (zoodb) now resolves a scientific name; `cc_get_db()` default excludes
  `obs_ctd_full`, `cc_get_db(supplemental=TRUE)` includes it; db-schema Tables tab
  badges it and the ERD omits it; station portal var list reproduces from
  `SELECT FROM taxon`.
- **Full release + heavy CTD re-freeze:** user-run, gated by `test_release.qmd`
  before `latest` promotion.
