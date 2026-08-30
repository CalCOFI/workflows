# Rebrand to the SIO look — `brand/v2` (light default), the calcofi.io landing page and the Explorer first

**Status:** proposed 2026-08-30, for the 9/3 (show) and 9/8 (decide) meetings with Mark and Erin ·
**Scale:** Phases 0–2 build the previews (~3.5 days) and nothing live changes until the flip; Phase 3 is
the fleet (~4–5 days, per product, any order) · **Supersedes nothing** — `brand/v1` stays frozen and
served; every product opts into `v2` by changing one URL.

## Context

calcofi.org is being rebuilt by the SIO web team, who will also support it afterwards, on the template
they built for [scripps.ucsd.edu](https://scripps.ucsd.edu) ("so it will look a lot like the SIO site").
Mark's thread *CalCOFI.io product renames & themes* (2026-08-25 → 08-27) is the brief:

- **Mark (08-27 15:51):** "how consistent in style and approach should these apps be with the upgraded
  website. That style is clean, clear and a bit dull. … I am not wedded to having the apps fit the guide
  perfectly, but there should be common elements." **(19:16):** "I do want to provide creative latitude on
  the apps, but there needs to be some connective tissue to the brand. (I don't like the boring, all
  white, blocky style either, but SIO's web team is creating a template and doing content migration for
  free!!!)"
- **Erin (08-27 18:16):** "I think the fonts and some colors would be good to align … Although I do feel
  pretty strongly that the dark mode/black background is an important thing for our data tools to make
  them look more polished and finalized."
- **Ben (08-27 16:37):** "the 'branding' (i.e., colors, fonts, logos) is relatively straightforward to
  update later. When I visit scripps.ucsd.edu I do see a lot of whitespace, which can be tricky to
  implement in apps already starved for visual real estate." — and the ask for this plan: keep dark and
  light, **default to light** to match SIO, put the whole thing in `brand/` as **v2**, start with the
  calcofi.io landing page and `CalCOFI/explore`.

The same thread carries Erin's naming suggestions and page-order ideas; they are a separate decision
(§ Naming & IA) and nothing here waits on them.

### What "the SIO look" measures as (live template, read in the browser 2026-08-30 at 1470 px)

The site is Drupal 10, theme `sio_ucsd` + a `sio_bluemoon` module, Bootstrap 3 grid. Its old base
stylesheet says gray `#484949` text and SIO blue `#006A96`; the **rendered** 2026 template has moved onto
the UC San Diego palette, and that is what calcofi.org will inherit:

| element | measured |
|---|---|
| body | **Brix Sans Regular 18 px / 1.44**, colour **navy `#182B49`**, white ground |
| h1 (hero) | **Refrigerator Deluxe Extrabold 72 px, uppercase**, letter-spacing 1 px, white on a full-bleed photo |
| h2 | Refrigerator Deluxe 41.4 px uppercase, navy on white / white on a band |
| h3 | Brix Sans Bold 31.5 px uppercase |
| eyebrow / dates | uppercase 0.85 em, Cool Gray `#747678` |
| nav | Brix Sans Bold 15 px **uppercase**, navy on white, 69 px row |
| masthead | **210 px, white, fixed**: 40 px utility strip (Jobs · News · Portal · Directory · UCSD.EDU, gray 15 px) + logo row (the "UC San Diego \| Scripps" lockup, 350 × 36) + the 69 px nav |
| container | 1170 px |
| hero | 688 px, padding 165/144, photo, 35-ch lede, one yellow CTA |
| bands | 40 px padding, alternating **white / Sand `#F5F0E6` / navy `#182B49`** |
| cards | UCSD blue `rgba(0,98,155,.91)` over a photo, **14 px corners, no border, no shadow**; white uppercase h3; uppercase bold 14.4 px "text-links" with a 1 px underline, letter-spacing 1.15 px |
| CTA button | **yellow `#FFCD00`, navy text**, Brix Bold 15 px uppercase, letter-spacing 1.2 px, **8 px corners**, min-width 200 px, 42 px tall |
| links | navy, bold, no underline (inline); the underlined text-link idiom for calls to action |
| footer | navy 82 px bar with the white lockup + social icons → 3-column link list on white → navy copyright bar |
| fonts | self-hosted `themes/custom/sio_ucsd/fonts/brix_sans/*.woff2` (Regular, Regular-Italic, Bold, Bold-Italic, Black) + `refrigerator_deluxe_extrabold`; FontAwesome 6 for icons |

So "clean, clear, a bit dull" is specific: navy type on white, condensed uppercase display headings,
one yellow accent, cream and navy bands, rounded borderless cards, and a lot of vertical room. The
whitespace is a **reading layout** — an 1170 px column, 18 px type, 40 px bands, a 688 px hero — not a
property of the palette or the type.

The UC San Diego brand site (brand.ucsd.edu) fixes the rest: the 14-colour palette (Navy `#182B49`, Blue
`#00629B`, Yellow `#FFCD00`, Gold `#C69214`, Cyan `#00C6D7`, Sand `#F5F0E6`, Cool Gray `#747678`, …);
**Brix Sans** is the typeface with **Source Sans** named as the free substitute on the typography page
(the web page says Roboto) and **Teko** for Refrigerator Deluxe; "WCAG 2 … at least 4.5:1 for normal
sized text"; and, for *campus* websites, "The UC San Diego logo must appear in the masthead" (site name
top-left, campus logo top-right). Appendix B has the quotes.

### Where we are (brand v1, 2026-08-25 → 08-29)

