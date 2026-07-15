#!/usr/bin/env Rscript
# build_workflows_index.R
#
# Generates _output/_data/workflows.yml, the data file that drives the
# https://calcofi.io/workflows/ landing page (_output/index.html, rendered by
# Jekyll). One entry per published _output/*.html, enriched with the `calcofi:`
# YAML front-matter block from its *.qmd / *.Rmd source and grouped into
# priority-ordered categories: ingest -> publish -> release -> reference -> other.
#
# Re-run whenever notebooks are added/removed/retitled, then commit the result:
#   Rscript scripts/build_workflows_index.R
# (could later be wired into the targets pipeline as a release_database caboose
# chunk, or into .github/workflows/jekyll-gh-pages.yml before the Jekyll build.)

librarian::shelf(rmarkdown, yaml, quiet = TRUE)

# resolve workflows dir (expects to run from repo root, or one level up) ----
wd <- getwd()
if (!dir.exists(file.path(wd, "_output")))
  stop("run from the workflows/ repo root (no ./_output found)")
out_dir  <- file.path(wd, "_output")
data_dir <- file.path(out_dir, "_data")
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || identical(a, "")) b else a
oneline <- function(x) trimws(gsub("[[:space:]]+", " ", paste(x, collapse = " ")))

# provider display labels + ordering within the ingest section ----
provider_label <- c(calcofi = "CalCOFI", swfsc = "SWFSC", pic = "SIO PIC",
                    `cce-lter` = "CCE-LTER", sccoos = "SCCOOS")
provider_order <- names(provider_label)

# category definitions, in display order ----
categories <- list(
  ingest    = list(title = "Ingest",
                   blurb = "Acquire, standardize, and load a source dataset into the integrated database. Cards are grouped by data provider.",
                   layout = "cards", grouped = TRUE),
  publish   = list(title = "Publish",
                   blurb = "Push released tables out to external repositories (ERDDAP, OBIS).",
                   layout = "cards", grouped = FALSE),
  release   = list(title = "Release & pipeline",
                   blurb = "Freeze a versioned release and the maintenance utilities that support the pipeline.",
                   layout = "list", grouped = FALSE),
  reference = list(title = "Reference & plans",
                   blurb = "Planning and reference notebooks. (Candidate to fold into calcofi.io/docs/.)",
                   layout = "list", grouped = FALSE),
  other     = list(title = "Other notebooks",
                   blurb = "Exploratory analyses and legacy load scripts, kept for reference.",
                   layout = "list", grouped = FALSE))

classify <- function(base, cc) {
  wt <- cc$workflow_type %||% ""
  if (!is.null(cc)) {
    if (wt %in% c("ingest", "spatial")) return("ingest")
    if (wt == "publish") return("publish")
    if (wt == "release") return("release")
    if (wt == "reference") return("reference")
  }
  if (grepl("^publish_", base)) return("publish")
  if (grepl("^(release|update|sync|clean)_", base) || base == "load_views") return("release")
  if (base == "README_PLAN") return("reference")
  "other"
}

# find the *.qmd / *.Rmd source for a rendered html base name ----
find_source <- function(base) {
  for (ext in c(".qmd", ".Rmd", ".rmd"))
    if (file.exists(file.path(wd, paste0(base, ext)))) return(file.path(wd, paste0(base, ext)))
  NA_character_
}

# DB-derived temporal coverage from the latest frozen release's metadata.json
# (dataset_key -> "YYYY-MM to YYYY-MM"), computed in release_database.qmd from the
# real obs/sample datetimes. Best-effort: falls back to static coverage if the
# release sidecar can't be fetched (e.g. offline CI).
observed_coverage <- tryCatch({
  suppressWarnings(librarian::shelf(jsonlite, quiet = TRUE))
  base_url <- "https://storage.googleapis.com/calcofi-db/ducklake/releases"
  ver  <- trimws(readLines(url(file.path(base_url, "latest.txt")), warn = FALSE)[1])
  meta <- jsonlite::fromJSON(file.path(base_url, ver, "metadata.json"), simplifyVector = FALSE)
  obs  <- list()
  for (k in names(meta$datasets)) {
    o <- meta$datasets[[k]]$coverage_temporal_observed
    if (!is.null(o) && nzchar(o)) obs[[k]] <- o
  }
  cat(sprintf("observed temporal coverage for %d datasets from release %s\n", length(obs), ver))
  obs
}, error = function(e) {
  message("observed coverage unavailable (", conditionMessage(e), ") — using static coverage_temporal")
  list()
})

# build the pipeline DAG as Mermaid directly from the calcofi: front-matter
# (target_name + dependency + workflow_type) — the same fields build_targets_list()
# uses — so it needs no `targets` install. Nodes are grouped into subgraphs by
# workflow type and color-coded via classDef.
build_dag_mermaid <- function(recs) {
  # only genuine pipeline targets (a calcofi: block in an ingest/publish/release
  # category) — excludes the disconnected explore_*/legacy "other" + reference
  # notebooks that clutter the graph and aren't part of tar_make().
  cats       <- c("ingest", "publish", "release")
  tr <- Filter(function(r) isTRUE(r$has_meta) && r$category %in% cats && nzchar(r$target), recs)
  if (!length(tr)) return("")
  type_col   <- c(ingest = "#4dabf7", publish = "#20c997", release = "#f06595")
  type_title <- c(ingest = "Ingest", publish = "Publish", release = "Release")
  sid <- function(t) gsub("[^A-Za-z0-9_]", "_", t)
  all_targets <- vapply(tr, function(r) r$target, "")
  auto_deps   <- all_targets[vapply(tr, function(r) r$category, "") == "ingest"]

  lines <- "graph LR"
  for (cid in cats) {
    incat <- Filter(function(r) r$category == cid, tr)
    if (!length(incat)) next
    lines <- c(lines, sprintf("  subgraph %s [%s]", cid, type_title[[cid]]), "    direction LR")
    for (r in incat)
      lines <- c(lines, sprintf('    %s["%s"]:::%s', sid(r$target), r$target, cid))
    lines <- c(lines, "  end")
  }
  for (r in tr) {
    dv <- unlist(r$deps)
    if (length(dv) && any(dv == "auto")) dv <- setdiff(auto_deps, r$target)
    for (d in dv[dv %in% all_targets]) lines <- c(lines, sprintf("  %s --> %s", sid(d), sid(r$target)))
  }
  for (cid in names(type_col))
    lines <- c(lines, sprintf("  classDef %s fill:%s,stroke:#00000066,color:#10161c;", cid, type_col[[cid]]))
  paste(lines, collapse = "\n")
}

