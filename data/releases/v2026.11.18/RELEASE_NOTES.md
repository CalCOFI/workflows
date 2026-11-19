# CalCOFI integrated database release v2026.11.18

**Release date:** 2026-11-18 · **promoted** (`latest.txt`)

## Fall cruise 2611 grows from 36 to 53 casts: lines 83.3 and 80, without three Seabird-derived series on the new casts

The CalCOFI technicians re-issued `20-2611_CTDCast.zip` on 2026-11-18 (Ben Gire) with the
preliminary bottle-corrected casts 1–53, 31 October to 10 November. The 17 new casts (37–53, 7–10
November) finish line 83.3 offshore to station 90 and inshore to 39.4, run line 80 from station
100 to 51, and add 81.8 46.9 and 81.7 43.5. Cruise `2026-11-33P4` goes from 80,945 to 113,983
headline observations (`obs_env`, 37 measurement types) and from 1,133,895 to 1,614,109 in
`obs_ctd_full`. `calcofi_ctd-derived` gains the same casts' `sigma_theta_ave`, `spiciness0` and
`buoyancy_n2` (7,996 to 11,473 rows for the cruise). The tier is still `preliminary_with_bottle`,
with no nutrients yet.

**Left out on casts 37–53, at the provider's request.** For these casts the ship's Seabird
processing mangled several column names, so the file carries no `dynamic_height`,
`potential_temperature_2` or `specific_volume_anomaly`. Ben Gire advised against publishing until
a corrected file is posted, and Rasmus Swalethorp asked that the cruise be ingested with these
components left out in the meantime. The release carries none of the three on casts 37–53 and
fills nothing in for them. The derived values the file does carry for those casts were checked
against TEOS-10 from the casts' own temperature, salinity and pressure. On all 53 casts,
`potential_temperature_1` agrees to within 0.0003 °C and `sigma_theta_1` to within 0.012 kg/m³,
and the oxygen saturations match the sensor oxygen. They ship as published. The corrected file
will be ingested the same way when the technicians post it.

The re-issue also refits the corrections on casts 1–36 over more bottles. Corrected salinity
moves by at most 0.0018, the averaged station-corrected oxygen by at most 0.015 mL/L
(0.68 µmol/kg), and the cruise-corrected chlorophyll estimate by up to 0.027 µg/L. No flag
changes. As before, dynamic height stays downcast only for this cruise, because it is blank on
every upcast in the source.

