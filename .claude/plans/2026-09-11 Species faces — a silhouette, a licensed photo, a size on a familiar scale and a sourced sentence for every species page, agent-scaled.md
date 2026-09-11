# Species faces — a silhouette, a licensed photo, a size on a familiar scale and a sourced sentence for every species page, agent-scaled

**Status:** proposed 2026-09-11 from the mockup; **Ben decided the five open questions the same evening** (§ Open questions →
Answers): the silhouette is the constant, full-colour photos where a licensed one exists, non-commercial licences accepted,
full-colour ink, the ship stays on the ladder, and the three courtesy emails are drafted (Appendix B; Gmail drafts created
2026-09-11, unsent). Nothing is built. **Spec:** the mockup artifact *CalCOFI Species Faces* —
https://claude.ai/code/artifact/34135a47-7597-41af-ad58-5328bde815dd — ten cast taxa (sardine, anchovy, hake, lanternfish,
krill, market squid, sooty shearwater, common dolphin, *Chaetoceros*, *Sebastes*), every asset fetched live on 2026-09-11 with its
licence and credit, the composed head in both themes, the face options, the treatments, the size ladder, the sentence, the
sources ledger and the build. **Scale:** six workstreams (≈ 6 agent-days) in two waves — wave 1 is parallel and needs no
release (the fetcher, the sizes, the page against a fixture, the index glyphs, the docs, and `n_present` in `calcofi4db`);
wave 2 is the integrator's (the full fetch, the checks, the PR, the deploy); `n_present` rides the next release. **Sits on** the
species catalog (`2026-09-09 Landing follow-ups …` § D5–D8, D11: `taxa.json`, `_plugins/species.rb`, `_layouts/species.html`,
`assets/species.js`) and copies the measurements catalog's agent-scaled shape (`2026-09-10 Measurements catalog …`).
**Probe scripts, the raw probe and the fixture:** `.claude/plans/2026-09-11 species-faces-probe/` (README there).

## The ask (Ben, 2026-09-11)

> The species pages are quite dry and static and don't say much about the actual species. Explore in a mockup artifact
> different design ideas for systematically fetching Creative Common images or drawings for every given species (or taxa)
> applying a common style / filter (eg dark or light fade from center) perhaps with something creative (a human / a quarter
> profile) to provide perspective on its size. indicate the relative. Perhaps calling and citing allowable sources like
> MarineSpecies.org (ie WoRMS), WikiSpecies, iNaturalist, eBird. I'm open to your ideas!

On the mockup: "Fantastic! File as a plan with prompt for a new session and overseeing agent suggested model + effort to issue
sub-agents in parallel" — and the decisions: "go with the silhouette-constant, show full color photos where available,
non-commercial licenses accepted, full color ink, ship stays, yes compose courtesy ask emails".

## Context, measured 2026-09-11 (calcofi.io live on v2026.09.06)

- **The live species page** (`/species/worms-217452/`): lineage › name › common name › WoRMS · ITIS · GBIF ids › the stats
  band › *Observed in* rows › the years strip › *Ways in*. `_layouts/species.html` reads `page.*` from `_plugins/species.rb`,
  which reads `taxa.json` and nothing else. Nothing on the page describes the organism.
- **`taxa.json`** (v2026.09.06): 2,410 pages, 1,506 observed taxa, 1,008 species; each taxon carries
  `ids{worms_id, itis_id, gbif_id, ncbi_id, inat_id}` — `worms_id` on every WoRMS-keyed taxon, `itis_id` widely, `gbif_id` on
  part of the record, `ncbi_id` and `inat_id` empty. Wikidata fills the rest from the WoRMS id.
- **The probe** (12 taxa × 8 sources, `species-faces-probe/fetch_media.py` + `phylopic_names.py`; Appendix C has the numbers):
  PhyloPic resolves 4 of 12 by WoRMS id and 12 of 12 by name with a walk up the lineage; Wikidata has an item for 12 of 12
  (11 with an image, 12 with an English article); Commons gives the licence per file; iNaturalist's curated taxon photos are
  licensed per photo (5 defaults NC, 4 all-rights-reserved); GBIF has 38–4,061 images per taxon; WoRMS has a checked body size
  for 7 of 12; FishBase/SeaLifeBase have a max length for all 9 fishes, crustaceans, squid and the dolphin, and egg/larval
  lengths for 5 fishes citing Matarese et al. 1989 and the Atlas 33 chapters; NOAA AFSC's Ichthyoplankton Information System
  served a developmental plate for 4 of 4 fishes tried.
