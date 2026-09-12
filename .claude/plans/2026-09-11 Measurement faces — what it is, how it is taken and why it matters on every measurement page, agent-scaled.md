# Measurement faces — what it is, how it is taken and why it matters on every measurement page, agent-scaled

**Status:** proposed 2026-09-11 from the mockup; **Ben decided the five open questions the same day** (§ Open questions →
Answers): draw the structures ourselves, one why sentence with the rest collapsed, every depth band where measured, fix the findings now,
"stands in" for keys with no concept. The findings pass ran the same day in the main session (§ Findings F8–F9 carry its outcome); nothing
of the faces is built. **Spec:** the mockup artifact *CalCOFI Measurement Faces* —
https://claude.ai/code/artifact/aefb4449-c780-4da9-8216-3cbe91530e03 — eleven cast measurements (temperature, salinity, dissolved oxygen,
nitrate, ammonium, chlorophyll-a, pH, dissolved inorganic carbon, *Synechococcus*, wind speed, and the stands-in example estimated
nitrate), every structure drawn from ChEBI's own coordinates on 2026-09-11 and every number read from release v2026.09.10 or computed from
it with the computation named. **Scale:** eight workstreams (≈ 7 agent-days) in two waves — wave 1 is parallel (the registries, the why
sentences, the record's schema 1.1 in `calcofi4db`, the landing fetcher, the page against a fixture, the docs, and the picoplankton ↔
species link); wave 2 is the integrator's (merge, the bridge record, the full fetch, the PR, the deploy); schema 1.1 rides the next
release. **Sits on** the measurements catalog (`2026-09-10 Measurements catalog …`: `measurements.json`, `_plugins/measurements.rb`,
`_layouts/measurement.html`, `assets/measurements.js`) and copies the species faces' agent-scaled shape (`2026-09-11 Species faces …`).
**Probe scripts, inputs and the mockup source:** `.claude/plans/2026-09-11 measurement-faces-probe/` (README there).

## The ask (Ben, 2026-09-11)

> Now that the species faces are almost done (artifact mockup: https://claude.ai/code/artifact/34135a47-7597-41af-ad58-5328bde815dd;
> plan: `.claude/plans/2026-09-11 Species faces — … agent-scaled.md`), let's similarly give the measurements a "face". I am most
> interested in:
>
> - What: what is the thing being measured, per the documented description from NERC and within our database. If it has a chemical
>   structure, eg ammonia (NH4) or even salinity (NaCl), I'd like to see it.
>
> - How: How is it being measured? By rosette bottle, CTD sensor, ... Should link out to CalCOFI.org for details a la homepage pins.
>
> - Why: Why should we care about this measurement? How is it relevant to the health of the ocean?

On the mockup's five questions:

> 1. … Draw ourselves
> 2. … You pick one and offer the rest under an expandable details/summary class like "not yet in the database" in the datasets catalog.
> 3. … Show all of the bands where measured, ie "Where in the water column" in your mockup
> 4. … Fix findings now.
> 5. … stands in

## Context, measured 2026-09-11 (calcofi.io live on v2026.09.10)

- **The live measurement page** (`/measurements/temperature/`): crumb › eyebrow › label › description › NERC ids › the stats band ›
  *Measured in* rows › years strip › *By depth* › *By month* › *Range & quality* › *Related* › *Ways in*. `_layouts/measurement.html` reads
  `page.*` from `_plugins/measurements.rb`, which reads `measurements.json` and nothing else. Nothing on the page shows what is measured,
  how, or why it matters.
- **`measurements.json`** (v2026.09.10, schema 1.0): 89 keys, 94 series, 5 datasets, 29,432,595 `obs_env` rows; 50 of 89 keys carry a NERC
  P01, 24 distinct P01s; 17 METS keys have no category.
- **The probe** (`measurement-faces-probe/`; Appendix B): 20 of 24 P01s read from NVS with their parts; 13 structures drawn from ChEBI
  molfiles; the GOOS EOV sheets for 8 variables; calcofi.org's six method pages; NCEI 0301029; NOAA CPC ONI; Wikipedia leads and the pH and
  Beaufort tables; the anomaly per depth band from `obs_env` ⋈ `climatology` for five variables.
- **Face kinds over the 89 keys:** structure 26 (an S27 with a ChEBI link), composition 13 (salinity ×7, DIC/alkalinity ×4, phaeopigment
  ×2), scale 9 (a property: temperature, pH, pressure, density, attenuation), organism 4 (*Synechococcus*, *Prochlorococcus* by S25; two
  picoplankton counts without a P01), no concept 37 → 20 borrow a sibling's face, 16 show their scale alone, 1 (`uws_flow`) shows nothing.

## Findings

- **F1** NERC's P01 is the key ring, not a label: its parts carry identifiers. S27 (chemical object) is `owl:sameAs` a ChEBI entry and a
  ChemIDplus CAS (9 of 9 S27s probed); S25 (biological entity) is `sameAs` a WoRMS id (2 of 2); S06 (property) is `sameAs` a QUDT quantity
  kind; A05 (AtlantOS essential variable) is a broader of 6 of 20 P01s (TEMPPR01, PSLTZZ01, DOXMZZXX, CPHLZZXX, TCO2MSXX, MDMAP014). The
  CAS also sits in the P01 label (`{NO3- CAS 14797-55-8}`).
- **F2** ChEBI serves a curated 2D molfile per entity (`/chebi/backend/api/public/molfile/{id}/`); RDKit draws it as SVG with text as paths,
  and swapping black for `currentColor` gives one file that is navy on white and bone on navy (1.7 KB for O₂, 32 KB for chlorophyll-a).
  A layout computed from SMILES wrecks chlorophyll-a (the Mg²⁺ collapses the ring); ChEBI's own coordinates keep it. Only 8 of 23
  compounds have a structure image on Wikidata, each in a different style.
