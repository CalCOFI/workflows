# Provider question sheets: review and reconcile (2026-10-01)

Read-only toward Google (Drive and Gmail were only read). Nothing under `~/_big/calcofi`, nothing installed, local working tree and registries untouched. Registry state is `origin/main` (fetched 2026-10-01, head `30591bd`).

## How I read it

- **calcofi sheet** (`1uW9GLogdD2K6NiQGS_xJiIPFUPUvifWesrLlK5UUK7g`): all 8 dataset tabs read in full via xlsx export (README, calcofi_bottle, ctd-cast, dic, hydro-master, mets, phyllosoma, phytoplankton; `metadata` and `holdings` tabs not reviewed). Comment threads read through Drive (`includeComments`) and cross-checked against the 9 Gmail notification threads. Last modified 2026-09-28 23:36Z (Rasmus). No provider edit to any cell other than comments; one exception (ctd-cast Q12 `proposed_answer`, below).
- **SWFSC sheet** (`1kQM6aw3...`, modified 2026-09-25 23:16Z) and **CDFW sheet** (`1cOEo_yl...`, modified 2026-09-23 17:16Z): both tabs read in full, compared by hand to `questions.csv`. No anchored comments on either.
- **SIO, CCE-LTER, Farallon, SCCOOS sheets**: Drive `modifiedTime` is 2026-09-05 (the sync push time) and no comment notification exists in Gmail, so no provider activity since 09-01. I did not diff their cell contents (the xlsx exports for SIO/Farallon/SCCOOS came back inline and CCE-LTER was not diffed); treat as unreviewed at cell level.
- **Gmail**: `after:2026/08/15` comment notifications on the calcofi sheet (9 threads, all from comments-noreply). Also read the email threads that carry answers to registry questions outside the sheets (Ed Weber 09-25, Ben Gire 09-23, Rasmus 09-23/24, Christy Juhasz 09-14..09-30), because several registry questions were answered there and not recorded.
- **Sync direction** (`scripts/sync_questions_sheets.R`): CSV is the record for question text; the sheet owns only `answer`, `status`, `answered_date`, `who`. `pull` overwrites those four columns for every id in the sheet (a blank sheet cell overwrites a filled registry cell), and auto-flips `open` + answer present to `answered`. `push` does `sheet_write()` of the whole tab from the CSV.

## Two sync hazards found (time-sensitive)

1. **Do not run `pull --execute` as is.** The calcofi sheet is stale against the registry on one row: `calcofi_ctd-cast_21` (Q21) is `answered` + answer text + 2026-09-11 in the registry but `proposed` + blank in the sheet. A pull would regress it and wipe the answer. Fix Q21 in the sheet side first (re-push) or hand-edit after the pull.
2. **Do not run `push --execute` before the provider answers are recorded.** Ed Weber's answers (SWFSC, in the `answer` column) and Christy Juhasz's answers (CDFW, typed in the locked `proposed_answer` column) exist only in the sheets. A push rewrites each tab from the CSV and would erase them. Record them in `questions.csv` first (updates below), then push. The CDFW answers sit in a column `pull` never reads, so they will not be recovered by a pull either.
3. The sheets are missing rows added since 2026-09-04/05 (calcofi: bottle Q13/Q14, ctd-cast Q33-Q39, dic Q08/Q09, mets Q32, phytoplankton Q09; SWFSC: cufes Q06-Q08, ichthyo Q07-Q16; CDFW: Q08-Q15). Ed said he "filled in the spreadsheet for all cufes and ich questions" but he can only have seen the rows that were there (cufes Q01-Q05, ichthyo Q02-Q06). A re-push (after the pull) is needed so providers see the new questions.

## Summary table

Dates are UTC (Drive/Gmail). "Class" per the brief; a row can carry two (primary first).

