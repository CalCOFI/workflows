#!/usr/bin/env Rscript
# build_netcdf_index.R
#
# Generate the browsable index for the published CF NetCDF products:
#   netcdf/index.html          every dataset, its latest release, size, CF scope
#   netcdf/{dataset}/index.html  that dataset's release history
#
# Driven entirely by the per-dataset manifests.json written by
# cc_netcdf_publish(), so the page cannot claim a file that was never published.
# Per-release pages are written by the publish notebooks themselves.
#
# Supersedes the index written by scripts/publish_netcdf.sh, which listed two
# flat files with no version and no provenance.
#
# Usage:
#   Rscript scripts/build_netcdf_index.R [--dry-run] [--out=DIR]
#
# Needs write credentials: the CalCOFI server has read-only storage scopes.
librarian::shelf(glue, jsonlite, quiet = TRUE)
WF <- if (nzchar(Sys.getenv("CALCOFI_WORKFLOWS"))) Sys.getenv("CALCOFI_WORKFLOWS") else getwd()
source(file.path(WF, "libs/gcs_index.R"))

ARGV    <- commandArgs(trailingOnly = TRUE)
DRY     <- any(ARGV %in% c("--dry-run", "-n"))
OUT_DIR <- sub("^--out=", "", grep("^--out=", ARGV, value = TRUE)[1])
BUCKET  <- "calcofi-files-public"
SITE    <- glue("{SITE_URL}/{BUCKET}/netcdf")

# Discover datasets from the published manifests rather than a hardcoded list —
# a dataset appears here exactly when its publish notebook has actually run.
objs <- gcs_list(BUCKET, prefix = "netcdf/", max_keys = 5000)
dsets <- sort(unique(sub("^netcdf/([^/]+)/manifests\\.json$", "\\1",
  grep("^netcdf/[^/]+/manifests\\.json$", objs$key, value = TRUE))))
message(glue("datasets with manifests: {paste(dsets, collapse = ', ')}"))

# Files published before the versioned layout existed: flat, no release in the
# path, built from the ERDDAP serving snapshot rather than a release. Listed
# separately and labelled, NOT quietly mixed in with the versioned products.
legacy <- objs[grepl("^netcdf/[^/]+\\.nc$", objs$key), , drop = FALSE]

