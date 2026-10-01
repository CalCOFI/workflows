# Gmail status for CalCOFI.io, 2026-09-22 .. 2026-10-01 (read-only extraction, run 2026-10-01)

Scope: inbox + sent + drafts, ben@ecoquants.com. Searches run: `after:2026/09/21 calcofi`, CTD/Rasmus/eDNA/iron/phyto/marmam/Kuali keywords, from/to ucsd.edu / noaa.gov / wildlife.ca.gov, `in:sent after:2026/09/21`, GitHub notifications, Kuali/Pilar.
Not found: no Kuali / Pilar vendor-security email in this window (search returned nothing; the only trace is a local plan file). No GitHub notification emails in the window (search empty). No eDNA/iron/sonobuoy/Venrick-direct/Library-new emails beyond what is below. Rasmus's 9/29 screenshots are inline images I could not view.

Note: all mail times are UTC. "Thursday" in Ben's own promise to Rasmus = 2026-10-01 (today).

---------------------------------------------------------------------------------------------------

## A. Threads, newest activity first

### 1. Updated quote for SCCOOS - $49,652?  (thread 1a0f49a5deecf2a2)  [FYI / waiting on Erin]
- Erin -> Ben (cc jdclark@ucsd.edu, m4gold@ucsd.edu), 9/30 23:14Z: SCCOOS budget/proposal exact amount is $49,652; asks for an updated quote.
- Ben replied 10/1 10:26Z (sent): new amount is $433.25 more than original Quote 2 ($49,218.75). Originals: Quote 1 $16,406.25 + Quote 2 $49,218.75 = $65,625. Asks Erin: bump Quote 1 down by $433.25 to keep the $65,625 sum, or leave Quote 1 and let the sum become $66,058.25?
- Ben replied: yes. Ball is with Erin. Once she answers, issue revised quote document(s).

