# Email drafts (2026-09-03, revised after Ben's decisions) — drafts only, Ben sends; numbers verified against the repo and the rendered notebooks

## 1 · Re: Attribution to integrated data — to Erin (cc Betty, Rasmus, Mark)

Hi Erin,

Agreed, and good timing: attribution is going into the next database release rather than being bolted
onto the app afterwards, so every consumer gets it the same way. Where your five land:

1. **Source beside the variable** — the Explorer's selection rail gets a "Sources" line under the
   dataset pills: provider · dataset · license, with the citation one click away. Where a number pools
   several datasets (same life stage and denominator), every one of them is listed.
2. **A citation with every row** — every download already carries `dataset_key` on each row plus a
   `CITATION.md` with one formal citation per dataset in the selection. What changes is upstream: the
   release's dataset table gains a checked citation, an SPDX license, a DOI where the source has one,
   an acknowledgement line and a "source accessed" date for all 16 datasets (8 have no citation and 13
   no license today), and the build fails if any of that is missing or disagrees with what EDI / ERDDAP
   / NCEI publish for the same dataset.
3. **"Cite this data"** — a button in the app, and `cc_cite()` in both calcofi4r and calcofi4py: hand it a
   query result or a list of datasets and it returns the individual citations plus one for the
   integrated release (text, BibTeX or CSL).
4. **A Data Sources & Attribution page** — in the app (from the header) and as a page on
   calcofi.io/docs, generated from the release so it cannot drift.
5. Figures exported from the app carry the dataset list in their footer, and the welcome screen's button
   becomes "I will cite the datasets I use".

Two things you'll want to know: the integrated database will get its own DOI per release, minted by
Zenodo from a tagged GitHub release of the workflows repository, with the citation naming the three
principal partners — "CalCOFI (2026). CalCOFI Integrated Database, release v2026.09.xx [Data set].
Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife.
https://doi.org/10.5281/zenodo.…". And for reaching PIs: rather than publish personal emails in a
public table, the attribution page gets one CalCOFI front door plus a "Register a product" form in the
app (the same pipeline as the feedback button, landing as public GitHub issues), so PIs can see what was
made from their data. If you'd rather that form live in a Google Form you own, we point at it instead.

Cheers, Ben

## 2 · Re: CalCOFI DMP work update — to Ed (cc the thread)

*(Draft 2, refined 2026-09-03 with the WS-B spike + memo numbers, measured on v2026.08.25; 296
words by `wc -w` from "Hi Ed" to "Ben". Ben sends.)*

Hi Ed,

Agreed, and more is already true than the Task 12 text suggests:

- Every SWFSC station, tow and net is already keyed by the UUID your export ships, and `cruise`
  carries CruiseId. The next release adds `source_uuid` (typed UUID) on `sample`, and `station_uuid`:
  casts matched to your station occupation (by occupation order, or a unique occupation within
  24 h): 78% of 35,644 bottle and 80% of 19,242 CTD casts; the rest are pre-1951 or lack stations in
  your export.
