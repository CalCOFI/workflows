# explore_dataset.R
# profile a new CSV dataset before ingestion into the CalCOFI database
# usage: Rscript scripts/explore_dataset.R <csv_path_or_directory>

librarian::shelf(
  DBI, duckdb, dplyr, fs, glue, here, readr, stringr, tibble, tidyr,
  quiet = T)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("usage: Rscript scripts/explore_dataset.R <csv_path_or_directory>")
}

csv_path <- args[1]

# determine if path is a file or directory ----
if (dir_exists(csv_path)) {
  csv_files <- dir_ls(csv_path, regexp = "\\.csv$", recurse = FALSE)
} else if (file_exists(csv_path)) {
  csv_files <- csv_path
} else {
  stop("path not found: ", csv_path)
}

if (length(csv_files) == 0) stop("no CSV files found in: ", csv_path)

cat(glue("# Dataset Profile\n\n"))
cat(glue("**Source**: `{csv_path}`\n"))
cat(glue("**Files found**: {length(csv_files)}\n\n"))

# connect to in-memory DuckDB ----
con <- dbConnect(duckdb(), ":memory:")
on.exit(dbDisconnect(con, shutdown = TRUE))

# known CalCOFI PKs/FKs to match against ----
calcofi_keys <- list(
  cruise_key  = list(pattern = "cruise", type = "varchar", format = "YYMMKK"),
  ship_key    = list(pattern = "ship",   type = "varchar"),
  cast_id     = list(pattern = "cast",   type = "integer"),
  bottle_id   = list(pattern = "bottle", type = "integer"),
  species_id  = list(pattern = "sp(p|ecies)", type = "smallint"),
  grid_key    = list(pattern = "grid|line.*sta", type = "varchar"),
  site_uuid   = list(pattern = "site.*uuid",    type = "uuid"),
  tow_uuid    = list(pattern = "tow.*uuid",     type = "uuid"),
  net_uuid    = list(pattern = "net.*uuid",      type = "uuid"))

# profile each CSV file ----
cat("## Source Files\n\n")
cat("| File | Rows | Cols | Size |\n")
cat("|------|------|------|------|\n")

all_profiles <- list()

for (f in csv_files) {
  tbl_name <- tools::file_path_sans_ext(basename(f))
  tbl_name <- str_replace_all(tbl_name, "[^a-zA-Z0-9_]", "_") |> tolower()

  # read CSV into DuckDB
  d <- tryCatch(
    read_csv(f, show_col_types = FALSE, guess_max = 10000),
    error = function(e) {
      cat(glue("| {basename(f)} | ERROR | - | - | {e$message} |\n"))
      return(NULL)
    })
  if (is.null(d)) next

  dbWriteTable(con, tbl_name, d, overwrite = TRUE)
  size <- file_size(f)
  cat(glue("| {basename(f)} | {format(nrow(d), big.mark=',')} | {ncol(d)} | {size} |\n"))

  # run SUMMARIZE ----
  summary_df <- tryCatch(
    dbGetQuery(con, glue("SUMMARIZE {tbl_name}")),
    error = function(e) NULL)

  # profile columns ----
  col_profiles <- tibble(
    table     = tbl_name,
    column    = names(d),
    r_type    = sapply(d, class) |> sapply(\(x) x[1]),
    n_total   = nrow(d),
    n_null    = sapply(d, \(x) sum(is.na(x))),
    null_pct  = round(100 * n_null / n_total, 1),
    n_unique  = sapply(d, \(x) length(unique(x[!is.na(x)]))),
    is_unique = n_unique == (n_total - n_null))

  # check for FK matches ----
  col_profiles$fk_match <- ""
  for (col in col_profiles$column) {
    col_lower <- tolower(col)
    for (key_name in names(calcofi_keys)) {
      if (str_detect(col_lower, calcofi_keys[[key_name]]$pattern)) {
        col_profiles$fk_match[col_profiles$column == col] <-
          paste0(col_profiles$fk_match[col_profiles$column == col],
                 ifelse(nchar(col_profiles$fk_match[col_profiles$column == col]) > 0, ", ", ""),
                 key_name)
      }
    }
  }

  all_profiles[[tbl_name]] <- col_profiles
}

# display column profiles ----
cat("\n## Column Profiles\n\n")

for (tbl_name in names(all_profiles)) {
  prof <- all_profiles[[tbl_name]]
  cat(glue("\n### Table: `{tbl_name}`\n\n"))
  cat("| Column | Type | NULLs | Unique | Is PK? | FK Match |\n")
  cat("|--------|------|-------|--------|--------|----------|\n")
  for (i in seq_len(nrow(prof))) {
    r <- prof[i, ]
    pk_flag <- ifelse(r$is_unique & r$null_pct == 0, "yes", "")
    cat(glue("| {r$column} | {r$r_type} | {r$null_pct}% | {format(r$n_unique, big.mark=',')} | {pk_flag} | {r$fk_match} |\n"))
  }
}

# spatial coverage ----
cat("\n## Spatial Coverage\n\n")

