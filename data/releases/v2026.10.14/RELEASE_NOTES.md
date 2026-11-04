# CalCOFI integrated database release v2026.10.14

**Release date:** 2026-10-14 · **promoted** (`latest.txt`)

## BOEM wind leases, oil and gas leases, planning areas and Chumash Heritage are areas you can filter by

Seven boundary layers come from the [Ocean Metrics gazetteer](https://oceanmetrics.io/places/) and
were map layers only: the Explorer listed them in the Area filter but greyed them out, because
`ingest_spatial.qmd` skipped them. They are now in `spatial` and `sample_spatial` like every other
layer. Each one's `places.parquet` is read at a pinned gazetteer version, its sha256 checked
(`calcofi4db::read_gazetteer_layer()`, calcofi4db 4.25.0), and the pins are kept in
`data/parquet/spatial/gazetteer_pins.csv`. All seven are at gazetteer v1.1.0 in this release.

Each layer's regions and root samples (counted in the v2026.10.14 staging build's `sample_spatial`):

| layer | gazetteer collection | regions | with samples | root samples |
|---|---|---|---|---|
| BOEM OCS Planning Areas | `boem_ocs_planning` | 4 | 4 | 293,149 |
| BOEM 11th National OCS Program | `boem_program_11_draft` | 3 | 3 | 286,942 |
| National Marine Sanctuaries | `noaa_sanctuaries` | 7 | 7 | 48,562 |
| BOEM Pacific Oil & Gas Leases | `boem_pacific_og_leases` | 30 | 30 | 1,444 |
| SoCal Aquaculture AOAs | `noaa_aoa_socal` | 10 | 8 | 713 |
| BOEM Wind Leases | `boem_wind_leases` | 5 | 5 | 554 |
| BOEM Wind Planning Areas | `boem_wind_planning_rescinded` | 235 | 33 | 45 |

- **Status travels with each region.** `spatial_attribute` carries the gazetteer's `status`,
  `status_date`, `status_source`, the source's own code `status_upstream` and the dated
  `status_history`. `spatial_layers.json` gains the layer status (`status`, `status_label`,
  `status_history`, `created`, `source_date`, `gazetteer_version`) and, for every layer, `region_status`
  (`name`, `status`, `status_date` of each region that holds samples). So the Explorer can say "BOEM
  Wind Planning Areas (rescinded 2025-07-30)" and "OCS-P 0564 Commercial - Golden State Wind LLC
  (settlement pending 2026-04-27)".
- **The California wind leases have a dated history.** It comes from BOEM's lease documents.
  - OCS-P 0561 (RWE): settlement 2026-08-04, relinquished 2026-09-03.
  - OCS-P 0564 (Golden State Wind): settlement pending since 2026-04-27.
  - OCS-P 0565 (Invenergy): settlement 2026-06-12, cancelled 2026-07-10.
  - OCS-P 0562 and 0563: active.

  The geometries are kept whatever the status. A rescinded or cancelled area stays a region you can
  filter by, with its status beside its name.
- **Only features touching the CalCOFI study area join `spatial`.** The study area is the extent of
  the station grid, 135.25°W–105.75°W and 18.4°N–49.25°N. Features are kept whole, never clipped, so
  membership stays exact. The national layers shrink: sanctuaries 47 → 7, wind planning areas
  3,325 → 235 (outlines and OCS blocks), OCS planning areas 27 → 4. Four samples outside the box lose
  a gazetteer region they touched: three 2015 CUFES underway points off SE Alaska and a 2002 ichthyo
  station off Oahu.
