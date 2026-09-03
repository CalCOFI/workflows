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

librarian::shelf(rmarkdown, yaml, curl, quiet = TRUE)

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
# provider display labels come from metadata/provider.csv — a reviewable registry,
# not a lookup buried in this script. A hardcoded vector silently yielded
# NA_character_ (rendered as a literal ".na.character" heading on the live page)
# for any provider nobody remembered to add; the registry is validated below
# instead, so a missing org fails loudly at build time.
provider_csv <- here::here("metadata/provider.csv")
stopifnot("metadata/provider.csv not found" = file.exists(provider_csv))
d_provider     <- readr::read_csv(provider_csv, show_col_types = FALSE)
provider_label <- setNames(d_provider$provider_short, d_provider$provider)
# the category vocabulary is a registry too (metadata/category.csv; explorer UI plan D14): an ingest's
# `category:` was free text, so a typo made a category of one on the schema site and in the explorer's Browse
category_csv <- here::here("metadata/category.csv")
stopifnot("metadata/category.csv not found" = file.exists(category_csv))
d_category    <- readr::read_csv(category_csv, show_col_types = FALSE)
# display order within the ingest section follows the registry's row order
provider_order <- d_provider$provider

# category definitions, in display order ----
categories <- list(
  ingest    = list(title = "Ingest",
                   blurb = "Acquire, standardize, and load a source dataset into the integrated database. Cards are grouped by data provider.",
                   layout = "cards", grouped = TRUE),
  publish   = list(title = "Publish",
                   blurb = "Publish the released core to external services and formats \u2014 ERDDAP, CF NetCDF, OBIS. These are dataset-agnostic: one notebook covers every dataset in the release.",
                   layout = "cards", grouped = FALSE),
  release   = list(title = "Release & pipeline",
                   blurb = "Freeze a versioned release, validate it against the consumer contract, deploy it to the apps and services that read it, and the maintenance utilities that support the pipeline.",
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
    # `test` and `deploy` belong with `release`: they are the steps immediately
    # before and after freezing one. Without them here they fell through to
    # "Other notebooks", which is where test_release had been sitting — listed
    # among exploratory scratch work rather than as the gate that promotes
    # latest.txt.
    if (wt %in% c("release", "test", "deploy")) return("release")
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

# DB-derived coverage from the latest frozen release's metadata.json, computed
# in release_database.qmd by calcofi4db::observed_coverage() from the real
# obs/sample rows: temporal as "YYYY-MM to YYYY-MM" and spatial as a formatted
# bbox ("29.8–37.8°N, 126.5–117.3°W"). Best-effort: falls back to whatever the
# QMD front-matter still asserts if the sidecar can't be fetched (offline CI).
#
# Only two datasets still assert coverage — calcofi_phytoplankton is
# region-pooled and has no datetime to measure, and cdfw_dungeness-crab is
# `in_release: false` so the release never sees it. Everything else measures.
# The sidecar is the ONLY source for these numbers. Measuring them here from the
# local data/parquet working tree instead would put an extent on the card that
# is not in the release the card links to — the same "confident string nobody
# can check" problem this whole change removes. A card gains its bbox when a
# release carrying one is promoted, and not before.
#
# CALCOFI_RELEASE_META overrides the source with a path or URL to a
# metadata.json, so a freshly frozen release can be previewed on the index
# before test_release.qmd promotes latest.txt.
observed_coverage <- tryCatch({
  suppressWarnings(librarian::shelf(jsonlite, quiet = TRUE))
  base_url <- "https://storage.googleapis.com/calcofi-db/ducklake/releases"
  override <- Sys.getenv("CALCOFI_RELEASE_META", "")
  if (nzchar(override)) {
    ver <- override
  } else {
    ver <- trimws(readLines(url(file.path(base_url, "latest.txt")), warn = FALSE)[1])
  }
  meta <- jsonlite::fromJSON(
    if (nzchar(override)) override else file.path(base_url, ver, "metadata.json"),
    simplifyVector = FALSE)
  obs  <- list(); n_t <- 0L; n_s <- 0L
  for (k in names(meta$datasets)) {
    d <- meta$datasets[[k]]
    e <- list(temporal = d$coverage_temporal_observed %||% "",
              spatial  = d$coverage_spatial_observed  %||% "")
    n_t <- n_t + nzchar(e$temporal); n_s <- n_s + nzchar(e$spatial)
    obs[[k]] <- e
  }
  cat(sprintf("observed coverage from release %s: %d temporal, %d spatial\n",
              ver, n_t, n_s))
  obs
}, error = function(e) {
  message("observed coverage unavailable (", conditionMessage(e),
          ") — falling back to asserted coverage_* in the front-matter")
  list()
})

# build the pipeline DAG as Mermaid directly from the calcofi: front-matter
# (target_name + dependency + workflow_type) — the same fields build_targets_list()
# uses — so it needs no `targets` install. Flat graph (no subgraphs) of rounded
# "pill" nodes; each ingest node is filled with its dataset color (calcofi.erd.color),
# other node types get a categorical color.
build_dag_mermaid <- function(recs) {
  cats <- c("ingest", "publish", "release")
  tr <- Filter(function(r) isTRUE(r$has_meta) && r$category %in% cats && nzchar(r$target), recs)
  if (!length(tr)) return("")
  sid <- function(t) gsub("[^A-Za-z0-9_]", "_", t)
  all_targets <- vapply(tr, function(r) r$target, "")
  auto_deps   <- all_targets[vapply(tr, function(r) r$category, "") == "ingest"]
  # categorical colors for non-ingest types (+ a fallback for ingest w/o a color)
  cat_col <- c(ingest = "#cdd9e5", publish = "#20c997", release = "#f06595")

  lines <- "graph LR"
  cls_defs <- character(); seen <- character()
  for (r in tr) {
    id <- sid(r$target)
    if (r$category == "ingest" && nzchar(r$color)) {
      cls <- paste0("c_", id); col <- r$color
    } else {
      cls <- r$category;        col <- cat_col[[r$category]]
    }
    if (!cls %in% seen) {
      cls_defs <- c(cls_defs, sprintf(
        "  classDef %s fill:%s,stroke:#00000033,color:#10161c;", cls, col))
      seen <- c(seen, cls)
    }
    # stadium node (["…"]) renders as a rounded pill
    lines <- c(lines, sprintf('  %s(["%s"]):::%s', id, r$target, cls))
  }
  for (r in tr) {
    dv <- unlist(r$deps)
    if (length(dv) && any(dv == "auto")) dv <- setdiff(auto_deps, r$target)
    for (d in dv[dv %in% all_targets]) lines <- c(lines, sprintf("  %s --> %s", sid(d), sid(r$target)))
  }
  paste(c(lines, cls_defs), collapse = "\n")
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
  # DB-derived extent (from the frozen release) beats anything the QMD
  # front-matter asserts; fall back to the asserted string only if measurement
  # is impossible or the sidecar was unreachable.
  cov  <- observed_coverage[[ds_key]]$temporal %||% dm$coverage_temporal %||% ""
  bbox <- observed_coverage[[ds_key]]$spatial  %||% dm$coverage_spatial  %||% ""

  list(
    base        = base,
    url         = h,
    title       = base,   # use the simplified notebook file name as the card header + link text
    category    = cat_id,
    has_meta    = !is.null(cc),
    provider    = prov,
    target      = oneline(cc$target_name %||% base),
    deps        = cc$dependency,
    dataset_name= oneline(dm$dataset_name %||% ""),
    # `dataset_meta` belongs to an ingest; a publish/release notebook is not a
    # dataset and should not fake one, so fall back to a plain `calcofi.description`
    description = oneline(dm$description %||% cc$description %||% ""),
    coverage    = oneline(cov),
    bbox        = oneline(bbox),
    color       = cc$erd$color %||% "",
    dataset_category = dm$category %||% NA_character_,   # the dataset's category (metadata/category.csv), not the site's section
    link_calcofi_org = dm$link_calcofi_org %||% "",
    link_data_source = dm$link_data_source %||% "",
    source_qmd  = if (is.na(src)) "" else basename(src))
})

# declared source links must BE links, and must still resolve ----
# The cards on calcofi.io/workflows link straight to these, and so does
# db-viz-station, which reads them out of the release's `dataset.parquet`
# into an href. Both failure modes below have already shipped:
#   * prose in a link field — `link_data_source` held "BTEDB (Bongo Tow
#     Euphausiid Database) export" and "SIO Pelagic Invertebrate Collection DB
#     (CSV export)", which reach a consumer as a broken link and forced a
#     hardcoded per-dataset override downstream to work around;
#   * a URL that rotted — swfsc_ichthyo's `link_calcofi_org` 404'd while looking
#     perfectly plausible in the YAML, and became the portal's only link to the
#     single most-used dataset in the release.
# The shape check costs nothing and always runs. Reachability needs the network,
# so it separates "this link is wrong" (404/410/451 — fail, do not publish a card
# pointing at it) from "this server is unhappy right now" (5xx, timeout, DNS —
# warn only; NOAA CoastWatch ERDDAP 503s under load and that is not our bug).
# Set CALCOFI_SKIP_LINK_CHECK=1 to skip the network half.
links <- do.call(rbind, lapply(recs, function(r) {
  out <- NULL
  for (f in c("link_calcofi_org", "link_data_source")) {
    v <- trimws(r[[f]] %||% "")
    if (!nzchar(v)) next
    out <- rbind(out, data.frame(
      notebook = if (nzchar(r$source_qmd)) r$source_qmd else r$base,
      field = f, url = v, stringsAsFactors = FALSE))
  }
  out
}))

if (!is.null(links) && nrow(links) > 0) {
  fmt <- function(d, extra = "")
    paste0("  ", d$notebook, "  ", d$field, ": ", extra, d$url, collapse = "\n")

  not_url <- links[!grepl("^https?://", links$url), , drop = FALSE]
  if (nrow(not_url) > 0)
    stop("link field(s) that are not URLs:\n", fmt(not_url),
         "\n  A link field is rendered as an href. Provenance prose belongs in",
         " `description`; leave the link field empty when the source has no",
         " portal URL.", call. = FALSE)

  if (nzchar(Sys.getenv("CALCOFI_SKIP_LINK_CHECK"))) {
    message("link check: ", nrow(links),
            " declared link(s), reachability skipped (CALCOFI_SKIP_LINK_CHECK)")
  } else {
    # HEAD is not usable: EDI's mapbrowse answers 405 to it, and EDI hosts most
    # of the bio datasets — so a HEAD-based check would fail exactly the links
    # that are fine. A one-byte ranged GET answers 200/206 on every host we link
    # to and still does not pull the 31 MB bottle zip.
    status_of <- function(u) tryCatch(
      curl::curl_fetch_memory(u, handle = curl::new_handle(
        range = "0-0", followlocation = TRUE, timeout = 30, connecttimeout = 10,
        useragent = "calcofi-workflows link check"))$status_code,
      error = function(e) NA_integer_)

    # one request per distinct URL — several datasets share a landing page
    u_uniq <- unique(links$url)
    st     <- vapply(u_uniq, function(u) as.integer(status_of(u)), integer(1))
    links$status <- unname(st[links$url])

    dead <- links[!is.na(links$status) & links$status %in% c(404L, 410L, 451L), , drop = FALSE]
    iffy <- links[is.na(links$status) |
                  (links$status >= 400L & !links$status %in% c(404L, 410L, 451L)), , drop = FALSE]

    # warn before stopping, so one dead link does not hide the rest
    if (nrow(iffy) > 0)
      message("link check: ", nrow(iffy), " link(s) did not answer cleanly ",
              "(not failing the build — retry before treating as broken):\n",
              fmt(iffy, extra = paste0(
                ifelse(is.na(iffy$status), "unreachable", iffy$status), "  ")))
    if (nrow(dead) > 0)
      stop("dead link(s) — the server says the page is gone:\n",
           fmt(dead, extra = paste0(dead$status, "  ")),
           "\n  Fix the `calcofi.dataset_meta` link in the notebook listed. The",
           " release `dataset` table is built from this YAML at release time, so",
           " a release re-cut is what carries the fix to consumers.", call. = FALSE)

    message("link check: ", nrow(links), " declared link(s) over ", length(u_uniq),
            " distinct URL(s), ", sum(!is.na(links$status) & links$status < 400L), " OK")
  }
}

# a dataset's citation and license are a contract too, checked like its links ----
# calcofi4db::check_dataset_citation() (>= 3.30.0): the structural half always runs
# — a non-empty citation_main with a year and a locator, a license that is an
# active id in metadata/license.csv (`custom` with a license_url), a bare DOI —
# and the network half (behind the same CALCOFI_SKIP_LINK_CHECK) asks the
# source's own authority (EDI cite service, NCEI landing page, ERDDAP .das,
# DataCite) and caches it in metadata/{provider}/{dataset}/citation_authority.json.
# An error-level finding fails the build unless the dataset's questions.csv holds
# an open/proposed row on related_table = dataset naming the field; drift and an
# unreachable authority only warn. Nothing is written into a notebook's YAML.
# CALCOFI4DB_DIR loads a development checkout instead of the installed package.
suppressPackageStartupMessages(
  if (nzchar(Sys.getenv("CALCOFI4DB_DIR"))) {
    devtools::load_all(Sys.getenv("CALCOFI4DB_DIR"), quiet = TRUE)
  } else library(calcofi4db))
cit <- calcofi4db::check_dataset_citation(
  calcofi4db::read_ingest_yaml(wd),
  network   = !nzchar(Sys.getenv("CALCOFI_SKIP_LINK_CHECK")),
  cache_dir = here::here("metadata"))
calcofi4db::assert_dataset_citation(cit)
message("citation check: ", length(unique(cit$dataset_key)), " dataset(s); ",
        sum(cit$finding == "ok"), " ok, ",
        sum(cit$level == "error" & cit$exempt), " exempt (question open/proposed), ",
        sum(cit$level == "warn"), " warning(s)",
        if (nzchar(Sys.getenv("CALCOFI_SKIP_LINK_CHECK"))) " — authorities not fetched (CALCOFI_SKIP_LINK_CHECK)" else "")

# assemble the grouped, ordered structure for Liquid ----
emit_item <- function(r) {
  it <- list(url = r$url, title = r$title)
  if (nzchar(r$dataset_name))     it$dataset_name     <- r$dataset_name
  if (nzchar(r$description))      it$description       <- r$description
  if (nzchar(r$coverage))         it$coverage          <- r$coverage
  if (nzchar(r$bbox))             it$bbox              <- r$bbox
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

    # FAIL LOUDLY, don't publish a broken heading. Every provider an ingest
    # declares must be registered in metadata/provider.csv. The old hardcoded
    # lookup degraded silently: an unregistered provider became NA_character_ and
    # shipped as a literal ".na.character" group heading to the live page.
    cats <- unique(unlist(lapply(incat, function(r) r$dataset_category)))
    bad_cat <- setdiff(cats[!is.na(cats)], d_category$category)
    if (length(bad_cat))
      stop("category(ies) not in metadata/category.csv: ", paste(bad_cat, collapse = ", "),
           "\n  Every ingest's `category:` must be one of the registered categories (the explorer's Browse",
           " tab and the schema site group by them); add a row there first if it is genuinely new.", call. = FALSE)
    unregistered <- setdiff(unique(provs), c(names(provider_label), "other"))
    if (length(unregistered))
      stop("provider(s) not in metadata/provider.csv: ",
           paste(unregistered, collapse = ", "),
           "\n  Add a row (provider, provider_short, provider_name, url, status)",
           " — provider = the organization CURATING the data, not the portal",
           " hosting it and not the collection or lab within the org.",
           call. = FALSE)

    ord   <- c(provider_order, setdiff(sort(unique(provs)), provider_order))
    groups <- list()
    for (p in ord) {
      pin <- incat[provs == p]
      if (length(pin) == 0) next
      pin <- pin[order(vapply(pin, function(r) tolower(r$title), ""))]
      groups[[length(groups) + 1]] <- list(
        label = unname(provider_label[p]),
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
