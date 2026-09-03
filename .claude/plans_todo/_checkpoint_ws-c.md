# WS-C checkpoint (laptop going offline)

Branch: `ws-c` (this worktree, was fast-forwarded to `5bb45ca` per coordinator instruction,
then renamed from `worktree-agent-a3815ae6514c321e9` → `ws-c`).

## Done

Read: `.claude/agents/ws-sonnet-high.md`, the WS-C brief
(`.claude/plans_todo/2026-09-03 WS-C Dungeness crab — examined samples only, UCSD Library deposit
placeholder.md`), umbrella plan §§ *Context — Crab* and *Decisions — WS-C* (in
`.claude/plans/2026-09-03 Pre-release round …md`), `project_cdfw_dungeness_crab` memory (stale,
pre-release), `metadata/cdfw/dungeness-crab/questions.csv`, `metadata/dataset_status.csv` crab row,
and the full `ingest_cdfw_dungeness-crab.qmd` (YAML, Build Sorting Log, Emit Core Tables incl.
core-parity stopifnot, Schema, Validate incl. the `nullable` tribble + its stopifnot, Preview,
Write Outputs).

Edits made to `ingest_cdfw_dungeness-crab.qmd` (uncommitted, in working tree — **not yet
committed**):
1. YAML `dataset_meta.description` — rewritten to say 216 archived sorting-log samples were
   *examined and found free of M. magister* (1984–2009), and that only examined samples publish.
2. YAML `link_data_source` — set to the placeholder
   `https://library.ucsd.edu/dc/search?q=CalCOFI+Dungeness+crab+megalopae` with the
   `# placeholder until the UCSD Library RDC deposit (2026-08-27) is minted — see Q14` comment,
   per Q6.
3. YAML `tables_owned` notes for `sample`/`obs` updated to say 526 events (310 subsamples + 216
   examined tows; 1,795 unsorted rows not published).
4. "Emit Core Tables" prose paragraph rewritten: unsorted rows are dropped from the core entirely
   (not "sample row, no obs" as before); `dungeness_sorting_log` still keeps all 2,011 rows as the
   notebook's working table.
5. Arm 1b's `append_sample()` SQL: added `WHERE sorting_status = 'sorted'` so only examined tows
   enter `sample`. Arm 2b (`obs` absences) already had this filter — unchanged, and its declared
   null counts (`obs.grid_key`=30, `obs.cruise_key`=87, `obs.hex_id`=16 in the Validate section)
   were **already scoped to sorted rows only**, so they should NOT need to change.
6. `core-parity` chunk: `n_tow` stopifnot changed from `== nrow(d_sorting)` (2,011) to
   `== n_log_sorted` (`sum(d_sorting$sorting_status == "sorted")`, expected 216); added an explicit
   `(n_sub + n_tow) == 526` assertion; added a new assertion that unsorted log rows never appear in
   `sample` at all (in addition to the existing "no obs" assertion, kept as-is).

## Next step (not started / not verified)

- **NOT YET EDITED**: the "Validate" section's `nullable` tribble (~line ~1009 pre-edit,
  label `validate`). Four rows need new counts because `sample` now only contains the 216
  *sorted* log tows instead of all 2,011:
  - `sample.parent_sample_key` NULL count: was `2015L` (2011 tow roots + 4 unmatched subsamples) →
    should become `216 + 4 = 220L` (arithmetically certain, not yet applied).
  - `sample.site_key` NULL count: was `77L` ("inherited from the sorting log", i.e. all 77
    no-line/station log rows) → **unknown**, need the count of those 77 that fall within the
    216 *sorted* subset. NOT computed.
  - `sample.cruise_key` NULL count: was `1639L` → **unknown**, need count of sorted-subset rows
    with no resolvable cruise_key. NOT computed.
  - `sample.grid_key` NULL count: was `81L` (4 unmatched subsamples + 77 out-of-grid log tows) →
    **unknown**, need count of sorted-subset rows with no grid_key, +4. NOT computed.
  - `dungeness_sorting_log.*` rows (cruise_key 1639 / site_key 77 / grid_key 77) are UNCHANGED —
    that working table still holds all 2,011 rows per the brief, so those three declared counts
    stay as-is.
  - `obs.*` rows (grid_key 30 / cruise_key 87 / hex_id 16) — reasoned to be unchanged (arm 2b was
    already scoped to sorted rows before this change) but **not verified by an actual run**.

  These four `sample.*` counts feed a hard `stopifnot()` (`unexplained == 0`, `moved == 0`), so
  guessing wrong fails the render loudly — which is actually fine/self-correcting (the code prints
  `moved`/`unexplained` before erroring), but I have not yet run it to get real numbers.

