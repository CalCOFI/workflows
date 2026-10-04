# Tactiq extraction, meetings 2026-09-16 -> 2026-10-01 (run 2026-10-01)

No access_required errors. No meetings exist after 2026-09-30 in Tactiq (nothing for today 10/01 yet).
Tactiq's own AI summaries for 9/23, 9/24, 9/30 were still "generating"; the 9/23 report below is from the full transcript (5 pages, read in full).

## Meeting inventory

| Date | Title | Attendees | CalCOFI? |
|---|---|---|---|
| 2026-09-16 | CTD data on EDI discussion | Ben, Betty, Erin, Marina Frants, Rasmus | YES (already summarized before; brief below) |
| 2026-09-16 | MBON tech mtgs | Ben, Dan Otis, Tylar Murray | Mostly NOT; passing CalCOFI mentions (below) |
| 2026-09-23 | Ben, Betty, Erin CalCOFI DMP | Ben, Betty Huang, Erin Satterthwaite | YES (main meeting, focus) |
| 2026-09-24 | Marine sensitivity check-in | Ben, BSEE-STER-Conferenceroom334 | NO (no CalCOFI term matched in transcript) |
| 2026-09-30 | MBON Biodiversity Indicators Working Group | Adriano Lima, Ben, Joshua Kilborn, Tylar Murray | NO (no CalCOFI term matched) |

There was NO 9/17 -> 9/22 meeting in Tactiq, and no Rasmus meeting after 9/16.

---

## 2026-09-16 "CTD data on EDI discussion" (brief; previously summarized)
URL: https://app.tactiq.io/api/2/u/m/r/sQUnvbaQ6xG017MUaxDk?o=mcp  (91 min)

