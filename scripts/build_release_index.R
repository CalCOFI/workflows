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

BUCKET   <- "calcofi-db"
PREFIX   <- "ducklake/releases"
HTTPS    <- glue("https://storage.googleapis.com/{BUCKET}/{PREFIX}")
XML_API  <- glue("https://storage.googleapis.com/{BUCKET}")
ARGV     <- commandArgs(trailingOnly = TRUE)
DRY      <- any(ARGV %in% c("--dry-run", "-n"))
OUT_DIR  <- sub("^--out=", "", grep("^--out=", ARGV, value = TRUE)[1])
gcloud   <- Sys.which("gcloud")
if (!DRY && !nzchar(gcloud)) stop("gcloud not found; use --dry-run")

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || identical(a, "")) b else a
esc <- function(x) { x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE); gsub(">", "&gt;", x, fixed = TRUE) }
fmt_n  <- function(n) formatC(as.numeric(n), format = "d", big.mark = ",")
fmt_mb <- function(b) { b <- as.numeric(b)
  ifelse(is.na(b), "—",
    ifelse(b >= 1073741824, sprintf("%.2f GB", b / 1073741824),
      ifelse(b >= 1048576, sprintf("%.1f MB", b / 1048576),
        sprintf("%.0f KB", pmax(b / 1024, 1))))) }

