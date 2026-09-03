---
name: brand-contract
description: "CalCOFI brand contract (calcofi.io/brand/v1) — the ?theme= cookie chain, .cc-header rules, favicon set, ?tour=off screenshots, the new-product checklist and the framework traps. Load before touching any product's theme, header, favicon, screenshots or products.yml card."
---

# The brand contract (theme, header, favicon) — calcofi.io/brand/v1/

Every CalCOFI product wears one theme, one header and one favicon, and the rule is
**checked weekly, not assumed** (`CalCOFI.github.io/scripts/check_brand.py`). Source:
`CalCOFI.github.io/brand/v1/` (README there is the contract); plan:
`.claude/plans/2026-08-25 Consistent dark-light theme …`. In one breath:

- `?theme=dark|light` on any URL → `cc_theme` cookie on `.calcofi.io` → `localStorage.theme`
  → **dark**. `theme.js` sets `data-theme` / `data-bs-theme` / `data-md-color-scheme` on
  `<html>` and fires `cc:theme`; maps, Plotly and Mermaid restyle on it. Never key on
  `prefers-color-scheme`.
- `.cc-header`: logo far left → `https://calcofi.io`; the product's title beside it → its own
  root (that is how the two links stay distinguishable); the theme toggle at the right — a sun while
  the page is dark, a moon-in-sun while it is light, i.e. what a click switches *to* (MDI `brightness-7`/`-4`,
  calcofi4py's pair; fleet-wide since 2026-08-29, replacing 🌓 — `theme.js` draws it over the snippet's `🌓`
  fallback, `theme.css` exports the masks as `--cc-icon-sun`/`--cc-icon-moon`, and docs' `brand-head.html` /
  the packages' `_pkgdown.yml` dress the framework toggles with them; the Shiny apps' bslib switch is not yet
  switched). Where a
  framework owns the bar (Quarto, pkgdown, mkdocs, bslib `page_navbar`) the logo goes in its
  brand slot and its native toggle is bridged — never two bars, never two toggles.
- The CalCOFI favicon set, except `calcofi4r` (hex) and `calcofi4py` (squircle).
- `?tour=off` suppresses any guided tour, so `live_url?theme=<t>&tour=off` is a deterministic
  screenshot; each card on calcofi.io has `images/<key>_dark.png` + `_light.png`
  (`scripts/shots.py`, luminance-checked) once `shots: themed` is set in `products.yml`.

**New product checklist** (extends the three-slug contract in `products.yml` / uptime /
analytics): brand head + header + favicon · honours `?theme=` · `?tour=off` · two screenshots
· `shots: themed`. Shiny: `calcofi4r::cc_brand_head()` / `cc_brand_header(mode =
cc_theme(request))` / `cc_is_dark(input)` / `cc_tour_enabled()`. Quarto here: every render
includes `libs/brand/quarto_head.html` + `quarto_header.html` via `_quarto.yml`;
`scripts/brand_inject_html.R` (run by the Pages workflow) injects the same into notebooks
rendered before 2026-08-25, because re-rendering an ingest for a stylesheet is a pipeline run.

Two traps met on the way: pkgdown 2.2 has **no `html:` navbar component** (use a `link` with
`icon:` + `class:` and draw it in CSS); Quarto's `book.favicon` with a URL renders
`href="./https://…"` (download the png).

> Moved out of the root `CLAUDE.md` on 2026-09-03 so it loads on demand; the hard rules stay resident there. Edit this file, not both.
