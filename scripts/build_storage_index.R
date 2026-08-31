#!/usr/bin/env Rscript
# build_storage_index.R
#
# Generate the browsable front page for https://storage.calcofi.io and one index
# per public bucket, using the same skin as the release pages (libs/gcs_index.R).
#
# Why: GCS serves objects, not directories. Hitting a bucket root on
# storage.googleapis.com returns the raw XML ListBucketResult — no stylesheet, no
# links, jarring next to every other page we publish. Each bucket therefore gets a
# real index.html object, and Caddy's folder -> index.html rewrite makes
# storage.calcofi.io/<bucket>/ land on it.
#
# The ROOT page (storage.calcofi.io/) is published as an object too, at
# calcofi-files-public/_index/storage.html, and Caddy rewrites "/" to it — so
# there is exactly one generator and one skin, rather than HTML pasted into the
# Caddyfile.
#
# Usage:
#   Rscript scripts/build_storage_index.R                      # render + upload
#   Rscript scripts/build_storage_index.R --dry-run --out=DIR  # preview
#
# NOTE: must run somewhere with write credentials — the CalCOFI server's compute
# service account has read-only storage scopes. See scripts/publish_netcdf.sh.
librarian::shelf(glue, quiet = TRUE)
WF <- if (nzchar(Sys.getenv("CALCOFI_WORKFLOWS"))) Sys.getenv("CALCOFI_WORKFLOWS") else getwd()
source(file.path(WF, "libs/gcs_index.R"))

ARGV    <- commandArgs(trailingOnly = TRUE)
DRY     <- any(ARGV %in% c("--dry-run", "-n"))
OUT_DIR <- sub("^--out=", "", grep("^--out=", ARGV, value = TRUE)[1])

# The public buckets, in the order a newcomer should meet them. `entry` is where
# "browse" should land — not always the bucket root, since the interesting content
# can sit a few levels down.
BUCKETS <- list(
  list(name  = "calcofi-db",
       title = "Integrated database releases",
       desc  = paste("Versioned Parquet releases of the integrated CalCOFI database —",
                     "observations, samples, taxonomy and reference tables, plus",
                     "machine-readable catalog/metadata sidecars for each release."),
       # entry = "" on purpose (D30): the card lands on the bucket's OWN listing.
       # It used to jump straight to ducklake/releases/, which made every other
       # top-level folder (bathymetry/, ingest/, qc/, ...) look non-existent.
       entry = "",
       start = "ducklake/releases/",   # the "start here" link the card text keeps
       # One-line notes for the bucket-root listing's third column (D30). A folder
       # not named here simply gets an empty cell, so new folders never break this.
       folders = c(
         "ducklake"   = "releases + the content-addressed tables/ store — start at releases/",
         "bathymetry" = "GEBCO 2025: the consumers' crop, the terrain + contour PMTiles, gebco_2025.json",
         "ingest"     = "per-dataset parquet shards + JSON sidecars, mirrored from the ingests",
         "parquet"    = "per-dataset parquet shards + JSON sidecars (current layout)",
         "erddap"     = "datasets served by erddap.calcofi.io",
         "publish"    = "published derived products (netCDF and friends)",
         "qc"         = "working QC snapshots (e.g. the CTD team's accepted flags)",
         "pg"         = "PostgreSQL backups for the CTD team's working database",
         "gcloud"     = "gcloud's own scratch (tmp/ upload chunks; safe to prune)"),
       # Directories with their OWN richer generator. The generic walker must not
       # emit pages here: build_release_index.R publishes per-release pages with
       # row counts, catalog data and the partitioned/single-file explanation, and
       # a plain file listing written on top would silently destroy all of that.
       skip  = "^ducklake/releases(/|$)"),
  list(name  = "calcofi-files-public",
       title = "Source archive for reproducible ingests",
       desc  = paste("Primarily a versioned archive of the INPUT files the database",
                     "ingests read — largely CSVs synced from Google Drive — kept so",
                     "any release can be rebuilt reproducibly from the exact inputs it",
                     "was built from, rather than from whatever Drive holds today.",
                     "Also carries published derived products, such as the",
                     "whole-dataset CF NetCDF files."),
       # netcdf/ is owned by the per-dataset publish notebooks, which write a
       # curated page (provenance, CF structure, how to read it). A generic file
       # listing on top would erase that.
       entry = "", skip = "^netcdf(/|$)"),
  list(name  = "calcofi-projects",
       title = "Project outputs",
       desc  = "Outputs from individual CalCOFI projects and analyses.",
       entry = "", skip = NA_character_)
)