No other cruise changed in `obs_env` or `calcofi_ctd-derived`: every other cruise × measurement
type has the same row count, sum and flags as v2026.11.14. In `obs_ctd_full`, one 1 m bin of
cruise 2006-04 drops out (cast `0604_014u`, 403 m), in five station-corrected series (oxygen,
and the nitrate estimate). The source writes that bin twice, and only one copy carries those
series. The ingest's de-duplication cannot tell the copies apart, so which one survives can
differ between runs (workflows#278).

## Published files are content-addressed, as the release's tables are

No table changes. The four publishers (download zips, CF netCDF, EDI staging, Darwin Core
archives) now store each file once per distinct content, as the release stores its Parquet:
identity is a `content_hash` over the dataset's rows, its metadata record and a pinned format
version (calcofi4db 4.41.0, `CC_PUBLISH_FORMAT`), the path carries it
(`…/{dataset_key}/{content_hash[1:24]}/`), and a file names the release its content first
appeared in (`since`). A release that leaves a dataset alone only lists the existing file;
nothing is re-uploaded or deleted. Bucket staging for EDI and OBIS is now opt-in
(`CALCOFI_PUBLISH_EDI_STAGE`, `CALCOFI_PUBLISH_DWCA`), like the zip and netCDF uploads.

## Download bundles: every dataset as zips a researcher can open

No table changes. A new publisher, `publish_to-zip.qmd`, writes for every dataset one zip per
format (CSV for every dataset, an Excel workbook where every table fits an Excel sheet,
Parquet), each holding the dataset's own rows of every table it needs to be used alone, with
`site_key`, `line`, `station`, `scientific_name`, `common_name` and `units` beside their keys,
and a README, the dataset's and the release's citation, its licence and a column dictionary. They
stage at `gs://calcofi-db/publish/zip/{dataset_key}/` with a manifest beside them, and from this
release on `datasets.json` carries each as a `kind = "bundle"` distribution (calcofi4db 4.40.0):
the newest built, since the publisher runs after the release.

## `sio_cetacean-sightings` (held): the third preview reads the lab's final 2004–2025 files

No public table changes. The Scripps Whale Acoustics Lab published its final QA/QC'd visual-survey
product on 2026-11-13 (Michaela Alksne, a private GitHub repository the ingest reads at a pinned
commit through `libs/download_sio_cetacean_sightings.R`): 5,090 on-effort sightings on 3,241
segments over 78 cruises, with the lab's code list, data dictionary and field manual. The signed
angle off the bow (`sight_brng`) and the perpendicular distances are now computed for every year,
so 4,996 sightings are placed at the animal (4,150 in the second preview, where 2022–2025 stayed at
the ship; Q30). Behaviour is published from the lab's codebook as `obs_attribute` `behavior`
labels (Q03), the sea otter (`EL`) is keyed, and nineteen provider questions are settled by the
files and Michaela's note of 2026-11-09. The held dataset's NULL-`cruise_key` ratchet goes from 66 to 64 segments (no segment is
misdated any more). The private candidate (root `ducklake-preview-sightings`) is rebuilt from
these files with the Farallon cut, under a new preview token.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `climatology` | 1,992,777 | partitioned |
| `cruise` | 869 |  |
| `dataset` | 20 |  |
| `dataset_taxon` | 1,940 |  |
| `fish` | 10,796 |  |
| `grid` | 225 |  |
| `grid_crosswalk` | 673 |  |
| `ichthyo_net` | 77,888 |  |
| `isopycnal` | 709,787 |  |
| `lookup` | 26 |  |
| `measurement_type` | 304 |  |
| `obs` | 36,021,923 | deprecated → `obs_bio`, `obs_env` (objects removed in next) |
| `obs_attribute` | 455,300 |  |
| `obs_bio` | 1,586,795 |  |
| `obs_env` | 34,435,128 | partitioned |
| `region` | 4 |  |
| `sample` | 1,467,488 |  |
| `sample_measurement` | 715,412 |  |
| `sample_spatial` | 2,296,579 |  |
| `ship` | 49 |  |
| `spatial` | 3,395 |  |
| `spatial_attribute` | 37,968 |  |
| `taxon` | 2,606 |  |
| `taxon_group` | 438 |  |
| `obs_ctd_full` | 286,013,565 | supplemental |
| `obs_mets_full` | 19,926,523 | supplemental |
| `sample_root` | 419,547 | supplemental |

**27 tables, 386,178,025 rows, 2.89 GB.**

**Datasets (20):** `calcofi_2022-edna`, `calcofi_bottle`, `calcofi_bottle-derived`, `calcofi_ctd-cast`, `calcofi_ctd-derived`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_iron`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 195 pass / 0 fail / 4 skip (consumer-contract suite, 2026-11-19T03:24:25Z).

**Software:** calcofi4db 4.41.0, calcofi4r 1.34.0.

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.11.18 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://calcofi.io/db-schema/?v=v2026.11.18

Cite the source datasets you use alongside the release:

- `calcofi_2022-edna` — Patin N, ODonnell G (2026). CalCOFI October 2022 Vertebrate eDNA. Version 1.3. Occurrence dataset. https://doi.org/10.15468/n52j6r
 · CC-BY-4.0
- `calcofi_bottle` — CalCOFI. (2023). CalCOFI Bottle Database 194903-202105. CalCOFI.org. · CC-BY-4.0
- `calcofi_bottle-derived` — CalCOFI. (2026). CalCOFI Bottle Derived Hydrographic Products (from the CalCOFI Bottle Database 194903-202105). CalCOFI.io. https://calcofi.io/workflows/ingest_calcofi_bottle-derived.html · CC-BY-4.0
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
con <- calcofi4r::cc_get_db(version = "v2026.11.18")
```
```python
con = calcofi4py.cc_get_db("v2026.11.18")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.11.18/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
