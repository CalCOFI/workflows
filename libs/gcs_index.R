# gcs_index.R — shared chrome + helpers for the generated GCS browsing pages.
#
# storage.googleapis.com serves OBJECTS, not directories: there is no folder
# listing, so every "folder" a user can browse is an index.html object we publish.
# Those pages span several generators (release index, bucket indexes, the
# storage.calcofi.io root), and they must LOOK like one site — so the skin and the
# object-listing helper live here rather than being re-typed per script.
#
# Self-contained by necessity: served straight off a bucket, so no external CSS,
# font or script can be referenced. Light/dark via prefers-color-scheme; wide
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
{GA_HTML}
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
  keys <- character(); sizes <- numeric(); marker <- NULL; truncated <- FALSE
  repeat {
    u <- glue("{GCS_HOST}/{bucket}?max-keys=1000")
    if (!is.null(marker)) u <- glue("{u}&marker={utils::URLencode(marker, reserved = TRUE)}")
    x <- tryCatch(paste(readLines(url(u), warn = FALSE), collapse = ""),
                  error = function(e) "")
    k <- regmatches(x, gregexpr("(?<=<Key>)[^<]+", x, perl = TRUE))[[1]]
    s <- regmatches(x, gregexpr("(?<=<Size>)[0-9]+", x, perl = TRUE))[[1]]
    if (!length(k)) break
    n <- min(length(k), length(s))
    keys <- c(keys, k[seq_len(n)]); sizes <- c(sizes, as.numeric(s[seq_len(n)]))
    more <- grepl("<IsTruncated>true", x, fixed = TRUE)
    if (!quiet && length(keys) %% 10000 < 1000)
      message(glue("    {bucket}: {length(keys)} objects ..."))
    if (!more) break
    if (length(keys) >= cap) { truncated <- TRUE; break }
    marker <- k[length(k)]
  }
  if (truncated)
    warning(glue("{bucket}: stopped at cap={cap}; directory pages will be INCOMPLETE"))
  out <- data.frame(key = keys, size = sizes, stringsAsFactors = FALSE)
  attr(out, "truncated") <- truncated
  out
}
