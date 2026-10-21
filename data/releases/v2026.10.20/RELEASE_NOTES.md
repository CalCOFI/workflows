# CalCOFI integrated database release v2026.10.20

**Release date:** 2026-10-20 · **promoted** (`latest.txt`)

## SWFSC's 14 October export: squid eggs are *Abraliopsis felis*, FROSTI's cruises key by 18DN, and each net carries its side and tow number

Ed Weber's 2026-10-14 export of the SWFSC CalCOFI database answers the ten questions of
2026-10-06 (`metadata/swfsc/ichthyo/questions.csv` Q14, Q17–Q25; `metadata/swfsc/cufes/questions.csv`
Q09–Q15). `swfsc_ichthyo` and `swfsc_cufes` are re-ingested from it; no column was added or removed
in any of its 17 tables. The sections below are what a consumer sees change.

## CUFES "squid eggs" are *Abraliopsis felis*, not market squid

"Bill says we can safely call these Abraliopsis felis, sppcode 9561, AphiaID 341849, because they
are the only squid in this region that have pelagic eggs" (Ed Weber, 2026-10-14; `swfsc_cufes` Q11,
the opposite of what we had proposed). `metadata/measurement_taxon.csv` keys `squid_eggs` and
`squid_eggs_per_m3` to *Abraliopsis felis* (`worms:341849`, ITIS 82401); through v2026.10.19 they
were keyed to *Doryteuthis opalescens* (`worms:574540`).

**Consumers:** every `obs_bio` row of `swfsc_cufes` with `measurement_type` `squid_eggs` /
`squid_eggs_per_m3` (82,334 rows: 41,167 counts and 41,167 concentrations, 18,131 of each with eggs)
changes `taxon_key` from `worms:574540` to `worms:341849`; the
species face and the Explorer label change from "Market squid" to *Abraliopsis felis*. A query
keyed on `worms:574540` finds no CUFES rows in this release.

## FROSTI's seven cruises key by NODC 18DN, not OIFS

