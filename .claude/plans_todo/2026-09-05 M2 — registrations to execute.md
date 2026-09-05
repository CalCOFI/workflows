# M2 — registrations to execute

Drafts and checklists for Ben and Erin to run. Nothing here has been submitted, sent, or edited on a
live record — every "send" / "submit" / "edit" line below is a step for a human. Measured facts are
cited with the command or fetch that produced them (2026-09-05); everything else is marked as a draft
or an open confirmation.

---

## 1 · CalOOS — message to Iwen Su (Erin sends)

**Context.** Erin initiated CalCOFI's CalOOS registration with Iwen Su before erddap.calcofi.io
existed. `data.caloos.org` already carries four CalCOFI catalog modules built from CoastWatch's
`erdCalCOFI*` ERDDAP. `metadata/distribution.csv` matches three of the four to an integrated
`dataset_key` (the fourth is unconfirmed — see the portal.csv note below).

| module | CalOOS module id | dataset_key | erddap.calcofi.io dataset ids | calcofi.io page |
|---|---|---|---|---|
| CalCOFI Fish Eggs & Larvae Counts/Stages from net tows and CUFES | `1a1a7812-48f9-4325-8ad0-e51e67e366ba` | `swfsc_ichthyo` | `swfsc_ichthyo`, `swfsc_ichthyo_attribute`, `swfsc_ichthyo_sample` | `https://calcofi.io/datasets/swfsc_ichthyo/` |
| CalCOFI Zooplankton Biovolumes from net tows | `81f12914-825b-499c-8aad-33b34ec29c93` | `sio_pic-zooplankton` | `sio_pic-zooplankton_sample` (the tow registry; biovolume is NOAA-served, plan Q01 pending) | `https://calcofi.io/datasets/sio_pic-zooplankton/` |
| CalCOFI & CCE-LTER Seabird Visual Observations | `2458d7c2-af69-4a76-abfb-195fb5aa8f14` | `farallon_bird-mammal` | `farallon_bird-mammal`, `farallon_bird-mammal_attribute`, `farallon_bird-mammal_sample` | `https://calcofi.io/datasets/farallon_bird-mammal/` |
| *(4th module — unconfirmed)* | — | likely `calcofi_bottle` (hydrographic cast/bottle; CoastWatch mirrors are `siocalcofiHydroCast`/`siocalcofiHydroBottle`) | `calcofi_bottle`, `calcofi_bottle_sample` | `https://calcofi.io/datasets/calcofi_bottle/` |

**Draft — Erin to Iwen Su:**

