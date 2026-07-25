# libs/extract_accdb.R
# -----------------------------------------------------------------------------
# Reproducible extraction of an MS Access (.mdb/.accdb) database on macOS/Linux —
# no Windows VM, no Access install, nothing manual.
#
# Two engines, deliberately:
#
#   mdbtools  (brew install mdbtools / apt install mdbtools)
#     bulk table export + the system catalogs (MSysObjects, MSysRelationships).
#
#   Jackcess  (Java jars from Maven Central, driven by libs/java/DumpQueries.java)
#     saved-query SQL. AUTHORITATIVE.
#
# WHY BOTH: `mdb-queries` reconstructs the stored parse tree only partially — it
# silently drops JOIN clauses, GROUP BY, HAVING and column aliases, and emits
# `SELECT  FROM ` for queries it cannot parse. The output is plausible-looking and
# wrong: a LEFT JOIN find-unmatched query degrades into a cross join, inverting the
# meaning of the QA check it encodes. Jackcess walks the same tree faithfully. We run
# both and diff them (accdb_diff_query_sql()) so a regression in either engine
# surfaces instead of silently corrupting a ported rule.
#
# Tables are extracted as all-VARCHAR on purpose. This is an archival extraction;
# type coercion is a separate reviewable step, and CSV type-sniffing is exactly how
# you silently turn a sentinel into NA.
#
# Sourced + invoked from explore_accdb_hydro-master.qmd; also runnable headless via
# scripts/extract_accdb.sh.

# constants ----

ACCDB_MAVEN_BASE <- "https://repo1.maven.org/maven2"

# pinned so an extraction is reproducible; bump deliberately, never floating
ACCDB_JARS <- c(
  "jackcess-4.0.7.jar"         = "com/healthmarketscience/jackcess/jackcess/4.0.7",
  "commons-lang3-3.14.0.jar"   = "org/apache/commons/commons-lang3/3.14.0",
  "commons-logging-1.3.0.jar"  = "commons-logging/commons-logging/1.3.0")

# MSysObjects.Type -> label
ACCDB_OBJECT_TYPES <- c(
  "1"      = "table_local",
  "2"      = "database",
  "3"      = "container",
  "5"      = "query",
  "6"      = "table_linked",
  "8"      = "relationship",
  "-32768" = "form",
  "-32766" = "macro",
  "-32764" = "report",
  "-32761" = "module_vba",
  "-32758" = "user_or_group",
  "-32757" = "document_property",
  "-32756" = "data_access_page")

# MSysRelationships.grbit -> DAO RelationAttributeEnum bits
ACCDB_REL_FLAGS <- c(
  unique          = 1L,
  dont_enforce    = 2L,
  inherited       = 4L,
  update_cascade  = 256L,
  delete_cascade  = 4096L,
  join_left       = 16777216L,
  join_right      = 33554432L)

# tool discovery ----

#' Locate the external tools this file shells out to
#'
#' @return named list with `mdb_export`, `mdb_schema`, `mdb_queries`, `mdb_ver`, `java`
#' @details Two macOS traps. Homebrew's openjdk is keg-only, so a working `java` is
#'   frequently absent from PATH; and `/usr/bin/java` always exists as a stub that
#'   merely prints "Unable to locate a Java Runtime" and exits 1. So candidates are
#'   probed by actually running `-version`, never trusted for existing on disk.
accdb_tool_paths <- function() {
  java_works <- function(p) {
    if (!nzchar(p)) return(FALSE)
    status <- suppressWarnings(try(system2(
      p, args = "-version", stdout = FALSE, stderr = FALSE), silent = TRUE))
    !inherits(status, "try-error") && identical(status, 0L)
  }
  find_java <- function() {
    cands <- c(
      Sys.getenv("JAVA_HOME") |> (\(h) if (nzchar(h)) file.path(h, "bin", "java") else "")(),
      unname(Sys.which("java")),
      "/opt/homebrew/opt/openjdk/bin/java",
      "/usr/local/opt/openjdk/bin/java")
    home <- suppressWarnings(try(
      system2("/usr/libexec/java_home", stdout = TRUE, stderr = FALSE), silent = TRUE))
    if (!inherits(home, "try-error") && length(home) == 1 && nzchar(home)) {
      cands <- c(cands, file.path(home, "bin", "java"))
    }
    for (cand in cands) if (java_works(cand)) return(cand)
    ""
  }
  list(
    mdb_tables  = unname(Sys.which("mdb-tables")),
    mdb_export  = unname(Sys.which("mdb-export")),
    mdb_schema  = unname(Sys.which("mdb-schema")),
    mdb_queries = unname(Sys.which("mdb-queries")),
    mdb_ver     = unname(Sys.which("mdb-ver")),
    java        = find_java())
}