SWFSC corrected the ship table: "I dug into the NODC codes for Frosti (yes, 18DN) and Bold Horizon
today and now have a complete and correct table. Also NODC and ICES codes now correspond
completely" (Ed Weber, 2026-10-14; `swfsc_ichthyo` Q14). `create_cruise_key()` mints `YYYY-MM-NODC`
from `ship.ship_nodc`, so the seven FROSTI cruises change key (Ben Best, 2026-10-20, decision D1:
adopt the corrected code; NODC's own platform list says 18DN). Every dataset that keys events to
them (`swfsc_ichthyo`, `swfsc_cufes`, `cdfw_dungeness-crab`, `sio_pic-zooplankton`,
`cce-lter_euphausiids`, `cce-lter_zoodb`; 4,999 `sample` rows in v2026.10.19) is re-rendered against
the new `cruise` shard, and `ship_ices` now equals `ship_nodc` for every ship.

**Consumers:** the old keys are gone from `cruise`, `sample`, `obs_bio`, `obs_env` and
`climatology`; map them one to one:

| v2026.10.19 | now |
|---|---|
| `2003-07-OIFS` | `2003-07-18DN` |
| `2004-03-OIFS` | `2004-03-18DN` |
| `2004-07-OIFS` | `2004-07-18DN` |
| `2005-03-OIFS` | `2005-03-18DN` |
| `2009-04-OIFS` | `2009-04-18DN` |
| `2010-04-OIFS` | `2010-04-18DN` |
| `2011-04-OIFS` | `2011-04-18DN` |

`cruise.cruise_uuid` is unchanged for all seven, so a join on SWFSC's CruiseId needs no mapping.
Measured against v2026.10.19 on the re-ingested shards: 2,750 `swfsc_cufes` and 2,047 `swfsc_ichthyo`
`sample` rows change key (one fewer than the 2,048 of v2026.10.19: a removed net-less tow was on
2011-04); the other four datasets re-key at the release run.

## One ichthyo species code re-keys: 844 "Microdesmidae" is `worms:151793`

SWFSC's rebuilt Species table re-points code 844 (*Microdesmidae*) from AphiaID 151423 (family
Microdesmidae) to 151793 (subfamily Microdesminae, WoRMS's accepted placement). The ingest keys what
the source supplies, so its 6 `obs_bio` rows (8 larvae) move from `taxon_key` `worms:151423` to
`worms:151793`; SWFSC's verbatim name stays on `dataset_taxon`. Every other ichthyo `abundance` value
is identical to v2026.10.19 (487,610 of 487,616 rows pair exactly), and `data/flagged/species_worms_lookup_check.csv`
is empty: every code now keys its own source AphiaID and every `SpeciesWormsLookup` name agrees with
WoRMS (11 rows at v2026.10.19).

**Consumers:** `worms:151423` has no ichthyo rows in this release; read `worms:151793`.

## Each ichthyoplankton net carries its side and tow number: `ichthyo_net`

The core projection drops two source columns: `Net.NetSide` (starboard or port of a bongo pair) and
`Tow.TowNumber` (which of several tows of one type at one station occupation). They are what tells
the two nets of a CalBOBL or PairoVET tow, and two tows of one type at one occupation, apart, and the
SIO Pelagic Invertebrate Collection's "Parent Net Event" table is matched to the released nets on
exactly those (Linsey Sala; Ben Best, 2026-10-20, decision D2). New table **`ichthyo_net`**, one row
per net (77,888): `sample_key` (the net's; primary key and FK to `sample`), `net_uuid` (SWFSC's
NetId, = `sample.source_uuid`), `tow_uuid` (SWFSC's TowId), `net_side` (`S` on 56,248 nets, `P` on
3,557, NULL on the 18,083 single-net C1, CalVET and Manta nets), `tow_number` (1 on all but 121 tows;
up to 2 on C1, 3 on CalBOBL, 6 on Manta and 50 on PairoVET; (station, tow type, tow number) is unique)
and `tow_type`. Declared in `core_relationships()` (calcofi4db 4.28.0), beside `fish`. Every two-net
tow is one S and one P. `fish` itself is unchanged (10,796 rows identical to v2026.10.19).

## The cruise reference is the union of SWFSC's dbo and stg schemas

"You now have the union of my stg and dbo cruises" (Ed Weber, 2026-10-14; `swfsc_ichthyo` Q23).
`Cruise.csv` goes 694 → 739 rows, 50 of them with no station: the two cruises whose ichthyoplankton
are back in staging (198202JD, 198212JD — the ingest now asserts they have no Station, Tow or Net
row rather than no Cruise row), CUFES-only cruises, and cruises only the bottle and CTD sources
sample. Consequences in `cruise`:

- 21 keys that v2026.10.19 completed as `cruise_key_method = 'derived'` rows (1952-09 BD, 1989-08
  NH, and 19 bottle/CTD cruises from 2016-11 to 2025-07) are now `swfsc` rows with a `cruise_uuid`;
  `derived` falls from 151 to 130, mostly 1949–1959 cruises.
- A reference row with no station has no tow span, and the 21 above would have lost the span their
  derived row carried. `complete_cruise_reference()` (calcofi4db 4.28.0) now fills a NULL span from
  the events the other datasets key to the cruise, before adding any derived row, so check 6 of
  `check_cruise_key_integrity()` (an event within its cruise's span) keeps covering them. A row with
  its own tow span keeps it; a row no dataset keys to stays NULL.
- The 40 `cce-lter_euphausiids` tows of February 1982 key `1982-02-31JD` again (they resolved no
  cruise in v2026.10.05–v2026.10.19); the release's NULL-`cruise_key` ratchet for that dataset
  returns to 420.
- 24 brand-new SWFSC keys with no event in any dataset (e.g. `1993-09-31M4` beside `1993-09-31JD`,
  and the Lasker's 2019-07, 2021-03, 2021-07, 2022-07).

## Nine net-less tows and the egg stages 12–15 are gone at source; two proportions sorted corrected

- `Tow` 74,394 → 74,385: the nine CalBOBL tows with no Net row "were all spoiled samples, spilled
  samples, or lost vials. They are now removed" (`swfsc_ichthyo` Q21). They carried no observation
  and no effort, so `sample` loses nine tow rows (1978-08 VA, 1982-03 PN, 1985-05 JD ×2, 1999-08 NH,
  2007-04 JD, 2011-04 FR, 2012-03 SH, 2021-01 RL) and nothing else; true-zero tows go 6,302 → 6,293.
  Three of them were their station's only tow, so three `site` rows (1978-08-57VA 136.7 023.0,
  1982-03-90PN 093.3 035.0, 2021-01-33UD 080.0 060.0) now have no tow and a NULL `datetime`, as the
  stations of the 15 tow-less cruises already did.
- `EggStage` 18,914 → 18,245: every stage 12–15 row is removed at source — anchovy and sardine stage
  12 was "a lazy, stupid hack that they did to flag some records for DEPM", and the Dover and Rex
  sole rows go with them (Q22). The ingest already screened them out, so the published `stage`
  distribution is unchanged; the screen is now a guard that expects zero rows.
- Two C1 nets' `PropSorted` 3.4 → 0.294 and 4.286 → 0.233, and their `SmallPlankton` 10 → 34 and
  7 → 30 ml (Q21): `sample_measurement` `prop_sorted` and `small_plankton_biomass` change on those
  two nets and nowhere else (every other `sample_measurement` value of the dataset is identical). The
  five "empty bongo tows with no zooplankton volume" are port-net-only tows, and a port net carries
  no zooplankton volume by design ("I don't have any non-port bongo tows in the db without
  zooplankton volumes"); the ingest now counts a missing volume on non-port nets only (0).
- `Cufes` 202101 RL sample 100: `StopPumpSpeed` 40.0 → 0.64 (`swfsc_cufes` Q10), so that sample's
  `pump_speed_mean` and `volume_pumped_m3` change and its one non-zero `egg_concentration` (squid)
  goes 0.00113 → 0.0360 eggs/m³ (×31.75); its five other counts are zero. That is the only CUFES
  value that changes: all 550,162 `obs_bio` rows pair with v2026.10.19 once the squid key is mapped.

## NetDepth is the estimated depth with all wire out, and the stations where it is below the sea floor go back to SWFSC

"It is the estimated depth when all wire is out. It is roughly the maximum depth of the tow but
that estimate might be a little off. The 'possible' sounds too certain here" (Ed Weber, 2026-10-14;
`swfsc_ichthyo` Q19). Every description that said "maximum possible depth" now says this; the data
(`sample.depth_max_m` on tows and nets) and the release's own ratchet (210 stations more than 10 m
below the deepest GEBCO cell around them) are unchanged, because `Net.NetDepth` is unchanged in the
export. Those 210 stations, with their tow and net UUIDs, are in
`data/flagged/netdepth_below_seafloor.csv` for SWFSC to screen ("If you send me the problems we can
also try to screen some of these for errors").

## `fish` is fish larger than larval size, counted in addition to the larvae

"They are fish larger than larvae size. So generally juveniles but not exclusively. They are not in
both tables" (Ed Weber, 2026-10-14; `swfsc_ichthyo` Q20). The table stays (Ben Best, 2026-10-20,
decision D3) and is described so: additive to the larval abundance of the same net and species code,
never double-counted, and still not projected into `obs` because no life stage in the vocabulary says
exactly "larger than larval size". The 974 orphan `LarvaeMeasured` rows and the 629 lost larval-stage
records are "expected. Some of these may be reconstructed from paper sheets" (Q17, Q18): still
flagged, still unreleased.

## Other answers recorded

- CUFES "is ongoing. We cannot keep up with processing given our current staffing right now" (Q13);
  the record still ends 2022-04-27. The 37 CUFES samples with a start but no stop position are kept
  at their start position until SWFSC confirms whether "Yes to removing recs with no stop position"
  means them (Q14, proposed; decision D5).
- The five cruises with no station at v2026.10.05 "all have CUFES data … At least the last two have
  unprocessed staged tow data that will eventually be uploaded" (Q24).
- SWFSC rebuilt its ITIS and WoRMS lookups; `taxon.scientific_name` stays the WoRMS accepted name
  and `dataset_taxon.ds_scientific_name` SWFSC's verbatim name, as provenance (Q25; decision D4). Any
  code still keyed to another id than its source AphiaID is listed in
  `data/flagged/species_worms_lookup_check.csv` for SWFSC, never patched by an override.
- `swfsc_ichthyo` gains `link_data_source` (NOAA InPort item 20691, the provider's record of the
  database), so calcofi.io shows an "Original at" link for it.

## A new dataset: `calcofi_bottle-derived`, spice and TEOS-10 sigma-theta at every bottle since 1949

Rasmus Swalethorp asked for values derived from the bottle database to live in a dataset of their own,
back-calculated to the start of the record (thread "calcofi derived data", 2026-10-19), after
Nastassia Patin asked for spice at each bottle depth. `ingest_calcofi_bottle-derived.qmd` computes two
values per bottle from the bottle's own temperature and salinity, at the sea pressure of its depth
(`gsw_p_from_z(-depth, latitude)`):

- **`spiciness0`** (kg m⁻³), the same key and the same rule (`ctd_spice()`) as the CTD derived
  products. Filter on `dataset_key` to keep the bottle and CTD series apart. The registry row now lists
  both datasets in `_source_datasets` (Ben Best, decision D8).
- **`sigma_theta_teos10`** (kg m⁻³), new: potential density anomaly at 0 dbar by TEOS-10
  (`gsw_sigma0`), NERC P01 `SIGTPR03`. The bottle database's own `sigma_theta` is DECODR's legacy value
  and stays as it is in `calcofi_bottle`. The new key does not join its `variable`, because both come
  from the same bottles.

Flags come first: a bottle whose `T_qual` or `S_qual` is 8 or 9 gets neither value. A cruise whose
input is known to be wrong is withheld by name: all 918 bottles of 2021-05-3322, whose published
salinity equals its own sigma-theta, so the salinity column holds sigma-theta (`calcofi_bottle` Q13,
open with the provider). A value we know is wrong never enters a derived product (Ben Best,
2026-10-20), and the cruise returns when Q13 is answered (Q03). Of 843,828 other bottles with a
temperature and a salinity, 2,155 are flagged, so **841,673 bottles** (1949-02-28 to 2021-02-03) carry
both values, 1,683,346 `obs_env` rows. The dataset emits no `sample`; every row sits on its
`calcofi_bottle` bottle. `build_climatology()` takes every `obs_env` row, so both types get baseline
cells under this `dataset_key`. The rule is calcofi4db's new `bottle_spice_sigma0()` (4.27.0), and its
tests compare it to the Gibbs SeaWater functions directly. The declared bound for
`sigma_theta_teos10` is −8 to 37 kg m⁻³: `gsw_sigma0` over the registered bottle temperature and
salinity bounds (Q02). `spiciness0` keeps its −25 to 18 bound.

Over 839,590 bottles that also have an unflagged legacy value, TEOS-10 minus legacy is a median
0.0041 kg m⁻³ in absolute value (p99 0.0150, max 0.786). 10 bottles differ by more than 0.1 and are
listed for the provider (Q03). Licence and PI inherit `calcofi_bottle`'s open questions (Q01).
`ingest_calcofi_ctd-derived.qmd` now merges into `_source_datasets` rather than overwriting it, so
re-rendering it no longer drops the bottle dataset from `spiciness0`.

## CalCOFI 2607's second temperature sensor is judged by the provider's own flags, and a sigma-theta computed from a flagged sensor is flagged

The 24 provisional flags on cruise 2026-07-3322 (casts 1-6, both directions, the secondary temperature
sensor and the 11 series derived from it) are gone. We had set them on 2026-09-24 because the provider's
cruise notes called the sensor faulty on all six casts; the provider's corrected file now carries its own
codes (9 on casts 1U, 5U, 6D, 6U and 385 of the 515 bins of 5D) and Ben Gire wrote that the processed
files are accurate. Casts 2-4 and the downcast of cast 1, which the provider leaves unflagged, therefore
enter the sensor-pair averages again (the secondary reads about 0.15 degC from the primary there). Against
v2026.10.19, from the provider's file: `temperature_ave` changes on 841 one-metre bins (at most 0.257
degC), `salinity_ave_corr` on 889 (0.370), `oxygen_ml_l_ave_cruise_corr` on 889 (0.222 ml/L),
`oxygen_ml_l_ave_sta_corr` on 194 (0.281 ml/L) and `oxygen_umol_kg_ave_sta_corr` on 194 (12.31 umol/kg),
and the derived `spiciness0` on 889 bins (0.269). Of those bins, 151 (temperature), 157 (salinity and
spiciness) and 41 (oxygen, sta_corr) sit at depths published in `obs`. The 12 sensor-2 series change only
in `measurement_qual` on the bins the provider did not flag (9,864 values); no sensor-2 value changes, and
nothing else outside 2607 moves for this change. **Consumers:** a 2607 anomaly or section built on these
averages shifts by up to the amounts above.

