# Email drafts — drafts only, Ben sends; numbers verified against the repo and the rendered notebooks

Draft 1 (Erin, attribution) was SENT 2026-09-03; the follow-up with the Explorer's Sources UI waits for the
release that flips the app onto it. Drafts 2–5 revised 2026-09-04 after the release-round hand-backs.

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

Agreed, and more of it is already true than the Task 12 wording suggests:

- Every SWFSC station, tow and net is already keyed by the UUID your export ships, and `cruise`
  carries your CruiseId. The next release adds `source_uuid` as a typed column on the sample table,
  and `station_uuid`: any cast or tow matched to your station occupation (same occupation order, or a
  unique occupation within 24 h) carries that StationId — about 78 % of 35,644 bottle casts and 80 %
  of 19,242 CTD casts; the rest are pre-1951 or at stations your export has no row for.
- Compound keys: we hit exactly your failure mode in August (keys derived from each cast's month
  split cruises that straddle a month). Keys now come from the cruise table by your date spans, and
  the next release fails the build when a key's ship or dates disagree with its cruise row. Two things
  it turned up: one malformed key (Bold Horizon, July 2019 — `shiplookup` has no NODC for BH, so the
  key minted with an empty ship segment; we patch it to `39C2`), and 152 cruises that the bottle, CTD,
  METS and picoplankton sources designate but your export has no station row for (92 of them
  1949–1950, the rest mostly 2016–2026). Could you export the full cruise table (CruiseId, ship,
  month, dates) independent of stations, so those cruises get your UUID too?
- Task 12 is about the names of things (variables, units, station notation, dataset slugs), not
  primary keys; I'll say so in the status text. Erin, Betty and I talked this through yesterday: the
  conventions document will get an audience-and-purpose section up front and split its fields into
  mandatory (what, when, where), optional and best practice, with UUIDs listed as a best practice for
  any provider who runs a database. We will not require them of providers, most of whom keep
  spreadsheets, but where a provider mints them, as you do, we preserve them as columns, and for
  everything else the integrated database mints and maintains its own identifiers internally. That
  way anyone who finds a problem in a SWFSC record can hand you the station, tow or net UUID and you
  know exactly where it lives.

The open ichthyoplankton questions now live in a shared sheet you can answer in place (edit the
`answer` / `status` cells; everything else is generated):
https://docs.google.com/spreadsheets/d/1kQM6aw3yiT1AZAmFfgCp2Ou9u-UckR69Tien_4Mk1qE/edit
Where we could pre-answer we did, marked "proposed", so you can confirm rather than start from
scratch. The six that matter most:

1. **Egg stages 12–15**: 790 records (2,029 eggs, 5 species) use stages beyond Moser & Ahlstrom's
   1–11. A different scheme, or entry errors? Excluded for now.
2. **Missing net effort** (volume, standard haul factor, percent sorted): expected, and how should
   abundance be standardized when one is absent?
3. **Tow maximum depth**: every tow reaches us with no maximum depth. Which field carries it, and is
   it wire-out or true depth?
4. **Zero vs unsorted**: 6,907 of 61,104 tows have no taxon row; is there a per-tow or per-cruise
   "taxa sorted" flag? Proposed rule: a tow with any row is a zero for the rest, a tow with none is
   out of the denominator.
5. **A species_id → WoRMS AphiaID table?** We match on name today, and it bites: code 788
   *Syngnathus leptorhynchus* carries the AphiaID of *S. californiensis* in the species list.
6. **Duplicate net + taxon + stage keys**: replicate sorts or duplicates? And 4.8 % of observations
   resolve no CalCOFI grid cell: real off-grid positions, or coordinate errors?

Take care, Ben

## 3 · Re: Input on app … — to Rasmus (cc Erin, Ben G, Betty, Mark)

Hi Rasmus,

Thanks, that settles most of it. What we did with each:

- **(a)** R_* stays unflagged, and the registry now records that those series are interpolated to
  standard depths (pre-QC) and must never feed further interpolation; neither the transect tool nor
  the Explorer sections use them (both interpolate CTD profiles), and a release check keeps it so.
  We also checked the case your answer implies: casts where every T_degC is flagged bad yet R_Temp
  values exist. None in the current release. Still open from my list: whether P_qual is the
  pressure/depth code or the phosphate one.
- **(b), (c)** Rathburn casts stay excluded; `orig/` and `uncorrected/` are treated as superseded
  copies and excluded; `separate_runs/` inside a FinalQC archive is kept, since those casts exist
  nowhere else (20-1104SH 031–036).