- **Zero counts:** in `obs_bio` of v2026.09.10 (the cached release), rows with `value = 0` are 75.5 % of CUFES, 85.0 % of
  phytoplankton, 82.9 % of phyllosoma, 67.5 % of crab and 42.5 % of zoodb; ichthyoplankton, euphausiids, birds/mammals and
  mesopelagic fish are positive-only. The sardine's 49,572 CUFES "obs" on its page are 38,929 zeros; every CUFES species shows
  the same 49,572 and the same 1998 peak.

## Findings

- **F1** A silhouette is the only picture every page can have: PhyloPic's nearest-ancestor fallback never fails, the vector
  is 2–12 KB, and filled with `currentColor` it is navy on white and bone on navy without a second file.
- **F2** The photo sources do not agree on anything except the licence field: Commons `extmetadata`, iNaturalist
  `license_code` (`null` = all rights reserved), GBIF `media[].license`. The GBIF `license=` query parameter filters the
  *dataset*, not the image — NC-ND items came back through a CC0/CC BY filter.
- **F3** The first raw photo is rarely the portrait (a sardine on sand, a hake's head on a rock, a rockfish in a hand); the
  curated ones are — Commons P18 and category files, iNaturalist's `taxon_photos`. Wikidata's P18 for the Pacific sardine is
  the Japanese sardine, and PhyloPic's silhouette is drawn from it too: the caption has to name what is shown.
- **F4** eBird/Macaulay media belong to the contributors and may not be downloaded for third-party use; the eBird API is data
  only. FishBase and WoRMS photos are per photographer. NOAA Fisheries' consistent adult drawings are credited
  "NOAA Fisheries/Jack Hornady", a contractor. All four are link-outs or asks, never fetches.
- **F5** The lengths already exist and already cite CalCOFI: WoRMS body-size attributes (FishBase's, `checked`), SeaLifeBase for
  the invertebrates, FishBase `eggs`/`larvae` (`Eggdiammin/max`, `LhMin/Max`, `FlexLength*`, `TransLength*`) with reference
  265 = Matarese, Kendall, Blood & Vinter 1989 (NOAA Tech. Rep. NMFS 80) and Moser 1996's Atlas 33 chapters.
- **F6** The AFSC Ichthyoplankton Information System serves one plate per fish — egg to 31 mm larva with lengths —
  at `LHDataIll.php?GSID=Genus!species` → `images/ill/Genus!speciesPage.gif`, from the 1989 NOAA report, a US Government
  work in the public domain; the site asks to be cited. It is the picture of what the ichthyoplankton and CUFES datasets record.
- **F7** A CalCOFI-native size ladder needs no invented numbers: the bongo mesh (505 µm) and ring (71 cm) are the
  programme's own, the quarter (24.26 mm) and a person (1.7 m) are universal, R/V Reuben Lasker (63.8 m) is the flourish.
- **F8** "Observations" on the species page counts CUFES rows, not organisms (§ Context). The record needs `n_present`
  beside `n_obs`; the page needs the honest word in the meantime.

## Decisions (each with what the workstreams build; all confirmed by Ben 2026-09-11)

### D1 — The constant is the silhouette; the photo is the enrichment
Every page gets the PhyloPic silhouette in the page's ink (`fill: currentColor`), resolved by WoRMS id, then by name at each
rank up the lineage until an image exists, and flagged "drawn from *X*, n ranks up" when the image's `specificNode` is not the
page's taxon. A photo appears when one passes D7; when none does the slot is absent and the layout does not change.
*(Ben: "go with the silhouette-constant, show full color photos where available".)*

### D2 — One frame, one fade, full-colour ink
A fixed 3 : 2 crop with a stored focal point and a radial mask (`mask-image: radial-gradient(ellipse 74% 70% at 50% 50%,
#000 40%, transparent)`) that dissolves the edges into whatever ground the page has, so the same file sits on sand and on
navy. Full colour: the field marks survive. The muted and brand-blue inks stay in the mockup as rejected alternatives.
*(Ben: "full color ink".)*

### D3 — The size: a two-bar glance in the head, the ladder and the beside-figure on the page
The head shows two bars — the taxon's max length and the nearest familiar reference (the reference within an order of
magnitude whose log-ratio is smallest; hair and mesh excluded from "familiar"). The page's *How big* section draws the log
ladder (10 µm → 100 m, the six references of F7, the ship included) with the taxon's marks under the axis (adult max; for
fishes the egg, hatching, flexion and transformation lengths) and the silhouette to scale beside the nearest reference with
the sentence ("2 of them, nose to tail, would span the bongo-net ring"). No length on record → "not on record", nothing drawn,
never a typed number. The references live in `size_reference.csv` with their sources. *(Ben: "ship stays".)*

