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
       entry = "ducklake/releases/"),
  list(name  = "calcofi-files-public",
       title = "Published files",
       desc  = paste("Derived products published for download, including whole-dataset",
                     "CF NetCDF files, spatial layers and sync manifests."),
       entry = ""),
  list(name  = "calcofi-projects",
       title = "Project outputs",
       desc  = "Outputs from individual CalCOFI projects and analyses.",
       entry = "")
)

# --- root page ----------------------------------------------------------------
root_cards <- paste0(vapply(BUCKETS, function(b) {
  href <- glue("{SITE_URL}/{b$name}/{b$entry}")
  glue('<tr><td><a href="{href}"><code>{esc(b$name)}</code></a><br>',
       '<span style="font-size:.9em">{esc(b$title)}</span></td>',
       '<td style="white-space:normal">{esc(b$desc)}</td></tr>')
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
always holds the promoted release. Prefer a form? Try the browser query app at
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

# --- one index per bucket -----------------------------------------------------
# Top-level entries only: these buckets hold tens of thousands of objects, so a
# flat listing would be unusable (and slow). Folders link onward; where a folder
# has its own generated index (e.g. ducklake/releases/) that page takes over.
for (b in BUCKETS) {
  objs <- gcs_list(b$name, prefix = "", max_keys = 5000)
  if (!nrow(objs)) {
    body <- '<div class="note">This bucket is empty, or its listing is not public.</div>'
  } else {
    top    <- sub("/.*$", "", objs$key)
    is_dir <- grepl("/", objs$key)
    agg <- do.call(rbind, lapply(sort(unique(top)), function(tp) {
      sel <- top == tp
      data.frame(name = tp, dir = any(is_dir[sel]), n = sum(sel),
                 size = sum(objs$size[sel]), stringsAsFactors = FALSE)
    }))
    rows <- paste0(vapply(seq_len(nrow(agg)), function(i) {
      a <- agg[i, ]
      href <- if (a$dir) glue("{SITE_URL}/{b$name}/{a$name}/")
              else glue("{GCS_HOST}/{b$name}/{a$name}")
      label <- if (a$dir) glue("{esc(a$name)}/") else esc(a$name)
      cnt <- if (a$dir) glue('<span class="chip">{fmt_n(a$n)} objects</span>') else ""
      glue('<tr><td><a href="{href}">{label}</a> {cnt}</td>',
           '<td class="num">{fmt_mb(a$size)}</td></tr>')
    }, character(1)), collapse = "\n")
    body <- glue('
<div class="scroll"><table>
<thead><tr><th>entry</th><th style="text-align:right">size</th></tr></thead>
<tbody>
{rows}
</tbody></table></div>
<div class="note">Top-level entries only. Folders that have their own generated
index (such as <code>ducklake/releases/</code>) open into it.</div>')
  }
  pages[[length(pages) + 1]] <- list(
    html = page(glue("{b$name}"), esc(b$desc), body,
                crumb = glue('<p class="crumb"><a href="{SITE_URL}/">← all buckets</a></p>')),
    gcs  = glue("gs://{b$name}/index.html"),
    file = glue("{b$name}.html"))
  message(glue("  rendered {b$name}"))
}

# --- write / upload -----------------------------------------------------------
tmp <- if (!is.na(OUT_DIR)) OUT_DIR else file.path(tempdir(), "storage_index")
dir.create(tmp, showWarnings = FALSE, recursive = TRUE)
for (p in pages) writeLines(p$html, file.path(tmp, p$file))

if (DRY) {
  cat("\nDRY RUN — nothing uploaded:\n")
  for (p in pages) cat(sprintf("  %s  ->  %s\n", file.path(tmp, p$file), p$gcs))
} else {
  for (p in pages) gcs_upload(file.path(tmp, p$file), p$gcs)
  cat(glue("\nuploaded {length(pages)} pages\n"))
  cat(glue("  root:   {SITE_URL}/\n"))
  for (b in BUCKETS) cat(glue("  bucket: {SITE_URL}/{b$name}/\n"))
}
