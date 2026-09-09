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
librarian::shelf(commonmark, glue, here, jsonlite, calcofi4db, quiet = TRUE)
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

# a table of contents for every rendered page: an id on each h1–h3 (slug of its text, made
# unique), a nested list in a sticky aside on a wide screen and a collapsed <details> above the
# text on a narrow one, with the heading in view highlighted as the reader scrolls. RELEASES.md is
# 23 release sections deep; without this it is a wall.
#
# a heading that *starts* with a release version — `v2026.09.06 (2026-09-06)`, or a range
# `v2026.08.04 – v2026.08.06` — is anchored on the version string itself, `id="v2026.09.06"` (dots
# are legal in an id and in a fragment), so anything holding a version can link
# `RELEASES.html#v{version}` without reproducing the slug rule or knowing the release date. The
# slug that heading used to carry (`v2026-09-06-2026-09-06`: the version *and* the date, both
# transformed) stays as an empty <a id> inside it so a bookmark on it still resolves, and every
# other version the heading spans gets one of those too. Every other heading keeps its slug id.
slug <- function(x) { x <- tolower(gsub("<[^>]+>", "", x)); x <- gsub("[^a-z0-9]+", "-", x); gsub("^-+|-+$", "", x) }
VER_RX <- "v[0-9]{4}\\.[0-9]{2}\\.[0-9]{2}"
# a range heading covers every version between its endpoints, and names only the two: v2026.08.05
# lives inside `# v2026.08.04 – v2026.08.06` and is written nowhere. So `known` — the release
# folder's own versions.json — fills the middle in, and every version in the span is anchored.
# String order is date order on `vYYYY.MM.DD`.
heading_versions <- function(x, known = character()) {
  x <- gsub("<[^>]+>", "", x)
  if (!grepl(paste0("^", VER_RX), x)) return(character())
  v <- regmatches(x, gregexpr(VER_RX, x))[[1]]
  if (length(v) < 2 || !length(known)) return(v)
  c(v, sort(setdiff(known[known >= min(v) & known <= max(v)], v)))
}
# versions.json beside the object being rendered, read once per folder. Only the release prefix
# has one; `known` is passed unevaluated, so a folder without one is never asked (R forces the
# promise at the first range heading, and a `{v}/RELEASE_NOTES.md` has none).
VERSIONS_CACHE <- list()
release_versions <- function(uri) {
  folder <- paste0(dirname(uri), "/")
  if (!is.null(VERSIONS_CACHE[[folder]])) return(VERSIONS_CACHE[[folder]])
  txt <- suppressWarnings(system2(calcofi4db:::find_gcloud(),
                                  c("storage", "cat", shQuote(paste0(folder, "versions.json"))),
                                  stdout = TRUE, stderr = FALSE))
  v <- character()
  if (length(txt))
    v <- tryCatch(as.character(jsonlite::fromJSON(paste(txt, collapse = "\n"))$versions$version),
                  error = function(e) character())
  if (!length(v))
    cat("note: no readable versions.json at", folder, "— a range heading anchors only the versions it names\n")
  VERSIONS_CACHE[[folder]] <<- v
  v
}
add_toc <- function(html, known = character()) {
  m <- gregexpr("<h([1-3])>(.*?)</h[1-3]>", html, perl = TRUE)
  hits <- regmatches(html, m)[[1]]
  if (length(hits) < 3) return(list(body = html, nav = ""))
  seen <- character(); vseen <- character(); items <- character(); out <- html
  for (h in hits) {
    lvl <- as.integer(sub("^<h([1-3])>.*", "\\1", h))
    txt <- sub("^<h[1-3]>(.*)</h[1-3]>$", "\\1", h)
    id  <- slug(txt); if (!nzchar(id)) id <- "section"
    n <- sum(seen == id); seen <- c(seen, id); if (n) id <- paste0(id, "-", n + 1)
    vs  <- heading_versions(txt, known)
    if (length(vs) && vs[1] %in% vseen) vs <- character()  # a version anchors one heading
    vs  <- unique(vs[!vs %in% vseen]); vseen <- c(vseen, vs)
    # a version heading: the first version is the id, the slug and every other
    # version in its span ride along as empty anchors
    if (length(vs)) {
      txt <- paste0(paste(sprintf('<a id="%s"></a>', c(id, vs[-1])), collapse = ""), txt)
      id  <- vs[1]
    }
    out <- sub(h, sprintf('<h%d id="%s">%s</h%d>', lvl, id, txt, lvl), out, fixed = TRUE)
    items <- c(items, sprintf('<li class="l%d"><a href="#%s">%s</a></li>', lvl, id, gsub("<[^>]+>", "", txt)))
  }
  nav <- paste0('<nav class="toc" aria-label="Contents"><details><summary>Contents · ',
                length(items), '</summary><ol>', paste(items, collapse = ""), '</ol></details></nav>')
  list(body = out, nav = nav)
}
TOC_CSS <- '<style>
.mdwrap{display:grid;grid-template-columns:minmax(0,1fr);gap:0 2.5rem}
@media(min-width:960px){.mdwrap{grid-template-columns:17rem minmax(0,1fr)}.toc{position:sticky;top:1rem;align-self:start;max-height:calc(100vh - 2rem);overflow:auto}}
.toc{font-size:.85rem;line-height:1.35;margin:0 0 1.2rem}
.toc summary{cursor:pointer;font-weight:600;font-size:.8rem;text-transform:uppercase;letter-spacing:.06em;color:var(--muted);margin-bottom:.4rem}
.toc ol{list-style:none;margin:0;padding:0;border-left:2px solid var(--border)}
.toc li{margin:0}.toc li a{display:block;padding:.15rem .6rem;color:var(--fg);border-left:2px solid transparent;margin-left:-2px}
.toc li.l2 a{padding-left:1.2rem;color:var(--muted)}.toc li.l3 a{padding-left:1.9rem;color:var(--muted);font-size:.8rem}
.toc li a:hover{color:var(--accent);text-decoration:none}.toc li a.is-active{color:var(--accent);border-left-color:var(--accent)}
.md h1,.md h2,.md h3{scroll-margin-top:1rem}
</style>'
TOC_JS <- '<script>(function(){var links=[].slice.call(document.querySelectorAll(".toc ol a"));if(!links.length)return;
var heads=links.map(function(a){return document.getElementById(decodeURIComponent(a.getAttribute("href").slice(1)))});
var on=null;function mark(i){if(on===i)return;links.forEach(function(a){a.classList.remove("is-active")});if(i>=0){links[i].classList.add("is-active");on=i;
var el=links[i];var box=el.closest(".toc");if(box&&box.getBoundingClientRect().height<box.scrollHeight){var r=el.getBoundingClientRect(),b=box.getBoundingClientRect();if(r.top<b.top||r.bottom>b.bottom)el.scrollIntoView({block:"center"})}}}
function spy(){var y=window.scrollY+24,best=-1;for(var i=0;i<heads.length;i++){if(heads[i]&&heads[i].offsetTop<=y)best=i}mark(best)}
window.addEventListener("scroll",spy,{passive:true});window.addEventListener("resize",spy);spy();
var d=document.querySelector(".toc details");if(d&&window.innerWidth>=960)d.open=true})();</script>'

