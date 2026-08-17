# Clean up & restructure the `calcofi.io/workflows/` landing page

## Context

`https://calcofi.io/workflows/` is a Jekyll site that GitHub Actions
(`.github/workflows/jekyll-gh-pages.yml`) builds from the `_output/` directory and
deploys to Pages. The current landing page is `_output/README.md` — a single Liquid
loop that lists **every** `*.html` in `_output/` alphabetically, with no theme and no
prioritization. The result mixes 14 official, metadata-bearing workflows in with ~25
exploratory/legacy notebooks and several stale renders (test pages, superseded ingests,
orphaned renders whose source no longer exists).

Goals:
1. **Prune** stale/superseded/test renders from the published site.
2. **Restructure** the landing page to prioritize ingest → publish → release, with
   exploratory/legacy notebooks kept but demoted to a low "Other" section.
3. **Restyle** to read as a sibling of `calcofi.io/schema` and `/query` (shared dark-default
   palette, sticky header w/ logo + theme toggle, cross-site footer).
4. Drive the page from the authoritative `calcofi:` YAML metadata already embedded in each
   notebook's front matter (the same blocks `release_database.qmd` consumes).

The `calcofi:` front-matter block (e.g. in `ingest_calcofi_bottle.qmd`) carries
`workflow_type` (ingest / publish / release / spatial), `provider`, `dataset`,
`dataset_meta` (dataset_name, description, coverage_temporal/spatial, links),
`workflow_url`, and `erd.color`. 14 of 49 sources have it; these are the "official" workflows
to prioritize. The schema site's `renderDatasets()` (`schema/app.js` ~L642) shows the card
field set to mirror for consistency.

## Part A — Prune published renders (`_output/`)

Delete these rendered HTML files **and their `_files/` asset dirs** (sources noted):

| Remove from `_output/` | Why | Source handling |
|---|---|---|
| `test_release.html` (+ `_files`) | `workflow_type: test` — CI gate, not a public page | keep `test_release.qmd` (functional) |
| `ingest_coastwatch.pfeg.noaa.gov_erdCalCOFIlrvsiz.html` (+ `_files`) | superseded by `ingest_swfsc_ichthyo` | move `…erdCalCOFIlrvsiz.qmd` → `old/` |
| `ingest_ships.html` (+ `_files`) | orphan render, no source; stale dup of `ingest_ices.dk_ship-ices` (same title/size) | none (no source) |
| `scrape_ctd.html` (+ `_files`) | orphan render, no source; superseded by `ingest_calcofi_ctd-cast` | none (no source) |

Everything else stays published (per your "keep legacy in a low Other section" choice).

## Part B — Generate the workflow manifest

New script **`scripts/build_workflows_index.R`** (run locally / pre-build; commits its output):
- Enumerate existing `_output/*.html`; for each, locate the `*.qmd`/`*.Rmd` source and read its
  front matter with `rmarkdown::yaml_front_matter()` (already proven to surface the nested
  `calcofi:` block; avoids coupling to calcofi4db non-exported helpers).
- Emit **`_output/_data/workflows.yml`** — one entry per published page with: `url`
  (`<base>.html`), `title`, `category`, `provider`, `dataset`, `dataset_name`, `description`,
  `coverage_temporal`, `color` (from `calcofi.erd.color`), `link_calcofi_org`,
  `link_data_source`, and a `priority` for stable ordering.
