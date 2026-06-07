# build_status_and_relationships.R
# one-off authoring of metadata/relationships_cross.csv and metadata/dataset_status.csv.
# re-runnable. dates hardcoded (2026-06-07) for deterministic output.

suppressMessages({library(readr); library(tibble); library(here)})
today <- "2026-06-07"

# -- cross-dataset foreign keys (migrated verbatim from release_database.qmd YAML) --
rels_cross <- tribble(
  ~`table`,      ~column,      ~ref_table, ~ref_column, ~note,
  "casts",       "cruise_key", "cruise",   "cruise_key", "every bottle cast links to a cruise",
  "casts",       "ship_key",   "ship",     "ship_key",   "cast ship resolved to NODC ship",
  "casts",       "grid_key",   "grid",     "grid_key",   "cast spatial grid assignment",
  "ctd_cast",    "cruise_key", "cruise",   "cruise_key", "every CTD cast links to a cruise",
  "ctd_cast",    "ship_key",   "ship",     "ship_key",   "CTD ship resolved to NODC ship",
  "ctd_cast",    "grid_key",   "grid",     "grid_key",   "CTD spatial grid assignment",
  "dic_sample",  "cast_id",    "casts",    "cast_id",    "DIC matched to bottle cast via site_key + datetime (issue #47)",
  "dic_sample",  "bottle_id",  "bottle",   "bottle_id",  "DIC matched to nearest Niskin bottle by depth_m",
  "euphausiids_tow", "cruise_key", "cruise", "cruise_key", "tow cruise derived as YYYY-MM-{ship_nodc} (81.9% matched)",
  "euphausiids_tow", "ship_key",   "ship",   "ship_key",   "tow vessel resolved to NODC ship (98.3% matched)",
  "euphausiids_tow", "grid_key",   "grid",   "grid_key",   "tow spatial grid assignment",
  "zooplankton_tow", "cruise_key", "cruise", "cruise_key", "tow cruise derived as YYYY-MM-{ship_nodc} (66.6% matched)",
  "zooplankton_tow", "ship_key",   "ship",   "ship_key",   "tow vessel resolved to NODC ship",
  "zooplankton_tow", "grid_key",   "grid",   "grid_key",   "tow spatial grid assignment (98.7% in CalCOFI grid)",
  "bird_mammal_transect", "grid_key", "grid", "grid_key",   "transect-midpoint grid assignment (100% in CalCOFI grid)"
)
write_csv(rels_cross, here("metadata/relationships_cross.csv"), na = "")
cat("wrote", nrow(rels_cross), "cross-dataset FKs to metadata/relationships_cross.csv\n")

# -- dataset pipeline-stage tracker -------------------------------------------------
# stage = furthest stage reached: todo|explored|metadata|ingested|validated|published
# per-stage cells: done | wip | n/a | <blank> ; publish_* cells hold portal status or issue refs
st <- tribble(
  ~provider, ~dataset,      ~gh_issue, ~priority,        ~stage,      ~explore, ~metadata, ~ingest, ~validate, ~publish_obis, ~publish_erddap,        ~publish_edi, ~blockers,                                   ~updated,
  # ---- completed ingests ----
  "swfsc",   "ichthyo",     "",        "must-complete",  "published", "done",   "done",    "done",  "done",    "done",        "#38;#39;#40 planned",  "n/a",        "",                                          today,
  "calcofi", "bottle",      "",        "must-complete",  "ingested",  "done",   "done",    "done",  "done",    "n/a",         "#37 planned",          "n/a",        "",                                          today,
  "calcofi", "ctd-cast",    "",        "must-complete",  "ingested",  "done",   "done",    "done",  "done",    "n/a",         "#36 planned",          "n/a",        "",                                          today,
  "calcofi", "dic",         "#25",     "must-complete",  "validated", "done",   "done",    "done",  "done",    "n/a",         "#41 planned",          "n/a",        "spatial match only 24.7% (#47)",            today,
  "calcofi", "spatial",     "#54",     "should-complete","ingested",  "done",   "done",    "done",  "done",    "n/a",         "n/a",                  "n/a",        "GEBCO bathymetry layer pending (#54)",      today,
  "swfsc",   "invert",      "",        "must-complete",  "ingested",  "done",   "done",    "done",  "done",    "n/a",         "n/a",                  "n/a",        "folded into swfsc/ichthyo",                 today,
  # ---- pending must-complete ingests ----
  "cce-lter","euphausiids", "#26",     "must-complete",  "ingested",  "done",   "done",    "done",  "done",    "n/a",         "n/a",                  "#42 planned","ingested w/ provisional units+taxon (Q01/Q02); ship 98.3%/cruise 81.9% matched", today,
  "pic",     "zooplankton", "#27",     "must-complete",  "ingested",  "done",   "done",    "done",  "done",    "n/a",         "n/a",                  "#42 planned","tow registry ingested (99,530 CalCOFI-region tows); biovolume pending Q01", today,
  "calcofi", "phytoplankton","#28",    "must-complete",  "todo",      "",       "",        "",      "",        "n/a",         "n/a",                  "planned",    "BLOCKED: source not on Drive (Venrick, DataZoo+EDI multi-source not acquired)", today,
  "calcofi", "bird_mammal_census","#29","should-complete","ingested",  "done",   "done",    "done",  "done",    "#43 planned", "n/a",                  "planned",    "transect+obs+species+behavior (1987-2021, Sydeman/DataZoo255); covers seabird #29 + mammal #30", today,
  # ---- pending should-complete ingests ----
  "calcofi", "seabird",     "#29",     "should-complete","todo",      "",       "",        "",      "",        "#43 planned", "n/a",                  "planned",    "confirm provider/source; underway census",  today,
  "calcofi", "mammals",     "#30",     "should-complete","todo",      "",       "",        "",      "",        "#44 planned", "n/a",                  "planned",    "confirm provider (CCE-LTER); underway",     today,
  "calcofi", "zoodb",       "#31",     "should-complete","todo",      "",       "",        "",      "",        "n/a",         "n/a",                  "planned",    "DataZoo online DB API; holoplankton",       today,
  "calcofi", "zooscan",     "#32",     "should-complete","todo",      "",       "",        "",      "",        "n/a",         "n/a",                  "planned",    "ZooScan online DB; imagery counts",         today,
  "calcofi", "phyllosoma",  "#33",     "should-complete","todo",      "",       "",        "",      "",        "n/a",         "n/a",                  "planned",    "source/provider unknown; lobster larvae",   today,
  # ---- pending nice-to-have ingests ----
  "calcofi", "prodo",       "#34",     "nice-to-have",   "todo",      "",       "",        "",      "",        "n/a",         "planned",              "n/a",        "primary production",                        today,
  "swfsc",   "cufes",       "#35",     "nice-to-have",   "todo",      "",       "",        "",      "",        "n/a",         "#45 planned",          "n/a",        "underway fish-egg sampler; MET (#45) too",  today
)
write_csv(st, here("metadata/dataset_status.csv"), na = "")
cat("wrote", nrow(st), "dataset rows to metadata/dataset_status.csv\n")