# the page: the markdown body in the index skin, the raw source one link away
render_one <- function(uri) {
  p <- calcofi4db:::parse_gcs_path(uri)
  https <- glue("https://storage.calcofi.io/{p$bucket}/{p$path}")
  local_md <- tempfile(fileext = ".md")
  system2(calcofi4db:::find_gcloud(), c("storage", "cp", shQuote(uri), shQuote(local_md)), stdout = FALSE, stderr = FALSE)
  if (!file.exists(local_md)) stop("could not fetch ", uri)
  md   <- readLines(local_md, warn = FALSE, encoding = "UTF-8")
  title <- sub("^#\\s+", "", grep("^#\\s+", md, value = TRUE)[1])
  if (is.na(title) || !nzchar(title)) title <- basename(p$path) else
    md <- md[-grep("^#\\s+", md)[1]]   # the page's h1 is the document's first heading; not twice
  body <- commonmark::markdown_html(paste(md, collapse = "\n"), extensions = TRUE, smart = FALSE)
  folder <- dirname(p$path)
  # ids on every h1–h3, and the nested list beside the page; the folder's versions.json, where
  # there is one, tells a range heading which versions it spans
  toc  <- add_toc(body, release_versions(uri))
  body <- toc$body
  crumb  <- glue('<p class="crumb"><a href="https://storage.calcofi.io/{p$bucket}/{folder}/">{esc(folder)}</a> / ',
                 '{esc(basename(p$path))} · <a href="{https}">raw markdown ↗</a></p>')
  html <- page(title, glue("{basename(p$path)} on gs://{p$bucket}/{folder}"),
               paste0(glue('<div class="mdwrap">{toc$nav}<article class="md">{body}</article></div>'),
                    TOC_CSS, TOC_JS,   # braces in CSS/JS: never through glue()
                    glue('<style>.md{{max-width:72ch;font-size:1rem}} .md h1{{font-size:1.4rem;margin:1.6rem 0 .4rem}} ',
                    '.md h2{{font-size:1.15rem;margin:1.4rem 0 .3rem}} .md h3{{font-size:1rem;margin:1.1rem 0 .2rem}} ',
                    '.md code{{font:.9em var(--mono);background:var(--panel);padding:.05em .3em;border-radius:4px}} ',
                    '.md pre{{background:var(--panel);padding:.8rem 1rem;border-radius:8px;overflow-x:auto}} .md pre code{{background:none;padding:0}} ',
                    '.md table{{font-size:.9rem;margin:.6rem 0}} .md th,.md td{{white-space:normal}} ',
                    '.md ul,.md ol{{padding-left:1.4em}} .md li{{margin:.15em 0}} .md blockquote{{margin:.8rem 0;padding:.2rem 1rem;border-left:3px solid var(--border);color:var(--muted)}}</style>')),
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