- **Categorization** (mirrors `release_database.qmd`'s use of `workflow_type`):
  - has `calcofi`: `workflow_type` ∈ {ingest, spatial} → **Ingest**; `publish` → **Publish**;
    `release` → **Release & pipeline**.
  - else by filename: `^publish_` → **Publish**; `^(release|update|sync|clean)_` or
    `load_views` → **Release & pipeline**; `README_PLAN` → **Reference & plans**; all else
    (`explore_*`, legacy `load_*`, `ingest_ices.dk_ship-ices`) → **Other notebooks**.
  - Within **Ingest**, subgroup by `provider` (calcofi, swfsc, pic, cce-lter) then title.

Re-run this script whenever notebooks are added/changed; note in the script header that it can
later be wired into the pipeline (e.g. a caboose chunk in `release_database.qmd`) or the GH
Action. (Optional, low-risk: add a minimal `calcofi: {workflow_type: publish}` block to
`publish_calcofi_to_erddap.qmd` so Publish is uniformly metadata-driven; categorization already
handles it by prefix if skipped.)

## Part C — Jekyll scaffolding in `_output/` (sibling styling)

Add, following the established pattern (Jekyll machinery lives in `_output/` alongside the
committed Quarto HTML; Quarto render leaves these untouched, as it already does `README.md`):

- **`_output/_config.yml`** — `title: CalCOFI Workflows`, `url: https://calcofi.io`,
  `baseurl: /workflows`, `markdown: kramdown`, `exclude: [README.md, LICENSE]`.
- **`_output/_layouts/default.html`** — adapted from `schema/_layouts/default.html`: pre-load
  theme script in `<head>`, sticky `app-header` (CalCOFI logo light/dark, `h1` title, spacer,
  `🌓` theme toggle), `{{ content }}`, and an `app-footer` linking
  schema · query · docs · calcofi4r · uptime · GitHub source. Inline ~10-line theme-toggle
  script (no app.js / mermaid / pan-zoom needed here).
- **`_output/style.css`** — copy the schema palette + `:root` tokens, header/footer, and add
  `.wf-section`, `.wf-grid`, `.wf-card` (color swatch via `border-left`/dot using
  `calcofi.erd.color`, provider badge, dataset_name, description, coverage), and a compact
  `.wf-list` for the low sections.
- **`_output/assets/`** — copy `favicon-16x16.png`, `favicon-32x32.png`, `favicon.ico`,
  `logo_calcofi.svg`, `logo_calcofi_light.svg` from `schema/assets/`.
- **`_output/index.html`** — `layout: default`; iterate `site.data.workflows` grouped by the
  category order **Ingest → Publish → Release & pipeline → Reference & plans → Other notebooks**.
  Ingest renders rich cards (swatch + provider badge + dataset_name + description + coverage +
  links to the notebook, CalCOFI.org page, and data source); Release/Reference/Other render as
  compact titled link lists. README_PLAN sits in **Reference & plans** with a short note that it
  may later be folded into `calcofi.io/docs/`.
- **`_output/README.md`** — trim to a plain repo pointer (kept out of the build via `exclude`);
  `index.html` becomes the served root.

## Files touched
- New: `scripts/build_workflows_index.R`, `_output/_config.yml`, `_output/_layouts/default.html`,
  `_output/style.css`, `_output/index.html`, `_output/_data/workflows.yml` (generated),
  `_output/assets/*` (copied).
- Edit: `_output/README.md` (trim), optionally `publish_calcofi_to_erddap.qmd` (add calcofi block).
- Delete: 4 renders + `_files/` dirs (Part A); move 1 superseded source to `old/`.

## Verification
1. `Rscript scripts/build_workflows_index.R` → inspect `_output/_data/workflows.yml` (correct
   categories, all 14 metadata workflows in Ingest/Publish/Release, no removed pages listed).
2. Build via the schema bundle (no local jekyll on PATH, but `bundle exec jekyll` 4.4.1 works there):
   `cd /Users/bbest/Github/CalCOFI/schema && bundle exec jekyll build --source ../workflows/_output --destination /tmp/wf_site`
   → confirm clean build, then open `/tmp/wf_site/index.html` (or `bundle exec jekyll serve`).
3. Visually check: ingest cards first (grouped by provider, color swatches), publish/release next,
   legacy collapsed into low "Other"; dark/light toggle works; logo + footer cross-links resolve
   under `/workflows/`; a few notebook links open the rendered HTML.
4. `git status` — verify the 4 deletions, new scaffolding, and generated `_data/workflows.yml`;
   confirm `data/erddap`/`data/cache` still ignored.

## Out of scope (noted for later)
- Wiring the generator into CI / the targets pipeline (left as a documented one-liner for now).
- Folding README_PLAN content into `calcofi.io/docs/` (your suggestion; tracked, not done here).