- **F3** DIC's S27 is "total inorganic carbon" `sameAs` CHEBI_27594, which is *carbon atom*, whose ChEBI roles include "antidepressant";
  dioxygen's include "anti-inflammatory drug". ChEBI roles are never shown, and a pool (DIC, alkalinity) or a mixture (salinity) takes
  composition rows, not the S27.
- **F4** A05 is not the EOV membership test: EV_NUTS names nitrate P01s per kilogram but not NTRAZZXX. The GOOS specification sheets'
  sub-variables are the list (Nutrients: NO₃⁻, NO₂⁻, NH₄, PO₄, Si(OH)₄; Inorganic carbon: DIC, TA, pCO₂, pH). The sheets carry the
  why as societal drivers, numbered scientific questions and phenomena; goosocean.org says "all rights reserved", so a question is
  quoted with a link, never a paragraph.
- **F5** calcofi.org's *Bottle sampling methods* page carries the principle, instrument, wavelength, precision and references per
  analysis (Winkler with a UV end point at 350 nm; nitrate's azo dye at 520 nm; phosphate at 820 nm; ammonium's indophenol blue and
  silicate at 660 nm; the Portasal 8410A at ±0.003); the *CTD FAQ* covers the sensors. The DIC, underway and phyto/bacterioplankton pages
  render client-side and return an empty shell to a fetcher. The pages have no stable anchors (Elementor ids), so a link to a section is
  a text fragment (`#:~:text=Dissolved%20Oxygen%20Sampling`). NCEI 0301029 fills the DIC instruments (CO₂ gas analyser, titrator).
- **F6** The record already tells the why, band by band (Measured § 2026-09-11): oxygen has fallen in every band since 1984 and faster
  with depth (−0.83 µmol/kg per decade at 0–10 m, −6.56 at 200–500 m); nitrate rose at 50–200 m (+0.53, +0.51 µmol/L per decade); the
  top 10 m ran +2.10 °C in 2015 though 1983 was warmer at 10–100 m; chlorophyll's lowest surface year was 2015 (−0.81 µg/L). NOAA's ONI
  for June–August 2026 is +1.80: a strong El Niño is under way.
- **F7** The release's `climatology` stops at the 500 m bin (`build_climatology(depth_max_m = 500L)`), so 117,302 temperature, 105,689
  salinity, 81,423 oxygen and 26,076 nitrate values below 500 m have no normal to depart from.
- **F8** The familiar scale is a quality check. What it surfaced, and what the findings pass (main session, 2026-09-11) did:
  - CTD two-sensor averages folding in a dead or out-of-range sensor (question Q21): salinity ≈ 17 on 36 casts (1998-07-32NM,
    2007-11-32NM, 2024-01-33UD: half of sensor 1, because sensor 2 read ~0 inside the 0–45 bound) and 35–40 °C at 1–2 m on 17 casts of
    2003-04-31JD → **fixed**: every average recomputed from the valid sensors only.
  - CTD oxygen above 450 µmol/kg: a failed station correction on casts 2404_025 and 1907_050 (station-corrected ≈ 2.8 × the raw sensor)
    → **filed to the CTD team**.
  - METS wind speed: 217 values at hurricane force on 7 cruises. NDBC buoy matchups (≤ 30 km, same 30-minute bin, 2016–2022; buoys
    46011, 46025, 46047, 46053, 46054, 46069, 46086) give median ship/buoy ratios of 1.7–2.4 on most 3322/33UD/39C2 cruises (knots-like) and
    0.5–1.3 on most 33P4 cruises (m/s-like), confounded by true versus relative wind (METS Q22) → **a provider question, not converted**.
  - The QC'd bottle `ammonia` has no P01 while its pre-QC twin `r_ammonium` and `btl_ammonium` carry AMONZZXX, and the method (Berthelot)
    measures ammonium → **P01 and label fixed** at the ingest.
  - Nitrate, chlorophyll-a and phaeopigment declare no bound; the 2020-07-33P4 cast whose 99 °C was dropped still ships salinity 9.50;
    17 METS keys have no category → **fixed** at the ingests and in the registry (bottle re-rendered 2026-09-11 08:40: nitrate −1…60
    removes six of seven 1976-02-31AX values of 56–95 µmol/L with phosphate < 1; the 56.0 sits inside the real deep tail, which runs to
    52, so it waits for bottle Q14; salinity removed beside an impossible temperature: 2 values; 17 out-of-range rows across 6 types).
- **F9** The two catalogs do not meet: *Synechococcus* and *Prochlorococcus* carry WoRMS ids through S25, but
  `ingest_cce-lter_picoplankton-bacteria.qmd` § Emit Core Tables emits the four flow-cytometry counts as realm `env` with a NULL
  `taxon_key` ("the four FCM types ARE the measurement vocabulary"), and `build_taxa_catalog()` reads `obs_bio` only
  (`R/catalog_taxa.R` ~L270–291), so `/species/worms-160572/` is a 404. A model change, so it is D9 and WS-MF7, not the findings pass.

## Decisions (each with what the workstreams build; D1–D5 confirmed by Ben 2026-09-11)

### D1 — The structure is ours: ChEBI's molfile, drawn by RDKit in the page's ink
The What shows the entity NERC names, reached only by identity: P01 → S27 → `sameAs` ChEBI (or a `measurement_chem.csv` row with a source
for composition and stand-ins) → ChEBI's molfile → RDKit SVG with `currentColor`, text as paths, a tight `viewBox`. The caption is ChEBI's
name, formula with charge, mass and id; ChEBI's definition may be quoted (CC BY 4.0); its roles never. No image from Commons or PubChem.
*(Ben: "Draw ourselves".)*

