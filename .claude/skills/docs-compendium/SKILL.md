---
name: docs-compendium
description: "The CalCOFI.io documentation book (../docs → calcofi.io/docs) as the authoritative compendium of the system — which chapter governs which area, how a change here must update its chapter in the same change, how the book is rendered (pre-render snapshot, diagrams, figure/table labels, references, docx/pdf checks, CI) and how it refreshes as a release consumer. Load before changing anything a chapter states, before editing ../docs, and when a session needs to learn how the system works."
---

# The docs book is the compendium — `../docs` → calcofi.io/docs

`CalCOFI/docs` is one Quarto book, five audience parts, the data management plan's five phases as
its spine (Ingest · Integrate · Publish · Visualize · Synthesize). It is **the authoritative,
human-readable description of the system**: what the database is, what its keys mean, what a
release contains, how a dataset is provided and ingested, what each product does, and what the
plan and the status are. `CLAUDE.md` and the skills in this directory are the *engineering rules*
for changing the system; the book is what the system *is*. When they disagree, the book is
wrong or stale — fix the book in the same change, never let it drift.

Kick off a session that needs to understand an area by reading its chapter (source in
`../docs/*.qmd`, rendered at `https://calcofi.io/docs/<chapter>.html`), then the skill that
holds the engineering rule, then the code.

## Which chapter governs what

| Area of change | Chapter(s) to read and update | Engineering skill |
|---|---|---|
| Any table, column, view or measurement type in the release; `obs`/`sample` family; climatology | `db.qmd`, `naming.qmd` | `core-model`, `metadata-registries` |
| A key (`*_key`, `*_id`), a PK/FK, a gate (`check_*()`), `integrity.json` | `keys.qmd`, `_gates.qmd` | `core-model`, `cruise-key`, `release-run` |
| Cutting, staging, promoting a release; `RELEASES.md`; content-addressed objects; DOI | `releases.qmd`, `cite.qmd` | `release-run`, `release-objects`, `attribution` |
| Reading the release from R / Python / DuckDB / a browser; match helpers; the API | `data-access.qmd`, `api.qmd` | `release-objects` |
| The Explorer (lenses, controls, URL params, tour) | `explore.qmd` | `brand-contract` (the app lives in `../explore`) |
| Providing a dataset; `dataset_meta.yml`; questions; the ingest loop; registries | `provide.qmd`, `metadata.qmd`, `ingest-loop.qmd` | `metadata-registries`, `explore-dataset` → `validate-ingest` |
| Portals (ERDDAP, OBIS, EDI, STAC, NCEI …), `distribution.csv`, `portal.csv`, publish policy | `portals.qmd` | `metadata-registries`, `publish-template` |
| A product, its card, brand, uptime, deploy | `products.qmd` | `brand-contract`, `deploy-consumers` |
| The CTD boundary (the team's files, flags, the PostgreSQL working store, `flag_accepted.parquet`) | `ctd-qaqc.qmd`, `server-access.qmd` | `pipeline-targets` |
| The system figure, hosts, repos, the 2022 → 2026 architecture | `architecture.qmd`, `diagrams/system.mmd` | — |
| The SoW / DMP tasks and their status | `dmp.qmd`, `status.qmd` | — |
| Terms | `glossary.qmd` | — |

The rule in `CLAUDE.md`: **a change that alters what a chapter states updates that chapter in the
same change** — the prose, the diagram source, the caption, the cross-reference — and the render
is checked. A rule the pipeline enforces is stated in the chapter with *how* it is enforced (the
function or check by name); a rule nobody enforces is stated as intent, not fact.

## Prose is authored, facts are generated

Never type a number, a column list, a count, a coverage, a status or a version into a chapter.
`libs/pre-render.R` runs on every render and is the ONE place the network is touched: it
snapshots under `data/` (committed) the promoted release's sidecars (`catalog.json`,
`integrity.json`, `metadata.json`, `relationships.json`, `datasets.json`, the `dataset` table,
the release notes), the registries in this repo's `metadata/`, and the product cards from
calcofi.io. Chapters read those files. To surface a new fact, add it to the snapshot in
`pre-render.R`, then read it in the chapter.

