# WS-A1 checkpoint — 2026-09-03 (stopped for laptop offline)

Branch `ws-a1` (in this worktree). Merged `5bb45ca` (ff-only) so briefs/agents/RELEASES.md are
present. **No `ingest_*.qmd` or `questions.csv` edits made yet** — this session was 100% research
(WebFetch/curl). Nothing to lose by resuming; just start writing edits from the findings below.

## Done — researched, ready to write (with evidence)

1. **calcofi_phytoplankton** (`ingest_calcofi_phytoplankton.qmd`): citation_main =
   `"CalCOFI - Scripps Institution of Oceanography, California Current Ecosystem LTER, and E.
   Venrick. 2023. Temporal and spatial changes of the abundance and species composition of
   phytoplankton in the California Current from samples collected aboard CalCOFI cruises from
   summer 1996 through 2022. ver 4. Environmental Data Initiative.
   https://doi.org/10.6073/pasta/60edabfbfd85c623fce05822befaa071"` (source: EDI cite service
   `knb-lter-cce.254.4?style=ESIP`, checked 2026-09-03). `doi: 10.6073/pasta/60edabfbfd85c623fce05822befaa071`.
   **license: CC0-1.0** — NOT CC-BY-4.0 as the brief guessed; verified from the actual EML
   `<intellectualRights>` (fetched via
   `https://cn.dataone.org/cn/v2/object/https%3A%2F%2Fpasta.lternet.edu%2Fpackage%2Fmetadata%2Feml%2Fknb-lter-cce%2F254%2F4`,
   since `pasta.lternet.edu` and `portal.edirepository.org` both 403/Cloudflare-Turnstile-block
   curl+WebFetch directly — DataONE mirrors the same EML without the bot wall, use this route for
   every EDI EML fetch): `"This data package is released to the public domain under Creative
   Commons CC0 1.0 No Rights Reserved..."`. license_url:
   `https://creativecommons.org/publicdomain/zero/1.0/`.

2. **calcofi_phyllosoma** (`ingest_calcofi_phyllosoma.qmd`): citation_main =
   `"CalCOFI - Scripps Institution of Oceanography and T. Koslow. 2017. Data pertaining to lobster
   phyllosoma, Panulirus interruptus, collection methods, locations, identification and staging
   (1951-2008, months of July and August) ver 4. Environmental Data Initiative.
   https://doi.org/10.6073/pasta/9e38121ebb26f1b59b7b39b2eff844fa"` (EDI cite service
   `knb-lter-cce.188.4?style=ESIP`, checked 2026-09-03). `doi: 10.6073/pasta/9e38121ebb26f1b59b7b39b2eff844fa`.
   **license: custom** — EML `<intellectualRights>` (same DataONE route, `188/4`) is bespoke
   non-CC text: "intended for scholarly use... Use or reproduction... for any commercial purpose is
   prohibited without prior written permission..." license_url:
   `https://portal.edirepository.org/nis/metadataviewer?packageid=knb-lter-cce.188.4` (where a human
   reads the rights statement; the raw EML endpoint 403s for bots).

3. **cce-lter_euphausiids** (`ingest_cce-lter_euphausiids.qmd`): newest EDI revision for
   `identifier=313` is **rev 1** (confirmed: DataONE object exists at `.../313/1`, 404s at `/2`,`/3`,`/4`).
   citation_main = `"Ohman, M.D. 2022. California Current Ecosystem Euphausiid data, Brinton and
   Townsend Euphausiid Database (BTEDB) ver 1. Environmental Data Initiative.
   https://doi.org/10.6073/pasta/4a92a0044bcd1523a4f994ece874a57d"` (EDI cite service
   `knb-lter-cce.313.1?style=ESIP`). `doi: 10.6073/pasta/4a92a0044bcd1523a4f994ece874a57d`.
   **license: custom** — EML rights text (DataONE route, `313/1`) is bespoke: "ethical obligation to
   cite... Reprints... shall be deposited in the Pelagic Invertebrate Collection..." license_url:
   `https://portal.edirepository.org/nis/metadataviewer?packageid=knb-lter-cce.313.1`.
   **acknowledgement** (pull from the same EML rights block, it IS the required citation string):
   `"Data originate from the Brinton and Townsend Euphausiid Database of the Pelagic Invertebrate
   Collection, Scripps Institution of Oceanography. Supported in recent years by NSF grants to
   M.D. Ohman and the CCE-LTER site."` — this notebook currently has NO `citation_others` field to
   migrate from; just add `acknowledgement` fresh.