- Compound keys: we hit your failure mode in August (keys derived from each cast's month split
  month-straddling cruises). Keys now come from the cruise table by your date spans, and the next
  release fails when a key's ship or dates disagree with its cruise row. It found one
  malformed key (Bold Horizon 2019-07: `shiplookup` lacks BH's NODC) and 152 cruises our
  bottle/CTD/METS sources designate that your export lacks (mostly 1949–1950, 2016–2026). Could you
  export the full cruise table (CruiseId, ship, month, dates) independent of stations, so every
  cruise gets your UUID?
- Task 12 is about names (variables, units, station notation), not keys; I'll say so.

The ichthyo questions, in a shared sheet: [link]. Top six:

1. Egg stages 12–15 (790 records, 5 species): beyond Moser & Ahlstrom's 1–11: a scheme, or errors?
   Excluded for now.
2. Missing net effort (volume, haul factor, percent sorted): expected, and how to standardize?
3. Tow maximum depth: which field, and wire-out or true depth?
4. Zero vs unsorted: 6,907 of 61,104 tows have no taxon row; any "taxa sorted" flag? Proposed: ≥1
   row ⇒ zeros for the rest, none ⇒ excluded.
5. A species_id → WoRMS AphiaID table?
6. Duplicate net+taxon+stage keys: replicates or duplicates? And 4.8% of observations off-grid:
   real, or coordinate errors?

Take care, Ben

## 3 · Re: Input on app … — to Rasmus (cc Erin, Ben G, Betty, Mark)

Hi Rasmus,

Thanks — that settles most of it. What we're doing with each:

- (a) R_* columns stay unflagged, and we'll now record in the registry that they are interpolated to
  standard depths (pre-QC) and must not feed further interpolation — neither the transect tool nor the
  Explorer sections use them (they interpolate CTD profiles), and a release check will keep it that
  way. One thing for Ben G, since it follows from your answer: we checked casts where every T_degC is
  flagged 8 (suspect) or 9 (missing) yet R_Temp values still exist — **zero casts** in v2026.08.25 meet
  that description (every cast with any bad-temperature bottle also has at least one good one), so this
  particular gap does not currently manifest in the released database; the check now exists if a future
  release needs re-checking. Still open from my list: whether P_qual is the pressure/depth code or the
  phosphate one.
- (b)/(c) Rathburn casts stay excluded; `orig/` and `uncorrected/` are treated as superseded copies and
  excluded; the `separate_runs/` folder inside a FinalQC archive is kept since those casts exist nowhere
  else (20-1104SH 031–036).
- (d) Codes 1/2 as sensor selection, 8/9 as exclusion — confirmed and documented.
- (e) Agreed: samples deeper than GEBCO stay a report, not a flag. To make "large discrepancy" a rule
  rather than a judgment, I'd propose we only raise a question when a cast or tow goes more than 500 m,
  or 25 %, below the deepest neighbouring GEBCO cell — does that sound right to you?
- (f) Counts, from the bottle database vs the SWFSC cruise table: **14 cruises (829 casts) between 1953
  and 1989** where the bottle's YYYYMM designation differs from the cruise the casts fall inside by date
  span. Five are David Starr Jordan cruises (1975-05, 1975-07, 1975-11, 1981-07 and the 1984-03 one I
  mentioned; 535 casts), one is New Horizon 1989-07, the rest are 1950s–60s SIO ships. Summer/fall cases
  exist: 1967-06 (158 casts), 1975-07, 1981-07, 1989-07 and 1975-11. Our rule is that the SWFSC table
  wins for every dataset so the join means one thing — which matches "follow the NOAA designation" for
  the Jordan cruises. For the nine SIO-ship cases, should the bottle designation win instead? (The
  bottle's own designation is kept on its cast table either way.) I'll send the 14 as a table.

| Bottle designation (YYYY-MM) | Resolved `cruise_key` | Ship | casts |
|---|---|---|---|
| 1984-02 | 1984-03-31JD | David Starr Jordan | 310 |
| 1967-07 | 1967-06-31EB | Ellen B. Scripps | 158 |
| 1975-10 | 1975-11-31JD | David Starr Jordan | 125 |
| 1981-08 | 1981-07-31JD | David Starr Jordan | 71 |
| 1962-04 | 1962-03-31HO | Horizon | 56 |
| 1982-08 | 1982-03-90PN | Poseydon | 25 |
| 1975-06 | 1975-05-31JD | David Starr Jordan | 20 |
| 1989-08 | 1989-07-32NM | New Horizon | 12 |
| 1953-07 | 1953-06-31ES | E. W. Scripps | 11 |
| 1962-04 | 1962-03-31BD | Black Douglas | 11 |
| 1953-05 | 1953-04-31ES | E. W. Scripps | 10 |
| 1960-02 | 1960-01-31HO | Horizon | 10 |
| 1975-06 | 1975-07-31JD | David Starr Jordan | 9 |
| 1959-06 | 1959-05-31OR | Orca | 1 |

14 rows, 829 casts total — reproduced from `_output/ingest_calcofi_bottle.html`'s rendered
"Casts whose resolved cruise month differs from the source Cruise designation" widget (684 rows as
rendered pre-fix), filtered client-side to the rows where `cruise` and `cruise_key` disagree as
integers rather than as the DOUBLE-vs-VARCHAR text the notebook's query used to compare — the same
670 rows the notebook's own comparison bug was dropping in are excluded here too, so this table and
the corrected notebook query agree. Ship names joined from the release `ship` table
(`calcofi4r::cc_get_db("v2026.08.25")`) on `ship_nodc`.

Cheers, Ben

## 4 · Re: CalCOFI Dungeness Crab Megalopae Data Deposit — to Betty (cc Erin)

Hi Betty,

Two things on the integrated-database side while the Library review runs:

- I'm revising the ingest so the dataset is the *examined* samples only: the 310 subsamples from the
  2008–2014 series plus the 216 archived samples from the sorting log that were actually searched
  (1984–2009), which carry a "none found" zero. The 1,795 jars that were never examined drop out of the
  integrated database (they remain what they are in your sorting-log deposit — an inventory). The
  temporal coverage therefore reads 1984–2014 rather than 1949–2014.
- Until the DOI is minted I'll point the dataset at the Library catalog as a placeholder and file the
  DOI as an open question; when it lands, the citation and link switch to it. Could you (1) let me know
  the moment the object/DOI exists, and (2) drop the two zips into the Drive folder
  `cdfw/dungeness-crab/deposit/` (the rdl-share link expires 26 Sept) so I can reconcile the ingest's
  corrections with your README — e.g. I currently null the +138° longitude where you sign-corrected it,
  and I'd rather match the citable copy.

Thanks, Ben