| # | Sheet | Tab | Label | Author | Date | Class | Gist |
|---|---|---|---|---|---|---|---|
| 1 | calcofi | bottle | Q01 (C2) | Rasmus (+reply) | 09-18 17:04 | ANSWERED-NOT-RECORDED, NEEDS-CODE | Quality codes >9 are impossible (dragged-down spreadsheet cells); turn all >9 into a blank code = treat as good, as a general rule; "only appended on 2104" |
| 2 | calcofi | bottle | Q02 (C3) | Rasmus | 09-18 17:18 | ANSWERED-NOT-RECORDED, NEEDS-BEN-REPLY | Code meanings 0/1/2/3/4/7 given; 5 and 6 "depend on column" |
| 3 | calcofi | bottle | Q03 (D4) | Rasmus to Annie | 09-28 23:31 | FYI (waiting on Annie) | Annie asked to check 2014 nutrient data for low-seawater / detection-limit issues |
| 4 | calcofi | bottle | Q04 (D5) | Rasmus (+reply to Annie) | 09-28 23:36 | ANSWERED-NOT-RECORDED, NEEDS-BEN-REPLY | Flagging protocol changed; do not backfill code 4; zero is a valid value, do not exclude; Annie asked to concur |
| 5 | calcofi | ctd-cast | Q10 (C7) | Rasmus | 09-17 17:51 | ANSWERED-NOT-RECORDED (partial) | Yes: serve both the bottle analytical value and the bottle-corrected sensor value for CTD profile data |
| 6 | calcofi | ctd-cast | Q10 (D7) | Rasmus | 09-17 17:45 | NEEDS-BEN-REPLY | "Need a meeting; I do not completely understand the question" (reference/tolerance half) |
| 7 | calcofi | ctd-cast | Q12 (C8,D8,E8) | Rasmus | 09-17 17:53 | ANSWERED-NOT-RECORDED, NEEDS-CODE | pH should have been converted; unrealistic values excluded; new QC will look; FYI tags to Ben G and Kelsey |
| 8 | calcofi | ctd-cast | Q12 (G8 cell text) | unknown (not a comment) | by 09-28 | DISAGREES-WITH-US (mildly), FYI | Text typed into locked `proposed_answer`: pH is in pH units in `cruise_station_correction.csv`, NOT a voltage |
| 9 | calcofi | ctd-cast | Q14 (G9) | Rasmus | 09-17 23:57 | ANSWERED-NOT-RECORDED, NEEDS-CODE | Confirms 3 data_stage labels; OK for calcofi.io/.org without bottle data, avoid EDI |
| 10 | calcofi | ctd-cast | Q15 (G10) | Rasmus | 09-18 16:18 | ANSWERED-NOT-RECORDED, NEEDS-BEN-REPLY, NEEDS-CODE | YES to (a) stable format and (b) publishable; (c) span undocumented; asks why span beats min-max |
| 11 | calcofi | ctd-cast | Q15 (C10,D10) | Rasmus to Kelsey, Ben G | 09-18 16:29 | FYI | Final release must include DBcoeff and xmlcoeff in metadata folder |
| 12 | calcofi | ctd-cast | Q20 (G11) | Rasmus | 09-18 16:25 | NEEDS-BEN-REPLY | Jim Wilkinson question; Ben to write him, CC Rasmus, Kelsey, Ben G |
| 13 | calcofi | ctd-cast | Q21 (G12) | Rasmus | 09-18 16:33 | FYI (already answered in registry) | "Confirmed" |
| 14 | calcofi | ctd-cast | Q21 (D12) | Rasmus; Kelsey reply | 09-18 18:51 | ANSWERED-NOT-RECORDED (Q37), NEEDS-BEN-REPLY | Catch malfunctioning sensor in preliminary release; Kelsey: failed 2607 temp sensor replaced, not yet removed, waiting for "Ben's Kraken program" |
| 15 | calcofi | ctd-cast | Q23 (D13) | Rasmus to Kelsey | 09-18 16:39 | FYI | Out-of-range par/transmissometer/spar look like calibration; research in new database |
| 16 | calcofi | ctd-cast | Q24 (D14) | Rasmus | 09-18 16:46 | NEEDS-BEN-REPLY | Sounds like station-correction problems on some casts; concentrated in specific cruises? |
| 17 | SWFSC | cufes | Q01, Q05 | Ed Weber (inferred) | 09-25 | ANSWERED-NOT-RECORDED, NEEDS-CODE | Raw in the db; eggs/m3 = count / (minutes x mean pump speed); gives the missing volume |
| 18 | SWFSC | cufes | Q02 | Ed | 09-25 | ANSWERED-NOT-RECORDED | Wind speed in knots; pump speed m3/min |
| 19 | SWFSC | cufes | Q03 | Ed | 09-25 | ANSWERED-NOT-RECORDED | Bounds fine |
| 20 | SWFSC | cufes | Q04 | Ed | 09-25 | ANSWERED-NOT-RECORDED, NEEDS-CODE | Early no-position records will be removed at source; start-only kept; CUFES not tied to stations |
| 21 | SWFSC | ichthyo | Q02 | Ed | 09-25 | ANSWERED-NOT-RECORDED, NEEDS-CODE | Stages 12-15 used for Dover/Rex sole, no reference; screen out |
| 22 | SWFSC | ichthyo | Q03 | Ed | 09-25 | ANSWERED-NOT-RECORDED, NEEDS-CODE | Net effort cannot be missing |
| 23 | SWFSC | ichthyo | Q04 | Ed | 09-25 | ANSWERED-NOT-RECORDED, NEEDS-CODE | Fixed in FishMeasured/LarvaeMeasured; aggregate |
| 24 | SWFSC | ichthyo | Q05 | Ed | 09-25 | ANSWERED-NOT-RECORDED, NEEDS-CODE | AphiaID and TSN in species table; new SpeciesWormsLookup/SpeciesItisLookup |
| 25 | SWFSC | ichthyo | Q06 | Ed | 09-25 | ANSWERED-NOT-RECORDED | Bounds fine |
| 26 | SWFSC | ichthyo | Q07 (email) | Ed | 09-25 | ANSWERED-NOT-RECORDED | Off-grid tows (ETP etc.) are real, kept |
| 27 | SWFSC | ichthyo | Q08 (email) | Ed | 09-25 | ANSWERED-NOT-RECORDED, NEEDS-CODE | Net.csv NetDepth (m) is true depth, not wire-out |
| 28 | SWFSC | ichthyo | Q09 (email) | Ed | 09-25 | DISAGREES-WITH-US, NEEDS-CODE | No sorted flag; tows with no row are true zeros except 198202JD and 198212JD (moved to staging); our proposal excluded no-row tows |
| 29 | SWFSC | ichthyo | Q13, Q14 (email) | Ed | 09-25 | ANSWERED-NOT-RECORDED | 788 stays in Bill's taxonomy, aggregate by AphiaID; BH ICES code now in ShipLookup, use ICES |
| 30 | CDFW | dungeness-crab | Q03, Q04, Q05, Q06, Q07 | Christy Juhasz (in locked col G) | 09-08 | ANSWERED-NOT-RECORDED (tentative) | Q06 yes; Q03 likely more than one jar; Q04 likely Pacific; Q05/Q07 unsure |
| 31 | CDFW | (email) | Q14 | Christy | 09-14, 09-30 | NEEDS-CODE, FYI | CNRA open-data copy exists; external link to UCSD Library page approved |
| 32 | calcofi (email) | ctd-cast | Q36 | Ben Gire | 09-23 | ANSWERED-NOT-RECORDED | *Q columns use 0/1/2/8/9; column names and types will stay stable |
| 33 | calcofi (email) | ctd-derived | Q01-Q05, Q08 | Rasmus | 09-23, 09-24 | DISAGREES-WITH-US (Q01, Q02), ANSWERED-NOT-RECORDED (Q05), partial (Q03, Q04, Q08) | MLD is 0.02 not 0.03; chl max 3 m running mean; down cast |
| 34 | calcofi (email) | ctd-cast | Q14 (b) | Rasmus | 09-09 | DISAGREES-WITH-US | Hold off uncorrected sensor series on CTD-only cruises |