Where the provider flags a temperature or salinity 8 or 9 it often leaves the sigma-theta computed from it
unflagged (`SigThetaTS2Q` is blank on 2607 casts 1U, 5D and 6U where `Temp2Q` is 9), and the derived
`sigma_theta_ave` and mixed-layer depths read only the sigma flags. A bad sensor's sigma-theta therefore
entered the average. The ingest now writes the sensor's flag onto its sigma-theta (`sigma_theta_1` from
`temperature_1` and `salinity_1`, `sigma_theta_2` from the second pair; 9 over 8; the provider's own 8/9 is
kept), after the provider's flags and before anything is averaged, and `calcofi_ctd-derived` asserts that no
`sigma_theta_ave` includes a sensor whose sigma, temperature or salinity is flagged. Against v2026.10.19 this
touches 28 cruises and 194 casts, 2607 included, and no sigma value changes: `sigma_theta_1` gains a flag on
4,994 values (419 at depths published in `obs`) and `sigma_theta_2` on 5,788 (not published in `obs`);
`sigma_theta_ave` changes on 10,188 one-metre bins (at most 4.27 kg/m3, in 2005-07-32NM) and disappears on 413
where both sensors are now flagged (825 changed or removed at depths published in `obs`, 24 of them removed);
the per-cast `mld_sigma_theta_002` changes on 24 casts (at most 26.2 m) and `mld_sigma_theta_0125` on 31 (at
most 59.9 m), and each vanishes on 3 casts. The largest effects outside 2607 are 2016-11-33P4, 2012-07-32I1,
2018-02-3322, 2008-01-31JD, 2005-04-32NM, 2001-01-31JD, 2005-07-32NM and 2001-07-32NM. The `climatology`
(1993-2013 baseline) moves on 336 monthly cells of `sigma_theta_ave` (at most 0.251 kg/m3), 221 of
`sigma_theta_1` (0.174), 16 of `mld_sigma_theta_002` (5.95 m) and 23 of `mld_sigma_theta_0125` (6.36 m); no
cell appears or disappears. **Consumers:** `sigma_theta_1` rows with `measurement_qual` 8 or 9 are now more
numerous, so a query that does not apply `cc_qual_ok_sql()` / `qual_ok_sql()` / `qualOkSQL()` sees values it
did not see flagged before, and a `sigma_theta_ave` anomaly on those cruises changes.