- **(d)** Codes 1/2 as sensor selection, 8/9 as exclusion: confirmed and documented.
- **(e)** Agreed, samples deeper than GEBCO stay a report. To make "large discrepancy" a rule, we
  would only raise a question when a cast or tow goes more than 500 m, or 25 %, below the deepest
  neighbouring GEBCO cell. Does that sound right?
- **(f)** 14 cruises (829 casts, 1953–1989) where the bottle database's YYYYMM designation differs
  from the cruise the casts fall inside by date span. Five are David Starr Jordan cruises (535
  casts), where your "follow the NOAA designation" is what we do; the summer and fall cases are
  1967-06, 1975-07, 1981-07, 1989-07 and 1975-11. Our rule is that the SWFSC cruise table wins for
  every dataset so the join means one thing, and the bottle's own designation stays on its cast
  table. For the nine SIO-ship cases, should the bottle designation win instead?

| Bottle designation | Resolved cruise | Ship | Casts |
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

Three new ones from this week's work, for you and Ben G:

- **Ammonia or ammonium?** The bottle database labels the QC'd column NH3 ("Micromoles Ammonia")
  while its raw columns say ammonium (NH4+). They are the same measurement, so one label is wrong,
  and it matters now that each type carries a NERC vocabulary id for OBIS and ERDDAP.
- **Seven final CTD casts carry timestamps far outside their cruise**: 9908_067/069/070 (down and
  up) in the 9908NM archive dated 1997, and 1307_021u, off by up to 948 days. The keys are right
  (they come from the archive name); the timestamps look like the corruption we saw before.
- **DIC bottles that share no Niskin with the bottle database** (3,255 of 3,262) reach the release
  with no cruise at all; the NCEI EXPOCODE would resolve them, and that one is for Todd and Aaron.

All of the CalCOFI-curated questions (bottle, CTD, METS, DIC, hydro-master, phyllosoma,
phytoplankton), pre-answered where we could, are in one sheet you can edit in place:
https://docs.google.com/spreadsheets/d/1uW9GLogdD2K6NiQGS_xJiIPFUPUvifWesrLlK5UUK7g/edit

Cheers, Ben

## 4 · Re: CalCOFI Dungeness Crab Megalopae Data Deposit — to Betty (cc Erin)

Hi Betty,

Two things on the integrated-database side while the Library review runs:

- The ingest now publishes the *examined* samples only: the 310 subsamples from the 2008–2014 series
  plus the 216 archived samples from the sorting log that were actually searched (1984–2009), which
  carry a "none found" zero. The 1,795 jars that were never examined are out of the integrated
  database; they remain what they are in your sorting-log deposit, an inventory. The dataset's
  temporal coverage therefore reads 1984–2014 rather than 1949–2014, and it ships that way in the
  next release.
- Until the DOI is minted the dataset points at the Library catalog as a placeholder, with the DOI
  filed as an open question; when it lands, the citation and link switch to it. Could you (1) tell me
  the moment the object or DOI exists, and (2) drop the two zips into the Drive folder
  `cdfw/dungeness-crab/deposit/` before the rdl-share link expires on 26 September, so I can
  reconcile the ingest's corrections with your README? I currently null the +138° longitude where you
  sign-corrected it, and I'd rather match the citable copy.

Thanks, Ben

## 5 · PR #77, Farallon on ERDDAP — to Betty (cc Erin)

Hi Betty,

I pushed four commits onto your `ingest-farallon-erddap` branch (your three keep their authorship;
mine merge main and move the species list onto the generic taxon path we finished this week), so the
PR is ready for your review. What to look at, one change per commit:

1. The `taxon-stage` chunk's `erddap_only` table is the judgment call: nine ERDDAP-only codes are
   staged (seabirds, marine mammals, sea turtles), six excluded (CRAB, FISH, TUNA, VEVE, RAPT, WIWA),
   each with a reason, and the list is asserted complete so a new code on a re-pull stops the render.
2. Your "confirm the extra year" is now measured: 1987–2018 identical row for row, 2019, 2020 and
   2022 new, and **no 2021 observations upstream** (DataZoo had 625 for CAC2021_7), taken as served
   and filed as Q11, high.
3. ERDDAP's `time` being UTC settles Q01; the row is still open and yours to mark answered.
4. The species table keeps your `type` columns and adds `itis_id` / `include_flag` /
   `is_unidentified` from the DataZoo list, which is what keeps every key identical to the last
   release (164 of 164, one documented Mew Gull re-key).
