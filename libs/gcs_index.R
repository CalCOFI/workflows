# gcs_index.R — shared chrome + helpers for the generated GCS browsing pages.
#
# storage.googleapis.com serves OBJECTS, not directories: there is no folder
# listing, so every "folder" a user can browse is an index.html object we publish.
# Those pages span several generators (release index, bucket indexes, the
# storage.calcofi.io root), and they must LOOK like one site — so the skin and the
# object-listing helper live here rather than being re-typed per script.
#
# The chrome is the calcofi.io brand contract (https://calcofi.io/brand/v1/):
# favicons, theme.css + theme.js hotlinked from calcofi.io (a bucket-served page
# may reference them; only the listing styles are inline), dark by default with
# light via <html data-theme="light">, the shared .cc-header / .cc-footer. Wide
# tables scroll inside their own container rather than forcing the page sideways.
librarian::shelf(glue, quiet = TRUE)

# NB: deliberately NOT called BUCKET_URL — build_release_index.R defines its own
# bucket-scoped BUCKET_URL, and a same-named constant here would silently
# overwrite it on source() and strip the bucket out of every generated link.
GCS_HOST   <- "https://storage.googleapis.com"   # object keys hang off <this>/<bucket>
SITE_URL   <- "https://storage.calcofi.io"       # browsable front door (Caddy adds
                                                 # folder -> index.html rewriting)

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || identical(a, "")) b else a
esc <- function(x) { x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE); gsub(">", "&gt;", x, fixed = TRUE) }
fmt_n  <- function(n) formatC(as.numeric(n), format = "d", big.mark = ",")
fmt_mb <- function(b) { b <- as.numeric(b)
  ifelse(is.na(b), "—",
    ifelse(b >= 1073741824, sprintf("%.2f GB", b / 1073741824),
      ifelse(b >= 1048576, sprintf("%.1f MB", b / 1048576),
        sprintf("%.0f KB", pmax(b / 1024, 1))))) }

# GA4, site property — the same tag every CalCOFI page carries (canonical copy:
# CalCOFI/analytics snippets/gtag-site.html). Built here as a plain string
# rather than inline in page()'s glue template, because glue would try to
# interpolate the `{ content_group: ... }` braces.
#
# NOTE this only ever counts BROWSING. These pages are the human front door to
# buckets whose real traffic is machines fetching parquet/netcdf directly, which
# runs no JavaScript. Request counts come from the Caddy access logs instead.
GA_HTML <- paste0(
  '<script>window.__CC_GA = location.hostname.endsWith("calcofi.io") && !navigator.webdriver;</script>\n',
  '<script async src="https://www.googletagmanager.com/gtag/js?id=G-0HVK8TDMCF"></script>\n',
  '<script>\n',
  '  window.dataLayer = window.dataLayer || [];\n',
  '  function gtag(){ dataLayer.push(arguments); }\n',
  '  if (window.__CC_GA) {\n',
  '    gtag("js", new Date());\n',
  '    gtag("config", "G-0HVK8TDMCF", { content_group: "storage" });\n',
  '  }\n',
  '</script>')

# --- shared page chrome -------------------------------------------------------
# Brand head block pasted verbatim from brand/v1/head.html (favicon set, the
# inline pre-paint theme snippet so the first paint is already the right colour,
# theme.css, theme.js), then the page's own listing styles. The token block
# mirrors theme.css so the page still reads if calcofi.io is unreachable.
BRAND_URL  <- "https://calcofi.io/brand/v1"
BRAND_HEAD <- paste0(
  '<link rel="icon" type="image/x-icon" href="', BRAND_URL, '/favicon.ico">\n',
  '<link rel="icon" type="image/png" sizes="32x32" href="', BRAND_URL, '/favicon-32x32.png">\n',
  '<link rel="icon" type="image/png" sizes="16x16" href="', BRAND_URL, '/favicon-16x16.png">\n',
  '<link rel="apple-touch-icon" sizes="180x180" href="', BRAND_URL, '/apple-touch-icon.png">\n',
  '<script>(function(){var m=/[?&]theme=(dark|light)\\b/.exec(location.search),',
  'c=/(?:^|;\\s*)cc_theme=(dark|light)/.exec(document.cookie),s=null;',
  'try{s=localStorage.getItem("theme")}catch(e){}',
  'var t=(m&&m[1])||(c&&c[1])||(s==="light"||s==="dark"?s:null)||"dark",d=document.documentElement;',
  'd.dataset.theme=t;d.setAttribute("data-bs-theme",t);',
  'd.setAttribute("data-md-color-scheme",t==="dark"?"slate":"default");d.style.colorScheme=t})();</script>\n',
  '<link rel="stylesheet" href="', BRAND_URL, '/theme.css">\n',
  '<script defer src="', BRAND_URL, '/theme.js"></script>')

