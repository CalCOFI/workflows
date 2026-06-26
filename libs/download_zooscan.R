# libs/download_zooscan.R
# -----------------------------------------------------------------------------
# Reproducible acquisition of ZooScan PRPOOS per-taxon station data from the SIO
# Ocean Informatics ZooScan portal (https://oceaninformatics.ucsd.edu/zooscandb).
#
# The portal's "Download Data" button is disabled; the only data path is the
# PRPOOS plot CGI (/cgi-bin/tssubplot_new.py), whose returned Plotly HTML embeds
# the underlying per-station values as a `data:text/csv` download URI. For each
# bioclass taxon we request both plot modes (basic = abundance + C biomass,
# extra = Feret diameter + individual C content) with pquant=Stations and parse
# that embedded CSV.
#
# Sourced + invoked from ingest_cce-lter_zooscan.qmd (guarded so it only hits the
# portal when the consolidated CSV is missing or overwrite = TRUE).
#
# @importFrom httr2 request req_user_agent req_cookie_preserve req_body_form
#   req_url_query req_perform resp_body_string

#' Download + consolidate ZooScan PRPOOS per-taxon data
#'
#' @param out_dir   directory to write zooscan_prpoos.csv + by_taxon/ raw extracts
#' @param overwrite if FALSE (default) and the consolidated CSV exists, skip the
#'   portal entirely and return the cached path
#' @param email,name,institution public-access identity submitted to the portal
#' @param verbose   print per-taxon progress
#' @return path to the consolidated zooscan_prpoos.csv
download_zooscan <- function(
    out_dir,
    overwrite   = FALSE,
    email       = "bdbest@gmail.com",
    name        = "Ben Best",
    institution = "CalCOFI / Scripps Institution of Oceanography",
    verbose     = TRUE) {

  stopifnot(requireNamespace("httr2", quietly = TRUE))
  consolidated <- file.path(out_dir, "zooscan_prpoos.csv")
  raw_dir      <- file.path(out_dir, "by_taxon")
  if (!overwrite && file.exists(consolidated)) {
    if (verbose) cat("ZooScan: using cached", basename(consolidated), "\n")
    return(consolidated)
  }
  dir.create(raw_dir, showWarnings = FALSE, recursive = TRUE)

  root <- "https://oceaninformatics.ucsd.edu"
  base <- paste0(root, "/zooscandb")
  ua   <- "Mozilla/5.0 (CalCOFI data integration; bdbest@gmail.com)"
  cj   <- tempfile(fileext = ".cookies")   # cookie jar persisted across requests

  req_base <- function(url) httr2::request(url) |>
    httr2::req_user_agent(ua) |> httr2::req_cookie_preserve(cj)

  # --- authenticate as a public user (sets PHPSESSID) ---
  req_base(paste0(base, "/secure/login.php")) |> httr2::req_perform()
  req_base(paste0(base, "/secure/authenticate.php?action=public")) |>
    httr2::req_body_form(
      name = name, email = email, institution = institution,
      use = "Academic Research", confirmDataUse = "1") |>
    httr2::req_perform()
  if (verbose) cat("ZooScan: authenticated (public)\n")

  # 23 individual bioclass taxa (id -> slug); aggregate/sum categories excluded
  taxa <- c(
    "1"="appendicularia", "3"="bryozoan_larvae", "5"="chaetognatha",
    "34"="cnidaria_ctenophores", "6"="copepoda_calanoida_minus_eucalanids",
    "7"="copepoda_eucalanids", "8"="copepoda_harpacticoida",
    "9"="copepoda_oithona_like", "11"="copepoda_others",
    "10"="copepoda_poecilostomatoids", "12"="crustacea_others", "14"="doliolids",
    "15"="eggs", "16"="euphausiids", "17"="multiples", "18"="nauplii",
    "19"="ostracods", "20"="others", "21"="polychaete",
    "22"="pteropoda_heteropoda", "33"="pyrosomes", "35"="rhizaria", "31"="salps")

  # shared position columns + the 2 value columns that differ by plot mode
  pos_cols  <- c("cruise","station","line","latitude","longitude","max_depth_m",
                 "min_depth_m","cruise_mid_date","station_date","local_time_pst",
                 "day_night")
  mode_vals <- list(
    basic = c("abundance_per_m2","biomass_mgC_per_m2"),
    extra = c("feret_diameter_mm","carbon_content_indiv"))

  # fetch one taxon x mode -> data.frame of the embedded CSV (NULL if empty)
  fetch_csv <- function(bioclass, mode) {
    html <- req_base(paste0(root, "/cgi-bin/tssubplot_new.py")) |>
      httr2::req_url_query(
        mode = mode, bioclass = bioclass, linesel = "Both", daynight = "DayNight",
        pquant = "Stations", plotlines = "SepLines", showlims = "show") |>
      httr2::req_perform() |> httr2::resp_body_string()
    # the per-station values are embedded as: href='data:text/csv;charset=utf-8, ...'
    m <- regmatches(html, regexpr(
      "href='data:text/csv;charset=utf-8,.*?'", html, perl = TRUE))
    if (length(m) == 0) return(NULL)
    payload <- sub("^href='data:text/csv;charset=utf-8,\\s*", "", m)
    payload <- sub("'$", "", payload)
    txt   <- utils::URLdecode(payload)
    lines <- grep("\\S", strsplit(txt, "\r?\n")[[1]], value = TRUE)
    if (length(lines) < 4) return(NULL)         # 2 title lines + header + >=1 row
    utils::read.csv(text = paste(lines[-(1:2)], collapse = "\n"),
                    check.names = FALSE, stringsAsFactors = FALSE)
  }

  merged   <- list()   # sample_key -> named list of values
  manifest <- list()
  slugs    <- sort(unname(taxa))
  for (i in seq_along(slugs)) {
    slug <- slugs[i]; bid <- names(taxa)[match(slug, taxa)]
    for (mode in names(mode_vals)) {
      df <- tryCatch(fetch_csv(bid, mode), error = function(e) NULL)
      n  <- if (is.null(df)) 0L else nrow(df)
      manifest[[length(manifest) + 1]] <- data.frame(
        taxon = slug, bioclass_id = bid, mode = mode, rows = n)
      if (verbose) cat(sprintf("(%d/%d) %s [%s] rows=%d\n",
                               i, length(slugs), slug, mode, n))
      if (n == 0) next
      names(df)[1:11] <- pos_cols
      names(df)[12:13] <- mode_vals[[mode]]
      utils::write.csv(df, file.path(raw_dir, sprintf("%s__%s.csv", slug, mode)),
                       row.names = FALSE)
      key <- paste(slug, df$cruise, df$line, df$station, df$station_date,
                   df$local_time_pst, sep = "|")
      for (r in seq_len(n)) {
        d <- merged[[key[r]]]
        if (is.null(d)) d <- c(list(taxon = slug),
                               as.list(df[r, pos_cols, drop = FALSE]))
        for (vc in mode_vals[[mode]]) d[[vc]] <- df[[vc]][r]
        merged[[key[r]]] <- d
      }
      Sys.sleep(0.3)   # be polite to the portal
    }
  }

  all_cols <- c("taxon", pos_cols, "abundance_per_m2", "biomass_mgC_per_m2",
                "feret_diameter_mm", "carbon_content_indiv")
  out <- do.call(rbind, lapply(merged, function(d) {
    for (c in all_cols) if (is.null(d[[c]])) d[[c]] <- NA
    as.data.frame(d[all_cols], stringsAsFactors = FALSE)
  }))
  utils::write.csv(out, consolidated, row.names = FALSE)
  utils::write.csv(do.call(rbind, manifest),
                   file.path(raw_dir, "_manifest.csv"), row.names = FALSE)

  if (verbose) cat(sprintf(
    "ZooScan: wrote %s (%d taxon x sample rows, %d taxa, %d samples)\n",
    basename(consolidated), nrow(out), length(unique(out$taxon)),
    length(unique(paste(out$cruise, out$line, out$station, out$station_date,
                        out$local_time_pst)))))
  consolidated
}