The bottle database's `sigma_theta` and `r_dynamic_height` are now described as legacy DECODR values:
computed by the bottle database's old DECODR algorithm, which does not reproduce a Sea-Bird or TEOS-10
computation from the same temperature and salinity (Ben Gire, 2026-10-16). They are kept as published
(Rasmus Swalethorp: "keep legacy, add modern, document"); no value changes. A TEOS-10 recomputation is
planned as a separate dataset.

## Eight CTD cruises from 1995–98 return: 9501JD, 9712SP and 9803SP–9812SP

These cruises had no CTD casts in any earlier release. calcofi.org listed a final (`CTDFinalQC`) zip for
each, but every one returned 404, so the ingest skipped it with only a warning, and it also skipped the
cruise's `CTDFinalDB` copy on the Shared Drive (from JRW's pre-1998 archive) as a duplicate of the web
final it never got. By 2026-10-20 calcofi.org lists only the raw zips for these cruises, so the
`CTDFinalDB` copies are read (Ben Best, 2026-10-20). `19-9712SP_CTDFinalDB` writes cast 005d at 521 m
twice, 9 s apart; that one scan is recorded in the duplicate-scan ratchet as new coverage
(`1997-12-32QU` = 1). The ingest now stops when a web final it means to read fails to download while its
Shared Drive copy is skipped, so a cruise cannot vanish this way again. Whether `CTDFinalDB` is the
record for these cruises is ctd-cast Q46, open with the CTD team.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `climatology` | 1,878,006 | partitioned |
| `cruise` | 869 |  |
| `dataset` | 20 |  |
| `dataset_taxon` | 1,940 |  |
| `fish` | 10,796 |  |
| `grid` | 225 |  |
| `grid_crosswalk` | 673 |  |
| `ichthyo_net` | 77,888 |  |
| `lookup` | 26 |  |
| `measurement_type` | 232 |  |
| `obs` | 35,358,143 | deprecated → `obs_bio`, `obs_env` (objects removed in next) |
| `obs_attribute` | 455,300 |  |
| `obs_bio` | 1,586,795 |  |
| `obs_env` | 33,771,348 | partitioned |
| `region` | 4 |  |
| `sample` | 1,467,375 |  |
| `sample_measurement` | 659,253 |  |
| `sample_spatial` | 1,996,331 |  |
| `ship` | 49 |  |
| `spatial` | 3,390 |  |
| `spatial_attribute` | 37,943 |  |
| `taxon` | 2,606 |  |
| `taxon_group` | 438 |  |
| `obs_ctd_full` | 286,148,061 | supplemental |
| `obs_mets_full` | 19,926,523 | supplemental |
| `sample_root` | 419,418 | supplemental |