### 2. Choosing State of the California Current figures  (thread 1a0e89249473c1f3)  [REPLY NEEDED / meeting to schedule]
- Betty -> Rasmus (cc Ben, Erin), 9/28 15:10Z: building short R + Python tutorials (calcofi4r issue #17), each recreating one State of the California Current report figure; Ben suggested these become the data-paper outline. Four proposed: larval fish abundance by species/year; zooplankton volume+biomass over time; ocean conditions (temperature sections + anomalies); seabirds and marine mammals (Farallon). Asks Rasmus which other figures matter more.
- Rasmus -> Betty (cc Ben, Erin, andrew.thompson@noaa.gov, nvpatin@ucsd.edu), 9/30 17:02Z (UNREAD): "We were just thinking about this as Nastassia was having some challenges pulling down the hydrographic data she needed. Also, Andrew will also have a lot of thoughts on standard plots for the SOCCR. I have included both of them here. Could you try and find a time where we can all meet mid next week?"
- Ben has not replied; Betty is the addressee, but Ben was asked implicitly (cc) and the hydrographic-data-access problem (Nastassia Patin) is Ben's domain. Meeting target: mid-week of Oct 5-9 (note Oct 8 6pm CEST Betty/Ben/Erin meeting exists, see item 14).
- Action: reply-all or let Betty schedule; offer to help Nastassia pull hydrographic data (calcofi4r / ctd_thin / derived dataset).

### 3. Next Two Weeks Tasks  (thread 1a081fa6c2393fa1)  -- RASMUS, HIGHEST PRIORITY  [REPLY NEEDED + ACTION: code/data]
15 messages (9/8 .. 9/29). Window messages:
- 9/22 20:37Z Rasmus -> Ben (cc Betty, Erin): checking when plotter updates land; 2607 stations excluded offshore (and Explorer line 93 near shore); asks for SigThetaTS1/TS2 average "unless one is flagged"; spice and relative geostrophic flow wanted (no anomaly for geostrophic, relative only, he pasted an R/gsw script: haversine station distances, gsw_SA_from_SP, gsw_CT_from_t, gsw_spiciness0, gsw_geo_strf_dyn_height with p_ref = 500, velocity = (dh2-dh1)/(f*dx), positive equatorward, 1 m grid to 500 dbar, averaging surface-10 m ... 490-500 m).
- 9/22 23:31Z Betty: PR ctd-transects#4 sent (temperature-only for CTD-only prelim cruises; station+cruise corrected chl/oxygen; EstNO3 pair; climatology min 3 -> 5 cruises; per-cell tooltip + badge for #cruises); waits for Ben on SigTheta/spice/geostrophic.
- 9/23 16:55Z Rasmus -> Betty: plotter looks good; DO only station-corrected not cruise-corrected (2408SR 93.3-45 odd DO); wants toggle monthly vs seasonal climatology; "I suggest we do not offer up a transect plot if the transect has less than 3 stations on it."
- 9/23 17:15Z Ben (sent) long update: plotter live at calcofi.io/ctd-transects/; 2607 station numbers >= 100 truncated to 3 digits (100/110/120 -> 000/010/020), Kelsey's corrected file 9/14 fixes it (workflows#104); cruise-corrected oxygen to arrive next release (workflows#106); issues filed ctd-transects#5 (averaged sigma-theta), #6 (spice), #7 (geostrophic flow), #8 (monthly vs seasonal toggle), #9 (bottle climatology on observed depths); derived-products dataset (workflows#98) built over 9,630 casts with defaults + 5 questions; code at calcofi4db PR#11, workflows PR#110, PR#107; Explorer layers explore#13 "within your ~2-month window for El Nino".
- 9/24 00:24Z Rasmus (inline answers to Ben's 5 questions):
  * Bottle-based climatology: offer 1949-2013 mean AND 1993-2013 mean; rule "if a datapoint exists in the bottle database use that, and if not pull it from the CTD profile data"; T_degC fallback = avg sensor temp at bottle depth; variables: Salnty, O2ml_l, STheta, ChlorA, NO3uM (1 m binned sensor data since 1993) plus add PO4uM, SiO3uM, NH3uM, NO2uM; label bottle data "Discrete depth bottle data".
  * Spice: undercurrent on line 90 near shore at 100-300 m is expected.
  * MLD: "I suggest we use the CalCOFI legacy definition established by Ralf. +0.02 kg/m3 below 10 m. This, and the derived products below are for the explorer app to generate surface maps, not the transect plotter."
  * Chl-a max: define as Depth of Chl a max (DCM); 3 m running mean ("I was considering 5m but sometimes the layers can be pretty narrow"); DCM = depth of highest value within the running mean.
  * Integrated chl a: sum all 1 m bins in top 200 m or station depth if shallower; bottle data trapezoidal integration.
  * Geostrophic: speeds too high ("most points well below 1"); exclude SCCOOS stations; (did not understand Ben's shelf reference-depth question).
  * Down cast (not up cast). Seasonal climatology: winter/spring/summer/fall.
  * Spice < -3 kg/m3 outliers (153 bins, 22 casts): "We probably won't flag things based on spice... but in your pipeline we should exclude unrealistic values."
- 9/24 21:41Z Rasmus (more derived products; attached MATLAB bottle script + draft R script):
  * Nitracline depth: depth where nitrate equals or is just above 1 uM; 1 m binned simple; bottle by linear interpolation between points above/below; "nice product to visualize on a map in the explorer".
  * Hypoxic boundary depth: same as nitracline with thresholds 2.4 mL/L (mild), 1.4 (hypoxic), 0.5 (severe, core OMZ); take the shallowest boundary depths; explorer candidate.
  * Pycnocline depth: modernize with TEOS-10 / Gibbs; modify for 1 m binned sensor data; explorer candidate.
  * Buoyancy frequency: from same script for 1 m binned CTD, for the CTD transect plotter.
  * Isopycnal tracking (ok to park): toggleable isopycnal overlay (25 to 27 in 0.2 steps) on the plotter; chemistry on isopycnals and depth/anomaly maps in the explorer; old MATLAB script + untested R draft attached.
  * "Happy to jump on a meeting."
- 9/25 16:05Z Ben (sent): started a new release incl. derived hydrographic dataset for MLD and spiciness; "I will need to pick up the rest early next week. Look forward to digging in then. I should update you by Thursday." (= TODAY 10/1)
- 9/25 16:19Z Rasmus: sounds excellent; tackled most urgent of Ben's questions.
- 9/29 16:22Z Rasmus -> Ben (UNREAD, 3 screenshot images): "Just sharing a couple screenshots where the CTD transect plotter does not seem to be showing the data correctly." No Ben reply. (Need to open the thread in Gmail to see the images; unknown which cruise/line.)
- Classification: [REPLY NEEDED] (Thursday update promised today) + [ACTION: code/data] (see checklist C).

### 4. CalCOFI integrated database - questions for CalCOFI (Google Sheet comment)  (thread 1a0ea6580f0654bc)  [DECISION FOR BEN / ACTION: data]
- Rasmus assigned Ben an action item, 9/28 23:41Z (UNREAD). Re qual=4 / ammonium censoring. Verbatim from Rasmus: "@ben it indicates there was a change in flagging protocol around then. Some of these measurements would have read 0 when the sample was analyzed, while others would have been above 0 but below the detection limit so gotten auto zeroed since they would be indistinguishable from 0. So it would be inappropriate to give them all a code 4. Also, a 0 is a valid data point so we should not exclude them." He also asked Annie (aleffinger@ucsd.edu) "do you concur?"
- Ben's own note in the sheet: "qual=4 is essentially unused before 2013 (0-0.9%), exact zeros 40-71% in 2008-2012; portable censoring test is measurement_value == 0, not the flag."
- Implication: do NOT backfill qual=4 on early zeros; zeros stay valid data; do not exclude them. Update the ammonium censoring treatment/question and docs; reply in the sheet thread. Waiting on Annie.

### 5. Phytoplankton data -- Thanks again!  (thread 1a0d97de0b259d88)  [ACTION: code/data, mostly Betty]
- Erin -> Betty (cc Ben, Mark Goldstein m4gold), 9/25 16:54Z (UNREAD). Notes from the 9/25 call with Pooh (Venrick, evenrick@ucsd.edu), who found things to fix in the phytoplankton app:
  * Check station numbers, esp. inshore, have correct line/station (all stations in a line should be in a row).
  * Verify what the number on the right card means when clicking a phytoplankton taxon (regions), e.g. Actinocyclus has 105 for Alley; label what the values are.
  * Do not sort alphabetically, keep original order.
  * Genus-level taxa: add "spp.".
  * Link at top to region info and species-code info; when clicking regions say "This station is included in the sums of the alley region".
  * Cross-check with the integrated database; add common names and sums (e.g. diatom sum).
  * Physical oceanography has 4 phytoplankton species that need to move into phytoplankton.
  * Change sentence "Click on a highlighted station on the map to view the years the species was observed".
- Ben missed the 9/25 12pm ET call (thread 1a0d94dbc7fb9c9d: Ben sent "Sorry to miss this... mom visiting... let me know how I can help asynchronously"; Erin: "I sent along the key notes and we can discuss more next time we meet"). Pooh meeting invite thread 1a0cafedff522795 (9/25 12-1pm ET).
- Classification: [ACTION: code/data] (phytoplankton ingest/app fixes: station keys, region sums, taxa order, spp., common names, 4 species moved from physical oceanography); [FYI] for Ben unless he owns the ingest side.

### 6. CalCOFI IFCB classifier check  (thread 19cd9613315016d4)  [FYI / possible future ingest]
- Rasmus <-> Vivian (Lin) Hou (vihou@ucsd.edu, PhD student, IFCB), Rebecca (rey003@ucsd.edu, undergrad intern); Ben + Erin cc. 9/29-9/30.
- Hou: Rebecca will check IFCB taxon naming against WoRMS (csv attached); a new detection model counts cells in chain diatoms (Chaetoceros/Lauderia); asks whether previous metadata format is the one wanted.
- Rasmus 9/29: metadata looks good, "if possible time could be added to the date stamp"; shows Explorer link (calcofi.io/explore/?lens=region&taxon=worms:341379&den=raw&layer=National+Marine+Sanctuaries) as eventual visualization place; asks how soon after fall cruise data can be ready (El Nino focus).
- Hou: normally everything (QC, classification, metadata) in a week after cruise; IFCB time series short (max 3 cruises/season, instrument breaks); mentions Mark's El Nino watch email. Rasmus 9/30: "amazing being able to serve and visualize the data almost real time on calcofi.io"; unsure how IFCB fits El Nino watch (short series with gaps), will ask Mark. Hou 9/30 16:25Z (UNREAD): "calcofi.io looks amazing !!! ... would be really nice to get the IFCB data there too."
- No ask of Ben yet; implied future ingest of IFCB data (WoRMS-named taxa) once dataset ready. Mark's El Nino watch email itself is not in Ben's mailbox.

### 7. Re: Follow up to RDC Consultation on depositing data at the Library  (thread 1a03b3c476afe255)  [REPLY NEEDED (to Ho Jung) / DECISION]
- Ho Jung Yoo (hjsyoo@ucsd.edu, UCSD Library) 9/16: answered copyright/cruise-naming questions; 9/17: created test instance, VPN/on-campus only: https://librarytest.ucsd.edu/dc/collection/bd9072271d; asks review of metadata fields and download of a file or two. Her pending question to the team: should Library cruise tags use CalCOFI naming; she is unfamiliar with "1998-02-31JD".
- Ben (sent 9/23 17:35Z) a draft-style reply "ONLY TO ERIN and BETTY..." to Erin and bthuang@ucsd.edu. It is NOT addressed to Ho Jung. Content: copyright agreed (UC Regents and CDFW rights holders, CC BY 4.0, credit in citation; CalCOFI is a program, not a legal entity); cruise_key = YYYY-MM-NODC explained (31JD = Jordan, 3322 = Shimada); suggested Library tag form "CalCOFI 0804JD (2008-04-31JD)"; mapping for the 2008-2014 object (1404SH = 2014-04-3322, 1304SH 2013-04-3322, 1304OS 2013-04-32I1, 1204SH/OS, 1104SH 2011-04-3322, 1104FR 2011-04-OIFS, 1004FR 2010-04-OIFS, 1004MF 2010-04-31FN, 0904FR 2009-04-OIFS, 0903JD 2009-03-31JD, 0804MF 2008-04-31FN, 0804JD 2008-04-31JD); mapping for 1949-2012 object (8405 = 1984-05-31JD, 8803 = 1988-03-31JD, 9804 = 1998-04-31JD, CALCOFI 0404/0504/0704/0804 = 200x-04-31JD, CCES-Sardine 0807 = 2008-07-31JD, Sardine Biomass 0904 = 2009-04-OIFS); one label covers two cruises (CALCOFI 0604 = 2006-04-31JD and 2006-04-33OA, per jar); one jar unplaced (2006-04-23 at station 40.0 35.0), asks Library/CDFW records for ship label.
- Erin 9/29 23:54Z (UNREAD) replied to Ho Jung only: "We discussed in our last data meeting. I have been having issues with the VPN recently so we will need to try again soon." She did not forward Ben's cruise mapping. So Ho Jung still has no cruise-naming answer from the team.
- Action: Erin/Betty to send Ben's text to Ho Jung (or Ben replies to Ho Jung directly); note Christy Juhasz (CDFW) asked for the Library URL (item 9).

### 8. CalCOFI DMP work update by Sept 2?  (thread 1a035889e1db4873)  -- Ed Weber (SWFSC)  [REPLY NEEDED + ACTION: code/data + DECISION]
- Ed Weber 9/25 23:37Z to Ben (cc Erin, Betty): no reply from Ben yet. Content:
  * New updated tables at Google Drive folder https://drive.google.com/drive/u/0/folders/13A9yDJCdV0M-lrMLqurzIb3G3ozknr9O ("more like our real db"). Standard haul factor hidden (trust SWFSC, not computed from wire angles per 10 m); MOCNESS nets screened out.
  * New tables: SpeciesItisLookup, SpeciesWormsLookup (accepted names; "Just aggregate by AphiaID"; "Do not question the taxonomic knowledge of the almighty Bill"), Fish (grown-out) table, CUFES data in the csv repo now linked with CruiseId.
  * Breaking change: LarvaeMeasured now contains length and/or stage; separate stage/size tables are gone (larvae both measured and staged can now be linked).
  * Answers to Ben's 6 questions: (1) egg stages 12-15 used for Dover Sole and sometimes Rex Sole, no reference, screen out if wanted; (2) net effort (volume, standard haul factor, percent sorted) "cannot be missing"; (3) tow max depth: Net.csv now has NetDepth (m) (true depth, not wire-out); (4) zero vs unsorted: no per-tow flag; separate stg (staging) schema exists, 198202 JD and 198212 JD (flagged by Ben) moved back to staging, "the others are true zeros and have valid positive zooplankton volumes"; (5) species_id -> WoRMS AphiaID: species table has AphiaID/TSN; (6) duplicate net+taxon+stage keys: FishMeasured resolves it, aggregate; the 4.8 % off-grid are real (ETP and other places, standard CalCOFI methods, retained).
  * "we agreed to use ICES ship codes, not NODC (they are virtually all the same though). Erin helped get our last blank ICES code resolved last year and the updated ShipLookup table now has a code for all."
- Asks of Ben: re-ingest swfsc_ichthyo from the new tables (breaking LarvaeMeasured schema), confirm cruise_key NODC vs ICES (our cruise_key is YYYY-MM-NODC; Ed says ICES agreed) -> DECISION; update the Q-sheet answers (shared "questions for SWFSC" sheet), drop 198202JD/198212JD; reply to Ed; he offered to talk.
- Earlier in thread (before window): Ed's UUID-as-primary-key objection, Ben 9/4 reply, naming-conventions doc.

### 9. Final questions about CDFW/CALCOFI crab data  (thread 1a06e1862431777c)  [FYI]
- Christy Juhasz (CDFW) 9/30: confirmed external links to the Library page are allowed; "Let me know the URL when you have it available." Erin 9/30: "We will share once its done!" Erin 9/24 had asked for a link to the UCSD Library page. Depends on item 7 completing. Ben and Betty cc only; no ask of Ben.

### 10. Naming Conventions doc comments  (thread 1a0cf5e3ae7f1ec2)  [FYI / possible edit]
- Erin comment 9/23 in "CalCOFI Naming Conventions" Google Doc (Identifiers): "@bhuang0022 @ben When we add the alt_cruise_key then mention that this is used by the community (e.g., 2505SR)". Ben replied in doc: "I suggest cruise_key_alt vs alt_cruise_key". Nothing outstanding; a schema decision (cruise_key_alt column name) now recorded, and relates to Library/community short-form labels (item 7).

### 11. CTD profile work updates?  (thread 1a0c51cab55b7a18)  -- Ben Gire / CTD team  [REPLY: optional / ACTION: code]
- Erin 9/21 asked for status; Ben Gire 9/21: first cruise through new software to preliminary stage "sometime this week"; Rasmus 9/22: asks Ben G to share new prelim csv format.
- Ben Gire 9/23 01:16Z: sample "cruise_station_correction.csv" (1 m binned CTD + bottle + cruise/station-corrected; NOT QA'd, coding exercise) with 27 new quality-code columns: TempAveQ; Salt1_CorrQ, Salt2_CorrQ, SaltAve_CorrQ; Ox1_CruiseCorrQ, Ox1_StaCorrQ, Ox2_CruiseCorrQ, Ox2_StaCorrQ, OxAve_StaCorrQ; Ox1uMQ, Ox1uM_CruiseCorrQ, Ox1uM_StaCorrQ, Ox2uMQ, Ox2uM_CruiseCorrQ, Ox2uM_StaCorrQ, OxAveuM_StaCorrQ; EstChl_CruiseCorrQ, EstChl_StaCorrQ; EstNO3_CruiseCorrQ, EstNO3_StaCorrQ; BATQ; PoT1Q, PoT2Q, DynHtQ, SVAQ, OxSat1Q, OxSat2Q.
- Ben (sent 9/23 17:19Z): 2607 corrected file already uses this layout; ingest adapted to read both layouts, apply each *Q flag to its own series (workflows#105); keeps computing two-sensor averages with Rasmus's rule and compares with SaltAve_Corr/OxAve_StaCorr, disagreements go back as a QC list; asked Gire to confirm *Q code list and keep column names/types stable (Marina said int->text flips stall DataZoo/EDI).
- Ben Gire 9/23 17:42Z: *Q columns use same code list (0,1,2,8,9); column names/value types will not change.
- Rasmus 9/23 18:23Z (UNREAD; to Gire, cc Ben): MLD criterion question: "MLD is the depth at which sigma-theta is 0.02 kg/m3 greater that a reference depth of 10 m" (Ralph/Ralf legacy definition); visualize derived data as explorer surface map. (Same as answered inline in item 3.)

### 12. Marine mammal app fix?  (thread 1a0cb55a69218911)  [FYI, loop closed by Ben; ACTION for Betty]
- Erin 9/22: marmam app down; can data be pulled into the integrated DB? Betty: yes (sightings 2004-Nov 2023, eDNA 2014-16, acoustics 2004-12 from marmam-app repo); needed GCS permissions (blocking eDNA + iron too). Ben (sent 9/23 17:37Z): fixed (CARTO Positron basemap now needs API key; switched to keyless Esri light grey; marmam-app#1, apps#42 for other apps); asked Betty to ingest all three; granted Betty objectAdmin on gs://calcofi-files-public and gs://calcofi-db under bthuang@ucsd.edu (unblocks eDNA DOI 10.15468/n52j6r and iron ingests); proposes retire app with URL redirect; asked Erin if SAEL is the owner to confirm retirement. Erin 9/23: yes SAEL; discuss with new Oct data. Done; nothing owed by Ben except later retire/redirect.

### 13. 2026-09-23 CalCOFI.io update (deck)  (thread 1a0cf85ba487a334)  [FYI]
- Ben sent the pptx to Erin, Betty, Mark (m4gold). Mark 9/24: appreciates, "impressive amount of work... visual approach is helpful".

### 14. Invitation: Betty, Ben, Erin email  (thread 1a0cf84008d8ad2f)  [FYI / calendar]
- Thu 2026-10-08 6pm-7pm CEST (Zoom, host Erin), attendance "optional".

### 15. Phytoplankton / Pooh meeting scheduling  (threads 1a0262fb50997c8d, 1a0cafedff522795, 1a0d94dbc7fb9c9d)  [FYI]
- Pooh (Venrick) "Input on app to easily find data collected on the CalCOFI platform" thread (26 msgs): meeting fixed Fri 9/25 9am PT / noon ET; Ben declined (family). Outcome in item 5.

### 16. Not CalCOFI (listed for completeness, not analysed)
- MarineSensitivity / BOEM: Tim White "Atlas" 9/24 (Ben replied: ready by end of week); Rice's whale data thread; unsent draft "Turtle suitability thresholding" to Tim White (9/21). 
- MBON: contact-form spam; USF SICC form 12051 (Ben promised to fill 9/30, not confirmed done); MBON Biodiversity WG declines.
- Marina Frants (CCE-LTER) "Datazoo template" 9/16 (1 msg, no body text visible; before window). EDI meeting thread 1a08d324dcee36c9 (9/16 9am call set).

---------------------------------------------------------------------------------------------------

## B. Unsent drafts (the five drafts of 9/24)

Only ONE of the five still exists as an unsent Gmail draft. The other four have no draft in their threads and match sent messages dated 9/23-9/25.

| Intended recipient | Thread | Status | Evidence |
|---|---|---|---|
| Kelsey Vogel (CTD files, 2607 corrected, Drive access, CSV attached) | 1a0a19b0fc83a57f "Google Drive Access" | **STILL UNSENT DRAFT** (draft id r-5609354737494233360, saved 9/23 23:03Z; thread has only Kelsey's 9/14 message) | list_drafts |
| Rasmus | 1a081fa6c2393fa1 "Next Two Weeks Tasks" | SENT 9/23 17:15Z (long update + 5 questions) and 9/25 16:05Z (short "update you by Thursday") | sent mail |
| Ben Gire / CTD team | 1a0c51cab55b7a18 "CTD profile work updates?" | SENT 9/23 17:19Z (Gire replied 17:42Z) | sent mail |
| Erin + Betty (marmam) | 1a0cb55a69218911 "Marine mammal app fix?" | SENT 9/23 17:37Z (Erin replied 18:28Z) | sent mail |
| UCSD Library | 1a03b3c476afe255 "Follow up to RDC Consultation..." | SENT only as an internal copy to Erin + bthuang@ucsd.edu, 9/23 17:35Z ("ONLY TO ERIN and BETTY..."); NOT sent to Ho Jung. No draft exists any more. Erin's 9/29 reply to Ho Jung did not include it. | sent mail + thread |

Other old drafts exist (e.g. 9/21 "Turtle suitability thresholding" to Tim White; 9/11 "Re: CalCOFI CTD profile & bottle data on EDI" to Rasmus, superseded by Ben's actual sends 9/15; 9/11 three species-illustration permission requests to NOAA/others; 9/10 "calcofi4py question" to nvpatin; 9/4 "CalCOFI Explorer citations and sources" to Erin+Betty).

### Draft gist: Kelsey (unsent)  -- cc rswalethorp@ucsd.edu, bmgire@ucsd.edu; attachment ctd_station_truncation_repaired.csv
Reply to Kelsey's 9/14 request for Drive edit access.
1. Thanks; diffed corrected 20-2607SH_CTDPrelim.zip (calcofi.org, 2026-09-14) vs ingested copy (2026-07-28): old file cut station numbers >= 100 to three digits (100/110/120 -> 000/010/020), the cause of missing 2607 offshore stations Rasmus noticed. Ben already put her corrected zip into the Drive folder and the cloud copy; offers edit rights on the folder for future fixes.
2. Same truncation found by the ingest check in four more preliminary files: 2507SR (12 casts; stations 80/100, 83.3/100, 86.7/100, 90/100-120), 2511SR (12 casts; same six stations), 2601RL (24 casts; stations 100-120 on lines 76.7-93.3), 2604SH (18 casts; stations 100-120 on lines 80-93.3); counts include down and up casts. Cast positions are 0.01-2.7 km from station + 100 and ~738 km from the station as written, so unambiguous; ingest restores station only where position confirms (reproduces her 2607 correction exactly). Asks her to issue corrected files for these four.
3. Sensor issue on 2607 casts 1-6: secondary temperature sensor (described faulty in cruise notes) not flagged; 1,516 scans physically impossible, another 806 differ from sensor 1 by > 0.5 C (up to 22.6 C). Next release flags sensor 2 as bad (9) on casts 1-6 plus derived series; temperature averages/climatology/transect plotter use sensor 1 alone there. Provisional: asks her to confirm or flag those scans in the source file.
4. Question: is the *Q-column layout in the corrected file (TempAveQ, SaltAve_CorrQ, OxAve_StaCorrQ, EstChl_*Q...) final for preliminary files from here on; do *Q columns use the same codes as per-sensor flags (0 good, 1 use primary, 2 use secondary, 8 questionable, 9 bad)? Ingest maps them (workflows#105). Signed "Cheers, Ben".
(NB: Ben Gire already confirmed the *Q code list and column stability on 9/23 in the CTD thread, so item 4 of the draft is largely answered; trim before sending. Items 1-3 still open and addressed to Kelsey. The draft was written before sending the Rasmus update on 9/23; it should now cite that the 2607 fix is in the next release.)

---------------------------------------------------------------------------------------------------

## C. Rasmus's open asks (consolidated checklist)

Deadline: Ben promised "update you by Thursday" (10/1). Rasmus's own window: "within your ~2-month window for El Nino" (Ben's phrase; fall cruise focus).

- [ ] Send the Thursday (10/1) update to Rasmus (promised 9/25); reply to 9/29 screenshots "CTD transect plotter does not seem to be showing the data correctly" (images unseen, open the thread in Gmail; likely 2607 / missing stations / DO).
- [ ] 2607 re-ingest of Kelsey's corrected file (+ 4 more truncated prelim files; request corrected files from Kelsey) so offshore stations and line 93 near shore appear (workflows#104, #105); then plotter rebuilds.
- [ ] Cruise-corrected oxygen into the database (workflows#106) so plotter shows cruise-corrected DO (2408SR 93.3-45 weird DO).
- [ ] ctd-transects: averaged sigma-theta TS1/TS2 "unless one is flagged" (#5), spice (#6), relative geostrophic flow (#7; relative only, no anomaly, exclude SCCOOS stations, speeds should be well below 1 m/s, down cast), monthly vs seasonal climatology toggle (#8; seasons = winter/spring/summer/fall), bottle climatology on observed depths (#9).
- [ ] Do not offer a transect plot with fewer than 3 stations.
- [ ] Bottle-based climatology: 1949-2013 and 1993-2013 means; bottle value if present else CTD profile (T_degC from avg sensor temp at bottle depth); variables T_degC, Salnty, O2ml_l, STheta, ChlorA, NO3uM plus PO4uM, SiO3uM, NH3uM, NO2uM; label "Discrete depth bottle data".
- [ ] Derived products defaults: MLD = legacy +0.02 kg/m3 sigma-theta below 10 m reference (headline; currently built with 0.03/0.125/0.2 C defaults), for Explorer surface maps; DCM = depth of Chl a max using 3 m running mean; integrated chl 0-200 m (sum of 1 m bins; trapezoid for bottle); exclude unrealistic spice/salinity outliers in pipeline (don't flag by spice).
- [ ] New derived products: nitracline depth (NO3 = 1 uM, linear interpolation for bottle); hypoxic boundary depths (O2 2.4 / 1.4 / 0.5 mL/L, shallowest); pycnocline depth (TEOS-10/gsw, MATLAB script attached, modify for 1 m bins); buoyancy frequency (plotter); isopycnal tracking 25-27 in 0.2 steps (parked, "ok to park"); Explorer layers (explore#13).
- [ ] Ammonium: do NOT assign qual=4 to early zeros; zeros are valid data and not to be excluded (Google Sheet action item 9/28; Annie Leffinger to concur).
- [ ] SOCCR / State of the California Current: schedule a meeting mid next week with Betty, Rasmus, Andrew Thompson (NOAA), Nastassia Patin; she had trouble pulling hydrographic data; standard plots for SOCCR.
- [ ] (From IFCB thread) eventual IFCB data ingest/visualisation; time stamp to be added to IFCB metadata; no action yet.
- [ ] Earlier (before window, still open?): EDI deposit decisions from the 9/16 meeting (CTD package, 1 m obs_ctd_full inclusion) with Marina Frants; CTD team PostgreSQL QC flow (Rasmus 9/24: flagging outliers once past cruises are QC'd in PostgreSQL).

---------------------------------------------------------------------------------------------------

## D. Needs Ben, ranked

1. [REPLY NEEDED, DEADLINE TODAY 10/1] Rasmus: status update promised "by Thursday" + 9/29 plotter screenshots + confirm MLD definition choice (legacy +0.02 below 10 m) and the new derived-product list. Thread 1a081fa6c2393fa1 (reply to msg 1a0edf9b753357f7).
2. [REPLY NEEDED + DECISION] Ed Weber (SWFSC) 9/25: new tables, breaking LarvaeMeasured, ICES vs NODC ship codes (affects cruise_key), answers to the six questions. Thread 1a035889e1db4873 (reply to 1a0daee3c2bb9090). Ed offered to talk.
3. [REPLY NEEDED] Kelsey Vogel: unsent draft exists (r-5609354737494233360); edit (the *Q question is answered) and send. Thread 1a0a19b0fc83a57f. Open since 9/14.
4. [DECISION] Library/Ho Jung: cruise-naming answer from Ben never reached Ho Jung; decide who sends (Erin said she has VPN issues; Ben's mapping is ready). Thread 1a03b3c476afe255. Christy (CDFW) waits on the Library URL.
5. [DECISION/ACTION] Ammonium qual=4 backfill: do not backfill (Rasmus). Update ammonium censoring doc/questions; reply to the sheet comment (thread 1a0ea6580f0654bc). Annie to concur.
6. [ACTION: data/code] 2607 + four truncated prelim files re-ingest, cruise-corrected oxygen, derived products update, Explorer layers (workflows#104/#105/#106/#98, explore#13, ctd-transects#5-9).
7. [FYI/Waiting] SCCOOS quote: Ben asked Erin which way to adjust Quote 1; issue revised quote(s) on answer (thread 1a0f49a5deecf2a2).
8. [FYI] Oct 8 6pm CEST Betty/Ben/Erin meeting; Hou asks for IFCB on calcofi.io; phytoplankton fix list (Betty/Pooh); marmam ingest by Betty.

No messages with explicit calendar deadlines other than: Thu 10/1 (Rasmus update), Wed 10/7 or so (SOCCR meeting "mid next week"), Thu 10/8 (team meeting).
