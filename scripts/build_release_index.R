#!/usr/bin/env Rscript
# build_release_index.R
#
# Generate browsable HTML indexes for the release bucket and upload them to GCS.
#
# WHY THIS EXISTS: https://storage.googleapis.com serves OBJECTS, not directories.
# There is no folder listing — a URL ending in "/" 404s unless an object literally
# has that key. So `.../releases/latest.txt` works (it is an object) while
# `.../releases/v2026.07.17/parquet/` does not, and no bucket permission changes
# that. The fix is to publish real index.html OBJECTS and link to them directly:
#   https://storage.googleapis.com/calcofi-db/ducklake/releases/index.html
#   https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.07.17/index.html
#
# (Bare folder URLs like .../parquet/ still 404 — serving index.html for a folder
# needs either a GCS *website* configuration, which requires a domain-named bucket
# reached via CNAME rather than storage.googleapis.com, or a proxy in front. See
# the note printed at the end.)
#
# Data sources, all already published by release_database.qmd — this script adds
# no new state, it only renders what is there:
#   ducklake/releases/versions.json            -> every release (date/tables/rows/size)
#   ducklake/releases/latest.txt               -> the promoted version
#   ducklake/releases/{v}/catalog.json         -> per-table rows + supplemental flag
#   GCS object listing                         -> real byte sizes per file
#
# Usage:
#   Rscript scripts/build_release_index.R                      # render + upload
#   Rscript scripts/build_release_index.R --dry-run            # render only, print paths
#   Rscript scripts/build_release_index.R --dry-run --out=DIR  # render to DIR to preview
librarian::shelf(jsonlite, glue, quiet = TRUE)

WF_LIB     <- if (nzchar(Sys.getenv("CALCOFI_WORKFLOWS"))) Sys.getenv("CALCOFI_WORKFLOWS") else getwd()
BUCKET     <- "calcofi-db"
PREFIX     <- "ducklake/releases"
BUCKET_URL <- glue("https://storage.googleapis.com/{BUCKET}")   # object keys hang off THIS
HTTPS      <- glue("{BUCKET_URL}/{PREFIX}")                     # convenience for page links
XML_API  <- glue("https://storage.googleapis.com/{BUCKET}")
ARGV     <- commandArgs(trailingOnly = TRUE)
DRY      <- any(ARGV %in% c("--dry-run", "-n"))
OUT_DIR  <- sub("^--out=", "", grep("^--out=", ARGV, value = TRUE)[1])
gcloud   <- Sys.which("gcloud")
if (!DRY && !nzchar(gcloud)) stop("gcloud not found; use --dry-run")

# chrome (page()), escaping/formatting helpers, gcs_list() and gcs_upload() are
# shared with build_storage_index.R so every generated page looks like one site
source(file.path(WF_LIB, "libs/gcs_index.R"))

# --- read published state -----------------------------------------------------
message("reading versions.json + latest.txt ...")
versions <- fromJSON(glue("{HTTPS}/versions.json"), simplifyDataFrame = FALSE)$versions
latest   <- trimws(readLines(glue("{HTTPS}/latest.txt"), warn = FALSE)[1])
message(glue("  {length(versions)} releases; latest = {latest}"))

# object listing for one release prefix -> data.frame(key, size)
list_objects <- function(ver) {
  u <- glue("{XML_API}?prefix={PREFIX}/{ver}/&max-keys=1000")
  x <- paste(readLines(url(u), warn = FALSE), collapse = "")
  keys  <- regmatches(x, gregexpr("(?<=<Key>)[^<]+", x, perl = TRUE))[[1]]
  sizes <- regmatches(x, gregexpr("(?<=<Size>)[0-9]+", x, perl = TRUE))[[1]]
  n <- min(length(keys), length(sizes))
  if (!n) return(data.frame(key = character(), size = numeric()))
  data.frame(key = keys[seq_len(n)], size = as.numeric(sizes[seq_len(n)]))
}

