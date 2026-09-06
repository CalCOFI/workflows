# UI-F · Keep it true — `check_layout.py` in CI, shots of the catalog pages, Lighthouse, README

**Agent:** Sonnet 5 · high. **Wave 3**, `CalCOFI.github.io` worktree (branch `ui-keep-true`), from main **after UI-A
and UI-B are merged and deployed**. **Plan:** `.claude/plans/2026-09-05 CalCOFI.io UI refresh — emphasis, density and the dataset page, now that the catalog is live.md` § D-10, Phase F, § Verification.

## Goal

The two measured problems (tile stretch, the blank column) and the round-2 rules (URLs one line at 375 px, one
ERDDAP listing, no `--warn` on a holding) are regression checks that run weekly and on every pull request; the
catalog pages have themed screenshots like every product card; the README says how.

## Read first

`scripts/check_layout.py` (UI-A + UI-B), `scripts/check_brand.py`, `scripts/shots.py` + `_data/shots.yml`,
`.github/workflows/{pages,refresh,check-brand}.yml`, `README.md`, the plan's § Verification.

## Do

1. `check-brand.yml`: a step that builds the site (`scripts/fetch_release.sh` + `jekyll build`), serves `_site` on a
   local port and runs `check_layout.py` against `/datasets/`, `/datasets/calcofi_ctd-cast/`, `/datasets/swfsc_ichthyo/`,
   `/datasets/calcofi_prodo/` at 1470 and 375 px, both themes; red on any assertion.
2. `pr.yml` (new): on `pull_request` — fetch, build, `check_jsonld.py _site`, `check_layout.py` (same list), no deploy.
3. `shots.py` recipes for `/datasets/` and the two dataset pages (light + dark, `images/datasets_*.png`), and the
   luminance check; the landing page's themed card for the catalog if one is wanted (ask — do not invent a card).
4. Lighthouse: a documented local command (`npx lighthouse` or the Chrome panel) with the a11y ≥ 100 expectation;
   in CI only if it runs under two minutes.
5. README: the layout check, the PR workflow, how to add an assertion; the plan's Measured line.

## Gates

Both workflows green on a test PR; `check_layout.py` fails when you deliberately reintroduce `align-items: normal`
on the grid (prove the assertion bites, then revert).

## Do not

Change any page, style or plugin behaviour; loosen an assertion to make it pass.

## Hand back

The workflow run URLs, the shots, one *Measured* line.
