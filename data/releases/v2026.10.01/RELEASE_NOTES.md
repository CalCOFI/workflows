# CalCOFI integrated database release v2026.10.01

**Release date:** 2026-10-01 · **promoted** (`latest.txt`)

## CTD: the corrected 2607 file, provider flags on every series, cruise-corrected oxygen

**Five recent cruises regain their offshore stations.** The first 20-2607SH_CTDPrelim.zip wrote station numbers
of 100 and above with three digits, so 100/110/120 read as 000/010/020. The distance filter then
dropped every such cast as a position error: in v2026.09.11, 2026-07-3322 has 122 casts instead of
144, and lines 80, 83.3, 86.7, 90 and 93.3 stop at station 90. The provider fixed the file on
2026-09-14 (Kelsey Vogel). Only `Sta` and `Sta_ID` differ between the two files, not a single
measured value, so this release adds those 22 casts back: 11,372 rows per series, and no value
changes on any other cruise. The same truncation is in the still-current preliminary files for
**2507SR, 2511SR, 2601RL and 2604SH**, which the provider has not re-issued. The ingest repairs a
station to station + 100 only where the cast's own GPS position confirms it: within 10 km of
station + 100 and farther than that from the station as written. Applied to the old 2607 file,
that rule reproduces the provider's correction on all 56,993 rows. Every repaired cast is listed
in the ingest's report, and questions.csv Q39 asks for re-issued files. The ingest also **fails the
render** if any dropped cast still carries the signature, so a truncation cannot drop stations
quietly again. A zip
re-published under the same name also invalidates the ingest's fingerprint, its checkpoint and its
extraction now; before this, the corrected file would have read as "inputs unchanged"
(CalCOFI/workflows#104).

**Every CTD series carries the provider's own flag.** The CTD team's 2026 processing software writes
a quality code for each corrected, averaged and derived series (`SaltAve_CorrQ`, `OxAve_StaCorrQ`,
`EstChl_StaCorrQ`, `EstNO3_CruiseCorrQ`, `BATQ`, `PoT1Q`, `DynHtQ`, … 27 columns, first in the
corrected 2607 file). Each series' `measurement_qual` now comes from that column, falling back to
the sensor flag it inherited before for a file in the legacy layout, so no flag on a legacy cruise
moves. The two-sensor averages are still rebuilt by Rasmus Swalethorp's flag rule
(`combine_sensor_pair_sql()`); the provider's flag on its own average rides on ours, and a
cross-check table compares the two averages per file layout for the CTD team (#105).

**2607 casts 1–6: the faulty secondary temperature is flagged.** The provider's cruise notes say the
secondary temperature sensor was faulty on casts 1–6. It reads a median 11 °C from the primary, up to
42 °C, and nothing flagged it, so 1,775 of those casts' `temperature_ave` values averaged it in (up to
11.3 °C off). A new committed registry, `metadata/calcofi/ctd-cast/flag_overrides.csv` (one row per
cruise, cast range, direction and series, each with a reason, a source and a question), flags that
sensor 9 on those casts, together with every series the provider derives from it (secondary
salinity, sigma-theta, potential temperature and oxygen). It is applied after the provider's flags
and before any average, so `temperature_ave` there is the primary sensor alone; the ingest asserts
it. This is provisional until the CTD team flags at source (questions.csv Q37).

**`oxygen_ml_l_ave_cruise_corr`**, the cruise-corrected DO average, is new. It is built from
`Ox1_CruiseCorr` / `Ox2_CruiseCorr` by the same flag rule; the source ships no average of that
pair. It is canonical (in `obs` via `ctd_thin`) and bounded 0–15 ml/L like its station-corrected
sibling (#106).
## A new dataset: `calcofi_ctd-derived`, hydrographic products computed from the CTD casts

Rasmus Swalethorp asked for values derived from the CTD profiles beside the measured series,
to show how much upwelling, productivity and California Undercurrent there is on each cruise
(CalCOFI/workflows#98). `ingest_calcofi_ctd-derived.qmd` computes them from the full-resolution
1 m bins of `calcofi_ctd-cast` after the provider's 8/9 flags are dropped, with one tested
calcofi4db (≥ 4.16.0) function per rule. It publishes:
- **`obs`** (so `obs_env` and the `climatology`): `spiciness0` (TEOS-10 spice at 0 dbar) and
  `sigma_theta_ave` (the sensor pair combined by its flags), at the depths ctd-cast publishes;
- **`sample_measurement`**, on the ctd-cast cast:
  - mixed-layer depth by three criteria (`mld_sigma_theta_003`, `mld_sigma_theta_0125`,
    `mld_temperature_02`);
  - `chl_max_depth` / `chl_max`;
  - `chl_integrated` (0–200 m) / `chl_integrated_depth`;
- **`ctd_geostrophic`**, a new table: relative geostrophic velocity between adjacent stations of
  each line, referenced to 500 dbar, in 10 dbar bins (no anomaly: relative flow).

`preliminary_without_bottle` casts get only `mld_temperature_02`, since nothing salinity-based
applies. The defaults (10 m / Δσθ 0.03, 5 m median, 0–200 m, p_ref 500, 10 km minimum spacing,
down cast) are provisional until Rasmus answers the dataset's questions Q01–Q05. The dataset emits
no `sample`: every row keys to the ctd-cast cast, declared in `relationships_cross.csv`.

## Dataset metadata: the 16 CalOOS-sheet proposals reviewed into the record (#79, #96)

Each `dataset_meta.yml` proposal imported from the CalOOS sheet on 2026-09-05 was reviewed field by
field against its dataset (Betty Huang). What was accurate was merged, what wasn't was rejected
with a reason, and what was uncertain became a `proposed` question for the provider. The new
fields are abstracts, creators, associated parties, contacts, keywords, QC statements and
maintenance, which flow into every dataset page, citation and EML document.
- **DIC:** creators are now the seven authors of its NCEI citation, in order. The two PIs stay in
  `pi_names`.
- **Dungeness crab:** its data source is CDFW's CNRA Open Data page (Christy Juhasz, 2026-09-14).
- **`sio/pic-zooplankton`:** the proposal is rejected; it described the pending biovolume table
  (Q01).
- The proposal files are removed now that they are reviewed.

## Why each measurement matters: one cited pick, the alternatives beside it

`metadata/measurement_why.csv` now carries, for every measurement key with a face, one authored
rank-1 sentence about the health of the ocean or the California Current, each tied to a citation
whose DOI resolves, plus the alternatives a reader can open instead: a second authored line, the
GOOS Essential Ocean Variable's scientific question quoted verbatim from its specification sheet,
the Wikipedia article the page leads from, and calcofi.org's own words where a methods page states
why. The why covers the concept, not the key, so the fifteen oxygen keys share one pick and a
stand-in inherits the pick of the face it borrows, with its own reason ranked beneath it. The
BibTeX entries live in `../docs/refs/refs.bib`.

## `measurements.json` is schema 1.1: an anomaly per depth band, the face registries, `n_flagged`

The measurements catalog record gains three things, all additive — a 1.0 reader sees the record it
always saw. **`anomaly`**: for every key the release's `climatology` covers, the yearly departure
from that baseline in each depth band it is measured in (`obs_env` joined to `climatology` on
dataset_key, measurement_type, `site_key`, calendar month and 10 m bin), with a 1984–2021
least-squares trend per decade, the band's extremes, one symmetric `ymax` shared by the key's bands
and the bands that hold values but reach no baseline listed under `deeper[]` rather than dropped.
The mean is taken per cruise and then over cruises, and a year of fewer than two cruises stays in
the series but never steers a trend, an extreme or the scale. A unified key merges its series before
averaging, each series against the normal of its own `measurement_type`. **The five face
registries** `metadata/measurement_{face,chem,method,scale,why}.csv` ride on the key when they carry
a row for it; a `kind = computed` scale mark is recomputed at build from its own `how` (TEOS-10's
`gsw`) and never read as a typed number, and one this package cannot evaluate says so
(`computed_at_build: false`). **`n_flagged`** (`n_values − qual_ok_n`) is now on every series and
every key, and `observed{}` — the range a page quotes — is computed inside the declared bounds
**and** inside `qual_ok`: a provider's quality flag outranks a physical bound, so a flagged extreme
that happens to be inside the bounds is no longer advertised as the observed maximum. Measured on
v2026.09.11: 89 keys, 71 with an anomaly over 362 bands with a normal and 164 deeper bands named,
48,427 values that a provider flag keeps out of `observed{}`; the record grows 189 KB → 551 KB.

## The climatology goes to the bottom, not to 500 m

`build_climatology()`'s `depth_max_m` defaulted to 500 m — the depth the Explorer's Sections lens
draws to — and the cap travelled well beyond that lens: on v2026.09.10, 117,302 temperature,
105,689 salinity, 81,423 oxygen and 26,076 nitrate values below 500 m had no normal to depart from,
so no product could show a deep anomaly at all. The default is now no depth ceiling: the ≥ 5-cruise
rule the release already passes is the only rule that decides whether a cell is a baseline, and it
stops the table where the data thins. Measured on v2026.09.10 at `min_cruises = 5`: 714,882 →
734,410 rows (+19,528, +2.7 %), deepest bin 500 → 720 m, 8.98 → 9.27 MB of parquet. The change is
additive: no cell at or above 500 m is added, lost, or changed (the Explorer's own
`section_clim.sql` returns the identical 21,306 cells above 500 m and 533 new ones at 510–720 m),
so every existing anomaly reads exactly as before.

## Picoplankton counts move to Biology, with a taxon on every row

The CCE-LTER flow-cytometry counts are observations of organisms, so they are now `obs_bio`
rather than `obs_env` (measurement-faces plan D9; Ben, 2026-09-12). All 60,802 rows carry one
`measurement_type`, `picoplankton_abundance` (cells per ml), and the population counted moves
into `obs.taxon_key`: `worms:160572` *Synechococcus* (16,002 rows, 2004–2023) and
`worms:345515` *Prochlorococcus* (12,789), which therefore get species pages at
`/species/worms-160572/` and `/species/worms-345515/`. The flow cytometer's other two
populations are operational, not taxonomic — a size fraction and a trophic fraction — so they
keep their identity in a declared dataset-local key
(`cce-lter_picoplankton-bacteria:picoeukaryotes`, 16,009 rows; `…:het_bacteria`, 16,002), the
same mechanism ZooScan's eggs / multiples / nauplii / others use, and both are declared in
`check_taxon_ids()`'s allowlist.

Consequence for consumers: the four measurement keys `synechococcus`, `prochlorococcus`,
`picoeukaryotes` and `het_bacteria` **leave the measurements catalog** — 89 keys / 94 series on
v2026.09.11 become 85 / 90 — and `obs_env` loses those 60,802 rows (29,838,093 → 29,777,291).
Their `metadata/measurement_type.csv` rows are **not deleted**: a registry row is statused, never
removed, and they remain the vocabulary of the dataset's own
`picoplankton_bacteria_measurement` table, which is still served as a compat view carrying the
source's four column names.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `climatology` | 821,001 | partitioned |
| `cruise` | 842 |  |
| `dataset` | 17 |  |
| `dataset_taxon` | 1,921 |  |
| `grid` | 218 |  |
| `lookup` | 26 |  |
| `measurement_type` | 211 |  |
| `obs` | 33,139,449 | deprecated → `obs_bio`, `obs_env` (objects removed in next) |
| `obs_attribute` | 458,184 |  |
| `obs_bio` | 1,319,467 |  |
| `obs_env` | 31,819,982 | partitioned |
| `region` | 4 |  |
| `sample` | 1,469,239 |  |
| `sample_measurement` | 652,879 |  |
| `sample_spatial` | 929,664 |  |
| `ship` | 49 |  |
| `spatial` | 13,206 |  |
| `spatial_attribute` | 148,461 |  |
| `taxon` | 2,623 |  |
| `taxon_group` | 441 |  |
| `obs_ctd_full` | 284,379,888 | supplemental |
| `obs_mets_full` | 19,926,523 | supplemental |
| `sample_root` | 421,538 | supplemental |

**23 tables, 375,505,833 rows, 2.73 GB.**

**Datasets (17):** `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_ctd-derived`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 87 pass / 0 fail / 4 skip (consumer-contract suite, 2026-10-01T14:22:24Z).

**Software:** calcofi4db 4.17.2, calcofi4r 1.24.2.

## How to cite

> CalCOFI (2026). CalCOFI Integrated Database, release v2026.10.01 [Data set]. Scripps Institution of Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. https://calcofi.io/db-schema/?v=v2026.10.01

Cite the source datasets you use alongside the release:

- `calcofi_bottle` — CalCOFI. (2023). CalCOFI Bottle Database 194903-202105. CalCOFI.org. · *license pending*
- `calcofi_ctd-cast` — CalCOFI. (2023). CalCOFI CTD Cast Files. CalCOFI.org. · *license pending*
- `calcofi_ctd-derived` — CalCOFI. (2026). CalCOFI CTD Derived Hydrographic Products (from the CalCOFI CTD Cast Files). CalCOFI.io. https://calcofi.io/workflows/ingest_calcofi_ctd-derived.html · *license pending*
- `calcofi_dic` — Keeling, C.D.; Lueker, T.J.; Emanuele, G.; Dickson, A.G.; Martz, T.R.; Wolfe, W.H.; Mau, A. (2025). Discrete profile dissolved inorganic carbon, total alkalinity, water temperature and salinity measurements for CalCOFI (NCEI Accession 0301029). NOAA NCEI. https://doi.org/10.25921/3w9f-jd72 · CC-BY-4.0
- `calcofi_mets` — CalCOFI. Underway (METS) TSG/Meteorology Data. CalCOFI.org. · *license pending*
- `calcofi_phyllosoma` — CalCOFI - Scripps Institution of Oceanography and T. Koslow. 2017. Data pertaining to lobster phyllosoma, Panulirus interruptus, collection methods, locations, identification and staging (1951-2008, months of July and August) ver 4. Environmental Data Initiative. https://doi.org/10.6073/pasta/9e38121ebb26f1b59b7b39b2eff844fa · custom (https://portal.edirepository.org/nis/metadataviewer?packageid=knb-lter-cce.188.4)
- `calcofi_phytoplankton` — CalCOFI - Scripps Institution of Oceanography, California Current Ecosystem LTER, and E. Venrick. 2023. Temporal and spatial changes of the abundance and species composition of phytoplankton in the California Current from samples collected aboard CalCOFI cruises from summer 1996 through 2022. ver 4. Environmental Data Initiative. https://doi.org/10.6073/pasta/60edabfbfd85c623fce05822befaa071 · CC0-1.0 (https://creativecommons.org/publicdomain/zero/1.0/)
- `cce-lter_euphausiids` — Ohman, M.D. 2022. California Current Ecosystem Euphausiid data, Brinton and Townsend Euphausiid Database (BTEDB) ver 1. Environmental Data Initiative. https://doi.org/10.6073/pasta/4a92a0044bcd1523a4f994ece874a57d · custom (https://portal.edirepository.org/nis/metadataviewer?packageid=knb-lter-cce.313.1)
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
con <- calcofi4r::cc_get_db(version = "v2026.10.01")
```
```python
con = calcofi4py.cc_get_db("v2026.10.01")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.10.01/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
