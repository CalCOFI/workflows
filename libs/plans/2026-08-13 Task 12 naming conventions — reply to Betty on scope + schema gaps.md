**To:** Betty Huang <bhuang0022@gmail.com>
**Cc:** ben@oceanmetrics.io
**Subject:** Re: Task 12: naming conventions: scope check + schema gaps
**Date:** 2026-08-13

---

Hi Betty,

I dug into all of this. Short version: your scoping instinct is right that the conventions already exist — but they exist in **three different documents that disagree with each other and with the actual database**, which is worse than not existing, because anyone following them today would be following a database we stopped having. That reconciliation *is* Task 12's product (1), and it's real work, not duplicated work.

On top of that, four of your five questions landed on genuine gaps in the data itself, a couple of them serious. Details below, then a proposed split.

---

## 1. Is the schema the standard?

**Yes — but there are three normative statements of it, and only one is current.**

| document | status |
|---|---|
| [`docs/db.qmd`](https://github.com/CalCOFI/docs/blob/main/db.qmd) → "Database naming conventions" | The published guide. Last substantively touched 2026-05-19; predates the `obs`/`sample` consolidation and the unified taxon work. |
| [`workflows/README_PLAN.qmd`](https://github.com/CalCOFI/workflows/blob/main/README_PLAN.qmd) §"Database Naming Conventions" + §"Primary Key Strategy" | The most *detailed* statement of the key strategy anywhere — and a January 2026 planning document that still has the original drafting prompt in an HTML comment at the top. It is also in the wrong repo. |
| `workflows/CLAUDE.md` | The only one that matches the current database — and it's an agent-instruction file, not a publication. |

Concretely, here's what the published docs say versus what's actually in release `v2026.08.11`:

| the docs say | where | the database has |
|---|---|---|
| `cruise_key` = `YYMMKK`, e.g. `2401NH` | db.qmd:35; README_PLAN:875, 896 | `YYYY-MM-NODC`, e.g. `2023-04-3322`, `1998-02-33JD` — year-month plus the **NODC ship code**, not the 2-letter `ship_key` |
| PKs are `site_uuid` / `tow_uuid` / `net_uuid` / `ichthyo_uuid`; sequential `site_id` sorted by `cruise_key, orderocc` | db.qmd:41–44; README_PLAN:884–923 | none of those tables exist. One `sample` table, keyed `sample_key` = `dataset_key:sample_type:id` |
| `taxon.taxonID` (PK per authority), `taxa_rank.taxonRank` | README_PLAN:955–956 | `taxon.taxon_key` = `worms:<AphiaID>` or `itis:<TSN>`, with `rank` + `rank_order` |
| "Avoid UUIDs in output tables"; `_source_uuid` "stripped in frozen releases" | db.qmd:46; README_PLAN:1006 | the released `cruise` table carries `_source_uuid`, `_source_file`, `_source_row`, `_ingested_at` |
| dev/prod two-schema **PostgreSQL** strategy; one master ingestion script `calcofi4db/inst/create_db.qmd` | db.qmd:124–154 | DuckDB + parquet; 16 per-dataset notebooks orchestrated by `targets` |
| "DuckLake Workflow (Recommended)": `get_working_ducklake()` → `ingest_dataset()` → `save_working_ducklake()` | db.qmd:160–199 | `gs://calcofi-db/ducklake/working/` holds **zero objects**. `get_working_ducklake()` and `save_working_ducklake()` are called by **no** ingest; `ingest_dataset()` by 2 of 16 (the two oldest). The functions are still exported, so nothing errors — the path is just dead. |
| Working vs Frozen DuckLake, "two-database strategy" | README_PLAN:1010+ | one frozen release. The working half was never built. |
| `metadata.json` schema version 1.1 | db.qmd:247 | 1.2 |
| `metadata/dataset.csv` = source of truth for dataset descriptions | db.qmd:231 | deprecated — superseded by each notebook's `calcofi:` YAML block |

And here's what is **absent from all three published docs** but is load-bearing in the database today:

- `sample_key` = `dataset_key:sample_type:id`, globally unique across datasets *and* across event levels (site / tow / net / cast / bottle / underway / transect / region\_pool)
- `dataset_key` = `provider_dataset`, the provenance stamp on every observation
- `taxon_key` = `worms:<AphiaID>`, or `itis:<TSN>` for birds — WoRMS bird taxonomy lags (it still says *Oceanodroma*, *Puffinus*, *Phalacrocorax*)
- the core table family: `obs`, `sample`, `obs_attribute`, `sample_measurement`, plus supplemental `obs_ctd_full` / `obs_mets_full`
- the three measurement grains (see §2)
- all released geometry tagged EPSG:4326; `hex_id` = H3 resolution 10 on `obs`
- the three registries themselves: `metadata/field_dictionary.csv` (canonical column names/types/units/aliases, 53 rows), `metadata/core_dictionary.csv` (the 55 core columns), `metadata/measurement_type.csv` (198 measured quantities with units and valid ranges), plus `metadata/provider.csv`

`calcofi.io/db-schema` publishes the *content* of those registries — tables, columns, measurement types, units. What no published page states is the *rules*.

**So I'd reframe Task 12 product (1) from "write the guide" to "reconcile three guides into one, and generate it from the registries so it can't rot again."** That's a better deliverable and it's unambiguously not duplicated work.

Related, and I think worth folding in: `README_PLAN.qmd` is in the wrong place. It's a planning document sitting in the workflows repo while holding the most authoritative PK documentation we have. The normative content should move into `docs/db.qmd`; the plan itself belongs in `workflows/libs/plans/` with the others.

### Datasets folded in

15 in the current release (`v2026.08.11`):

| dataset_key | obs rows | measurement types | taxa |
|---|---:|---:|---:|
| calcofi_ctd-cast | 13,488,402 | 33 | env (+274.9M supplemental) |
| calcofi_bottle | 11,135,600 | 26 | env |
| calcofi_mets | 511,459 | 17 | env (+19.9M supplemental) |
| cce-lter_picoplankton-bacteria | 60,802 | 4 | env |
| calcofi_dic | 3,708 | 4 | env |
| swfsc_ichthyo | 482,250 | 1 | 963 |
| swfsc_cufes | 284,097 | 1 | 6 |
| calcofi_phytoplankton | 159,804 | 1 | 25 — *should be ~390, see §2* |
| cce-lter_zooscan | 126,692 | 4 | 23 |
| cce-lter_euphausiids | 100,505 | 1 | 37 |
| farallon_bird-mammal | 66,344 | 1 | 124 |
| cce-lter_zoodb | 30,948 | 3 | 33 |
| calcofi_phyllosoma | 1,859 | 1 | 1 |
| sio_mesopelagic-fish | 1,393 | 1 | 87 |
| sio_pic-zooplankton | 0 | — | 82,343 tow records, effort-only for now (biovolume pending, issue #27) |

A 16th (`cdfw_dungeness-crab`) is ingested but held out of the release pending publication permission.

---

## 2. How was the schema built / why so few measurement types?

Mostly by design, and partly a real gap.

**By design: `measurement_type` is the QUANTITY, not the SPECIES.** The species dimension is `taxon_key`. So `swfsc_ichthyo` has one measurement type in `obs` (`abundance`) across 963 taxa and 482,250 rows — the type count tells you nothing about the breadth of a dataset. Where a source column mashes the two together (CUFES `sardine_eggs`, `phyllosoma_stage_3`), `metadata/measurement_taxon.csv` splits it into (taxon, canonical type, life stage, bin). That's why 22 of the 198 registered types have zero rows in the release: they're the pre-decomposition names, and they should probably be retired or flagged as such.

**Also by design: measurements land at three grains**, so counting only `obs` undercounts. Ichthyo really has 8 types spread across all three:

| grain | table | ichthyo's types |
|---|---|---|
| per occurrence | `obs` | `abundance` |
| sub-occurrence | `obs_attribute` | `body_length`, `stage` |
| per event (effort) | `sample_measurement` | `volume_sampled`, `std_haul_factor`, `prop_sorted`, `total_plankton_biomass`, `small_plankton_biomass` |

**But you found something real.** `larvae_10m2` and `larvae_100m3` aren't stored because they're *derived*, and everything needed to derive them is in the DB:

```
oblique / vertical tows (C1, CB, CV, PV):
    tally * std_haul_factor / prop_sorted           ->  count / 10 m²

manta / surface tows (MT):
    tally / prop_sorted / volume_sampled * 100      ->  count / 100 m³
```

The two differ because the manta `std_haul_factor` does not standardize to volume — using it understates manta density about 50×. That split is implemented in the hex-map app's prep and is why its manta counts changed earlier this year.

The problem is **delivery**, not storage. ERDDAP's tabledap cannot join across datasetIDs, and we put the numerator and the denominator in different ones:

- `swfsc_ichthyo` → `measurement_value` (raw tally), no effort
- `swfsc_ichthyo_sample` → `tow_type`, `std_haul_factor`, `prop_sorted`, `volume_sampled`

So anyone who downloads the obvious dataset gets raw counts with no denominator and no warning. **Proposal:** widen effort onto the observation view for gear-based datasets, and/or publish a standardized value alongside the raw one with its own unit column.

### And it's wider than ichthyo

Only 2 of the 15 released datasets (`calcofi_bottle`, `swfsc_ichthyo`) have **any** rows in `sample_measurement`. These sources have effort parsed at ingest and then dropped before the release:

| dataset | effort columns parsed, then dropped |
|---|---|
| farallon_bird-mammal | `length_m`, `width_m`, `area_m2` |
| calcofi_phyllosoma | `volume_filtered`, `aliquot_pct`, `aliquot_adjustment` |
| sio_mesopelagic-fish | `volume_sampled` |
| sio_pic-zooplankton | `net_type`, `mesh_size_mm` |
| cce-lter_zoodb | `net_type` |
| calcofi_mets | `uws_flow` |

The bird/mammal one matters most: without `area_m2`, the released database cannot produce seabird density (birds km⁻²), which is the headline CalCOFI seabird product. **Proposal:** an "effort completeness" pass — every bio dataset emits its denominator into `sample_measurement`, asserted at release time so it can't silently regress.

### The most consequential one: phytoplankton is released at class resolution

`calcofi_phytoplankton`'s **393 source taxa collapse to 25 `taxon_key`s** — 171 species to `worms:148899` Bacillariophyceae (Class), 144 to Dinophyceae, 53 to Coccolithophyceae. The species names survive in `dataset_taxon.ds_scientific_name`, but `obs` carries only `taxon_key` and no `ds_taxa_code`, so **there is no path from an observation row back to the Venrick species**.

And we already resolved **309 of 385 to species-level AphiaIDs**, sitting in `metadata/calcofi/phytoplankton/taxon_worms.csv`. I believe `metadata/taxon_override.csv` is overriding them: its five phytoplankton rows use `match_column = "taxa"` — the *functional-group* column — so a single override row swallows every species in the group, and the override takes precedence over the name match. I want to confirm that before calling it a bug, but if it holds, the fix is to make the override a **fallback** for unresolved names rather than a precedence rule.

---

## 3. Bird/mammal — one of your five is literally our source

- **CCE-LTER 255.3 (Sydeman / FIAER)** — this is what we ingested. Our recorded DOI (`10.6073/pasta/4ee1bd70…`) resolves to exactly `knb-lter-cce.255.3`.
- **CalCOFI Seabird Survey (Farallon Institute, NOAA ERDDAP)** — the *same survey*, differently distributed. It publishes `CAC_FI_SBAS_obs` / `_tr` / `_sp`, which are our `bird_mammal_observation` / `_transect` / `_species` tables, same columns (`gis_key`, `species`, `behavior`, `count`). Two things it has that we don't: it runs to **2022-10** where ours stops **2021-08**, and its transect log carries `length_km` / `width_km` / `area_km2` — the effort we dropped. I'd propose switching our source to it, or at minimum reconciling. (It carries a Farallon data-sharing agreement and has `_private` variants, so that's a permissions conversation, not just plumbing.)
- **Seabird At-Sea Density Anomaly (CCIEA)** and **Seasonal Seabird Density & Richness Index (CCE-LTER 162.3)** — derived indicator products built on that same survey. I wouldn't ingest them as datasets; they're the sort of thing we should be able to *reproduce* from the release — and right now we can't, for exactly the missing-`area_m2` reason above.
- **Hildebrand Marine Mammal Visual Surveys (CCE-LTER 262.2)** — genuinely distinct (SIO, separate survey), and a real candidate. That's issue #30, still open.

So "only 2 measurement types" is half by design (`count` is the quantity; the 124 species live in `taxon_key`) and half a real gap (behavior is there, effort is not).

---

## 4. The actual dataset count

**41 datasetIDs on `erddap.calcofi.io`** (42 if you count `allDatasets`). Those are **views, not datasets**. Per `dataset_key` we publish up to four, each only when it has rows:

| datasetID | grain | source |
|---|---|---|
| `{key}` | one row per observation | `obs` + `taxon` + `sample` |
| `{key}_sample` | one row per sampling event, effort widened on | `sample` + `sample_measurement` |
| `{key}_attribute` | sub-occurrence detail (length/stage bins) | `obs_attribute` + `sample` |
| `{key}_full` | the full series before thinning | a supplemental table |

34 of the 41 are current. **Seven are stale IDs from the pre-consolidation naming, still live on the server**: `calcofi_casts`, `calcofi_ctd_measurement`, `calcofi_ctd_thin`, `calcofi_dic_old`, `calcofi_phytoplankton_old`, `calcofi_zooplankton`, `calcofi_euphausiids`. They should be retired — they're a good part of why every list you've found has a different total.

Two more reasons the lists don't reconcile, both documentation problems:

- **`docs/portals.qmd` doesn't mention `erddap.calcofi.io` at all.** It documents EDI, NCEI, OBIS, ERDDAP (linking only NOAA's upwell / oceanview / coastwatch servers), ODIS and Google Dataset Search — but not our own ERDDAP, which is the one serving the 41. Same for `data/portal_comparison.csv`, whose "ERDDAP" row is about NOAA's.
- **There is no inventory mapping a portal listing back to a `dataset_key`.** That's the thing that would let anyone answer "is this dataset already in?" in one lookup instead of a morning of sleuthing — and it's arguably the natural companion to Task 12's product (2).

The authoritative list today is the release's own `dataset` table (15 rows in `v2026.08.11`), generated from each ingest notebook's YAML block. `metadata/dataset_status.csv` is the intended tracker but has drifted — it still says `mets` is "NOT YET RUN" and `zoodb`/`zooscan` are at "metadata" stage; all three are in the release. **Proposal:** generate `dataset_status.csv` from the release plus notebook YAML rather than hand-maintaining it, and treat the Google Sheet strictly as a *candidate* list.

---

## 5. Are these in scope?

| candidate | verdict |
|---|---|
| Invertebrates Count / Size (Cephalopods) | **Already in.** That's Ed Weber's invert data, folded into `swfsc_ichthyo` — the cephalopods are among the 963 taxa. Issue #38 tracks publishing the slice to ERDDAP. |
| Additional CTD Hydrographic Cast Data (NOAA) | Probably redundant with `calcofi_bottle` / `calcofi_ctd-cast`. Worth a day of overlap checking before anyone ingests it. |
| PRODO Chlorophyll / Productivity | In scope; open as issue #34. |
| Primary Production ¹⁴C (cce.71.4), POC/PON (54.7), HPLC pigments (72.4), Nitrate isotopes, Total Organic Carbon | **In scope, and the strongest candidates on your list.** All bottle-adjacent chemistry at a grain we already model, so each extends `obs` with little new modelling, and they compose with the existing bottle/DIC data. |
| NCOG 16S / 18S | In scope for CalCOFI, but that's DMP Tasks 3–6 under Nastassia Patin, and it needs the FAIRe/OBIS model rather than our measurement triple. Issue #63. |
| IFCB Images | Imaging, not tabular — belongs with the eDNA/imaging track. |
| Stanford Hopkins zooplankton / phytoplankton (Monterey Bay) | Outside the CalCOFI grid and not CalCOFI-program data. Interesting as regional comparison; out of scope for the DB. |
| Stanford–CalCOFI Supplemental | Haven't looked. Worth 30 minutes. |

---

## 6. Crosswalk format

Yes — `flds_redefine.csv` is the format, and all 16 ingested datasets already have one. But it stops one step short of Task 12's product (2): it records **source column → canonical column** and stops there. It does *not* record where the column lands in the released core — which table, which column, or which `measurement_type` at which grain. That projection exists only as SQL inside each notebook's "Emit Core Tables" section, so today nobody can answer "where did this source column go?" without reading a notebook.

**Proposal:** extend `flds_redefine.csv` with `core_table` / `core_column` / `measurement_type` / `grain` / `disposition`, where disposition is one of `stored` | `derived` | `dropped`. The `dropped` value is the whole point — it's what turns the bird/mammal `area_m2` case from invisible into a row in a table. (I checked: `calcofi4db` reads that file with a plain `read_csv()` and selects columns by name downstream, so adding columns in place is safe and doesn't need a sibling file.)

Two things worth knowing before you build on the dictionary, because they'll bite otherwise:

- **`field_dictionary.csv` covers 146 of the 481 (dataset, field) pairs the ingests actually mint** — 30%, ranging from 8% (`mets`) to 83% (`ctd-cast`, `picoplankton`). It also still lists `taxon_id` (renamed `taxon_key` in the consolidation) and `standard_haul_factor` (now `std_haul_factor`), and one row in `sio/mesopelagic-fish` has prose sitting in the `fld_new` cell: `"(used to derive datetime_start_utc, not stored)"`.
- **The lint that would catch all of that has effectively never run.** It exists only as prose inside `.claude/skills/validate-ingest/SKILL.md`, is not a function in `calcofi4db`, has no test, and doesn't run at release time.

**Proposal:** promote it to a tested function and run it in `release_database.qmd` with a ratchet — the count of undeclared fields may only ever go down, so the existing backlog doesn't block us but *new* drift fails the release. That's the pattern we already use for measurement bounds and it has worked well.

---

## Proposed split

**Yours** — no pipeline access needed, and it is the actual Task 12 deliverable:

- **A.** Reconcile the three convention documents into one authoritative guide, using the discrepancy table in §1 as the worklist. I'll wire it to generate from the registries so it can't rot again.
- **B.** Fill in the crosswalk: add `core_table` / `core_column` / `measurement_type` / `grain` / `disposition` across all 16 `flds_redefine.csv`. This *is* the audit that finds the dropped columns — the work and the product are the same artifact.
- **C.** Reconcile `field_dictionary.csv` against what the ingests actually mint (the 335 undeclared names): which are canonical, which are aliases that should have been normalized, which are legitimately source-only.
- **D.** Triage the candidate dataset list into in / out / decide with a one-line reason each, and fold the result into `docs/portals.qmd` so we stop having three lists.

**Mine:**

- **E.** The effort/denominator gaps — a `sample_measurement` arm per dataset, plus the ERDDAP numerator/denominator split.
- **F.** The phytoplankton `taxon_override` precedence.
- **G.** Retire the 7 stale ERDDAP IDs; generate `dataset_status.csv`; add `erddap.calcofi.io` to `portals.qmd`.
- **H.** Promote the schema lint into `calcofi4db` with tests and a release ratchet.

---

## Two calls I'd like your read on

1. **Audience for the guide.** Internal contributor spec (how to ingest a new dataset correctly) or external data-user document (how to read what we publish)? Those are quite different documents and I can argue either. My lean is contributor spec first — that's what stops the drift, and the drift is what we just spent this email cataloguing.
2. **Phytoplankton.** If I'm right about the override, restoring species-level keys changes the released taxon vocabulary for that dataset. Worth checking with Elizabeth Venrick / CCE-LTER *before* rather than after — it's possible the class-level rollup was a deliberate call about count reliability that simply never got written down. Which, appropriately enough, is the same failure mode as everything else in §1.

Really good sleuthing on this. Several of these are things nobody had looked at, and the phytoplankton one in particular would have gone unnoticed for a long while.

Ben