4. **cce-lter_zoodb** (`ingest_cce-lter_zoodb.qmd`): fetched `https://oceaninformatics.ucsd.edu/zoodb/`
   directly (curl works fine, no bot wall — this is a UCSD site, not EDI). Its "Data Use Policy" /
   "Data Acknowledgement Policy" panel gives EXACTLY the existing `citation_others` text —
   `"Plankton sample analysis supported by NSF grants to M.D. Ohman and the CCE-LTER site, and by
   the SIO Pelagic Invertebrate Collection."` — confirming brief's instruction: **move this to
   `acknowledgement` verbatim, remove `citation_others`** (it's not an additional citation, it's
   credit prose). No formal author/year/title citation is stated anywhere on the portal.
   **license: custom** (policy text: "intended for scholarly use... Use or reproduction of any
   materials herein for any commercial purpose is prohibited without prior written permission from
   Dr. Mark D. Ohman."), license_url: `https://oceaninformatics.ucsd.edu/zoodb/` (the Data Use
   Policy panel on that page, toggled by JS — no separate anchor URL exists). **citation_main stays
   empty; file a `proposed` questions.csv row** to Mark Ohman / Linsey Sala (pi_names already lists
   both) asking them to confirm a formal citation — proposed_answer draft: `"Ohman, M.D. (SIO
   Pelagic Invertebrate Collection). ZooDB Holoplankton Community Database. Scripps Institution of
   Oceanography."` (mark clearly as our proposal, not sourced).

5. **cce-lter_zooscan** (`ingest_cce-lter_zooscan.qmd`): same pattern, fetched
   `https://oceaninformatics.ucsd.edu/zooscandb/` directly (curl works). Its policy text gives
   EXACTLY the existing `citation_others` — `"Plankton sample analysis supported by NSF grants to
   M.D. Ohman and the CCE-LTER site."` → move to `acknowledgement`, remove `citation_others`.
   **license: custom** (same non-commercial-without-permission clause), license_url:
   `https://oceaninformatics.ucsd.edu/zooscandb/`. **citation_main stays empty; file a `proposed`
   row** to Mark Ohman / Marina Frants (pi_names already lists both).

6. **cce-lter_picoplankton-bacteria** (`ingest_cce-lter_picoplankton-bacteria.qmd`): citation_main
   already populated (has value, per brief table) — leave as is unless found wrong (not re-verified
   this session). Checked DataZoo dataset page
   `https://oceaninformatics.ucsd.edu/datazoo/catalogs/ccelter/datasets/159` directly (curl 200,
   12KB, plain HTML, no bot wall) — it shows only a generic site copyright line ("Ocean Informatics
   - Scripps Institution of Oceanography, UCSD © 2026"), NO explicit data-use/license terms
   anywhere on that page (unlike zoodb/zooscan which have a dedicated policy panel). **Conclusion:
   no stated license found → do NOT set license; file a `proposed` questions.csv row to Michael
   Landry** (pi_names already has him) asking for licensing terms, per the brief's "else proposed
   (Landry)" fallback. (Not yet fully certain — could check the CCE LTER methods-manual page
   `http://cce.lternet.edu/data/methods-manual/augmented-cruises/picoplankton-bacteria-abundance-biomass`
   linked from that page for a sitewide policy before concluding; did not get to it.)

## Not started (no research done yet this session)

7. **farallon_bird-mammal** — need ERDDAP `.das` fetch:
   `https://oceanview.pfeg.noaa.gov/erddap/tabledap/CAC_FI_SBAS_obs.das` for `creator_name`
   (expect Sarah Ann Thompson), `institution`, `title`, `license` (expect it points at a
   data-sharing-agreement PDF → `license: custom` + `license_url` = that PDF URL). File `proposed`
   citation row to Sydeman/Thompson — questions.csv already has a Q03 asking attribution per the
   brief; check it and reuse/extend rather than duplicating.

8. **swfsc_cufes** — ERDDAP `.das`:
   `https://coastwatch.pfeg.noaa.gov/erddap/tabledap/erdCalCOFIcufes.das` for title/institution;
   license text ("may be used and redistributed for free…") → `license: custom` + `license_url` =
   the `.das` URL itself. File `proposed` citation row (NOAA SWFSC, Ed Weber / Noelle Bowlin —
   pi_names already Noelle Bowlin).