rows <- character()
for (d in dsets) {
  h <- tryCatch(fromJSON(glue("{SITE}/{d}/manifests.json"), simplifyDataFrame = FALSE),
                error = function(e) NULL)
  if (is.null(h) || !length(h$releases)) next
  cur <- h$releases[[1]]
  n_rel <- length(h$releases)
  rows <- c(rows, glue(
    '<tr><td><a href="{SITE}/{d}/">{esc(d)}</a></td>',
    '<td><a href="{SITE}/{d}/{cur$version}/">{cur$version}</a></td>',
    '<td class="num">{fmt_mb(cur$bytes)}</td>',
    '<td class="num">{n_rel}</td>',
    '<td style="white-space:normal">{esc(substr(cur$cf_scope, 1, 90))}…</td></tr>'))

  # per-dataset page: full release history, showing which releases reused bytes
  hrows <- paste0(vapply(h$releases, function(r) glue(
    '<tr><td><a href="{SITE}/{d}/{r$version}/">{r$version}</a></td>',
    '<td>{substr(r$generated_utc, 1, 10)}</td>',
    '<td class="num">{fmt_mb(r$bytes)}</td>',
    '<td>{if (is.null(r$identical_to) || is.na(r$identical_to)) "new bytes" else
          paste0("identical to ", r$identical_to)}</td></tr>'), character(1)),
    collapse = "\n")
  dpage <- page(glue("{d} — CF NetCDF releases"),
    glue("{n_rel} release(s) · latest {cur$version}"),
    glue('<div class="scroll"><table><thead><tr><th>release</th><th>built</th>',
         '<th style="text-align:right">size</th><th>bytes</th></tr></thead><tbody>',
         '{hrows}</tbody></table></div>',
         '<div class="note"><b>Versioning.</b> Paths are named for the database ',
         'release so a URL always answers "which release is this?". When a build is ',
         'byte-identical to an earlier release the bytes are NOT duplicated — the ',
         'release still gets a manifest and page, and the download points at the ',
         'existing object. <code>latest.txt</code> holds the newest release.',
         '<br><br><b>CF scope.</b> {esc(cur$cf_scope)}</div>'),
    crumb = glue('<p class="crumb"><a href="{SITE}/">netcdf</a></p>'))
  assign(glue("page_{d}"), dpage)
}

legacy_rows <- if (nrow(legacy)) paste0(vapply(seq_len(nrow(legacy)), function(i) {
  sprintf('<tr><td><a href="%s/%s/%s">%s</a></td><td class="num">%s</td></tr>',
          GCS_HOST, BUCKET, legacy$key[i], esc(basename(legacy$key[i])),
          fmt_mb(legacy$size[i]))
}, character(1)), collapse = "\n") else ""

legacy_html <- if (nzchar(legacy_rows)) paste0(
  '<h1 style="font-size:1.1rem;margin:2rem 0 .2rem">Legacy files</h1>',
  '<p class="sub">Published before the versioned layout, from an ERDDAP serving ',
  'snapshot rather than a database release — so their provenance cannot be traced ',
  'to a release. Retained only where no versioned replacement exists yet.</p>',
  '<div class="scroll"><table><thead><tr><th>file</th>',
  '<th style="text-align:right">size</th></tr></thead><tbody>',
  legacy_rows, '</tbody></table></div>') else ""

body <- glue('
<div class="scroll"><table>
<thead><tr><th>dataset</th><th>latest</th><th style="text-align:right">size</th>
<th style="text-align:right">releases</th><th style="white-space:normal">CF scope</th></tr></thead>
<tbody>
{paste(rows, collapse = "\n")}
</tbody></table></div>

<div class="note">
<b>What these are.</b> One self-documenting file per dataset, generated from the
CalCOFI integrated database by the <code>publish_&lt;dataset&gt;_to-netcdf</code>
workflows. Units, standard names, coordinate conventions and provenance travel
<i>inside</i> the file, so a CF-aware tool reads it without reference to anything
else.
<br><br>
<b>Not all are fully CF.</b> CF defines profile and trajectory geometries but no
feature type for a tow → net → taxon → size-bin hierarchy. Files that nest use
netCDF-4 groups with explicit <code>parent_index</code> links and say so in their
<code>cf_scope</code> attribute. Read that attribute before assuming compliance.
<br><br>
<b>Versioned by database release.</b> Browse a dataset for its history, or fetch
<code>{SITE}/&lt;dataset&gt;/latest.txt</code>.
</div>
{legacy_html}')

pages <- list(list(html = page("CalCOFI CF NetCDF",
    glue("{length(dsets)} dataset(s) · versioned by database release"), body,
    crumb = sprintf('<p class="crumb"><a href="%s/%s/">%s</a></p>', SITE_URL, BUCKET, BUCKET)),
  gcs = glue("gs://{BUCKET}/netcdf/index.html"), file = "index.html"))
for (d in dsets) pages[[length(pages) + 1]] <- list(
  html = get(glue("page_{d}")), gcs = glue("gs://{BUCKET}/netcdf/{d}/index.html"),
  file = glue("{d}.html"))

tmp <- if (!is.na(OUT_DIR)) OUT_DIR else file.path(tempdir(), "netcdf_index")
dir.create(tmp, showWarnings = FALSE, recursive = TRUE)
for (p in pages) writeLines(p$html, file.path(tmp, p$file))
if (DRY) {
  cat(glue("\nDRY RUN — {length(pages)} pages under {tmp}\n"))
  for (p in pages) cat(sprintf("  %s\n", p$gcs))
} else {
  for (p in pages) gcs_upload(file.path(tmp, p$file), p$gcs)
  cat(glue("\nuploaded {length(pages)} pages -> {SITE}/\n"))
}
