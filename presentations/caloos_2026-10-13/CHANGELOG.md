# CHANGELOG — CalOOS keynote slides, brand polish (2026-10-02)

Polish pass over the 21-slide draft (`2026-10-13_CalOOS_keynote_-_CalCOFI.io_slides.pptx`) using only
`brand/v2/` (theme.css tokens, Source Sans 3 + Teko, the horizontal lockups). Every slide, title, number,
URL, label and speaker note is unchanged — verified by diffing every text run and every notes page of the
polished deck against the draft (identical on all 21 slides). The deck is rebuilt as native shapes; nothing
was rasterised.

## Deck-wide

- **Type.** Titles are Teko, now rendered uppercase (the brand's display idiom) via PowerPoint's all-caps
  formatting, so the title text itself is untouched. Title size auto-fits: 40 pt where the title fits one
  line, 36/33 pt where it is longer, 32 pt on two lines (slide 3 only). Body is Source Sans 3 throughout;
  eyebrows are 11 pt bold uppercase with tracking, as `.cc-eyebrow`.
- **Smallest text is now 11 pt** (the draft had six 10.5 pt door sub-labels on slides 6–8 and 11.5 pt in
  the database block). Nothing sits off the slide.
- **Logo.** The draft carried the pre-September "CalCOFI" wordmark; replaced with the kit's current
  horizontal lockup (`logo_calcofi_h_light.svg` top-right on light slides, `logo_calcofi_h.svg` top-left
  on the two dark slides), rasterised at 2554 px wide.
- **Footer.** The heavy navy rule is now the brand's hairline footer rule (`--border`); link left in UCSD
  Blue, "CalOOS summit · 2026-10-13 · N" right in `--muted`. Content zone is 1.72 in–6.80 in on every
  light slide, so elements line up from slide to slide.
- **Bands and cards.** Content slides are white with full-width Sand bands (`.cc-band-alt`) where the
  draft used inset sand boxes; cards on a band are white, rounded (12 px), borderless, no shadow
  (`.cc-card`). The coloured top stripes on the slide-4 cards are gone.
- **One accent per slide.** Yellow appears at most once per slide: the kicker line on 1 and 21, the
  new-column marker on 5–8, the TRY IT chip on 11, 13–18. Nothing else is yellow.
- **Shadows and default theme effects removed** from every shape so the PNGs match PowerPoint.
- **PNGs** re-rendered at 1920 × 1080 with Source Sans 3 and Teko embedded (the draft's PNGs had fallen
  back to Arial).

## Per slide

1. **Title (dark).** Ground `#0F1A2E`, lockup top-left at 2.9 in. Kicker in yellow with tracking; title
   66 pt Teko uppercase on two lines; subtitle in Stone.
2. **Part 1 · Betty.** Full-width Sand band holds the PLACEHOLDER eyebrow and the two lines at 20 pt.
3. **Part 2 · Erin.** Two-line title. Sand band (starts a touch lower, 1.9 in, to clear the title) carries
   the eyebrow, "This is not the data. It is metadata." in 38 pt Teko and Erin's message in bold blue
   22 pt; her note and Ben's line sit below on white at 16 pt. Message intact.
4. **The FAIR vision.** Lede at 18 pt muted. Sand band with three white cards; the step number is 48 pt
   Teko in blue beside the step name in 28 pt Teko; body 15 pt. Stone arrows between cards. The rule
   sentence is 17 pt bold blue beneath the band. Top stripes (blue/yellow/blue) removed.
5–8. **The four build steps.** One diagram drawn four times; columns 1–3 are pixel-identical from slide
   to slide (checked by image diff), each slide adding only its new column and arrows. Rows tightened
   to a 0.70 in pitch so the sentence under the diagram has air. "Who" tiles Sand; door tiles white with
   a hairline border, name 13 pt bold blue, sub-label 11 pt muted; database block navy with "ONE
   DATABASE" in 30 pt Teko, the two counts at 18 pt bold, release line in the navy band's muted tone;
   portal tiles white, CalOOS the only blue-filled tile with white text. The yellow bar sits under the
   newest column, exactly one per slide. The one-sentence line under each diagram is 16 pt navy; on
   slide 8 it is "CalOOS links to the authoritative dataset. Nothing is copied." in 17 pt bold blue.
9. **The integrated database.** Sand band with six white tiles; numbers 60 pt Teko in blue (88 stays
   Gold), labels 15 pt. Release line and the frozen-and-fingerprinted sentence at 17/16 pt below the
   band, DOI in bold blue.
10. **Part 5 · Betty.** As slide 2.
11. **Explore 1/7.** Screenshot enlarged from 7.97 × 4.98 in to 8.13 × 5.08 in (full content height),
   hairline frame, header/release stamp/Controls/sentence all in frame. Caption 16 pt in two short
   paragraphs; yellow TRY IT chip with navy text and the URL in bold blue.
12. **Explore 2/7.** Wide capture kept full width; the two sentences now sit in two columns beneath it.
   (The thin white strip at the very top of the frame is in the capture itself.)
13–17. **Explore 3–7/7.** As slide 11. On 14 and 15 the TRY IT URL is long enough to wrap after
   `explore/?`; it stays at 14 pt rather than dropping below the 11 pt floor to fit one line.
18. **CTD Transects 1/2.** Capture enlarged to 6.41 × 5.08 in; three short paragraphs at 16 pt; TRY IT.
   The capture is cut at its right edge in the source image (the MAX slider and the baseline chip),
   which the RESHOOT line in the notes already covers.
19. **Before / after.** BEFORE · … and AFTER · … eyebrows kept; both captures enlarged to 5.92 × 3.18 in
   with hairline frames; caption 16 pt, "Red is warmer and blue colder than normal." in bold. The axis
   labels overlapping tick numbers are in the app's own captures, not the slide.
20. **The El Niño cruise.** Two Sand placeholder frames with a dashed Stone outline (so they read as
   placeholders), PLACEHOLDER SHOT eyebrow, 28 pt Teko frame title, 15 pt caption. "The El Niño cruise
   leaves 31 October." at 22 pt bold blue; the aim sentence at 17 pt.
21. **Closing (dark).** As slide 1; the five lines at 20 pt with the address/URL in bold white and the
   description after " · " in the dark band's muted tone — same text, two runs.

## Not changed on purpose

- Screenshots: same files as the draft, byte for byte; none cropped, recoloured or redrawn.
- Speaker notes, including every RESHOOT line.
- Slide count and order; the four build-step slides stay four slides with no animation.
