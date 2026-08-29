# seed metadata/measurement_type.csv's `category` and `variable` (explorer UI plan D14) — through
# calcofi4db::declare_measurement_fields(), never a bare write_csv. `category` for the env types follows
# the rule db-viz-station used for years (contentKeywordGroup, ported verbatim: it has paid for its false
# positives) so the first fill matches what people already see, and is then a reviewable registry; the
# bio types take their dataset's category (the ingest's `calcofi.dataset_meta.category`). `variable` is
# the bottle/CTD crosswalk the explorer carried in src/variables.ts. Idempotent; re-run after adding types.
#   Rscript scripts/declare_measurement_fields.R
suppressPackageStartupMessages({ devtools::load_all(here::here("../calcofi4db"), quiet = TRUE); library(dplyr) })
path <- here::here("metadata/measurement_type.csv")
cats <- readr::read_csv(here::here("metadata/category.csv"), show_col_types = FALSE)
mt   <- read_measurement_type(path)
env_cat <- function(n) {
  n <- tolower(n)
  if (n == "sw_ph") return("Carbonate System")
  if (startsWith(n, "tsg")) return("Physical Oceanography")
  if (n %in% c("chl_fluor", "par_surf", "pred_chl")) return("Productivity & Pigments")
  if (n == "pred_sal_psu") return("Physical Oceanography")
  if (n == "ph" || startsWith(n, "ph ") || startsWith(n, "ph_") || grepl("ph replicate", n, fixed = TRUE)) return("Carbonate System")
  if (any(sapply(c("alkalinity", "dissolved inorganic carbon", "carbonate", "pco2"), grepl, n, fixed = TRUE)) || n == "dic" || startsWith(n, "dic_") || startsWith(n, "dic ")) return("Carbonate System")
  if (n == "isus_v") return("Nutrients & Chemistry")
  if (any(sapply(c("phosphate", "silicate", "nitrate", "nitrite", "ammoni"), grepl, n, fixed = TRUE))) return("Nutrients & Chemistry")
  if (any(sapply(c("chlorophyll", "phaeopigment", "c14", "productivity", "pigment", "fluorescence", "light_pct"), grepl, n, fixed = TRUE)) || n %in% c("par", "spar") || startsWith(n, "par ") || startsWith(n, "spar ")) return("Productivity & Pigments")
  if (any(sapply(c("wind", "wave", "weather", "cloud", "visibility", "bulb", "atmospheric", "barometric", "secchi", "forel"), grepl, n, fixed = TRUE)) || n == "water_color") return("Meteorology & Sea State")
  if (any(sapply(c("temperature", "salinity", "density", "sigma", "oxygen", "o2", "pressure", "depth", "dynamic height"), grepl, n, fixed = TRUE))) return("Physical Oceanography")
  NA_character_
}
# which datasets emit each type, and their categories, from the ingest YAML (the authoritative dataset metadata)
ds <- ingest_yaml_to_dataset_df(read_ingest_yaml(here::here())) |> mutate(dataset_key = paste(provider, dataset, sep = "_")) |> select(dataset_key, ds_category = category)
src <- mt |> select(measurement_type, `_source_datasets`) |> tidyr::separate_longer_delim(`_source_datasets`, ";") |>
  rename(dataset_key = `_source_datasets`) |> mutate(dataset_key = trimws(dataset_key)) |> left_join(ds, by = "dataset_key")
ds_cat <- src |> filter(!is.na(ds_category)) |> group_by(measurement_type) |> summarise(ds_category = names(sort(table(ds_category), decreasing = TRUE))[1], .groups = "drop")
env_ds <- c("calcofi_bottle", "calcofi_ctd-cast", "calcofi_dic", "calcofi_mets")
realm <- src |> group_by(measurement_type) |> summarise(env = any(dataset_key %in% env_ds), .groups = "drop")
fields <- mt |> select(measurement_type, description) |> left_join(realm, by = "measurement_type") |> left_join(ds_cat, by = "measurement_type") |>
  rowwise() |> mutate(category = if (isTRUE(env)) coalesce(env_cat(measurement_type), env_cat(coalesce(description, "")), "Physical Oceanography") else ds_category) |> ungroup() |>
  select(measurement_type, category)
# the crosswalk src/variables.ts carried (the CTD's `btl_*` are its own bottle samples and stay separate)
uni <- tibble::tribble(~measurement_type, ~variable,
  "temperature", "temperature", "temperature_ave", "temperature",
  "salinity", "salinity", "salinity_ave_corr", "salinity",
  "oxygen_ml_l", "oxygen_ml_l", "oxygen_ml_l_ave_sta_corr", "oxygen_ml_l",
  "oxygen_umol_kg", "oxygen_umol_kg", "oxygen_umol_kg_ave_sta_corr", "oxygen_umol_kg",
  "sigma_theta", "sigma_theta", "sigma_theta_1", "sigma_theta")
fields <- fields |> left_join(uni, by = "measurement_type") |> filter(!is.na(category) | !is.na(variable))
d <- declare_measurement_fields(fields, path, categories = cats$category)
cat("\ncategory by type:\n"); print(count(d, category), n = 20)
cat("\nvariable crosswalk:\n"); print(d |> filter(!is.na(variable)) |> select(measurement_type, variable), n = 20)
