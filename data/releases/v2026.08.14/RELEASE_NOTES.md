# CalCOFI integrated database release v2026.08.14

**Release date:** 2026-08-14

## CDFW Dungeness crab megalopae enter the release

Held out since 2026-07-30 behind `in_release: false` while permission was open; CDFW confirmed
publication (CC BY 4.0, Laura Rogers-Bennett primary provider, CDFW citable custodian), so
`cdfw_dungeness-crab` is the 16th dataset — 310 sorted samples and a 2,011-sample sorting log,
with the sorters credited in the citation ("a record of looking, not just of finding"). Its two
staged measurement types moved into the shared registry; its 14 orphan cruises are exempted as an
inventory grain rather than allowed.

## Phytoplankton regions have real geometry, derived not invented

The four Venrick pooling regions are now polygons derived from the station-membership list
(`+proj=calcofi` places all 34 stations; convex hulls were measured and rejected), which resolves
phytoplankton Q01. Four taxa the join had missed now resolve.

## Vernacular names, dataset display metadata, and a readable promotion

- `common_name` reached the release only from a dataset's own vocabulary — 1,208 of 2,125 taxa
  (57 %) had none. WoRMS returns an unordered bag of vernaculars with no preferred flag, so names
  are chosen only when unambiguous (43 picked); *Dungeness crab* is the worked example.
- Dataset display metadata (name, short name, description, links) is authored once in each
  ingest's front-matter; `metadata/dataset.csv` is deprecated.
- Promotion (`latest.txt`) is now gated on a *readable* release: `check_release_complete()`
  requires `catalog.json`/`metadata.json`/`relationships.json`, and the pointer is read through
  the authenticated API rather than the CDN, after 2026-08-14 promoted a release with no catalog.
- The workflows index build fails on a dead or non-URL `link_data_source`; `swfsc_ichthyo` had
  pointed at a 404 for months.

**Rows:** `obs` 26.45 M → 25.62 M and `obs_ctd_full` 274.9 M → 259.3 M as the CTD archive moved
off Google Drive to local scratch and the extraction completeness check began comparing member
counts (a Drive placeholder reads as an empty file with no error). **Packages:** calcofi4db
3.15.0–3.19.0, calcofi4r 1.7.0 (a time-series gap is drawn as a gap, not a measured zero).

## Contents (generated)

| table | rows | |
|---|---:|---|
| `cruise` | 691 |  |
| `dataset` | 16 |  |
| `dataset_taxon` | 1,910 |  |
| `grid` | 218 |  |
| `lookup` | 26 |  |
| `measurement_type` | 200 |  |
| `obs` | 25,624,046 | partitioned |
| `obs_attribute` | 452,789 |  |
| `region` | 4 |  |
| `sample` | 1,466,254 |  |
| `sample_measurement` | 589,603 |  |
| `ship` | 49 |  |
| `spatial` | 13,206 |  |
| `spatial_attribute` | 148,461 |  |
| `taxon` | 2,125 |  |
| `taxon_group` | 151 |  |
| `obs_ctd_full` | 259,309,891 | supplemental |
| `obs_mets_full` | 19,927,416 | supplemental |

**18 tables, 307,537,056 rows, 2.02 GB.**

**Datasets (16):** `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 28 pass / 0 fail / 4 skip (consumer-contract suite, 2026-08-14T06:25:47Z).

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.08.14 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://calcofi.io/db-schema/?v=v2026.08.14

Cite the source datasets you use alongside the release:

- `calcofi_bottle` — CalCOFI. (2023). CalCOFI Bottle Database 194903-202105. CalCOFI.org. · *license pending*
- `calcofi_ctd-cast` — CalCOFI. (2023). CalCOFI CTD Cast Files. CalCOFI.org. · *license pending*
- `calcofi_dic` — Keeling, C.D.; Lueker, T.J.; Emanuele, G.; Dickson, A.G.; Martz, T.R.; Wolfe, W.H.; Mau, A. (2025). Discrete profile dissolved inorganic carbon, total alkalinity, water temperature and salinity measurements for CalCOFI (NCEI Accession 0301029). NOAA NCEI. https://doi.org/10.25921/3w9f-jd72 · CC BY 4.0
- `calcofi_mets` — CalCOFI. Underway (METS) TSG/Meteorology Data. CalCOFI.org. · *license pending*
- `calcofi_phyllosoma` — *citation pending* · *license pending*
- `calcofi_phytoplankton` — *citation pending* · *license pending*
- `cce-lter_euphausiids` — *citation pending* · *license pending*
- `cce-lter_picoplankton-bacteria` — Landry, M. (2004-2023). Picoplankton and Bacteria Abundance (CalCOFI Cruise). CCE LTER. · *license pending*
- `cce-lter_zoodb` — *citation pending* · *license pending*
- `cce-lter_zooscan` — *citation pending* · *license pending*
- `cdfw_dungeness-crab` — Rogers-Bennett, L.; Jones, E.; Klemmedson, A. (2026). CDFW Dungeness Crab Megalopae from archived CalCOFI plankton samples (1949-2014). California Department of Fish and Wildlife, published through CalCOFI / Scripps Institution of Oceanography.
 · CC BY 4.0
- `farallon_bird-mammal` — *citation pending* · *license pending*
- `sio_mesopelagic-fish` — Koslow, J. Anthony (2016). CalCOFI Trawl Data. In California Cooperative Oceanic Fisheries Investigations (CalCOFI): Acoustic and Trawl Data. UC San Diego Library Digital Collections. https://doi.org/10.6075/J0BZ64DH
 · CC BY 4.0
- `sio_pic-zooplankton` — *citation pending* · *license pending*
- `swfsc_cufes` — *citation pending* · *license pending*
- `swfsc_ichthyo` — NOAA Fisheries SWFSC. CalCOFI Ichthyoplankton Database. · *license pending*

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.08.14")
```
```python
con = calcofi4py.cc_get_db("v2026.08.14")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.08.14/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
