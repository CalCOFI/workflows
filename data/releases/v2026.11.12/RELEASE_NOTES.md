# CalCOFI integrated database release v2026.11.12

**Release date:** 2026-11-12 · **promoted** (`latest.txt`)

## The 1 m CTD table is whole again: 22 cruises had been published with most of their casts missing

`obs_ctd_full`, the supplemental table of 1 m CTD bins, was published short in v2026.11.05 and
v2026.11.09: for 22 cruises between 2015-04 and 2026-04 it carried 2 to 68 casts where there are
92 to 232 (`2015-11-32OC`: 2 of 140), so 47,189,291 of its 287,281,956 rows were missing. The
release had built the table whole; the loss happened on the way to the bucket. DuckDB 2.0.0 starts
another file for a partition once more than 100 are open, so 24 of the table's 143 cruises were
written as two or three files. Each was given the cruise's one path, the uploads overwrote each
other and the last, smallest file stayed. The catalog listed each of those 24 paths once per file
(169 objects for 143 cruises), so the two whole cruises among them, `1994-03-31JD` and
`2005-11-32NM`, were read twice. v2026.11.04 has the same repeated listings, but its objects are
whole: every row is there, and those 24 cruises' rows are read two or three times. v2026.10.30 and
earlier are right. No other table was affected (`obs_env` has 96 partitions, below the limit), and
nothing upstream was lost: the staged ingest output matches the release export row for row.

This release publishes one object per cruise again (calcofi4db 4.38.0: the export keeps every
partition open for the write and stops unless each holds exactly one file; `release_objects()`
and `freeze_plan()` stop on a second file or a repeated path). It replaces the 22 short objects in
the shared store, where their content, and so their path, is unchanged: the upload step now
re-uploads an object the plan would reuse when its size in the bucket differs from what the
previous catalog recorded. Because v2026.11.05 and v2026.11.09 point at the same objects, they now
read whole cruises too, though their catalogs still list those 24 paths two or three times.

`test_release.qmd` now checks every table in the catalog, supplemental ones included, before
promotion: the paths are unique, a partitioned table has one object per partition value, and the
rows in the published objects' parquet footers equal the catalog's `rows`
(`check_release_objects()`). Against v2026.11.09 as published it fails those three checks for
`obs_ctd_full` and passes the other 75. The CTD derived-products ingest applies the same check
before it falls back to the published table.

**Consumers:** read `obs_ctd_full` from this release, or pass `refresh = TRUE` to
`calcofi4r::cc_get_db()` if you opened v2026.11.05 or v2026.11.09 with `supplemental = TRUE`: the
cached connection holds the repeated file list. calcofi4r, calcofi4py and db-query now drop a
repeated path when they read a catalog.

## `sample_root` says which stage its data are at, so an app can label a preliminary cruise

`sample_root` gains `data_stage` as its last column (calcofi4db 4.37.0, `build_sample_root()`):
the root sample's own `sample.data_stage`, NULL where the dataset records none. Until now the
stage was only on `sample`, which the Explorer does not load, so it drew the preliminary fall
cruise with no label while the CTD transects app marked it. The release notebook's column-order
check accepts `hex7` followed by `data_stage`.

**Consumers:** additive. A reader that selects `sample_root` columns by name is unaffected; one
that relies on `hex7` being the table's last column should select by name instead.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `climatology` | 1,921,596 | partitioned |
| `cruise` | 869 |  |
| `dataset` | 20 |  |
| `dataset_taxon` | 1,940 |  |
| `fish` | 10,796 |  |
| `grid` | 225 |  |
| `grid_crosswalk` | 673 |  |
| `ichthyo_net` | 77,888 |  |
| `lookup` | 26 |  |
| `measurement_type` | 298 |  |
| `obs` | 36,096,173 | deprecated → `obs_bio`, `obs_env` (objects removed in next) |
| `obs_attribute` | 455,300 |  |
| `obs_bio` | 1,586,795 |  |
| `obs_env` | 34,509,378 | partitioned |
| `region` | 4 |  |
| `sample` | 1,467,430 |  |
| `sample_measurement` | 715,139 |  |
| `sample_spatial` | 2,296,225 |  |
| `ship` | 49 |  |
| `spatial` | 3,395 |  |
| `spatial_attribute` | 37,968 |  |
| `taxon` | 2,606 |  |
| `taxon_group` | 438 |  |
| `obs_ctd_full` | 287,281,956 | supplemental |
| `obs_mets_full` | 19,926,523 | supplemental |
| `sample_root` | 419,489 | supplemental |

**26 tables, 386,813,199 rows, 2.89 GB.**

**Datasets (20):** `calcofi_2022-edna`, `calcofi_bottle`, `calcofi_bottle-derived`, `calcofi_ctd-cast`, `calcofi_ctd-derived`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_iron`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 184 pass / 0 fail / 4 skip (consumer-contract suite, 2026-11-13T06:01:18Z).

**Software:** calcofi4db 4.38.0, calcofi4r 1.31.1.

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.11.12 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://calcofi.io/db-schema/?v=v2026.11.12

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
con <- calcofi4r::cc_get_db(version = "v2026.11.12")
```
```python
con = calcofi4py.cc_get_db("v2026.11.12")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.11.12/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
