# libs/build_qc_protocol.R
# -----------------------------------------------------------------------------
# Assemble the QA/QC protocol document from the rule registry itself.
#
# WHY GENERATED RATHER THAN WRITTEN. A hand-written protocol describing rules that
# live in metadata/qc_rules/ would drift the first time a threshold moved, and the
# drift would be invisible — the document would keep describing a check that no
# longer runs that way. So every per-rule section here is assembled at render time
# from the same three sources the engine reads:
#
#   rules.csv          the index: type, severity, target, scope, params, provenance
#   sql/<file>.sql     the check itself, shown verbatim
#   the SQL's own leading comment block, which is where the rationale, the
#                      threshold derivation and the known limitations already live
#
# That last point is deliberate. The rules were written with their reasoning in a
# header comment, next to the code it justifies. Harvesting those comments means
# the protocol cannot say something the rule file does not, and a reviewer editing
# a rule updates the documentation by editing the thing they were already editing.
#
# qc_protocol_check() then refuses to publish a protocol that has fallen behind:
# an active rule missing from the rendered document, or carrying no rationale at
# all, fails the build rather than shipping an undocumented check.
#
# Sourced from qc_protocol.qmd. Pure text assembly — no database, no network.

suppressMessages({
  library(dplyr); library(stringr); library(glue); library(purrr)
})

# -- rationale extraction ------------------------------------------------------

#' Split a rule's SQL into its leading comment block and the query
#'
#' The block ends at the first line that is not a `--` comment and not blank.
#' A trailing `-- params: {{a}} {{b}}` line is dropped: parameters are rendered as
#' a table, and repeating them as prose invites the two to disagree.
qc_sql_rationale <- function(sql) {
  # a parked rule may have no SQL at all — that is a registry state, not an error
  if (length(sql) != 1 || is.na(sql) || !nzchar(sql))
    return(list(prose = "", sql = ""))
  lines <- str_split(sql, "\n")[[1]]
  is_c  <- str_detect(lines, "^\\s*--")
  is_b  <- !nzchar(str_trim(lines))

  n <- 0L
  for (i in seq_along(lines)) {
    if (is_c[i] || is_b[i]) n <- i else break
  }
  head_lines <- if (n > 0) lines[seq_len(n)] else character(0)
  body       <- if (n < length(lines)) lines[(n + 1):length(lines)] else character(0)

  prose <- head_lines |>
    str_remove("^\\s*--\\s?") |>
    discard(\(x) str_detect(x, "^params:")) |>
    str_trim(side = "right")
  # collapse the blank line the params: removal can leave at the end
  while (length(prose) && !nzchar(str_trim(tail(prose, 1)))) prose <- head(prose, -1)

  list(prose = paste(qc_fence_aligned(prose), collapse = "\n"),
       sql   = paste(str_trim(paste(body, collapse = "\n"), side = "both")))
}

#' Preserve the aligned evidence tables inside a rule's comment block
#'
#' Several rules record their threshold derivation as a hand-aligned little table
#' inside the SQL header — the spike rule's naive-vs-neighbour-agreement counts,
#' the calibration thresholds per property. Markdown collapses runs of spaces, so
#' those arrive as one unreadable paragraph. Any run of indented lines is fenced
#' instead, which keeps the alignment that made them worth writing.
qc_fence_aligned <- function(lines) {
  if (!length(lines)) return(lines)
  indented <- str_detect(lines, "^\\s{2,}\\S")
  out <- character(0)
  i <- 1L
  while (i <= length(lines)) {
    if (!indented[i]) {
      out <- c(out, lines[i]); i <- i + 1L; next
    }
    j <- i
    # a blank line inside an indented run keeps the run going
    while (j < length(lines) &&
           (indented[j + 1L] || !nzchar(str_trim(lines[j + 1L])))) j <- j + 1L
    while (j > i && !nzchar(str_trim(lines[j]))) j <- j - 1L
    out <- c(out, "", "```", lines[i:j], "```", "")
    i <- j + 1L
  }
  out
}

# -- per-rule markdown ---------------------------------------------------------

SCOPE_LABEL <- c(
  all    = "whole dataset",
  cruise = "one cruise at a time (reads the full-resolution scans)")