Summary: Plan to publish CalCOFI CTD profiles to EDI (via CCE DataZoo handoff by Marina, or direct EML upload from Ben's pipeline). License CC BY 4.0. Quarterly updates, only data at "preliminary + portal" quality or better. Explore app/derived products discussed; Rasmus wants derived hydrographic products in ~2 months for El Nino interest.

Decisions
- License CC BY 4.0 (the existing calcofi.org data-usage-policy license) unless an objection.
- First EDI submission follows current CalCOFI CTD profile CSV format (hydrography + chl-a) plus a unique identifier column for linking to the portal DB, plus a "data state" column.
- Quarterly EDI updates; Marina wants stable column types across updates (no int -> string flips) and email notification with a link, not attachments.
- No "CTD preliminary"-only data to EDI. Rasmus: "I would not include anything that is just CTD preliminary. I think not before it's reached these preliminary and portal data would I release it to EDI."
- Keep the simple bespoke CTD transect viewer alive alongside Explore. Rasmus: "I think I still want to keep it alive, at least for the time being, because it's a little more simple and in relation to ... this incoming El Nino, it's just a very straightforward, easy way to direct people to."
- Derived products = separate derived dataset(s) (Ben's proposal), selectable in Explorer and separately downloadable.

Rasmus verbatim (derived products / CTD tech)
- "average sigma theta" and "average salinity ... some of the things I mentioned in the email"; "there's some individual sensors in there that we can get rid of."
- "what the possibility is on your end, if I supply the equations, all the directions for how to do it. Some of them are really simple, to generate some derived products ... such as ocean spiciness ... A spicy water is warm and salty. [Minty] water is cold and fresh. But it is a pretty useful index, because ... sometimes it allows us to discern a little bit better where different currents are located ... you will often see a high spiciness on line 93 ... closer to the coast, and that is where ... the California undercurrent is coming in ... during El Nino, you anticipate that one to increase in strength and probably also in size. So be able to actually see that would be a cool thing."
- Mixed layer depth: "a very simple calculation. You have a reference point. And when density has increased by this much, I forgot exactly how much, but I can look it up, then that is the depth of the mixed layer."
- "it could be something like hydrographic-derived products ... in that Explorer as well ... not actually the raw values, but the derived products of the raw values."
- "there's a bunch more I can think of. And most of them are fairly easy to calculate. But as long as I supply an equation with how to do that..."
- Also in meeting (per summary): depth of chl-a max, integrated chl-a (sum of 1 m bins).
- QC: "we're adding more quality code fields ... there isn't one for every data stream ... nobody ever looked at PAR data before ... there's going to be a quality field for PAR data. So the format in the next release of CTD profile data is going to contain some more columns [same names, added quality-code columns]." New CSVs will be generated "going back at least to 2019."
- Timeline ask: "...two months ... by the time that we have some data ready from our [El Nino] cruise ... updating the transect viewer, but maybe also adding some derived products to the map viewer that we can direct people to." Ben: feasible ("we can give it a shot"; "Super El Nino ... there's gonna be a lot of eyes on it").
- Cruise dates (Rasmus): "it keeps moving around. Right now, it's been pushed to October 31st to November 10th, so it's also gotten shortened a little bit." "We will have journalists out on the next cruise."
- Quarterly cadence: "if we keep up the pace ... generate preliminary CTD and bottle data before the next cruise."
- Mark Ohman (garbled "Mark Ullman") convened a meeting 9/15 on data products/plots to keep the public informed about the incoming El Nino; Rasmus refers people to the transect site.

Action items (9/16)
- Rasmus: share new CSV layout + QC column definitions + site_key schema ASAP; confirm/populate PI/role/contact/license metadata; supply equations for derived products (MLD threshold, spiciness, etc.).
- Ben: confirm exact unique-ID construction for CTD records; produce compressed parquet/CSV with GCS download links for Marina; decide direct EDI upload (needs credentials) vs DataZoo handoff; was offline a few days after 9/16 (mom's 80th).
- Betty (+ Aaron): with Ben/Rasmus the following week, build the first EDI-ready CTD submission and test EML validation.
- Marina: DataZoo entry/EML validation/upload to EDI (uses EDI access key); wants stable schema.
- Erin: verify CC license / NOAA-funding constraints.
Open: split by decade vs one big 1 m table (full thinned 1.39 GB parquet, 3.2 GB wide CSV, ~15.8 GB 1 m-binned); who holds EDI credentials; definition of "preliminary" vs publishable.

---

## 2026-09-16 "MBON tech mtgs" (not CalCOFI; passing mentions only)
Ben showed MBON colleagues (Dan Otis, Tylar Murray): an oceanmetrics.io/erddap-places DuckDB-in-browser app; the CalCOFI Explorer (hexagons, IDW, sections, 3D deck.gl, sanctuaries summaries); that "my next meeting is with CalCOFI folks on pushing datasets into EDI"; that he pushed a CalCOFI ichthyoplankton dataset to OBIS and built a generic OBIS publisher borrowing eDNA data standard; considering migrating Shiny apps to AI-assisted dev. No actions beyond this.

---

## 2026-09-23 "Ben, Betty, Erin CalCOFI DMP"  (FOCUS)
URL: https://app.tactiq.io/api/2/u/m/r/W9SDZSgAd09L6MpqRqor?o=mcp  (~82 min; Rasmus and Marina NOT present)
Attendees: Ben Best, Betty Huang (now in Sacramento), Erin Satterthwaite.

### Summary
1. Kuali / vendor security: Erin emailed "Pilar" (Kuali vendor-security contact); Pilar said it is moving, "days", will let them know. Ben had also asked ~1.5 weeks earlier. Erin is keeping it moving. (No further detail in this meeting.)
2. CDFW Dungeness crab dataset: the CDFW (California) data portal posted the dataset faster than expected, but its link points to the original "notebook/HTML" link, not the UCSD Library DOI. Portal has no DOIs. Erin will ask Christy (CDFW) to link to the UCSD Library DOI instead and to make sure the portal's data/resources match the DOI version. Unclear whether the portal copy is Betty's cleaned version or the raw one; Betty only looked at the link, not the content. Erin's difficulty with VPN (could not view the test version). Christy answered some provider questions (e.g., timezone: Pacific time); this likely changes nothing for the UCSD Library submission except noting timezone, but Betty should verify. Ben had generated the questions via the ingest skill; Ben/Betty to send consolidated reply.
3. Cruise nomenclature: UCSD Library asked how cruises are named. Community format is e.g. "2501SR" (YYMM + 2-letter ship); DB uses cruise_key YYYY-MM-NODC. Crab dataset itself uses odd labels (e.g. "CalCOFI 8803", no ship code); Betty had earlier replied with a proposed mapping (e.g. 0404SR) in the email thread. Decision: add an explicit alternate field `cruise_key_alt` (community/legacy nomenclature) to the cruise table, keep cruise_key authoritative; reconcile sources (bottle vs ichthyo disagree). Ben pointed to `collect_cruise_key_mismatches()` in calcofi4db and floated a web tool where people upload a CSV of cruise names and get a lookup + mismatches. Ben to investigate where the original source form lives (source cruise id).
4. Betty's status (GitHub issues): #79 provider metadata inventory; #80 she drafted emails to every provider for citation/license/DOI/PI (Google Doc), Erin to review tone/recipients and added comments (suggestion: include the full metadata spreadsheet row and ask providers to verify ALL fields; Betty will also add the spreadsheet at the bottom of the email); #81 definitions of Southern/Central California regions mapped to CalCOFI grid (phytoplankton has four regions; Ben had inferred; ask Venrick Friday); #82 she needs GCP access (Ben enabled it on her UCSD email; she has 2-3 ingest groups ready); Explorer review (#?; "looking pretty good", mostly UI hand-holding; one bug: value not updating when toggling biology/environment: krill 106 and temperature 106 deg; explore issue #12; broken image display was Ben's end); #17 tutorials in R and Python that reproduce State of the California Current figures (feeds the database paper) - she made one test figure; question which figures (phyto/zoo/seabird/mammal). Erin: email Rasmus (he and Andrew Thompson are doing State of the California Current this year), send screenshot, ask which figures matter, CC Erin. Marine mammal data mentioned as an upcoming topic (Betty to cover).
5. Mark flagged to Betty that CTD profiles are the number-one priority for CalCOFI; Betty wants to help; Erin to facilitate; "it's going to be on Ben and Rasmus" to get ready.
6. Ben's update slides (2026-09-23 CalCOFI.io update.pptx): species pages + measurement pages (89), silhouettes (PhyloPic), photos, GOOS EOVs + NERC tagging, "stations not grid cells" (site_key, 3.x format), climatology table (site_key by month, 10 m bin) changing coastal anomalies (freshening/cooling), quality flags and sensor-average rules (Rasmus's latest responses) going into next release, Jim Wilkinson's 66 pre-1998 cruises ingested (source = GCS, not yet on calcofi.org), undersea feature names + station/line labels in 3D map, ERDDAP refuses unconstrained dumps now (4 GB requests had crashed the server), sitemap auto-regenerated, feedback bubble with screenshot -> issue + email + Google Sheet, docs updated (draft Google Doc removed; docs book authoritative), mislabeled stations fixed, license links on emails, Marmap app fixed (repo had to be unarchived).
   - On derived products: "Rasmus was asking about spiciness ... and geostrophic flow, and also mixed layer depth. So that's going to be in the [next release]." "the transect ... derived CTD [slice] is actually in process". "there's going to be a new derived product data set ... Andrew Thompson has created derived data products like for the sanctuaries."
   - Ben wants the Explorer section lens to use the same cmocean color ramps as the CTD transects app, and to be exactly identical to the CTD transects (site_key finer than grid_key at coastal stations).
7. Feedback/rollout plan: Erin wants providers' input saved for dataset/metadata sorting, and the next rollout to providers will be the Explorer. Ben suggested live "backseat" sessions (30 min, screen-share, don't drive) with key people (Ed = ichthyo, Andrew = plankton, Rasmus = measurement pages) to see where they stumble. Erin liked it. Ben flagged AI-written "why it matters" quotes/sentences on measurement pages need citation + expert review.
8. Ben: "maybe we just need the AI chat bot thing ... we talked about [in the] proposal a while back."

