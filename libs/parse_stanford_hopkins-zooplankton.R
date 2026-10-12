# parse_stanford_hopkins-zooplankton.R
#
# Parse the FromThePage double transcriptions of the Hopkins Marine Station
# CalCOFI zooplankton log sheets (1955-1963; Whitmire 2022,
# doi:10.25740/nt620vn7810) into long tables for
# ingest_stanford_hopkins-zooplankton.qmd. Sourced by that notebook; kept here so
# the parsing is reviewable and re-runnable on its own:
#
#   source("libs/parse_stanford_hopkins-zooplankton.R")
#   z <- tidy_hopkins_zoopl("~/My Drive/.../stanford/hopkins-zooplankton/calcofi-zoopl-spreadsheets")
#
# Each source CSV row is one log sheet (one date, six stations). Each sheet was
# transcribed twice (`_1`, `_2`), independently. tidy_hopkins_zoopl():
#   1. reads both transcriptions and pivots every sheet to
#      date x station x item (wet settled volume or one of 24 taxa + 2 write-ins);
#   2. pairs the two transcriptions by page position and keeps a consensus value
#      only where they agree (or only one transcribed the cell);
#   3. normalizes text values ("trace", "<1", "no haul", ...) and assigns a unit:
#      `ml` (wet volume), `percent_volume` (> 5), or `unit_unclear` (whole numbers
#      1-5, which the log sheet allows to be either a count or a percent: Q01).
#
# Returns a list:
#   sample  one row per sheet x station (sampled?, wet volume, coordinates)
#   obs     one row per non-blank taxon cell (value, unit, agreement, raw text)
#   check   cells/sheets to check against the scans (values or dates differ)
#   notes   transcriber notes per sheet (e.g. "line 4/3 is No. not %")

# stations: README "Geographic location of data collection" ----
hopkins_stations <- tibble::tribble(
  ~station, ~latitude, ~longitude, ~cast_depth_m,
  1L, 36.625,   -121.895,  33,
  2L, 36.68667, -121.955,  53,
  3L, 36.77,    -122.0167, 53,
  4L, 36.86,    -122.0017, 53,
  5L, 36.935,   -121.9867, 18,
  6L, 36.87,    -121.92,   53)

# read one transcription file and pivot to long ----
read_hopkins_zoopl_sheet <- function(path) {
  d <- readr::read_csv(
    path, col_types = readr::cols(.default = "c"),
    locale = readr::locale(encoding = "latin1"),
    name_repair = "minimal", show_col_types = FALSE)
  nm <- names(d)

  # item blocks: a header "(text)" column followed by station 1..6 "(text)"
  # columns at offsets +2, +4, ... +12; the two "(blank)" columns after them
  # are the sheet's sum columns and are skipped (derived, not observed)
  i_hdr <- which(
    stringr::str_detect(nm, "^(Wet settled volume \\(mL\\)|\\d+ .+|25|bottom) \\(text\\)$"))
  stopifnot(length(i_hdr) == 27)  # wet volume + 24 taxa + row 25 + bottom

  meta <- tibble::tibble(
    file          = basename(path),
    year          = as.integer(stringr::str_extract(basename(path), "\\d{4}")),
    transcription = as.integer(stringr::str_match(basename(path), "_(\\d)\\.csv$")[, 2]),
    page_position = as.integer(d[["Page Position"]]),
    page_url      = d[["Page URL"]],
    page_status   = d[["Page Status"]],
    date_text     = d[["Date (text)"]],
    notes         = d[["NOTES, MISCELLANEOUS (text)"]])

  purrr::map_dfr(seq_along(i_hdr), function(k) {
    i     <- i_hdr[k]
    label <- stringr::str_remove(nm[i], " \\(text\\)$")
    purrr::map_dfr(1:6, function(s) {
      dplyr::mutate(
        meta,
        item_seq   = k - 1L,  # 0 = wet volume, 1-24 log-sheet rows, 25, 26 = bottom
        item_label = label,
        write_in   = if (label %in% c("25", "bottom")) d[[i]] else NA_character_,
        station    = s,
        value_raw  = d[[i + 2L * s]])
    })
  })
}

