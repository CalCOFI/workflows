# CalCOFI integrated database release v2026.04.02

**Release date:** 2026-04-02
*Documented with v2026.04.02 – v2026.04.08 (2026-04-02 … 2026-04-08).*

Invertebrates folded into ichthyo; spatial tables consolidated and uploaded to GCS; pipeline
optimised with VIEWs and GCS server-side copy (60+ min → ~4 min); `inverts` → `invert`,
`dic_measurement_summary` → `dic_summary`.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `boem_wind_planning` | 9,833 |  |
| `bottle` | 895,371 |  |
| `bottle_measurement` | 11,135,600 |  |
| `ca_assembly_districts` | 80 |  |
| `ca_cdfw_regions` | 7 |  |
| `ca_county_boundaries` | 58 |  |
| `ca_cowcod_conservation` | 2 |  |
| `ca_marine_protected_areas` | 155 |  |
| `ca_maritime_boundaries` | 2 |  |
| `ca_ports` | 194 |  |
| `ca_senate_districts` | 40 |  |
| `ca_swqpa` | 36 |  |
| `ca_watershed_boundaries` | 140 |  |
| `cast_condition` | 235,513 |  |
| `casts` | 35,644 |  |
| `cruise` | 691 |  |
| `ctd_cast` | 6,065,096 |  |
| `ctd_measurement` | 236,782,294 | partitioned |
| `ctd_summary` | 104,828,768 | partitioned |
| `dataset` | 5 |  |
| `dic_measurement` | 16,391 |  |
| `dic_measurement_summary` | 15,786 |  |
| `dic_sample` | 4,391 |  |
| `grid` | 218 |  |
| `ichthyo` | 830,873 |  |
| `invert_count` | 9,628 |  |
| `invert_size` | 4,574 |  |
| `lookup` | 26 |  |
| `measurement_type` | 104 |  |
| `meow_ecoregions` | 232 |  |
| `net` | 76,512 |  |
| `noaa_aquaculture_aoas` | 10 |  |
| `noaa_iea_regions` | 1 |  |
| `noaa_maritime_boundaries` | 260 |  |
| `noaa_ocean_disposal` | 2,148 |  |
| `noaa_onms_sanctuaries` | 16 |  |
| `segment` | 60,413 |  |
| `ship` | 48 |  |
| `site` | 61,104 |  |
| `species` | 1,144 |  |
| `taxa_rank` | 41 |  |
| `taxon` | 3,348 |  |
| `tow` | 75,506 |  |

**43 tables, 361,152,303 rows, 12.06 GB.**

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.04.02")
```
```python
con = calcofi4py.cc_get_db("v2026.04.02")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.04.02/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