- Also not yet touched, per the brief, still to do:
  - The `1984-05-17 → 2009-04-19` / coverage bbox comment near YAML line ~59 ("measured extent runs
    to 164.1°W…") — check whether it's still accurate once unsorted rows drop out; may be unaffected
    (it's about longitude, not date range) but not verified.
  - `metadata/cdfw/dungeness-crab/questions.csv`: add **Q14** (open, normal, who = Betty Huang /
    UCSD Library RDC — "DOI and object URL for the deposit?", `proposed_answer` = on mint add
    `doi:`, cite the DOI in `citation_main` with the deposit year, point `link_data_source` at
    `dc/object/<ark>`). Also update **Q08**'s `context` per the brief: "the deposit README says the
    sign was corrected; reconcile (negate, close Q08) once the zips are in Drive
    `cdfw/dungeness-crab/deposit/` — Ben downloads them before 2026-09-26; do not block on it." NOT
    STARTED.
  - `metadata/dataset_status.csv` crab row: `blockers` column still says "HELD OUT OF RELEASE
    (in_release: false)…" — stale since 2026-08-14 (dataset entered the release then). Rewrite to
    current state (526 events, examined-only, Library deposit pending DOI). NOT STARTED. (`stage`
    column is already `ingested`, consistent with other in-release datasets — leave that alone
    unless the render proves otherwise.)
  - `RELEASES.md` `# Unreleased`: append a new `##` heading (after the existing three: "One
    climatology…", "`coverage.json` carries taxa…", "The release now cuts browser-shaped
    objects…" — do NOT touch those, they belong to other workstreams) — "The Dungeness crab
    dataset is the examined samples" — 2,321 → 526 events, `coverage_temporal_observed` 1949 →
    1984 start (measured 1984-05 → 2014-05 per umbrella), the Library deposit + pending DOI. NOT
    STARTED.
  - Memory file `project_cdfw_dungeness_crab.md` update — NOT STARTED (per rules of engagement,
    hand back a "Measured" line; the memory file itself may be for the user's own memory system,
    not something I write directly — re-check whether the brief means literally editing
    `~/.claude/projects/…/memory/project_cdfw_dungeness_crab.md`, which is OUTSIDE the repo/worktree
    and may not be something this sandboxed agent can/should touch directly. Flag this to the
    integrator rather than assume.)
  - `quarto render ingest_cdfw_dungeness-crab.qmd` — NOT RUN YET. Confirmed a blocker first:
    **`devtools::load_all(here::here("../calcofi4db"))` in the Setup chunk fails in this worktree**
    because `here::here()` roots at the worktree dir
    (`.claude/worktrees/agent-a3815ae6514c321e9`), so `../calcofi4db` resolves to
    `.claude/worktrees/calcofi4db`, which does not exist — the real sibling repos live at
    `/Users/bbest/Github/CalCOFI/calcofi4db` and `/Users/bbest/Github/CalCOFI/workflows/calcofi4db`
    (the latter exists in the MAIN workflows checkout, not in this nested worktree). The brief says
    "the installed calcofi4db 3.28.0 is fine" for the render, which implies `devtools::load_all()`
    on the sibling source is NOT actually required/expected to succeed here, but the notebook's
    Setup chunk calls it unconditionally — I have not yet resolved this (candidates: symlink
    `calcofi4db`/`calcofi4r` into this worktree pointing at
    `/Users/bbest/Github/CalCOFI/calcofi4db` and `/Users/bbest/Github/CalCOFI/calcofi4r`, or find
    out whether other WS agents hit and solved this already — worth asking the coordinator before
    spending more time). Tried purl-and-Rscript as a faster iteration path (rather than full
    `quarto render`) to get exact counts for the `nullable` tribble — blocked on the same
    `load_all()` issue.

## Open questions for the coordinator / next resumption

1. **How should sibling-repo relative paths (`../calcofi4db`, `../calcofi4r`) resolve from a
   nested worktree at `.claude/worktrees/agent-*`?** Is there a standard symlink/env-var setup
   other WS agents used, or should I create
   `ln -s /Users/bbest/Github/CalCOFI/calcofi4db calcofi4db` etc. at the worktree root myself
   (note: NOT `../calcofi4db` from inside the worktree, since `here()` roots at the worktree
   itself, one level higher than a plain relative path would suggest — needs re-verification)?
2. Is editing `~/.claude/projects/-Users-bbest-Github-CalCOFI-workflows/memory/project_cdfw_dungeness_crab.md`
   (the user's cross-session memory file, outside git) actually in scope for this agent, or is
   "update the memory file" something only the coordinator/user does after reading my report?

## Files touched so far (uncommitted at checkpoint time — committed in the checkpoint commit)

- `ingest_cdfw_dungeness-crab.qmd` (partial — see "Done" above; core-parity and arm-1b/YAML edits
  in; nullable-tribble, questions.csv, dataset_status.csv, RELEASES.md all still pending)