**26 tables, 383,803,652 rows, 2.85 GB.**

**Datasets (20):** `calcofi_2022-edna`, `calcofi_bottle`, `calcofi_bottle-derived`, `calcofi_ctd-cast`, `calcofi_ctd-derived`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_iron`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 97 pass / 0 fail / 4 skip (consumer-contract suite, 2026-10-21T03:44:12Z).

**Software:** calcofi4db 4.28.0, calcofi4r 1.28.0.

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.10.20 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://calcofi.io/db-schema/?v=v2026.10.20

Cite the source datasets you use alongside the release:

- `calcofi_2022-edna` — Patin N, ODonnell G (2026). CalCOFI October 2022 Vertebrate eDNA. Version 1.2. Occurrence dataset. https://doi.org/10.15468/n52j6r
 · CC-BY-4.0
- `calcofi_bottle` — CalCOFI. (2023). CalCOFI Bottle Database 194903-202105. CalCOFI.org. · *license pending*
- `calcofi_bottle-derived` — CalCOFI. (2026). CalCOFI Bottle Derived Hydrographic Products (from the CalCOFI Bottle Database 194903-202105). CalCOFI.io. https://calcofi.io/workflows/ingest_calcofi_bottle-derived.html · *license pending*
- `calcofi_ctd-cast` — CalCOFI. (2023). CalCOFI CTD Cast Files. CalCOFI.org. · *license pending*
- `calcofi_ctd-derived` — CalCOFI. (2026). CalCOFI CTD Derived Hydrographic Products (from the CalCOFI CTD Cast Files). CalCOFI.io. https://calcofi.io/workflows/ingest_calcofi_ctd-derived.html · *license pending*
- `calcofi_dic` — Keeling, C.D.; Lueker, T.J.; Emanuele, G.; Dickson, A.G.; Martz, T.R.; Wolfe, W.H.; Mau, A. (2025). Discrete profile dissolved inorganic carbon, total alkalinity, water temperature and salinity measurements for CalCOFI (NCEI Accession 0301029). NOAA NCEI. https://doi.org/10.25921/3w9f-jd72 · CC-BY-4.0
- `calcofi_mets` — CalCOFI. Underway (METS) TSG/Meteorology Data. CalCOFI.org. · *license pending*
- `calcofi_phyllosoma` — CalCOFI - Scripps Institution of Oceanography and T. Koslow. 2017. Data pertaining to lobster phyllosoma, Panulirus interruptus, collection methods, locations, identification and staging (1951-2008, months of July and August) ver 4. Environmental Data Initiative. https://doi.org/10.6073/pasta/9e38121ebb26f1b59b7b39b2eff844fa · custom (https://portal.edirepository.org/nis/metadataviewer?packageid=knb-lter-cce.188.4)
- `calcofi_phytoplankton` — CalCOFI - Scripps Institution of Oceanography, California Current Ecosystem LTER, and E. Venrick. 2023. Temporal and spatial changes of the abundance and species composition of phytoplankton in the California Current from samples collected aboard CalCOFI cruises from summer 1996 through 2022. ver 4. Environmental Data Initiative. https://doi.org/10.6073/pasta/60edabfbfd85c623fce05822befaa071 · CC0-1.0 (https://creativecommons.org/publicdomain/zero/1.0/)
- `cce-lter_euphausiids` — Ohman, M.D. 2022. California Current Ecosystem Euphausiid data, Brinton and Townsend Euphausiid Database (BTEDB) ver 1. Environmental Data Initiative. https://doi.org/10.6073/pasta/4a92a0044bcd1523a4f994ece874a57d · custom (https://portal.edirepository.org/nis/metadataviewer?packageid=knb-lter-cce.313.1)
- `cce-lter_iron` — California Current Ecosystem LTER, CalCOFI - Scripps Institution of Oceanography, and K. Barbeau. 2017. Measurements of dissolved inorganic concentrations of nutrient iron and of iron limitation at selected stations and depths from CalCOFI cruises in the California Current System, Nov. 2002 - July 2004 (completed) ver 3. Environmental Data Initiative. https://doi.org/10.6073/pasta/63c4e57f87861db3acaf80d1dec103e1.
 · custom (https://portal.edirepository.org/nis/mapbrowse?packageid=knb-lter-cce.21.3)
- `cce-lter_picoplankton-bacteria` — Landry, M. (2004-2023). Picoplankton and Bacteria Abundance (CalCOFI Cruise). CCE LTER. · *license pending*
- `cce-lter_zoodb` — *citation pending* · custom (https://oceaninformatics.ucsd.edu/zoodb/)
- `cce-lter_zooscan` — *citation pending* · custom (https://oceaninformatics.ucsd.edu/zooscandb/)
- `cdfw_dungeness-crab` — Rogers-Bennett, L.; Jones, E.; Klemmedson, A. (2026). CDFW Dungeness Crab Megalopae from archived CalCOFI plankton samples (1949-2014). California Department of Fish and Wildlife, published through CalCOFI / Scripps Institution of Oceanography.
 · CC-BY-4.0
- `farallon_bird-mammal` — *citation pending* · custom (https://oceanview.pfeg.noaa.gov/CalCOFI/app/resources/docs/Data_Sharing_Agreement_FarallonInstitute.pdf)
- `sio_mesopelagic-fish` — Koslow, J. Anthony (2016). CalCOFI Trawl Data. In California Cooperative Oceanic Fisheries Investigations (CalCOFI): Acoustic and Trawl Data. UC San Diego Library Digital Collections. https://doi.org/10.6075/J0BZ64DH
 · CC-BY-4.0
- `sio_pic-zooplankton` — *citation pending* · *license pending*
- `swfsc_cufes` — *citation pending* · custom (https://coastwatch.pfeg.noaa.gov/erddap/tabledap/erdCalCOFIcufes.das)
- `swfsc_ichthyo` — NOAA Fisheries SWFSC. CalCOFI Ichthyoplankton Database. · *license pending*

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.10.20")
```
```python
con = calcofi4py.cc_get_db("v2026.10.20")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.10.20/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
