# Integrator notes — the UI refresh, 2026-09-05 (coordinator session; not an agent brief)

Umbrella: `.claude/plans/2026-09-05 CalCOFI.io UI refresh — emphasis, density and the dataset page, now that the
catalog is live.md` (Decisions 1–20 confirmed by Ben 2026-09-05; § Workstreams). Artifact (the spec, round 3):
https://claude.ai/code/artifact/b06dcb2e-f899-4c00-831e-7383a5f4e87e. Briefs: `2026-09-05 UI-{C,D,E,A,B,F}.md` here.

## Models and effort (why)

| WS | model · effort | why this and not more |
|---|---|---|
| UI-C brand additive | Opus 5 · medium | small, but it is the contract every product consumes; the gate is mechanical (zero deleted lines, the contrast table) |
| UI-D the record | Opus 5 · high | the one place a wrong value silently mislabels data (identifiers, bbox) — specified to the column and gated by tests; Fable only if the bbox rule needs design |
| UI-E links back | Sonnet 5 · high | three small parameter features in apps with their own tests |
| UI-A the grid | Opus 5 · high | layout judgment in two themes against a mockup, with `check_layout.py` as the validator |
| UI-B the dataset page | Opus 5 · high | the largest brief; geometry (a port of the prototype), the Access model, tests for the id parser — still spec + validator, not a contract to invent |
| UI-F keep it true | Sonnet 5 · high | CI wiring |
| integrator (this) | Opus 5 · medium is enough; Fable if continuity of judgment matters | merges, renders, runs the gates, appends Measured lines |

The single-session alternative: one Opus 5 · high session in `CalCOFI.github.io` doing C → A → B → F in order
(no merges; ≈ 4 days wall) plus D and E as two sessions. Recommended: the waves (≈ 1½ days wall).

## Waves and merge order

- **Wave 1** (parallel, own worktrees, three repos): UI-C (`CalCOFI.github.io` `brand-v2-additions` + `explore`
  `icons-ui`), UI-D (`calcofi4db` `catalog-4.5.0` + `workflows` `catalog-record-4.5`), UI-E (`db-query`,
  `db-viz-station`, `db-viz-hex`). Merge C first (A and B branch from it). D merges to calcofi4db main and is
  **installed** by the integrator; it renders with the next release — the site keeps its fallbacks until then.
  E merges per repo; the two `products.yml` template lines go in with B's merge.