### D4 — The sentence: borrowed prose, generated facts, each part marked
Wikipedia's lead, first one or two sentences (≤ 320 characters), under CC BY-SA 4.0 with a link to the revision; "(Wikipedia
has only the genus.)" when the sitelink lands above the species. Then the record's own numbers as a sentence ("CalCOFI holds
62,898 records of it in 2 datasets between 1951 and 2022, as egg and larva"), then WoRMS's authority and the max length.
Rendered server-side in Liquid (it is content, not a figure); the three parts carry `class="s-wp | s-rec | s-au"` and the page
underlines them in the source colours with a legend.

### D5 — The larval plate, from NOAA now, from Atlas 33 later
For fishes with an AFSC plate: the plate beside the FishBase egg/larval lengths, credited "Matarese, Kendall, Blood & Vinter
1989, NOAA Tech. Rep. NMFS 80, via the AFSC Ichthyoplankton Information System" with a link to the species' IIS page. A courtesy
email to AFSC goes out before the pages ship (Appendix B). Atlas 33 extraction is deferred until AFSC lacks a species and SWFSC
answers (Appendix B).

### D6 — `taxa_media.json` is built by the landing repo's fetcher, not by the release
The media depend on eight external services and change on their own cadence; the release must stay reproducible. So
`scripts/fetch_species_media.py` (+ `scripts/fetch_species_sizes.R`) in CalCOFI.github.io runs weekly in a new
`species-media.yml` workflow and by hand after a release, walks `taxa.json`, and writes `taxa_media.json` + 800 px WebP
thumbnails to `gs://calcofi-files-public/species-media/{release}/`; `scripts/fetch_release.sh` (run by `pages.yml`, `pr.yml`,
`refresh.yml` and `check-brand.yml`) pulls the JSON into `_data/` like the other release files (git-ignored). The generator
merges by `taxon_key`; a taxon without media renders exactly as today.

### D7 — The licence policy and the ranking
**Take:** CC0, public domain (incl. the Public Domain Mark), CC BY, CC BY-SA (the cropped, faded copy is shared under the same
terms). **Take, rank last, label:** CC BY-NC, CC BY-NC-SA — the caption shows the licence. **Leave:** any ND (the crop and the
fade are derivatives) and anything without a licence field. **Never fetch:** Macaulay, FishBase and WoRMS photos, Hornady's
drawings, until a written yes. **Rank, per slot:** the page's taxon, then a species under it (a genus page shows one and names
it), then an ancestor within two ranks flagged "stands in"; curated over raw (Commons P18 and category, iNaturalist
`taxon_photos`, the NOAA plate) before the first research-grade observation; then licence order CC0 › PD › BY › BY-SA › NC;
then landscape and ≥ 800 px on the long side. Every asset carries `{source, id, url, page, license, license_url, credit,
taxon_shown, steps_up, fetched}`. *(Ben: "non-commercial licenses accepted".)*

### D8 — Pictures are cached, never hot-linked
Thumbnails at 800 px (WebP, quality 80) on the public bucket, so pages are stable, iNaturalist's S3 is not hot-linked, and the
source URL beside each is what the caption links to. The JSON-LD `Taxon` gains `image` as an `ImageObject` with
`contentUrl`, `license`, `creditText` and `acquireLicensePage`.

### D9 — `n_present` beside `n_obs`, and the honest word meanwhile
`calcofi4db::build_taxa_catalog()` adds `n_present` (rows with `value > 0`) to `direct`, `rollup` and `datasets[]`
(`taxa.schema.json` 1.1, additive), with a fixture test that holds a zero row; it reaches `taxa.json` at the next release.
Until then the page's stat and the sentence say **records**; when `n_present` is present the stat reads
`n_present` "observations" with `n_obs` "records" beside it, and the sentence uses `n_present`.

### D10 — Documentation
The landing README's *The species catalog* gains *Faces* (the sidecar, the policy, the credit line, the check); the docs book's
chapter that describes the species catalog gains one paragraph and the figure of a head with its face row (docs-compendium
rule: the chapter changes in the same change); `RELEASES.md` `# Unreleased` gets the `n_present` line; the `taxon-reference`
skill gets a two-line pointer to the fetcher and the policy.

## Architecture — what changes, by repo