# normalize values ----
roman <- c(I = 1, II = 2, III = 3, IV = 4, V = 5, VI = 6, VII = 7,
           VIII = 8, IX = 9, X = 10, XI = 11, XII = 12)

# the sheets write dates day-first with a Roman-numeral month ("10-II-55");
# transcribers retyped some as "4/2/55" (day-first) and others as "2/7/61"
# (US month-first). `swap = TRUE` reads a slash date month-first.
parse_hopkins_date <- function(x, swap = FALSE) {
  x <- stringr::str_to_upper(stringr::str_trim(x))
  slash <- stringr::str_detect(x, "/")
  x <- stringr::str_remove_all(x, "\\[|\\]|\\(.*\\)")       # "2[0]-II-61", "(55 ?)"
  x <- stringr::str_replace_all(x, "[\\s./=]+", "-")         # one separator
  m <- stringr::str_match(x, "^(\\d{1,2})-([IVX]+|\\d{1,2})-(\\d{2}|\\d{4})-?$")
  a  <- m[, 2]; b <- m[, 3]
  if (swap) { tmp <- ifelse(slash, b, a); b <- ifelse(slash, a, b); a <- tmp }
  dd <- suppressWarnings(as.integer(a))
  mm <- suppressWarnings(ifelse(stringr::str_detect(b, "^\\d"), as.integer(b), roman[b]))
  yy <- as.integer(m[, 4]); yy <- ifelse(yy < 100, 1900L + yy, yy)
  ok <- !is.na(dd) & !is.na(mm) & !is.na(yy) & mm %in% 1:12 & dd %in% 1:31
  out <- rep(as.Date(NA), length(x))
  out[ok] <- as.Date(sprintf("%04d-%02d-%02d", yy[ok], mm[ok], dd[ok]), optional = TRUE)
  out
}

norm_hopkins_value <- function(x) {
  x <- stringr::str_to_lower(stringr::str_squish(x))
  x <- stringr::str_replace_all(x, "&amp;lt;|&lt;", "<")
  x <- stringr::str_remove(x, "%$")
  dplyr::case_when(
    is.na(x) | x == ""                                   ~ NA_character_,
    stringr::str_detect(x, "^(0-)?(less than ?1|<1)$")   ~ "<1",
    x == "trace"                                         ~ "trace",
    stringr::str_detect(x, "^-+\\*?$")                   ~ "-",
    stringr::str_detect(x, "^no (sample|haul)")          ~ "no_sample",
    x == "fouled"                                        ~ "fouled",
    TRUE                                                 ~ stringr::str_remove_all(x, " "))
}

