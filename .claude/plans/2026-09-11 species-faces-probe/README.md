# Species faces — the 2026-09-11 probe

What the mockup *CalCOFI Species Faces* (https://claude.ai/code/artifact/34135a47-7597-41af-ad58-5328bde815dd) was built from, kept so the
fetcher (WS-F2a) and the page (WS-F3) start from measured material. Umbrella plan: `../2026-09-11 Species faces — … agent-scaled.md`.

- `fetch_media.py` — one pass over 12 taxa × WoRMS (record, attributes) · PhyloPic by WoRMS id · Wikidata SPARQL (P850) · Wikipedia summary · Commons extmetadata · iNaturalist taxa · GBIF occurrence media → `species_media_sample.json` (raw, includes the PhyloPic SVGs).
- `phylopic_names.py` — PhyloPic by name with a walk up the lineage (the id route resolved 4 of 12; this resolves all) → `phylopic_by_name.json` (not kept; rerun).
- `silhouettes.json` — the cleaned silhouettes (`fill="currentColor"`, viewBox, aspect) with `image_uuid`, contributor, licence, `image_of`, `steps_up`.
- `cast_record.json` — the cast's entries of the release's `taxa.json` (v2026.09.06). `cast.txt` — the ten taxon keys, for `--only`.
- `build.py` + `species_faces.template.html` — the mockup builder (needs `photos2.json`, the base64 thumbnails, not kept: rerun the encode step in `photos.txt` order). `cast_data.json` — the assembled cast (sizes, early-life lengths, links, blurbs).
- `make_fixture.py` → **`taxa_media.sample.json`** — the sidecar in the plan's Appendix A shape for the ten taxa, URLs instead of cached files. WS-F3 and WS-F4 build against this until the real one exists.

Sizes in `cast_data.json` came from WoRMS attributes (fishes, dolphin), SeaLifeBase (krill, squid) and FishBase `eggs`/`larvae` (refs 265, 6879, 31442); see the plan's § Context and Appendix C.
