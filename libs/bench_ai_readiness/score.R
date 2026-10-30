# score the AI-readiness pilot: reference answers from the release, agent answers from transcripts
librarian::shelf(DBI, dplyr, duckdb, jsonlite, purrr, readr, stringr, tibble, tidyr, yaml, quiet = T)

# hosts and paths that mark a session reaching past its condition (the sandbox should already block them);
# matched only in the urls and paths a tool call uses, so grepping a page for the word "zenodo" is not a reach
BENCH_FORBIDDEN <- c(
  "calcofi.io", "storage.googleapis.com/calcofi", "calcofi-db", "zenodo.org", "bench_ai_release",
  "_big/calcofi", "Github/CalCOFI")
# loading the integrated release through a client package
BENCH_FORBIDDEN_PKG <- "library\\(calcofi4r|require\\(calcofi4r|import calcofi4py|install[^\\n]{0,40}calcofi4(r|py)"

# does one tool-call json line reach a forbidden url, path or client package?
bench_tool_forbidden <- function(l) {
  refs <- stringr::str_extract_all(l, "(https?://|~/|/Users/)[^\\s\"'\\\\)]+")[[1]]
  any(purrr::map_lgl(BENCH_FORBIDDEN, \(p) any(stringr::str_detect(refs, stringr::fixed(p))))) || stringr::str_detect(l, BENCH_FORBIDDEN_PKG)
}
stopifnot(
  !bench_tool_forbidden('{"command":"grep -iE \'erddap|zenodo|doi\' page.html"}'),
  !bench_tool_forbidden('{"query":"ZooScan zenodo dataset"}'),
   bench_tool_forbidden('{"command":"curl -sL https://zenodo.org/records/1"}'),
   bench_tool_forbidden('{"url":"https://calcofi.io/docs"}'),
   bench_tool_forbidden('{"command":"ls ~/_big/calcofi/parquet"}'),
   bench_tool_forbidden('{"command":"Rscript -e \'library(calcofi4r)\'"}'))

read_bench_questions <- function(f = here::here("libs/bench_ai_readiness/questions.yml")) {
  y <- yaml::read_yaml(f)
  purrr::map_dfr(y$questions, \(x) tibble(
    id      = x$id,
    tier    = x$tier,
    kind    = x$kind,
    tol_abs = x$tol$abs %||% NA_real_,
    tol_rel = x$tol$rel %||% NA_real_,
    text    = x$text,
    sql     = x$sql))
}

# reference answer per question: the first column of the first row of its sql
bench_reference <- function(q, db = file.path(Sys.getenv("BENCH_RELEASE_DIR", "~/_big/bench_ai_release"), "release.duckdb")) {
  drv <- duckdb::duckdb(path.expand(db), read_only = TRUE)
  con <- DBI::dbConnect(drv)
  on.exit({ DBI::dbDisconnect(con); duckdb::duckdb_shutdown(drv) }, add = TRUE)
  q |> mutate(reference = purrr::map_chr(sql, \(s) as.character(DBI::dbGetQuery(con, s)[[1]][1])))
}

# the value after the last "FINAL ANSWER:" in the session's reply
parse_final_answer <- function(txt) {
  m <- stringr::str_match_all(txt %||% "", "(?i)FINAL ANSWER:\\s*\\**\\s*([^\\n*]+)")[[1]]
  if (nrow(m) == 0) return(NA_character_)
  stringr::str_trim(m[nrow(m), 2])
}

# is one answer correct? numbers within tolerance, names by match, unanswerable must be declined
score_answer <- function(answer, kind, reference, tol_abs = NA, tol_rel = NA) {
  declined <- !is.na(answer) && stringr::str_detect(answer, "(?i)not available")
  if (kind == "none") return(declined)
  if (is.na(answer) || declined) return(FALSE)
  if (kind == "text") return(stringr::str_detect(tolower(answer), stringr::fixed(tolower(reference))))
  a <- suppressWarnings(as.numeric(stringr::str_extract(gsub(",", "", answer), "-?[0-9]*\\.?[0-9]+(e-?[0-9]+)?")))
  r <- as.numeric(reference)
  if (is.na(a)) return(FALSE)
  tol <- max(c(if (!is.na(tol_abs)) tol_abs, if (!is.na(tol_rel)) abs(r) * tol_rel, 1e-9))
  abs(a - r) <= tol + 1e-9
}

# one row per session: answer, cost, turns, seconds, and any reach past its condition
collect_bench_runs <- function(run_dir) {
  dirs <- list.dirs(run_dir, recursive = TRUE) |> purrr::keep(\(d) file.exists(file.path(d, "transcript.jsonl")))
  purrr::map_dfr(dirs, \(d) {
    res <- tryCatch(jsonlite::fromJSON(file.path(d, "result.json")), error = \(e) list())
    tr  <- readLines(file.path(d, "transcript.jsonl"), warn = FALSE)
    tool_inputs <- tr[stringr::str_detect(tr, '"type":"tool_use"')]
    parts <- stringr::str_match(d, "/([a-z]+)/([A-Z][0-9])_r([0-9]+)$")
    tibble(
      condition  = parts[2],
      id         = parts[3],
      rep        = as.integer(parts[4]),
      answer     = parse_final_answer(res$result),
      cost_usd   = res$total_cost_usd %||% NA_real_,
      turns      = res$num_turns %||% NA_integer_,
      seconds    = (res$duration_ms %||% NA_real_) / 1000,
      completed  = identical(res$subtype, "success"),
      n_tool_calls   = length(tool_inputs),
      n_forbidden    = sum(purrr::map_lgl(tool_inputs, bench_tool_forbidden)),
      n_sandbox_deny = sum(stringr::str_count(tr, "sandbox_violations>\\\\n deny|deny network-outbound|deny file-read")))
  })
}

# every run folder under runs_root matching pattern, with its model and effort from config.json
collect_bench_configs <- function(runs_root, pattern = "^2026-10-30_") {
  dirs <- list.dirs(path.expand(runs_root), recursive = FALSE) |> purrr::keep(\(d) grepl(pattern, basename(d)))
  purrr::map_dfr(dirs, \(d) {
    cfg <- jsonlite::fromJSON(file.path(d, "config.json"))
    collect_bench_runs(d) |>
      mutate(run_id = basename(d), model = sub("^claude-", "", cfg$model), effort = cfg$effort, .before = 1)
  })
}

score_bench_runs <- function(runs, ref) {
  runs |>
    left_join(ref |> select(id, tier, kind, tol_abs, tol_rel, reference), by = "id") |>
    mutate(correct = purrr::pmap_lgl(list(answer, kind, reference, tol_abs, tol_rel), score_answer))
}