- **National Marine Sanctuaries now come from the gazetteer** (NOAA ONMS via MarineCadastre). This adds
  **Chumash Heritage** (designated 2024; explore#34), splits Channel Islands into its Northern and Santa
  Barbara sections, and drops the bad name "Flower Garden BanksUpdated 03/23/21". **Consumers:** the
  region names change from the short form ("Channel Islands", "Monterey Bay") to the full name
  ("Monterey Bay National Marine Sanctuary"). The Explorer widens an old short name to the regions it
  prefixes.
- **SoCal Aquaculture AOAs now come from the gazetteer.** The AOA codes stay the names (CN1-A … N2-E).
  The duplicate registry row `noaa_aoa_socal` is removed; the Explorer maps its slug to
  `noaa_aquaculture_aoas`.
- **BOEM Wind Planning Areas is a different layer from the one v2026.10.08 carried.** That one was
  BOEM's 2023 planning areas, with Humboldt and Morro Bay (793 samples in 3 areas). BOEM's current
  layer holds only the areas never leased, all rescinded on 2025-07-30. The California WEAs became
  leases OCS-P 0561–0565, so they are in BOEM Wind Leases.
- **The Pacific oil and gas leases drop four renewable leases.** BOEM's Pacific cadastral service lists
  OCS-P 0560 and 0562–0564 as `RENACV`. 0562–0564 are wind leases, in BOEM Wind Leases with their dated
  status.
- **`spatial.geojson` keeps only the gazetteer regions that hold samples**, so the national layers do
  not bloat the sidecar. The Explorer draws the full layers from the gazetteer's PMTiles.

## CTD quality code 4 means "below detection limit"

The provider defined CTD code 4 (Ben Gire, 2026-10-13): **below detection limit**, reported as 0. On the
corrected chlorophyll-a and nitrate estimates only a negative value is set to 0 and coded 4; the code
may be used on any CTD sensor series. `metadata/measurement_qual.csv` renames the code from
`set_to_zero` to `below_detection` and says so. No value changes: the zeros still count in averages,
integrated chlorophyll and anomalies. Cruises after 2107 are to be reprocessed with the same rule;
earlier cruises, the 1993–2013 baseline included, keep their negatives or gaps for now.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `climatology` | 1,828,215 | partitioned |
| `cruise` | 845 |  |
| `dataset` | 19 |  |
| `dataset_taxon` | 1,940 |  |
| `fish` | 10,796 |  |
| `grid` | 225 |  |
| `grid_crosswalk` | 673 |  |
| `lookup` | 26 |  |
| `measurement_type` | 231 |  |
| `obs` | 33,326,406 | deprecated → `obs_bio`, `obs_env` (objects removed in next) |
| `obs_attribute` | 455,300 |  |
| `obs_bio` | 1,586,795 |  |
| `obs_env` | 31,739,611 | partitioned |
| `region` | 4 |  |
| `sample` | 1,467,016 |  |
| `sample_measurement` | 658,009 |  |
| `sample_spatial` | 1,994,263 |  |
| `ship` | 49 |  |
| `spatial` | 3,390 |  |
| `spatial_attribute` | 37,943 |  |
| `taxon` | 2,606 |  |
| `taxon_group` | 438 |  |
| `obs_ctd_full` | 281,888,334 | supplemental |
| `obs_mets_full` | 19,926,523 | supplemental |
| `sample_root` | 419,050 | supplemental |

**25 tables, 375,348,707 rows, 2.75 GB.**

**Datasets (19):** `calcofi_2022-edna`, `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_ctd-derived`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_iron`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 97 pass / 0 fail / 4 skip (consumer-contract suite, 2026-10-14T14:21:34Z).

**Software:** calcofi4db 4.25.0, calcofi4r 1.27.0.

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.10.14 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://doi.org/10.5281/zenodo.23371724

Cite the source datasets you use alongside the release:

- `calcofi_2022-edna` — Patin N, ODonnell G (2026). CalCOFI October 2022 Vertebrate eDNA. Version 1.2. Occurrence dataset. https://doi.org/10.15468/n52j6r
 · CC-BY-4.0
- `calcofi_bottle` — CalCOFI. (2023). CalCOFI Bottle Database 194903-202105. CalCOFI.org. · *license pending*
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
con <- calcofi4r::cc_get_db(version = "v2026.10.14")
```
```python
con = calcofi4py.cc_get_db("v2026.10.14")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.10.14/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
