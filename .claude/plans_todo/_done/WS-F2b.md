# WS-F2b — sizes and early-life lengths from FishBase / SeaLifeBase, and the ladder's references (D3, F5, F7)

**Umbrella:** `.claude/plans/2026-09-11 Species faces — a silhouette, a licensed photo, a size on a familiar scale and a sourced sentence for every species page, agent-scaled.md` § F5, F7, § D3, Appendix A (the `sizes.json` contract and `size_reference.csv`). **Agent:** `ws-sonnet-high`. **Repo:** CalCOFI/CalCOFI.github.io in a worktree `~/Github/CalCOFI/.worktrees/CalCOFI.github.io-ws-f2b`, branch `ws-f2b`. **Wave 1 · ≈ 0.5 day.**

## Read first
- The umbrella's § Context (the rfishbase calls that worked: `rfishbase::species(names, fields = c("SpecCode","Species","Length","LTypeMaxM","CommonLength"))`, `rfishbase::fb_tbl("eggs")` keyed `Speccode` with `Eggdiammin`, `Eggdiammax`; `rfishbase::fb_tbl("larvae")` keyed `SpecCode` with `LhMin`, `LhMax`, `FlexLengthMin/Max`, `TransLengthMin/Max`, `LarvaeRefNo`; `rfishbase::fb_tbl("refrens")` for `RefNo → Author, Year, Title`; `server = "sealifebase"` for the invertebrates and the dolphin) and Appendix C's numbers for the cast.
- `.claude/plans/2026-09-11 species-faces-probe/cast_data.json` — the sizes the mockup showed; your output must reproduce them for the ten cast keys.
- `_data/taxa.json` (`scripts/fetch_release.sh` fetches it): `taxa[]` with `scientific_name`, `rank`, `lineage`, `taxon_key`.
- `rfishbase` downloads FishBase and SeaLifeBase as parquet on first use (hundreds of MB, cached under `~/.cache`); use `librarian::shelf(rfishbase, dplyr, jsonlite, readr, quiet = TRUE)` at the top of the script, `|>` pipes, 2-space indent.

## You own
`scripts/fetch_species_sizes.R` (new), `_data/size_reference.csv` (new). Nothing else; WS-F2a merges your `sizes.json`.

## Do
1. **`scripts/fetch_species_sizes.R`** — `Rscript scripts/fetch_species_sizes.R [--out .cache/species-media/sizes.json]`: for every `taxa[]` row at rank Species, Subspecies, Variety or Forma, look the accepted name up in FishBase when the lineage's class is a fish class (Actinopteri, Actinopterygii, Teleostei, Elasmobranchii, Holocephali, Myxini, Petromyzonti), otherwise in SeaLifeBase; when the accepted name misses, try `rfishbase::synonyms()` and the dataset names in `datasets[].sources[].name`. Write per taxon_key: `{ server, spec_code, name_matched, length_cm, length_type, common_length_cm, egg_mm: [min, max] | null, hatch_mm, flexion_mm, transformation_mm, refs: { "<RefNo>": "<Author>. <Year>. <Title>." } }` (`refs` for every RefNo used: `EggsRefNo`, `LarvaeRefNo`). One JSON, keys sorted, `null` where a field is absent — never a guessed number, never a genus-level average.
2. **`_data/size_reference.csv`** — columns `key,label,m,note,source` — the six rows of the umbrella's F7 (hair 7.0e-5 m; bongo mesh 5.05e-4; US quarter 0.02426; bongo ring 0.71; person 1.70; R/V Reuben Lasker 63.8), each `source` a URL or citation (the CalCOFI methods page for the bongo net; the US Mint coin specifications; a stated source for the mean adult height; NOAA OMAO's ship page; a stated source for hair diameter). No row without a source.
3. **Measure**: species in `taxa.json` by fish / non-fish; matched by accepted name, by synonym, unmatched; with a length; with any early-life length; the runtime. Reproduce the cast: sardine 39.5 SL / egg 1.34–2.05 / hatch 3.5–3.8 / flexion 9–14 / transformation 25–35; anchovy 24.8 SL; hake 91 TL (WoRMS) vs FishBase 83 — report FishBase's own; lanternfish 13; krill 2.2 TL; squid 19.2 ML; dolphin 260 TL.

## Gates (stop and report)
- The parquet download fails or FishBase's schema differs from the fields above (report the fields you see).
- Fewer than 60 % of fish species match — report the unmatched names; do not fuzzy-match.

## Hand back
Branch + commit; `sizes.json` (or its path) with the coverage numbers; the csv; the cast reproduction table; one *Measured* line for the umbrella.