# build one record per published page ----
htmls <- sort(list.files(out_dir, pattern = "[.]html$"))
htmls <- htmls[!basename(htmls) %in% c("index.html")]

recs <- lapply(htmls, function(h) {
  base <- sub("[.]html$", "", h)
  src  <- find_source(base)
  fm   <- if (!is.na(src)) tryCatch(rmarkdown::yaml_front_matter(src), error = function(e) list()) else list()
  cc   <- fm$calcofi
  dm   <- cc$dataset_meta
  cat_id <- classify(base, cc)

  prov   <- tolower(cc$provider %||% (if (cat_id == "ingest") "calcofi" else ""))
  ds_key <- if (nzchar(prov) && !is.null(cc$dataset)) paste0(prov, "_", cc$dataset) else ""
  # DB-derived temporal extent (from the frozen release) beats the static
  # coverage_temporal in the QMD front-matter; fall back to the static string.
  cov <- observed_coverage[[ds_key]] %||% dm$coverage_temporal %||% ""

  list(
    base        = base,
    url         = h,
    title       = oneline(fm$title %||% base),
    category    = cat_id,
    has_meta    = !is.null(cc),
    provider    = prov,
    target      = oneline(cc$target_name %||% base),
    deps        = cc$dependency,
    dataset_name= oneline(dm$dataset_name %||% ""),
    description = oneline(dm$description %||% ""),
    coverage    = oneline(cov),
    color       = cc$erd$color %||% "",
    link_calcofi_org = dm$link_calcofi_org %||% "",
    link_data_source = dm$link_data_source %||% "",
    source_qmd  = if (is.na(src)) "" else basename(src))
})

# assemble the grouped, ordered structure for Liquid ----
emit_item <- function(r) {
  it <- list(url = r$url, title = r$title)
  if (nzchar(r$dataset_name))     it$dataset_name     <- r$dataset_name
  if (nzchar(r$description))      it$description       <- r$description
  if (nzchar(r$coverage))         it$coverage          <- r$coverage
  if (nzchar(r$color))            it$color             <- r$color
  if (nzchar(r$link_calcofi_org)) it$link_calcofi_org  <- r$link_calcofi_org
  if (nzchar(r$link_data_source)) it$link_data_source  <- r$link_data_source
  if (nzchar(r$provider))         it$provider          <- r$provider
  it
}

cats_out <- list()
for (cid in names(categories)) {
  cdef  <- categories[[cid]]
  incat <- Filter(function(r) r$category == cid, recs)
  if (length(incat) == 0) next

  if (isTRUE(cdef$grouped)) {
    provs <- vapply(incat, function(r) r$provider %||% "other", "")
    ord   <- c(provider_order, setdiff(sort(unique(provs)), provider_order))
    groups <- list()
    for (p in ord) {
      pin <- incat[provs == p]
      if (length(pin) == 0) next
      pin <- pin[order(vapply(pin, function(r) tolower(r$title), ""))]
      groups[[length(groups) + 1]] <- list(
        label = unname(provider_label[p]) %||% toupper(p),
        items = lapply(pin, emit_item))
    }
    body <- list(groups = groups)
  } else {
    incat <- incat[order(vapply(incat, function(r) tolower(r$title), ""))]
    body  <- list(groups = list(list(label = "", items = lapply(incat, emit_item))))
  }

  cats_out[[length(cats_out) + 1]] <- c(
    list(id = cid, title = cdef$title, blurb = cdef$blurb,
         layout = cdef$layout, count = length(incat)),
    body)
}

out_yaml <- file.path(data_dir, "workflows.yml")

# pipeline DAG (preserve a previously committed one if the rebuild comes up empty)
dag_mermaid <- tryCatch(build_dag_mermaid(recs), error = function(e) "")
if (!nzchar(dag_mermaid))
  dag_mermaid <- tryCatch(yaml::read_yaml(out_yaml)$dag_mermaid %||% "", error = function(e) "")

doc <- list(
  generated   = format(Sys.time(), "%Y-%m-%d"),
  n_total     = length(recs),
  n_meta      = sum(vapply(recs, function(r) r$has_meta, logical(1))),
  categories  = cats_out,
  dag_mermaid = dag_mermaid)

writeLines(yaml::as.yaml(doc, indent = 2), out_yaml)
cat("wrote", out_yaml, "\n",
    length(recs), "pages;", doc$n_meta, "with calcofi metadata;",
    length(cats_out), "categories:",
    paste(vapply(cats_out, function(c) sprintf("%s(%d)", c$id, c$count), ""), collapse = " "),
    "\n")
