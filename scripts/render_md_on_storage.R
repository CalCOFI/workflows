#!/usr/bin/env Rscript
# render_md_on_storage.R — a readable page beside every markdown object on the public buckets.
#
# storage.calcofi.io serves objects as they are, so a link to RELEASES.md opened raw markdown.
# For every `*.md` object under the prefixes below this writes a sibling `*.html` in the same
# skin as the storage index pages (libs/gcs_index.R), with the raw source linked from the page,
# and only when the rendered bytes differ from what is already there (an MD5 read, not a
# re-upload — the same rule as calcofi4db::put_gcs_file()). Idempotent; run it after anything
# that writes a markdown object, and `scripts/publish_release_notes.R` calls it for the notes.
#
#   Rscript scripts/render_md_on_storage.R                  # every *.md under the prefixes below
#   Rscript scripts/render_md_on_storage.R gs://calcofi-db/ducklake/releases/RELEASES.md  …   # just these
#   Rscript scripts/render_md_on_storage.R --dry-run        # render locally, upload nothing
#
# The prefixes: the release notes (ducklake/releases), the staged portal bundles (publish/), the
# netCDF site and the archived source folders on calcofi-files-public.
librarian::shelf(commonmark, glue, here, calcofi4db, quiet = TRUE)
# libs/gcs_index.R finds gcloud with Sys.which(); an Rscript's PATH may not carry the SDK
Sys.setenv(PATH = paste(dirname(calcofi4db:::find_gcloud()), Sys.getenv("PATH"), sep = ":"))
source(here("libs/gcs_index.R"))

PREFIXES <- c("gs://calcofi-db/ducklake/releases/", "gs://calcofi-db/publish/",
              "gs://calcofi-files-public/netcdf/", "gs://calcofi-files-public/archive/")

args <- commandArgs(trailingOnly = TRUE)
dry  <- "--dry-run" %in% args
uris <- grep("^gs://", args, value = TRUE)

list_md <- function(prefix) {
  p <- calcofi4db:::parse_gcs_path(prefix)
  out <- system2(calcofi4db:::find_gcloud(), c("storage", "ls", "-r", shQuote(paste0(prefix, "**/*.md"))),
                 stdout = TRUE, stderr = FALSE)
  out <- out[grepl("^gs://.*\\.md$", out)]
  # `ls -r` on a wildcard also matches nothing under a folder that has none; fine
  unique(out)
}
if (!length(uris)) uris <- unlist(lapply(PREFIXES, list_md))
cat(length(uris), "markdown object(s)\n")

# the page: the markdown body in the index skin, the raw source one link away
render_one <- function(uri) {
  p <- calcofi4db:::parse_gcs_path(uri)
  https <- glue("https://storage.calcofi.io/{p$bucket}/{p$path}")
  local_md <- tempfile(fileext = ".md")
  system2(calcofi4db:::find_gcloud(), c("storage", "cp", shQuote(uri), shQuote(local_md)), stdout = FALSE, stderr = FALSE)
  if (!file.exists(local_md)) stop("could not fetch ", uri)
  md   <- readLines(local_md, warn = FALSE, encoding = "UTF-8")
  body <- commonmark::markdown_html(paste(md, collapse = "\n"), extensions = TRUE, smart = FALSE)
  title <- sub("^#\\s+", "", grep("^#\\s+", md, value = TRUE)[1])
  if (is.na(title) || !nzchar(title)) title <- basename(p$path)
  folder <- dirname(p$path)
  crumb  <- glue('<p class="crumb"><a href="https://storage.calcofi.io/{p$bucket}/{folder}/">{esc(folder)}</a> / ',
                 '{esc(basename(p$path))} · <a href="{https}">raw markdown ↗</a></p>')
  html <- page(title, glue("{basename(p$path)} on gs://{p$bucket}/{folder}"),
               glue('<article class="md">{body}</article>',
                    '<style>.md{{max-width:72ch;font-size:1rem}} .md h1{{font-size:1.4rem;margin:1.6rem 0 .4rem}} ',
                    '.md h2{{font-size:1.15rem;margin:1.4rem 0 .3rem}} .md h3{{font-size:1rem;margin:1.1rem 0 .2rem}} ',
                    '.md code{{font:.9em var(--mono);background:var(--panel);padding:.05em .3em;border-radius:4px}} ',
                    '.md pre{{background:var(--panel);padding:.8rem 1rem;border-radius:8px;overflow-x:auto}} .md pre code{{background:none;padding:0}} ',
                    '.md table{{font-size:.9rem;margin:.6rem 0}} .md th,.md td{{white-space:normal}} ',
                    '.md ul,.md ol{{padding-left:1.4em}} .md li{{margin:.15em 0}} .md blockquote{{margin:.8rem 0;padding:.2rem 1rem;border-left:3px solid var(--border);color:var(--muted)}}</style>'),
               crumb = crumb)
  local_html <- sub("\\.md$", ".html", local_md); writeLines(html, local_html, useBytes = TRUE)
  target <- sub("\\.md$", ".html", uri)
  if (dry) { cat("dry:", target, "\n"); return(invisible(FALSE)) }
  # md5-compared first (the same rule as calcofi4db::put_gcs_file()), then uploaded with the
  # content type a browser renders — the package's gcloud path sends none, and an HTML object
  # served as octet-stream downloads instead of opening
  if (identical(gcs_object_md5(target), local_md5_base64(local_html))) {
    cat("unchanged:", target, "\n"); return(invisible(FALSE))
  }
  gcs_upload(local_html, target, content_type = "text/html", cache_control = "no-cache")
  cat("rendered:", sub("^gs://", "https://storage.calcofi.io/", target), "\n")
  invisible(TRUE)
}
done <- 0L
for (u in uris) tryCatch({ render_one(u); done <- done + 1L },
                        error = function(e) message("skip ", u, ": ", conditionMessage(e), " [", deparse(conditionCall(e))[1], "]"))
cat("rendered", done, "of", length(uris), "\n")
