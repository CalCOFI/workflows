#!/usr/bin/env Rscript
# Provider dataset-metadata sheets — a `metadata` tab added to each active
# provider's EXISTING question Sheet (metadata/questions_sheets.yml — the same
# spreadsheets scripts/sync_questions_sheets.R already writes to), long form,
# one row per (dataset, field), generated from and pulled back into
# metadata/{provider}/{dataset}/dataset_meta.yml (plan 2026-09-05 CalCOFI.io
# dataset catalog, WS-R2, D-9 / D-11, Decisions 14/25/26).
#
# The sidecar is the source of the VALUE (and every comment above it — the
# evidence trail); the Sheet is the source of an EDIT once a provider has
# typed one in — three columns only: value, edited_by, edited_date. `pull`
# validates before writing (license against metadata/license.csv, contact as
# an email or URL, doi bare, creators/associated_parties parsed from
# `Name · Org · orcid · email` lines) and rewrites ONLY the changed value's
# lines in the sidecar's own text — never yaml::write_yaml(), which would
# re-flow every string and drop every comment. See CLAUDE.md "The question
# registry convention" and scripts/sync_questions_sheets.R (the same auth
# precedence, dry-run default, protected-range and Drive mechanics).
#
# The `calcofi` Sheet ALSO gets a `holdings` tab (D-11): one row per holding
# sidecar (status: planned | external | archived) across every provider —
# the team's own triage board, not a per-provider tab. `status`, `priority`,
# `owner`, `next_step` are its editable columns.
#
#   Rscript scripts/sync_dataset_meta_sheets.R push [provider]              # dry run: plan only, no network
#   Rscript scripts/sync_dataset_meta_sheets.R push [provider] --execute    # write the metadata (+ holdings) tab(s)
#   Rscript scripts/sync_dataset_meta_sheets.R pull [provider]              # dry run: reads the sheet, prints the diff
#   Rscript scripts/sync_dataset_meta_sheets.R pull [provider] --execute    # applies the diff to the sidecar(s)
#
# `provider` is a metadata/provider.csv slug; omit it to act on every active
# provider that already has a sheet_id in metadata/questions_sheets.yml, OR that
# has at least one dataset_meta.yml sidecar (a holding, with no questions.csv and
# therefore no reason for scripts/sync_questions_sheets.R to have made it a sheet
# yet — sccoos, as of 2026-09-05). `push --execute` for such a provider creates its
# spreadsheet itself (Drive-folder mechanics, README tab, silent shares — all
# reused from sync_questions_sheets.R via source(), never copied) rather than
# requiring `sync_questions_sheets.R push <provider> --execute` to run first.
#
# Google auth: the calcofi-admin SERVICE ACCOUNT only, via scripts/lib_google_auth.R
# (QS_GOOGLE_SA_JSON / CALCOFI_GOOGLE_SA_JSON, else the key's Drive home, else
# /etc/rclone/calcofi-admin-sa.json) — no interactive fallback.
#
# Deps beyond calcofi4db, all CRAN, loaded via librarian::shelf() below.
suppressMessages(librarian::shelf(
  googlesheets4, googledrive, readr, yaml, glue, here, jsonlite, calcofi4db, quiet = TRUE))

SHEETS_YML          <- here("metadata/questions_sheets.yml")
PROVIDER_CSV        <- here("metadata/provider.csv")
LICENSE_CSV         <- here("metadata/license.csv")
DATASET_META_FIELDS <- here("metadata/dataset_meta_fields.csv")
METADATA_DIR        <- here("metadata")
DM_TAB              <- "metadata"
HOLDINGS_TAB        <- "holdings"
HOLDINGS_PROVIDER   <- "calcofi"  # the sheet that carries the team triage board
source(here("scripts/lib_google_auth.R"))
QS_SCOPES <- CC_GOOGLE_SCOPES

# Drive/Sheet-creation mechanics (qs_ensure_folder(), gs_ensure_spreadsheet(),
# qs_save_sheets_yml(), qs_readme_content(), qs_provider_registry(), SHARE_WITH)
# are reused from sync_questions_sheets.R, not copied — see dm_ensure_provider_sheet()
# below. It is sys.nframe()==0-guarded, so source()-ing it here never runs its own
# CLI or touches the network.
source(here("scripts/sync_questions_sheets.R"))