#' Fail loudly, with the install command, if a required tool is missing
accdb_require_tools <- function(need_java = TRUE) {
  tools <- accdb_tool_paths()
  missing <- character()
  if (!nzchar(tools$mdb_export)) missing <- c(missing, "mdbtools (brew install mdbtools | apt install mdbtools)")
  if (need_java && !nzchar(tools$java)) missing <- c(missing, "a JDK 11+ (brew install openjdk | apt install default-jdk)")
  if (length(missing) > 0) {
    stop("missing required tool(s):\n  - ", paste(missing, collapse = "\n  - "), call. = FALSE)
  }
  tools
}

#' Ensure the pinned Jackcess jars are cached locally, downloading if absent
#'
#' @param jar_dir cache directory (gitignored; defaults under data/cache)
#' @return the jar directory, invisibly
accdb_ensure_jars <- function(jar_dir = here::here("data/cache/jackcess")) {
  dir.create(jar_dir, showWarnings = FALSE, recursive = TRUE)
  for (jar in names(ACCDB_JARS)) {
    dest <- file.path(jar_dir, jar)
    if (file.exists(dest) && file.size(dest) > 0) next
    url <- paste(ACCDB_MAVEN_BASE, ACCDB_JARS[[jar]], jar, sep = "/")
    cat("accdb: downloading", jar, "\n")
    utils::download.file(url, dest, mode = "wb", quiet = TRUE)
    if (!file.exists(dest) || file.size(dest) == 0) {
      stop("failed to download ", url, call. = FALSE)
    }
  }
  invisible(jar_dir)
}

# helpers ----

#' Sanitize an Access object name into a filesystem-safe stem
#'
#' Access names contain spaces, `&`, `:`, `/` and `?`. The original name is always
#' preserved alongside in the emitted CSVs, so this is one-way by design.
accdb_safe_name <- function(x) {
  x |>
    gsub("[^A-Za-z0-9._-]+", "_", x = _) |>
    gsub("_+", "_", x = _) |>
    gsub("^_|_$", "", x = _)
}

#' Decode a MSysRelationships grbit bitmask into a comma-separated flag list
accdb_decode_rel_flags <- function(grbit) {
  vapply(grbit, function(g) {
    g <- suppressWarnings(as.integer(g))
    if (is.na(g)) return(NA_character_)
    hit <- names(ACCDB_REL_FLAGS)[bitwAnd(g, ACCDB_REL_FLAGS) == ACCDB_REL_FLAGS]
    if (length(hit) == 0) "" else paste(hit, collapse = ",")
  }, character(1), USE.NAMES = FALSE)
}

# read a table straight out of Access into a data.frame, via mdb-export
accdb_read <- function(db, table, tools = accdb_tool_paths()) {
  txt <- system2(
    tools$mdb_export,
    args   = c("-D", shQuote("%Y-%m-%d"), "-T", shQuote("%Y-%m-%d %H:%M:%S"),
               "-b", "strip", "-B", shQuote(db), shQuote(table)),
    stdout = TRUE, stderr = FALSE)
  if (length(txt) <= 1) {
    return(utils::read.csv(text = paste(c(txt, ""), collapse = "\n"),
                           colClasses = "character", check.names = FALSE))
  }
  utils::read.csv(text = paste(txt, collapse = "\n"),
                  colClasses = "character", check.names = FALSE)
}

# catalog ----

