# parse_phytoplankton.R — flatten the Venrick CalCOFI phytoplankton workbooks
# (EDI knb-lter-cce.254.4) from their per-year cross-tab sheets into tidy long
# form: one row per (cruise, region, species_code) with an abundance value.
#
# Each year-sheet is a taxon × (cruise × region) matrix with a 2-row merged
# header: row1 = "CalCOFI YYMM" (spanning 4 columns), row2 = the 4 pooled
# regions (NE, SE, Alley, Offshore). Col 1 holds the species code; rows are taxa
# plus a trailing "SUM MISC. TAXA". Sheet names vary (CC96DATA … cc22data).

suppressMessages({library(readxl); library(dplyr); library(tidyr); library(stringr); library(purrr)})

# YY (2-digit) -> 4-digit year: 96-99 -> 19xx, 00-49 -> 20xx
yy_to_year <- function(yy) ifelse(yy >= 50L, 1900L + yy, 2000L + yy)

# parse one year-sheet to long: cruise_yymm, year, month, region, species_code, abundance
parse_phyto_sheet <- function(path, sheet) {
  raw <- suppressMessages(read_excel(path, sheet = sheet, col_names = FALSE))
  if (nrow(raw) < 3 || ncol(raw) < 2) return(NULL)

  cruise_row <- as.character(unlist(raw[1, ]))
  region_row <- as.character(unlist(raw[2, ]))

  # fill the merged cruise label rightward across its region columns
  cruise_fill <- cruise_row
  for (j in seq_along(cruise_fill))
    if (is.na(cruise_fill[j]) && j > 1) cruise_fill[j] <- cruise_fill[j - 1]

  # data columns = those with a region label in row2 (NE/SE/Alley/Offshore)
  reg_clean <- str_to_title(str_trim(region_row))
  is_data <- !is.na(reg_clean) & reg_clean %in% c("Ne", "Se", "Alley", "Offshore")
  region_norm <- recode(reg_clean, Ne = "NE", Se = "SE")
  data_cols <- which(is_data)
  if (!length(data_cols)) return(NULL)

  # cruise YYMM from "CalCOFI 9702" / typo "CalCOFO 2111" -> first 4 digits
  yymm <- str_extract(cruise_fill, "\\d{4}")

  body <- raw[-c(1, 2), , drop = FALSE]
  codes <- as.character(unlist(body[, 1]))

  map_dfr(data_cols, function(j) {
    tibble(
      cruise_yymm  = yymm[j],
      region       = region_norm[j],
      species_code = codes,
      abundance    = suppressWarnings(as.numeric(as.character(unlist(body[, j])))))
  }) |>
    filter(!is.na(cruise_yymm), !is.na(species_code), str_trim(species_code) != "") |>
    mutate(
      sheet  = sheet,
      yy     = suppressWarnings(as.integer(str_sub(cruise_yymm, 1, 2))),
      mm     = suppressWarnings(as.integer(str_sub(cruise_yymm, 3, 4))),
      year   = yy_to_year(yy),
      month  = mm) |>
    select(cruise_yymm, year, month, region, species_code, abundance, sheet)
}

# parse every sheet in every abundance workbook -> one long tibble
parse_phyto_workbooks <- function(files) {
  map_dfr(files, function(f)
    map_dfr(excel_sheets(f), function(s) parse_phyto_sheet(f, s)))
}

# species-code lookup from the Definitions workbook ("Species Codes" sheet)
read_phyto_taxa <- function(def_path) {
  suppressMessages(read_excel(def_path, sheet = "Species Codes")) |>
    rename_with(~ str_to_lower(str_replace_all(str_trim(.x), "\\s+", "_"))) |>
    rename(species_code = 1) |>
    mutate(species_code = as.character(species_code))
}