- **Wave 2** (after C merged and pushed): UI-A (`ui-grid`) and UI-B (`ui-page`), two worktrees of the landing repo.
  Merge **A first**, then rebase B onto main: `style.css` (A appends the grid rules, B the page rules — different
  sections), `_plugins/datasets.rb` (A: tile/band methods + `normalize_variables`; B: `map_svg`, `access_groups`,
  `record_pages` — B drops its local normaliser copy for A's), `scripts/check_layout.py` (A's grid assertions +
  B's page assertions — concatenate). Then `scripts/build.sh serve`, `check_layout.py` on the four URLs at both
  widths and themes, `check_brand.py --url`, `check_jsonld.py _site`, Lighthouse; push main → Pages deploys.
- **Wave 3**: UI-F after the deploy. UI-G later, after D renders.

## Mechanics (carried from 2026-09-03 and 09-05; still true)

- Push first, then spawn: worktree isolation branches from the last **pushed** commit. Worktrees live under
  `/Users/bbest/Github/CalCOFI/.worktrees/`.
- `.claude/worktrees/calcofi4db` and `calcofi4r` are symlinks to the sibling checkouts, so a render in ANY
  worktree loads the sibling's *checked-out* branch — **an agent that changes calcofi4db must not render**; the
  integrator renders staging after merging with the sibling checkout on the merged branch.
- The landing repo build in a worktree needs `bundle install` and `scripts/fetch_release.sh` (network to GCS;
  `_data/{datasets,versions}.json`, `grid.geojson`, and after UI-B `coverage_stations.json` are git-ignored). The
  site renders the **staging** record v2026.09.05 through the `DATASETS_RELEASE_URL` fallback until the next
  production release writes `datasets.json`; a worktree build does the same.
- `shot-scraper` + Chrome for `check_brand.py` / `check_layout.py` (`pipx install shot-scraper && shot-scraper install`).
- Every WS: README (landing repo) or NEWS.md (calcofi4db) in the same commit; `tar_invalidate()` any `.qmd` it
  edits that must run; hand back one *Measured* line for the umbrella. Fable 529s: wait and retry, do not switch
  model. A message to a completed agent resumes it.
- Nothing in any brief types a dataset fact; the two marked fallbacks (grain glossary, portal one-liners) carry
  `# until the record carries …` and are deleted when D's release renders.

## Checkpoints (agent → branch @ sha → next step)

- 2026-09-05 evening · plan decided, briefs written, nothing spawned. **Ben chose the single Opus 5 · high session**
  (C → A → B → F in `CalCOFI.github.io` on `ui-refresh`, merged and pushed per phase; then E, then D) — the kickoff
  prompt is in the plan; these notes stay the mechanics reference. **Next:** that session.
- 2026-09-05 · **UI-C done** — `CalCOFI.github.io` main **f848c44** (branch `ui-refresh` → merged, pushed;
  Pages deploying) and `explore` main **5e1fc3e** (branch `icons-ui`). `theme.css` deletions **0**; specimen
  contrast 58 pairs / min 4.56 : 1 / 0 below AA; sprite 51 glyphs; Lighthouse a11y 100 both themes (95 before —
  two pre-existing specimen faults fixed: unnamed card-shot links, no `<main>`). `check_brand.py --url` and
  `check_jsonld.py _site` green. **Next:** UI-A on `ui-refresh` off the merged main.
- 2026-09-05 · **UI-A done** — `CalCOFI.github.io` main **887b6e4** (merged, pushed; Pages deploying).
  Grid 4,910 → **2,096 px**, worst stretch 1.00×, holdings `--muted` with no `--warn`, reference band
  939 px, one column at 375. `check_layout.py` new and proven to bite (6 failures with
  `align-items: normal` back). Lighthouse 100 on `/` and `/datasets/`, both themes.
  **Next:** UI-B — and Ben (mid-session) named two of its items on the live page: the ~928 px of blank
  above Access, and no STAC link. The record carries **no `stac` distribution** (measured: 0 of 20
  distribution kinds), while `gs://calcofi-db/stac/collections/{key}/collection.json` answers 200 —
  so UI-B renders it as a marked site-side fallback and UI-D adds the field.
- 2026-09-05 · **UI-B done** — `CalCOFI.github.io` main **812bf05** (merged, pushed; Pages deploying).
  Hero columns 399/399 (gap 0); maps 13.3 / 33.0 / 10.4 KB inline, `land.geojson` 18.3 KB committed;
  38/38 URL tails whole at 375; every ERDDAP id once; `derive_id` 29 assertions; Lighthouse 100 on
  three pages × two themes; `check_layout.py` green on 12 combinations. Two finds: the build-time
  `unlisted_endpoints` guard caught two legacy ERDDAP ids with no `format` key that had vanished from
  the CTD page, and `#layout`'s max-content grid column let one nowrap URL widen the whole page to
  758 px at 375. `products.yml` carries `dataset_url` for **explore** and **db-viz-cruise** only —
  the Station and Hexagon lines land with UI-E, when those apps can honour them.
  **Next:** UI-F (CI), then UI-E, then UI-D.
- 2026-09-05 · **UI-F done** — `CalCOFI.github.io` main **13db153** (merged, pushed). `pr.yml` new;
  `check-brand.yml` gained a `layout` job; both assertion families proved to bite; six catalog page
  shots captured and luminance-checked; Lighthouse documented, not in CI (106 s measured).
  **Next:** UI-E (`db-query`, `db-viz-station`, `db-viz-hex`, then the two `products.yml` lines),
  then UI-D (`calcofi4db` 4.5.0 + `workflows`).
- 2026-09-05 · **UI-E done** — `db-query` **463f82d**, `db-viz-station` **89786ce**, `db-viz-hex`
  **9b12cf9**, `CalCOFI.github.io` **01da915** (the two `products.yml` lines went in AFTER the apps
  could honour them, not with UI-B). 4 of 6 Explore rows now say *this dataset*. db-query and
  db-viz-station verified in a browser; **db-viz-hex was not run** — the local DuckDB is v2026.08.02
  and `global.R` fails on main too, so the rule is a pure tested function and the app check waits for
  the next deploy (`deploy-consumers` skill; this session does not deploy).
  **Next:** UI-D (`calcofi4db` 4.5.0 / schema 1.1 + `workflows`); merge and install, no render, no release.
- 2026-09-05 · **UI-D done** — `calcofi4db` main **93ee0228** (4.5.0, **installed**: `packageVersion()`
  4.5.0, both new functions exported, the installed schema reads `const: "1.1"`), `workflows` main
  **743f25e**. 2,643 tests pass. `distribution.csv` needed no edit (31/31 ids already curated and all
  agreeing with the derived rule). Q16 filed. Nothing rendered, no release.
- 2026-09-05 · **Ben's live review** — two rounds, both shipped: `de04dcb` (the filter had never hidden
  anything; `[hidden]` lost to `display:flex`) and `0298b3f` (the map box was the cell, not the map).
  **ALL SIX PHASES DONE.** What is left is not this session's: the next release renders schema 1.1 and
  the site deletes its five marked fallbacks; `db-viz-hex` needs a deploy before its `?datasets=` can be
  checked in a running app (the local DuckDB is v2026.08.02 and `global.R` fails on main too); UI-G (the
  list view, the season strip from `coverage.months`) was always "later".
