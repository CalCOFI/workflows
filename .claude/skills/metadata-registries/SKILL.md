---
name: metadata-registries
description: "The metadata/ registries and their helpers — field_dictionary, measurement_type, category, life_stage, gear, provider, license, distribution, portal, holdings, dataset_meta.yml, questions.csv (id vs label, status/priority vocabulary, proposed answers, the provider Google Sheets), the exact-match rule for controlled-vocabulary ids, the provider and link-field conventions, and the write_csv(na = \"\") trap. Load before adding or editing anything under metadata/, a calcofi: YAML block, or a provider question."
---

# Metadata registries

> Moved verbatim out of `CLAUDE.md` on 2026-09-08 so the rules stay in every session's context and the mechanics and incidents behind them load only when needed. `CLAUDE.md` summarizes each rule and names this skill.

## Metadata registries — single sources of truth (`metadata/`)

| File | Role |
|---|---|
| `field_dictionary.csv` | **Prescriptive** canonical field names/types/units/aliases. New datasets conform; consistency is linted against it. `dwc_term` is the Darwin Core term URI the field publishes as, on the 12 of 57 fields one term means exactly. Authored by `libs/build_field_dictionary.R`, which regenerates the whole CSV — **add a row there, not to the CSV**, or the next run deletes it (four rows had already drifted out by 2026-09-03). |
| `measurement_type.csv` | Canonical measurement vocabulary (raw measured quantities). `is_canonical` flags the headline types; `valid_min`/`valid_max` bound the value and `valid_depth_min_m`/`valid_depth_max_m` the **depth over which the type is defined** (`est_chlorophyll_a_*` is computed for 0–200 m alone, so a null below that is by construction, not missing data); `derivation` is free text saying how a *derived* type was produced (the `_cruise_corr` vs `_sta_corr` distinction is not something a consumer should have to guess). **Read it with `calcofi4db::read_measurement_type()` and append with `register_measurement_types()`, never with bare `read_csv`/`write_csv`** — see the round-trip trap below. Bounds are **enforced per dataset at ingest time**, see below. `nerc_p01` / `units_nerc_p06` are the NERC concept URIs a Darwin Core / OBIS eMoF export emits as `measurementTypeID` / `measurementUnitID` — set with `declare_measurement_fields()` (`scripts/declare_measurement_vocab.R` seeds them), never a bare `write_csv`. |
| `category.csv` | **Registry of the twelve data categories** (`category, order, realm, icon, description`) — what an ingest's `calcofi.dataset_meta.category` and `measurement_type.category` must be one of (`build_workflows_index.R` errors on an unregistered one); the explorer's *Browse* tab, the schema site and the calcofi.io cards group by it, and `icon` is the brand sprite id (`calcofi.io/brand/v2/icons/`). Set a type's `category` / `variable` with `calcofi4db::declare_measurement_fields()`, never a bare `write_csv` (`scripts/declare_measurement_fields.R` seeds them). |
| `life_stage.csv` | **Registry of life stages** (`life_stage, dwc_lifeStage, nerc_s11, life_stage_parent, datasets, note`) — every distinct `obs.life_stage` value, with the DwC label and NERC S11 concept URI where one is exact, and `life_stage_parent` for a substage S11 does not carve (`furcilia F1` → `furcilia`). Two values are recorded as **not life stages** (euphausiid `damaged`, ichthyo `invert`); do not emit those as `lifeStage`. |
| `gear.csv` | **Registry of net gear** (`tow_type, gear_name, dwc_samplingProtocol, nerc_l22, datasets, note`) — every `sample.tow_type` code with the sentence a DwC `samplingProtocol` needs and the NERC L22 *device* URI where one is exact. L22 is a device catalogue: `DC` (a 600 m oblique) shares `CB`'s bongo id because the depth is protocol, not gear. |
| `provider.csv` | **Registry of curating organizations** — one row per `provider` slug with `provider_short` (display label), `provider_name`, `url`, `status`. Any provider an ingest declares MUST be here: `scripts/build_workflows_index.R` errors out otherwise. Replaced a hardcoded label vector in that script, which silently yielded `NA` and published a literal `.na.character` heading for unregistered orgs. |
| `license.csv` | **Registry of dataset licenses** (`license, name, url, status, notes`): the SPDX-style ids an ingest's `calcofi.dataset_meta.license` may carry — `CC-BY-4.0`, `CC0-1.0`, `CC-BY-NC-4.0`, `CC-BY-SA-4.0`, `US-PD`, `custom` (needs `license_url`), `unknown`. Read with `calcofi4db::read_license_registry()`; `check_dataset_citation()` fails the index and the release on a value outside it (`attribution` skill). |
| `{provider}/{dataset}/citation_authority.json` | **Generated cache** of what the source's own authority says (EDI / NCEI / ERDDAP / DataCite: `authority, url, citation, license, creator, title, checked, doi, doi_status`). Written by `check_dataset_citation()`; safe to delete (it refetches); `refresh = TRUE` refetches in place. A proposal, never the record — nothing copies it into the YAML. |
| `dataset.csv` | **DEPRECATED** — superseded by each ingest's `calcofi.dataset_meta` YAML block via `ingest_yaml_to_dataset_df(read_ingest_yaml())`. The CSV drifted from the notebooks and orphaned `obs` rows. |
| `dataset_status.csv` | Pipeline-stage tracker, one row per dataset; each skill writes its stage column. The `publish_obis` / `publish_erddap` / `publish_edi` / `publish_ncei` / `publish_caloos` cells (`done`, `n/a`, `#38 planned`) become each record's `registrations[]` in `datasets.json` — ERDDAP and OBIS are *measured* there and win over the cell. |
| `distribution.csv` | **Registry of curated endpoints per dataset** (`dataset_key, kind, portal, id, url, title, status, superseded_by, observed_utc, notes`; calcofi4db ≥ 4.1.0, plan 2026-09-05 § D-1/D-10) — the endpoints the release cannot measure itself: CoastWatch mirrors, the EDI / NCEI / DataZoo records, the OBIS dataset and its IPT resource, the legacy erddap.calcofi.io ids with their successor. `kind ∈ download|service|mirror|source|archive`, `status ∈ current|superseded|retired|external|planned`; read with `read_distribution_registry()` (an unknown value errors). **Never delete a row — status it** (`retired`, `superseded_by`), so a page can say "was at X until …". |
| `portal.csv` | **Registry of the portals** (`portal, name, kind, url, full_archive … api_access, harvests_from_us, observe_method, notes`) — the capability table `docs/portals.qmd` used to hand-maintain, plus what each portal reads from calcofi.io and how the weekly observation will ask it. Read with `read_portal_registry()`. |
| `distribution_observed.json` | **GENERATED** by `observe_distributions()` (calcofi4db ≥ 4.3.0, `Rscript scripts/observe_distributions.R`, weekly in `.github/workflows/observe.yml`) — what each portal says *now* about every curated distribution **and every holding's link**, one observer per `portal.csv` `observe_method`. It is a parallel observation, never an edit: `status ∈ live \| superseded \| retired \| unreachable \| skipped` sits beside the registry's own `status`, **no row is ever deleted**, and an unanswered request is `unreachable`, never `retired` (EDI's portal rate-limits, NOAA's ERDDAPs 503 under load). A change since the last run is a `proposed` `questions.csv` row for the provider, not a rewrite. `build_datasets_sitemap()` reads it for `lastmod` and drops a `retired` row. |
| `holdings.csv` | **GENERATED** by `write_holdings_csv()` at release from every `metadata/{provider}/{dataset}/dataset_meta.yml` whose `status` is `planned | external | archived` (a dataset CalCOFI has but has not ingested — plan § D-11). Edit the sidecar, never this file. |
| `metadata/{provider}/{dataset}/dataset_meta.yml` | **The descriptive half of `calcofi.dataset_meta`** (plan § D-9): `description`/`abstract`, `citation_main`, `citation_others`, `license`, `license_url`, `doi`, `acknowledgement`, `contact`, `pi_names`, `creators[]`, `keywords_gcmd`, `link_*`, `methods_md`, … and `visibility: public | internal` (default public; `internal` keeps a dataset in the record and off every public surface). The notebook YAML keeps the *structural* keys only (`dataset_name`, `dataset_name_short`, `category`, `color`, `tables`, `in_release`); `read_calcofi_meta()` merges the two, and `check_dataset_meta_split()` (run by `build_workflows_index.R`) errors on a descriptive key left in a notebook. Providers edit it through the `metadata` tab of their question Sheet (`scripts/sync_dataset_meta_sheets.R`). For a holding the sidecar also carries the structural keys and `status`, `priority`, `owner`, `next_step`, `gh_issue`, `module`. |
| `relationships_cross.csv` | Cross-dataset FKs (intra-dataset FKs live in each ingest's `relationships.json`). |
| `measurement_taxon.csv` | Decomposes a taxon-bearing `measurement_type` name (`sardine_eggs`, `phyllosoma_stage_3`) into (taxon, canonical type, `life_stage`, `bin_value`, target grain). **Stage it with `ensure_measurement_taxon()`, never `dbWriteTable()`** — the CSV has no `taxon_key` column, so a raw write makes every `mx.taxon_key` reference a binder error, and hand-rolling `'worms:' \|\| worms_id` mis-keys ITIS-resolved taxa. Filter it to the emitting `dataset_key`. |
| `taxon_override.csv` | Manual id resolution for source taxa with no clean id (phyto functional groups, marine mammals, "(species group)" codes), matched on the source column named in its own `match_column`. **Generic since calcofi4db 3.6.0** — every arm consults it, and a row naming an unknown `dataset_key` or a `match_column` the source does not expose now **errors**. Before that, `match_column` was never read anywhere in `R/` and only 2 of 7 arms consulted the file, so a row for any other dataset was parsed and silently dropped. |
| `taxon_lineage.csv` | **Generated cache** of WoRMS/ITIS classification chains, one row per (requested taxon, ancestor-or-self). Written by `ensure_taxon_lineage()`; safe to delete (it refetches, slowly). Not hand-maintained. |
| `taxon_xref.csv` | **Generated cache** of the WoRMS↔ITIS cross-reference, one row per (`query_type`, `query_value`). Written by `ensure_taxon_xref()`, which must run *before* `ensure_taxon_lineage()`. Fills `worms_id` on `itis:`-keyed taxa and `itis_id` on `worms:`-keyed ones, re-keys onto the authority-accepted id, and fetches the real `taxonomic_status` + `status_checked`. `notes` is append-only. Safe to delete; `scripts/warm_taxon_xref.R` repopulates it. |
| `metadata/{provider}/{dataset}/` | Per-dataset `tbls_redefine.csv`, `flds_redefine.csv`, `questions.csv`, corrections, etc. |
| `metadata/{provider}/{dataset}/questions.csv` | **Provider-question registry** — one file per dataset. Read with `calcofi4db::read_questions()` and render with `questions_datatable()`; never a bare `read_csv()` + hand-written `factor(priority, …)` (see below). |

## A controlled-vocabulary id is filled only on an exact match

The four registries above carry the ids a Darwin Core / OBIS ENV-DATA export needs —
`measurement_type.nerc_p01` / `units_nerc_p06` (BODC P01 / P06),
`life_stage.nerc_s11`, `gear.nerc_l22`, `field_dictionary.dwc_term`. **An id is written
only when a concept states exactly what the row is**: every facet the concept names —
quantity, matrix, phase, method — has to be something this registry or the dataset's
documented protocol actually supplies. A *generic* concept is an exact match at coarser
specificity (P01 `TEMPPR01`, *Temperature of the water body*, for a QC'd bottle
temperature); a concept that adds a facet nobody recorded is not (`IRRDUV01` pins PAR to a
cosine-collector radiometer). **An empty cell therefore means "no concept says exactly
this", never "not looked at"** — inventing an id to fill the column is the same mistake as
inventing a bound to quiet `check_measurement_bounds()`, and it is worse in one way: a
wrong bound deletes data visibly, a wrong id misdescribes it at a portal that will never
ask. At v2026.09 that is 115/200 types with a P01, 174/200 with a P06 unit, 10/23 life
stages with an S11, 4/11 gear codes with an L22, 12/57 fields with a DwC term; the empties
and why are in `RELEASES.md` and `docs/db.qmd` § *Darwin Core / OBIS ENV-DATA mapping*.
Resolve concepts against the NVS SPARQL endpoint (`https://vocab.nerc.ac.uk/sparql/sparql`)
and exclude deprecated ones.

## Declared bounds are checked per dataset, at ingest time

**Every ingest that emits measurements calls `calcofi4db::check_measurement_bounds()`
(≥ 3.10.0) on its `{dataset}_measurement` / `obs` and on every supplemental table it
publishes, and resolves every non-`ok` row before the notebook is done** — by
`declare_measurement_bounds()` (generous; one-sided is fine and usually right;
`register_measurement_types()` only appends and cannot set bounds) or by a
`proposed` provider question carrying the `finding`. Do not invent a bound to make
the check quiet, and never set one to the observed range: a bound describes what is
physically possible. Enforcement is the separate `drop_out_of_bounds()`, which
DELETEs. `release_database.qmd`'s `bounds_coverage` chunk is the backstop, not the
mechanism: `out_of_range` fails the release, `undeclared` is ratcheted by
`BOUNDS_UNDECLARED_MAX` (only ever down). The two findings, the resolution
procedure and the incidents behind these rules are in the **`measurement-bounds`
skill**.

## The question registry convention

Two identifiers, deliberately: **`id`** (`calcofi_ctd-cast_15`) is the durable
globally-unique key an issue or another dataset cites; **`label`** (`Q15`) is the
short display form, unique *within* the dataset, rendered first so "see Q15" in
prose resolves for a reader. (`calcofi/hydro-master` is the one registry whose
ids span two namespaces — `hydro_master_*` and `recon_*`, both cited by name in
`ctd-cast_qa-qc-protocol.qmd`, `ingest_calcofi_ctd-cast.qmd` and `libs/*.R` — so its recon
labels take an `R`: `QR01`. `label` is authored, not derived from `id`.)

`status` is **`open` | `proposed` | `answered` | `wontfix`** and `priority` is
**`blocker` | `high` | `normal` | `low`**. `proposed` is the one that matters:
it means *we have already built or reasoned an answer and want it confirmed* —
`proposed_answer` holds it, `questions_email.qmd` puts it in the draft marked
`[PROPOSED]`, and the provider approves a solution rather than being handed a
problem. Pre-answer everything the repo can settle before asking.

Each active provider also gets a Google Sheet (`metadata/questions_sheets.yml`, one tab
per dataset, `Rscript scripts/sync_questions_sheets.R push|pull [provider] [--execute]`;
**auth is the calcofi-admin service account only**, resolved by `scripts/lib_google_auth.R` from
`QS_GOOGLE_SA_JSON` / `CALCOFI_GOOGLE_SA_JSON`, else the key's Drive home, else
`/etc/rclone/calcofi-admin-sa.json` — never an individual's OAuth token, which expires and needs a
human at the keyboard) —
the CSV stays the record and every column but `answer`/`status`/`answered_date`/`who` is
protected there, so `pull` only ever writes those four columns back into `questions.csv`.

Descriptive dataset metadata (abstract, methods, creators, license, …) lives in
`metadata/{provider}/{dataset}/dataset_meta.yml`, not the notebook — `read_calcofi_meta()` merges it
back into `calcofi.dataset_meta` so every reader sees one block. Each provider's Sheet gains a
`metadata` tab, long form (`dataset_key · field · value · guidance · edited_by · edited_date`), tiered
required → recommended → optional from `metadata/dataset_meta_fields.csv`; only
`value/edited_by/edited_date` are unprotected, and the `calcofi` Sheet's `holdings` tab is the team's
triage board for the not-yet-ingested datasets. `scripts/sync_dataset_meta_sheets.R pull` validates
before writing — `license` against `metadata/license.csv`, `contact` as an email or URL, `doi` bare,
`creators`/`associated_parties` parsed from `Name · Org · orcid · email` lines — and rewrites only the
changed value plus an `edited:` stamp, never the whole file. WS-R1's CalOOS-sheet proposals sit beside
each sidecar as `dataset_meta.proposed.yml` until a provider confirms them.


## Conventions the registries enforce

- **`provider` = the organization curating the data.** Not the portal that hosts
  it, and not a collection or lab *within* the organization. CalCOFI program data
  is `calcofi` even when served from NCEI/EDI/ERDDAP; the portal goes in
  `link_data_source`. **Every provider must be registered in
  `metadata/provider.csv`** — it carries the display label and full org name, and
  `scripts/build_workflows_index.R` errors on an unregistered one rather than
  publishing a broken heading.
  - Two failure modes to avoid, both of which happened: an *agency abbreviation
    that isn't the agency* (`dfw` → `cdfw`, California Department of Fish and
    Wildlife), and *the collection standing in for the org* (`pic` → provider
    `sio` with dataset `pic-zooplankton`, since the Pelagic Invertebrate
    Collection is the dataset, SIO is the org). Likewise a redundant prefix:
    `ucsd_sio` → `sio`.