> Subject: CalCOFI's own ERDDAP — adding it beside the CoastWatch modules
>
> Hi Iwen,
>
> Following up on the CalOOS registration from earlier this year: CalCOFI now runs its own ERDDAP,
> `https://erddap.calcofi.io/erddap`, serving the integrated database directly (the same station/cruise
> records as the CoastWatch mirrors your four modules already carry, plus a few tables CoastWatch
> doesn't have). Three things to settle:
>
> 1. **Direct harvest, not copies.** Since Axiom's portal reads an ERDDAP dataset by URL, could CalOOS
>    harvest erddap.calcofi.io's datasets directly rather than us sending copies? The relevant dataset
>    ids per module are in the table above (also at `https://erddap.calcofi.io/erddap/info/index.html`).
> 2. **The handoff.** We'd like the CoastWatch datasets to stay listed as NOAA's (Ed Weber's group still
>    maintains them), with the calcofi.io ones joining the *same* modules as the integrated versions —
>    not new modules. Does that work on your end, or would you rather split them out?
> 3. **Propagation to data.ioos.us.** Is CalOOS's catalog what data.ioos.us harvests for our region — so
>    registering with you is the only IOOS-level step we need — or is a separate CalCOFI provider record
>    in the IOOS Harvest Registry still wanted? (We're asking IOOS the same question in parallel — see
>    below — because `registry.ioos.us` doesn't currently resolve for us to check ourselves.)
>
> One more thing while we're in touch: our working sheet lists a fourth CalOOS module we haven't been
> able to match to one of our datasets with confidence — could you confirm which one it is? Our guess is
> the hydrographic cast/bottle data (CoastWatch's `siocalcofiHydroCast`/`siocalcofiHydroBottle`).
>
> Thanks,
> Erin

**Gate:** once CalOOS confirms, add a `registrations[].caloos` row per dataset and flip
`metadata/portal.csv`'s `caloos.observe_method` outcome into `distribution.csv` as `service/caloos` rows
(the pattern already used for the three confirmed modules).

---

## 2 · IOOS Harvest Registry — the measured 19115-3 answer

### The question the plan asked (D-5.4)

> ERDDAP 2.30 emits 19115-3 (`mdb:`); ckanext-spatial historically parsed 19115-2/19139 (`gmi:`/`gmd:`).
> Check first that the IOOS harvester accepts ISO 19115-3.

### Measured answer: **no, it does not.**

1. **The document erddap.calcofi.io serves is genuine ISO 19115-3.** Fetched
   `https://erddap.calcofi.io/erddap/metadata/iso19115/xml/calcofi_bottle_iso19115.xml` (200 OK,
   2026-09-05): root element `<mdb:MD_Metadata xmlns:mdb="http://standards.iso.org/iso/19115/-3/mdb/1.0" …>`,
   closing tag `</mdb:MD_Metadata>` — the full 2016 ISO 19115-3 encoding (`mdb`, `mri`, `mcc`, `cit`, …
   namespaces), not 19139/19115-2.

2. **The IOOS Catalog's harvester is CKAN + `ckanext-spatial` + `ckanext-harvest`**
   (`ioos/catalog-docker-ckan-harvest`; IOOS maintains its own fork of `ckanext-spatial`, unmodified in
   the relevant function). Its format-detection function is `guess_standard()` in
   `ckanext/spatial/harvesters/base.py`:

   ```python
   def guess_standard(content):
       lowered = content.lower()
       if '</gmd:MD_Metadata>'.lower() in lowered:
           return 'iso'
       if '</gmi:MI_Metadata>'.lower() in lowered:
           return 'iso'
       if '</metadata>'.lower() in lowered:
           return 'fgdc'
       return 'unknown'
   ```
   (fetched `raw.githubusercontent.com/ckan/ckanext-spatial/master/ckanext/spatial/harvesters/base.py`
   and the identical `ioos/ckanext-spatial` fork, 2026-09-05.) It recognizes only the 19139/19115-1
   closing tag (`gmd:`) and the 19115-2 closing tag (`gmi:`). There is no `mdb:` case — a 19115-3
   document returns `'unknown'` and the harvester skips it. Corroborating: `ckanext-spatial`'s own
   XSD validation tree ships only `iso19139/`, `iso19139ngdc/` and `medin` (a UK 19139 profile) schemas —
   no 19115-3/`mdb` schema exists anywhere in the package
   (`api.github.com/repos/ckan/ckanext-spatial/git/trees/master?recursive=1`, 2026-09-05). And the ISO
   parsing class (`ISODocument`/`ISOElement` in `ckanext/spatial/harvested_metadata.py`) declares
   `namespaces = {"gmd": "http://www.isotc211.org/2005/gmd", …}` and every XPath in the file is
   `gmd:…` — none of that would match a 19115-3 document even if `guess_standard()` let it through,
   because 19115-3 restructures element names, not just namespace prefixes (e.g.
   `mdb:identificationInfo/mri:MD_DataIdentification` replaces `gmd:identificationInfo/gmd:MD_DataIdentification`).
   Fourth confirmation, from NOAA's own page: ioos.noaa.gov/data/data-standards/catalog-registration
   states plainly that a provider's WAF must hold "routinely-updated **ISO 19115-2** XML metadata".

### Fallback: the FGDC WAF

`https://erddap.calcofi.io/erddap/metadata/fgdc/xml/` is live (confirmed 200 OK, 2026-09-05) and its
records' root element is `<metadata>` (no namespace) — exactly `guess_standard()`'s `'fgdc'` branch.
**This is what should be registered**, not the ISO 19115-3 WAF, until/unless ERDDAP adds a 19115-2
(`gmi:`) output or IOOS's harvester adds 19115-3 support (there's no open upstream issue found for
this — worth filing on `ioos/catalog` if Ben wants an ISO-3 path kept open).

### A second, operational finding: `registry.ioos.us` does not currently resolve

`curl -sI https://registry.ioos.us/` → `getaddrinfo ENOTFOUND` / DNS `NXDOMAIN` (measured 2026-09-05).
`data.ioos.us/about` (200 OK) calls the Harvest Registry "an internal site used by data providers to
manage metadata harvest sources" and gives **data.ioos@noaa.gov / 240-533-9444** as the contact for
account requests; the public docs (`ioos.github.io/catalog/pages/registry/`) describe the *process*
(request an account → account approved + org affiliation confirmed → configure WAF/CSW sources) but not
a self-service form. So the exact registry form fields cannot be confirmed at this URL right now —
either it moved, requires an active account/VPN to reach, or is temporarily down.

**Recommended path (draft, Ben to send or confirm before Erin sends the CalOOS message above):**

> To: data.ioos@noaa.gov
> Subject: CalCOFI ERDDAP — provider registration for the IOOS Catalog
>
> Hi IOOS Catalog team,
>
> CalCOFI (Scripps/NOAA SWFSC/CDFW) runs its own ERDDAP at `https://erddap.calcofi.io/erddap`, serving
> the integrated CalCOFI database (37 current dataset ids). We'd like to register it for harvest into
> the IOOS Catalog and were trying to reach the Harvest Registry to request an account, but
> `registry.ioos.us` isn't resolving for us today — is that URL still current, or has it moved?
>
> One thing worth flagging while we're in touch: ERDDAP (≥ 2.30) now emits its ISO metadata as
> 19115-3 (`mdb:MD_Metadata`) rather than 19115-2 (`gmi:MI_Metadata`), and we found that
> `ckanext-spatial`'s `guess_standard()` doesn't recognize the 19115-3 closing tag, so a 19115-3 WAF
> would be silently skipped by the harvester. We'll register our **FGDC WAF**
> (`https://erddap.calcofi.io/erddap/metadata/fgdc/xml/`) instead, which we've confirmed matches your
> parser's expected root element — but if 19115-3 support is on a roadmap, happy to be an early tester.
>
> We're also CalCOFI's regional CalOOS/SCCOOS partner (Iwen Su has our four existing modules) — if
> CalOOS's own harvest into data.ioos.us already covers us, let us know and we'll skip a separate
> provider record.
>
> Thanks,
> Ben

**Form fields to fill once an account exists** (from the public docs, since the live form couldn't be
reached): organization name/affiliation, contact person + email, region (IOOS RA — California =
SCCOOS/CeNCOOS), and the WAF or CSW endpoint URL to harvest
(`https://erddap.calcofi.io/erddap/metadata/fgdc/xml/`). Confirm the exact field set once
`registry.ioos.us` is reachable or the account-request reply arrives.

**§ Measured line for the plan:** ERDDAP's ISO 19115-3 WAF is confirmed live and well-formed
(`mdb:MD_Metadata`), and confirmed **incompatible** with the IOOS Catalog's `ckanext-spatial` harvester
(`guess_standard()` recognizes only `gmd:`/`gmi:` closing tags — source read, not inferred); the FGDC
WAF is the fallback and is itself confirmed live and correctly shaped. `registry.ioos.us` is DNS-dead as
of 2026-09-05; the account-request path is `data.ioos@noaa.gov`.

---

## 3 · ODISCat 3318 — re-point to the generated sitemap

**Current state:** record `https://catalogue.odis.org/view/3318` — Erin/Ben hold edit access (per the
existing `docs/portals.qmd` write-up); it currently points at the old hand-maintained repository sheet's
sitemap (78 external pages, snapshot 2025-07-02). `datasets/sitemap.xml` is now generated from
`datasets.json` (WS-M1, verified 127 URLs: 33 calcofi.io pages + 94 external, 0 superseded/retired) but
those 33 calcofi.io pages 404 until Ben pushes `CalCOFI.github.io` main (I-14) — **do not re-point the
ODIS record until after that push**, or ODIS's crawl will 404 on a third of the sitemap and may
de-index the record while it retries.

**Checklist (Ben, after the landing-repo push):**
1. Log into `catalogue.odis.org`, open record 3318, edit its sitemap/source field.
2. Change the URL to `https://calcofi.io/datasets/sitemap.xml`.
3. Save.
4. `curl -sI https://calcofi.io/datasets/sitemap.xml` → confirm 200 first (this is the literal
   pre-condition above).
5. Watch `book.odis.org`'s dashboard for calcofi.io pages appearing in the crawl — allow up to a week
   (per the plan's own Verification section).

**ODIS checklist fields verified against a locally built page** (schema.org validator's own guidance +
`book.odis.org/gettingStarted.html`, which does not mandate a fixed field list but shows `@context`,
`@type`, `@id`, `name`, `description` as its normative example): built `CalCOFI.github.io` locally
(`scripts/build.sh`, staging record v2026.09.05) and confirmed both `swfsc_ichthyo` and
`calpoly_whale-edna`'s JSON-LD carry `@id`, `identifier`, `includedInDataCatalog`, `provider`, `name`,
`description` — the fields `scripts/check_jsonld.py`'s own docstring calls out as "ODIS's checklist" —
and `scripts/check_jsonld.py` passes clean over the full local `_site` (33 dataset pages + sitemap +
data.json). No ODIS-specific gap found.

---

## 4 · Google Dataset Search — Rich Results results (measured on 2 locally built pages)

Built `CalCOFI.github.io` locally (`bash scripts/build.sh`; staging record v2026.09.05, 16 datasets / 17
holdings) and ran the **Rich Results Test** (`search.google.com/test/rich-results`, Code tab — pasting
each page's `<script type="application/ld+json">` block wrapped in a minimal HTML shell, since a
localhost URL can't be fetched by Google's crawler) on two pages: `swfsc_ichthyo` (the richest record —
29 distributions/registrations) and `calpoly_whale-edna` (a thin holding page).

**Result, both pages: "2 items detected: Some are invalid."** Google's parser walks the JSON-LD graph
and treats *every* node typed `"@type": "Dataset"` as its own top-level item to validate — including
the nested `isPartOf` stub every page carries:

```json
"isPartOf": { "@type": "Dataset", "@id": "https://calcofi.io/datasets/release/",
              "name": "CalCOFI Integrated Database, release v2026.09.05" }
```

| item | swfsc_ichthyo | calpoly_whale-edna |
|---|---|---|
| the page's own Dataset | ✅ valid — 1 non-critical: missing optional `license` | ✅ valid — 1 non-critical: missing optional `license` |
| the `isPartOf` release stub (parsed as its own Dataset) | ❌ invalid — 1 critical, 2 non-critical | ❌ invalid — 1 critical, 2 non-critical |

The `license` non-critical finding on both real pages is **not a plugin bug** — confirmed by reading the
built `.jsonld` sidecars: `_plugins/datasets.rb` line 517 already does
`node["license"] = Fmt.present(a["license_url"]) || Fmt.present(a["license"])`, and both
`swfsc_ichthyo` and `calpoly_whale-edna` simply have no license value in their sidecar yet — this is the
same "6 `no_license` exempt on open licence questions" gap WS-E1 already found, not something for P1 to
fix in code.

The `isPartOf` critical finding **is a real, fixable plugin gap** — `_plugins/datasets.rb`, lines 542–543:

```ruby
node["isPartOf"] = { "@type" => "Dataset", "@id" => abs("/datasets/release/"),
                     "name" => "CalCOFI Integrated Database, release #{release['version']}" }
```

Typing this stub as `"@type": "Dataset"` with only `@id`/`name` makes Google's own validator treat it as
a second, incomplete Dataset entity (missing the required `description`, among other recommended
fields) — one *valid* dataset and one *invalid* one on every one of the 33 pages. `check_jsonld.py`
doesn't catch this because it only asserts on the page's *own* top-level node, not on nested `@type`
stubs — worth a follow-up assertion there too. **Recommended fix for P1** (hand back, do not edit): make
`isPartOf` a plain URL string (`node["isPartOf"] = abs("/datasets/release/")`) rather than a typed
sub-node — schema.org's own `isPartOf` accepts a URL or a `CreativeWork`, and a URL reference doesn't
get parsed as a competing Dataset item. (Retyping it `"@type": "CreativeWork"` would also dodge Google's
Dataset-specific required-field check, but the URL form is simpler and loses nothing — the release page
itself already carries the full `name`/`description`.)

**Google Search Console indexing request** (Ben's account, after the landing-repo push and the sitemap
fix above):
1. Open Search Console for the `calcofi.io` property.
2. Sitemaps → add `https://calcofi.io/datasets/sitemap.xml`.
3. URL Inspection → request indexing for `https://calcofi.io/datasets/` and 2–3 representative dataset
   pages to seed the crawl.

---

## 5 · data.gov / CKAN — is `data.json` harvestable?

`https://calcofi.io/data.json` (generated from `datasets.json` by `_plugins/datasets.rb`, DCAT-US 1.1
non-federal profile) is exactly the shape a CKAN harvester needs zero custom work for: `ckanext-dcat`'s
**DCAT JSON Harvester** (the extension every CKAN instance data.gov and most agency/university portals
run, including IOOS's own CKAN) is pointed at a `data.json` URL and does the rest — no WAF, no CSW, no
account request beyond adding the harvest source in that CKAN's admin. Locally confirmed (2026-09-05,
`scripts/check_jsonld.py` on the built `_site`): `data.json` has 34 DCAT-US datasets and passes the
required-field subset check (full JSON Schema validation needs the `jsonschema` Python package, not
installed in this check — install it in CI per the script's own comment for the stricter pass).

**Checklist for Ben, once the site is live:**
1. data.gov itself: submit at `https://www.data.gov/contact/` or through an agency's own data.gov
   organization if CalCOFI has a NOAA/CDFW sponsor willing to add it — data.gov harvests are normally
   agency-initiated, not self-service for a non-federal partnership; confirm with Erin/Ed whether SWFSC
   or CDFW's existing data.gov organization would add `https://calcofi.io/data.json` as a harvest
   source, which is the fastest path.
2. Any other CKAN (a university library catalog, a state portal): add
   `https://calcofi.io/data.json` as a "DCAT JSON" harvest source in that CKAN's admin — no CalCOFI-side
   work needed beyond keeping the URL live.

---

## 6 · Legacy ERDDAP ids — sunset plan for the 7 `superseded` ids

The 7 ids (`metadata/distribution.csv`, `status = superseded`), their successors, and current state
(`erddap/content/datasets.xml`, all confirmed `active="true"`, all **outside** the generated block —
hand-maintained, per `publish_to-erddap.qmd`'s own callout):

| legacy id | `superseded_by` | datasets.xml line |
|---|---|---|
| `calcofi_casts` | `calcofi_bottle` | 8793 |
| `calcofi_ctd_thin` | `calcofi_ctd-cast` | 9816 |
| `calcofi_ctd_measurement` | `calcofi_ctd-cast_full` | 10029 |
| `calcofi_dic_old` | `calcofi_dic` | 9117 |
| `calcofi_euphausiids` | `cce-lter_euphausiids` | 9233 |
| `calcofi_phytoplankton_old` | `calcofi_phytoplankton` | 9652 |
| `calcofi_zooplankton` | `sio_pic-zooplankton` | 9391 |

### Consumer reference grep (repo · file · id)

Grepped every sibling repo (`db-query`, `db-schema`, `db-viz-hex`, `db-viz-station`, `ctd-transects`,
`explore`, `calcofi4r`, `calcofi4py`, `api`, `api-h3t`, `api-h3t-py`, `apps`, `analytics`, `uptime`,
`capstone`, `hypoxia-story`, `larvae-cinms`, `marmam-app`, `pollutants-app`, `SaferSeafood`, `server`,
`docs`, `data`, and the three student-project repos) for all 7 ids, 2026-09-05:

| repo | file | id |
|---|---|---|
| *(none)* | — | — |

**No consumer repo references any of the 7 legacy ids.** The only references anywhere in the CalCOFI
org are internal to `workflows` and `erddap` themselves (expected — `erddap/content/datasets.xml`'s own
`<dataset>` blocks, `workflows/publish_to-erddap.qmd`'s documentation of the hand-maintained exclusion,
`workflows/metadata/distribution.csv` / `distribution_observed.json`, and `calcofi4db`'s test fixtures).
This means the sunset carries **no known downstream breakage** — safe to proceed on Ben's schedule
without a deprecation-notice waiting period for internal consumers; the only unknown audience is
external users who bookmarked or scripted against these URLs directly, which is what the ERDDAP
`summary` note (below) and a sunset date are for.

### Sunset plan

1. **Date:** recommend 90 days from today (**2026-12-04**) — long enough for the `summary` note (below)
   to reach anyone polling the dataset via ERDDAP's own metadata, short enough that the new
   `dataset_key`-based ids (all live since 2026-08+) are clearly the stable target.
2. **Now (no wait needed):** add a note to each of the 7 datasets' ERDDAP `summary` in
   `erddap/content/datasets.xml` pointing at its successor, e.g. for `calcofi_casts` (line 8793 area):
   > "**This dataset id is retired and will stop being served after 2026-12-04. Use `calcofi_bottle`
   > instead: https://erddap.calcofi.io/erddap/tabledap/calcofi_bottle.html**" (prepended to the
   > existing summary text, all 7 datasets, same wording pattern with each row's own successor id).
   This is a config edit only — no retirement yet, and `publish_to-erddap.qmd`'s generator never
   touches these hand-maintained blocks, so it's safe against the next release's config regen.
3. **On 2026-12-04, on the CalCOFI host, for each of the 7 ids:**
   ```bash
   sudo bash /share/github/CalCOFI/workflows/scripts/retire_erddap_dataset.sh calcofi_casts
   sudo bash /share/github/CalCOFI/workflows/scripts/retire_erddap_dataset.sh calcofi_ctd_thin
   sudo bash /share/github/CalCOFI/workflows/scripts/retire_erddap_dataset.sh calcofi_ctd_measurement
   sudo bash /share/github/CalCOFI/workflows/scripts/retire_erddap_dataset.sh calcofi_dic_old
   sudo bash /share/github/CalCOFI/workflows/scripts/retire_erddap_dataset.sh calcofi_euphausiids
   sudo bash /share/github/CalCOFI/workflows/scripts/retire_erddap_dataset.sh calcofi_phytoplankton_old
   sudo bash /share/github/CalCOFI/workflows/scripts/retire_erddap_dataset.sh calcofi_zooplankton
   ```
   Omit `--purge-files` on the first pass (stop serving, keep the files) — decide separately whether to
   purge `/share/erddap/datasets/<id>/` later; the script backs up `datasets.xml` before each edit and
   prints the `curl` verification + `git commit` command for the `erddap` repo.
4. **After retirement, in `workflows/metadata/distribution.csv`:** flip each of the 7 rows' `status`
   from `superseded` to `retired` and stamp `observed_utc` with the retirement date (per D-10, rows are
   never deleted — this is exactly the "was at X until 2026-12; now at Y" case the registry is built
   for). `update_datasets-sitemap.qmd` already excludes both `superseded` and `retired` rows from
   `datasets/sitemap.xml`, so no further sitemap change is needed at retirement time.
5. **Verify:** `curl -sI https://erddap.calcofi.io/erddap/info/calcofi_casts/index.json` (and the other
   6) → expect 404, per the script's own printed verification line.

---

## 7 · `docs/portals.qmd` § "Registrations" — text for P2 (hand back only; do not edit that file)

P2 is rewriting `docs/portals.qmd` around the registry (`metadata/portal.csv`) per plan D-6; this is the
prose for its "Registrations" section, built from what this brief measured:

> ## Registrations
>
> Beyond the archives and aggregators above, three meta-portals and one regional catalog index CalCOFI
> by crawling or harvesting what calcofi.io already publishes — no data is copied to them, they read the
> record.
>
> **ODIS** crawls `datasets/sitemap.xml`, generated from `datasets.json` (never hand-maintained); record
> [catalogue.odis.org/view/3318](https://catalogue.odis.org/view/3318) points at it. **Google Dataset
> Search** and any DCAT-aware **data.gov**-style CKAN read the same JSON-LD and `data.json` respectively
> — a CKAN needs nothing beyond adding `calcofi.io/data.json` as a DCAT JSON harvest source.
>
> **The IOOS Catalog** (`data.ioos.us`) harvests ISO XML from WAFs registered in the IOOS Harvest
> Registry. erddap.calcofi.io publishes both an ISO 19115-3 WAF and an FGDC WAF
> (`/erddap/metadata/{iso19115,fgdc}/xml/`) — only the **FGDC** one is compatible with the Catalog's
> current harvester (`ckanext-spatial` recognizes 19139/19115-2's `gmd:`/`gmi:` root elements, not
> 19115-3's `mdb:`; measured 2026-09-05 from the harvester's own source). **CalOOS**
> (`data.caloos.org`, the SCCOOS/CeNCOOS regional portal) is the more direct route for the region: it
> already carries four CalCOFI catalog modules seeded from NOAA CoastWatch's ERDDAP, and its own harvest
> is what feeds data.ioos.us for California — registering erddap.calcofi.io there may be the only IOOS
> step CalCOFI needs at all.
>
> | portal | what it reads | registered |
> |---|---|---|
> | ODIS | `datasets/sitemap.xml` (JSON-LD) | record 3318, re-pointed at the generated sitemap |
> | Google Dataset Search | JSON-LD on each dataset page | automatic once pages are live and indexed |
> | data.gov / any CKAN | `data.json` (DCAT-US 1.1) | per-consumer harvest-source setup, no CalCOFI-side work |
> | IOOS Catalog | FGDC WAF (not the ISO 19115-3 one) | pending — `registry.ioos.us` account request |
> | CalOOS | erddap.calcofi.io dataset list | pending — Iwen Su, in progress |

---

## Hand-back summary

- **Branch:** `registrations-drafts` (worktree `/Users/bbest/Github/CalCOFI/.worktrees/workflows-m2`) —
  see the sha in the commit that accompanies this file.
- **The 19115-3 answer:** confirmed incompatible with evidence (§ 2) — ERDDAP's WAF is genuine 19115-3
  (`mdb:MD_Metadata`), `ckanext-spatial`'s `guess_standard()` (source read, both upstream and IOOS's own
  fork) recognizes only `gmd:`/`gmi:` closing tags, and ioos.noaa.gov's own registration page asks for
  19115-2. The FGDC WAF is the confirmed-live fallback. `registry.ioos.us` itself is DNS-dead today;
  `data.ioos@noaa.gov` is the fallback contact.
- **The validator results:** Rich Results Test run on 2 locally built pages (`swfsc_ichthyo`,
  `calpoly_whale-edna`) via the Code-paste method (no live URL to test against yet). Both pages' own
  Dataset node is valid (1 non-critical: missing `license`, a data gap not a plugin bug); both pages'
  nested `isPartOf` release stub is invalid (1 critical + 2 non-critical) — a real `_plugins/datasets.rb`
  fix named at lines 542–543 for P1 (make `isPartOf` a URL, not a typed Dataset node). No screenshot
  captured (the Rich Results Test UI became unresponsive to the browser tool after the second
  drill-down; the summary-level result — "2 items detected: Some are invalid", with the per-item
  breakdown above — was captured before that).
- **The legacy-id reference grep table:** zero hits in any of the 22 non-`workflows`/`erddap` CalCOFI
  repos checked (§ 6) — the sunset carries no known downstream breakage.
- **`RELEASES.md` bullet:** none needed — nothing in this brief changed release content. The one file
  change outside this document is `metadata/portal.csv` (see below), which is workflow-registry
  metadata, not release output.
- ***Measured* line for the plan's § Measured:** 2026-09-05 · WS-M2: erddap.calcofi.io's ISO 19115-3 WAF
  confirmed genuine (`mdb:MD_Metadata`) and confirmed incompatible with the IOOS Catalog's
  `ckanext-spatial` harvester (`guess_standard()` source read); its FGDC WAF is the live, correctly-typed
  fallback; `registry.ioos.us` is currently DNS-dead. Rich Results Test on 2 local pages: both valid on
  their own Dataset node (missing-license, a data gap), both invalid on the nested `isPartOf` release
  stub (a real `_plugins/datasets.rb:542` fix for P1). `data.json` is a zero-extra-work DCAT JSON
  harvest source for any CKAN. Zero of 22 non-workflows/erddap CalCOFI repos reference any of the 7
  legacy ERDDAP ids — the sunset is clear to schedule (recommend 2026-12-04). CalOOS: 3 of 4 existing
  modules matched to a `dataset_key`; the 4th needs Iwen/Betty to confirm.

## `metadata/portal.csv` changes (this branch)

- `ioos-catalog` row: `harvests_from_us` corrected from `erddap-waf` to `fgdc-waf`; `notes` rewritten
  with the measured 19115-3 rejection, its citations, the FGDC fallback, and the `registry.ioos.us`
  DNS/contact finding.
- `caloos` row: `notes` appended with the 3-of-4-modules-matched finding and the open confirmation for
  the 4th.

No row deleted; both edits are corrections with citations, per the brief.
