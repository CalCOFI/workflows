# Content-addressed release — GO / NO-GO (for Ben)

Staging validation is done. Everything below the line is **for you to authorize** — each item
either mutates the production bucket, the production server, or deletes data, so I did not run it
autonomously while you were away. The plan is `.claude/plans/2026-08-25 Database changelog …`.

## What is validated (staging prefix `ducklake-staging/`, no prod impact)

| check | result |
|---|---|
| T6 — `release_database.qmd` renders on the staging prefix, both layouts | ✅ compat rc=0, canonical rc=0 |
| **sample dedup** (the v2026.08.25 bug) | ✅ `total_rows` 320,260,205 = 4,855 fewer than live; `check_core_pk_unique()` gate passes |
| compat catalog | ✅ 18 tables, writer pinned, `obs` = 15 partitions + 1 single-file twin |
| T3 — every compat object exists, size + sha256 match catalog | ✅ 214 objects, 211 hashed, 0 problems |
| canonical catalog | ✅ `layout: canonical`, 214 objects all under `tables/{table}/{hash}/`, per-object `compat_path`, 0 problems |
| canonical `tables/{hash}/` store + compat copies on GCS | ✅ both return 206 (object, compat copy, obs twin) |
| redirect map from the canonical catalog | ✅ 214 entries, legacy path → canonical object (`build_release_redirects.R`) |
| T3 — canonical objects + compat copies | ⏳ running (`t3_canon.log`) |
| resolvers (calcofi4r 1.11.0, calcofi4py 0.4.0) against both catalog shapes | ✅ shared fixtures, unit tests green |

**Not yet exercised** (needs a prod change): T4 — the `storage.calcofi.io` 404→302 redirect. There is
no staging Caddy, so proving the redirect requires deploying the rule to the production server.

## Pushed already (safe: backward-compatible with the live legacy release)

- calcofi4r `main` (1.11.0 + the pkgdown/match.R fix), docs `main` (catalog contract),
  CalCOFI.github.io (calcofi4r card themed), and — via workflows-72's rename push — apps &
  db-viz-hex catalog migrations. All resolve the current legacy release identically to before.

## Held back, unpushed (the release engine + remaining consumers)

- calcofi4db 3.22.0 → **3.23.3**, the workflows release notebook / test_release / scripts,
  calcofi4py 0.4.0, db-query, db-viz-station, ctd-transects, db-schema.
- server Caddy redirect (on branch `feat/release-redirects`, not `main`).

---

## GO / NO-GO items (need your word)

**1. Push the release engine + remaining consumers.** Low risk — all backward-compatible with the
live release. Unblocks the next release running on the new code. → *push calcofi4db, workflows,
calcofi4py, db-query, db-viz-station, ctd-transects, db-schema.*

**2. Deploy the Caddy redirect rule to the production server**, then run T4
(`scripts/verify_storage_redirects.sh v2026.08.25`). The rule is a 404-only 302 map (empty default =
no-op for every path that still 200s), so it cannot affect a working URL. This is the only way to
prove the redirect. → *server `git pull` on `feat/release-redirects`→main, regen
`releases_redirects.caddy` from the prod catalog, reload Caddy.*

**3. Cut the first real content-addressed release.** This is the actual "proceed": re-run
`release_database.qmd` on the **production** prefix (`CALCOFI_RELEASE_LAYOUT=canonical`). It also
**re-releases v2026.08.25's data deduplicated** (fixes the 4,855 samples) — so it doubles as the
sample-fix release. It writes the `tables/` store + compat copies + catalog; latest.txt promotion
still gates on `test_release.qmd`. Then `deploy_consumers.sh` rebuilds the Shiny apps (their
`prep_db.R` must NOT be re-run against the current v2026.08.25 — they'd carry the dup).

**4. Thin the archive** — `scripts/thin_releases.R` (dry-run first, T7), then `--execute`. **Deletes
~130 GB** of non-consolidated versions' parquet (keeps sidecars + notes, writes `retired.json`,
sweeps unreferenced `tables/` objects). Irreversible after the 7-day soft-delete window. Keep:
v2026.04.08, .05.14, .06.26, .07.17, .08.14, .08.25 + promoted + predecessor.

Recommended order: **1 → 2 (+T4) → 3 → 4**. I can do 1–2 and the T7 dry-run of 4 on your go; I'd
want an explicit second confirm before `thin_releases.R --execute`.