# logo -> calcofi.io, title -> the storage front door, the site's own links,
# the theme toggle (theme.js wires it). Absolute hrefs: release pages are also
# reachable under storage.googleapis.com/<bucket>/..., where "/" is not ours.
BRAND_HEADER <- glue('
<header class="cc-header">
  <a class="cc-home" href="https://calcofi.io" aria-label="CalCOFI.io home">
    <img class="cc-logo-dark"  src="{BRAND_URL}/logo_calcofi.svg"       alt="CalCOFI" width="32" height="32">
    <img class="cc-logo-light" src="{BRAND_URL}/logo_calcofi_light.svg" alt="CalCOFI" width="32" height="32">
  </a>
  <a class="cc-title" href="{SITE_URL}/">storage</a>
  <span class="cc-spacer"></span>
  <nav class="cc-links">
    <a href="{SITE_URL}/calcofi-db/ducklake/releases/">releases</a>
    <a href="{SITE_URL}/calcofi-files-public/netcdf/">netcdf</a>
    <a href="https://calcofi.io/docs/">docs</a>
  </nav>
  <button class="cc-theme-toggle" type="button" aria-label="Toggle dark / light theme">🌓</button>
</header>')

# the script rendering the page, for the footer (Rscript passes --file=; falls
# back to the release generator when sourced interactively)
GENERATOR <- local({
  f <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
  if (length(f)) file.path("scripts", basename(f[1])) else "scripts/build_release_index.R" })

page <- function(title, subtitle, body_html, crumb = "") glue('
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(title)}</title>
{BRAND_HEAD}
{GA_HTML}
<style>
  :root {{
    --bg:#1b1d20; --panel:#24272b; --panel-2:#2c3035; --border:#3a3f44;
    --fg:#e6e9ed; --muted:#9aa0a6; --accent:#4dabf7; --accent-d:#339af0;
    --sans:system-ui,-apple-system,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif;
    --mono:ui-monospace,"SF Mono",Menlo,Consolas,"Liberation Mono",monospace;
    color-scheme:dark;
  }}
  :root[data-theme="light"] {{
    --bg:#ffffff; --panel:#f8f9fa; --panel-2:#ffffff; --border:#dee2e6;
    --fg:#212529; --muted:#6c757d; --accent:#2780e3; --accent-d:#1c69bf;
    color-scheme:light;
  }}
  * {{ box-sizing:border-box; }}
  body {{ margin:0; background:var(--bg); color:var(--fg); font:16px/1.55 var(--sans); }}
  .wrap {{ max-width:60rem; margin:0 auto; padding:2rem 1.25rem 4rem; }}
  h1 {{ font-size:1.5rem; margin:0 0 .2rem; letter-spacing:-.01em; }}
  .sub {{ color:var(--muted); margin:0 0 1.5rem; font-size:.95rem; }}
  .crumb {{ font-size:.85rem; color:var(--muted); margin:0 0 1rem; }}
  a {{ color:var(--accent); text-decoration:none; }}
  a:hover {{ color:var(--accent-d); text-decoration:underline; }}
  .scroll {{ overflow-x:auto; border:1px solid var(--border); border-radius:8px; }}
  table {{ border-collapse:collapse; width:100%; font-size:.92rem; }}
  th, td {{ text-align:left; padding:.5rem .7rem; border-bottom:1px solid var(--border); white-space:nowrap; }}
  th {{ background:var(--panel); font-weight:600; font-size:.82rem; text-transform:uppercase;
        letter-spacing:.04em; color:var(--muted); }}
  tr:last-child td {{ border-bottom:none; }}
  td.num {{ text-align:right; font-variant-numeric:tabular-nums; }}
  .chip {{ display:inline-block; background:var(--panel-2); color:var(--accent); border:1px solid var(--border);
    border-radius:999px; padding:.05rem .5rem; font-size:.75rem; font-weight:600; }}
  .note {{ background:var(--panel); border:1px solid var(--border); border-radius:8px;
    padding:.8rem 1rem; font-size:.88rem; margin:1.5rem 0; color:var(--muted); }}
  .note code, code {{ font-family:var(--mono); font-size:.85em; }}
</style>
</head>
<body>
{BRAND_HEADER}
<div class="wrap">
{crumb}
<h1>{esc(title)}</h1>
<p class="sub">{subtitle}</p>
{body_html}
<footer class="cc-footer"><p>Generated by <code>{GENERATOR}</code> in
<a href="https://github.com/CalCOFI/workflows">CalCOFI/workflows</a>.
Objects are served directly from Google Cloud Storage.</p>
<p><a href="https://calcofi.io">calcofi.io</a>
· <a href="https://github.com/CalCOFI">github.com/CalCOFI</a>
· <a href="https://status.calcofi.io">status</a></p></footer>
</div></body></html>')


#' List every object under a bucket prefix via the XML API.
#' @return data.frame(key, size); empty if the prefix has no objects.
gcs_list <- function(bucket, prefix = "", max_keys = 1000) {
  u <- glue("{GCS_HOST}/{bucket}?prefix={prefix}&max-keys={max_keys}")
  x <- tryCatch(paste(readLines(url(u), warn = FALSE), collapse = ""),
                error = function(e) "")
  keys  <- regmatches(x, gregexpr("(?<=<Key>)[^<]+", x, perl = TRUE))[[1]]
  sizes <- regmatches(x, gregexpr("(?<=<Size>)[0-9]+", x, perl = TRUE))[[1]]
  n <- min(length(keys), length(sizes))
  if (!n) return(data.frame(key = character(), size = numeric()))
  data.frame(key = keys[seq_len(n)], size = as.numeric(sizes[seq_len(n)]),
             stringsAsFactors = FALSE)
}

#' Upload one rendered page. `gcloud storage` is not in the default release track
#' everywhere (the CalCOFI server only has it under `alpha`), so probe once.
gcs_upload <- function(local, gcs, content_type = "text/html",
                       cache_control = "no-cache") {
  gcloud <- Sys.which("gcloud")
  if (!nzchar(gcloud)) stop("gcloud not found")
  sub <- if (system2(gcloud, c("storage", "--help"), stdout = FALSE,
                     stderr = FALSE) == 0) "storage" else c("alpha", "storage")
  res <- system2(gcloud, c(sub, "cp", glue("--content-type={content_type}"),
                           glue("--cache-control={cache_control}"),
                           shQuote(local), shQuote(gcs)),
                 stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(res, "status"))) warning(glue("upload failed: {gcs}"))
  invisible(res)
}

