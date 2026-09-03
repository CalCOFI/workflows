# WS-A3 · Explorer attribution — agree-to-cite, Sources line, figure footers, Cite this data, Sources modal, Register a product

**Agent:** Opus 5 · medium. **Wave 2** (start from A0's column spec; degrade when a column is absent —
the app runs on the dev catalog until F). Repo: `CalCOFI/explore`.
**Plan:** umbrella § *WS-A › Explorer*; Erin's five asks and Ben's additions in § *The ask › 1*.
Answers to Q3/Q4 may arrive mid-flight — build the wording as constants.

## Read first

- `src/help.tsx` (Welcome / About / Modal; `seenWelcome`/`markWelcome`; `provName`), `src/App.tsx`
  (`REG.dataset` and `setDatasets` ~l.203–210; pills ~l.423–473; modal state ~l.512–523),
  `src/export.ts` (`Stamp`, `drawFooter`, `plotPng`, `plotSvg`, `csv`), `src/capture.ts`,
  `src/bundle.ts` (`CITATION.md`, `README.md` — keep these as they are; reuse their text builder),
  `src/feedback.tsx` (the Apps Script → public-issue pipeline), `src/tour.ts`, `src/ui.tsx` (pill/menu).
- Memories: *Explorer verify gotchas* (no HMR edits during verify; CDP click sequence; html-to-image),
  *html-to-image loses <img> in <picture>*. The `brand-contract` skill: `?tour=off` must keep every
  modal closed (screenshots), and `?theme=` must still apply.
- The plan `2026-08-29 CalCOFI Explorer UI — …md` for the rail/card vocabulary (SELECT · FILTERS · EXPORT).

## Do

1. **Agreement in the Welcome modal** — the primary button reads the Q4 wording (default: "I will cite
   the datasets I use → Explore"); a second line under it: "Downloads and figures name their datasets;
   *Cite this data* gives you the citations." Stored as `explore_cite_ack` beside `explore_welcome`;
   `?tour=on` re-shows; `?tour=off` never shows. Keep "Take the tour".
2. **Sources line** in the SELECT rail directly under the dataset pills: for each dataset in view
   `provider_short · dataset_name_short · <license chip>`; click/hover → the `citation_main` with a copy
   button. Uses `dataset` rows already loaded (`provName` → prefer the release's `provider` table when
   present, else the map). Erin's (1).
3. **Figure footers**: `Stamp` gains `datasets: string[]`; `drawFooter` and `plotSvg` add a third line
   "Data: <dataset_key, …> · cite: calcofi.io/explore → Cite this data"; `FOOTER_PX` grows accordingly;
   `capture.ts` follows. Check both themes at 1× and 2× (Plotly and the map capture).
4. **Cite this data** in the EXPORT card: copies text (and offers BibTeX) for the datasets in view +
   the release citation (`catalog.citation` when present, else the same wording A2 uses). Erin's (3).
   Every panel CSV keeps/gains a `dataset_key` column (never a `#` comment line — it breaks parsers).
5. **Data Sources & Attribution modal** (`?modal=sources`, header help menu, and linked from About):
   one row per dataset — category icon, name, provider, span, n obs, `citation_main`, license chip with
   `license_url`, DOI link, PIs, `contact` when present, calcofi.org / source links; a footer with the
   release citation and the CalCOFI front door (Q3). Erin's (4). Group phytoplankton's taxa under the
   one dataset (Pooh Venrick's point) — the table is per dataset already; make sure nothing lists
   sub-headings.
6. **Register a product** — a second kind in the feedback dialog ("I used CalCOFI data in …": title,
   link/DOI, datasets in view prefilled) → the same Apps Script → public issue, label `derived-product`.
   Q3 may redirect this to a Google Form; keep the entry point and swap the sink.
7. **Averaging copy (Ben).** The statistics already pool across datasets that share the chosen life
   stage and denominator (`_filters.sql` + `station.sql`/`hex.sql`); the copy says the opposite. Change
   App.tsx:730, help.tsx:70 and tour.ts:37 to "averaged across datasets that share this life stage and
   denominator; never across denominators or life stages" ("stages" → "life stages" everywhere), and
   make the Sources line (item 2) list **every pooled dataset** in view — pooling is exactly why each of
   them must be cited. No behaviour change.
8. `scripts/verify.mjs`: extend with the agreement flow, the footer line, and `?tour=off` showing no
   modal; screenshots both themes; `README.md` section "Attribution".

## Do not

Change `bundle.ts`'s `CITATION.md` shape; change `pages.yml` (`VITE_RELEASE_PREFIX` flips in WS-F);
average or merge anything across datasets; add a network fetch for citations (everything is in
`dataset.parquet` + the catalog).

## Hand back

Commit SHA, verify output, four screenshots (welcome · sources line · footer · sources modal, dark +
light), and the list of columns the UI degrades without.
