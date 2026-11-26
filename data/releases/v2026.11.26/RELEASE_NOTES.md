# CalCOFI integrated database release v2026.11.26

**Release date:** 2026-11-26 · **promoted** (`latest.txt`)

## A row's id now changes only when its own dataset changes

`obs_id`, `obs_attribute_id`, `sample_measurement_id` and `root_id` were each one running number
over a whole table, across every dataset. So when one dataset gained rows, every dataset sorted
after it was renumbered. The 17 CTD casts added to cruise 2611 in v2026.11.25 gave all 487,616
ichthyoplankton observations an `obs_id` 2,354 higher although no other column of those rows
changed, and the same happened to fifteen datasets. Because a published file is named for the
content of its rows, ids included, every dataset's `obs` file was written again at each release,
and the download zips would all have been rebuilt.

Each dataset now owns a block of numbers, listed in `metadata/id_block.csv` and never changed or
reused:

- `obs_id`, `obs_attribute_id` and `sample_measurement_id` are `id_block × 10,000,000,000 + n`,
  where `n` counts that dataset's own rows from 1 (still `BIGINT`, every value below 2^53);
- `root_id` is `id_block × 5,000,000 + n` over that dataset's own root samples (still `INTEGER`).

Within a dataset the rows are numbered in a fixed order: by time for `obs`, by cruise for the
full-resolution `obs_ctd_full` and `obs_mets_full`, then by every other column. A later cruise
therefore takes the next numbers and leaves the earlier ones alone, and rebuilding unchanged data
gives the same ids. The release stops if any id is outside its dataset's block
(`calcofi4db::check_id_blocks()`, calcofi4db 4.43.0), and the release test checks the published
files the same way.

**Consumers:** every id changes once, in this release. From here an id changes only when its own
dataset's rows change, so it is still not a permanent identifier for a row: use `sample_key` with
the measurement, taxon and depth to follow a row across releases. Ids no longer start at 1 or run
without gaps across a table, and the largest `obs_id` is no longer the row count.

## Every published output is brought up to date with each release

The download zips, Darwin Core Archives, netCDF files and staged EDI packages are built by
notebooks that sit after the release test, and a release was cut without running them:
v2026.11.18 and v2026.11.25 were both promoted with the zips still built from v2026.11.14. They
are now a step of the deploy that follows every promotion (`scripts/publish_all.sh`, called by
`scripts/deploy_consumers.sh` before calcofi.io rebuilds). Each output is named for its content,
so a dataset the release did not change is checked and left as it is, and only a changed dataset
is rebuilt and uploaded. Creating or revising a package on EDI itself stays a person's decision.

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
| `obs` | 36,024,277 | deprecated → `obs_bio`, `obs_env` (objects removed in next) |
| `obs_attribute` | 455,300 |  |
| `obs_bio` | 1,586,795 |  |
| `obs_env` | 34,437,482 | partitioned |
| `region` | 4 |  |
| `sample` | 1,467,488 |  |
| `sample_measurement` | 715,412 |  |
| `sample_spatial` | 2,296,579 |  |
| `ship` | 49 |  |
| `spatial` | 3,395 |  |
| `spatial_attribute` | 37,968 |  |
| `taxon` | 2,606 |  |
| `taxon_group` | 438 |  |
| `obs_ctd_full` | 286,046,006 | supplemental |
| `obs_mets_full` | 19,926,523 | supplemental |
| `sample_root` | 419,547 | supplemental |

**27 tables, 386,215,174 rows, 2.96 GB.**

**Datasets (20):** `calcofi_2022-edna`, `calcofi_bottle`, `calcofi_bottle-derived`, `calcofi_ctd-cast`, `calcofi_ctd-derived`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_iron`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 199 pass / 0 fail / 4 skip (consumer-contract suite, 2026-11-26T12:18:36Z).

**Software:** calcofi4db 4.43.0, calcofi4r 1.34.0.

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.11.26 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://calcofi.io/db-schema/?v=v2026.11.26

Cite the source datasets you use alongside the release:

- `calcofi_2022-edna` — Patin N, ODonnell G (2026). CalCOFI October 2022 Vertebrate eDNA. Version 1.0. Occurrence dataset. https://ipt-obis.gbif.us/resource?r=calcofi_october2022_edna&v=1.0 https://doi.org/10.15468/n52j6r
 · CC-BY-4.0
- `calcofi_bottle` — Scripps Institution of Oceanography, UC San Diego, 2026. CalCOFI Hydrographic CTD Bottle Data. https://calcofi.org/data/oceanographic-data/bottle-database/ · CC-BY-4.0
- `calcofi_bottle-derived` — CalCOFI. (2026). CalCOFI Bottle Derived Hydrographic Products (from the CalCOFI Bottle Database 194903-202105). CalCOFI.io. https://calcofi.io/workflows/ingest_calcofi_bottle-derived.html · CC-BY-4.0
- `calcofi_ctd-cast` — Scripps Institution of Oceanography, UC San Diego, 2026. CalCOFI Hydrographic CTD Cast Profile Data. https://calcofi.org/data/oceanographic-data/ctd-cast-files/ · CC-BY-4.0
- `calcofi_ctd-derived` — CalCOFI. (2026). CalCOFI CTD Derived Hydrographic Products (from the CalCOFI CTD Cast Files). CalCOFI.io. https://calcofi.io/workflows/ingest_calcofi_ctd-derived.html · CC-BY-4.0
- `calcofi_dic` — Keeling, C.D.; Lueker, T.J.; Emanuele, G.; Dickson, A.G.; Martz, T.R.; Wolfe, W.H.; Mau, A. (2025). Discrete profile dissolved inorganic carbon, total alkalinity, water temperature and salinity measurements for CalCOFI (NCEI Accession 0301029). NOAA NCEI. https://doi.org/10.25921/3w9f-jd72 · CC-BY-4.0
- `calcofi_mets` — CalCOFI. Underway (METS) TSG/Meteorology Data. CalCOFI.org. · CC-BY-4.0
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
- `farallon_bird-mammal` — Sydeman, W. J., Veit, R. R., & Hyrenbach, K. D. (2025). CalCOFI Farallon Institute Seabirds [Dataset]. Farallon Institute. NOAA ERDDAP. https://oceanview.pfeg.noaa.gov/erddap/tabledap/CAC_FI_SBAS_tr.html · CC-BY-4.0 (https://oceanview.pfeg.noaa.gov/CalCOFI/app/resources/docs/Data_Sharing_Agreement_FarallonInstitute.pdf)
- `sio_mesopelagic-fish` — Koslow, J. Anthony (2016). CalCOFI Trawl Data. In California Cooperative Oceanic Fisheries Investigations (CalCOFI): Acoustic and Trawl Data. UC San Diego Library Digital Collections. https://doi.org/10.6075/J0BZ64DH
 · CC-BY-4.0
- `sio_pic-zooplankton` — *citation pending* · *license pending*
- `swfsc_cufes` — Southwest Fisheries Science Center, 2026: Continuous Underway Fish-Egg Sampler (CUFES) Database. NOAA National Centers for Environmental Information, https://www.fisheries.noaa.gov/inport/item/20692. · CC0-1.0
- `swfsc_ichthyo` — Southwest Fisheries Science Center, 2026: CalCOFI Database. NOAA National Centers for Environmental Information, https://www.fisheries.noaa.gov/inport/item/20691. · CC0-1.0

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.11.26")
```
```python
con = calcofi4py.cc_get_db("v2026.11.26")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.11.26/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