`calcofi.io/brand/v1/` — `theme.css` (nine semantic tokens, `.cc-header`/`.cc-footer`, the release chip,
the sun / moon-in-sun toggle), `theme.js` (`?theme=` → `cc_theme` cookie on `.calcofi.io` → localStorage →
**dark**), `head.html`, `icons.css` + the 48-glyph sprite, the logo pair, the favicon set. Consumed by
URL from 16 repos (the landing page, explore, db-schema, db-query, workflows, analytics, docs, calcofi4r,
calcofi4db, calcofi4py, erddap, uptime, server/storage, pollutants, db-viz-hex, api-h3t-py) and, through
`calcofi4r::cc_brand_head()`/`cc_brand_header()`, the Shiny apps. The weekly `check_brand.py` opens every
`live_url` at `?theme=light` and `?theme=dark`; 16 of 26 cards are `shots: themed` with a dark and a
light capture. **All of that machinery is what makes a rebrand a one-URL change per product** — the point
of v1's "consumed by URL, never vendored" decision. v1 chose a neutral gray dark palette
(`#1b1d20` ground, `#4dabf7` accent) with a Bootstrap-flavoured light (`#2780e3`); neither is SIO.

The explorer (`CalCOFI/explore`, Vite + React) is the most demanding consumer: a 13 px working surface
(27 rules at 11 px), three docked rails, floating cards over a map, 4/6 px corners, `color-mix()` panels,
Plotly reading its colours from the tokens via `getComputedStyle`, the basemap swapping on `cc:theme`
(CARTO dark-matter / positron), an html-to-image feedback capture, and a phone layout — it is the test of
whether the tokens work at density.

## Goal

One `brand/v2` that gives every product the SIO **connective tissue** — its type, its palette (navy /
blue / yellow / sand), its header anatomy, its button and link idiom, and a light ground by default —
while an app keeps its own density and layout. Concretely:

1. **Light is the default; dark stays first-class and one click away**, remembered across
   `*.calcofi.io` exactly as today, and `?theme=` still forces either. The v2 dark theme is **navy**, not
   gray: the ground is the UCSD navy the SIO template already uses for its bands, so a dark app is still
   recognisably on-brand (and Erin's "polished" dark is a click, not a fork).
2. **Type**: Source Sans 3 for everything, Teko for page display headings (both OFL, self-hosted in
   `brand/v2/fonts/`); the tokens name *roles*, so licensing Brix Sans later is a one-file swap.
3. **The header is SIO-shaped and still one bar**: a horizontal CalCOFI lockup far left → calcofi.io,
   the product title as an uppercase nav item → its root, uppercase links, the release chip, the toggle.
4. **The whitespace question has a mechanism, not a mood**: `theme.css` carries two scales — *page*
   (18 px / 40 px bands / 1170 px) and *app* (13 px / 6 px gutters / 44 px header) — selected by one
   attribute. Pages get SIO's rhythm; apps get SIO's tokens.
5. **Preview in place before anything flips**: `calcofi.io/brand/v2/` (a specimen page),
   `calcofi.io/v2/` (the landing page) and `calcofi.io/explore/v2/` (the explorer), both themes, so the
   9/3 meeting clicks through the real thing and 9/8 decides.
6. **Checked, not assumed**: `check_brand.py` reports each product's brand version and its default
   theme; a v2 product must default light, load the fonts and carry the lockup.

## Non-goals

- Re-laying out any app. Rails, cards, pills, the z scale, the tour, feedback — untouched. v2 changes
  what things are *made of*, not where they are.
- Importing SIO's masthead (210 px, utility strip, search), its Drupal components, FontAwesome, or its
  hero photography as a requirement. The landing page may take a photo band once the SIO team shares
  calcofi.org's imagery; the text hero ships first.
- The UC San Diego lockup in calcofi.io's masthead (Decision 7) — CalCOFI is NOAA + CDFW + SIO.
- Retiring v1. It stays served and frozen; a product that never migrates keeps working.
- The renames and the page order from the thread (§ Naming & IA): designed for, decided separately.
- Students / archived cards: single screenshot, both themes, as in v1.

---

## The contract — `calcofi.io/brand/v2/`

Same directory idiom as v1, same file names, so a consumer's diff is `v1` → `v2` plus the header lockup:

```
brand/v2/
  theme.css            # tokens (both themes, both scales), .cc-header / .cc-footer / .cc-release / buttons / text-link / bands
  fonts.css            # @font-face for Source Sans 3 (variable) + Teko; the one file to edit if Brix Sans is licensed
  fonts/               # SourceSans3[wght].woff2, SourceSans3-Italic[wght].woff2, Teko[wght].woff2 (OFL, ~200 KB total, latin subset)
  theme.js             # v1's, with: default "light"; persist only on an explicit choice; version "2"
  head.html            # favicon set + font preloads + the pre-paint snippet + fonts.css + theme.css + theme.js
  icons.css  icons/    # the v1 sprite, regenerated here (build_icons.mjs takes the output dir)
  logo_calcofi.svg  logo_calcofi_light.svg        # the mark, as v1 (kept for favicons, cards, small places)
  logo_calcofi_h.svg  logo_calcofi_h_light.svg    # NEW: the horizontal lockup — mark + "CalCOFI" wordmark (+ the long name, small)
  favicon.ico  favicon-32x32.png  favicon-16x16.png  apple-touch-icon.png
  index.html           # the specimen: every token, both themes, both scales, header, buttons, cards, chips — what the meeting looks at
  README.md            # the contract, the deltas from v1, the per-framework recipes
```

### Tokens (semantic names unchanged from v1, so every consumer's CSS keeps resolving)

| token | light (default) | dark | note |
|---|---|---|---|
| `--bg` | `#ffffff` | `#0f1a2e` | dark ground sits just below UCSD navy so navy panels read as panels |
| `--panel` | `#f5f5f5` | `#182b49` | **UCSD Navy** is the dark panel — SIO's own band colour |
| `--panel-2` | `#ffffff` | `#21375c` | |
| `--border` | `#dddddd` | `#34486b` | |
| `--fg` | `#182b49` | `#e9edf3` | **navy text on white** is the single most SIO thing on the page (14.2:1) |
| `--muted` | `#6e7072` | `#9fb0c8` | Cool Gray `#747678` darkened one step: 4.6:1 on `--panel` (the brand value is 4.2:1 there, below AA) |
| `--accent` | `#00629b` | `#4fb6e6` | **UCSD Blue** for links and the active state (6.5:1); lifted for the dark ground (7.6:1) |
| `--accent-d` | `#004663` | `#8ad0f0` | hover |
| `--on-accent` | `#ffffff` | `#0f1a2e` | NEW — text on an accent fill; white on the dark accent is 2.3:1, so dark uses navy |
| `--warn` | `#8a6500` | `#ffcd00` | UCSD Gold darkened for AA as text (5.3:1); the yellow itself in dark (11.6:1) |
| `--band` | `#f5f0e6` | `#182b49` | NEW — the alternating page band (**Sand** / navy) |
| `--cta-bg` / `--cta-fg` | `#ffcd00` / `#182b49` | same | NEW — the yellow button, both themes (9.5:1) |
| `--cc-navy --cc-blue --cc-yellow --cc-gold --cc-cyan --cc-sand --cc-gray` | constants | constants | the UCSD palette by name, for a product's own use (a highlight, a chart annotation) |
| `--sans` | `"Source Sans 3", system-ui, -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif` | | |
| `--display` | `"Teko", "Source Sans 3", Impact, sans-serif` | | page h1/h2 only; an app never uses it |
| `--mono` | as v1 | | |
| `--radius` / `--radius-card` | `8px` / `12px` (page) · `4px` / `6px` (app) | | SIO rounds its CTAs 8 px and its cards 14 px — "blocky" is the band layout, not the corners |

Contrast ratios above were computed (WCAG 2 relative luminance) for every text/ground pair used; the
two derived values (`--muted`, light `--warn`) exist only because the brand's own value fails AA on the
panel gray at UI sizes, and the README says so. Everything else is a brand value verbatim.

### Two scales, one attribute

```css
:root                      { --fs: 18px; --lh: 1.44; --space: 8px; --band-pad: 40px; --header-h: 72px; --container: 1170px; --radius: 8px; --radius-card: 12px; }
:root[data-cc-scale="app"] { --fs: 13px; --lh: 1.35; --space: 4px; --band-pad: 0;    --header-h: 44px; --container: none;   --radius: 4px; --radius-card: 6px;  }
```

`head.html` sets `data-cc-scale` from a `<meta name="cc-scale" content="app">` beside it (the pre-paint
snippet reads it, so there is no reflow). A page gets SIO's rhythm by default; an app declares `app` and
gets the same tokens at its own density. This is the whole answer to "how would the whitespace work for
the apps": **it doesn't transfer, and it isn't supposed to** — the connective tissue is type, palette,
header, buttons and links, which transfer at any size.

### Type

- **Body / UI:** Source Sans 3 (variable, 200–900). Chosen over Roboto (the web page's substitute)
  because the typography page names Source Sans, its humanist forms are the closer match to Brix, and
  Roboto is what the *old* calcofi.org (OceanWP + Elementor) already uses — it reads as no identity.
- **Display:** Teko 500–600, uppercase, letter-spacing 0.02 em, for page h1 (56–72 px) and h2 (36–41 px).
  Not used in apps (nothing there is that size), and h3 down is Source Sans 3 700 uppercase with
  0.04 em tracking, the SIO nav/h3 idiom.
- **Self-hosted, not Google-hosted**: one origin, no third-party request, works in the feedback capture
  (GitHub Pages sends `access-control-allow-origin: *` on every asset — verified on `brand/v1/theme.css`
  — so html-to-image can embed the fonts cross-origin). `font-display: swap`; `head.html` preloads the two
  woff2 files; latin subset only (~200 KB total; the variable Source Sans 3 is ~110 KB).
- **Brix Sans:** MyFonts-licensed to UC San Diego, self-hosted by SIO under that license. We do not
  hotlink it (license and CORS). **Ask the SIO web team** whether their webfont license can cover
  calcofi.io as a UCSD-hosted program; if yes, `fonts.css` swaps the sources and `--sans` gains
  `"Brix Sans"` at the front — nothing else changes, because every rule names the role.

### Header (`.cc-header`, one bar, SIO-shaped)

```html
<header class="cc-header">
  <a class="cc-home" href="https://calcofi.io" aria-label="CalCOFI.io home">
    <img class="cc-logo-dark"  src="…/brand/v2/logo_calcofi_h.svg"       alt="CalCOFI" height="36">
    <img class="cc-logo-light" src="…/brand/v2/logo_calcofi_h_light.svg" alt="CalCOFI" height="36">
  </a>
  <a class="cc-title" href="./">Explorer <small>Stations</small></a>
  <a class="cc-release" …>release <b>v2026.08.25</b></a>
  <span class="cc-spacer"></span>
  <nav class="cc-links"><a>Apps</a><a>Services</a>…</nav>
  <button class="cc-theme-toggle">🌓</button>
</header>
```

- White ground in light, navy (`--panel`) in dark; a 1 px `--border` rule below; sticky, as v1.
- **The lockup** is the new asset: the existing round mark beside a "CalCOFI" wordmark set in Source
  Sans 3 800 (and, in the page scale, the long name in 11 px caps beneath) — drawn once as SVG, two
  variants, **36 px tall on pages, 28 px in apps**. SIO's identity is a horizontal lockup; a 32 px mark
  with text beside it in the page font is what v1 does and it reads as an app icon, not a masthead.
- **Title and links in the SIO nav idiom**: Source Sans 3 700, 15 px on pages / 13 px in apps,
  uppercase, 0.06 em tracking, navy (`--fg`); hover and the current item in `--accent`. The title keeps
  its `<small>` subtitle (the explorer's lens; Erin's descriptive names — § Naming & IA), set in 400
  sentence case.
- The release chip, `.cc-icon-button`, the sun / moon-in-sun toggle: unchanged, on the new tokens.
- **No utility strip, no search, no second bar** — SIO's 210 px is its whole IA; ours is one product.
  `calcofi.org ↗` is a link in `.cc-links` on the landing page, where the SIO template's utility strip
  would carry "UCSD.EDU".

### Buttons, links, cards, bands (page scale; apps take only the first two)

- `.cc-btn` — the SIO button: uppercase 700, 0.08 em tracking, 8 px corners, 42 px tall, min-width 200 px.
  `.cc-btn-cta` yellow / navy (both themes); `.cc-btn-primary` `--accent` / `--on-accent`;
  `.cc-btn-ghost` outlined. **One yellow per view** — it is the accent, not a colour.
- `.cc-text-link` — the uppercase 700 14.4 px link with the 1 px underline and 0.08 em tracking ("VIEW ALL",
  "OPEN →"); inline links in prose are `--accent`, no underline, underline on hover.
- `.cc-card` — `--radius-card`, no border, no shadow, `--panel-2` on a band or `--panel` on `--bg`; image
  on top at 16:10; an uppercase eyebrow; title in `--accent`.
- `.cc-band` — full-width, `--band-pad` vertical, alternating `--bg` / `--band` / navy (`.cc-band-navy`,
  white text) — the SIO page rhythm in one class.

### `theme.js` v2 — what changes and the rollout wrinkle

Resolution is v1's with the default flipped: `?theme=` → cookie → localStorage → **`light`**. Two
mechanics change, both because v1 and v2 pages will coexist for a few weeks:

1. **Persist only an explicit choice.** v1's `theme.js` writes the resolved theme into the cookie *on
   every load* — so a visitor whose first page is a v1 product gets `cc_theme=dark` written from v1's
   default, and every v2 page would then open dark. v2 writes the cookie (and `localStorage.cc_theme`) only
   from the toggle or `?theme=`, and marks it `cc_theme_src=user`; on load it honours `cc_theme` only when
   that marker is present. A v1 default can no longer leak into v2; a v1 *toggle* is lost across the
   boundary during the rollout (it lacks the marker), which is the acceptable cost and is documented.
2. **`window.ccTheme.version === "2"`** and a `cc:theme` detail of `{theme, version}`, so the checker and
   an app can tell which contract a page is on.

`?theme=` keeps persisting (v1 Decision 2), `?tour=off` is unchanged, `data-theme` / `data-bs-theme` /
`data-md-color-scheme` are set as before. `prefers-color-scheme` stays unused (Decision 1).

---

## Phase 0 — `brand/v2` + the specimen page (`CalCOFI.github.io`)  ~1.5 days

1. `theme.css`, `fonts.css` + `fonts/`, `theme.js`, `head.html` as above; `icons.css` + sprite regenerated
   into `v2/` (`node scripts/build_icons.mjs ../CalCOFI.github.io/brand/v2` — the script already takes the
   directory). Favicon set copied (unchanged; the mark is the mark).
2. **The lockup** `logo_calcofi_h.svg` / `_light.svg`: compose from the existing mark's paths + the
   wordmark as outlined text (Source Sans 3 800; outline it so the SVG needs no font), two grounds,
   `viewBox` 0 0 ~1200 240 (5:1). Check it at 28 px against the mark-plus-text v1 header before drawing
   the long-name line; the app header may not want it.
3. **`brand/v2/index.html`, the specimen**: the header in both scales; the type ramp (Teko h1/h2, Source
   Sans 3 h3–body–caption at page and app sizes, the 11 px app labels on the panel gray); every token as a
   swatch with its contrast ratio; buttons, text-links, chips, the release chip; a `.cc-card` row on each
   band; a sample of the explorer's rail (copied markup) on the app scale — and **the toggle**, so the
   meeting sees dark-navy next to light. One page, no framework, both themes: the thing to send Mark, Erin
   and the SIO web team before 9/3.
4. `README.md`: the contract, the v1 → v2 deltas (default theme, lockup, scale attribute, `--on-accent`,
   `--band`, `--cta-*`, the persistence rule), the per-framework recipes carried over from v1's plan with
   the URL changed, and the Brix Sans note.
5. v1's README gains one line: superseded by v2 on the flip date; v1 remains served, frozen.

Verification: `index.html` passes `check_brand.py`'s four checks on itself at `?theme=light` and `?theme=dark`;
`document.fonts.check('16px "Source Sans 3"')` true after load; every text/ground pair in the swatch table
≥ 4.5:1 (the specimen computes and prints them — the table above must match).

## Phase 1 — the landing page on v2, as a preview at `calcofi.io/v2/`  ~1 day

Jekyll makes preview-in-place trivial: a second layout and a second index, both on `main`, no flag.

1. `_layouts/v2.html` — `brand/v2/head.html` (same-origin paths, as today), the v2 header (lockup, the
   section anchors as uppercase nav, `calcofi.org ↗`, toggle), `style-v2.css` after `theme.css`.
   `v2/index.html` is today's `index.html` with `layout: v2`. When the flip comes, `default.html` and
   `style.css` take the v2 content and `v2/` is deleted — one commit.
2. `style-v2.css` — only what is page-specific, on the page scale:
   - **hero**: a `.cc-band` (Sand) with "FROM SHIP TO SCREEN" in Teko at 64 px, the lede at 18 px / 1.44
     capped at 60 ch, the `ship → workflows → database → …` line as a muted mono caption, and one yellow CTA
     **Explore the data** → the Explorer. No photo until the SIO team shares calcofi.org's imagery
     (Decision 8); the band is designed to take one (`background-size: cover`, white text variant).
   - **sections**: h2 in Teko 41 px uppercase navy with the count as a muted eyebrow; the blurb at 18 px;
     `.cc-band` alternation white / Sand / white; "VIEW ALL"-style text-links where a section has a
     sibling site (Developer → docs).
   - **cards**: `.cc-card` — 12 px corners, no border, image top (the light shot is now the default face),
     eyebrow = the section name, title in `--accent`, description at 16 px navy, tech chips, the
     `open ↗ · source ↗` row as text-links, `status · usage` muted at the right as today. Featured grid
     unchanged. `demoted` cards keep 0.75 opacity.
   - **section nav**: the pill strip becomes an uppercase tab row (SIO's nav idiom) under the hero.
   - **footer**: a 3-column white footer (Program · Technical · Links) over a navy copyright bar, and the
     **partner strip** — NOAA · CDFW · SIO/UC San Diego marks, "a partnership since 1949" — assets from
     calcofi.org's media (`sio_logo-1.png`, `NOAA_round_logo.png`, `CDFW_logo.png` are what it serves
     today); confirm the SIO lockup file with the SIO web team (Decision 7).
3. `_includes/product_card.html`: `img:` fallback and the single-shot cards prefer `_light`; an optional
   `tagline:` renders under the title (§ Naming & IA).
4. `scripts/shots.py`: no change needed for the previews — `check` already tests luminance per theme.
   The landing page's own card image is reshot after the flip.

Verification: `bundle exec jekyll build` clean; `/v2/` at both themes in Chrome and on a phone width;
`check_brand.py` against `https://calcofi.io/v2/` (add a `--url` override) passes; the light default holds
in a fresh profile (no cookie); Lighthouse a11y ≥ 95 (contrast is the thing that moves).

## Phase 2 — the Explorer on v2, as a preview at `calcofi.io/explore/v2/`  ~1 day

1. **Build-time brand selection**: `VITE_BRAND` (`v1` | `v2`, default `v1` until the flip) → `index.html`
   is templated (a 20-line Vite HTML plugin, or two `index.html`s picked by `build.rollupOptions.input`)
   so `head.html` and the logo URLs follow it; `pages.yml` builds twice — `VITE_BASE=/explore/` with v1 to
   `dist/`, `VITE_BASE=/explore/v2/ VITE_BRAND=v2` to `dist/v2/` — and uploads `dist` once. The flip is
   the default of one variable and deleting the second build.
2. `index.html`: `<meta name="cc-scale" content="app">` beside the v2 head; the lockup images.
3. `App.tsx` header: `cc-logo-*` → the lockup at 28 px; the title's `cc-title-org` span goes (the lockup
   says CalCOFI); "Explorer" + the lens subtitle stay; the release chip, the help cluster, the toggle
   unchanged.
4. `style.css` sweep — small, because the app is already on the tokens (185 `var(--…)` uses, three hex
   literals):
   - the 9 `rgba(0,0,0,…)` shadows → `color-mix(in srgb, var(--fg) 20%, transparent)` so they read on
     white (a black shadow on a white page is v1's dark heritage);
   - `.lenses button.on` `#fff` → `--on-accent`; `.timing .go/.nogo` greens/reds → `--cc-green`/a red
     token added to v2 (`#6e963b` UCSD Green passes on navy, needs darkening on white — same treatment
     as `--warn`);
   - `--folded`, the z scale, radii: unchanged (`--radius` resolves to the app scale's 4 px);
   - **measure the 11 px labels in Source Sans 3** against system-ui on the specimen's rail sample — its
     x-height is smaller; expect the 11 px rules to want 11.5–12 px and `letter-spacing: 0.01em` on the
     uppercase group titles. Decide from the preview, not in advance.
5. `charts.tsx`: the hard-coded fallbacks (`#3a3f44 #9aa0a6 #e6e9ed`, `#2780e3/#4dabf7`) → the v2 values
   (they only apply before `getComputedStyle` answers); the **selection highlight `#ffd60a` → `--cc-yellow`
   `#ffcd00`** — the one place the SIO accent lands inside the data view, deliberately: the thing you
   picked is marked in the brand's yellow. The viridis ramp and the dataset colours are the product's own
   and stay.
6. `map.tsx`: positron for light, dark-matter for dark — already right; light is now the first frame.
7. `capture.ts` (feedback screenshot): html-to-image must embed the two woff2 files now that text is not
   in the system stack — CORS is fine (above); check the composited PNG on both themes, and that the
   fallback still stamps a legible footer if a font fails.
8. `tour.ts` / `help.tsx` / `feedback.tsx` modals: on tokens already; check the driver.js popover on white.
9. Phone: the header at 390 px with the lockup at 28 px — if it wraps, the lockup drops the wordmark
   (`<picture>`/`srcset` with the mark) below 480 px.
10. `scripts/verify.mjs` gains `v2_*` checks (default light in a fresh context; `ccTheme.version === "2"`;
    fonts loaded; the lockup present; no `#fff`/`rgba(0,0,0` left in `style.css`); `card_shots.mjs` shoots
    the preview for the meeting.

Verification: `npm run build` clean for both builds; `verify.mjs`; both themes at 1470 px and 390 px;
the feedback capture on both themes; the timing panel's first-paint number within noise of today's
(fonts are preloaded; the app's own bundle does not change size).

## 9/3 (show) → 9/8 (decide) → the flip  ~0.5 day

Send before 9/3: the specimen, `/v2/`, `/explore/v2/`, and the decisions below. After 9/8: flip the
landing page (`default.html` ← v2, delete `v2/`), flip the explorer (`VITE_BRAND` default, delete the second
build), reshoot both cards, and open Phase 3 with the order in its table. The v1 pages keep working; the
grid on calcofi.io is mixed (v2 light shots beside v1 light shots) until Phase 3 lands — order it by card
prominence.

## Phase 3 — the fleet, one URL at a time  ~4–5 days, any order after the flip

The mechanism is v1's: change `brand/v1` → `brand/v2` in the head, add the lockup, set the scale,
reshoot. Per product, what is *not* mechanical:

| product | scale | beyond the URL swap | size |
|---|---|---|---|
| `calcofi4r` 1.15.0 (`R/brand.R`) | — | `cc_brand_head(brand = "v2")` / `cc_brand_header()` emit the lockup + `data-cc-scale="app"`; `cc_theme(default = "light")` follows the brand; `cc_plot_colors()` gets the v2 values (both themes); `.CC_BRAND_URL` per version; NEWS + tests. **Gates the five Shiny apps.** | ½ d |
| Shiny — db-viz-hex, ctd-viz, db-viz-cruise, ctd-qaqc, pollutants | app | helpers only; bslib's `input_dark_mode(mode = cc_theme(request))` now starts light; `prep_db.R` untouched; deploy via the `deploy-consumers` skill | ½ d |
| `db-viz-station`, `ctd-transects` (static JS) | app | header lockup; station's bespoke `--ocean/--deep` palette rebinds its light set to v2; transects' plot theme reads tokens | ½ d |
| `db-schema`, `db-query`, `analytics` (Jekyll / Hugo) | page | the page scale suits them (reading sites); Mermaid ERD light theme default; Leaflet `light_nolabels` first | ½ d |
| `workflows` index + ~60 rendered notebooks | page | `libs/brand/quarto_head.html` → v2 and Quarto's *light* theme becomes the default (`brand-light.scss` gets the Source Sans stack + navy); `scripts/brand_inject_html.R` swaps the URL in already-rendered HTML — no re-render | ½ d |
| `docs` (Quarto book) | page | `brand-head.html` → v2; light first in `_quarto.yml` (it already is) | ¼ d |
| `calcofi4r`, `calcofi4db` (pkgdown), `calcofi4py` (mkdocs) | page | `_pkgdown.yml` includes → v2; mkdocs `extra.css` navy header now *is* the brand — keep; both keep their own favicons | ½ d |
| ERDDAP, storage index (`libs/gcs_index.R`), status (Upptime), api-h3t-py | page | URL swap; Upptime stays dark (no runtime toggle) with the v2 navy; ERDDAP's best-effort dark overlay re-checked on the navy tokens | ½ d |
| calcofi.io cards | — | reshoot every `shots: themed` product after its migration (`scripts/shots.py <key>`), the light shot first | ¼ d |

## Phase 4 — keep it true  ~½ day

- `check_brand.py`: report `ccTheme.version` per product; for a v2 product also require: **default theme
  is light in a fresh context** (no `?theme=`, no cookie — shot-scraper's context is fresh), fonts loaded
  (`document.fonts.check('16px "Source Sans 3"')`), the lockup `<img>` present, and `data-cc-scale` set
  for `app.calcofi.io/*`. The weekly run fails a `shots: themed` product that regresses to v1.
- `shots.py`: the default face of a themed card is `_light`; `check` unchanged.
- `CLAUDE.md` § The brand contract → v2 (default light, lockup, scale, `--on-accent`/`--band`/`--cta-*`,
  the persistence rule); the new-product checklist gains "declares its scale".
- `brand/v1/README.md` marked superseded with the date; `check_brand.py` warns on any v1 product after
  Phase 3 closes.

---

## Naming & IA (from the thread) — decided separately; the design leaves room

Erin proposed descriptive names (Station Explorer → "CalCOFI data finder", Cruise Explorer → "CalCOFI
cruise data inventory", Hexagon Explorer → "CalCOFI larval fish and oceanography data explorer", CTD
Explorer → "CTD cast data visualizer", …), splitting the top section into *Find what data have been
collected* / *Explore CalCOFI data*, and a *Past applications* section at the bottom for the superseded
Contour Explorer. Ben: the long forms fit a card but not an app's header; single words plus a subtitle.

v2 accommodates any outcome without rework: `products.yml` gains an optional **`tagline:`** (the
descriptive name, rendered under the card title and as the app header's `<small>` subtitle through
`cc_brand_header(subtitle = )`); sections are already data (`sections:`), so the split is a YAML edit; a
*Past applications* section is `status: superseded` cards sorted last. Nothing in Phases 0–2 depends on
which names win.

## Decisions to confirm (9/3 → 9/8)

1. **Default = light, fleet-wide, one default.** Alternatives: (a) pages light / apps dark — rejected:
   the choice persists across `*.calcofi.io`, so a split default is exactly v1's "coin-flip on clicking a
   card" for every fresh visitor; (b) `prefers-color-scheme` as the fallback — rejected as in v1 (a
   non-deterministic first impression; a one-line change if wanted later). Erin's dark preference is
   met by making dark **navy and good**, one click, remembered, and shown on the cards when chosen.
   *Recommend light everywhere.*
2. **Source Sans 3 + Teko now; Brix Sans + Refrigerator Deluxe if the SIO web team's license covers
   calcofi.io.** Ask Mark to ask. *Recommend proceeding with the free pair; the swap is one file.*
3. **Palette = the UCSD palette verbatim**, with two derived text tones (`--muted`, light `--warn`)
   documented as AA fixes. Alternative: SIO's older `#006A96` blue — rejected; the live template is on
   `#00629B` and calcofi.org will be too. *Recommend as stated.*
4. **Dark = navy** (`#182B49` panels on a `#0f1a2e` ground), not a darkened gray. *Recommend navy* — it is
   the SIO template's own dark band, so the connective tissue survives the toggle.
5. **The horizontal lockup** — mark + wordmark, drawn by us in Source Sans 3 800. Alternative: ask the
   SIO team's designer for a CalCOFI lockup in Brix (better, slower, and it commits calcofi.io to a font it
   may not have). *Recommend drawing it now; replace if SIO supplies one.*
6. **Corners: 8 px buttons / 12 px page cards / 4 px in apps.** SIO's own template is rounded; Mark's
   "blocky" is the full-width band layout, which pages take and apps don't. *Recommend.*
7. **No UC San Diego lockup in calcofi.io's masthead; the partner strip in the footer.** The brand
   site's masthead rule is written for campus websites; CalCOFI is a NOAA–CDFW–SIO program and calcofi.org
   (built by SIO) is where the institutional identity belongs. Mark should confirm this with the SIO web
   team, since they may have a view. *Recommend the footer strip.*
8. **Hero: text band first, photo when calcofi.org's imagery is shared.** *Recommend not waiting on a photo.*
9. **Preview-in-place** (`/v2/`, `/explore/v2/`, `brand/v2/index.html`) rather than branches or a staging
   site. *Recommend* — the reviewers click a real URL on their phone.
10. **Brand v2 is "consumed by URL", v1 stays served forever.** As v1 Decision 3. *Recommend.*

## Risks and what bounds them

- **Type at density.** Source Sans 3's x-height is smaller than system-ui's; the explorer's 27 rules at
  11 px may need 12 px. Bounded by the specimen's rail sample and the `/explore/v2/` preview — decided by
  looking, before the flip.
- **Fonts and the feedback capture.** A cross-origin font that html-to-image cannot embed makes the
  screenshot fall back to system type. CORS is verified; the Phase 2 check on both themes is the gate.
- **The cookie boundary.** Mixed v1/v2 weeks: a v1 toggle does not carry into v2 pages; a v1 default cannot
  leak into them. Bounded by the `cc_theme_src` rule and a short Phase 3.
- **Mixed grid.** Until Phase 3 lands, calcofi.io shows v2 light shots beside v1 light shots. Bounded by
  ordering Phase 3 by card prominence (Apps first) — ~1 week.
- **calcofi.org drift.** Our values are measured from scripps.ucsd.edu today; the SIO template will move.
  Ask the SIO web team for their token sheet or theme CSS; re-measure when calcofi.org launches; the
  README records the date and the numbers.
- **Taste.** Mark dislikes "all white, blocky"; Erin likes dark. The specimen shows both themes side by
  side, with the Sand and navy bands, before anyone commits — the plan's first deliverable is the thing
  to argue over.

## Rough order & size

| phase | repos | size |
|---|---|---|
| 0 brand/v2 + specimen + lockup | CalCOFI.github.io | 1½ d |
| 1 landing page preview `/v2/` | CalCOFI.github.io | 1 d |
| 2 explorer preview `/explore/v2/` | explore | 1 d |
| — 9/3 show · 9/8 decide · flip both | both | ½ d |
| 3 the fleet | calcofi4r, 5 Shiny, 2 static, 3 Jekyll/Hugo, workflows, docs, 3 package sites, 4 services | 4–5 d |
| 4 checker · shots · docs | CalCOFI.github.io, workflows | ½ d |

## Kickoff prompt (a new session — cwd `~/Github/CalCOFI/workflows`, so CLAUDE.md and the memory index load)

> Execute Phase 0 of `.claude/plans/2026-08-30 Rebrand to the SIO look — brand v2 …md`: create
> `CalCOFI.github.io/brand/v2/` (theme.css with the token table and the two scales, fonts.css + self-hosted
> Source Sans 3 and Teko, theme.js with the light default and the explicit-persist rule, head.html, icons
> regenerated, the horizontal lockup SVGs, the specimen index.html, README.md). Verify the specimen against
> `scripts/check_brand.py` at both themes and print the contrast table. Then Phase 1 (`_layouts/v2.html`,
> `v2/index.html`, `style-v2.css`) and Phase 2 (`VITE_BRAND`, the second Pages build, the style.css sweep,
> charts fallbacks, capture check). Do not flip any default; do not touch the other consumers. Commit and push as needed.

---

## Appendix A — scripps.ucsd.edu, measured 2026-08-30 (Chrome, 1470 × 832; the numbers behind § Context)

`getComputedStyle` on the live page: body `BrixSansRegular 18px/25.92px #182B49`; h1 `RefrigeratorDeluxeExtrabold
72px/79.2px uppercase, letter-spacing 1px, #fff`; h2 `41.4px/45.54px uppercase` navy or white, margin 22/11.5;
h3 `BrixSansBold 31.5px/30px uppercase`; nav link `BrixSansBold 15.03px uppercase #182B49`, 69 px row; utility
link `BrixSansBold 15px #484949`, 40 px strip; masthead 210 px (`.navbar-fixed-top`, white); lockup img
350 × 36 at y = 65; `.container` 1170; hero 688 px (`padding 165px/144px`, background image); bands at
`padding 40px` with backgrounds `#fff`, `#F5F0E6`, `#182B49`; card `.panel-primary` `rgba(0,98,155,.914)`,
`border-radius 14px`, no border/shadow, 360 px wide; `.btn-default` `#FFCD00` on `#182B49`, `BrixSansBold
15px uppercase`, `letter-spacing 1.2px`, `border-radius 8px`, `min-width 200–238px`, 42 px; `.text-link`
`BrixSansBold 14.4px uppercase`, `letter-spacing 1.152px`, `border-bottom 1px`; footer `.footer-sio-bar`
`#182B49` 82 px, then a 585 px region; `document.fonts`: BrixSansRegular, BrixSansBold (+ a base64
Refrigerator face). Stylesheet facts (theme `sio_ucsd`, module `sio_bluemoon`): `@font-face` sources under
`themes/custom/sio_ucsd/fonts/brix_sans/*.woff2` and `fonts/refrigerator_deluxe_extrabold/`; Bootstrap 3
containers 750/970/1170; the older base rules use `#484949` text, `#006A96` links/`#004663` hover,
`#747678` meta, `#DDDDDD`/`#EEEEEE`/`#F5F5F5` grays, `#00C6D7` date underline.

## Appendix B — UC San Diego brand (brand.ucsd.edu, read 2026-08-30)

Palette: Navy `#182B49` (PMS 2767), Blue `#00629B` (3015), Yellow `#FFCD00` (116), Gold `#C69214` (1245);
accents Turquoise `#00C6D7`, Magenta `#D462AD`, Sand `#F5F0E6`, Citron `#F3E500`, Orange `#FC8900`, Green
`#6E963B`; neutrals Black, Cool Gray `#747678`, Stone `#B6B1A9`, White. "Blue being a required color" on
external materials; accents "secondary and non-dominant."

Typography: Brix Sans (primary, MyFonts), Refrigerator Deluxe (headlines, Adobe Fonts), Chronicle (formal
serif). "Source Sans is a clean sans serif with a wide range of weights similar to Brix" (Google Fonts);
"Never use Brix and Source Sans simultaneously"; Teko for Refrigerator Deluxe; "For digital, font size
should be between 12-16 px." Hierarchy: H1 Refrigerator Deluxe Heavy all caps; H2 Brix Black all caps; H3
eyebrows Refrigerator Deluxe Extra Bold all caps; body Brix Regular, 140 % leading. The web-and-digital
page names Roboto as the substitute instead, and Helvetica Neue/Helvetica/Arial as the backup stack.

Web: "The Web Content Accessibility Guidelines (WCAG 2) recommends a type/background contrast ratio of at
least 4.5:1 for normal sized text to meet Level AA requirements"; large text = "bold 18.66px (14 point) or
larger, or 24px (18 point) or larger." "The UC San Diego logo must appear in the masthead on all campus
websites" — "the site name … in the top left and the campus logo in the top right"; academic schools may
substitute their sub-brand logo. Nothing on dark mode or footers.

Contrast of the v2 pairs (WCAG 2 relative luminance): light — fg/bg 14.2, fg/panel 12.9, muted/bg 4.9,
muted/panel 4.6, accent/bg 6.5, accent/panel 6.0, warn/bg 5.3, white/accent 6.5, navy/yellow 9.5;
dark — fg/bg 14.8, fg/panel 12.1, muted/bg 7.9, muted/panel 6.4, accent/bg 7.6, accent/panel 6.2,
warn(yellow)/bg 11.6, white/accent **2.3** (hence `--on-accent`), navy/yellow 9.5. The brand's own
`#747678` on `#F5F5F5` is 4.2 and `#C69214` on white 2.8 — the two derivations in the token table.

## Appendix C — the thread, in order (subject *CalCOFI.io product renames & themes*)

08-25 15:30 Ben: the renames (Station/Hexagon/Cruise/Contour Explorer at `app.calcofi.io/{station,hex,cruise,contour}`,
CTD Explorer, CTD Transects, Pollutants; sections Apps · Apps — Dataset-Specific · Services · Developer ·
Student Contributions), the one look (dark + light, `?theme=`, logo → calcofi.io, favicon, release chip,
themed cards, weekly check), and release v2026.08.25. 08-25 16:17 Ben: student badges. 08-26 Erin: the
descriptive names, Find/Explore split, superseded apps at the bottom. 08-27 15:51 Mark: the SIO question.
16:37 Ben: marinate; names too long for the header; consolidate?; whitespace concern. 18:16 Erin: agenda
for the meetings; keep Contours at the bottom to show what was tried; align fonts and some colours; dark
mode matters. 19:16 Mark: creative latitude, connective tissue, the SIO template is free.

## Appendix D — sources

- `CalCOFI.github.io/brand/v1/{README.md,theme.css,theme.js,head.html}`, `_layouts/default.html`,
  `_includes/product_card.html`, `style.css`, `_data/products.yml` (26 products, 16 themed, 5 sections),
  `scripts/{check_brand.py,shots.py}`, `.github/workflows/pages.yml`
- `explore/{index.html,src/App.tsx,src/style.css,src/charts.tsx,src/map.tsx,scripts/build_icons.mjs,vite.config.ts,.github/workflows/pages.yml}`
- `calcofi4r/R/brand.R` (1.14.2)
- `.claude/plans/2026-08-25 Consistent dark-light theme …` (v1) and `2026-08-29 CalCOFI Explorer UI …` (D11, D15, D16)
- scripps.ucsd.edu (HTML + six aggregated stylesheets, computed styles, three screenshots),
  brand.ucsd.edu (`logos-and-brand-elements/{color-palette,typography}`, `using-the-brand/web-and-digital`),
  calcofi.org (OceanWP + Elementor, Open Sans + Roboto, partner logos), fonts.googleapis.com (Source Sans 3
  v19, Teko), `curl -I calcofi.io/brand/v1/theme.css` (ACAO `*`)
- Gmail thread `1a03983b3c3cb52e`

---

## Execution log

**2026-08-30 — Phases 0–2 executed; nothing flipped.** Previews live for 9/3 → 9/8:
`https://calcofi.io/brand/v2/` (CalCOFI.github.io 440c254 + b987e32), `https://calcofi.io/v2/` (32ebc29),
`https://calcofi.io/explore/v2/` (explore 4cbdda1, 7c4db12, 3fab508). `check_brand.py --url` passes all four
checks on each at both themes; a fresh context opens light with no cookie written; `ccTheme.version === "2"`.

- **Phase 0.** As specified, with three measured departures: `--muted` is `#66686a` (the plan's `#6e7072` is
  4.38:1 on the Sand band); the font files are `SourceSans3-VF.woff2` / `SourceSans3-Italic-VF.woff2` /
  `Teko-VF.woff2` (brackets in a URL are a needless risk) and total 72 KB, not ~200; the long programme name
  under the wordmark was drawn (`build_lockup.py --long`) and rejected — illegible at 36 px, so the lockup is
  mark + wordmark. The specimen computes its table from `theme.css`: 42 pairs, minimum 4.56:1, all AA.
  `--cc-green` / `--cc-red` were added (the explorer's go / no-go states). HarfBuzz needs sfnt bytes — the
  woff2 is decompressed through fontTools first.
- **Phase 1.** Lighthouse accessibility 100 (both themes) after two fixes the audit forced: `demoted` cards
  dim the screenshot rather than the whole card (a 0.75 opacity took every word below AA), and prose links
  carry a faint underline (WCAG 1.4.1). Nav labels are short per section id ("Apps · Dataset apps · …": both
  Apps sections split to "Apps"). Partner logos are the three calcofi.org serves, resized into `images/partners/`.
- **Phase 2.** `VITE_BRAND` selects `brand/<v>.head.html` through a 6-line vite plugin; `src/brand.ts` carries
  the same choice into the header, the default theme and the capture. `verify.mjs` `v2_*` states pass;
  the full suite ran 100 states with one unrelated failure (`u2_prewarm` — stale since U7c's picker opens on
  the category tree; fails identically on v1). First paint on the production builds, three cold loads each:
  v1 2,090–2,322 ms, v2 2,079–2,280 ms. **11 px labels became 11.5 px** via `--fs-sm` in the app scale, decided
  from the specimen's rail sample (Source Sans 3's x-height). Two traps: html-to-image silently drops an
  `<img>` inside `<picture>` (the lockup vanished from the capture — now two `<img>`s + a media query, and
  the state asserts the mark's yellow pixels in the capture), and `theme.css`'s `.cc-header .cc-home img
  { display: block }` (0,2,1) outranks a two-class hide.
- **Left:** the ten decisions (ask Mark about the Brix Sans licence and the SIO lockup file); the flip; Phase 3
  (calcofi4r 1.15.0 first); Phase 4 (`check_brand.py` version + light-default + fonts + lockup; CLAUDE.md § brand).