Counts by class (a row counted under its primary class; items 33/34 are email-sourced): ANSWERED-NOT-RECORDED 19 rows (about 33 distinct questions), NEEDS-BEN-REPLY 7 rows (Q02, Q04, Q10 D7, Q15, Q20, Q21 D12, Q24), DISAGREES-WITH-US 4 rows (items 8, 28, 33, 34), FYI 5 rows (3, 11, 13, 15, 31), NEEDS-CODE/DATA as a secondary tag on about 14 rows.

## Ammonium qual=4 thread (the one you asked about)

- **bottle Q04** (`calcofi_bottle_04`, cell D5): Rasmus, 2026-09-28 23:36Z, "assigned you an action item" (Gmail 1a0ea6580f0654bc, 23:41Z). Anchor text is the Q04 context ("The qual=4 flag is essentially unused before 2013 ...").
- Verbatim, Rasmus: "@ben@ecoquants.com it indicates there was a change in flagging protocol around then. Some of these measurements would have read 0 when the sample was analyzed, while others would have been above 0 but below the detection limit so gotten auto zeroed since they would be indistinguishable from 0. So it would be inappropriate to give them all a code 4. Also, a 0 is a valid data point so we should not exclude them."
- Reply in the same thread, same minute: "@aleffinger@ucsd.edu Annie do you concur?"
- **bottle Q03** (cell D4), 2026-09-28 23:31Z, Rasmus to Annie: "@aleffinger@ucsd.edu Annie can you check if there is anything in the 2014 nutrient data that suggests there was issues with the low seawater measurements and below detection limit?"
- **Latest**: nothing since. The sheet's last modification is 23:36:45Z on 09-28, there is no Gmail from Annie (or any notification from this sheet after 09-28 23:41Z), and both threads are still OPEN. Annie has not replied or concurred as of this morning (2026-10-01). Ben has not replied either; the action item is still assigned to him.
- Meaning for us: his answer to Q04 is "no, do not backfill code 4". That agrees with our current stance (project memory: qual=4 unreliable, test `value == 0`) but adds a rule we should check against the code: **zeros are valid values and must not be excluded**. Our context text recommended `measurement_value == 0` as the portable censoring test; that remains a way to *identify* censored values, not a reason to drop them. Check that no ammonium climatology/anomaly/summary step drops or NULLs zeros (the `build_climatology()` path, the bottle ammonium bounds and any `measurement_summary` that treats 0 as missing).
- Registry update proposed below (Q04 answered by Rasmus, Annie concurrence pending; Q03 stays open, add a note).

## Registry updates (exact), calcofi dataset `questions.csv` on main

Dates are the Pacific date of the comment. `who` is the registry's `who` column.

**metadata/calcofi/bottle/questions.csv**