# --- per-release page ---------------------------------------------------------
# Object keys are absolute from the BUCKET root, so links must be built on
# BUCKET_URL, not HTTPS (which already ends in /ducklake/releases). Prepending the
# latter double-prefixed every link and returned "No such object".
#
# Large tables are hive-PARTITIONED DIRECTORIES (obs/dataset_key=…/data_0.parquet,
# obs_ctd_full/cruise_key=…/data_0.parquet), not single files. Listing every key
# and showing basename() collapsed all of them to a wall of identical
# "data_0.parquet" rows and threw away the structure the names imply. So: group by
# the first path segment under parquet/, render a single row per table, and give
# each partitioned table its OWN nested index page listing its parts.
status_chips <- function(rec) paste0(
  if (isTRUE(rec$consolidated)) ' <span class="chip">consolidated</span>' else "",
  if (!is.null(rec$retired)) ' <span class="chip">retired</span>' else "")

release_page <- function(ver, is_latest, emit_child, rec = list()) {
  objs <- list_objects(ver)
  ctl <- tryCatch(fromJSON(glue("{HTTPS}/{ver}/catalog.json"), simplifyDataFrame = TRUE),
                  error = function(e) NULL)
  tbls <- if (!is.null(ctl) && is.data.frame(ctl$tables)) ctl$tables else NULL
  rows_of <- function(nm) if (!is.null(tbls) && nm %in% tbls$name)
    tbls$rows[match(nm, tbls$name)] else NA
  supp_of <- function(nm) if (!is.null(tbls) && nm %in% tbls$name)
    isTRUE(tbls$supplemental[match(nm, tbls$name)]) else FALSE

  pq_pre <- glue("{PREFIX}/{ver}/parquet/")
  is_pq  <- startsWith(objs$key, pq_pre)
  pq     <- objs[is_pq, ]; sc <- objs[!is_pq, ]
  pq$rel <- substring(pq$key, nchar(pq_pre) + 1)
  pq$top <- sub("/.*$", "", pq$rel)                    # first segment == the table
  pq$is_dir <- grepl("/", pq$rel)

  tops <- unique(pq$top)
  pq_rows <- if (length(tops)) paste0(vapply(sort(tops), function(tp) {
    part <- pq[pq$top == tp, ]
    nm   <- sub("[.]parquet$", "", tp)
    chip <- if (supp_of(nm)) ' <span class="chip">supplemental</span>' else ""
    rws  <- if (is.na(rows_of(nm))) "—" else fmt_n(rows_of(nm))
    if (any(part$is_dir)) {                            # partitioned -> child page
      emit_child(ver, tp, part)
      glue('<tr><td><a href="{HTTPS}/{ver}/parquet/{tp}/index.html">{esc(tp)}/</a>{chip}',
           ' <span class="chip">{nrow(part)} parts</span></td>',
           '<td class="num">{rws}</td><td class="num">{fmt_mb(sum(part$size))}</td></tr>')
    } else {
      glue('<tr><td><a href="{BUCKET_URL}/{part$key[1]}">{esc(tp)}</a>{chip}</td>',
           '<td class="num">{rws}</td><td class="num">{fmt_mb(part$size[1])}</td></tr>')
    }
  }, character(1)), collapse = "\n") else '<tr><td colspan="3">(none)</td></tr>'

  # content-addressed releases (catalog objects[], calcofi4db >= 3.22): the
  # catalog is the listing — one row per object with where it lives, when its
  # content first shipped and its hash. The parquet/ listing above may be empty
  # for a version whose compat copies were never made or have been thinned.
  obj_rows <- ""
  ctl_l <- tryCatch(fromJSON(glue("{HTTPS}/{ver}/catalog.json"), simplifyVector = FALSE),
                    error = function(e) NULL)
  if (!is.null(ctl_l) && any(vapply(ctl_l$tables, function(t) length(t$objects) > 0, TRUE))) {
    obj_rows <- paste0(unlist(lapply(ctl_l$tables, function(t) {
      chip <- if (isTRUE(t$supplemental)) ' <span class="chip">supplemental</span>' else ""
      vapply(t$objects, function(o) {
        part <- if (!is.null(o$partition_by)) glue("{o$partition_by}={o$partition_value}") else ""
        since_chip <- if (identical(o$since, ver)) ' <span class="chip">new</span>' else ""
        glue('<tr><td>{esc(t$name)}{chip}</td><td>{esc(part)}</td>',
             '<td><a href="{BUCKET_URL}/{o$path}">{substr(o$content_hash, 1, 12)}</a></td>',
             '<td>{esc(o$since %||% "")}{since_chip}</td>',
             '<td class="num">{fmt_mb(o$bytes %||% NA)}</td></tr>')
      }, character(1))
    })), collapse = "\n")
    obj_rows <- glue('
<h1 style="font-size:1.1rem;margin:2rem 0 .2rem">Objects (content-addressed)</h1>
<p class="sub">One immutable object per table or partition under <code>ducklake/tables/</code>,
shared by every release whose catalog points at it. <b>since</b> is the first release that
shipped this exact content; <b>new</b> marks what changed in {ver}. Resolve tables through
<code>catalog.json</code> <code>objects[].path</code> (e.g. <code>calcofi4r::cc_release_sources()</code>,
<code>calcofi4py.release_sources()</code>) rather than the <code>parquet/</code> path, which is kept
only for the promoted and consolidated versions.</p>
<div class="scroll"><table>
<thead><tr><th>table</th><th>partition</th><th>object (hash)</th><th>since</th><th style="text-align:right">size</th></tr></thead>
<tbody>
{obj_rows}
</tbody></table></div>')
  }

  sc_rows <- if (nrow(sc)) paste0(vapply(seq_len(nrow(sc)), function(i)
    glue('<tr><td><a href="{BUCKET_URL}/{sc$key[i]}">{esc(basename(sc$key[i]))}</a></td>',
         '<td class="num">{fmt_mb(sc$size[i])}</td></tr>'), character(1)),
    collapse = "\n") else '<tr><td colspan="2">(none)</td></tr>'

  # A table published BOTH partitioned and as a single file looks like a mistake on
  # a listing page. It is deliberate — say so here rather than leaving readers to
  # guess (or "tidy up" the copy something depends on).
  dup <- intersect(sub("[.]parquet$", "", tops[grepl("[.]parquet$", tops)]),
                   tops[!grepl("[.]parquet$", tops)])
  dup_note <- if (length(dup)) glue(
    '<div class="note"><b>Why {paste(sprintf("<code>%s</code>", dup), collapse=", ")} ',
    'appears twice.</b> Each is published both as a Hive-partitioned directory and ',
    'as a single <code>.parquet</code> file, on purpose — they are the same rows.<br><br>',
    'The <b>partitioned</b> form lets DuckDB, R and Python skip whole partitions when ',
    'you filter on the partition column, so it is the faster choice for most analysis. ',
    'The <b>single-file</b> form exists because plain HTTPS has no directory listing: ',
    'browser DuckDB-WASM (which powers ',
    '<a href="https://calcofi.io/db-query/">calcofi.io/db-query</a>) and other ',
    'HTTPS-only consumers cannot expand a <code>/**/*.parquet</code> glob against ',
    'cloud storage, so they need one addressable object. Removing either breaks a ',
    'real consumer.</div>') else ""

  body <- glue('
<div class="scroll"><table>
<thead><tr><th>table</th><th style="text-align:right">rows</th><th style="text-align:right">size</th></tr></thead>
<tbody>
{pq_rows}
</tbody></table></div>

{obj_rows}
<h1 style="font-size:1.1rem;margin:2rem 0 .2rem">Sidecars</h1>
<p class="sub">Machine-readable descriptions of this release.</p>
<div class="scroll"><table>
<thead><tr><th>file</th><th style="text-align:right">size</th></tr></thead>
<tbody>
{sc_rows}
</tbody></table></div>

{dup_note}

<div class="note">
Read directly with DuckDB — no download needed. A single-file table:<br>
<code>SELECT * FROM read_parquet(\'{BUCKET_URL}/{PREFIX}/{ver}/parquet/sample.parquet\') LIMIT 10;</code>
<br><br>
A <b>partitioned</b> table (note the <code>/**/*.parquet</code> glob and
<code>hive_partitioning</code>, which turns the directory names into a real column):<br>
<code>SELECT * FROM read_parquet(\'{BUCKET_URL}/{PREFIX}/{ver}/parquet/obs_ctd_full/**/*.parquet\',
hive_partitioning = true) LIMIT 10;</code>
</div>')

  sub <- glue('{ctl$release_date %||% ""} · {length(tops)} tables · ',
              '{fmt_n(ctl$total_rows %||% 0)} rows · {fmt_mb(ctl$total_size %||% NA)}',
              '{if (is_latest) " · <span class=\\"chip\\">latest</span>" else ""}')
  # archive thinning (metadata/release_policy.yml): the parquet of a retired
  # version is gone; its notes and sidecars stay, and the banner says where to go
  if (!is.null(rec$retired)) {
    r <- rec$retired
    body <- paste0(glue('<div class="callout" style="border-left:4px solid #c60;padding:.6rem 1rem;margin:0 0 1.5rem">
<b>Data retired {substr(r$retired_utc %||% "", 1, 10)}</b> — the parquet of {ver} was removed from the archive; ',
      'read <a href="{HTTPS}/{r$to}/index.html">{r$to}</a> (the nearest consolidated release) or ',
      '<code>latest.txt</code> instead. The catalog, metadata and release notes below remain the record of this version.
</div>'), body)
  }
  sub <- paste0(sub, status_chips(rec))
  page(glue("CalCOFI release {ver}"), sub, body,
       crumb = glue('<p class="crumb"><a href="{HTTPS}/index.html">← all releases</a></p>'))
}

# --- page for one partitioned table (its parts, structure preserved) -----------
partition_page <- function(ver, tp, part) {
  part <- part[order(part$rel), ]
  rows <- paste0(vapply(seq_len(nrow(part)), function(i) {
    sub_path <- substring(part$rel[i], nchar(tp) + 2)   # drop "<tp>/"
    glue('<tr><td><a href="{BUCKET_URL}/{part$key[i]}">{esc(sub_path)}</a></td>',
         '<td class="num">{fmt_mb(part$size[i])}</td></tr>')
  }, character(1)), collapse = "\n")
  body <- glue('
<div class="scroll"><table>
<thead><tr><th>partition / file</th><th style="text-align:right">size</th></tr></thead>
<tbody>
{rows}
</tbody></table></div>

<div class="note">
Query every partition at once rather than downloading them individually —
<code>hive_partitioning</code> exposes the directory name as a column you can filter on:<br>
<code>SELECT * FROM read_parquet(\'{BUCKET_URL}/{PREFIX}/{ver}/parquet/{tp}/**/*.parquet\',
hive_partitioning = true) LIMIT 10;</code>
</div>')
  page(glue("{tp} — {ver}"),
       glue("{nrow(part)} partitions · {fmt_mb(sum(part$size))}"), body,
       crumb = glue('<p class="crumb"><a href="{HTTPS}/index.html">all releases</a> / ',
                    '<a href="{HTTPS}/{ver}/index.html">{ver}</a></p>'))
}

# --- root page ----------------------------------------------------------------
root_rows <- paste0(vapply(versions, function(v) {
  is_l <- identical(v$version, latest)
  glue('<tr><td><a href="{HTTPS}/{v$version}/index.html">{esc(v$version)}</a>',
       '{if (is_l) " <span class=\\"chip\\">latest</span>" else ""}{status_chips(v)}</td>',
       '<td>{esc(v$release_date %||% "")}</td>',
       '<td class="num">{v$tables %||% "—"}</td>',
       '<td class="num">{fmt_n(v$total_rows %||% 0)}</td>',
       '<td class="num">{sprintf("%.1f MB", as.numeric(v$size_mb %||% 0))}</td></tr>')
}, character(1)), collapse = "\n")

root_body <- glue('
<div class="scroll"><table>
<thead><tr><th>release</th><th>date</th><th style="text-align:right">tables</th>
<th style="text-align:right">rows</th><th style="text-align:right">size</th></tr></thead>
<tbody>
{root_rows}
</tbody></table></div>

<div class="note">
<b>What changed between versions?</b> <a href="{HTTPS}/RELEASES.md">RELEASES.md</a> is
the running changelog (newest first); the <code>RELEASE_NOTES.md</code> of each version is its
section plus a generated appendix.<br><br>
<b>Which version should I use?</b> <code>{HTTPS}/latest.txt</code> holds the
promoted version — currently <b>{latest}</b>. Resolve it, then build the path:<br>
<code>V=$(curl -s {HTTPS}/latest.txt); curl -O {HTTPS}/$V/parquet/obs.parquet</code>
<br><br>
<b>Why no folder browsing?</b> Google Cloud Storage serves <i>objects</i>, not
directories — a URL ending in <code>/</code> has no listing and returns 404. These
index pages are real objects standing in for that listing, so link to
<code>index.html</code> explicitly.
</div>')

# --- render + upload ----------------------------------------------------------
tmp <- if (!is.na(OUT_DIR)) OUT_DIR else file.path(tempdir(), "release_index")
dir.create(tmp, showWarnings = FALSE, recursive = TRUE)
writeLines(page("CalCOFI database releases",
  glue("{length(versions)} versioned releases · latest <b>{latest}</b>"),
  root_body), file.path(tmp, "root.html"))
targets <- list(list(local = file.path(tmp, "root.html"),
                     gcs = glue("gs://{BUCKET}/{PREFIX}/index.html")))

for (v in versions) {
  # release_page calls back here for each partitioned table so its child page is
  # written in the same pass (and lands next to the parts it describes)
  emit_child <- function(ver, tp, part) {
    cf <- file.path(tmp, glue("{ver}__{gsub('[^A-Za-z0-9]', '_', tp)}.html"))
    writeLines(partition_page(ver, tp, part), cf)
    targets[[length(targets) + 1]] <<- list(local = cf,
      gcs = glue("gs://{BUCKET}/{PREFIX}/{ver}/parquet/{tp}/index.html"))
  }
  f <- file.path(tmp, glue("{v$version}.html"))
  writeLines(release_page(v$version, identical(v$version, latest), emit_child, rec = v), f)
  targets[[length(targets) + 1]] <- list(local = f,
    gcs = glue("gs://{BUCKET}/{PREFIX}/{v$version}/index.html"))
  message(glue("  rendered {v$version}"))
}

if (DRY) {
  cat("\nDRY RUN — rendered locally, nothing uploaded:\n")
  for (t in targets) cat(sprintf("  %s  ->  %s\n", t$local, t$gcs))
} else {
  for (t in targets) {
    res <- system2(gcloud, c("storage", "cp",
      "--content-type=text/html", "--cache-control=no-cache",
      shQuote(t$local), shQuote(t$gcs)), stdout = TRUE, stderr = TRUE)
    if (!is.null(attr(res, "status"))) warning(glue("upload failed: {t$gcs}"))
  }
  cat(glue("\nuploaded {length(targets)} index pages\n"))
  cat(glue("  root: {HTTPS}/index.html\n"))
  cat(glue("  latest: {HTTPS}/{latest}/index.html\n"))
}
cat("\nNOTE: bare folder URLs (.../parquet/) still 404 — GCS has no directory\n",
    "listing. True folder browsing needs a proxy in front (e.g. a Caddy vhost\n",
    "rewriting */ -> */index.html and reverse-proxying to storage.googleapis.com)\n",
    "or a GCS website config on a domain-named bucket reached via CNAME.\n", sep = "")
