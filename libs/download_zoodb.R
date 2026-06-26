# libs/download_zoodb.R
# -----------------------------------------------------------------------------
# Reproducible acquisition of ZooDB holoplankton per-taxon data from the SIO
# Ocean Informatics ZooDB portal (https://oceaninformatics.ucsd.edu/zoodb).
#
# ZooDB is an interactive portal, not a file download. We script its public
# login and `save.php` CSV export: for each of the 33 higher taxa, request both
# abundance units (#/1000 m3 and #/m2) with pooled=combined (returns BOTH
# unpooled tows and pooled regional composites, distinguished by the Source
# column), raw/uncorrected, all years/months/times/regions. The two unit files
# per taxon are joined on the source RowNumber (biomass is unit-independent) into
# one tidy long table, zoodb_holoplankton.csv.
#
# Sourced + invoked from ingest_cce-lter_zoodb.qmd (guarded so it only hits the
# portal when the consolidated CSV is missing or overwrite = TRUE).
#
# @importFrom httr2 request req_user_agent req_cookie_preserve req_body_form
#   req_url_query req_perform resp_body_string

#' Download + consolidate ZooDB holoplankton per-taxon data
#'
#' @param out_dir   directory to write zoodb_holoplankton.csv + by_taxon/ extracts
#' @param overwrite if FALSE (default) and the consolidated CSV exists, skip the
#'   portal entirely and return the cached path
#' @param email,name,institution public-access identity submitted to the portal
#' @param verbose   print per-taxon progress
#' @return path to the consolidated zoodb_holoplankton.csv
download_zoodb <- function(
    out_dir,
    overwrite   = FALSE,
    email       = "bdbest@gmail.com",
    name        = "Ben Best",
    institution = "CalCOFI / Scripps Institution of Oceanography",
    verbose     = TRUE) {

  stopifnot(requireNamespace("httr2", quietly = TRUE))
  consolidated <- file.path(out_dir, "zoodb_holoplankton.csv")
  raw_dir      <- file.path(out_dir, "by_taxon")
  if (!overwrite && file.exists(consolidated)) {
    if (verbose) cat("ZooDB: using cached", basename(consolidated), "\n")
    return(consolidated)
  }
  dir.create(raw_dir, showWarnings = FALSE, recursive = TRUE)

  base <- "https://oceaninformatics.ucsd.edu/zoodb"
  ua   <- "Mozilla/5.0 (CalCOFI data integration; bdbest@gmail.com)"
  cj   <- tempfile(fileext = ".cookies")

  req_base <- function(url) httr2::request(url) |>
    httr2::req_user_agent(ua) |> httr2::req_cookie_preserve(cj)

  # --- authenticate as a public user ---
  req_base(paste0(base, "/secure/login.php")) |> httr2::req_perform()
  req_base(paste0(base, "/secure/authenticate.php?action=public")) |>
    httr2::req_body_form(
      name = name, email = email, institution = institution,
      use = "Academic Research", confirmDataUse = "1") |>
    httr2::req_perform()
  if (verbose) cat("ZooDB: authenticated (public)\n")

  # the 33 higher-taxon HT[] option values (from command.php?action=getOptions,
  # func=HTSearchName); stable set, kept in sync with taxon_worms.csv
  ht_taxa <- c(
    "AMPHIPODA GAMMARIDEA","AMPHIPODA HYPERIIDEA","APPENDICULARIA","CHAETOGNATHA",
    "COPEPODA","COPEPODA CALANOIDA AETIDEIDAE","COPEPODA CALANOIDA CALANIDAE",
    "COPEPODA CALANOIDA CANDACIIDAE","COPEPODA CALANOIDA EUCALANIDAE",
    "COPEPODA CALANOIDA EUCHAETIDAE","COPEPODA CALANOIDA HETERORHABDIDAE",
    "COPEPODA CALANOIDA LUCICUTIIDAE","COPEPODA CALANOIDA METRIDINIDAE",
    "COPEPODA CALANOIDA PONTELLIDAE","COPEPODA CALANOIDA SCOLECITRICHIDAE",
    "COPEPODA OTHER CALANOIDS","CTENOPHORA","DECAPODA ANOMURA GALATHEIDAE",
    "DECAPODA CARIDEA PASIPHAEIDAE","DECAPODA SERGESTOIDEA","DOLIOLIDA",
    "FORAMINIFERA","HYDROMEDUSA","MOLLUSCA EUTHECOSOMATA","MOLLUSCA GYMNOSOMATA",
    "MOLLUSCA HETEROPODA ATLANTIDAE","MOLLUSCA PSEUDOTHECOSOMATA","OSTRACODA",
    "POLYCHAETA TOMOPTERIDAE","PYROSOMA","RADIOLARIA","SALPIDA","SIPHONOPHORA")
  slug <- function(x) gsub("[^a-z0-9_]", "",
                           gsub(" ", "_", tolower(x)))

  # one taxon x unit -> data.frame of the save.php export (NULL if empty).
  # save.php returns a 5-line query preamble, a blank line, then the CSV header
  # "RowNumber,Cruise,..." and data rows.
  fetch_save <- function(taxon, unit) {
    txt <- req_base(paste0(base, "/save.php")) |>
      httr2::req_url_query(
        mode = "save", beginYear = "1949", endYear = "2026",
        `month[]` = as.character(1:12),
        timeType = "all", locType = "all",
        `HT[]` = taxon, `GS[]` = ".*", `PS[]` = ".*",
        pooled = "combined", calcType = "individual", calcUnit = unit,
        .multi = "explode") |>
      httr2::req_perform() |> httr2::resp_body_string()
    lines <- strsplit(txt, "\r?\n")[[1]]
    h <- which(grepl("^RowNumber,Cruise", lines))
    if (length(h) == 0 || h == length(lines)) return(NULL)
    df <- utils::read.csv(text = paste(lines[h:length(lines)], collapse = "\n"),
                          check.names = FALSE, stringsAsFactors = FALSE)
    if (nrow(df) == 0) NULL else df
  }

  out <- list()
  for (i in seq_along(ht_taxa)) {
    taxon <- ht_taxa[i]; sl <- slug(taxon)
    a <- tryCatch(fetch_save(taxon, "1000m3"), error = function(e) NULL)
    Sys.sleep(0.3)
    b <- tryCatch(fetch_save(taxon, "m2"),     error = function(e) NULL)
    Sys.sleep(0.3)
    na <- if (is.null(a)) 0L else nrow(a)
    if (verbose) cat(sprintf("(%d/%d) %s rows=%d\n", i, length(ht_taxa), sl, na))
    if (is.null(a)) next
    utils::write.csv(a, file.path(raw_dir, sprintf("%s__1000m3.csv", sl)), row.names = FALSE)
    if (!is.null(b)) utils::write.csv(b, file.path(raw_dir, sprintf("%s__m2.csv", sl)), row.names = FALSE)
    # join m2 abundance onto the 1000m3 rows by source RowNumber (1:1; same query)
    ab_m2 <- if (is.null(b)) rep(NA, na) else
      b$Abundance[match(a$RowNumber, b$RowNumber)]
    out[[sl]] <- data.frame(
      taxon                = sl,
      cruise               = a$Cruise,    ship      = a$Ship,
      date                 = a$Date,      line      = a$Line,
      station              = a$Station,   region    = a$Region,
      tow_begin            = a$TowBegin,  tow_end   = a$TowEnd,
      latitude             = a$Latitude,  longitude = a$Longitude,
      max_depth_m          = a$MaxDepth,  min_depth_m = a$MinDepth,
      net_type             = a$NetType,
      abundance_per_1000m3 = a$Abundance,
      abundance_per_m2     = ab_m2,
      biomass_mgC_per_m2   = a$Biomass,
      n_tows_pooled        = a$Tows,      source    = a$Source,
      stringsAsFactors = FALSE)
  }
  d <- do.call(rbind, out)
  utils::write.csv(d, consolidated, row.names = FALSE)
  if (verbose) cat(sprintf(
    "ZooDB: wrote %s (%d taxon x sample rows, %d taxa)\n",
    basename(consolidated), nrow(d), length(unique(d$taxon))))
  consolidated
}