### D2 — Four faces and a fallback, by what NERC says the thing is
**Structure** (an S27 with ChEBI; an equilibrium pair where the method measures both, as NH₄⁺ ⇌ NH₃); **composition** (salinity: the
TEOS-10 Table D.3 mass fractions as an ion bar with the grams in a kilogram at the record's own median; DIC: CO₂ + HCO₃⁻ + CO₃²⁻ with the
Bjerrum plot at the record's surface medians; phaeopigment: pheophytin-a, flagged "one of"); **scale** (a property: the familiar-scale
figure is the face); **organism** (S25 → WoRMS → the species face from `taxa_media.json`, linking the species page once D9 lands).

### D3 — "Stands in" for the 37 keys with no concept
A key without a P01 borrows the face of the quantity it estimates or repeats, with a chip "stands in: nitrate's face, estimated from the
ISUS sensor" and **no borrowed ids** in its ids row. The map lives in `metadata/measurement_face.csv` (`key, face_kind, face_of,
stands_in_note, source`): 20 borrow (the TSG and SST keys → temperature/salinity; ISUS voltage and estimates → nitrate; fluorescence and
estimated chlorophyll → chlorophyll-a; ¹⁴C incubations → HCO₃⁻, the form the ¹⁴C is added as; METS oxygen and pH → theirs), 16 show their
scale alone, `uws_flow` shows nothing. A key that gains an exact P01 leaves the map. *(Ben: "stands in".)*

### D4 — How: one card per series, from the method page, linked like the front door's pins
`metadata/measurement_method.csv` (dataset_key × measurement_type): platform (bottle | ctd | underway | lab | net), instrument, `nerc_l22`
(exact match only), a one-or-two-sentence principle, reaction steps, wavelength, precision, BibTeX keys, the calcofi.org page and its
text fragment, and the source of each row (the page section, the dataset's EML, the record's own `derivation`). The card shows the
spectrum strip where there is a wavelength, the series' flag column or "no flag at this grain", and a pin link styled as the hero's.
Beside the cards, *Where in the water column* from the record's `depth_bands`. Chlorophyll-a's card shows the method as chemistry
(chl-a → acid, Mg²⁺ out → pheophytin-a).

### D5 — Why: one pick on the page, the rest one click away
`metadata/measurement_why.csv` (`key, rank, kind, text, bibkeys, source_url, eov, goos_doc`): rank 1 is the pick, Claude's, authored and
cited (every BibTeX key in `../docs/refs/*.bib`, every DOI resolving); ranks 2… are the alternatives — a second authored line, the GOOS
question(s) quoted, the Wikipedia lead (two sentences, CC BY-SA 4.0, linked to the revision), calcofi.org's own words where it has them.
The page shows the pick in the sentence (NERC definition · the record · the pick, each underlined in its source colour) and the rest
collapsed in `<details class="ds-details">` whose summary reads "other ways to say why · n" — the datasets catalog's "not yet in the
database" idiom (`_includes/catalog_grid.html`, `.ds-details` / `.ds-holdings-det` in `style.css`). An authored alternative without a
citation is labelled "needs a citation before it can be the pick". No human review gate. *(Ben: "You pick one and offer the rest …")*

### D6 — Why: every depth band where measured, against the release's own normal
`build_measurements_catalog()` adds `anomaly` per key: one yearly series per depth band of the record's `depth_bands` edges that has both
values and a climatology — obs_env ⋈ climatology on dataset_key, measurement_type, site_key, calendar month, 10 m bin; `qual_ok`; mean per
cruise, then per year; `n_cruises` kept so one-cruise years draw faded — with a 1984–2021 least-squares trend per band over years with two
or more cruises, the band extremes, and a symmetric `ymax` shared by all bands of the key (set by the ≥ 2-cruise years; one-cruise years
beyond it are clipped and marked). The page draws small multiples on one year axis with the strong El Niño years shaded from NOAA CPC's
ONI (fetched by the landing fetcher, D8); the head's sparkline is the band with the most values. **`build_climatology()` is carried to
the bottom** (`depth_max_m` = the deepest bin with ≥ 3 cruises, the existing rule) so the deeper bands appear too — it grows the
`climatology` table and the Explorer's section anomalies read it, so WS-MF3 measures both before and after. *(Ben: "Show all of the bands
where measured".)*

### D7 — The familiar scale, every mark sourced
`metadata/measurement_scale.csv` (`key, value, lo, hi, label, kind, how, source, source_url`), kind ∈ familiar | physical | threshold |
computed. Computed marks name their function and inputs (`gsw.t_freezing(35, 0)`; `gsw.O2sol_SP_pt` at the record's surface medians) and
are recomputed at build, never typed. The figure: the record's 5th–95th percentile per series with min–max and median, the declared bounds
dashed, the marks below the axis, the flags (a value outside what the scale makes plausible) as red marks with their text; Beaufort for
wind (both readings until METS Q22 is answered); the universal-indicator strip for pH; a log axis for chlorophyll and cell counts.

### D8 — `measurements_media.json` is the landing fetcher's; the release carries only what it computes or CalCOFI authors
The vocabularies and leads change on their own cadence and the release must stay reproducible, so
`scripts/fetch_measurement_faces.py` in CalCOFI.github.io (weekly `measurement-media.yml`, and by hand after a release) walks
`measurements.json`, follows each key's P01 (or its `face_of`, or its `measurement_chem.csv` rows) through NVS, fetches the ChEBI records and
molfiles, draws the SVGs (RDKit), fetches the Wikipedia leads named in `measurement_why.csv` and the ONI table, and writes
`measurements_media.json` to `gs://calcofi-files-public/measurement-media/` — **one copy, never one per release**: the structures under
`measurement-media/keys/{key}/structure.svg` and the sidecar beside them at `measurement-media/measurements_media.json`, its own `release`
field the only place a version appears. (This read `measurement-media/{release}/` until 2026-09-12. The species faces shipped that layout
and promoting v2026.09.11 silently took every face, size ladder and sentence off every species page, because the site fetched the sidecar
at the *promoted* version and the media existed only for the previous one; a molecule and an EOV outlive a release exactly as a taxon
does. Fixed there in CalCOFI.github.io `6904faa`; do not reintroduce it here.) `scripts/fetch_release.sh` pulls it into `_data/`
(git-ignored). The record (`measurements.json` 1.1) carries the anomaly and the five registries, so the page's numbers and the authored
prose come from the release and the pictures from the fetcher. A key without media renders exactly as today.

### D9 — Picoplankton meet the species catalog (option a)
(a) **Recommended:** the picoplankton ingest sets `obs_env.taxon_key` = `worms:160572` / `worms:345515` on `synechococcus` /
`prochlorococcus` and declares them with `append_dataset_taxon()`; `build_taxa_catalog()` also counts `obs_env` rows that carry a
`taxon_key` (counted in `n_obs`/`n_present` like any other, flagged by dataset). Species pages appear; the measurement pages are unchanged;
`check_taxon_ids()` covers the new keys. (b) Moving them to `obs_bio` would remove them from the measurements catalog — rejected. Needs
Ben's yes before WS-MF7 merges (it changes what `taxa.json` counts).

### D10 — Documentation
The docs book's `db.qmd` gains *A face for every measurement page* after *A face for every species page* (one paragraph, one figure, one
caption, no typed number; the docs-compendium rule); the landing README's measurements section gains *Faces*; the `metadata-registries`
skill gains a pointer to the five new registries and their evidence rule; `RELEASES.md` `# Unreleased` gets the schema 1.1 line and the
deeper climatology line.

## Architecture — what changes, by repo

| Repo | File | What | Owner |
|---|---|---|---|
| **workflows** | `metadata/measurement_chem.csv`, `measurement_method.csv`, `measurement_scale.csv`, `measurement_why.csv`, `measurement_face.csv` (new) | the five registries with a source per row (Appendix A) | WS-MF1 (chem, method, scale, face) · WS-MF2 (why) |
| **calcofi4db** | `R/registry_measurement_face.R` (new), `tests/testthat/test-registry_measurement_face.R` | `read_measurement_{chem,method,scale,why,face}()` + `register_*()` (the `na = ""` writer), validators (vocabularies, source present, rank 1 unique, bibkeys resolve) | WS-MF1 |
| | `R/catalog_measurements.R`, `inst/schema/measurements.schema.json` (→ 1.1), `R/climatology.R`, `tests/…`, `NEWS.md` | `anomaly` per band; the registries carried per key; `face_kind`/`face_of`; `build_climatology()` to the bottom | WS-MF3 |
| **workflows** | `release_database.qmd` (the `build_measurements_catalog()` call only), `RELEASES.md` `# Unreleased` | pass the registries; the two lines | WS-MF3 |
| **CalCOFI.github.io** | `scripts/fetch_measurement_faces.py`, `scripts/check_measurement_faces.py`, `.github/workflows/measurement-media.yml`, `scripts/fetch_release.sh`, `.gitignore` | the fetcher, the RDKit drawing, the media JSON, the check | WS-MF4 |
| | `_plugins/measurements.rb`, `_layouts/measurement.html`, `_includes/measurement_face.html` (new), `_includes/measurement_why.html` (new), `assets/measurements.js`, `style.css`, `scripts/check_jsonld.py`, `scripts/check_layout.py`, `_data/shots.yml`, `README.md` | the face row, the sentence + details, What / How / Why sections, the figures, JSON-LD `image` + `sameAs` | WS-MF5 |
| **docs** | `db.qmd` + `refs/*.bib` (+ `data/` snapshot only if a number is stated) | D10 | WS-MF6 |
| **workflows** | `.claude/skills/metadata-registries/SKILL.md` | the pointer | WS-MF6 |
| **workflows + calcofi4db** | `ingest_cce-lter_picoplankton-bacteria.qmd` § Emit Core Tables, `R/catalog_taxa.R`, tests, `RELEASES.md` | D9 option (a) | WS-MF7 |

Shared files: `assets/measurements.js` and `style.css` — WS-MF5 only; `RELEASES.md` — MF3 and MF7 each append their own bullet;
`metadata/measurement_why.csv` — MF2 only (MF1 creates it empty with the header). The findings pass already touched `measurement_type.csv`,
the CTD/bottle/METS ingests and `RELEASES.md`: every workstream starts from main after that pass is merged.

## Workstreams and agents — who runs what, in which wave

| WS | Brief | Agent (model · effort) | Depends on | Days |
|---|---|---|---|---|
| MF1 | the registries + helpers; fill chem, method, scale, face for all 89 keys with evidence | `ws-sonnet-high` (Sonnet · high) | Appendix A | 1.5 |
| MF2 | the why: a pick + alternatives for every key with a face, citations verified | `ws-opus-medium` (Opus · medium) | the `measurement_why.csv` header (Appendix A) | 1 |
| MF3 | `measurements.json` 1.1: anomaly per band, registries carried, climatology to the bottom | `ws-opus-medium` (Opus · medium) | fixture registries from the probe | 1 |
| MF4 | the landing fetcher: NVS → ChEBI → RDKit, Wikipedia, ONI → `measurements_media.json`, the check | `ws-opus-medium` (Opus · medium) | Appendix A media shape | 1 |
| MF5 | the page: face row, sentence + details, What / How / Why figures, JSON-LD, checks, reshoot | `ws-opus-medium` (Opus · medium) | the probe's `data.json` as fixture | 1.5 |
| MF6 | docs chapter, landing README, skill pointer, BibTeX | `ws-sonnet-high` (Sonnet · high) | the mockup (for the figure) | 0.5 |
| MF7 | picoplankton ↔ species (D9 a) | `ws-opus-medium` (Opus · medium; stop at the gate for Ben's yes) | — | 0.5 |
| MF8 | integration: merges, the bridge record, the full fetch, the PR, deploy | the integrator session (Fable 5.1 · high) | MF1–MF7 | 1 |

Wave 1: MF1–MF7 in parallel, one `Agent` call each in ONE message, `isolation: worktree`. Wave 2: MF8. The briefs are
`.claude/plans_todo/WS-MF1.md` … `WS-MF7.md` (Read first · You own · Do · Gates · Hand back, the WS-F form); each names this plan as its
umbrella.

## Verification (what "done" means, per workstream)

- **MF1**: `devtools::test()` green with a fixture per validator (a row without a source fails; two rank-1 rows fail; a `nerc_l22` that is
  not an exact concept is empty); every key with a P01 has its S27/S25 → ChEBI/WoRMS row or a note why not; every series in
  `measurements.json` has a `measurement_method.csv` row with a source; the 37 no-concept keys are all in `measurement_face.csv`.
- **MF2**: one rank-1 row per key with a face; every bibkey in `../docs/refs/*.bib`; every DOI returns 200 through doi.org; no alternative
  copies more than one GOOS sentence; a hand-read of the eleven cast keys against the mockup.
- **MF3**: `devtools::test()` green; `measurements.schema.json` 1.1 validates a record built from v2026.09.10 with the MF1 fixtures;
  the per-band series reproduce `measurement-faces-probe/anom_bands.csv` exactly for the five probed variables; the climatology's row count
  and the Explorer smoke (`scripts/smoke_release.mjs`) before and after the depth change pasted into § Measured.
- **MF4**: `--only` the eleven cast keys reproduces the probe's structures (same ChEBI ids, `viewBox` within 1 unit) and chains;
  `check_measurement_faces.py` passes (every structure reached through NERC or a registry row, every Wikipedia lead with a revision, no
  ChEBI role anywhere); a full run over 89 keys is resumable and rate-limited (NVS ≤ 2 rps with a contact User-Agent).
- **MF5**: `/measurements/nitrate/`, `/salinity/`, `/dic/`, `/synechococcus/`, `/wind_speed_ms/`, `/est_nitrate_sta_corr/` and
  `/ammonia/` show the right face kind; the details element is closed on load and its summary count matches; the anomaly rows equal the
  record's bands; `check_layout.py` passes at 1470/375 in both themes; `check_jsonld.py` finds `image` and `sameAs` on every page with a
  structure; a page without media differs from today's build only by nothing.
- **MF6**: the book renders html, docx and pdf (`feedback_docs_book_gt_word_export`); the figure is numbered and referenced; no number typed.
- **MF7**: `taxa.json` built from a fixture holds `worms:160572` with its FCM counts; the measurement record unchanged; `check_taxon_ids()`
  green; Ben's yes recorded here before merge.
- **MF8**: live at calcofi.io/measurements/ in both themes against the bridge record; coverage (structures, method rows, why picks, bands)
  pasted into § Measured; `RELEASES.md` lines present; schema 1.1 rides the next release — do not cut one for it.

## Risks, and what bounds them

- **A wrong structure** (a stand-in misread as the thing): the ids row never shows borrowed ids; the check asserts every drawn structure
  traces to an S27 `sameAs` or a sourced registry row.
- **A why that overclaims:** rank 1 must carry a citation; the check refuses a pick without one; authored text never states a number the
  record does not hold.
- **The deeper climatology changes a consumer:** MF3 measures the Explorer's section anomalies before and after; if a lens changes, the
  depth cap becomes a parameter the release passes, not a default.
- **NVS slowness** (~15 s per concept with links): the fetcher caches per URI and runs weekly, not per build.
- **GOOS text rights:** a question is quoted and linked, never a paragraph.
- **METS wind stays ambiguous** until Q22 is answered: the Beaufort face shows both readings and says so.

## Open questions (for Ben) — ANSWERED 2026-09-11

1. Draw the structures or use images → **draw ourselves** (D1).
2. Who writes the why → **Claude picks one; the rest under a collapsed details** like "not yet in the database" (D5).
3. Which depth band → **all bands where measured** (D6), which carries the climatology to the bottom.
4. Findings now or later → **now** (F8; done or filed the same day).
5. Keys with no concept → **stands in** (D3).

**D9 decided 2026-09-12 (Ben): neither (a) nor (b) as written — the counts move to Biology.** "The picoplankton dataset should probably be under Biology, not Environment … it already is under Biology" (the datasets catalog files it there). WS-MF7 now emits the four flow-cytometry counts as `obs_bio` rows (one `measurement_type` for the quantity, number/ml) with `taxon_key` `worms:160572` / `worms:345515` on *Synechococcus* / *Prochlorococcus*; picoeukaryotes and heterotrophic bacteria keep their identity through the established composite-group mechanism or a NULL key plus a proposed question. `build_taxa_catalog()` is unchanged. Consequence at the next release: the four keys leave `measurements.json` (89 → 85 keys, 94 → 90 series) and the *organism* face kind is served by the species pages instead.

## Kickoff prompt (the integrator session — Claude Fable 5.1 · effort high; cwd `~/Github/CalCOFI/workflows`)

```
You are the integrator for the plan ".claude/plans/2026-09-11 Measurement faces — what it is, how it is taken and why it matters on
every measurement page, agent-scaled.md". Read it end to end, then the seven briefs .claude/plans_todo/WS-MF1.md … WS-MF7.md, then the
mockup it cites (open the artifact URL with WebFetch) and the probe folder .claude/plans/2026-09-11 measurement-faces-probe/ (README
first). Ben has decided D1–D5; do not re-open them. D9 needs his yes before WS-MF7 merges — ask once, early.

First confirm the findings pass (F8) is merged on main in workflows and calcofi4db; every worktree branches from after it.

Wave 1 — launch all seven briefs in ONE message with the Agent tool, each with isolation "worktree" and the subagent_type the plan's
§ Workstreams table names (MF1 ws-sonnet-high; MF2 ws-opus-medium; MF3 ws-opus-medium; MF4 ws-opus-medium; MF5 ws-opus-medium;
MF6 ws-sonnet-high; MF7 ws-opus-medium). Each agent's prompt: the brief's path, this plan's path as the umbrella, the repo(s) it works
in, and the worktree convention `git -C ~/Github/CalCOFI/<repo> worktree add ~/Github/CalCOFI/.worktrees/<repo>-ws-<id> -b ws-<id>`.
Remind each: never install a package into the shared R library while a render runs, never push, never touch another workstream's files,
hand back branch + SHAs + tests run + one Measured line. While they run: confirm gcloud runs as the calcofi-admin service account and
gs://calcofi-files-public/measurement-media/ is writable; read the landing repo's fetch_release.sh and refresh.yml — including its
species-media block, which is the worked example of the version-free media layout MF4 must follow.

Wave 2 — merge MF1 → MF2 into workflows (registries), MF1 → MF3 → MF7 into calcofi4db (bump to the next minor, NEWS.md, install while no
render runs, devtools::test()); build a bridge measurements.json 1.1 from v2026.09.10 with the merged builder and upload it to
gs://calcofi-db/ducklake-staging/releases/v2026.09.10/measurements.json (set MEASUREMENTS_RELEASE_URL on the landing repo, as the catalog
did). Merge MF4 into the landing repo, run the fetcher for the eleven cast keys (--only) and diff against the probe, then all 89 keys;
upload. Merge MF5 onto the same branch, build against the bridge record and the real media, run check_measurement_faces.py,
check_jsonld.py, check_layout.py, check_brand.py; hand-read the eleven cast pages plus five stand-ins. Open the PR with § Verification as
its checklist, merge when green, confirm live in both themes. Merge MF6 (docs, skill). Append every measured number to § Measured with
the date. Schema 1.1 and the deeper climatology reach the release at the next run — do not cut one for them.

Stop and ask Ben only for: D9's yes, a credential, a source that refuses the whole run, or a number that contradicts the plan. When done,
tell Ben in one message: what is live, the coverage by face kind, and what waits for the next release.
```

## Measured (appended per workstream as it ships)

- 2026-09-11 — the probe (Appendix B; numbers from v2026.09.10):
  - Anomaly per band, trend per decade 1984–2021 (years with ≥ 2 cruises): **oxygen** 0–10 −0.83, 10–50 −3.04, 50–100 −3.93, 100–200
    −4.40, 200–500 −6.56 µmol/kg (lows 2012 at 100–500 m); **nitrate** 0–10 +0.05, 10–50 +0.22, 50–100 +0.53, 100–200 +0.51, 200–500
    +0.23 µmol/L; **temperature** within ±0.08 °C per decade in every band, highs 2015 (0–10 m, +2.10) and 1983 (10–500 m, up to +2.20);
    **salinity** within ±0.01; **chlorophyll-a** 0–10 m +0.02, low 2015 (−0.81 µg/L). Values per band with a climatology: temperature
    283,364, salinity 280,678, oxygen 259,310, nitrate 213,375, chlorophyll-a 171,079; below 500 m without one: 117,302 / 105,689 / 81,423
    / 26,076 / 75.
  - Computed at the record's surface medians (bottle T 16.08 °C, SP 33.472; DIC 2009.8, TA 2234.65 µmol/kg): seawater of S 35 freezes at
    −1.91 °C; Reference Salinity 33.63 g/kg, Na⁺ + Cl⁻ 85.7 %; O₂ saturation 245.2 µmol/kg; pH_T 8.07, HCO₃⁻ 91.3 %, CO₃²⁻ 8.0 %, CO₂
    0.67 %, Ω_aragonite 2.5, pCO₂ 368 µatm (PyCO2SYS 1.8.3, Lueker et al. 2000).
  - Structures: 13 drawn (O₂ 1.7 KB … chlorophyll-a 32 KB); 23 of 23 CAS numbers resolve on Wikidata, 8 with a structure image.
  - NOAA ONI: 16 strong El Niño years 1950–2026 (≥ +1.5); JJA 2026 +1.80.
- 2026-09-11 — the findings pass (main session): F8.

- 2026-09-11 — **findings pass shipped to the staged ingests** (not released): CTD re-staged and synced 11:25 (forced rebuild; the first attempt died in a reboot): `obs` salinity_ave_corr < 20 PSU 2,797 → 95, temperature_ave > 35 °C 18 → 1, 2024-01-33UD median salinity 17.13 → 34.08; residual = single-sensor faults for the CTD team. **Correction the same afternoon:** that run also rewrote the oxygen averages (OxAve_StaCorr on 2.65 M scans by 0.1–0.4 ml/L where Ox2_StaCorr is empty; OxAveuM_StaCorr up to 225 µmol/kg on 2022-04-3322) — the mode-3 rule is now temperature- and salinity-only, oxygen asked as ctd-cast Q34, CTD re-staged again. Bottle re-staged 08:40: nitrate 6 of 7 dropped (56.0 waits for Q14), 2 salinities beside impossible temperatures. Landing PR #21 (5faa8c2): a key with no category takes its dataset's, so /measurements/ draws the 17 METS keys again and check_layout.py is green on main (DATA_SECTION_BASE 2974 → 3099).

- 2026-09-12 — **WS-MF1** (workflows `8ca1bdf`, calcofi4db `47cee6f6`): against v2026.09.11 (89 keys / 94 series) 51 keys carry a NERC P01 (26 structure, 13 composition, 10 scale, 2 organism); of the 38 without, 19 borrow another key's face (D3), 16 show only their own scale, 1 (`uws_flow`) shows nothing; registries chem 101 rows, method 94 (75 sourced from calcofi.org or the record, 19 METS/underway/CTD-PAR rows `source = "not found"` — the underway page is a client-rendered empty shell, checked live), scale 36 marks over 9 keys, face 89; `nerc_l22` filled twice on an exact device (SBE 43 `TOOL0036`, Portasal 8410 `TOOL0242`); `validate_measurement_faces()` 0 findings.
- 2026-09-12 — **WS-MF2** (workflows `62d2b71`, docs `978cf33`): `measurement_why.csv` 422 rows over 88 of 89 keys, 88 rank-1 authored picks across 29 concepts, each with a bibkey; alternatives 117 authored, 146 wikipedia, 69 goos, 2 calcofi; 22 new BibTeX entries in `../docs/refs/refs.bib`, every DOI 302 through doi.org and every abstract read; 4 of the 8 GOOS sheets (subsurface temperature, subsurface salinity, phytoplankton, microbes) carry no scientific question, so those keys link the sheet. Three mockup picks were uncited (chlorophyll-a, *Synechococcus*, the ISUS estimate) and were cited or demoted to rank 2. The CSV re-emitted through `register_measurement_why()` is byte-identical.
- 2026-09-12 — **WS-MF3** (calcofi4db `e0f7cb45`, workflows `0578ead`): `measurements.json` 1.1 — the per-band anomaly reproduces `anom_bands.csv` exactly (1,687/1,687 rows, max diff 0; F6's trends recovered) and on v2026.09.11 covers 71 of 89 keys over 362 bands with a normal + 164 deeper bands named; `observed{}` moved inside `qual_ok`, exposing 48,427 flagged values as `n_flagged` (equal to `n_values − qual_ok_n` on all 94 series, so the record and landing #22's arithmetic agree). `build_climatology()` to the bottom on v2026.09.10 at `min_cruises = 5`: 714,882 → 734,410 rows (+2.7 %), 500 → 720 m, 8.98 → 9.27 MB, purely additive (the Explorer's `section_clim.sql` returns the identical 21,306 cells at or above 500 m plus 533 new at 510–720 m over 8 lines). `devtools::test()` 3,296 passing, 0 failed, on calcofi4db 4.15.0.
- 2026-09-12 — **WS-MF4** (landing `a1ff472`, `c1d59be`): the fetcher walks the record in 138 s cold / 65 s warm; the eleven cast keys reproduce every structure the probe drew with a `viewBox` delta of 0.0 (63 of 65 drawings over all keys; silicate's probe SVG is not reproducible from the probe's own inputs). NERC S06 `S0600045` ("Concentration") never answers and is remembered per run. Against the **1.1 bridge**: 89 keys, 51 own NERC chains + 19 borrowed, 56 ChEBI records, 87 SVGs (616 KB), 53 keys with a drawn structure, 88 leads, 19 stands-in, DIC's CHEBI:27594 skipped on 6 keys; `check_measurement_faces.py` OK; uploaded 2026-09-12 to `gs://calcofi-files-public/measurement-media/` (sidecar `release` v2026.09.11, no version in the layout).
- 2026-09-12 — **WS-MF6** (docs `9862e8b`, workflows `67e325c`): `db.qmd` § *A face for every measurement page* (Figure 4.3, the mockup's light nitrate head 1118×1578 until the live shot replaces it), `millero2008` in refs, the `metadata-registries` skill's *Measurement faces* pointer; html/docx/pdf rendered with zero new warnings (42 s / 46 s / 53 s; 175 KB / 8.0 MB / 7.4 MB).
- 2026-09-12 — **WS-MF7** (workflows `8c27276`; calcofi4db unchanged): D9 as Ben re-decided — the picoplankton counts move to `obs_bio`: 60,802 rows, one `measurement_type` (`picoplankton_abundance`), four `taxon_key`s (`worms:160572` 16,002; `worms:345515` 12,789; `cce-lter_picoplankton-bacteria:picoeukaryotes` 16,009; `:het_bacteria` 16,002, the last two allowlisted dataset-local keys as ZooScan's are); `check_taxon_ids()`, `check_obs_pair_parity()`, `validate_taxa_catalog()` green; at the next release `measurements.json` goes 89 → 85 keys / 94 → 90 series and `obs_env` 29,838,093 → 29,777,291. Integrator's trap: a manifest committed from a worktree render whose parquet went to a scratch stage dir makes `write_parquet_outputs()` "reuse" the stale file in the real stage dir (the dedup trusts the manifest hash, not the file) — the August `obs.parquet` was deleted and the target re-run.
- 2026-09-12 — **integrator**: the bridge `measurements.json` 1.1 built from v2026.09.11 with calcofi4db 4.15.0 in 6.6 s (777,810 bytes; 89/94/5, `obs_env_rows` 29,838,093, identical to the promoted 1.0 record in every 1.0 field except `observed{}` on 33 series and the added `n_flagged`), uploaded to `gs://calcofi-db/ducklake-staging/releases/v2026.09.11/measurements.json`; `MEASUREMENTS_RELEASE_URL` set to it, and `fetch_release.sh` now lets a set variable override the promoted record (every promoted release carries a 1.0 file, so a fill-the-gap bridge could never be read).

## Appendix A — the registries, `measurements.json` 1.1 and `measurements_media.json`

```
metadata/measurement_chem.csv    key,chebi_id,role,mass_fraction,via,source,source_url,note
                                 role ∈ the_thing | component | conjugate | method_product | one_of ; via ∈ nerc_s27 | registry
metadata/measurement_method.csv  dataset_key,measurement_type,platform,instrument,nerc_l22,principle,steps,wavelength_nm,precision,
                                 bibkeys,calcofi_org_url,text_fragment,source,source_url
metadata/measurement_scale.csv   key,value,lo,hi,label,kind,how,source,source_url      kind ∈ familiar | physical | threshold | computed
metadata/measurement_why.csv     key,rank,kind,text,bibkeys,source_url,eov,goos_doc    kind ∈ authored | goos | wikipedia | calcofi
metadata/measurement_face.csv    key,face_kind,face_of,stands_in_note,source           face_kind ∈ structure | composition | scale | organism | standsin | none
```

`measurements.json` 1.1, one key (additive to 1.0):

```
{ "key": "oxygen_umol_kg", … ,
  "face":   { "kind": "structure", "face_of": null },
  "chem":   [ { "chebi": "CHEBI:15379", "role": "the_thing", "via": "nerc_s27" } ],
  "method": [ { "dataset_key": "calcofi_bottle", "measurement_type": "oxygen_umol_kg", "platform": "bottle",
                "instrument": "Automated Winkler titrator, UV end point", "principle": "Carpenter (1965) modification of Winkler …",
                "steps": ["Mn²⁺ + 2OH⁻ → Mn(OH)₂", "…"], "wavelength_nm": 350, "bibkeys": ["carpenter1965"],
                "calcofi_org": "https://calcofi.org/sampling-info/methods/bottle-sampling-methods/#:~:text=Dissolved%20Oxygen%20Sampling" }, … ],
  "scale":  [ { "value": 61.0, "label": "hypoxic (1.4 ml/L)", "kind": "threshold", "bibkeys": ["bograd2008"] },
              { "value": 245.2, "label": "air-saturated at the surface medians", "kind": "computed", "how": "gsw.O2sol_SP_pt(33.472, 16.08)" } ],
  "why":    [ { "rank": 1, "kind": "authored", "text": "Below the mixed layer …", "bibkeys": ["bograd2008"] },
              { "rank": 2, "kind": "authored", … }, { "rank": 3, "kind": "goos", "text": "How large are the ocean's …", "goos_doc": "…/17473" } ],
  "anomaly": { "baseline": [1993, 2013], "ymax": 31.328, "spark_band": "200-500",
               "bands": [ { "band": "0-10", "n_values": 23134, "series": [[1950, 7.34, 2, 312], …],
                            "trend": { "per_decade": -0.826, "from": 1984, "to": 2021 }, "ext": { "hi": [1975, 8.93], "lo": [1951, -18.22] } }, … ],
               "deeper": [ { "band": "500-1000", "n_obs": 64316 }, … ] } }
```

`measurements_media.json` (the fetcher; D8):

```
{ "schema_version": "1.0", "release": "v2026.09.10", "fetched": "…",
  "oni": { "source": "https://www.cpc.ncep.noaa.gov/data/indices/oni.ascii.txt", "strong_el_nino": [1957, …, 2026], "latest": ["JJA", 2026, 1.80] },
  "measurements": { "oxygen_umol_kg": {
    "nerc": { "p01": "DOXMZZXX", "pref": "…", "definition": "…", "license": "CC BY 4.0",
              "s27": { "id": "CS002779", "chebi": "CHEBI:15379", "cas": "7782-44-7" }, "a05": "EV_OXY", "p07": "moles_of_oxygen_per_unit_mass_in_sea_water" },
    "structures": [ { "chebi": "CHEBI:15379", "name": "dioxygen", "formula": "O2", "charge": 0, "mass": "31.998", "definition": null,
                      "viewBox": "25.8 73.4 167.8 32.8", "svg_inner": "<path …/>", "drawn_by": "RDKit 2026.03 from the ChEBI molfile" } ],
    "wikipedia": [ { "title": "Ocean deoxygenation", "revision": 1354922617, "license": "CC BY-SA 4.0", "extract": "…" } ] } } }
```

## Appendix B — the sources, as probed (2026-09-11)

| Source | Keyed by | In the probe | Verdict |
|---|---|---|---|
| NERC NVS (P01 + S27/S25/S06/S26/P02/P06/P07/A05) | the P01 URI in `measurement_type.csv` | 20 of 24 P01s; S27 → ChEBI 9/9, S25 → WoRMS 2/2, A05 on 6/20; ~15 s per concept with links | use · the key ring (CC BY 4.0) |
| ChEBI API + molfile | the S27's `sameAs` | 13 of 13 structures; roles nonsense (dioxygen "anti-inflammatory drug"; carbon atom "antidepressant") | use · structures, never roles (CC BY 4.0) |
| RDKit | — | 13 of 13, 1.7–32 KB; SMILES layout wrecks chl-a | use · at fetch time |
| Wikidata · PubChem | CAS (P231) / ChEBI (P683) | 23/23 CAS resolve; 8 with P117 images | ids only |
| TEOS-10 Manual Table D.3 | — | the 15-solute Reference Composition | a registry row per ion |
| gsw · PyCO2SYS | — | the computed marks and the Bjerrum curve | computed, named |
| GOOS EOV sheets (oceanexpert.org PDFs) | EOV name | 8 sheets; questions/drivers/phenomena; "all rights reserved" site | quote the question, link |
| calcofi.org methods pages | page + text fragment | bottle page and CTD FAQ rich; DIC, underway, phyto/bacterio pages empty to a fetcher | author from, link |
| NCEI 0301029 | the DIC `link_data_source` | instrument keywords | fill a gap |
| NOAA CPC ONI | — | 16 strong years; JJA 2026 +1.80 | the shading |
| Wikipedia | a curated title per key | 22 titles, 21 resolve; pH and Beaufort tables | alternatives + scales (CC BY-SA 4.0) |
| The release | the key | v2026.09.10, 89 keys; `obs_env` ⋈ `climatology` | the only source of numbers |