5. Two small fixes: the stale "matched on `date`" comment above `cruise_track`, and the unused `b01()`.
6. No rendered HTML is in the PR; the manifest and metadata diffs are the evidence.

Since the four commits are on your branch, please `git pull` it before editing anything (RStudio's
Git pane works for all of this: pull, stage, commit, push), then edit line by line and push; the PR
updates itself. If you hit the "rejected, fetch first" message, that is the pull-then-resolve dance
we walked through, not a problem with your work.

The Farallon questions, including the ERDDAP gaps, are in a sheet you can edit in place:
https://docs.google.com/spreadsheets/d/1szPLnPuQtaskPpwB1dkX7kGqs4hj6I2g2cE_kGq6ZbU/edit

On the dataset-by-affiliation list you offered Erin: build it from the release rather than the CalOOS
draft. The `dataset` table (or `data/parquet/*/metadata.json` on main) already carries provider,
`dataset_name`, `pi_names`, `citation_main`, `license` and, from the next release, `acknowledgement`
for the funder credit Erin wants elevated (the ZooDB and ZooScan rows carry "supported by NSF grants
to the CCE-LTER site" today; the seabird data should say CCE-LTER too), and `metadata/provider.csv`
maps each provider slug to its display name and full organization (SWFSC now shows as "NOAA SWFSC").
Anything you or Erin add there flows to every app, package and page at the next release, which is why
the source of truth has to stay in the workflows repo rather than in any one app.

Two notes for db-viz-station while you are there: the next release's `dataset` table gains `doi`,
`license_url`, `acknowledgement` and `contact`, so `scripts/build_datasets.sql` should carry them into
`datasets_meta.json`; and Pooh Venrick asked that the phytoplankton entry show one heading,
"Phytoplankton abundances by species", instead of per-parameter sub-headings, since they are all one
table.

Thanks, Ben

## 6 · The datasets still missing a citation or licence — to Erin (cc Betty)

*(The list Erin asked for on 2026-09-03 so she can chase providers; sendable now, independent of the
Explorer's Sources UI, because provider answers take weeks.)*

Hi Erin,

Here is the list you asked for. Every dataset now has a checked entry in the release for citation,
licence, DOI and acknowledgement, and the build fails if one goes missing without a question on
record; these are the gaps that only a provider can close. Each is already a row in that provider's
question sheet, pre-answered where we could ("proposed"), so the ask is to confirm or correct in
place. The sheets are shared with you; the provider link is in each row's `who`.

**No formal citation anywhere we could find (5):**

| dataset | provider | who | what we propose |
|---|---|---|---|
| ZooDB holoplankton | CCE-LTER | Mark Ohman, Linsey Sala | author-year-title citation for the ZooDB export |
| ZooScan PRPOOS | CCE-LTER | Mark Ohman, Marina Frants | same, for the ZooScan export |
| Seabird and marine mammal surveys | Farallon Institute | Bill Sydeman, Sarah Ann Thompson | citation; the ERDDAP entry names only the institution |
| CUFES eggs | NOAA SWFSC | Ed Weber, Noelle Bowlin | citation for the ERDDAP dataset |
| PIC zooplankton net tows | SIO | Linsey Sala | citation and licence; no portal exists |

**No licence stated by the source (6):** the CalCOFI bottle database, CTD cast files and METS
(we propose CC-BY-4.0, to Rasmus); the SWFSC ichthyoplankton database (we propose US government work,
to Ed); picoplankton and bacteria (Mike Landry); PIC zooplankton (as above). Four datasets carry
bespoke terms rather than a Creative Commons licence (CUFES, Farallon's data-sharing agreement, and
EDI's own terms on phyllosoma and euphausiids), which we record as they are.

**No named PI or contact (4):** bottle, CTD, METS (we propose Rasmus; Ben Gire for CTD) and
ichthyoplankton (we propose Ed).

**Affiliation and funder credit.** Your CCE-LTER point from Kathy and Mike is exactly what the new
`acknowledgement` field is for: ZooDB and ZooScan already carry "supported by NSF grants to the
CCE-LTER site", the euphausiid package its EDI credit line, and nothing else has one yet. The seabird
data should say CCE-LTER too; if you can tell me the wording each program wants (CCE-LTER, NOAA,
CDFW), it goes on every download, figure footer and the Sources page verbatim. Betty is building the
dataset-by-affiliation list for you from the release table rather than the CalOOS draft, so the two
stay one thing.

Cheers, Ben