tidy_hopkins_zoopl <- function(dir_src) {
  files <- list.files(dir_src, "^zooplankton-data-sheets-\\d{4}_[12]\\.csv$",
                      full.names = TRUE, recursive = TRUE)
  files <- files[!grepl("__MACOSX", files)]   # the zip's macOS resource forks
  stopifnot(length(files) == 18)
  d_long <- purrr::map_dfr(files, read_hopkins_zoopl_sheet) |>
    dplyr::filter(page_status != "Blank Page" | is.na(page_status))

  d_long <- d_long |>
    dplyr::mutate(
      date      = parse_hopkins_date(date_text),
      date_us   = parse_hopkins_date(date_text, swap = TRUE),
      date_roman = stringr::str_detect(stringr::str_to_upper(dplyr::coalesce(date_text, "")), "[IVX]"),
      value_txt = norm_hopkins_value(value_raw))

  # pair the two transcriptions ----
  key <- c("year", "page_position", "item_seq", "station")
  d_pair <- dplyr::full_join(
    d_long |> dplyr::filter(transcription == 1),
    d_long |> dplyr::filter(transcription == 2) |>
      dplyr::select(dplyr::all_of(key), date_2 = date, date_us_2 = date_us,
                    date_roman_2 = date_roman, date_text_2 = date_text,
                    page_url_2 = page_url, write_in_2 = write_in,
                    value_raw_2 = value_raw, value_txt_2 = value_txt),
    by = key) |>
    dplyr::rename(value_raw_1 = value_raw, value_txt_1 = value_txt,
                  date_1 = date, date_us_1 = date_us, date_roman_1 = date_roman,
                  page_url_1 = page_url, write_in_1 = write_in) |>
    dplyr::mutate(
      # trust the Roman-numeral form (as on the sheet); else accept a slash date
      # read either way if it then matches the other transcription
      date = dplyr::case_when(
        date_roman_1 & !is.na(date_1)                              ~ date_1,
        date_roman_2 & !is.na(date_2)                              ~ date_2,
        !is.na(date_1) & (date_1 %in% date_2 | date_1 %in% date_us_2) ~ date_1,
        !is.na(date_us_1) & (date_us_1 %in% date_2)                ~ date_us_1,
        TRUE ~ dplyr::coalesce(date_1, date_2)),
      date_agree = (!is.na(date_1) & (date_1 == date) | (!is.na(date_us_1) & date_us_1 == date)) &
                   (!is.na(date_2) & (date_2 == date) | (!is.na(date_us_2) & date_us_2 == date)),
      date_flag = dplyr::case_when(
        is.na(date)                                   ~ "date_unparsed",
        !is.na(date_text) & !is.na(date_text_2) & !dplyr::coalesce(date_agree, FALSE) ~ "dates_differ",
        as.integer(format(date, "%Y")) != year        ~ "year_from_file",
        TRUE                                          ~ "ok"),
      # a sheet's year is set by its file (1955-1963, one file pair per year):
      # "4-VIII-49" in the 1955 file is 1955-08-04 by its place in the sequence
      date = dplyr::if_else(
        !is.na(date) & as.integer(format(date, "%Y")) != year,
        as.Date(paste0(year, format(date, "-%m-%d")), optional = TRUE), date),
      agreement = dplyr::case_when(
        is.na(value_txt_1) & is.na(value_txt_2) ~ "both_blank",
        value_txt_1 == value_txt_2              ~ "agree",
        is.na(value_txt_2)                      ~ "only_1",
        is.na(value_txt_1)                      ~ "only_2",
        TRUE                                    ~ "differ"),
      value_txt = dplyr::if_else(agreement == "differ", NA_character_,
                                 dplyr::coalesce(value_txt_1, value_txt_2)))

  # sampling was ~weekly: flag a sheet whose date runs backwards from the one
  # before it, or more than 6 weeks ahead (likely a misread day or month)
  d_seq <- d_pair |>
    dplyr::distinct(year, page_position, date) |>
    dplyr::arrange(year, page_position) |>
    dplyr::group_by(year) |>
    dplyr::mutate(gap_days = as.integer(date - dplyr::lag(date))) |>
    dplyr::ungroup()
  d_pair <- d_pair |>
    dplyr::left_join(dplyr::select(d_seq, year, page_position, gap_days), by = c("year", "page_position")) |>
    dplyr::mutate(date_flag = dplyr::if_else(
      date_flag == "ok" & !is.na(gap_days) & (gap_days <= 0 | gap_days > 42),
      "out_of_sequence", date_flag))

  # classify consensus value ----
  is_num <- function(x) stringr::str_detect(dplyr::coalesce(x, ""), "^\\d+(\\.\\d+)?$")

  d_pair <- d_pair |>
    dplyr::mutate(
      value = dplyr::if_else(is_num(value_txt), suppressWarnings(as.numeric(value_txt)), NA_real_),
      value_code = dplyr::case_when(
        agreement == "differ"                  ~ "transcriptions_differ",
        is.na(value_txt)                       ~ NA_character_,
        is_num(value_txt)                      ~ "number",
        value_txt %in% c("<1", "trace")        ~ "trace",
        value_txt %in% c("no_sample", "fouled") ~ value_txt,
        value_txt == "-"                       ~ "dash",
        TRUE                                   ~ "unparsed"),
      unit = dplyr::case_when(
        item_seq == 0                                     ~ "ml",
        value_code == "trace"                             ~ "percent_volume",
        value_code == "number" & value > 5                ~ "percent_volume",
        value_code == "number" & value < 1                ~ "percent_volume",
        value_code == "number" & value %% 1 != 0          ~ "percent_volume",
        value_code == "number"                            ~ "unit_unclear",   # whole 1-5
        TRUE                                              ~ NA_character_),
      present = dplyr::case_when(
        item_seq == 0                                     ~ NA,
        value_code == "number"                            ~ value > 0,
        value_code == "trace"                             ~ TRUE,
        TRUE                                              ~ NA))

  # sample table: one row per date x station ----
  d_sample <- d_pair |>
    dplyr::filter(item_seq == 0) |>
    dplyr::transmute(
      year, page_position, date, date_flag, station,
      wet_volume_ml   = dplyr::if_else(value_code == "number", value, NA_real_),
      wet_volume_code = value_code, wet_volume_agreement = agreement,
      page_status, page_url_1, page_url_2) |>
    dplyr::left_join(
      d_pair |>
        dplyr::filter(item_seq > 0) |>
        dplyr::group_by(year, page_position, station) |>
        dplyr::summarize(
          n_taxa_cells = sum(!is.na(value_txt)),
          any_no_sample = any(value_code %in% c("no_sample", "fouled"), na.rm = TRUE),
          .groups = "drop"),
      by = c("year", "page_position", "station")) |>
    dplyr::mutate(
      sampled = dplyr::case_when(
        wet_volume_code %in% c("no_sample", "fouled") | any_no_sample ~ FALSE,
        !is.na(wet_volume_ml) | n_taxa_cells > 0                      ~ TRUE,
        TRUE                                                         ~ NA)) |>
    dplyr::left_join(hopkins_stations, by = "station")

  # obs table: one row per non-blank taxon cell ----
  d_obs <- d_pair |>
    dplyr::filter(item_seq > 0, agreement != "both_blank") |>
    dplyr::mutate(
      taxon_label = dplyr::if_else(
        item_label %in% c("25", "bottom"),
        stringr::str_squish(dplyr::coalesce(write_in_1, write_in_2)),
        stringr::str_remove(item_label, "^\\d+ ")),
      # joins metadata/measurement_taxon.csv (log-sheet rows 1-24 only)
      raw_measurement_type = dplyr::if_else(
        item_seq <= 24,
        stringr::str_remove_all(
          stringr::str_replace_all(stringr::str_to_lower(taxon_label), "[^a-z0-9]+", "_"),
          "^_|_$"),
        NA_character_)) |>
    dplyr::select(
      year, page_position, date, date_flag, station, item_seq, taxon_label, raw_measurement_type,
      value, unit, value_code, present, agreement,
      value_raw_1, value_raw_2, write_in_1, write_in_2, page_url_1, page_url_2)

  # check list for the scans: one row per cell the transcriptions disagree on,
  # plus one row per sheet whose date needs a look
  d_disagree <- dplyr::bind_rows(
    d_pair |>
      dplyr::filter(agreement == "differ") |>
      dplyr::transmute(year, page_position, date, issue = "values_differ", item_seq,
                       item_label, station, text_1 = value_raw_1, text_2 = value_raw_2,
                       page_url_1, page_url_2),
    d_pair |>
      dplyr::filter(date_flag != "ok") |>
      dplyr::distinct(year, page_position, date, issue = date_flag,
                      text_1 = date_text, text_2 = date_text_2, page_url_1, page_url_2)) |>
    dplyr::arrange(year, page_position, item_seq, station)

  d_notes <- d_long |>
    dplyr::filter(!is.na(notes)) |>
    dplyr::distinct(year, transcription, page_position, date_text, page_url, notes) |>
    dplyr::arrange(year, page_position, transcription)


  list(sample = d_sample, obs = d_obs, check = d_disagree, notes = d_notes)
}
