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

Hi Ed,

Thanks — this is on the radar, and more of it is already true than the naming-conventions text
suggests. Concretely:

- Your UUIDs are in the integrated database now: every SWFSC station, tow and net is keyed by the UUID
  your export ships (`sample_key = swfsc_ichthyo:site:<StationId>` and so on), and the cruise table
  carries your CruiseId as `cruise_uuid`. Two things we'll add in the next release: `source_uuid` as a
  proper UUID column on the sample table (so a join to your database needs no string surgery), and the
  same treatment of station occupations for the other datasets — a bottle or CTD cast matched to the
  SWFSC station occupation gets its StationId as `station_uuid`. I'll send you the match rates before
  we ship that.
- On compound keys: you're right about the failure mode, and we hit exactly it in August — `cruise_key`
  was being derived from each cast's month instead of looked up from the cruise, which split cruises
  that straddle a month boundary. It's now resolved against the cruise table (your date spans), and
  the next release adds a check that fails the build if a key's ship or dates ever disagree with the
  cruise row it points to. We keep the readable `cruise_key` / `sample_key` as the join keys because
  the integrated database is a read-only frozen release — the "business logic" lives in those
  release-time checks rather than in an entry form — but the identifiers of record are yours, carried
  as columns, not re-minted.
- Task 12 is about the *names* of things (variables, units, station notation, dataset slugs), not
  about primary keys; I'll make that explicit in the status text.

While I have you — the questions we've accumulated on the ichthyoplankton export, in priority order.
Each ingest keeps a standard question log (id, question, context, our proposed answer, status), and
I've put the SWFSC ones in a Google Sheet we can both edit: [link]. The most important:

1. **Egg stages 12–15.** 790 egg records (2,029 eggs, 5 species) use stages 12–15, but the Moser &
   Ahlstrom scale we encode runs 1–11. A different scheme, or entry errors? They are excluded for now.
2. **Missing net effort.** Should `volume_sampled`, `standard_haul_factor` or `percent_sorted` ever be
   absent, and how should abundance be standardized when one is? (Manta tows were ~50× low in one app
   before gear-aware handling.)
3. **Tow depth.** Every tow/net in the export reaches us with no maximum depth, so a tow can't be drawn as
   the 0–210 m span it is. Which field carries it (`tow.max_depth`?), and is it wire-out or true depth?
4. **Zero vs unsorted.** The larvae/egg tables are positive-only, so absence of a row is our only zero.
   Two 1982 cruises (1982-02 and 1982-12 on Jordan) look sorted for anchovy only, and 6,907 of 61,104
   tows have no row of any taxon. Is there a per-tow or per-cruise "taxa sorted" indicator? Our
   proposed rule: a tow with ≥ 1 row of any taxon is a zero for the rest; a tow with none is out of the
   denominator.
5. **Species crosswalk.** Do you hold a `species_id` → WoRMS AphiaID table? We match on name today.
6. **Duplicate occurrence keys** (same net + taxon + stage more than once): replicate sorts, or
   duplicates to collapse? And 4.8 % of observations resolve no CalCOFI grid cell — genuine off-grid
   positions, or coordinate errors?

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
