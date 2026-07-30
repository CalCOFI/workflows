# parse the CDFW Dungeness crab megalopae workbooks
# source(here::here("libs/parse_dungeness_crab.R")) from ingest_dfw_dungeness-crab.qmd
#
# Three hand-maintained Excel workbooks, none machine-friendly. The parsing is
# committed here (rather than inline in the notebook) so it is re-runnable and
# reviewable, per the acquisition-reproducibility convention.
#
# Workbook quirks this file exists to absorb:
#  - "Dungeness Time Series" is saved with Excel's **1904 date system**
#    (`date1904="1"` in xl/workbook.xml). Serial dates read as text are four
#    years early; readxl applies the epoch correctly only when it types the cell
#    as a date, so date columns are NEVER read as text here.
#  - the sorting log's `SampleDate` lost its leading month in most rows
#    ("/5/1988"); the month survives in the separate `Month` column.
#  - the sorting log pads numbers with U+00A0 (non-breaking space).
#  - column headers carry trailing spaces.

librarian::shelf(dplyr, lubridate, purrr, readxl, stringr, tibble, quiet = T)

# strip non-breaking spaces + ordinary whitespace, then parse as double
.num <- function(x) {
  x <- str_replace_all(as.character(x), " ", " ") |> str_trim()
  x[x == ""] <- NA_character_
  suppressWarnings(as.numeric(x))
}

#' Excel day-fraction or "HH:MM" text -> seconds since midnight
#'
#' The time columns are mixed: most cells are Excel day fractions read as text
#' ("0.4145833..."), a handful were typed as strings ("21:55").
#' @param x character vector
#' @return integer seconds since midnight (NA where unparseable)
parse_daytime_sec <- function(x) {
  x   <- str_trim(str_replace_all(as.character(x), " ", " "))
  out <- rep(NA_real_, length(x))
  frac <- suppressWarnings(as.numeric(x))
  out[!is.na(frac)] <- frac[!is.na(frac)] * 86400
  hm <- str_match(x, "^(\\d{1,2}):(\\d{2})(?::(\\d{2}))?$")
  i  <- is.na(out) & !is.na(hm[, 1])
  out[i] <- as.numeric(hm[i, 2]) * 3600 + as.numeric(hm[i, 3]) * 60 +
    coalesce(as.numeric(hm[i, 4]), 0)
  as.integer(round(out))
}

#' CalCOFI line + station -> site_key ("LLL.L SSS.S")
#' @param line,station numeric
site_key_from_line_station <- function(line, station) {
  ifelse(is.na(line) | is.na(station), NA_character_,
         sprintf("%05.1f %05.1f", line, station))
}

#' Cruise label "YYMMSS" -> components
#'
#' The workbook labels cruises `YYMM` + a two-letter CalCOFI ship abbreviation
#' (e.g. `1404SH` = April 2014, Bell M. Shimada). The abbreviation is
#' `ship.ship_key` in the CalCOFI reference tables, so `cruise_key`
#' (`YYYY-MM-NODC`) is recoverable by joining on it — see the notebook.
#'
#' @param x character vector of cruise labels
#' @return tibble(cruise_orig, year, month, ship_key)
parse_cruise_label <- function(x) {
  m <- str_match(str_trim(x), "^(\\d{2})(\\d{2})([A-Z]{2})$")
  yy <- as.integer(m[, 2])
  tibble(
    cruise_orig = x,
    # workbook covers 2008-2014; two-digit years are unambiguously 20xx here
    year     = ifelse(is.na(yy), NA_integer_, 2000L + yy),
    month    = as.integer(m[, 3]),
    ship_key = m[, 4])
}

