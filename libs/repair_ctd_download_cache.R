# Repair the CTD download cache: rehydrate Google Drive placeholders, drop conflict copies
#
# `dir_dl` for ingest_calcofi_ctd-cast.qmd lives inside Google Drive
# (`~/My Drive/projects/calcofi/data-public/calcofi/ctd-cast/download`), and Drive
# does two things to it that a plain directory would not:
#
#  1. It **evicts** a synced file to a cloud-only placeholder. `ls -lO` marks the
#     file `dataless`, `list.files()` still reports its full size, and reading it
#     fails — on this machine it times out rather than returning an error, so
#     `readr::read_csv()` yields a **0-row tibble with no condition raised**.
#  2. It leaves **conflict copies** named `<name> 2.csv` beside the original. The
#     archives contain no such file; `unzip -l` on any of the zips proves it.
#
# Together those cost release v2026.08.08 ten cruises: 20 CSVs across 14 cruises
# read 0 rows, the only copy holding data was the conflict copy, and the copy's
# name ends " 2.csv" rather than "D.csv" so the cast-direction rule could not read
# a direction off it. No downcast means no `ctd_thin`, no `obs`, and a partition
# that `write_parquet_outputs()` then deletes as "gone from the source".
#
# This script restores the tree to exactly what the archives contain. It is
# idempotent and safe to re-run: it re-extracts only files it cannot read, and it
# removes a conflict copy only once the canonical sibling is readable.
#
# The durable fix is to move `dir_dl` out of Google Drive — the zips are mirrored
# to `gs://calcofi-files/`, so a fresh non-Drive download directory rehydrates
# from the object store. Until that happens, run this before a CTD ingest.
#
# Usage:  Rscript libs/repair_ctd_download_cache.R [--dry-run]

librarian::shelf(dplyr, fs, glue, purrr, stringr, tibble, quiet = TRUE)

dry_run <- "--dry-run" %in% commandArgs(trailingOnly = TRUE)
dir_dl  <- path_expand(
  "~/My Drive/projects/calcofi/data-public/calcofi/ctd-cast/download")

stopifnot("download directory not found" = dir_exists(dir_dl))

# --- which files are unreadable? ---------------------------------------------
# Test by READING, not by asking the filesystem: `dataless` is a macOS-specific
# flag, and what actually matters downstream is whether read_csv() gets bytes.
# A short timeout keeps a stalled Drive fetch from hanging the whole scan.
# `defined($n)`, not `$n > 0`: one archive genuinely ships a 0-byte file
# (20-0810NH_CTDFinalQC/metadata/0810EventsCorrExcel.csv is 0 bytes inside the
# zip), and re-extracting it forever would not make it longer. Empty-but-openable
# is a question for the ingest's own inventory; unopenable is this script's.
readable <- function(path, timeout_s = 15) {
  ok <- system2("perl", c("-e",
    shQuote(glue(
      'alarm {timeout_s}; open(F,"<",$ARGV[0]) or exit 1; ',
      'my $n=read(F,my $b,1); exit(defined($n) ? 0 : 1);')),
    shQuote(path)), stdout = FALSE, stderr = FALSE)
  identical(as.integer(ok), 0L)
}

csvs <- dir_ls(dir_dl, recurse = TRUE, glob = "*.csv", type = "file")
cat(glue("scanning {length(csvs)} CSV(s) under {dir_dl}\n\n"))

d <- tibble(path = as.character(csvs)) |>
  mutate(
    rel      = str_remove(path, fixed(paste0(dir_dl, "/"))),
    archive  = str_extract(rel, "^[^/]+"),
    member   = str_remove(rel, "^[^/]+/"),
    is_copy  = str_detect(path_file(path), "\\s\\d+\\.csv$"),
    can_read = map_lgl(path, readable))

bad <- d |> filter(!can_read)
cat(glue("{nrow(bad)} unreadable file(s)\n\n"))

# --- 1. re-extract each unreadable file from its archive ----------------------
if (nrow(bad) > 0) {
  repaired <- bad |>
    mutate(zip = file.path(dir_dl, paste0(archive, ".zip"))) |>
    mutate(fixed = pmap_lgl(list(zip, member, archive), \(zip, member, archive) {
      if (!file_exists(zip)) {
        cat(glue("  MISSING ARCHIVE for {archive}/{member}\n\n")); return(FALSE)
      }
      cat(glue("  re-extracting {archive}/{member}\n\n"))
      if (dry_run) return(NA)
      # -o overwrites the placeholder in place; -d keeps the archive's own layout
      out <- system2("unzip", c("-o", shQuote(zip), shQuote(member),
                                "-d", shQuote(file.path(dir_dl, archive))),
                     stdout = TRUE, stderr = TRUE)
      readable(file.path(dir_dl, archive, member))
    }))
  if (!dry_run) {
    n_ok <- sum(repaired$fixed, na.rm = TRUE)
    cat(glue("re-extracted {n_ok} of {nrow(bad)} unreadable file(s)\n\n"))
    # report and carry on rather than stopping here: step 2 is conservative (it
    # only removes a copy whose canonical sibling reads), so a file this could
    # not fix costs nothing by letting the rest complete. The summary at the end
    # is what fails the script.
    still_bad <<- repaired |> filter(is.na(fixed) | !fixed) |> pull(rel)
  }
}
if (!exists("still_bad")) still_bad <- character()

# --- 2. drop the Drive conflict copies ---------------------------------------
# Only once the canonical sibling reads: the copy is the sole materialized copy
# until step 1 has run, so deleting it first would destroy the only data.
copies <- d |>
  filter(is_copy) |>
  mutate(canonical = path |>
           str_remove("\\s\\d+\\.csv$") |> paste0(".csv"))

if (nrow(copies) > 0) {
  copies <- copies |> mutate(canon_ok = map_lgl(canonical, \(p)
    file_exists(p) && readable(p)))
  drop <- copies |> filter(canon_ok)
  keep <- copies |> filter(!canon_ok)

  for (p in drop$path) {
    cat(glue("  removing conflict copy {str_remove(p, fixed(paste0(dir_dl, '/')))}\n\n"))
    if (!dry_run) file_delete(p)
  }
  if (nrow(keep) > 0) {
    cat(glue("KEPT {nrow(keep)} conflict copy/copies whose canonical sibling ",
             "still does not read:\n\n"))
    walk(keep$path, \(p) cat(glue("  {p}\n\n")))
  }
  cat(glue("removed {if (dry_run) 0 else nrow(drop)} conflict copy/copies ",
           "({nrow(copies)} found)\n\n"))
}

if (length(still_bad) > 0) {
  cat(glue("\n{length(still_bad)} file(s) are STILL unreadable:\n\n"))
  walk(still_bad, \(p) cat(glue("  {p}\n\n")))
  stop("re-extraction did not recover every file — check that its archive exists")
}

cat(if (dry_run) "dry run — nothing changed\n" else "done\n")