9. **sio_pic-zooplankton** — no portal (confirmed by existing YAML comment). File `proposed` row
   to Linsey Sala (pi_names already has her) for citation + license. `link_data_source` stays
   empty (CLAUDE.md rule, already respected in current YAML — don't touch).

10. **swfsc_ichthyo** — citation_main already has value but no year/URL:
    `"NOAA Fisheries SWFSC. CalCOFI Ichthyoplankton Database."` — append year + the existing
    `link_calcofi_org` URL (`https://calcofi.org/data/marine-ecosystem-data/fish-eggs-larvae/`) so
    `check_dataset_citation()`'s `no_locator`/`no_year` findings clear. Need to determine a year —
    check calcofi.org page or NOAA SWFSC ERDDAP for a stated database version year (not yet
    checked). `license: US-PD` (proposed — file `proposed` questions.csv row, Q1 per umbrella).
    `pi_names: Ed Weber` — also a `proposed`/fact row per brief ("Q1 row").

11. **calcofi_bottle, calcofi_ctd-cast, calcofi_mets** — citation_main exists (calcofi.org strings,
    already has years). calcofi.org states no license anywhere — confirmed by memory/plan text, not
    independently re-checked this session. File one `proposed` questions.csv row PER DATASET (3
    total) proposing `license: CC-BY-4.0`, addressed to Rasmus (Swalethorp, presumably — verify PI
    name spelling from an existing dataset, e.g. euphausiids/pic-zooplankton pi_names). Also file
    `pi_names` proposed rows: Rasmus for bottle/mets, **Ben G[oericke]** for ctd-cast (per umbrella
    §Attribution "Ben G for CTD" and the P_qual-open item — get full name "Ralf Goericke" is a
    different person mentioned for the O2 spike; "Ben G" is likely a CTD PI — do NOT guess full name
    without a source; check ctd-cast's questions.csv / calcofi.org CTD page for a stated PI, or
    leave the full name uncertain in the proposed_answer and ask the provider to confirm the surname
    in the question row).

12. **calcofi_dic** — trivial: change `license: CC BY 4.0` → `license: CC-BY-4.0` (normalize only,
    already has doi `10.25921/3w9f-jd72` in the citation string per current YAML — brief says add a
    `doi:` key too, bare form: `doi: 10.25921/3w9f-jd72`).

13. **sio_mesopelagic-fish** — normalize `license: "CC BY 4.0"` → `CC-BY-4.0`. Check
    `https://library.ucsd.edu/dc/object/bb9217084g` for a DOI to add as `doi:` (not yet fetched this
    session). The 2013 paper link (`https://doi.org/10.1016/j.pocean.2013.05.013`) stays in
    `link_others`/becomes a `citation_others` list entry (not touched otherwise).

14. **cdfw_dungeness-crab** — normalize `license: CC BY 4.0` → `CC-BY-4.0` ONLY. WS-C (a separate
    workstream) owns everything else in this notebook — do not touch other fields.

## Also not started

- Writing the actual `Edit` calls to all 16 `ingest_*.qmd` files (none done yet).
- Filing the `questions.csv` rows (need to first read each dataset's existing
  `metadata/{provider}/{dataset}/questions.csv` to find the next free `Qnn` label and to check for
  an existing attribution question to extend rather than duplicate — e.g. farallon's Q03 mentioned
  in the brief).
- Reading `read_questions()` in calcofi4db (or CLAUDE.md's summary) to confirm exact CSV columns/
  vocabulary before writing new rows (`id, label, dataset_key?, related_table, status, priority,
  who, context, proposed_answer, ...` — confirm exact column set from an existing questions.csv
  file, e.g. `metadata/calcofi/bottle/questions.csv`, before writing).
- Running `Rscript scripts/build_workflows_index.R`.
- `RELEASES.md` — add own `## ` heading under `# Unreleased` (per `.claude/agents/ws-sonnet-high.md`
  rule: "your own `##` heading" — brief text says "under A0's heading" but agent rules override;
  A0 likely hasn't merged yet anyway since waves run concurrently).
- Committing on `ws-a1`.
- `questions_email.qmd` render for hand-back.

## Open questions / things to verify on resume

- Confirm exact SPDX-style normalization target is `CC-BY-4.0` (hyphens, no spaces) — matches
  umbrella's registry list `CC-BY-4.0, CC0-1.0, CC-BY-NC-4.0, CC-BY-SA-4.0, US-PD, custom, unknown`.
- `metadata/license.csv` does NOT exist yet (WS-A0 creates it in parallel) — per task instructions,
  do not create it, just use the ids as bare strings in `license:`.
- Need to check whether `calcofi4db::check_dataset_citation()` exists yet in the installed package
  (A0 hasn't merged into this branch) — likely NOT callable; hand-back should note it wasn't run
  and why (A0 dependency), per brief step 3's own conditional ("once A0 is merged").
- Picoplankton license: didn't confirm absence of terms is final — one more page
  (`cce.lternet.edu/data/methods-manual/...`) was flagged but not checked.
- CTD-cast PI "Ben G": need the real surname from a source before writing `pi_names`, not memory.
- swfsc_ichthyo: need a defensible year for the citation string before writing it.

## Immediate next step on resume

Start writing `Edit` calls for items 1–6 above (fully researched, ready), then do the ERDDAP `.das`
fetches for farallon (7) and cufes (8), then knock out the easy normalizations (12, 13, 14), then
tackle the `proposed` question rows (9, 10, 11) which need `questions.csv` schema confirmation
first. Save `build_workflows_index.R` + `RELEASES.md` + commit for last.