#' Access engine format string, e.g. "ACE12" (Access 2007) or "JET4"
accdb_version <- function(db, tools = accdb_tool_paths()) {
  system2(tools$mdb_ver, args = shQuote(db), stdout = TRUE, stderr = FALSE)[1]
}

#' List user tables (system tables excluded)
accdb_tables <- function(db, tools = accdb_tool_paths()) {
  tbls <- system2(tools$mdb_tables, args = c("-1", shQuote(db)),
                  stdout = TRUE, stderr = FALSE) |> trimws()
  tbls[nzchar(tbls)]
}

#' Full object inventory from MSysObjects, with decoded type labels
accdb_objects <- function(db, tools = accdb_tool_paths()) {
  d <- accdb_read(db, "MSysObjects", tools)
  keep <- intersect(c("Id", "ParentId", "Name", "Type", "DateCreate", "DateUpdate"), names(d))
  d <- d[, keep, drop = FALSE]
  d$object_type <- unname(ACCDB_OBJECT_TYPES[as.character(d$Type)])
  d$object_type[is.na(d$object_type)] <- paste0("unknown_", d$Type[is.na(d$object_type)])
  names(d) <- tolower(names(d))
  d[order(d$object_type, d$name), ]
}

#' Declared referential-integrity graph from MSysRelationships
accdb_relationships <- function(db, tools = accdb_tool_paths()) {
  d <- accdb_read(db, "MSysRelationships", tools)
  out <- data.frame(
    relationship  = d$szRelationship,
    from_table    = d$szObject,
    from_column   = d$szColumn,
    to_table      = d$szReferencedObject,
    to_column     = d$szReferencedColumn,
    grbit         = d$grbit,
    flags         = accdb_decode_rel_flags(d$grbit),
    stringsAsFactors = FALSE)
  out$enforced <- !grepl("dont_enforce", out$flags)
  out[order(out$relationship), ]
}

# tables -> parquet ----

#' Export every table to Parquet (all-VARCHAR), returning a manifest
#'
#' @param db       path to the .accdb
#' @param out_dir  directory for `<safe_name>.parquet`
#' @param tables   character vector of table names; defaults to all user tables
#' @return data.frame: table, safe_name, parquet, n_row, n_col, ok, error
accdb_export_tables <- function(
    db,
    out_dir,
    tables  = NULL,
    tools   = accdb_tool_paths(),
    verbose = TRUE) {

  stopifnot(requireNamespace("calcofi4db", quietly = TRUE))
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  if (is.null(tables)) tables <- accdb_tables(db, tools)

  con <- calcofi4db::get_duckdb_con(":memory:")
  on.exit(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE), add = TRUE)

  rows <- lapply(seq_along(tables), function(i) {
    tbl  <- tables[i]
    safe <- accdb_safe_name(tbl)
    pq   <- file.path(out_dir, paste0(safe, ".parquet"))
    csv  <- tempfile(fileext = ".csv")
    on.exit(unlink(csv), add = TRUE)

    if (verbose) cat(sprintf("  [%3d/%3d] %-45s", i, length(tables), substr(tbl, 1, 45)))

    res <- try({
      status <- system2(
        tools$mdb_export,
        args   = c("-D", shQuote("%Y-%m-%d"), "-T", shQuote("%Y-%m-%d %H:%M:%S"),
                   "-b", "strip", "-B", shQuote(db), shQuote(tbl)),
        stdout = csv, stderr = FALSE)
      if (!identical(status, 0L)) stop("mdb-export exited ", status)

      # all_varchar: archival fidelity. sniffing here is how sentinels become NA.
      DBI::dbExecute(con, sprintf(
        "COPY (SELECT * FROM read_csv(%s, all_varchar = true, header = true,
                                      sample_size = -1, strict_mode = false))
         TO %s (FORMAT parquet, COMPRESSION zstd)",
        DBI::dbQuoteString(con, csv), DBI::dbQuoteString(con, pq)))

      DBI::dbGetQuery(con, sprintf(
        "SELECT COUNT(*) AS n FROM read_parquet(%s)", DBI::dbQuoteString(con, pq)))$n
    }, silent = TRUE)

    if (inherits(res, "try-error")) {
      if (verbose) cat("FAILED\n")
      return(data.frame(
        table = tbl, safe_name = safe, parquet = NA_character_,
        n_row = NA_integer_, n_col = NA_integer_, ok = FALSE,
        error = trimws(as.character(res)), stringsAsFactors = FALSE))
    }

    n_col <- length(DBI::dbGetQuery(con, sprintf(
      "SELECT * FROM read_parquet(%s) LIMIT 0", DBI::dbQuoteString(con, pq))))
    if (verbose) cat(sprintf("%10s rows\n", format(res, big.mark = ",")))

    data.frame(
      table = tbl, safe_name = safe, parquet = basename(pq),
      n_row = as.integer(res), n_col = n_col, ok = TRUE, error = "",
      stringsAsFactors = FALSE)
  })

  do.call(rbind, rows)
}

