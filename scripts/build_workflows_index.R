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

  list(
    base        = base,
    url         = h,
    title       = oneline(fm$title %||% base),
    category    = cat_id,
    has_meta    = !is.null(cc),
    provider    = tolower(cc$provider %||% (if (cat_id == "ingest") "calcofi" else "")),
    dataset_name= oneline(dm$dataset_name %||% ""),
    description = oneline(dm$description %||% ""),
    coverage    = oneline(dm$coverage_temporal %||% ""),
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

doc <- list(
  generated  = format(Sys.time(), "%Y-%m-%d"),
  n_total    = length(recs),
  n_meta     = sum(vapply(recs, function(r) r$has_meta, logical(1))),
  categories = cats_out)

out_yaml <- file.path(data_dir, "workflows.yml")
writeLines(yaml::as.yaml(doc, indent = 2), out_yaml)
cat("wrote", out_yaml, "\n",
    length(recs), "pages;", doc$n_meta, "with calcofi metadata;",
    length(cats_out), "categories:",
    paste(vapply(cats_out, function(c) sprintf("%s(%d)", c$id, c$count), ""), collapse = " "),
    "\n")
