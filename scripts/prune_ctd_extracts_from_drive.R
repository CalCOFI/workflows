# Remove extracted CTD archives from the Google Drive download directory
#
# `dir_dl` for ingest_calcofi_ctd-cast.qmd holds the `.zip` archives and nothing
# else. Drive syncs ~370 archives without complaint; it cannot sync their
# contents — the 151 final/preliminary archives expand to ~124,000 files and
# ~45 GB, which the Drive client never finishes, and mid-sync it evicts files to
# cloud-only placeholders (read back as 0-row CSVs, no error) and mints ` 2.csv`
# conflict copies. Release v2026.08.08 lost ten cruises that way.
#
# The notebook now extracts to `cc_stage_dir()/ctd-cast/unzip` instead, and stops
# the render if an extracted directory reappears in `dir_dl`. This script is what
# that error tells you to run.
#
# It deletes only what it can prove is redundant. For each directory in dir_dl:
#
#   1. the sibling `<name>.zip` must exist and its central directory must read —
#      that archive is the durable copy and the reason the extraction is
#      disposable;
#   2. every file on disk must be recoverable from that archive. An unmatched
#      file is something the archive cannot give back (a hand-added file, a Drive
#      conflict copy holding the only readable bytes), so the whole directory is
#      SKIPPED and named, rather than deleted with a warning.
#
# "Recoverable" is looser than "is a member at the same path", because three
# layouts occur across these 154 directories and all three are still recoverable:
#
#   - a **wrapper folder**: 20-2105SH_CTDFinalQC.zip puts every member under
#     `20-2105SH_CTDFinalQC/`, but its extracted tree is flattened. All 591 files
#     are in the archive, one path component deeper.
#   - a **nested archive**: 19-9401JD_CTDCast.zip ships one zip per cast, and
#     someone extracted `9401_09001100_017.zip` in place. Its 4 files are not
#     members, but the zip that holds them is.
#   - a **Drive conflict copy**: `u1904020 2.asc`, `…075u (1).asc`. The archive
#     has the canonical name; the copy is Drive's own artifact.
#
# Matching only on the literal path would skip all three, and skipping is not
# free — it leaves the directory in Drive, which is the thing being fixed.
#
# Deleting through the Drive mount moves files to Drive's trash, but do not lean
# on that: the guarantee here is check 1, that the archive itself is intact.
#
# Usage:
#   Rscript scripts/prune_ctd_extracts_from_drive.R            # report only
#   Rscript scripts/prune_ctd_extracts_from_drive.R --apply    # delete
#
# Dry run is the default because this is one-way and measured in tens of GB.

librarian::shelf(dplyr, fs, glue, purrr, stringr, tibble, quiet = TRUE)

apply_it <- "--apply" %in% commandArgs(trailingOnly = TRUE)
dir_dl   <- path_expand(
  "~/My Drive/projects/calcofi/data-public/calcofi/ctd-cast/download")

stopifnot("download directory not found" = dir_exists(dir_dl))

# macOS litters a synced tree with these; they are not in any archive and are not
# worth blocking a prune over. Everything else unmatched is a real finding.
JUNK <- c("\\.DS_Store$", "^Icon\r?$", "^\\.Spotlight-", "^\\.Trashes",
          "^\\.fseventsd", "^__MACOSX/")

dirs <- dir_ls(dir_dl, recurse = FALSE, type = "directory")

if (length(dirs) == 0) {
  cat(glue("no extracted directories under {dir_dl} — nothing to do\n\n"))
  quit(save = "no", status = 0)
}

cat(glue("{length(dirs)} extracted director(ies) under {dir_dl}\n\n"))

# utils::unzip, NOT the bare name — `zip::unzip()` masks it and takes no `list`
# argument (the ingest notebook hits the same trap; see [jrw_overlap_report]).
zip_members <- function(zip_path) {
  tryCatch(utils::unzip(zip_path, list = TRUE)$Name, error = function(e) NULL)
}