| Repo | File | What | Owner |
|---|---|---|---|
| **calcofi4db** | `R/catalog_taxa.R`, `inst/schema/taxa.schema.json` (→ 1.1), `tests/testthat/test-catalog_taxa.R`, `NEWS.md` | `n_present` in `direct`, `rollup`, `datasets[]`; schema; fixture test with a zero row | WS-F1 |
| **workflows** | `RELEASES.md` `# Unreleased` | "taxa.json 1.1: `n_present` beside `n_obs`; CUFES rows include zeros" | WS-F1 |
| **CalCOFI.github.io** | `scripts/fetch_species_media.py`, `scripts/check_species_media.py`, `.github/workflows/species-media.yml` (new, weekly), `scripts/fetch_release.sh`, `.gitignore` | the fetcher (PhyloPic → Wikidata → Commons → Wikipedia → iNaturalist → GBIF → WoRMS → NOAA IIS), the cache, the thumbnails, the merge with `sizes.json`, the check | WS-F2a |
| | `scripts/fetch_species_sizes.R`, `_data/size_reference.csv` | FishBase / SeaLifeBase max length, egg and larval lengths with references → `sizes.json`; the ladder's references with sources | WS-F2b |
| | `_plugins/species.rb`, `_layouts/species.html`, `_includes/species_face.html`, `_includes/species_size.html`, `assets/species.js`, `style.css`, `scripts/check_jsonld.py`, `scripts/check_layout.py`, `_data/shots.yml`, `README.md` | the face row, the sentence, the glance, the ladder + beside + plate figures, JSON-LD `image`, the checks, the reshoot | WS-F3 |
| | `_layouts/species_index.html`, `assets/species.js` (the tree), `index.html` (the Life tile), `style.css` | class-level silhouettes in the tree and a six-silhouette strip on the Life tile | WS-F4 |
| **docs** | the species-catalog chapter (find it via the `docs-compendium` skill's chapter table) + `data/` snapshot if a number is stated | one paragraph, one figure, one caption | WS-F5 |
| **workflows** | `.claude/skills/taxon-reference/SKILL.md` | the pointer to the fetcher and the policy | WS-F5 |

Shared files: `assets/species.js` and `style.css` are touched by F3 and F4 — F4 appends its own `// ── index glyphs` /
`/* ── index glyphs */` sections and never edits F3's; the integrator merges F3 first.

## Workstreams and agents — who runs what, in which wave

| WS | Brief | Agent (model · effort) | Depends on | Days |
|---|---|---|---|---|
| F1 | `n_present` in the taxa record (calcofi4db) + the RELEASES.md line | `ws-opus-medium` (Opus · medium) | — | 0.5 |
| F2a | the media fetcher, cache, thumbnails, merge, check (Python) | `ws-opus-medium` (Opus · medium; raise to high if the per-source quirks trip it) | the schema in Appendix A | 1.5 |
| F2b | sizes and early-life lengths (R, rfishbase) + `size_reference.csv` | `ws-sonnet-high` (Sonnet · high) | the `sizes.json` contract in Appendix A | 0.5 |
| F3 | the page: face row, sentence, glance, ladder, plate, JSON-LD, checks, reshoot | `ws-opus-medium` (Opus · medium) | the fixture `taxa_media.sample.json` (exists) | 1.5 |
| F4 | index tree glyphs + the Life tile strip | `ws-sonnet-high` (Sonnet · high) | the fixture | 0.5 |
| F5 | docs chapter, landing README section, skill pointer | `ws-sonnet-high` (Sonnet · high) | the mockup (for the figure) | 0.5 |
| F6 | integration: full fetch, sample review, checks, PR, deploy, the emails go out (Ben) | the integrator session (Fable 5.1 · high) | F2a + F2b, then F3 + F4 + F5 | 1 |

Wave 1: the six briefs F1, F2a, F2b, F3, F4, F5 in parallel, one `Agent` call each in ONE message, `isolation: worktree`.
Wave 2: F6. The briefs are the files `.claude/plans_todo/WS-F1.md`, `WS-F2a.md`, `WS-F2b.md`, `WS-F3.md`, `WS-F4.md`,
`WS-F5.md` (Read first · You own · Do · Gates · Hand back, the WS-M form); each names this plan as its umbrella.

## Verification (what "done" means, per workstream)

- **F1**: `devtools::test()` green with the new fixture (a dataset whose rows include `value = 0`): `n_present < n_obs` for it,
  `n_present == n_obs` for a positive-only dataset, `rollup.n_present` sums over descendants; the schema validates; the measured
  zero shares per dataset pasted into § Measured.
- **F2a**: `python scripts/fetch_species_media.py --only species-faces-probe/cast.txt` reproduces the ten cast records
  (same silhouette uuids, same photo files or better-ranked ones, same licences); `check_species_media.py` passes on the output
  (every asset allow-listed, credited, a live URL, `taxon_shown` within two ranks); a full run is resumable (kill and restart
  continues) and rate-limited (PhyloPic ≤ 2 rps with `build`; Wikidata SPARQL batched in `VALUES` of 100; Commons 50 titles per
  query; iNaturalist ≤ 1 rps; a User-Agent with a contact on every request); coverage per source and runtime reported.
- **F2b**: `sizes.json` holds a max length for every fish in `taxa.json` FishBase knows and every invertebrate SeaLifeBase knows,
  with `length_type` and the FishBase `SpecCode`; egg/larval rows carry their `RefNo` and its citation; `size_reference.csv`
  has a source per row; the six ladder numbers of F7 come from that file, not from code.
- **F3**: `/species/worms-217452/` shows the face row, the sentence with three underlined parts, the glance, the ladder with
  five marks and the plate; `/species/worms-148985/` (*Chaetoceros*) shows the silhouette and photo, "not on record" for size,
  no plate, no gap; `/species/itis-1255050/` (sooty shearwater) shows an *Ardenna* silhouette flagged "drawn from Ardenna
  creatopus, 1 rank up"; `check_jsonld.py` finds an `ImageObject` with `license` and `creditText` on every page that has a
  photo; `check_layout.py` passes at 1470 / 375 in both themes; the reshoot in `_data/shots.yml`.
- **F4**: the `/species/` tree shows a silhouette on every phylum and class row; the Life tile shows six; the tree's search
  and expand are unchanged (`check_layout.py`).
- **F5**: the docs chapter renders (html; the docx/pdf builds still pass — `feedback_docs_book_gt_word_export`), the figure is
  numbered and referenced, no number is typed; the README section exists; the skill pointer exists.
- **F6**: the full fetch covers 2,410 taxa; coverage measured (silhouettes 100 %, photos ≥ 60 % expected, plates for the
  fishes AFSC covers); 30 pages sampled by hand across the ten classes with the most observations; the PR passes the three checks
  and the brand check; live at calcofi.io/species/ in both themes; the emails sent by Ben.

## Risks, and what bounds them

- **A source rate-limits or changes shape mid-run** — the fetcher is resumable per taxon per source with a local cache; a
  source that fails leaves that slot empty and the run continues; the check refuses to publish a JSON with < 95 % silhouettes.
- **A caption misnames what is shown** (F3 finding) — `taxon_shown` is read from the source (PhyloPic `specificNode`, the
  Commons file's category, iNaturalist's taxon), never assumed; the check asserts it is within two ranks of the page's taxon.
- **An all-rights-reserved photo slips through** — the policy is a whitelist on the normalised licence; `null` is never mapped.
- **The plates draw complaints** — public domain by law, but the AFSC courtesy email goes out before the pages ship and the
  credit line is theirs to word.
- **Photos of the wrong life stage or a dead specimen** — the ranking prefers curated files; the integrator's 30-page sample
  can demote a source per class (a `rank_override.csv` keyed by taxon_key, hand-curated, never large).
- **`n_present` changes a published number** — it is additive; `n_obs` stays; the RELEASES.md line says why.

## Open questions (for Ben) — ANSWERED 2026-09-11

1. Silhouette-constant vs photo-first → **silhouette-constant, full-colour photos where available.**
2. Allow NC licences → **yes**, ranked last and labelled (D7).
3. The ink → **full colour** (D2).
4. The ship on the ladder → **stays** (D3).
5. The courtesy asks → **yes, compose them** → Appendix B; Gmail drafts created 2026-09-11 (AFSC addressed to the IIS
   contact on its page; the NOAA Fisheries and SWFSC drafts need Ben's recipients).

## Kickoff prompt (the integrator session — Claude Fable 5.1 · effort high; cwd `~/Github/CalCOFI/workflows`)

```
You are the integrator for the plan ".claude/plans/2026-09-11 Species faces — a silhouette, a licensed photo, a size on a
familiar scale and a sourced sentence for every species page, agent-scaled.md". Read it end to end, then the six briefs
.claude/plans_todo/WS-F1.md, WS-F2a.md, WS-F2b.md, WS-F3.md, WS-F4.md, WS-F5.md, then the mockup it cites (open the artifact
URL with WebFetch) and the probe folder .claude/plans/2026-09-11 species-faces-probe/ (README first). Ben has decided every
open question (§ Open questions); do not re-open them.

Wave 1 — launch all six briefs in ONE message with the Agent tool, each with isolation "worktree" and the subagent_type the
plan's § Workstreams table names (F1 ws-opus-medium; F2a ws-opus-medium; F2b ws-sonnet-high; F3 ws-opus-medium;
F4 ws-sonnet-high; F5 ws-sonnet-high). Each agent's prompt: the brief's path, this plan's path as the umbrella, the repo it
works in, and the worktree convention: `git -C ~/Github/CalCOFI/<repo> worktree add ~/Github/CalCOFI/.worktrees/<repo>-ws-<id>
-b ws-<id>` (as the measurements catalog did; worktrees have no _targets/ or staging dirs, which none of these briefs need).
Remind each agent: never install a package, never push, never touch another workstream's files, hand back branch + SHAs +
tests run + one Measured line. While they run, do the integrator's own prep: confirm `gcloud` runs as the calcofi-admin
service account and that `gs://calcofi-files-public/species-media/` can be written; read the landing repo's refresh.yml and
fetch_release.sh so you know where F2a's lines land.

Wave 2 — when F2a and F2b hand back: merge F2b into F2a's worktree, run the fetcher for the ten cast taxa (`--only`) and diff
against species-faces-probe/taxa_media.sample.json (silhouette uuids and licences must match; photos may differ only by
ranking upward), then run the full fetch for all 2,410 taxa (expect 1–2 h; it is resumable), upload the JSON and thumbnails,
and paste the coverage per source into the plan's § Measured. Then merge F3, F4 and F5 in that order onto a single branch
`species-faces` of CalCOFI.github.io (F3 before F4: F4 appends to files F3 owns), build the site locally against the real
taxa_media.json, run scripts/check_species_media.py, check_jsonld.py, check_layout.py and check_brand.py, and hand-review 30
pages: the three most observed taxa in each of the ten classes with the most observations. Fix captions that misname what
is shown by adding rows to rank_override.csv, never by editing the fetched JSON. Reshoot _data/shots.yml. Open the PR with
the plan's § Verification as its checklist, merge when green, confirm live in both themes, and append every measured number
to § Measured with the date. calcofi4db (F1): review the branch, bump DESCRIPTION to the next minor, write the NEWS.md entry,
install, run devtools::test(), merge to main; it reaches taxa.json at the next release — do not cut one for it.

Stop and ask Ben only for: a credential, a source that refuses the whole run, a picture you believe is wrong for a whole class,
or a number that contradicts the plan. Everything else is decided. When done, tell Ben in one message: what is live, the
coverage, the three emails waiting in his Gmail drafts, and what waits for the next release.
```

## Measured (appended per workstream as it ships)

- 2026-09-11 — the probe: Appendix C. Nothing else yet.

## Appendix A — `taxa_media.json` in shape (schema 1.0) and the `sizes.json` contract

```
{ "schema_version": "1.0", "release": "v2026.09.06", "fetched": "2026-09-11T00:00:00Z",
  "policy": { "allow": ["CC0", "PD", "PDM", "CC BY", "CC BY-SA", "CC BY-NC", "CC BY-NC-SA"], "deny": ["ND", "ARR", "unknown"] },
  "coverage": { "taxa": 2410, "silhouette": 2410, "photo": 0, "drawing": 0, "plate": 0, "size": 0, "text": 0 },
  "taxa": { "worms:217452": {
    "silhouette": { "source": "phylopic", "uuid": "34c2ed3a-aa57-4e52-9ae8-a1e543c9bef8", "url": "https://www.phylopic.org/images/34c2ed3a-…",
                    "svg": "species-media/v2026.09.06/worms-217452/silhouette.svg", "license": "CC0 1.0",
                    "license_url": "https://creativecommons.org/publicdomain/zero/1.0/", "credit": "Mathieu Pélissié",
                    "taxon_shown": "Sardinops melanostictus", "resolved_by": "worms_id", "steps_up": 0, "aspect": 3.116, "length_axis": "w",
                    "viewBox": "0 0 1536 493", "svg_inner": "<g transform=…>…</g>" },   ← the normalised markup, inlined by the generator
    "photo":   { "source": "commons", "id": "File:Pacific sardine (Sardinops sagax) 01.jpg", "page": "https://commons.wikimedia.org/wiki/File:…",
                 "url": "https://commons.wikimedia.org/wiki/Special:FilePath/…", "license": "CC BY 2.5", "license_url": "…", "credit": "Tewy",
                 "taxon_shown": "Sardinops sagax", "steps_up": 0, "shows": "a school of Pacific sardines", "curated": true,
                 "cached": "species-media/v2026.09.06/worms-217452/photo.webp", "w": 800, "h": 533, "focal": [0.5, 0.5] },
    "drawing": { "source": "commons", "id": "File:Sardinops sagax.jpg", "license": "public domain", "credit": "J. H. Richard", … },
    "plate":   { "source": "noaa_iis", "url": "https://apps-afsc.fisheries.noaa.gov/ichthyo/LHDataIll.php?GSID=Sardinops!sagax",
                 "license": "public domain (US Government work)", "credit": "Matarese, Kendall, Blood & Vinter 1989, NOAA Tech. Rep. NMFS 80",
                 "cached": "species-media/v2026.09.06/worms-217452/plate.webp" },
    "size":    { "m": 0.395, "length_type": "SL", "kind": "max", "source": "worms_attribute", "source_id": 232797, "url": "https://www.marinespecies.org/aphia.php?p=taxdetails&id=217452#attributes" },
    "early":   [ { "stage": "egg", "mm": [1.34, 2.05], "source": "fishbase_eggs", "ref": 265 },
                 { "stage": "hatching", "mm": [3.5, 3.8], "source": "fishbase_larvae", "ref": 265 },
                 { "stage": "flexion", "mm": [9, 14], "source": "fishbase_larvae", "ref": 265 },
                 { "stage": "transformation", "mm": [25, 35], "source": "fishbase_larvae", "ref": 265 } ],
    "text":    { "source": "wikipedia", "title": "Sardinops", "url": "https://en.wikipedia.org/wiki/Sardinops_sagax", "revision": 1371053494,
                 "timestamp": "2026-08-24", "license": "CC BY-SA 4.0", "about": "genus", "extract": "…" },
    "links":   { "wikidata": "Q2069084", "inat": 55535, "fishbase": 1477, "gbif": 2412583, "ebird": null } } },
  "refs":    { "265": "Matarese, A.C., A.W. Kendall, D.M. Blood and M.V. Vinter. 1989. Laboratory guide to early life history stages of Northeast Pacific fishes. NOAA Tech. Rep. NMFS 80." } }
```

`sizes.json` (WS-F2b → merged by F2a into `size`, `early`, `refs`): `{ "<taxon_key>": { "fishbase": { "server": "fishbase|sealifebase",
"spec_code": 1477, "length_cm": 39.5, "length_type": "SL", "common_length_cm": 20, "egg_mm": [1.34, 2.05], "hatch_mm": [3.5, 3.8],
"flexion_mm": [9, 14], "transformation_mm": [25, 35], "refs": { "265": "…" } } } }`, keyed by the accepted name matched to
FishBase's `Species`, with the synonym table consulted when the accepted name misses. `size_reference.csv`:
`key,label,m,note,source` — hair (7.0e-5), mesh (5.05e-4, CalCOFI bongo), quarter (0.02426, US Mint), ring (0.71, CalCOFI
bongo), person (1.70), ship (63.8, NOAA R/V Reuben Lasker).

## Appendix B — the courtesy emails (drafted 2026-09-11; Gmail drafts created, unsent; Ben adds recipients where marked)

**1 · AFSC — the Ichthyoplankton Information System plates.** To: kimberly.bahl@noaa.gov (the contact on the IIS pages; cc
the project team as Ben sees fit). Subject: *Reusing the Ichthyoplankton Information System's developmental plates on
calcofi.io species pages.*

> Dear Kimberly and the IIS team,
>
> I build and maintain the integrated CalCOFI database and its website, calcofi.io, for the CalCOFI programme (Scripps
> Institution of Oceanography, NOAA SWFSC and CDFW). We publish one page per taxon observed in the CalCOFI time series
> (calcofi.io/species/), and we would like each fish's page to show what the ichthyoplankton and CUFES surveys actually
> collect: the egg and larval stages.
>
> Your Ichthyoplankton Information System serves exactly that — a developmental plate per species, for example
> https://apps-afsc.fisheries.noaa.gov/ichthyo/LHDataIll.php?GSID=Sardinops!sagax. We would like to display those plates,
> resized, for the California Current fishes the IIS covers, each credited "Matarese, Kendall, Blood & Vinter (1989), NOAA
> Technical Report NMFS 80, via the AFSC Ichthyoplankton Information System" with a link back to the species' IIS page, and to
> keep a cached copy on our own storage so we never load your server.
>
> Our understanding is that the plates are a US Government work in the public domain; I am writing as a courtesy, to check
> that no third-party illustrator rights apply, and to ask (a) how you would like the IIS cited on each page and (b) whether a
> bulk export or species list exists so we can avoid fetching a few hundred pages one by one.
>
> I would be glad to share the pages before they go live; a mock-up of the design is at [link].
>
> With thanks,
> Ben Best
> calcofi.io · on behalf of CalCOFI

**2 · NOAA Fisheries — the species-directory illustrations.** To: [NOAA Fisheries Office of Communications, or the West Coast
Region communications contact — Ben to fill in]. Subject: *Permission to show NOAA Fisheries' species illustrations on
calcofi.io species pages.*

> Hello,
>
> I build and maintain calcofi.io, the integrated database and website of the CalCOFI programme (Scripps Institution of
> Oceanography, NOAA SWFSC and CDFW). Each species observed in the 77-year CalCOFI time series has a page
> (calcofi.io/species/), and we are adding a picture to each.
>
> The NOAA Fisheries species directory carries a fine, consistent illustration per managed species, credited "NOAA
> Fisheries/Jack Hornady" — for example on https://www.fisheries.noaa.gov/species/pacific-sardine. We would like to show
> those illustrations for the roughly two dozen CalCOFI species NOAA manages (Pacific sardine, northern anchovy, Pacific hake,
> jack mackerel, market squid, the rockfishes and others), with that credit and a link to each species profile.
>
> Could you tell me whether these illustrations are NOAA works in the public domain, or whether the illustrator retains
> rights? If the latter, would NOAA be able to grant, or put us in touch to request, permission for non-commercial educational
> display on calcofi.io?
>
> I am happy to share the pages before they go live.
>
> With thanks,
> Ben Best
> calcofi.io · on behalf of CalCOFI

**3 · SWFSC — CalCOFI Atlas 33.** To: [SWFSC Fisheries Resources Division, Ichthyoplankton Ecology; the CalCOFI Committee —
Ben to fill in]. Subject: *Using the larval fish drawings of CalCOFI Atlas 33 on calcofi.io species pages.*

> Hello,
>
> As you know, calcofi.io now has a page for every taxon observed in the CalCOFI time series (calcofi.io/species/). We are
> giving each page a picture, and for the fishes we want the picture to be the life stages CalCOFI actually samples.
>
> Where NOAA AFSC's Ichthyoplankton Information System has a developmental plate (from Matarese et al. 1989) we will use it.
> For the California Current species it lacks, the definitive source is CalCOFI Atlas 33, *The Early Stages of Fishes in the
> California Current Region* (Moser, ed., 1996). We would like to extract the per-species developmental figures from the
> Atlas PDF — or, better, from high-resolution originals if SWFSC holds them — and display them with the credit "Moser (ed.)
> 1996, CalCOFI Atlas 33" naming the illustrator where the plate does, with a link to the Atlas.
>
> Before we do: who holds the rights to the Atlas figures (CalCOFI, the illustrators, Allen Press)? Is there any objection to
> this use under the Atlas data-use agreement? Do figure files exist beyond the scanned PDF? And would the ichthyoplankton
> group like to review the pages before they go live?
>
> A mock-up of the design is at [link].
>
> With thanks,
> Ben

## Appendix C — the probe, by source (2026-09-11; 12 taxa: the ten of the cast, *Pseudo-nitzschia*, *Homo sapiens*)

| Source | Keyed by | Hits | Notes |
|---|---|---|---|
| PhyloPic `/resolve/marinespecies.org/taxname/{id}` | WoRMS id | 4 / 12 | sardine → Clupeoidei image of *S. melanostictus* (CC0); dolphin → Delphininae (CC BY-SA 3.0); *Chaetoceros* (CC0); *Sebastes* → *S. melanops* (CC BY 3.0) |
| PhyloPic `/nodes?filter_name=` + lineage walk | name | 12 / 12 | anchovy, krill, hake, *Pseudo-nitzschia* have their own (CC0 / PDM); squid → *Doryteuthis* (1 up), shearwater → *Ardenna* (1 up), lanternfish → Myctophidae (2 up) |
| Wikidata SPARQL, P850 | WoRMS id | 12 / 12 | P18 on 11; enwiki on 12; P3151 iNat on 12; P3444 eBird on the shearwater (`sooshe`); P938 FishBase on the fishes |
| Wikipedia REST `page/summary` | sitelink | 12 / 12 | the sardine's sitelink resolves to the genus article |
| Commons `extmetadata` | P18 file | 11 / 12 | licences: PD ×5, CC BY 4.0 ×2, CC BY-SA ×3, CC BY 2.0 ×1; the sardine category: 26 files, 8 PD |
| iNaturalist `/taxa/{id}` | name → id | 12 / 12 | default photo licences: BY-SA, BY-NC-SA ×3, BY-NC ×2, BY-NC-ND, CC0, `null` ×4 |
| GBIF `occurrence/search?mediaType=StillImage` | usage key | 12 / 12 | 38–4,061 images each; `license=` filters the dataset, not the media |
| WoRMS `AphiaAttributesByAphiaID` | AphiaID | 7 / 12 with body size | sardine 39.5 cm max / 20 common; anchovy 24.8; hake 91; lanternfish 13; dolphin 235 (adult) |
| FishBase / SeaLifeBase (rfishbase) | name | 9 / 9 lengths; 5 fishes with egg/larval lengths | krill 2.2 cm TL, squid 19.2 cm ML, dolphin 260 TL; refs 265, 6879, 31442, 36715 |
| NOAA AFSC IIS `LHDataIll.php?GSID=` | Genus!species | 4 / 4 fishes | 550 × 733 GIF plates; contact on the page; "please cite this website" |
| eBird / Macaulay | P3444 | link only | media owned by contributors; API is data only |
| NOAA Fisheries species page | slug | 1 checked | "Credit: NOAA Fisheries/Jack Hornady"; photos "Credit: iStock" |
| CalCOFI Atlas 33 | — | PDF | https://calcofi.org/downloads/publications/atlases/CalCOFI_Atlas_33.pdf, data-use agreement |