# --- root page ----------------------------------------------------------------
root_cards <- paste0(vapply(BUCKETS, function(b) {
  href  <- glue("{SITE_URL}/{b$name}/{b$entry}")
  start <- if (!is.null(b$start))
    glue(' Start at <a href="{SITE_URL}/{b$name}/{b$start}"><code>{esc(b$start)}</code></a>.') else ""
  glue('<tr><td><a href="{href}"><code>{esc(b$name)}</code></a><br>',
       '<span style="font-size:.9em">{esc(b$title)}</span></td>',
       '<td style="white-space:normal">{esc(b$desc)}{start}</td></tr>')
}, character(1)), collapse = "\n")

root_body <- glue('
<div class="scroll"><table>
<thead><tr><th>bucket</th><th style="white-space:normal">contents</th></tr></thead>
<tbody>
{root_cards}
</tbody></table></div>

<div class="note">
<b>Reading these files directly.</b> Everything here is a plain HTTPS object, so
most tools can read it in place without downloading. For the Parquet releases:<br>
<code>SELECT * FROM read_parquet(\'{SITE_URL}/calcofi-db/ducklake/releases/latest-version/parquet/obs.parquet\') LIMIT 10;</code>
<br><br>
Resolve <code>latest-version</code> from
<a href="{SITE_URL}/calcofi-db/ducklake/releases/latest.txt">latest.txt</a>, which
always holds the promoted release. That <code>parquet/</code> path is kept for the promoted and
consolidated versions; every version\'s <code>catalog.json</code> lists its tables\' objects
(<code>objects[].path</code>, under <code>ducklake/tables/</code>) — the durable way to address a
table, and what <code>calcofi4r::cc_get_db()</code> / <code>calcofi4py.cc_get_db()</code> use. Prefer a form? Try the browser query app at
<a href="https://calcofi.io/db-query/">calcofi.io/db-query</a>, or
<a href="https://erddap.calcofi.io">erddap.calcofi.io</a> for filtered subsets.
</div>

<div class="note">
<b>Why these pages exist.</b> Cloud storage serves <i>objects</i>, not directories —
a bucket root returns an XML listing with no styling, and a URL ending in
<code>/</code> has no listing at all. Each browsable folder here is a generated
<code>index.html</code>, so the structure is navigable rather than guessable.
</div>')

pages <- list(list(
  html = page("CalCOFI public storage",
              glue("{length(BUCKETS)} public buckets · served via {SITE_URL}"),
              root_body),
  gcs  = glue("gs://calcofi-files-public/_index/storage.html"),
  file = "root.html"))

# --- one index per DIRECTORY, for every bucket ----------------------------------
# The first version generated only bucket-root pages, then linked every folder to
# `/<bucket>/<folder>/` — URLs with no object behind them, so every link 404'd
# with NoSuchKey. On object storage a browsable folder only exists if we publish
# an index.html for it, so we walk the whole tree and emit one per directory.
for (b in BUCKETS) {
  message(glue("  listing {b$name} ..."))
  objs <- gcs_list_all(b$name)
  if (isTRUE(attr(objs, "truncated")))
    message(glue("  WARNING: {b$name} listing truncated — pages will be incomplete"))
  # never index our own generated pages
  objs <- objs[!grepl("(^|/)index\\.html$", objs$key), , drop = FALSE]
  if (!nrow(objs)) {
    dirs <- ""
  } else {
    parts <- strsplit(objs$key, "/", fixed = TRUE)
    dirs  <- unique(c("", unlist(lapply(parts, function(p)
      if (length(p) > 1) vapply(seq_len(length(p) - 1),
        function(i) paste(p[seq_len(i)], collapse = "/"), character(1)) else NULL))))
  }
  message(glue("    {nrow(objs)} objects -> {length(dirs)} directory pages"))

  skip_re <- b$skip %||% NA_character_
  if (!is.na(skip_re)) {
    n0 <- length(dirs); dirs <- dirs[!grepl(skip_re, dirs)]
    message(glue("    skipping {n0 - length(dirs)} dirs owned by another generator ({skip_re})"))
  }
  for (d in dirs) {
    pre  <- if (nzchar(d)) paste0(d, "/") else ""
    here <- objs[startsWith(objs$key, pre), , drop = FALSE]
    rel  <- substring(here$key, nchar(pre) + 1)
    top  <- sub("/.*$", "", rel)
    isd  <- grepl("/", rel)
    agg  <- do.call(rbind, lapply(sort(unique(top)), function(tp) {
      sel <- top == tp
      data.frame(name = tp, dir = any(isd[sel]), n = sum(sel),
                 size = sum(here$size[sel]),
                 # a folder shows its NEWEST object's LastModified; `since` is its
                 # oldest — for write-once objects, when the folder was started.
                 # (The XML API has no timeCreated, so "since" is the honest name.)
                 modified = max(here$modified[sel]),
                 since    = min(here$modified[sel]), stringsAsFactors = FALSE)
    }))
    agg <- agg[order(!agg$dir, agg$name), , drop = FALSE]   # folders first
    notes <- if (!nzchar(d) && !is.null(b$folders)) b$folders else NULL
    rows <- paste0(vapply(seq_len(nrow(agg)), function(i) {
      a <- agg[i, ]
      href <- if (a$dir) glue("{SITE_URL}/{b$name}/{pre}{a$name}/")
              else       glue("{GCS_HOST}/{b$name}/{pre}{a$name}")
      lbl  <- if (a$dir) glue("{esc(a$name)}/") else esc(a$name)
      cnt  <- if (a$dir) glue(' <span class="chip">{fmt_n(a$n)}</span>') else ""
      note <- if (is.null(notes)) "" else {
        # notes[missing] is NA_character_, which %||% does NOT catch — the first
        # run published a literal "NA" for ducklake-staging/ (the provider.csv
        # failure mode all over again). An unlisted folder gets an empty cell.
        v <- notes[a$name]; if (is.na(v)) v <- ""
        glue('<td style="white-space:normal;font-size:.9em">{esc(v)}</td>')
      }
      # a folder's cell says modified (newest object) and, muted, since (oldest)
      when <- if (a$dir && substr(a$since, 1, 10) != substr(a$modified, 1, 10))
        glue('{fmt_dt(a$modified)}<br><span style="font-size:.85em;opacity:.65">since {substr(a$since, 1, 10)}</span>')
      else fmt_dt(a$modified)
      glue('<tr><td><a href="{href}">{lbl}</a>{cnt}</td>{note}',
           '<td class="num">{fmt_mb(a$size)}</td>',
           '<td class="num" title="oldest {esc(a$since)} · newest {esc(a$modified)}">{when}</td></tr>')
    }, character(1)), collapse = "\n")

    # breadcrumb back up through every ancestor
    segs <- if (nzchar(d)) strsplit(d, "/", fixed = TRUE)[[1]] else character()
    crumb <- glue('<a href="{SITE_URL}/">storage</a> / <a href="{SITE_URL}/{b$name}/">{b$name}</a>')
    acc <- ""
    for (s in segs) {
      acc <- if (nzchar(acc)) paste0(acc, "/", s) else s
      crumb <- glue('{crumb} / <a href="{SITE_URL}/{b$name}/{acc}/">{esc(s)}</a>')
    }
    note_th <- if (is.null(notes)) "" else '<th style="white-space:normal">contents</th>'
    body <- glue('
<div class="scroll"><table>
<thead><tr><th>name</th>{note_th}<th style="text-align:right">size</th><th style="text-align:right">modified</th></tr></thead>
<tbody>
{rows}
</tbody></table></div>')
    sub <- glue("{fmt_n(nrow(agg))} entries · {fmt_mb(sum(agg$size))}")
    ttl <- if (nzchar(d)) glue("{b$name}/{d}") else b$name
    pages[[length(pages) + 1]] <- list(
      html = page(ttl, if (nzchar(d)) sub else esc(b$desc), body,
                  crumb = glue('<p class="crumb">{crumb}</p>')),
      gcs  = glue("gs://{b$name}/{pre}index.html"),
      file = file.path(b$name, pre, "index.html"))
  }
}

# --- write / upload -----------------------------------------------------------
# Upload is ONE batched recursive copy of a local mirror, not a gcloud invocation
# per page: with ~1.5k directory pages, per-file calls (a few seconds of process
# startup each) would take hours.
tmp <- if (!is.na(OUT_DIR)) OUT_DIR else file.path(tempdir(), "storage_index")
unlink(tmp, recursive = TRUE); dir.create(tmp, showWarnings = FALSE, recursive = TRUE)
for (p in pages) {
  f <- file.path(tmp, p$file)
  dir.create(dirname(f), showWarnings = FALSE, recursive = TRUE)
  writeLines(p$html, f)
}
message(glue("  wrote {length(pages)} pages to {tmp}"))

if (DRY) {
  cat(glue("\nDRY RUN — {length(pages)} pages under {tmp}, nothing uploaded\n"))
  cat("  sample:\n")
  for (p in head(pages, 6)) cat(sprintf("    %s\n", p$gcs))
} else {
  gcloud <- Sys.which("gcloud")
  sub <- if (system2(gcloud, c("storage", "--help"), stdout = FALSE, stderr = FALSE) == 0)
    "storage" else c("alpha", "storage")
  # root page lives in a bucket but is not part of a bucket mirror
  root <- Filter(function(p) !grepl("/", p$file), pages)
  for (p in root) gcs_upload(file.path(tmp, p$file), p$gcs)
  for (b in BUCKETS) {
    d <- file.path(tmp, b$name)
    if (!dir.exists(d)) next
    message(glue("  uploading {b$name} pages ..."))
    # `cp --recursive <dir>/.` returns 0 having copied only the top level — it
    # reported success while every nested page silently stayed local. Glob the
    # entries instead, then VERIFY, because a zero exit status has already proved
    # not to mean the objects are there.
    res <- system2(gcloud, c(sub, "cp", "--recursive", "--content-type=text/html",
                             "--cache-control=no-cache",
                             Sys.glob(file.path(d, "*")), shQuote(glue("gs://{b$name}/"))),
                   stdout = TRUE, stderr = TRUE)
    if (!is.null(attr(res, "status"))) warning(glue("upload failed for {b$name}"))
    # spot-check the deepest page we generated for this bucket
    deep <- pages[vapply(pages, function(p) startsWith(p$file, paste0(b$name, "/")), logical(1))]
    if (length(deep)) {
      probe <- deep[[which.max(vapply(deep, function(p) lengths(regmatches(p$file,
                 gregexpr("/", p$file))), integer(1)))]]
      url <- sub("^gs://", "https://storage.googleapis.com/", probe$gcs)
      code <- tryCatch({ con <- url(url, open = "rb"); close(con); 200L },
                       error = function(e) 404L)
      if (code != 200L)
        warning(glue("VERIFY FAILED: {url} not readable after upload — nested pages may be missing"))
      else message(glue("    verified deepest page: {probe$gcs}"))
    }
  }
  cat(glue("\nuploaded {length(pages)} pages\n"))
  cat(glue("  root:   {SITE_URL}/\n"))
  for (b in BUCKETS) cat(glue("  bucket: {SITE_URL}/{b$name}/\n"))
}