- `calcofi_bottle_01` (Q01): status `answered`; answered_date `2026-09-18`; who `Rasmus Swalethorp`; answer: `Rasmus Swalethorp (SIO), 2026-09-18, sheet comment: "these codes are not listed in the CTD profile data and a code above 9 is impossible. It seems that codes were dragged down in a spreadsheet somewhere accidentally on a number of stations. We should catch this during reprocessing at some point but for now turn everything >9 into a blank code meaning that we will consider this data good for now (this can be a general rule)." Reply: "BTW this only appended on 2104". So the 256-271 cluster is not a bitmask: it is an entry error. Caveat from us: a blank code is not evidence the value is good; cruise 2021-05-3322 salinity (calcofi_bottle_13) is physically invalid regardless of its code and stays governed by that question and the bound.` Open item: verify "only on 2104" against our extract (our `qual_code_observed.csv` has 248 of 279 column/code pairs >9, which looks wider than one cruise; query `bottle_measurement` for `measurement_qual > 9` by `cruise_key`).
- `calcofi_bottle_02` (Q02): do not mark answered yet. Status `proposed`; who `Rasmus Swalethorp`; proposed_answer: `Per Rasmus Swalethorp 2026-09-18: 0 = good data; 1 and 2 = sensor 1 or sensor 2 was used; 3 = observed data (PRODO: dark-bottle cruise average); 4 = value zeroed because below detection; 5 and 6 depend on the column; 7 = interpolated to a standard depth (not an actual observation for bottle-derived data). Codes above 9: see Q01.` Close as answered once 5 and 6 are given per column.
- `calcofi_bottle_03` (Q03): stays `open`; append to context: `Rasmus asked Annie Leffinger on 2026-09-28 to check the 2014 nutrient runs for low-seawater / detection-limit issues; awaiting her reply.`
- `calcofi_bottle_04` (Q04): status `answered`; answered_date `2026-09-28`; who `Rasmus Swalethorp`; answer: `Rasmus Swalethorp (SIO), 2026-09-28, sheet comment: "it indicates there was a change in flagging protocol around then. Some of these measurements would have read 0 when the sample was analyzed, while others would have been above 0 but below the detection limit so gotten auto zeroed since they would be indistinguishable from 0. So it would be inappropriate to give them all a code 4. Also, a 0 is a valid data point so we should not exclude them." Decision: do not backfill the flag; zeros are kept as valid values (measurement_value == 0 means at or below detection, true zero or auto-zeroed). Annie Leffinger asked to concur (2026-09-28); not yet answered.` If you prefer to hold until Annie concurs, use status `proposed` with the same text as proposed_answer.
- `calcofi_bottle_12` (Q12, P_qual): unchanged; Rasmus's Q02 list does not settle it. Add to Q02's follow-up (ask which columns carry 3/5/7).

**metadata/calcofi/ctd-cast/questions.csv**

- `calcofi_ctd-cast_10` (Q10): status `proposed` (not answered: half the question remains); proposed_answer prepend: `Rasmus Swalethorp 2026-09-17: "if the question is if we should both serve up the analytical measurement from the bottle as well as the bottle corrected sensor reading then the answer is yes for the CTD profile data." Still open: whether the btl_* values are the reference to calibrate against and what offset tolerances are acceptable (Rasmus 2026-09-17: "I think we will need to discuss this in a meeting. I do not completely understand the question.").`
- `calcofi_ctd-cast_12` (Q12): status `answered`; answered_date `2026-09-17`; who `Rasmus Swalethorp`; answer: `Rasmus Swalethorp 2026-09-17: "it should have been converted, but sounds like it was not or that the calibration had drifted substantially or the sensor was malfunctioning on those occasions. These unrealistic values should be excluded. We will look for this as part of the new QC process in the new database." Ben Gire and Kelsey Vogel tagged FYI. Action: declare a ph bound and drop what it excludes; the cruise-level clusters (2020-01-33UD, 2019-11-32OC, 2011-10-32NM) go to the CTD flag ledger. Separately an unattributed note typed in the sheet's proposed_answer cell says the ph column in the cruise_station_correction.csv files is in pH units, not a voltage.`
- `calcofi_ctd-cast_14` (Q14): status `answered`; answered_date `2026-09-17`; who `Rasmus Swalethorp`; answer: `Rasmus Swalethorp 2026-09-17: "I confirm the 3 data stage labeling. Regarding publication, I think it is fine for us to use the preliminary without bottle data on calcofi.io and .org, but I would avoid putting that on EDI." (a) confirmed. (b), publishing the uncorrected sensor series: not confirmed; Rasmus asked (2026-09-09, email) to hold off showing uncorrected salinity/oxygen on CTD-only cruises, and the consumers tier rule hides them.` NEEDS-CODE: the EDI package must exclude `data_stage = 'preliminary_without_bottle'`.
- `calcofi_ctd-cast_15` (Q15): status `answered`; answered_date `2026-09-18`; who `Rasmus Swalethorp`; answer: `Rasmus Swalethorp 2026-09-18: "YES to a and b. For the preliminary data we currently do not have a DBoeff associated csv, but this is something we will setup for the final data and we can try and keep the format as is. For C this is something that requires more research as I do not think anyone currently knows how these files were generated. It will be another element of our coming final data processing journey of discovery. I am not sure I understand why the span files is better that grabbing min-max from the processed data file? Does it not match the CTDBTL csv files?" Also to Ben Gire: "in the final data release we need to include at a minimum DBcoeff and xmlcoeff data releases (in the metadata folder)." So: DBcoeff format stable and coefficients publishable; build the DBcoeff ingest (libs builder called from ingest_calcofi_ctd-cast.qmd, per-cast scalars into sample_measurement, SDs into measurement_prec); span: compare to CTDBTL min/max before deciding; xmlcoeff: ships in the final release's metadata folder (publish as files; ingest still not needed).`
- `calcofi_ctd-cast_20` (Q20): stays `open`; who `Jim Wilkinson (via Rasmus Swalethorp)`; add to context: `Rasmus 2026-09-18: "I think this is a Jim Wilkinson question (jrwilkinson@gmail.com). I assume that the archived version came from his archive? It may be best if you write and explain this but please CC me, Kelsey and Ben G."`
- `calcofi_ctd-cast_21` (Q21): no change (registry already `answered` 2026-09-11). Rasmus 2026-09-18 on the proposed-answer cell: "Confirmed". Append to the answer: `Confirmed again by Rasmus Swalethorp in the sheet, 2026-09-18.` Fix the sheet (hazard 1).
- `calcofi_ctd-cast_23` (Q23): stays `proposed`; add to context: `Rasmus 2026-09-18 (to Kelsey Vogel): "this seems like situations where the sensor calibration could have been off ... We may need to research this more in the new database."` No bound confirmed.
- `calcofi_ctd-cast_24` (Q24): stays `proposed`; add: `Rasmus 2026-09-18: "this sounds like it is a problem with our station corrections on some casts, that to a much smaller extent affects the cruise corrections. ... Do these tend to concentrate in specific cruises (if so which ones?) or do they spread over many cruises?"` plus a reply (below).
- `calcofi_ctd-cast_36` (Q36): status `answered`; answered_date `2026-09-23`; who `Benjamin Gire`; answer: `Benjamin Gire 2026-09-23 (email, "CTD profile work updates?"): "Yes, the *Q columns will use the same code list as the sensor flags (0,1,2,8,9). Yes, we will not change the column names or value types of data that we enter for any columns in the 1 meter binned text '.csv' files. And we will reach out to you to discuss if we feel a change might be necessary."`
- `calcofi_ctd-cast_37` (Q37, 2607SH casts 1-6): evidence from the Q21 comment thread, Kelsey Vogel 2026-09-18: "we had a failed tempearture sensor on this cruise which we replaced. We haven't physically removed this from the preliminary data yet since we are waiting for Ben's Kraken program to be ready. We tested removing bad sensor data on it yesterday while going through 2601." Confirms the failed sensor; keep `proposed` until she confirms the flag (Temp2Q = 9) and cast range.