# queries ----

#' Extract saved-query SQL with Jackcess (authoritative)
#'
#' @return data.frame: query_name, query_type, ok, error, sql
accdb_queries_jackcess <- function(
    db,
    jar_dir = accdb_ensure_jars(),
    java    = accdb_tool_paths()$java,
    dump_java = here::here("libs/java/DumpQueries.java")) {

  stopifnot(nzchar(java), file.exists(dump_java))
  out_csv <- tempfile(fileext = ".csv")
  on.exit(unlink(out_csv), add = TRUE)

  msg <- system2(
    java,
    args   = c("-cp", shQuote(file.path(jar_dir, "*")),
               shQuote(dump_java), shQuote(db), shQuote(out_csv)),
    stdout = TRUE, stderr = TRUE)
  if (!file.exists(out_csv)) {
    stop("Jackcess extraction produced no output:\n", paste(msg, collapse = "\n"), call. = FALSE)
  }
  cat("accdb: jackcess", paste(grep("^queries=", msg, value = TRUE), collapse = " "), "\n")

  d <- utils::read.csv(out_csv, colClasses = "character", check.names = FALSE)
  d$ok <- tolower(d$ok) == "true"
  d
}

#' Extract saved-query SQL with mdbtools — LOSSY, cross-check only
#'
#' Never port a rule from this output. See the file header for why.
accdb_queries_mdbtools <- function(db, query_names, tools = accdb_tool_paths()) {
  sql <- vapply(query_names, function(q) {
    txt <- suppressWarnings(system2(
      tools$mdb_queries, args = c(shQuote(db), shQuote(q)),
      stdout = TRUE, stderr = FALSE))
    if (length(txt) == 0) "" else paste(trimws(txt), collapse = " ")
  }, character(1), USE.NAMES = FALSE)
  data.frame(query_name = query_names, sql_mdbtools = sql, stringsAsFactors = FALSE)
}

#' Compare the two extractors and classify the divergence
#'
#' Expected shape of the result: mdbtools is a strict subset — it should never
#' contain a JOIN/GROUP BY/HAVING that Jackcess lacks. A row where
#' `mdbtools_has_extra` is TRUE means one of the engines regressed; investigate
#' before trusting either.
accdb_diff_query_sql <- function(jackcess, mdbtools) {
  d <- merge(
    jackcess[, c("query_name", "query_type", "ok", "sql")],
    mdbtools, by = "query_name", all.x = TRUE)

  has <- function(x, kw) grepl(kw, x, ignore.case = TRUE)
  d$jk_join   <- has(d$sql, "\\bjoin\\b")
  d$md_join   <- has(d$sql_mdbtools, "\\bjoin\\b")
  d$jk_group  <- has(d$sql, "\\bgroup by\\b")
  d$md_group  <- has(d$sql_mdbtools, "\\bgroup by\\b")

  d$mdbtools_empty      <- !nzchar(trimws(d$sql_mdbtools)) |
                            grepl("^SELECT\\s+FROM\\s*$", trimws(d$sql_mdbtools))
  d$mdbtools_lost_join  <- d$jk_join  & !d$md_join
  d$mdbtools_lost_group <- d$jk_group & !d$md_group
  d$mdbtools_has_extra  <- (!d$jk_join & d$md_join) | (!d$jk_group & d$md_group)

  d[order(d$query_name), ]
}