#' Markdown for one rule
#'
#' @param rule one row of [calcofi4db::qc_read_rules()]
#' @param show_sql FALSE when an earlier rule already displayed this SQL file —
#'   several rules are the same query under different parameters, and repeating
#'   80 lines of SQL three times makes the document harder to read, not more
#'   complete. The shared file is named and linked instead.
#' @param shared_with rule_key that displayed the SQL, when `show_sql` is FALSE
qc_protocol_rule_md <- function(rule, show_sql = TRUE, shared_with = NA_character_) {
  r     <- as.list(rule)
  parts <- qc_sql_rationale(r$sql %||% "")

  prm <- r$params
  if (is.list(prm) && length(prm) == 1 && is.list(prm[[1]])) prm <- prm[[1]]

  facts <- c(
    glue("| checks | {r$description} |"),
    glue("| type | {r$rule_type} |"),
    glue("| severity | `{r$severity}` |"),
    glue("| runs against | `{r$target}` |"),
    glue("| scope | {SCOPE_LABEL[[r$scope %||% 'all']] %||% r$scope} |"))

  if (!is.na(r$requires_types) && nzchar(str_trim(r$requires_types))) {
    need <- str_split(r$requires_types, ",")[[1]] |> str_trim()
    facts <- c(facts, glue(
      "| requires | {paste0('`', need, '`', collapse = ', ')} — absent means ",
      "**skip**, never pass |"))
  }
  if (!is.na(r$source_query) && nzchar(str_trim(r$source_query))) {
    # `TQ - <name>` in the registry means a FAMILY of Access queries, not one
    # query called "<name>" — render it as such rather than as a broken citation
    src <- if (str_detect(r$source_query, "<name>"))
      glue("the Access master's `{str_remove(r$source_query, ' *<name>')}` ",
           "test family") else
      glue("Access master query `{r$source_query}`")
    facts <- c(facts, glue("| ported from | {src} |"))
  }
  if (!isTRUE(r$active)) {
    facts <- c(facts, "| status | **parked** — not run |")
  }

  md <- c(
    glue("### `{r$rule_key}` {{#rule-{r$rule_key}}}"), "",
    "| | |", "|---|---|", facts, "")

  if (length(prm)) {
    md <- c(md,
      "**Parameters**", "",
      "| parameter | value |", "|---|---|",
      unlist(imap(prm, \(v, k) glue("| `{k}` | `{v}` |"))), "")
  }

  has_sql <- !is.na(r$sql_file) && nzchar(str_trim(r$sql_file %||% ""))

  if (nzchar(parts$prose)) {
    md <- c(md, parts$prose, "")
  } else if (!has_sql) {
    md <- c(md, glue(
      "No query is written for this rule. The reason it is parked rather than ",
      "implemented is the registry note below — which is the point of keeping it ",
      "registered."), "")
  } else {
    md <- c(md, "*No rationale recorded in the rule's SQL header.*", "")
  }

  if (!is.na(r$notes) && nzchar(str_trim(r$notes))) {
    md <- c(md, glue("**Registry note.** {r$notes}"), "")
  }

  if (has_sql && show_sql) {
    md <- c(md,
      glue("::: {{.callout-note collapse=\"true\" ",
           "title=\"SQL — metadata/qc_rules/sql/{r$sql_file}\"}}"),
      "```sql", parts$sql, "```", ":::", "")
  } else if (has_sql) {
    md <- c(md, glue(
      "The query is `metadata/qc_rules/sql/{r$sql_file}`, shown under ",
      "[`{shared_with}`](#rule-{shared_with}) — this rule is the same check with ",
      "different parameters."), "")
  }

  paste(md, collapse = "\n")
}

#' Markdown for a set of rules, sharing SQL between rules that reuse a file
#'
#' @param rules rows of [calcofi4db::qc_read_rules()]
#' @param group_by column to group sections under (`rule_type`), or NULL for flat
qc_protocol_markdown <- function(rules, group_by = "rule_type") {
  seen <- character(0)   # sql_file -> first rule_key that displayed it
  out  <- character(0)

  emit <- function(idx) {
    for (i in idx) {
      f       <- rules$sql_file[i]
      has_sql <- !is.na(f) && nzchar(f)
      first   <- has_sql && !(f %in% names(seen))
      if (first) seen[[f]] <<- rules$rule_key[i]
      out <<- c(out, qc_protocol_rule_md(
        rules[i, ],
        show_sql    = first,
        shared_with = if (has_sql && !first) seen[[f]] else NA_character_), "")
    }
  }

  if (is.null(group_by)) {
    emit(seq_len(nrow(rules)))
  } else {
    for (g in unique(rules[[group_by]])) {
      out <- c(out, glue("## {str_to_title(g)} rules"), "")
      emit(which(rules[[group_by]] == g))
    }
  }
  paste(out, collapse = "\n")
}

# -- the guard -----------------------------------------------------------------

#' Refuse to publish a protocol that has fallen behind the registry
#'
#' Two failures, both silent otherwise: a rule that runs but is not described, and
#' a rule described only by its one-line `description` with no reasoning anywhere.
#' Either makes the protocol a document a reviewer cannot rely on.
#'
#' @param rules the FULL registry (`active_only = FALSE`)
#' @param md the assembled markdown
#' @return `TRUE`, invisibly
qc_protocol_check <- function(rules, md) {
  active <- rules[rules$active, , drop = FALSE]

  # as.character(): fixed() warns on a glue object, once per rule
  missing <- active$rule_key[!vapply(
    active$rule_key,
    \(k) str_detect(md, fixed(as.character(glue("#rule-{k}")))), logical(1))]
  if (length(missing)) {
    stop("active rule(s) absent from the protocol: ",
         paste(missing, collapse = ", "),
         "\n  every rule that runs must be documented before it can be published",
         call. = FALSE)
  }

  undoc <- active$rule_key[vapply(
    seq_len(nrow(active)),
    \(i) !nzchar(qc_sql_rationale(active$sql[i])$prose), logical(1))]
  if (length(undoc)) {
    stop("active rule(s) with no rationale in their SQL header: ",
         paste(undoc, collapse = ", "),
         "\n  add a leading -- comment block saying what it checks, where the",
         " threshold came from, and what it cannot see", call. = FALSE)
  }

  invisible(TRUE)
}

`%||%` <- function(x, y) if (is.null(x)) y else x