#' Split a carapace-length cell into one length per individual
#'
#' The cell holds one measurement per *Metacarcinus magister* megalopa found in
#' the sample ("6.0mm, 6.5mm, 7.0mm, 7.0mm"), so it is per-individual detail
#' rather than a sample-level scalar.
#'
#' @param x character vector, one element per sample
#' @return tibble(row_index, individual_num, carapace_length_mm)
parse_carapace_lengths <- function(x) {
  map_dfr(seq_along(x), function(i) {
    v <- x[[i]]
    if (is.na(v) || !nzchar(str_trim(v))) return(tibble())
    lens <- .num(str_extract_all(v, "\\d+(?:\\.\\d+)?")[[1]])
    lens <- lens[!is.na(lens)]
    if (!length(lens)) return(tibble())
    tibble(row_index = i, individual_num = seq_along(lens),
           carapace_length_mm = lens)
  })
}

#' Read the "Compiled Cruises" time series (Klemmedson, 2008-2014)
#'
#' One row per sorted plankton sample: aliquot sorted, sample volume, and counts
#' of Dungeness megalopae / other megalopae / Cancer zoea / other zoea, each with
#' a free-text taxonomic description. `Compiled Cruises` — not the 13 per-cruise
#' sheets — is authoritative: its 310 rows match the workbook's own "Plots"
#' summary (310 samples, 24 *M. magister* megalopae), while the per-cruise sheets
#' hold 313 and carry the counts as prose ("0 Metacarcinus magister megalopae
#' removed") rather than numbers.
#'
#' @param path path to "Dungeness Time Series - Angela Klemmedson.xlsx"
#' @return tibble, one row per sample
read_dungeness_timeseries <- function(path) {
  nm <- c("cruise_orig", "line", "station", "order_occ", "date", "time_frac",
          "aliquot", "volume_ml", "n_mega_magister", "carapace_len_txt",
          "n_mega_other", "mega_other_desc", "n_zoea_cancer", "zoea_cancer_desc",
          "n_zoea_other", "zoea_other_desc", "comments")
  # every column as text EXCEPT `date`: readxl only applies the workbook's 1904
  # epoch when it types the cell as a date, and a text read yields serials that
  # are four years early.
  ct <- c(rep("text", 4), "date", rep("text", 12))
  d  <- suppressMessages(read_excel(
    path, sheet = "Compiled Cruises", col_types = ct, .name_repair = "minimal"))
  stopifnot("unexpected column count in 'Compiled Cruises'" = ncol(d) == length(nm))
  names(d) <- nm

  d |>
    filter(!is.na(cruise_orig)) |>
    mutate(
      line      = .num(line),
      station   = .num(station),
      order_occ = as.integer(.num(order_occ)),
      date      = as.Date(date),
      time_sec  = parse_daytime_sec(time_frac),
      # fraction of the sample actually examined under the scope
      aliquot   = .num(aliquot),
      volume_ml = .num(volume_ml),
      across(starts_with("n_"), .num),
      site_key  = site_key_from_line_station(line, station),
      across(where(is.character), ~ na_if(str_trim(.x), "")))
}

#' Read the sorting-effort log (Jones, as of 2012-02-15)
#'
#' Two sheets of the master log of archived CalCOFI oblique-tow plankton samples
#' within the Dungeness range (San Francisco north): which have been examined for
#' *M. magister* megalopae and which have not. This is **effort/inventory**, not
#' counts — Jones reported finding no confirmed *M. magister* in the sorted set.
#'
#' @param path path to "Cancer Magister sorting update as of 02-15-12_EJones.xlsx"
#' @return tibble, one row per logged sample, with `sorting_status`
read_dungeness_sorting_log <- function(path) {
  sheets <- c(sorted   = "Samples that have been sorted",
              unsorted = "Unsorted samples as of 02-15-12")
  map_dfr(names(sheets), function(status) {
    d <- suppressMessages(read_excel(
      path, sheet = sheets[[status]], col_types = "text",
      .name_repair = "minimal"))
    # headers carry trailing spaces
    names(d) <- str_trim(names(d)) |> tolower() |> str_replace_all("[^a-z]+", "_")
    d |>
      filter(!is.na(expedition)) |>
      transmute(
        sorting_status  = status,
        expedition_orig = str_trim(expedition),
        line            = .num(staline),
        station         = .num(stano),
        latitude        = .num(lat),
        longitude       = .num(lon),
        month           = as.integer(.num(month)),
        sample_date_txt = str_trim(sampledate),
        time_start_sec  = parse_daytime_sec(starttime),
        time_end_sec    = parse_daytime_sec(endtime),
        max_depth_m     = .num(maxdepth),
        net             = str_trim(net),
        mesh_mm         = .num(mesh),
        tow_type        = str_trim(tow),
        preservative    = str_trim(preservative))
  }) |>
    mutate(
      date     = parse_sorting_log_date(sample_date_txt, month),
      site_key = site_key_from_line_station(line, station))
}