`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1 && is.na(a))) b else a

#' cat() a glue()d line with its newline intact (glue::glue() trims trailing
#' whitespace by default — see scripts/sync_questions_sheets.R's qcat()).
dcat <- function(..., .envir = parent.frame())
  cat(glue::glue(..., .envir = .envir), "\n", sep = "")

#' Authenticate once per process as the service account (scripts/lib_google_auth.R).
dm_auth <- function() cc_google_auth(QS_SCOPES)

# ============================================================================
# pure / network-free — unit-tested in scripts/test_sync_dataset_meta_sheets.R
# ============================================================================

#' The three sheet columns a provider may edit; everything else is protected.
dm_editable_cols <- function() c("value", "edited_by", "edited_date")

#' The dataset_meta_fields.csv `field`s that are measured, never edited.
dm_measured_fields <- function()
  c("coverage_temporal_observed", "coverage_spatial_observed",
    "source_accessed", "n_obs", "year_min", "year_max")

#' Does this provider's questions_sheets.yml `entry` (yml[[provider]], or NULL
#' when the provider has no entry at all) still need a spreadsheet created
#' before a metadata tab can be written to it? TRUE exactly when there is no
#' usable `sheet_id` yet — the create-vs-skip decision, kept pure/testable
#' apart from the Drive calls in dm_ensure_provider_sheet().
dm_provider_needs_sheet <- function(entry) is.null(entry$sheet_id) || !nzchar(entry$sheet_id)

#' Read metadata/dataset_meta_fields.csv, validated, sorted required -> recommended -> optional.
dm_read_fields_csv <- function(path = DATASET_META_FIELDS) {
  d <- readr::read_csv(path, na = "", show_col_types = FALSE,
                        col_types = readr::cols(.default = readr::col_character()))
  need <- c("field", "importance", "eml_path", "guidance", "editable")
  miss <- setdiff(need, names(d))
  if (length(miss)) stop("dataset_meta_fields.csv missing column(s): ", paste(miss, collapse = ", "), call. = FALSE)
  bad <- setdiff(d$importance, c("required", "recommended", "optional"))
  if (length(bad)) stop("dataset_meta_fields.csv has unknown importance value(s): ", paste(bad, collapse = ", "), call. = FALSE)
  d$editable <- toupper(trimws(d$editable)) %in% c("TRUE", "T", "1")
  d$.tier <- factor(d$importance, levels = c("required", "recommended", "optional"), ordered = TRUE)
  d[order(d$.tier), setdiff(names(d), ".tier")]
}

# ---- YAML line-level surgery (shared shape with scripts/migrate_dataset_meta.R,
# duplicated here so each sync script stays self-contained) ------------------

#' Split a sidecar's leading column-0 comment/blank lines (its header) from
#' the rest (a plain key: value mapping starting at `indent` spaces).
#' The body indent of a sidecar: 2 for the migrated notebooks' sidecars (every key
#' at two spaces), 0 for a hand-written or generated one. Mixed files are an error.
dm_detect_indent <- function(body) {
  if (any(grepl("^[A-Za-z_][A-Za-z0-9_]*:", body))) 0L else 2L
}

#' Drop whitespace at the end of every line (and the whole value) before comparing.
dm_norm_ws <- function(x) trimws(gsub("[ \t]+(\n|$)", "\\1", x %||% ""))

dm_split_header <- function(lines) {
  i <- 1L; n <- length(lines)
  while (i <= n && (grepl("^#", lines[i]) || !nzchar(trimws(lines[i])))) i <- i + 1L
  list(header = if (i > 1L) lines[seq_len(i - 1L)] else character(0),
       body   = if (i <= n) lines[seq(i, n)] else character(0))
}

#' Parse a `indent`-space-indented YAML mapping's lines into ordered key
#' entries (comment lines immediately above a key travel with it), plus any
#' trailing dangling comment with no key below it.
dm_parse_kv_block <- function(lines, indent = 2L) {
  pad <- strrep(" ", indent)
  key_re  <- paste0("^", pad, "([A-Za-z_][A-Za-z0-9_]*):")
  com_re  <- paste0("^", pad, "#")
  # a key's value continues on deeper-indented lines AND on block-sequence items
  # written at the key's own indent (`creators:` / `- name: …`, yaml.dump's style —
  # R1's holding sidecars)
  cont_re <- paste0("^(", pad, "- | {", indent + 1L, ",}\\S)")
  n <- length(lines); entries <- list(); pending <- character(0); i <- 1L
  while (i <= n) {
    ln <- lines[i]
    if (grepl(key_re, ln)) {
      key  <- sub(paste0(key_re, ".*$"), "\\1", ln)
      full <- c(pending, ln); pending <- character(0); i <- i + 1L
      while (i <= n && grepl(cont_re, lines[i])) { full <- c(full, lines[i]); i <- i + 1L }
      entries[[length(entries) + 1L]] <- list(key = key, lines = full)
    } else if (grepl(com_re, ln)) {
      pending <- c(pending, ln); i <- i + 1L
    } else if (!nzchar(trimws(ln))) {
      i <- i + 1L
    } else {
      stop("dm_parse_kv_block: unrecognized line: '", ln, "'", call. = FALSE)
    }
  }
  list(entries = entries, trailing = pending)
}

#' Dedent every line in `x` by exactly `n` leading spaces.
dm_dedent <- function(x, n = 2L) {
  if (!length(x)) return(x)
  vapply(x, function(ln) {
    # a blank (or whitespace-only) line separates blocks; it has nothing to dedent
    if (!nzchar(trimws(ln))) return("")
    lead <- nchar(regmatches(ln, regexpr("^ *", ln)))
    if (lead < n) stop("cannot dedent by ", n, " spaces: '", ln, "'", call. = FALSE)
    substring(ln, n + 1L)
  }, character(1), USE.NAMES = FALSE)
}

#' Re-render a full sidecar file from its header + entries.
dm_render_sidecar <- function(header, entries, trailing = character(0)) {
  c(header, unlist(lapply(entries, `[[`, "lines")), trailing)
}

#' Is `v` safe as a bare (unquoted) YAML plain scalar?
dm_yaml_plain_safe <- function(v) {
  if (!nzchar(v)) return(FALSE)
  if (grepl("^\\s|\\s$", v)) return(FALSE)
  if (grepl(": |:$", v)) return(FALSE)
  if (grepl(" #", v)) return(FALSE)
  if (substr(v, 1, 1) %in% c("-", "?", ":", ",", "[", "]", "{", "}", "#", "&", "*", "!", "|", ">", "'", "\"", "%", "@", "`")) return(FALSE)
  if (tolower(v) %in% c("true", "false", "null", "yes", "no", "~", "")) return(FALSE)
  if (grepl("^-?[0-9]+(\\.[0-9]+)?$", v)) return(FALSE)
  TRUE
}

#' `v` rendered as a YAML scalar (quoted only when it needs to be).
dm_yaml_scalar <- function(v) {
  if (!nzchar(v)) return('""')
  if (dm_yaml_plain_safe(v)) return(v)
  paste0('"', gsub('"', '\\\\"', v), '"')
}

dm_yaml_scalar_line <- function(field, value, indent = 2L)
  paste0(strrep(" ", indent), field, ": ", dm_yaml_scalar(value))

#' `field: >` folded-block lines for a (possibly multi-line) `value`.
dm_yaml_folded_lines <- function(field, value, indent = 2L) {
  pad <- strrep(" ", indent); pad2 <- strrep(" ", indent + 2L)
  body <- strsplit(value, "\n", fixed = TRUE)[[1]]
  if (!length(body)) body <- ""
  c(paste0(pad, field, ": >"), paste0(pad2, body))
}

#' Replace one key's VALUE in a parsed entries list, keeping its comment
#' lines and re-using its original style (folded block vs scalar). A field
#' with no existing entry is appended fresh (no comment).
dm_replace_entry_value <- function(entries, field, new_value, indent = 2L) {
  idx <- which(vapply(entries, `[[`, "", "key") == field)
  if (!length(idx)) {
    entries[[length(entries) + 1L]] <- list(key = field, lines = dm_yaml_scalar_line(field, new_value, indent))
    return(entries)
  }
  e <- entries[[idx[1]]]
  com_re <- paste0("^", strrep(" ", indent), "#")
  comment_lines <- character(0); rest <- e$lines
  while (length(rest) && grepl(com_re, rest[1])) { comment_lines <- c(comment_lines, rest[1]); rest <- rest[-1] }
  was_folded <- length(rest) && grepl(":\\s*>\\s*$", rest[1])
  new_lines <- if (was_folded) dm_yaml_folded_lines(field, new_value, indent) else dm_yaml_scalar_line(field, new_value, indent)
  e$lines <- c(comment_lines, new_lines)
  entries[[idx[1]]] <- e
  entries
}

#' Merge `changes` (a named list, each `list(by=, date=)`) into the sidecar's
#' `edited:` map, re-serializing only that key (machine-owned, not prose).
dm_set_edited <- function(entries, changes, indent = 2L) {
  idx <- which(vapply(entries, `[[`, "", "key") == "edited")
  existing <- list()
  if (length(idx)) {
    txt <- paste(dm_dedent(entries[[idx[1]]]$lines, indent), collapse = "\n")
    existing <- yaml::yaml.load(txt)$edited %||% list()
  }
  for (f in names(changes)) existing[[f]] <- changes[[f]]
  pad <- strrep(" ", indent)
  lines <- paste0(pad, "edited:")
  for (f in names(existing)) {
    lines <- c(lines, paste0(pad, "  ", f, ":"),
               paste0(pad, "    by: ", dm_yaml_scalar(existing[[f]]$by %||% "")),
               paste0(pad, "    date: ", existing[[f]]$date %||% ""))
  }
  entry <- list(key = "edited", lines = lines)
  if (length(idx)) entries[[idx[1]]] <- entry else entries[[length(entries) + 1L]] <- entry
  entries
}

#' `creators`/`associated_parties` as `Name · Org · orcid · email` lines,
#' whether the sidecar stores them that way already (a character vector of
#' pre-formatted lines) or as a YAML list of mappings — the shape a holding
#' sidecar minted from the CalOOS sheet uses (`name`/`organization`/`email`/
#' `role`, no `orcid`).
dm_format_people_field <- function(v) {
  if (is.null(v) || !length(v)) return("")
  is_mapping_list <- is.list(v) && all(vapply(v, is.list, logical(1)))
  if (is_mapping_list) {
    lines <- vapply(v, function(p) {
      name  <- as.character(p$name %||% "")
      org   <- as.character(p$organization %||% p$org %||% p$affiliation %||% "")
      orcid <- as.character(p$orcid %||% "")
      email <- as.character(p$email %||% "")
      paste(c(name, org, orcid, email), collapse = " · ")
    }, character(1))
    return(paste(lines, collapse = "\n"))
  }
  paste(trimws(as.character(unlist(v))), collapse = "\n")
}

#' The current value of `field` in a parsed sidecar (list from yaml::yaml.load),
#' flattened to one string for a Sheet cell (a character vector -> newline-joined).
dm_sidecar_field_value <- function(sidecar_list, field) {
  v <- sidecar_list[[field]]
  if (is.null(v)) return("")
  if (field %in% c("creators", "associated_parties")) return(dm_format_people_field(v))
  if (is.list(v)) v <- unlist(v)
  paste(trimws(as.character(v)), collapse = "\n")
}

#' Build the long-form rows for one dataset: one row per dataset_meta_fields.csv
#' field (editable ones from the sidecar, measured ones from `measured`),
#' sorted required -> recommended -> optional exactly as fields_df arrives
#' (dm_read_fields_csv() already sorts it).
dm_build_metadata_rows <- function(dataset_key, sidecar_list, fields_df, measured = list()) {
  edited <- sidecar_list$edited %||% list()
  vals <- vapply(fields_df$field, function(f) {
    if (isTRUE(fields_df$editable[fields_df$field == f])) dm_sidecar_field_value(sidecar_list, f)
    else as.character(measured[[f]] %||% "")
  }, character(1))
  eb <- vapply(fields_df$field, function(f) as.character(edited[[f]]$by %||% ""), character(1))
  ed <- vapply(fields_df$field, function(f) as.character(edited[[f]]$date %||% ""), character(1))
  data.frame(dataset_key = dataset_key, field = fields_df$field, value = vals,
             guidance = fields_df$guidance, edited_by = eb, edited_date = ed,
             stringsAsFactors = FALSE)
}

# ---- pull-side validation ----------------------------------------------------

#' `NAME · ORG · orcid · email`, one per line -> a list of parsed people
#' (unknown/blank sub-fields are ""); blank lines are dropped.
dm_parse_people <- function(text) {
  lines <- trimws(strsplit(text %||% "", "\n", fixed = TRUE)[[1]])
  lines <- lines[nzchar(lines)]
  lapply(lines, function(ln) {
    parts <- trimws(strsplit(ln, "·", fixed = TRUE)[[1]])  # ·
    list(name = parts[1] %||% "", org = parts[2] %||% "", orcid = parts[3] %||% "", email = parts[4] %||% "")
  })
}

#' Validate one (field, value) pair before it is ever written to a sidecar.
#' @return list(ok=, msg=)
dm_validate_field <- function(field, value, licenses = NULL) {
  ok <- TRUE; msg <- character(0)
  if (!nzchar(value %||% "")) return(list(ok = TRUE, msg = character(0)))
  if (field == "license" && !is.null(licenses) && !value %in% licenses) {
    ok <- FALSE; msg <- c(msg, glue::glue("license '{value}' is not an active id in metadata/license.csv"))
  }
  if (field == "contact") {
    is_email <- grepl("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", value)
    is_url   <- grepl("^https?://", value)
    if (!is_email && !is_url) { ok <- FALSE; msg <- c(msg, glue::glue("contact '{value}' is neither an email nor a URL")) }
  }
  if (field == "doi") {
    if (grepl("^https?://", value) || grepl("^doi:", value, ignore.case = TRUE)) {
      ok <- FALSE; msg <- c(msg, glue::glue("doi '{value}' must be bare (10.xxxx/...), not a URL/prefixed form"))
    } else if (!grepl("^10\\.[0-9]{4,9}/\\S+$", value)) {
      ok <- FALSE; msg <- c(msg, glue::glue("doi '{value}' does not match the bare DOI pattern 10.xxxx/..."))
    }
  }
  if (field %in% c("creators", "associated_parties")) {
    people <- dm_parse_people(value)
    if (!length(people)) { ok <- FALSE; msg <- c(msg, glue::glue("{field} has no parseable 'Name · Org · orcid · email' line(s)")) }
    blank_name <- vapply(people, function(p) !nzchar(p$name), logical(1))
    if (any(blank_name)) { ok <- FALSE; msg <- c(msg, glue::glue("{field} line(s) with no name")) }
  }
  list(ok = ok, msg = msg)
}

#' Apply one dataset's pulled sheet rows to its sidecar TEXT — validates every
#' changed (field, value) first (so nothing invalid is ever written), then
#' rewrites only the changed field's value lines plus the `edited:` map.
#'
#' @param sidecar_lines character vector, the sidecar file as it stands on disk
#' @param sheet_rows data.frame(field, value, edited_by, edited_date) — the
#'   provider-facing rows for THIS dataset_key, from the sheet
#' @param licenses active license ids (metadata/license.csv), or NULL to skip
#' @param today Date, used only when a row has a value but no edited_date
#' @return list(lines=<new sidecar text>, diffs=data.frame(field,old,new),
#'   errors=character() — validation failures, nothing written for those)
dm_apply_pull_dataset <- function(sidecar_lines, sheet_rows, licenses = NULL, today = Sys.Date()) {
  split  <- dm_split_header(sidecar_lines)
  ind    <- dm_detect_indent(split$body)
  parsed <- dm_parse_kv_block(split$body, indent = ind)
  sidecar_list <- yaml::yaml.load(paste(dm_dedent(split$body, ind), collapse = "\n")) %||% list()

  editable_fields <- dm_read_fields_csv()$field[dm_read_fields_csv()$editable]
  rows <- sheet_rows[sheet_rows$field %in% editable_fields, , drop = FALSE]

  diffs <- data.frame(field = character(), old = character(), new = character(), stringsAsFactors = FALSE)
  errors <- character(0)
  changes <- list()
  entries <- parsed$entries

  for (i in seq_len(nrow(rows))) {
    field <- rows$field[i]
    new_v <- trimws(rows$value[i] %||% "")
    old_v <- dm_sidecar_field_value(sidecar_list, field)
    # Sheets strips trailing whitespace from a cell, and an empty `·`-separated part
    # (a creator with no e-mail) leaves one: whitespace at a line end is never a change
    if (identical(dm_norm_ws(new_v), dm_norm_ws(old_v))) next
    v <- dm_validate_field(field, new_v, licenses)
    if (!v$ok) { errors <- c(errors, paste0(field, ": ", paste(v$msg, collapse = "; "))); next }
    entries <- dm_replace_entry_value(entries, field, new_v, indent = ind)
    diffs <- rbind(diffs, data.frame(field = field, old = old_v, new = new_v, stringsAsFactors = FALSE))
    who  <- trimws(rows$edited_by[i] %||% "")
    date <- trimws(rows$edited_date[i] %||% "")
    if (!nzchar(date)) date <- format(today, "%Y-%m-%d")
    changes[[field]] <- list(by = who, date = date)
  }

  if (length(changes)) entries <- dm_set_edited(entries, changes, indent = ind)
  new_lines <- dm_render_sidecar(split$header, entries, parsed$trailing)
  list(lines = new_lines, diffs = diffs, errors = errors)
}

# ---- holdings tab ------------------------------------------------------------

#' The holdings.csv-shaped row for one holding sidecar (D-11).
dm_holdings_row <- function(dataset_key, sidecar_list) {
  data.frame(
    dataset_key = dataset_key,
    name        = as.character(sidecar_list$dataset_name %||% ""),
    provider    = as.character(sidecar_list$provider %||% ""),
    category    = as.character(sidecar_list$category %||% ""),
    status      = as.character(sidecar_list$status %||% ""),
    priority    = as.character(sidecar_list$priority %||% ""),
    owner       = as.character(sidecar_list$owner %||% ""),
    next_step   = as.character(sidecar_list$next_step %||% ""),
    gh_issue    = as.character(sidecar_list$gh_issue %||% ""),
    observed    = as.character(sidecar_list$observed %||% ""),
    stringsAsFactors = FALSE)
}

dm_holdings_editable_cols <- function() c("status", "priority", "owner", "next_step")

#' Apply one holding's pulled sheet row to its sidecar text (status/priority/
#' owner/next_step only — the same line-level replace as the metadata tab).
dm_apply_holdings_pull <- function(sidecar_lines, row, statuses = calcofi4db::holding_statuses()) {
  split  <- dm_split_header(sidecar_lines)
  ind    <- dm_detect_indent(split$body)
  parsed <- dm_parse_kv_block(split$body, indent = ind)
  entries <- parsed$entries
  diffs <- data.frame(field = character(), old = character(), new = character(), stringsAsFactors = FALSE)
  errors <- character(0)
  cur <- yaml::yaml.load(paste(dm_dedent(split$body, ind), collapse = "\n")) %||% list()

  if (nzchar(row$status %||% "") && !row$status %in% statuses) {
    errors <- c(errors, glue::glue("status '{row$status}' not in {paste(statuses, collapse=' | ')}"))
  } else {
    for (f in dm_holdings_editable_cols()) {
      new_v <- trimws(row[[f]] %||% "")
      old_v <- as.character(cur[[f]] %||% "")
      if (identical(new_v, old_v)) next
      entries <- dm_replace_entry_value(entries, f, new_v, indent = ind)
      diffs <- rbind(diffs, data.frame(field = f, old = old_v, new = new_v, stringsAsFactors = FALSE))
    }
  }
  list(lines = dm_render_sidecar(split$header, entries, parsed$trailing), diffs = diffs, errors = errors)
}

# ---- protection / validation request-shapes (Sheets API) --------------------
# Same construction as scripts/sync_questions_sheets.R's qs_contiguous_ranges()
# / qs_protection_requests(), duplicated so this script stays self-contained.

dm_contiguous_ranges <- function(idx0) {
  if (!length(idx0)) return(list())
  idx0 <- sort(unique(idx0))
  if (length(idx0) == 1) return(list(list(start = idx0[1], end = idx0[1] + 1L)))
  brk <- which(diff(idx0) != 1)
  starts <- idx0[c(1, brk + 1)]; ends <- idx0[c(brk, length(idx0))]
  Map(function(s, e) list(start = s, end = e + 1L), starts, ends)
}

dm_protection_requests <- function(sheet_id, col_names, editable_cols) {
  editable_idx0 <- match(editable_cols, col_names) - 1L
  if (anyNA(editable_idx0))
    stop("editable column(s) not found in tab: ", paste(editable_cols[is.na(editable_idx0)], collapse = ", "), call. = FALSE)
  protected_idx0 <- setdiff(seq_along(col_names) - 1L, editable_idx0)
  col_reqs <- lapply(dm_contiguous_ranges(protected_idx0), function(r) list(addProtectedRange = list(
    protectedRange = list(range = list(sheetId = sheet_id, startColumnIndex = r$start, endColumnIndex = r$end),
                           description = "generated by scripts/sync_dataset_meta_sheets.R — edit the sidecar instead",
                           warningOnly = FALSE))))
  hdr_reqs <- lapply(dm_contiguous_ranges(sort(editable_idx0)), function(r) list(addProtectedRange = list(
    protectedRange = list(range = list(sheetId = sheet_id, startRowIndex = 0L, endRowIndex = 1L,
                                        startColumnIndex = r$start, endColumnIndex = r$end),
                           description = "header — do not rename, the pull matches columns by name",
                           warningOnly = FALSE))))
  c(col_reqs, hdr_reqs)
}

#' One setDataValidation request restricting the holdings tab's `status`
#' column (data rows only) to the controlled vocabulary.
dm_status_validation_request <- function(sheet_id, col_names, nrow_data, values = calcofi4db::holding_statuses()) {
  idx0 <- match("status", col_names) - 1L
  if (is.na(idx0)) stop("no 'status' column in tab", call. = FALSE)
  list(setDataValidation = list(
    range = list(sheetId = sheet_id, startRowIndex = 1L, endRowIndex = 1L + nrow_data,
                 startColumnIndex = idx0, endColumnIndex = idx0 + 1L),
    rule = list(condition = list(type = "ONE_OF_LIST", values = lapply(values, function(v) list(userEnteredValue = v))),
                showCustomUi = TRUE, strict = TRUE)))
}

#' One `updateBorders`-free background-color band per contiguous run of rows
#' sharing the same `importance` tier (required/recommended/optional), a
#' plain stand-in for "coloured header band per tier" (D-9).
dm_importance_band_requests <- function(sheet_id, importances, n_fixed_cols) {
  tiers <- c(required = "#e7f5ff", recommended = "#fff9db", optional = "#f1f3f5")
  reqs <- list()
  for (tier in names(tiers)) {
    idx0 <- which(importances == tier) - 1L  # 0-based data-row offset (header is row 0)
    for (r in dm_contiguous_ranges(idx0)) {
      reqs[[length(reqs) + 1L]] <- list(repeatCell = list(
        range = list(sheetId = sheet_id, startRowIndex = r$start + 1L, endRowIndex = r$end + 1L,
                     startColumnIndex = 0L, endColumnIndex = n_fixed_cols),
        cell = list(userEnteredFormat = list(backgroundColor = .hex_to_rgb(tiers[[tier]]))),
        fields = "userEnteredFormat.backgroundColor"))
    }
  }
  reqs
}
.hex_to_rgb <- function(hex) {
  hex <- sub("^#", "", hex)
  list(red = strtoi(substr(hex, 1, 2), 16L) / 255, green = strtoi(substr(hex, 3, 4), 16L) / 255,
       blue = strtoi(substr(hex, 5, 6), 16L) / 255)
}

# ---- measured-field lookup (best-effort; read-only context rows) ------------

#' Best-effort reader for the six measured fields, from the latest PROMOTED
#' release's coverage.json / metadata.json and the dataset's
#' citation_authority.json `checked` date — never authored, never written
#' back. Missing files/keys degrade to "" rather than erroring (a holding, or
#' a dataset not yet in a release, simply shows blank context rows).
dm_read_measured <- function(dataset_key, workflow_dir = here::here()) {
  out <- stats::setNames(as.list(rep("", length(dm_measured_fields()))), dm_measured_fields())
  stamp_path <- file.path(workflow_dir, "data/releases/_release_stamp.json")
  if (file.exists(stamp_path)) {
    v <- tryCatch(jsonlite::fromJSON(stamp_path)$release_version, error = function(e) NA_character_)
    if (!is.na(v)) {
      meta_p <- file.path(workflow_dir, "data/releases", v, "metadata.json")
      cov_p  <- file.path(workflow_dir, "data/releases", v, "coverage.json")
      if (file.exists(meta_p)) {
        md <- tryCatch(jsonlite::fromJSON(meta_p, simplifyVector = FALSE), error = function(e) NULL)
        ds <- md$datasets[[dataset_key]]
        if (!is.null(ds)) {
          out$coverage_temporal_observed <- as.character(ds$coverage_temporal_observed %||% "")
          out$coverage_spatial_observed  <- as.character(ds$coverage_spatial_observed %||% "")
        }
      }
      if (file.exists(cov_p)) {
        cv <- tryCatch(jsonlite::fromJSON(cov_p, simplifyVector = FALSE), error = function(e) NULL)
        hit <- Filter(function(x) identical(x$dataset_key, dataset_key), cv$datasets %||% list())
        if (length(hit)) {
          out$n_obs     <- as.character(hit[[1]]$n_obs %||% "")
          out$year_min  <- as.character(hit[[1]]$year_min %||% "")
          out$year_max  <- as.character(hit[[1]]$year_max %||% "")
        }
      }
    }
  }
  pd <- regmatches(dataset_key, regexec("^([^_]+)_(.+)$", dataset_key))[[1]]
  if (length(pd) == 3) {
    ca_p <- file.path(workflow_dir, "metadata", pd[2], pd[3], "citation_authority.json")
    if (file.exists(ca_p)) {
      ca <- tryCatch(jsonlite::fromJSON(ca_p), error = function(e) NULL)
      out$source_accessed <- as.character(ca$checked %||% "")
    }
  }
  out
}

# ============================================================================
# network-touching orchestration — cannot be exercised without Google auth;
# written to mirror scripts/sync_questions_sheets.R exactly.
# ============================================================================

dm_provider_registry <- function(path = PROVIDER_CSV) {
  d <- utils::read.csv(path, stringsAsFactors = FALSE)
  d[d$status == "active", , drop = FALSE]
}

dm_load_sheets_yml <- function(path = SHEETS_YML) yaml::read_yaml(path)

#' Every dataset_meta.yml sidecar for `provider` (ingested datasets AND
#' holdings alike — D-11: "a holding appears in its provider's metadata tab
#' like any dataset").
dm_provider_sidecars <- function(provider, metadata_dir = METADATA_DIR) {
  paths <- sort(Sys.glob(file.path(metadata_dir, provider, "*", "dataset_meta.yml")))
  # `path` rides along: gs_pull_metadata_provider() rewrites the file the sidecar came from
  stats::setNames(lapply(paths, function(p) { y <- calcofi4db::read_dataset_sidecar(p); y$path <- p; y }),
                   paste0(provider, "_", basename(dirname(paths))))
}

#' Every holding sidecar (status planned|external|archived) across ALL
#' providers, for the `calcofi` sheet's `holdings` tab.
dm_all_holding_sidecars <- function(metadata_dir = METADATA_DIR) {
  paths <- sort(Sys.glob(file.path(metadata_dir, "*", "*", "dataset_meta.yml")))
  out <- list()
  for (p in paths) {
    y <- calcofi4db::read_dataset_sidecar(p)
    if (nzchar(y$status %||% "") && y$status %in% calcofi4db::holding_statuses()) {
      dataset <- basename(dirname(p)); provider <- basename(dirname(dirname(p)))
      out[[paste0(provider, "_", dataset)]] <- y
    }
  }
  out
}

#' Create `provider`'s question spreadsheet when it has none yet (sccoos,
#' 2026-09-05: two holdings, no ingest, so sync_questions_sheets.R's own push
#' has nothing to create one FOR — its `qs_dataset_paths()` glob is empty).
#' Reuses sync_questions_sheets.R's Drive mechanics verbatim (source()d above,
#' never copied): `qs_ensure_folder()` for the Shared-Drive folder a service
#' account (no My Drive quota) must create inside, `gs_ensure_spreadsheet()`
#' for the spreadsheet + its README tab rename, `qs_save_sheets_yml()` to
#' record `sheet_id`/`url`/`created`, `qs_readme_content()` for the README
#' tab's text, and the same silent per-file shares (`SHARE_WITH`, minus the
#' service account's own address). Idempotent: returns the existing
#' `sheet_id` untouched when one is already on file.
dm_ensure_provider_sheet <- function(provider, sheets_yml_path = SHEETS_YML, share_with = SHARE_WITH) {
  yml   <- qs_load_sheets_yml(sheets_yml_path)
  entry <- yml[[provider]]
  if (!dm_provider_needs_sheet(entry)) return(googlesheets4::as_sheets_id(entry$sheet_id))

  reg   <- qs_provider_registry()
  short <- reg$provider_short[match(provider, reg$provider)]
  if (is.na(short)) short <- provider

  folder_id <- qs_ensure_folder(yml, sheets_yml_path)
  yml <- qs_load_sheets_yml(sheets_yml_path)   # qs_ensure_folder() may have written _folder
  ss  <- gs_ensure_spreadsheet(provider, short, entry, folder_id)

  meta <- googlesheets4::gs4_get(ss)
  yml[[provider]] <- list(sheet_id = as.character(ss), url = meta$spreadsheet_url,
                           created = format(Sys.Date()))
  qs_save_sheets_yml(yml, sheets_yml_path)

  # per-file sharing is additive to the folder's own Shared-Drive membership —
  # same rationale as gs_push_provider()'s identical loop
  share_with <- setdiff(tolower(share_with), getOption("qs.auth_user", character()))
  shared <- character()
  for (email in share_with) {
    ok <- tryCatch({
      googledrive::drive_share(googledrive::as_id(as.character(ss)), role = "writer",
                                type = "user", emailAddress = email,
                                sendNotificationEmail = FALSE); TRUE },
      error = function(e) { dcat("  share with {email} refused: {substr(conditionMessage(e), 1, 80)}"); FALSE })
    if (ok) shared <- c(shared, email)
  }
  dcat("created {meta$spreadsheet_url} in folder {folder_id}; shared with {paste(shared, collapse=', ')}")

  googlesheets4::sheet_write(qs_readme_content(short), ss = ss, sheet = "README")
  ss
}

#' Push provider(s) `metadata` tab (dry run touches no network).
gs_push_metadata_provider <- function(provider, sheets_yml_path = SHEETS_YML, execute = FALSE,
                                       metadata_dir = METADATA_DIR) {
  sidecars <- dm_provider_sidecars(provider, metadata_dir)
  if (!length(sidecars)) { dcat("{provider}: no dataset_meta.yml sidecars — nothing to push"); return(invisible(NULL)) }

  fields_df <- dm_read_fields_csv()
  rows <- do.call(rbind, lapply(names(sidecars), function(dk)
    dm_build_metadata_rows(dk, sidecars[[dk]], fields_df, dm_read_measured(dk))))

  dcat("push plan for {provider}: {DM_TAB} tab, {length(sidecars)} dataset(s), {nrow(rows)} row(s)")
  for (dk in names(sidecars)) dcat("  {dk}: {nrow(fields_df)} field row(s)")

  if (!isTRUE(execute)) { cat("dry run — pass --execute to write\n"); return(invisible(rows)) }

  # creates the spreadsheet (folder + README + shares) when this provider has
  # none yet; a no-op returning the existing id otherwise
  ss <- dm_ensure_provider_sheet(provider, sheets_yml_path)
  googlesheets4::sheet_write(rows, ss = ss, sheet = DM_TAB)
  props <- googlesheets4::sheet_properties(ss); sid <- props$id[props$name == DM_TAB]
  reqs <- c(dm_protection_requests(sid, names(rows), dm_editable_cols()),
            dm_importance_band_requests(sid, fields_df$importance[match(rows$field, fields_df$field)], ncol(rows)))
  googlesheets4::request_make(googlesheets4::request_generate(
    "sheets.spreadsheets.batchUpdate", params = list(spreadsheetId = as.character(ss), requests = reqs)))
  dcat("wrote {DM_TAB} to {provider} ({nrow(rows)} rows) + protection/banding")
  invisible(ss)
}

#' Pull provider(s) `metadata` tab back into each dataset's sidecar.
gs_pull_metadata_provider <- function(provider, sheets_yml_path = SHEETS_YML, execute = FALSE,
                                       metadata_dir = METADATA_DIR) {
  yml <- dm_load_sheets_yml(sheets_yml_path); entry <- yml[[provider]]
  if (is.null(entry$sheet_id) || !nzchar(entry$sheet_id)) {
    dcat("{provider}: no sheet_id in {sheets_yml_path} — SKIPPED (no sheet to pull from)")
    return(invisible(FALSE))
  }
  ss <- googlesheets4::as_sheets_id(entry$sheet_id)
  sheet_df <- tryCatch(googlesheets4::range_read(ss, sheet = DM_TAB, col_types = "c"),
                        error = function(e) NULL)
  if (is.null(sheet_df)) { dcat("{provider}: no {DM_TAB} tab in sheet — skipping"); return(invisible(FALSE)) }

  active_licenses <- calcofi4db::read_license_registry(LICENSE_CSV)
  active_licenses <- active_licenses$license[active_licenses$status == "active"]

  sidecars <- dm_provider_sidecars(provider, metadata_dir)
  any_diff <- FALSE
  for (dk in names(sidecars)) {
    p <- sidecars[[dk]]$path
    rows <- sheet_df[sheet_df$dataset_key == dk, , drop = FALSE]
    if (!nrow(rows)) next
    res <- dm_apply_pull_dataset(readLines(p, warn = FALSE), rows, licenses = active_licenses)
    if (length(res$errors)) { any_diff <- TRUE; dcat("{dk}: REFUSED — {paste(res$errors, collapse='; ')}") }
    if (nrow(res$diffs)) {
      any_diff <- TRUE
      dcat("{dk}: {nrow(res$diffs)} change(s)"); print(res$diffs, row.names = FALSE)
      if (isTRUE(execute)) { writeLines(res$lines, p); cat("  wrote ", p, "\n") }
    }
  }
  if (!isTRUE(execute)) cat("\ndry run — pass --execute to write\n")
  invisible(any_diff)
}

#' Push the `holdings` tab (the calcofi sheet only).
gs_push_holdings <- function(sheets_yml_path = SHEETS_YML, execute = FALSE, metadata_dir = METADATA_DIR) {
  holdings <- dm_all_holding_sidecars(metadata_dir)
  if (!length(holdings)) { dcat("holdings: no holding sidecars found — nothing to push"); return(invisible(NULL)) }
  rows <- do.call(rbind, Map(dm_holdings_row, names(holdings), holdings))
  dcat("push plan for holdings: {nrow(rows)} row(s) across {length(unique(rows$provider))} provider(s)")
  if (!isTRUE(execute)) { cat("dry run — pass --execute to write\n"); return(invisible(rows)) }

  yml <- dm_load_sheets_yml(sheets_yml_path); entry <- yml[[HOLDINGS_PROVIDER]]
  if (is.null(entry$sheet_id) || !nzchar(entry$sheet_id))
    stop(HOLDINGS_PROVIDER, ": no sheet_id in ", sheets_yml_path, call. = FALSE)
  ss <- googlesheets4::as_sheets_id(entry$sheet_id)
  googlesheets4::sheet_write(rows, ss = ss, sheet = HOLDINGS_TAB)
  props <- googlesheets4::sheet_properties(ss); sid <- props$id[props$name == HOLDINGS_TAB]
  reqs <- c(dm_protection_requests(sid, names(rows), dm_holdings_editable_cols()),
            list(dm_status_validation_request(sid, names(rows), nrow(rows))))
  googlesheets4::request_make(googlesheets4::request_generate(
    "sheets.spreadsheets.batchUpdate", params = list(spreadsheetId = as.character(ss), requests = reqs)))
  dcat("wrote {HOLDINGS_TAB} ({nrow(rows)} rows) + protection/validation")
  invisible(ss)
}

#' Pull the `holdings` tab back into every holding's sidecar.
gs_pull_holdings <- function(sheets_yml_path = SHEETS_YML, execute = FALSE, metadata_dir = METADATA_DIR) {
  yml <- dm_load_sheets_yml(sheets_yml_path); entry <- yml[[HOLDINGS_PROVIDER]]
  if (is.null(entry$sheet_id) || !nzchar(entry$sheet_id)) stop(HOLDINGS_PROVIDER, ": no sheet_id", call. = FALSE)
  ss <- googlesheets4::as_sheets_id(entry$sheet_id)
  sheet_df <- tryCatch(googlesheets4::range_read(ss, sheet = HOLDINGS_TAB, col_types = "c"), error = function(e) NULL)
  if (is.null(sheet_df)) { dcat("holdings: no {HOLDINGS_TAB} tab in sheet — skipping"); return(invisible(FALSE)) }
  holdings <- dm_all_holding_sidecars(metadata_dir)
  any_diff <- FALSE
  for (dk in names(holdings)) {
    p <- holdings[[dk]]$path
    row <- sheet_df[sheet_df$dataset_key == dk, , drop = FALSE]
    if (!nrow(row)) next
    res <- dm_apply_holdings_pull(readLines(p, warn = FALSE), as.list(row[1, ]))
    if (length(res$errors)) { any_diff <- TRUE; dcat("{dk}: REFUSED — {paste(res$errors, collapse='; ')}") }
    if (nrow(res$diffs)) {
      any_diff <- TRUE
      dcat("{dk}: {nrow(res$diffs)} change(s)"); print(res$diffs, row.names = FALSE)
      if (isTRUE(execute)) { writeLines(res$lines, p); cat("  wrote ", p, "\n") }
    }
  }
  if (!isTRUE(execute)) cat("\ndry run — pass --execute to write\n")
  invisible(any_diff)
}

# ============================================================================
# CLI
# ============================================================================

.main <- function(args = commandArgs(trailingOnly = TRUE)) {
  flags <- args[grepl("^--", args)]; pos <- args[!grepl("^--", args)]
  execute <- "--execute" %in% flags
  if (!length(pos)) stop("usage: Rscript scripts/sync_dataset_meta_sheets.R <push|pull> [provider] [--execute]", call. = FALSE)
  mode <- pos[1]; provider_arg <- if (length(pos) >= 2) pos[2] else NULL
  if (!mode %in% c("push", "pull")) stop("unknown mode '", mode, "' — expected push or pull", call. = FALSE)

  providers <- if (!is.null(provider_arg)) provider_arg else
    intersect(dm_provider_registry()$provider, names(dm_load_sheets_yml()))

  if (mode == "pull" || execute) options(dm.auth_user = dm_auth())

  for (pv in providers) {
    if (mode == "push") gs_push_metadata_provider(pv, execute = execute)
    else                gs_pull_metadata_provider(pv, execute = execute)
  }
  if (is.null(provider_arg) || provider_arg == HOLDINGS_PROVIDER) {
    if (mode == "push") gs_push_holdings(execute = execute)
    else                gs_pull_holdings(execute = execute)
  }
}

if (sys.nframe() == 0) .main()
