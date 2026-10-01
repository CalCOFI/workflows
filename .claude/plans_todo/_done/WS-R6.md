# WS-R6 — the Explorer's ramps: the default per variable group reaches every lens, and an anomaly is always balance (D4, Q3)

**Umbrella:** `.claude/plans/2026-09-15 CalCOFI.io faces round 2 — … agent-scaled.md` § D4 (revised by Q3), § Verification R6.
**Agent:** `ws-sonnet-high`. **Repo:** `../explore` (worktree `~/Github/CalCOFI/.worktrees/explore-ws-r6`, branch `ws-r6`, from
`main`). **Wave 2 · ≈ ½ day.** Ben (2026-09-15): "I like cmocean ramps, but not sure they are associated properly yet in Explorer
with different measurements, eg algae for productivity vs red-blue for temperature vs red-white-blue for anomaly".

## Read first (nothing else)
`src/ramps.ts` (whole: `RAMPS`, `defaultRamp()`), every call site of `defaultRamp`, `rampColors`, `rampCss` and of the URL `ramp=`
param (`grep -rn "defaultRamp\|rampColors\|rampCss\|\"ramp\"" src`), `src/state.ts` lines 30–40 and 260–320 (`anom`, `ramp` in the
URL), the Explorer's `README.md` § ramps or legend, the existing tests under `tests/` that touch ramps, `scripts/smoke_release.mjs`
(do not change it).

## You own
`src/ramps.ts`, the lens files that pick a ramp (map / section / contours / time series — name them in the hand-back), one new test
file `tests/ramps.default.test.ts`, `CHANGELOG.md` under Unreleased.

## Do
1. **Measure before touching.** For each lens × variable group (temperature, salinity, oxygen, chlorophyll/fluorescence,
   density, nutrients, PAR/light, a bio variable, an anomaly section) record the ramp id the running lens actually uses with no
   `ramp=` in the URL (read the state or the legend's gradient; Playwright with `?tour=off` if the state is not exposed). One table,
   before.
2. **Fix** every lens that does not call `defaultRamp(realm, variable, anomaly)` — that falls back to `viridis`, ignores
   `anomaly`, or keys on a stale variable name — so the rule in `ramps.ts` is the only rule. `anom=1` must give `balance` in every
   lens that can draw an anomaly. Do not change the rules themselves (thermal · haline · ice · algae · dense · tempo · solar) unless a
   rule provably matches the wrong group (e.g. `/rad/` catching `radius`); a rule change is reported, not assumed, because the landing
   site copies these rules (WS-R2).
3. **Test:** one test per lens × group asserting the ramp id; one asserting an anomaly is `balance` everywhere.
4. **Measure after.** The same table. `npm test`, `npm run build`, and `scripts/smoke_release.mjs` green.

## Gates (stop and report)
- A rule change (the regex or the ramp it names) — report it with the reason before committing so R2 can copy it.
- A lens whose ramp is chosen server-side or by the h3t API (out of this repo).

## Hand back (≤ 40 lines)
Branch + SHA; the two tables (lens × group → ramp, before / after); the call sites changed; test + build + smoke output; one
Measured line.