**metadata/swfsc/cufes/questions.csv** (answers typed by SWFSC in the sheet; Ed's email of 2026-09-25 says he filled in cufes and ichthyo; who is the registry `who` of the row, so author inferred as Ed Weber; status was left `open` by the provider so a pull would auto-flip)
- `swfsc_cufes_01` (Q01): `answered`, 2026-09-25, who `Ed Weber (SWFSC)`; answer: `"I don't know where your data are coming from but in the raw db they are not. The standardization is usually: eggs / m^3 = (count / minutes sampled) / mean pump speed, i.e., eggs / m^3 = (count / (stop time - start time) / ((start pump speed + stop pump speed) / 2)"`.
- `swfsc_cufes_02` (Q02): `answered`, same date/who; `"Wind speed is knots. Pump speed is m^3 / min."`
- `swfsc_cufes_03` (Q03): `answered`; `"Yes, this is fine."`
- `swfsc_cufes_04` (Q04): `answered`; `"There are some records with no position from the early-development years, which I am going to remove because I don't see how anyone could use them. I am retaining records with a start position but no stop position. CUFES samples are otherwise not constrained to have any relation with CalCOFI stations."`
- `swfsc_cufes_05` (Q05): `answered`; `"See Q01, above."`
- Q06, Q07, Q08 (citation, license, creator): not in the sheet, unanswered.

**metadata/swfsc/ichthyo/questions.csv**
- `swfsc_ichthyo_02` (Q02): `answered`, 2026-09-25, `Ed Weber (SWFSC)`; `"Stages 12-15 have been used for Dover Sole and sometimes Rex Sole but I do not have a reference. You or I could screen them out if wanted."` (Ben replied 10-01 that they will be filtered out.)
- `swfsc_ichthyo_03` (Q03): `answered`; `"They cannot be missing."`
- `swfsc_ichthyo_04` (Q04): `answered`; `"This structure is now revised and corrected in the FishMeasured table but you might have to aggregate, for example, if there are fish with multiple lengths but the same stage."` Email adds LarvaeMeasured now carries length and/or stage.
- `swfsc_ichthyo_05` (Q05): `answered`; `"Yes. As we have discussed a few times, our db is necessarily in Bill taxonomy but we link to Worms and ITIS. The species table contains the Worms AphiaID and ITIS TSN. I have now also included SpeciesItisLookup, SpeciesWormsLookup tables, which contain their taxon names. I haven't updated these in a year or so but they should be pretty good. Otherwise, you could link directly."`
- `swfsc_ichthyo_06` (Q06): `answered`; `"Yes, this is fine."`
- From the 2026-09-25 email only (rows Ed could not see in the sheet): `swfsc_ichthyo_07` (grid): `"there are some cruises in the ETP and other places. We retain these in the db because they used standard calcofi methods and there is no reason to get rid of them."`; `_08` (depth): `"Net.csv now has a NetDepth field (m), which is what you are looking for. You are right that wire-out is not the same thing at all for oblique tows."`; `_09` (zero vs unsorted): `"No. This was a nightmare. We now have a separate stg (i.e., staging) schema in our db for data that are in process ... You are right about 198202 JD and 198212 JD ... They have been moved back to the staging schema. The others are true zeros and have valid positive zooplankton volumes."`; `_13`: `"our db is necessarily in Bill taxonomy ... Just aggregate by AphiaID if that's what you want. Do not question the taxonomic knowledge of the almighty Bill."`; `_14`: `"we agreed to use ICES ship codes, not NODC ... the updated ShipLookup table now has a code for all."` `_15` (cruise table) and `_16` (coordinate sentinels) were not answered.

**metadata/cdfw/dungeness-crab/questions.csv** (Christy Juhasz's answers sit in the locked `proposed_answer` cell of the sheet; she dated them 2026-09-08 and her 09-08 email says "I was able to review all questions but was not able to answer all questions"; status was left `open`)
- `cdfw_dungeness-crab_03` (Q03): `proposed`, 2026-09-08, `C. Juhasz (CDFW)`; `"Unknown, but based on 2015 dataset it likely could represent more than one archived jar for same sample station."`
- `_04` (Q04): `proposed`; `"Time zone is likely Pacific."`
- `_05` (Q05, internal): `open`; `"Unsure of methods when aliquot was taken to appropriately sub-sample from entire volume of archived net catch."` Decide internally.
- `_06` (Q06): `answered`; `"I would say yes looks like all surveys are contained in 'Compiled Cruises'."` (tentative wording; fine to close)
- `_07` (Q07): `proposed`/internal; `"Unsure as goal of project was to identify Metacarcinus magster megalopae based on larger size. I could see the parsing of other crab larvae being useful, but unsure also about the identification."` Recommend keep free text.

## NEEDS-CODE / DATA

| Where | Change |
|---|---|
| `ingest_calcofi_bottle.qmd` | Read `measurement_qual > 9` as blank (NULL). Do NOT use that to rescue cruise 2021-05-3322 salinity (Q13). Record bottle code meanings 0/1/2/3/4/7 in `metadata/measurement_qual.csv` (5 and 6 pending). Decide whether code 7 ("interpolated to standard depth, not an observation") should fail `cc_qual_ok_sql()` for observed-depth products. Ammonium: keep zeros, no flag backfill; add the "zero = at or below detection" statement to metadata |
| `ingest_calcofi_ctd-cast.qmd` | Declare a `ph` bound (we used a generous 6..9 in Q12) with Rasmus's answer cited, and let `drop_out_of_bounds()` remove the rest; push cluster cruises to the flag ledger. DBcoeff builder (libs, called from the notebook): now approved; fill `measurement_prec` from the SDs. Ensure the EDI package excludes `preliminary_without_bottle` |
| `ingest_calcofi_ctd-cast.qmd` (new format) | Rule from Ben Gire: `*Q` columns use 0/1/2/8/9; column names and types stable. Matches issue 105 |
| `ingest_swfsc_cufes.qmd` | Derive `volume_sampled` = minutes x mean(start pump, stop pump) [m3/min] where times and speeds exist, so CUFES eggs get an effort and join the per-1000-m3 density instead of `raw_count_no_effort`. Register wind speed in knots, pump speed in m3/min. Rows with no position at all will be dropped at source by Ed; start-only rows keep a position. grid_key NULL is expected, not an error. Ed says CUFES is now in his CSV repo linked by CruiseId; ask where, since it may beat the ERDDAP feed |
| `ingest_swfsc_ichthyo.qmd` | Re-ingest from Ed's new Drive folder (`13A9yDJC...`) next week (Ben already said so on 10-01): NetDepth into `depth_max_m`; LarvaeMeasured replaces the size and stage tables; aggregate by AphiaID via SpeciesWormsLookup; drop egg stages 12-15; assert effort never NULL; zero-fill rule changes: tows with no taxon row are true zeros except cruises 198202JD and 198212JD (drop); carry the ICES ship code beside NODC. Update `swfsc_ichthyo_09` proposed answer accordingly (our version excluded no-row tows from the denominator) |
| `ingest_cdfw_dungeness-crab.qmd` | `datetime_start_utc`: treat times as Pacific local (America/Los_Angeles, DST-aware) rather than the current as-given; note mets Q02 used fixed PST -8, so decide one convention. Add the CNRA open-data copy (https://data.cnra.ca.gov/dataset/sorting-effort-in-2012-and-2015-for-dungeness-crab-megalopae-in-calcofi-plankton-samples) to `distribution.csv`; when the UCSD Library page exists, link it (Christy confirmed 09-30 external links are allowed) |
| `ingest_calcofi_ctd-derived` | MLD headline per Rasmus is +0.02 kg/m3 below a 10 m reference (not 0.03); chlorophyll maximum on a 3 m running mean (not 5 m median); integrated chl: sum 1 m bins in the top 200 m or to cast depth, trapezoid for bottle; down cast; exclude SCCOOS stations from geostrophic flow; seasonal climatology with winter/spring/summer/fall; spice outliers: do not flag on spice, exclude unrealistic values in the pipeline and QC salinity in PostgreSQL |

## DISAGREES-WITH-US

1. **ichthyo Q09** (Ed, email 09-25): "No [sorted flag] ... The others are true zeros." Our proposal excluded no-row tows from the denominator and counted 198202JD and 198212JD as zeros. Ed says the opposite on both counts. Ben accepted Ed's version on 10-01; the registry row still carries our proposal.
2. **ctd-derived Q01** (Rasmus, email 09-23): headline MLD is "sigma-theta 0.02 kg/m3 greater than a reference depth of 10 m" (Ralph's definition, "historically what people have been using"), not our 0.03.
3. **ctd-derived Q02** (Rasmus, email 09-24): chl max from a 3 m running mean, depth of the highest value; our proposal was a 5 m running median.
4. **ctd-cast Q14 (b)** (Rasmus, email 09-09): hold off on uncorrected sensor salinity/oxygen for CTD-only cruises; our proposal published them labelled uncorrected. Already resolved in the product.
5. **ctd-cast Q12** (unattributed text in the sheet's proposed_answer cell): says ph is in pH units, not voltage, contradicting our voltage hypothesis, though consistent with Rasmus's reading (bad values, exclude).
6. Soft conflict: Rasmus's "blank code = good" rule for bottle codes >9 clashes with bottle Q13 (2021-05-3322 salinities of 24-27 PSU with S_qual 254-344). Flag outranks bound only holds when the flag means something; here a blank code must not rehabilitate those values.

## Drafted replies (Ben's voice; edit before sending; none sent)

**1. bottle Q04 and Q03, ammonium (reply in the sheet thread or email to Rasmus, cc Annie)**

> Thanks, Rasmus. That settles the question for me: a zero in the bottle database means at or below the detection limit, either a true zero or an auto-zeroed value, so I won't backfill code 4, and I'll keep the zeros as valid values. In the metadata I'll say that zero means "at or below detection" and that the flag is only used from about 2013. Two things would help me describe it accurately: roughly which year the flagging protocol changed, and whether the detection limit stayed the same across the period. Annie, no rush: question 3 (why only 3.2% of 2014 values are zero when 2013 and 2015 are 41% and 53%) still needs your read on the 2014 runs.

**2. bottle Q02, codes (to Rasmus)**

> Thanks, this is what I needed. I'll record 0 = good, 1/2 = sensor 1 or 2 used, 3 = observed (PRODO: dark-bottle cruise average), 4 = zeroed below detection, 7 = interpolated to a standard depth. For 5 and 6 you said it depends on the column. I'll send a short table of the columns where each code appears (from our Bottle_Q counts); a one-line meaning per column from you or Annie would close this. I'm also treating 7 as "not an observation" for anything that should use observed depths only, such as the climatologies. Does that match how you use it?

**3. bottle Q01, codes above 9 (to Rasmus, cc Ben G, Kelsey)**

> Understood: codes above 9 aren't real, so I'll read them as blank. One flag back: in our extract they show up on more than the one cruise you mention, so I'll send the list by cruise to check. And one case where I'll keep acting on the value rather than the code: cruise 2021-05-3322 reads 24-27 PSU salinity in 918 bottles, which is physically wrong whatever the code says.

**4. ctd-cast Q10 (to Rasmus; offer a meeting)**

> Sorry, I asked that badly. Three simple pieces: (1) For CTD profile data we serve both the bottle analytical value and the bottle-corrected sensor value. Your answer says yes, which is what the release does now, thanks. (2) Are the bottle values (Winkler oxygen, Portasal salinity, thermometer temperature) the reference we should compare the sensor against? (3) We flag a pair when it differs by more than 0.5 degC, 0.05 PSS-78 or 0.3 mL/L; those thresholds are ours, are they about right? Happy to go through it at the next data meeting.

**5. ctd-cast Q12, ph (to Rasmus, cc Ben G, Kelsey)**

> Thanks. I'll drop pH outside 6-9 (a generous guard, not a QC call) and send you, Ben G and Kelsey the cruises where whole casts sit in a narrow negative band (2020-01-33UD at about -2.7, 2019-11-32OC, 2011-10-32NM) for the new QC process. Does 6-9 look right to you, or would you rather 6.5-9? Someone also typed into our proposed-answer cell that pH is in pH units in the cruise_station_correction.csv files; if that was you, Ben G or Kelsey, thank you, it helps.

**6. ctd-cast Q14 (to Rasmus)**

> Thanks for confirming the three data_stage labels. I'll keep the preliminary-without-bottle data on calcofi.io and calcofi.org and leave it out of the EDI package. On showing uncorrected salinity and oxygen for CTD-only cruises: per your 9/9 note I've removed them from the published data rather than badge them.

**7. ctd-cast Q15 (to Rasmus, cc Kelsey, Ben G)**

> Great, thanks for both yeses. I'll build the DBcoeff ingest first and keep your format as is. For span, you're right to ask: if the span files equal the min and max of the CTDBTL data they add nothing. I'll compare them on five cruises and tell you; if they match I'll drop span from the plan. For xmlcoeff, understood: it ships in the metadata folder of the final release.

**8. ctd-cast Q20, to Jim Wilkinson (cc Rasmus, Kelsey, Ben G)**

> Subject: CalCOFI CTD final files: which copy is authoritative for 66 cruises?
>
> Hi Jim, I'm Ben Best, building CalCOFI's integrated database with Rasmus's team. Rasmus suggested I ask you. We read your per-cruise _CTDFinalDB.zip archive for the 45 cruises (1993 to 2002) that calcofi.org has no final for, and it has been very useful. For the 66 cruises where both calcofi.org and your archive have a final, 130 of 140 comparable files are identical, but 8 files on four cruises are not: 1810SR, 1501NH, 1604SH and 1607OS. On 1810SR your copy has 59,726 rows against 29,863 on calcofi.org, same 74 casts and 82 columns, and your timestamps carry seconds where calcofi.org truncates to the minute. Which copy should we treat as authoritative, and do you know why the row counts differ? Right now we use calcofi.org's. Thank you.

**9. ctd-cast Q24 (to Rasmus, cc Ben G, Kelsey)**

> Yes, that is my read: the station-corrected oxygen goes wrong on individual casts, the cruise-corrected much less. Examples: 2301RL (OxAve_StaCorr up to 2.1e9 mL/L), 2404_025 and 1907_050 (about 2.8 times the sensor value), and 13 cruises ship some casts twice with disagreeing corrected oxygen. I'll send a per-cruise table of casts where sta_corr over the sensor value falls outside 0.5-2 so you, Ben G and Kelsey can see whether they cluster. [Run before sending; not run here.]

**10. Kelsey (reply to her comment on Q21)**

> Hi Kelsey, thanks for the 2607 detail. We've provisionally flagged Temp2/Salt2 on casts 1-6 as bad on our side; if you set Temp2Q = 9 on those scans at source I'll retire the override. On waiting for my "Kraken program": [Ben: say what that is and when it is ready]; tell me what you need from me and by when so you are not blocked before the next cruise.

**11. Ed Weber (follow-up to Ben's 10-01 reply)**

> Thanks for filling in the sheet. Four things we still need: (1) CUFES: where is the CUFES CSV in your repo, and does it carry both start and stop time and pump speed per sample? We'll compute volume from them. (2) The full cruise table (CruiseId, ship, designated month, start and end dates), independent of stations: 152 cruises from other sources have no CruiseId. (3) Coordinate sentinels: the ichthyo extent runs 0 to 54 N and 180 to 77 W; any known placeholder values or a flag to filter on? (4) License and citation for CUFES and the ichthyoplankton database; the sheet rows are in the new tab versions. I'll re-push the sheet so you can see them.

**12. Erin/Betty note on CDFW**

> Christy's answers are recorded: all surveys are in "Compiled Cruises", the time zone is probably Pacific, and the repeated rows probably mean several jars per station. I'll treat times as Pacific local. She also confirmed (9/30) that CDFW can link to the UCSD Library page and pointed to the CNRA open-data copy; I'll add that copy to our distributions. When the Library URL exists, please send it so I can add it to the dataset record.

## Time-sensitive

- **Nine open comment threads are assigned to Ben** (Q01, Q02, Q04, Q10 two threads, Q12, Q14, Q15, Q20, Q24) and are still OPEN in the sheet, the oldest since 09-17; with the DMP meeting today the sheet looks unattended to Rasmus. Q04/Q02/Q01/Q10/Q24 need replies, Q12/Q14/Q15/Q20 need replies plus actions.
- **Sync order** (above): record answers in the CSVs, then pull-or-hand-edit, then re-push; never push first, never pull before fixing Q21.
- **Release in progress**: items marked NEEDS-CODE should not go into the running release unless intended; the pH bound, bottle code >9 rule and ichthyo changes belong in the next one. `RELEASES.md` `# Unreleased` needs an entry when they land (core rule).
- **EDI**: the CTD-to-EDI package is "next with Betty and Aaron"; make `preliminary_without_bottle` exclusion a gate before it is built.
- **SWFSC re-ingest next week** (Ben committed 10-01); update the ichthyo rows first so the re-ingest reads settled answers.
- **Kelsey**: waiting on "Ben's Kraken program" for removing bad-sensor data from preliminary files; next cruise leaves soon (Erin 09-21).
- **Jim Wilkinson email**: Rasmus asked to be copied; no deadline, but Q20 is one of the three tied to the CTD-ledger decisions.
- **Unreplied since 09-28**: Annie has not answered Q03/Q04; nudge not needed from Ben, Rasmus tagged her.