#' List EVERY object in a bucket, paginating the XML API.
#'
#' The single-request gcs_list() silently stops at max-keys, which for a bucket
#' with 200k+ objects means a directory tree that looks complete and is not. This
#' pages through with `marker` and reports explicitly when it hits `cap`, because
#' a truncated listing produces index pages that omit files without saying so.
#' @return data.frame(key, size) plus attr(, "truncated")
gcs_list_all <- function(bucket, cap = 250000, quiet = FALSE) {
  keys <- character(); sizes <- numeric(); mods <- character(); marker <- NULL; truncated <- FALSE
  repeat {
    u <- glue("{GCS_HOST}/{bucket}?max-keys=1000")
    if (!is.null(marker)) u <- glue("{u}&marker={utils::URLencode(marker, reserved = TRUE)}")
    x <- tryCatch(paste(readLines(url(u), warn = FALSE), collapse = ""),
                  error = function(e) "")
    k <- regmatches(x, gregexpr("(?<=<Key>)[^<]+", x, perl = TRUE))[[1]]
    s <- regmatches(x, gregexpr("(?<=<Size>)[0-9]+", x, perl = TRUE))[[1]]
    m <- regmatches(x, gregexpr("(?<=<LastModified>)[^<]+", x, perl = TRUE))[[1]]
    if (!length(k)) break
    n <- min(length(k), length(s), length(m))
    keys <- c(keys, k[seq_len(n)]); sizes <- c(sizes, as.numeric(s[seq_len(n)]))
    mods <- c(mods, m[seq_len(n)])
    more <- grepl("<IsTruncated>true", x, fixed = TRUE)
    if (!quiet && length(keys) %% 10000 < 1000)
      message(glue("    {bucket}: {length(keys)} objects ..."))
    if (!more) break
    if (length(keys) >= cap) { truncated <- TRUE; break }
    marker <- k[length(k)]
  }
  if (truncated)
    warning(glue("{bucket}: stopped at cap={cap}; directory pages will be INCOMPLETE"))
  # LastModified rides along from the same XML — zero extra requests (D30);
  # ISO 8601 UTC strings, so lexicographic min/max ARE oldest/newest
  out <- data.frame(key = keys, size = sizes, modified = mods, stringsAsFactors = FALSE)
  attr(out, "truncated") <- truncated
  out
}

# render an ISO LastModified for a listing cell: "2026-08-31 17:05Z"
fmt_dt <- function(iso) ifelse(is.na(iso) | !nzchar(iso), "",
                               paste0(substr(gsub("T", " ", iso), 1, 16), "Z"))