#' Recover a sorting-log sample date
#'
#' Most cells are text that lost the leading month ("/5/1988"); the month
#' survives in the sheet's own `Month` column, which agrees with the month of
#' every cell that *was* stored as a serial. The remainder are 1900-epoch Excel
#' serials (this workbook has no `date1904` flag).
#'
#' @param txt character vector of raw `SampleDate` cells
#' @param month integer vector from the sheet's `Month` column
#' @return Date vector
parse_sorting_log_date <- function(txt, month) {
  txt <- str_trim(str_replace_all(as.character(txt), " ", " "))
  out <- as.Date(rep(NA_real_, length(txt)), origin = "1970-01-01")

  # "/<day>/<year>" — month comes from the Month column
  dm <- str_match(txt, "^/(\\d{1,2})/(\\d{4})$")
  i  <- !is.na(dm[, 1]) & !is.na(month)
  out[i] <- make_date(as.integer(dm[i, 3]), month[i], as.integer(dm[i, 2]))

  # fully-formed "<month>/<day>/<year>"
  md <- str_match(txt, "^(\\d{1,2})/(\\d{1,2})/(\\d{4})$")
  i  <- is.na(out) & !is.na(md[, 1])
  out[i] <- make_date(as.integer(md[i, 4]), as.integer(md[i, 2]),
                      as.integer(md[i, 3]))

  # bare Excel serial (1900 epoch)
  i <- is.na(out) & str_detect(txt, "^\\d+(\\.\\d+)?$")
  out[i] <- as.Date(as.numeric(txt[i]), origin = "1899-12-30")
  out
}

#' Read the specimen-verification sheet (5 megalopae mailed for ID, 2012-05-10)
#'
#' Emily Jones mailed five archived megalopae to CDFW so the identifications
#' could be confirmed; two were verified as Dungeness. This is the taxonomic
#' evidence behind the dataset's central caveat — most "Cancer magister"
#' megalopae in the historic Reilly-era labels are probably *C. productus*.
#'
#' @param path path to "ScrippsArchivedMegalopae_sent_5_10_2012.xlsx"
#' @return tibble, one row per specimen
read_dungeness_specimens <- function(path) {
  d <- suppressMessages(read_excel(
    path, sheet = "Sheet1", skip = 1, .name_repair = "minimal"))
  names(d) <- c("date", "station_txt", "cruise_orig", "time_txt",
                "is_magister_txt", "carapace_mm_txt", "notes")
  ls <- str_match(str_trim(d$station_txt), "^([\\d.]+)\\s+([\\d.]+)$")
  d |>
    transmute(
      specimen_num       = row_number(),
      cruise_orig        = str_trim(cruise_orig),
      line               = .num(ls[, 2]),
      station            = .num(ls[, 3]),
      date               = as.Date(date),
      time_sec           = parse_daytime_sec(
        str_replace(str_trim(time_txt), "^(\\d{2})(\\d{2})$", "\\1:\\2")),
      is_magister        = str_to_lower(str_trim(is_magister_txt)) == "yes",
      carapace_length_mm = .num(carapace_mm_txt),
      notes              = str_trim(notes)) |>
    mutate(site_key = site_key_from_line_station(line, station))
}
