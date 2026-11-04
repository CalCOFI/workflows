# CalCOFI integrated database release v2026.10.30

**Release date:** 2026-10-30 · **promoted** (`latest.txt`)

## The July 2009 bottle casts join their cruise

Every release through v2026.10.21 kept the 100 bottle casts and 230 picoplankton samples of the
July 2009 cruise on a cruise of their own, `2009-07-31M4` (MCARTHUR), while SWFSC and the ichthyo,
CTD, zooscan, PIC and Farallon datasets have the same dates, 2009-07-15 to 2009-08-03, as
`2009-07-33MH` (MCARTHUR II). A join on `cruise_key` found nothing for them, and none got a
`station_uuid`. The bottle database's Cast file names the ship MCARTHUR (31M4, Cruise_ID
`2009-07-14-C-31M4`) for that cruise, and picoplankton's `studyName` carries the same id, although
the McArthur's last CalCOFI cruise was in October 2002. DIC's EXPOCODE `31M420090714` has the same
error, which is why its 51 samples from that cruise had no `cruise_key` at all. A ship rename by name
and code would also move 198502, a real McArthur cruise, so the new
`metadata/cruise_ship_corrections.csv` corrects 31M4 to 33MH for cruise 200907 only, in all three
ingests (`correct_cruise_ship()`, calcofi4db 4.31.0).
The derived `2009-07-31M4` row leaves `cruise`. The providers are asked to confirm (bottle Q19,
picoplankton Q09).

`check_cruise_key_integrity()` passed this in every release because each check looks at one key:
the derived row satisfied the foreign key, 31M4 is MCARTHUR's own code, a derived cruise's span is
its own events', and the overlap check compares cruises of one ship. Its new check 11 stops a
release with any event on a derived cruise at a station that an ichthyo site occupied within 24 h
on a different cruise. On v2026.10.21 it finds exactly these 315 samples and nothing else.

## The CTD team answered two of the zero-rule questions

CTD question Q48 (`est_nitrate_cruise_corr` is 0 on every row of 2301, 2304, 2307 and 2411) is
answered: the CTD team asks that the values stay as published until those DECODR-era cruises are
reprocessed with Kraken, which will replace them. Q49 (the contaminated July baseline of
`est_chlorophyll_a_cruise_corr`) stays open; it is on the team's cruise processing issues log, and
`est_chlorophyll_a_sta_corr` is the series to use for anomalies meanwhile. No data change.

## Every live dataset carries a standing consent question

Each of the 20 released datasets now has one question asking its PI whether CalCOFI.io may publish
it as shown, under its licence (`related_field = consent`), so a PI's yes is recorded where the
provider Sheets already sync, with who, when and the email it came in. Ten are answered: seven are
openly licensed at their public source and three have a yes by email (Rasmus Swalethorp for the
bottle- and CTD-derived products, CDFW for the Dungeness crab megalopae). Nine are open and go to
their PIs through Betty Huang and Erin Satterthwaite; the PIC net-tow dataset waits until Linsey Sala
is ready. The provider Sheets were also brought up to date with answers recorded since September. No
data change.

## A provider Sheet that is behind git can no longer undo a recorded answer

Both Sheet syncs had a blind spot: a pull took every cell that differed from git as an edit, so a
Sheet nobody had refreshed would have put old values back. On 2026-10-22 the question tabs would
have reverted the eDNA, CUFES and ichthyo answers to open, and the metadata tabs would have blanked
102 fields and restored Farallon's licence from CC-BY-4.0 to custom. Now a pull never blanks a value
git holds, never moves a question's status back, flags a different answer on a question git already
closed as a conflict rather than applying it, and treats a metadata value the sidecar held at an
earlier commit as the Sheet being behind, not an edit. A push, which rewrites whole tabs, refuses
while a tab holds an edit nobody has pulled. The one real edit waiting was the team's own triage of
ten holdings, now in `datasets.json` (`status.priority` PR or IP for ten, `status.owner` betty for
seven); every Sheet was then pushed in step with git. No data change.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `climatology` | 1,878,132 | partitioned |
| `cruise` | 868 |  |
| `dataset` | 20 |  |
| `dataset_taxon` | 1,940 |  |
| `fish` | 10,796 |  |
| `grid` | 225 |  |
| `grid_crosswalk` | 673 |  |
| `ichthyo_net` | 77,888 |  |
| `lookup` | 26 |  |
| `measurement_type` | 234 |  |
| `obs` | 35,358,143 | deprecated → `obs_bio`, `obs_env` (objects removed in next) |
| `obs_attribute` | 455,300 |  |
| `obs_bio` | 1,586,795 |  |
| `obs_env` | 33,771,348 | partitioned |
| `region` | 4 |  |
| `sample` | 1,467,376 |  |
| `sample_measurement` | 659,307 |  |
| `sample_spatial` | 1,996,331 |  |
| `ship` | 49 |  |
| `spatial` | 3,390 |  |
| `spatial_attribute` | 37,943 |  |
| `taxon` | 2,606 |  |
| `taxon_group` | 438 |  |
| `obs_ctd_full` | 286,148,056 | supplemental |
| `obs_mets_full` | 19,926,523 | supplemental |
| `sample_root` | 419,418 | supplemental |

**26 tables, 383,803,829 rows, 2.85 GB.**

**Datasets (20):** `calcofi_2022-edna`, `calcofi_bottle`, `calcofi_bottle-derived`, `calcofi_ctd-cast`, `calcofi_ctd-derived`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_iron`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 97 pass / 0 fail / 4 skip (consumer-contract suite, 2026-10-31T01:16:27Z).

**Software:** calcofi4db 4.31.0, calcofi4r 1.28.1.

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.10.30 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://doi.org/10.5281/zenodo.23833029

Cite the source datasets you use alongside the release:

- `calcofi_2022-edna` — Patin N, ODonnell G (2026). CalCOFI October 2022 Vertebrate eDNA. Version 1.3. Occurrence dataset. https://doi.org/10.15468/n52j6r
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
- `farallon_bird-mammal` — *citation pending* · CC-BY-4.0 (https://oceanview.pfeg.noaa.gov/CalCOFI/app/resources/docs/Data_Sharing_Agreement_FarallonInstitute.pdf)
- `sio_mesopelagic-fish` — Koslow, J. Anthony (2016). CalCOFI Trawl Data. In California Cooperative Oceanic Fisheries Investigations (CalCOFI): Acoustic and Trawl Data. UC San Diego Library Digital Collections. https://doi.org/10.6075/J0BZ64DH
 · CC-BY-4.0
- `sio_pic-zooplankton` — *citation pending* · *license pending*
- `swfsc_cufes` — *citation pending* · custom (https://coastwatch.pfeg.noaa.gov/erddap/tabledap/erdCalCOFIcufes.das)
- `swfsc_ichthyo` — NOAA Fisheries SWFSC. CalCOFI Ichthyoplankton Database. · *license pending*

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.10.30")
```
```python
con = calcofi4py.cc_get_db("v2026.10.30")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.10.30/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
