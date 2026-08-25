# CalCOFI integrated database release v2026.08.08

**Release date:** 2026-08-08

## Declared bounds are enforced, and 31k impossible values leave

`valid_min`/`valid_max` in `metadata/measurement_type.csv` had been emitted as netCDF attributes
and shown on the schema site for months while nothing compared a value to them. v2026.08.07
shipped ~31k impossible CTD values (pH to −10, `oxygen_ml_l_1` to −79.5, `temperature_ave` to
−47.6) — the fallout of METS erasing curated bounds from the shared registry on its write-back.
`check_measurement_bounds()` now runs per dataset at ingest and across `obs` *and* the
supplemental tables at release; `out_of_range` fails the release, `undeclared` is ratcheted
(73 → 30 of 98 (dataset, type) pairs declared a bound at this release). Enforcement is a separate
`drop_out_of_bounds()` so a bound must be agreed before it deletes.

## Two-sensor averages are repaired, not averaged with −99

`TempAve` was averaged with the −99 missing marker when one sensor failed (Q21, cruise 2607SH);
each sensor is validated individually and the repair generalised to every two-sensor average.
Q22 records the surface-soak artifact.

**Rows:** `obs` 26.27 M → 25.39 M, `obs_ctd_full` 274.9 M → 261.1 M (the impossible values).
**Packages:** calcofi4db 3.10.0 (`declare_measurement_bounds()`), 3.11.0 (no directory outputs).

## Contents (generated)

| table | rows | |
|---|---:|---|
| `cruise` | 691 |  |
| `dataset` | 15 |  |
| `dataset_taxon` | 1,907 |  |
| `grid` | 218 |  |
| `lookup` | 26 |  |
| `measurement_type` | 198 |  |
| `obs` | 25,392,376 | partitioned |
| `obs_attribute` | 452,682 |  |
| `region` | 4 |  |
| `sample` | 1,465,189 |  |
| `sample_measurement` | 588,986 |  |
| `ship` | 49 |  |
| `spatial` | 13,206 |  |
| `spatial_attribute` | 148,461 |  |
| `taxon` | 2,121 |  |
| `taxon_group` | 154 |  |
| `obs_ctd_full` | 261,129,086 | supplemental |
| `obs_mets_full` | 19,927,469 | supplemental |

**18 tables, 309,122,838 rows, 2.04 GB.**

**Datasets (15):** `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 28 pass / 0 fail / 4 skip (consumer-contract suite, 2026-08-08T21:44:49Z).

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.08.08")
```
```python
con = calcofi4py.cc_get_db("v2026.08.08")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.08.08/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