- `CALCOFI_DOCS_REFRESH=1` refetches a snapshot younger than an hour (CI always does).
- `CALCOFI_DOCS_OFFLINE=1` renders from the committed snapshot without fetching (use it when
  GCS or GitHub is unreachable; the CalCOFI VM is never needed to render).
- A fetch that fails stops the render on purpose: a book that says "the record is missing" must
  never be published because a bucket blinked.

## The book is a release consumer

The snapshot is of the *promoted* release, so after `latest.txt` moves the book shows the previous
version until it re-renders. `scripts/deploy_consumers.sh` (the `deploy-consumers` skill)
dispatches `render_book.yml` in `CalCOFI/docs` beside the other hosted consumers; the workflow
also runs on push, on `workflow_dispatch`, on a `repository_dispatch` of type `release-promoted`
and on a weekly schedule as a safety net. If the docs show a stale version after a release, run
the deploy script or `gh workflow run render_book.yml --ref main -R CalCOFI/docs`.

## Rendering and checking

```bash
cd ../docs
quarto render --to html          # pre-render snapshot (if > 1 h old) then the book
quarto preview                   # live reload while editing
libs/render_diagrams.sh          # after editing diagrams/*.mmd → diagrams/*.svg (npm install once)
libs/check_formats.sh            # docx + pdf, before pushing a chapter that adds/changes a table
Rscript libs/check_links.R       # what CI's link check does (ranged GET; 404/410/451 fail)
```

- **Diagrams are pre-rendered SVGs, committed.** Source `diagrams/*.mmd`, rendered by the
  mermaid-cli pinned in `package.json`; no browser runs during `quarto render` (headless Chrome
  hangs, the same reason `mermaid-format: png` stays off in this repo). Every `.cc-diagram`
  figure gets pan/zoom/fullscreen from `libs/diagram.js`; the PDF keeps the static image.
  Edit the `.mmd`, run the script, commit the `.svg` beside it.
- **Every figure and table is numbered, captioned and cross-referenced.** A figure is
  `![caption](path){#fig-name …}`; a markdown table carries `: caption {#tbl-name}` beneath it; a
  chunk table sets `#| label: tbl-name` and `#| tbl-cap:`. The prose refers to it with
  `@fig-name` / `@tbl-name` at least once. An unlabelled figure or table is a defect.
- **References are BibTeX.** `refs/*.bib` is listed under `bibliography:` in `_quarto.yml`;
  cite with `[@key]` / `@key` and let Quarto build the References appendix (`refs.qmd`). Never
  paste a bare citation into prose.
- **The Word export is fragile.** A `gt` markdown cell containing `&` breaks the docx build;
  links in a `gt` cell use `gt::fmt_url()`, never a `[name](url)` cell. HTML widgets
  (`DT::datatable`) do not render in pdf/docx, so a chunk that shows one branches on
  `knitr::is_html_output()`. `libs/check_formats.sh` catches both before CI does.
- **CI** (`.github/workflows/render_book.yml`): job 1 renders HTML, runs the link check and
  publishes `gh-pages` (one publish at a time; a newer push cancels the run in flight); job 2 is
  non-blocking and builds the PDF + DOCX into the rolling `documents` release the sidebar links.
- **Brand**: `brand-head.html` + `brand-light.scss` / `brand-dark.scss` implement the fleet
  contract (`brand-contract` skill); the feedback button beside Quarto's theme toggle loads
  calcofi.io's `assets/feedback.{css,js}` and files reports with `app: docs`.

## History

- 2026-09-08 — the revamp (plan `.claude/plans/2026-09-08 Docs revamp — …`): one book, five
  audience parts, "Start here" by audience, keys stated and measured (`integrity.json`), SVG
  diagrams with a pan/zoom viewer, Chrome out of CI. The same day: the CTD PostgreSQL working
  store left the system figure (the team has not adopted it) and got its own figure in
  `ctd-qaqc.qmd`; De Pooter et al. (2017) became a real reference; every figure and table was
  labelled; the book was registered as a release consumer; this skill and the `CLAUDE.md`
  block were written so later sessions treat the book as authoritative.
