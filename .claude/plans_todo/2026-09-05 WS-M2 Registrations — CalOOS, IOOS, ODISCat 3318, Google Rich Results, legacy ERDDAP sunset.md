# WS-M2 · Registrations — CalOOS, IOOS, ODISCat 3318, Google Rich Results, legacy ERDDAP ids sunset

**Agent:** Sonnet · high (drafts, checks, forms filled to the point of submission); **Ben executes** each
submission. **Wave 3**, `workflows` + `erddap` worktrees. **Needs:** P1 (pages live), M1 (sitemap live).
**Plan:** `.claude/plans/2026-09-05 CalCOFI.io as a dataset catalog — one record per dataset with every endpoint, the front door re-cut around Datasets, and the portal registrations.md` § D-5 (1, 4, 4b), D-10, Decisions 7, 17; Open question 3.

## Do

1. **ISO version check**: fetch one record from `erddap.calcofi.io/erddap/metadata/iso19115/xml/` and confirm
   the root element (`mdb:MD_Metadata` = 19115-3); ask IOOS (catalog registry contact / the
   `ioos/catalog` repo issues) whether the harvester accepts 19115-3; if not, prepare the FGDC WAF
   alternative. Record the answer in the plan's § Measured.
2. **CalOOS**: Erin initiated the registration with **Iwen Su** (CalOOS) before erddap.calcofi.io existed; the four
   modules point at CoastWatch's `erdCalCOFI*`. Draft **one message to Iwen for Erin to send** asking three
   things: (a) harvest erddap.calcofi.io's datasets directly (the Axiom portal reads an ERDDAP dataset by URL) —
   list the dataset ids, titles and page URLs per module; (b) the handoff — CoastWatch's datasets stay NOAA's
   and remain listed, the calcofi.io ones join the same modules as the integrated versions; (c) confirm the
   modules propagate to data.ioos.us through CalOOS's catalog, or whether a CalCOFI provider record in the IOOS
   Harvest Registry is still wanted. A `registrations[].caloos` row per dataset once live.
3. **IOOS Harvest Registry**: the account request (CalCOFI as provider, or via CalOOS — per Ben's answer),
   the WAF URL, the org record; draft ready to send.
4. **ODISCat 3318**: the edit re-pointing the sitemap to `https://calcofi.io/datasets/sitemap.xml`; verify
   the ODIS dashboard shows calcofi.io pages within a week.
5. **Google**: run the Rich Results test on three dataset pages; fix anything P1 missed (hand back, do not
   restyle); request indexing of the sitemap in Search Console (Ben's account).
5b. **The role address** (Decision 23): prepare the two MX records + the SPF TXT for an MX-based forwarder
   (ImprovMX free tier) in Google Cloud DNS for `data@calcofi.io` → Erin, Ben, Betty; Ben applies them; verify
   delivery both ways. In parallel draft the one-paragraph request (or the self-service steps) for a
   `calcofi-data@ucsd.edu` Google Group for Erin.
6. **Legacy ERDDAP ids** (`calcofi_casts`, `calcofi_ctd_thin`, `calcofi_ctd_measurement`, `calcofi_dic_old`,
   `calcofi_euphausiids`, `calcofi_phytoplankton_old`, `calcofi_zooplankton`): `distribution.csv` rows with
   `superseded_by` and a sunset date; a note in each legacy dataset's ERDDAP `summary` pointing at its
   successor (`erddap/content/datasets.xml` or the generated config).

## Gates

Each submission is a text Ben can paste; the ISO answer is recorded; three pages pass Rich Results.

## Do not

Submit anything under Ben's name; change ERDDAP config beyond the summary notes.

## Hand back

The four drafts, the ISO finding, the Rich Results screenshots, one *Measured* line.