### Decisions
- Add `cruise_key_alt` to cruise table; cruise_key stays authoritative.
- Link CDFW portal to the UCSD Library DOI (Erin to ask Christy); ensure portal version = DOI version.
- Provider emails (#80): include full spreadsheet row; offer reply-by-email AND fill-in; Erin to sign off; sequence EDI uploads by who responds first (blockers = citation, license, PI name).
- Betty may run full ingest loop (GCP access granted).
- Ben's default: build from best inference, then ask providers for affirm/refute.
- State of California Current figure list: ask Rasmus.
- Explorer provider rollout after dataset/metadata work; run live feedback sessions.

### Action items by owner
Ben
- Add `cruise_key_alt`; investigate where the original/source cruise label lives; reconcile across sources; consider CSV-upload cruise-name translator (uses collect_cruise_key_mismatches).
- Send consolidated reply (with lookups) on CDFW crab questions to Erin and Betty (he said he just hit send / would send to Betty too).
- Fix Explorer section lens: cmocean ramps, match CTD transects; Betty's krill/temperature value bug (explore #12).
- Next DB release: derived hydrographic products dataset (spiciness, geostrophic flow, MLD), quality flags + sensor-average rules, climatology.
- Get expert review of species/measurement pages (citations for AI "why it matters" text).
- Be available for 10/8 9-10 am PT DMP call; Ben working lightly the last week of October.
Betty
- Revise provider emails per Erin's comments and send; verify whether crab data on UCSD Library/CDFW portal is clean vs raw and whether Christy's answers change the submission (timezone Pacific); email Rasmus re State of California Current figures; keep working issues 79-82, Explorer bug probing; run ingest loop with GCP.
Erin
- Review/sign off Betty's provider-email Google Doc (added comments); ask Christy (CDFW) to point portal at the UCSD DOI; ask phytoplankton (Venrick) region questions Friday 9/25 9 am; keep nudging Pilar re Kuali; plan Explorer rollout to providers; test species/measurement pages with her own questions.
Rasmus
- (not present) State of the California Current figure priorities when Betty emails.
Claude (automatable)
- Add `cruise_key_alt` column + test + docs; cruise-name lookup/translator.
- Derived hydrographic dataset: spiciness, MLD, sigma-theta averages, geostrophic flow (needs Rasmus's equations/thresholds), Explorer lens + release wiring.
- Explore: cmocean ramp harmonization; value-update bug (#12).
- Tutorial scaffolds for State of California Current figures (R/Python) once figure list known.
- Provider email drafts / questions.csv updates from Christy's answers.

### Open questions
- Is the CDFW portal copy the cleaned or raw crab data; will CDFW re-link to the DOI?
- What to call/how to populate the community cruise key; how to reconcile bottle vs ichthyo vs crab cruise labels.
- Phytoplankton region definitions (4 regions vs 2 documented).
- Order of dataset uploads to EDI (depends on provider responses).
- Which State of California Current figures to reproduce.
- Kuali vendor security timing (Pilar "days").

### Dates / deadlines stated
- "We have a meeting next week on the first [= TODAY, Thu 2026-10-01] with Mark" (Erin). Mark = presumably Mark Ohman (CalCOFI/SIO). No transcript for it exists yet.
- Next Ben/Betty/Erin DMP meeting: week of Oct 5, set for Thursday 2026-10-08, 9-10 am (Ben conflict only 10-11). 
- Erin: conference + travel at end of October (Western Society of Naturalists in Sacramento in November); Ben working lightly the last week of October.
- Friday 2026-09-25 9 am: meeting with the phytoplankton provider (Venrick) - Erin.
- El Nino cruise (from 9/16, Rasmus): Oct 31 - Nov 10, journalists aboard; goal of derived products + transect viewer updates "in about two months" from 9/16 (~mid-Nov).

---

## 9/24 and 9/30 (non-CalCOFI)
- 2026-09-24 Marine sensitivity check-in (Ben + BSEE conference room, 32 min): not CalCOFI.
- 2026-09-30 MBON Biodiversity Indicators Working Group (Adriano Lima, Joshua Kilborn, Tylar Murray, 55 min): not CalCOFI.

## Not found in Tactiq
No meetings with Rasmus, Betty, Marina, Kelsey Vogel, Ben Gire, Venrick, CDFW, marine mammals/sonobuoy/eDNA, iron, UCSD Library, or Kuali vendors after 9/16 other than the 9/23 DMP call. No 10/01 transcript yet.