# --- shared page chrome -------------------------------------------------------
# Self-contained: served straight off GCS, so no external CSS/font/script can be
# referenced (and a strict reader may block them anyway). Light/dark via
# prefers-color-scheme; wide tables scroll inside their own container.
page <- function(title, subtitle, body_html, crumb = "") glue('
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light dark">
<title>{esc(title)}</title>
<style>
  :root {{
    --bg:#ffffff; --fg:#1a1f24; --muted:#5b6670; --line:#e3e8ec;
    --accent:#1b6ec2; --chip:#eef4fa; --head:#f6f8fa;
  }}
  @media (prefers-color-scheme: dark) {{
    :root {{
      --bg:#12171c; --fg:#e6edf3; --muted:#9aa7b2; --line:#26303a;
      --accent:#6cb6ff; --chip:#182430; --head:#182028;
    }}
  }}
  * {{ box-sizing:border-box; }}
  body {{ margin:0; padding:2rem 1.25rem 4rem; background:var(--bg); color:var(--fg);
    font:16px/1.55 Inter,-apple-system,BlinkMacSystemFont,"Segoe UI",system-ui,sans-serif; }}
  .wrap {{ max-width:60rem; margin:0 auto; }}
  h1 {{ font-size:1.5rem; margin:0 0 .2rem; letter-spacing:-.01em; }}
  .sub {{ color:var(--muted); margin:0 0 1.5rem; font-size:.95rem; }}
  .crumb {{ font-size:.85rem; color:var(--muted); margin:0 0 1rem; }}
  a {{ color:var(--accent); text-decoration:none; }}
  a:hover {{ text-decoration:underline; }}
  .scroll {{ overflow-x:auto; border:1px solid var(--line); border-radius:8px; }}
  table {{ border-collapse:collapse; width:100%; font-size:.92rem; }}
  th, td {{ text-align:left; padding:.5rem .7rem; border-bottom:1px solid var(--line); white-space:nowrap; }}
  th {{ background:var(--head); font-weight:600; font-size:.82rem; text-transform:uppercase;
        letter-spacing:.04em; color:var(--muted); }}
  tr:last-child td {{ border-bottom:none; }}
  td.num {{ text-align:right; font-variant-numeric:tabular-nums; }}
  .chip {{ display:inline-block; background:var(--chip); color:var(--accent);
    border-radius:999px; padding:.05rem .5rem; font-size:.75rem; font-weight:600; }}
  .note {{ background:var(--chip); border:1px solid var(--line); border-radius:8px;
    padding:.8rem 1rem; font-size:.88rem; margin:1.5rem 0; color:var(--muted); }}
  .note code, code {{ font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:.85em; }}
  footer {{ margin-top:2.5rem; font-size:.82rem; color:var(--muted); }}
</style>
</head>
<body><div class="wrap">
{crumb}
<h1>{esc(title)}</h1>
<p class="sub">{subtitle}</p>
{body_html}
<footer>Generated by <code>scripts/build_release_index.R</code> in
<a href="https://github.com/CalCOFI/workflows">CalCOFI/workflows</a>.
Objects are served directly from Google Cloud Storage.</footer>
</div></body></html>')

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
release_page <- function(ver, is_latest) {
  objs <- list_objects(ver)
  cat_url <- glue("{HTTPS}/{ver}/catalog.json")
  ctl <- tryCatch(fromJSON(cat_url, simplifyDataFrame = TRUE), error = function(e) NULL)
  tbls <- if (!is.null(ctl) && is.data.frame(ctl$tables)) ctl$tables else NULL

  objs$base <- basename(objs$key)
  pq <- objs[grepl("/parquet/", objs$key), ]
  sc <- objs[!grepl("/parquet/", objs$key), ]

  rows_of <- function(nm) if (!is.null(tbls) && nm %in% tbls$name)
    tbls$rows[match(nm, tbls$name)] else NA
  supp_of <- function(nm) if (!is.null(tbls) && nm %in% tbls$name)
    isTRUE(tbls$supplemental[match(nm, tbls$name)]) else FALSE

  pq_rows <- if (nrow(pq)) paste0(vapply(seq_len(nrow(pq)), function(i) {
    nm <- sub("[.]parquet$", "", pq$base[i])
    glue('<tr><td><a href="{HTTPS}/{pq$key[i]}">{esc(pq$base[i])}</a>',
         '{if (supp_of(nm)) " <span class=\\"chip\\">supplemental</span>" else ""}</td>',
         '<td class="num">{if (is.na(rows_of(nm))) "—" else fmt_n(rows_of(nm))}</td>',
         '<td class="num">{fmt_mb(pq$size[i])}</td></tr>')
  }, character(1)), collapse = "\n") else '<tr><td colspan="3">(none)</td></tr>'

  sc_rows <- if (nrow(sc)) paste0(vapply(seq_len(nrow(sc)), function(i)
    glue('<tr><td><a href="{HTTPS}/{sc$key[i]}">{esc(sc$base[i])}</a></td>',
         '<td class="num">{fmt_mb(sc$size[i])}</td></tr>'), character(1)),
    collapse = "\n") else '<tr><td colspan="2">(none)</td></tr>'

  body <- glue('
<div class="scroll"><table>
<thead><tr><th>table (parquet)</th><th style="text-align:right">rows</th><th style="text-align:right">size</th></tr></thead>
<tbody>
{pq_rows}
</tbody></table></div>

<h1 style="font-size:1.1rem;margin:2rem 0 .2rem">Sidecars</h1>
<p class="sub">Machine-readable descriptions of this release.</p>
<div class="scroll"><table>
<thead><tr><th>file</th><th style="text-align:right">size</th></tr></thead>
<tbody>
{sc_rows}
</tbody></table></div>

<div class="note">
Read directly with DuckDB — no download needed:<br>
<code>SELECT * FROM read_parquet(\'{HTTPS}/{ver}/parquet/obs.parquet\') LIMIT 10;</code>
</div>')

  sub <- glue('{ctl$release_date %||% ""} · {nrow(pq)} tables · ',
              '{fmt_n(ctl$total_rows %||% 0)} rows · {fmt_mb(ctl$total_size %||% NA)}',
              '{if (is_latest) " · <span class=\\"chip\\">latest</span>" else ""}')
  page(glue("CalCOFI release {ver}"), sub, body,
       crumb = glue('<p class="crumb"><a href="{HTTPS}/index.html">← all releases</a></p>'))
}

# --- root page ----------------------------------------------------------------
root_rows <- paste0(vapply(versions, function(v) {
  is_l <- identical(v$version, latest)
  glue('<tr><td><a href="{HTTPS}/{v$version}/index.html">{esc(v$version)}</a>',
       '{if (is_l) " <span class=\\"chip\\">latest</span>" else ""}</td>',
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
  f <- file.path(tmp, glue("{v$version}.html"))
  writeLines(release_page(v$version, identical(v$version, latest)), f)
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