- **A link field must contain a link, and `build_workflows_index.R` now enforces
  it.** `link_calcofi_org` / `link_data_source` are rendered as an `href` — by the
  calcofi.io/workflows cards and, via the release `dataset` table, by
  db-viz-station. Two things fail the index build: a non-empty field that is not
  `http(s)` (`link_data_source` held the prose `"BTEDB (Bongo Tow Euphausiid
  Database) export"` and `"SIO Pelagic Invertebrate Collection DB (CSV export)"`),
  and a URL answering **404/410/451** (`swfsc_ichthyo` pointed at
  `/data/biology/ichthyoplankton/`, dead, for months). 5xx/timeout/DNS only
  **warn** — NOAA CoastWatch ERDDAP 503s under load, and failing a rebuild over
  someone else's busy server just teaches people to skip the check.
  - **Probe with a ranged GET, never HEAD.** EDI's `mapbrowse` answers `405` to
    HEAD and EDI hosts most of the bio datasets, so a HEAD-based check fails
    exactly the links that are fine. `curl::new_handle(range = "0-0")` answers
    200/206 everywhere and does not pull the 31 MB bottle zip.
  - If the source genuinely has no portal URL (a private collection DB export),
    leave the field **empty** and put the provenance in `description` — do not
    describe the source in a link field.
  - `CALCOFI_SKIP_LINK_CHECK=1` skips the network half (~3 s vs ~40 s); the shape
    check always runs.
  - Where one org commissions and another performs the work, the provider is the
    one that holds and can license the data — `cdfw_dungeness-crab` was sorted at
    SIO but is CDFW's.

- **Never `write_csv()` a shared registry without `na = ""`.** `readr`'s default is
  `na = "NA"`, so an empty cell round-trips to the two-character string `"NA"`.
  This is invisible from R — `read_csv()` reads `"NA"` straight back to `NA` — but
  DuckDB's `read_csv_auto` has a default `nullstr` of the empty string only, so the
  literal value reaches the release. It did: 161 rows of `_qual_column`, 192 of
  `_prec_column`, plus `units`, `is_canonical` and `grain` shipped as `"NA"`. Nine
  ingest notebooks had the bug; one didn't. Use
  `calcofi4db::read_measurement_type()` (strict read + validation) and
  `register_measurement_types()` (append-only, always `na = ""`); the generic guard
  is `check_registry_na_strings()`. A validator placed *after* a default `read_csv`
  can never catch this, which is why the strict read is part of the helper.