for (tbl_name in names(all_profiles)) {
  prof <- all_profiles[[tbl_name]]
  lat_cols <- prof$column[str_detect(tolower(prof$column), "lat")]
  lon_cols <- prof$column[str_detect(tolower(prof$column), "lon")]

  if (length(lat_cols) > 0 & length(lon_cols) > 0) {
    for (lat_col in lat_cols) {
      for (lon_col in lon_cols) {
        ranges <- dbGetQuery(con, glue(
          "SELECT
             MIN(\"{lat_col}\") as lat_min, MAX(\"{lat_col}\") as lat_max,
             MIN(\"{lon_col}\") as lon_min, MAX(\"{lon_col}\") as lon_max
           FROM {tbl_name}
           WHERE \"{lat_col}\" IS NOT NULL AND \"{lon_col}\" IS NOT NULL"))
        in_grid <- ranges$lat_min >= 23 & ranges$lat_max <= 51 &
                   ranges$lon_min >= -170 & ranges$lon_max <= -117
        cat(glue("- **{tbl_name}**: {lat_col} [{ranges$lat_min}, {ranges$lat_max}], {lon_col} [{ranges$lon_min}, {ranges$lon_max}] — {ifelse(in_grid, 'within', 'OUTSIDE')} CalCOFI grid\n"))
      }
    }
  }
}

# temporal coverage ----
cat("\n## Temporal Coverage\n\n")

for (tbl_name in names(all_profiles)) {
  d <- dbReadTable(con, tbl_name)
  date_cols <- names(d)[sapply(d, \(x) inherits(x, c("Date", "POSIXt")))]

  # also check character columns that look like dates
  char_cols <- names(d)[sapply(d, is.character)]
  for (cc in char_cols) {
    sample_vals <- head(na.omit(d[[cc]]), 20)
    if (length(sample_vals) > 0 &&
        all(str_detect(sample_vals, "^\\d{4}[-/]\\d{2}"))) {
      date_cols <- c(date_cols, cc)
    }
  }

  if (length(date_cols) > 0) {
    for (dc in date_cols) {
      date_range <- tryCatch({
        vals <- as.Date(d[[dc]])
        list(min = min(vals, na.rm = TRUE), max = max(vals, na.rm = TRUE))
      }, error = function(e) NULL)

      if (!is.null(date_range)) {
        cat(glue("- **{tbl_name}.{dc}**: {date_range$min} to {date_range$max}\n"))
      }
    }
  }
}

# measurement columns ----
cat("\n## Potential Measurement Columns\n\n")

# load existing measurement_type.csv if available
mt_path <- here("metadata/measurement_type.csv")
if (file_exists(mt_path)) {
  mt <- read_csv(mt_path, show_col_types = FALSE)
  cat(glue("Existing measurement types ({nrow(mt)}): {paste(head(mt$measurement_type, 20), collapse=', ')}...\n\n"))
} else {
  cat("(measurement_type.csv not found)\n\n")
  mt <- NULL
}

for (tbl_name in names(all_profiles)) {
  prof <- all_profiles[[tbl_name]]
  numeric_cols <- prof |>
    filter(r_type %in% c("numeric", "integer", "double")) |>
    filter(!is_unique | null_pct > 0) |>  # exclude likely IDs
    filter(!str_detect(tolower(column), "id$|key$|code$|uuid"))

  if (nrow(numeric_cols) > 0) {
    cat(glue("### {tbl_name}\n"))
    for (i in seq_len(nrow(numeric_cols))) {
      r <- numeric_cols[i, ]
      in_mt <- if (!is.null(mt))
        any(str_detect(tolower(mt$measurement_type),
                       tolower(str_replace_all(r$column, "_", ".")))) else FALSE
      status <- ifelse(in_mt, "(exists in measurement_type)", "(NEW - add to measurement_type)")
      cat(glue("- `{r$column}` — {r$n_unique} unique values, {r$null_pct}% NULL {status}\n"))
    }
    cat("\n")
  }
}

# recommendations ----
cat("\n## Recommendations\n\n")

total_rows <- sum(sapply(all_profiles, \(x) x$n_total[1]))
n_tables   <- length(all_profiles)
has_spatial <- any(sapply(all_profiles, \(x)
  any(str_detect(tolower(x$column), "lat|lon"))))
has_species <- any(sapply(all_profiles, \(x)
  any(str_detect(tolower(x$column), "sp(p|ecies)"))))
has_fk      <- any(sapply(all_profiles, \(x)
  any(nchar(x$fk_match) > 0)))

cat(glue("- **Total rows**: {format(total_rows, big.mark=',')}\n"))
cat(glue("- **Tables**: {n_tables}\n"))
cat(glue("- **Has spatial columns**: {has_spatial}\n"))
cat(glue("- **Has species/taxonomy**: {has_species}\n"))
cat(glue("- **Has FK matches to CalCOFI**: {has_fk}\n"))

# complexity estimate
complexity <- "Low"
if (n_tables > 3 | has_species) complexity <- "Medium"
if (n_tables > 5 | total_rows > 1e6) complexity <- "High"
cat(glue("- **Estimated complexity**: {complexity}\n"))

cat("\n### Next Steps\n")
cat("1. Review column profiles and FK matches above\n")
cat("2. Run `/generate-metadata {provider} {dataset}` to create redefinition files\n")
cat("3. Edit `flds_redefine.csv` with domain expert input\n")
cat("4. Run `/ingest-new {provider} {dataset}` to scaffold the ingest notebook\n")