# driver ----

#' Extract an Access database into committed metadata + gitignored Parquet
#'
#' Splits outputs by whether a human needs to review them in a diff:
#'   `dir_meta` (committed) — the SQL corpus, catalogs and manifests. ~100 KB.
#'   `dir_data` (gitignored) — `tables/*.parquet`. GBs.
#'
#' @param db       path to the .accdb
#' @param dir_meta committed output dir, e.g. metadata/calcofi/hydro-master/accdb
#' @param dir_data generated output dir, e.g. data/accdb/calcofi_hydro-master
#' @param tables   restrict to these tables (default: all user tables)
#' @return a list of the manifests, invisibly
extract_accdb <- function(
    db,
    dir_meta,
    dir_data,
    tables  = NULL,
    verbose = TRUE) {

  stopifnot(file.exists(db))
  tools <- accdb_require_tools()
  dir.create(dir_meta, showWarnings = FALSE, recursive = TRUE)
  dir.create(dir_data, showWarnings = FALSE, recursive = TRUE)
  dir_sql <- file.path(dir_meta, "sql")
  dir.create(dir_sql, showWarnings = FALSE, recursive = TRUE)

  ver <- accdb_version(db, tools)
  cat("accdb:", basename(db), "-", ver, "\n")

  # -- catalogs ----
  objects <- accdb_objects(db, tools)
  rels    <- accdb_relationships(db, tools)
  utils::write.csv(objects, file.path(dir_meta, "objects.csv"), row.names = FALSE, na = "")
  utils::write.csv(rels,    file.path(dir_meta, "relationships.csv"), row.names = FALSE, na = "")

  schema <- system2(tools$mdb_schema, args = shQuote(db), stdout = TRUE, stderr = FALSE)
  writeLines(schema, file.path(dir_meta, "schema.sql"))
  cat("accdb:", nrow(objects), "objects,", nrow(rels), "relationships,",
      length(schema), "schema lines\n")

  # -- queries (Jackcess authoritative, mdbtools cross-check) ----
  jk <- accdb_queries_jackcess(db)
  md <- accdb_queries_mdbtools(db, jk$query_name, tools)
  df <- accdb_diff_query_sql(jk, md)

  for (i in seq_len(nrow(jk))) {
    writeLines(
      c(paste0("-- query: ", jk$query_name[i]),
        paste0("-- type:  ", jk$query_type[i]),
        paste0("-- source: ", basename(db), " (", ver, "), extracted via Jackcess"),
        if (!jk$ok[i]) paste0("-- EXTRACTION FAILED: ", jk$error[i]),
        "",
        jk$sql[i]),
      file.path(dir_sql, paste0(accdb_safe_name(jk$query_name[i]), ".sql")))
  }
  utils::write.csv(jk, file.path(dir_meta, "queries.csv"), row.names = FALSE, na = "")
  utils::write.csv(df[, c("query_name", "query_type", "ok", "mdbtools_empty",
                          "mdbtools_lost_join", "mdbtools_lost_group",
                          "mdbtools_has_extra")],
                   file.path(dir_meta, "query_sql_diff.csv"), row.names = FALSE, na = "")
  cat("accdb:", nrow(jk), "queries (", sum(!jk$ok), "failed ), ",
      sum(df$mdbtools_lost_join), "lost a JOIN under mdbtools\n")

  # -- tables -> parquet ----
  cat("accdb: exporting tables to", dir_data, "\n")
  manifest <- accdb_export_tables(
    db, file.path(dir_data, "tables"), tables = tables, tools = tools, verbose = verbose)
  utils::write.csv(manifest, file.path(dir_meta, "tables.csv"), row.names = FALSE, na = "")
  cat("accdb:", sum(manifest$ok), "tables ok,", sum(!manifest$ok), "failed;",
      format(sum(manifest$n_row, na.rm = TRUE), big.mark = ","), "rows total\n")

  invisible(list(version = ver, objects = objects, relationships = rels,
                 queries = jk, query_diff = df, tables = manifest))
}