# Which of `files` (paths relative to the extracted directory) can `members` NOT
# give back? See the three layouts in the header comment.
unexplained <- function(files, members) {
  if (is.null(members)) return(files)
  members <- str_remove(members, "/$")

  # wrapper folder: accept the member path with its single shared top-level
  # component stripped, when there IS exactly one
  tops <- unique(str_extract(members, "^[^/]+"))
  if (length(tops) == 1)
    members <- c(members, str_remove(members, "^[^/]+/"))

  # Drive conflict copy: `name 2.ext` / `name (1).ext` → `name.ext`
  canonical <- files |>
    str_replace("\\s+\\d+(\\.[^./]+)$", "\\1") |>
    str_replace("\\s*\\(\\d+\\)(\\.[^./]+)$", "\\1")

  # nested archive: some ancestor directory of the file is itself a member `.zip`
  from_nested <- map_lgl(files, \(f) {
    parts <- str_split(f, "/")[[1]]
    if (length(parts) < 2) return(FALSE)
    ancestors <- map_chr(seq_len(length(parts) - 1),
                         \(i) paste(parts[seq_len(i)], collapse = "/"))
    any(paste0(ancestors, ".zip") %in% members)
  })

  files[!(files %in% members | canonical %in% members | from_nested)]
}

d <- tibble(dir = as.character(dirs)) |>
  mutate(
    name    = path_file(dir),
    zip     = file.path(dir_dl, paste0(name, ".zip")),
    has_zip = file_exists(zip),
    members = map2(zip, has_zip, \(z, ok) if (ok) zip_members(z) else NULL),
    # a zip that exists but whose directory will not read is NOT a durable copy
    zip_ok  = map_lgl(members, \(m) !is.null(m) && length(m) > 0),
    on_disk = map(dir, \(p) list.files(p, recursive = TRUE, all.files = TRUE,
                                       no.. = TRUE)),
    extra   = map2(on_disk, members, \(f, m) {
      unexplained(f[!str_detect(f, paste(JUNK, collapse = "|"))], m)
    }),
    n_files = map_int(on_disk, length),
    n_extra = map_int(extra, length),
    prunable = zip_ok & n_extra == 0)

blocked <- d |> filter(!prunable)

if (nrow(blocked) > 0) {
  cat(glue("\nSKIPPING {nrow(blocked)} director(ies):\n\n"))
  pwalk(list(blocked$name, blocked$has_zip, blocked$zip_ok, blocked$n_extra,
             blocked$extra),
        \(name, has_zip, zip_ok, n_extra, extra) {
          why <- if (!has_zip) "no sibling .zip"
                 else if (!zip_ok) "sibling .zip does not read"
                 else glue("{n_extra} file(s) not in the archive")
          cat(glue("  {name}: {why}\n\n"))
          if (n_extra > 0)
            walk(head(extra, 5), \(f) cat(glue("      {f}\n\n")))
        })
}

prune <- d |> filter(prunable)
cat(glue("\n{nrow(prune)} director(ies) prunable, ",
         "{format(sum(prune$n_files), big.mark = ',')} file(s)\n\n"))

if (!apply_it) {
  cat("dry run — nothing deleted. Re-run with --apply to remove them.\n")
  quit(save = "no", status = 0)
}

# One at a time, reporting as it goes: deleting ~124,000 files through a FUSE
# mount is minutes of work, and a silent run is indistinguishable from a hang.
walk2(prune$dir, seq_len(nrow(prune)), \(p, i) {
  cat(glue("  [{i}/{nrow(prune)}] removing {path_file(p)}\n\n"))
  dir_delete(p)
})

left <- dir_ls(dir_dl, recurse = FALSE, type = "directory")
cat(glue("\ndone — {nrow(prune)} removed, {length(left)} director(ies) remain, ",
         "{length(dir_ls(dir_dl, glob = '*.zip'))} archive(s) kept\n\n"))
