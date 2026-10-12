# fill_measurement_taxon_ids.R
#
# Fill blank `worms_id` / `itis_id` cells in metadata/measurement_taxon.csv for
# ONE dataset, by name, through calcofi4db::fetch_taxon_xref() (WoRMS
# wm_records_name on the cleaned name; cached in metadata/taxon_xref.csv, so a
# re-run costs no API calls). Rows that already carry an id are left alone, and
# every other dataset's rows are written back byte-for-byte.
#
# Written for stanford_hopkins-zooplankton, whose crosswalk was drafted where
# WoRMS was unreachable; run once, review the printed table, commit the CSV.
#
#   Rscript scripts/fill_measurement_taxon_ids.R stanford_hopkins-zooplankton
#
# A name WoRMS cannot match exactly stays blank and is listed at the end: fix the
# name (or add the id by hand from marinespecies.org) and re-run.

args <- commandArgs(trailingOnly = TRUE)
stopifnot("usage: Rscript scripts/fill_measurement_taxon_ids.R <dataset_key>" = length(args) == 1)
ds_key <- args[[1]]

devtools::load_all(here::here("../calcofi4db"))
librarian::shelf(dplyr, here, readr, quiet = TRUE)

path_mt   <- here("metadata/measurement_taxon.csv")
path_xref <- here("metadata/taxon_xref.csv")

# all character, so untouched rows are written back exactly as read
mt <- read_csv(path_mt, col_types = cols(.default = "c"), na = character())
need <- mt$dataset_key == ds_key & mt$worms_id == ""
cat(sum(mt$dataset_key == ds_key), "rows for", ds_key, "--", sum(need), "need a worms_id\n")
if (!any(need)) quit(save = "no")

xref <- fetch_taxon_xref(names = mt$taxon_scientific_name[need], cache_csv = path_xref) |>
  filter(query_type == "name", !is.na(worms_id)) |>
  distinct(query_value, .keep_all = TRUE)

key <- clean_taxon_name(mt$taxon_scientific_name)
hit <- match(key, xref$query_value)
fill <- need & !is.na(hit)
mt$worms_id[fill] <- as.character(xref$worms_id[hit[fill]])
mt$itis_id[fill & mt$itis_id == ""] <-
  dplyr::coalesce(as.character(xref$itis_id[hit[fill & mt$itis_id == ""]]), "")

write_csv(mt, path_mt, na = "")

mt |>
  filter(dataset_key == ds_key) |>
  mutate(accepted_name = xref$accepted_name[match(clean_taxon_name(taxon_scientific_name), xref$query_value)],
         status        = xref$status[match(clean_taxon_name(taxon_scientific_name), xref$query_value)]) |>
  select(raw_measurement_type, taxon_scientific_name, worms_id, itis_id, accepted_name, status) |>
  print(n = Inf)

still <- mt$dataset_key == ds_key & mt$worms_id == ""
if (any(still)) {
  cat("\nNO EXACT WoRMS MATCH -- fix the name or add the id by hand:\n")
  cat(paste0("  ", mt$taxon_scientific_name[still], collapse = "\n"), "\n")
}
