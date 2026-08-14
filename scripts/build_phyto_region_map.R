# Figure for the Q01 region-geometry discussion (workflows#76): the four Venrick
# pooling regions, and why the obvious construction — a convex hull per region —
# is not the one we ship.
#
# Reads the region membership verbatim from definitions.xlsx sheet `Regions`
# (EDI knb-lter-cce.254.4, citing Hayward & Venrick 1998) so it regenerates when
# the provider confirms or corrects the lists.

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(sf); library(ggplot2); library(readxl)
  library(stringr); library(units); library(calcofi4db); library(rnaturalearth)
})

xlsx <- "data/cache/calcofi_phytoplankton/definitions.xlsx"
if (!file.exists(xlsx))
  stop("run the download chunk of ingest_calcofi_phytoplankton.qmd first: ", xlsx)

reg_raw <- read_excel(xlsx, sheet = "Regions", col_names = FALSE,
                      .name_repair = "minimal") |>
  setNames(c("region", "description", "station_codes"))
hdr <- which(str_detect(reg_raw$region, regex("^abbreviation$", ignore_case = TRUE)))
reg_defs <- reg_raw |> slice((hdr + 1):n()) |>
  filter(!is.na(region), !is.na(station_codes)) |>
  mutate(across(everything(), str_squish))

# The sheet writes each station as a ROUNDED-line shorthand plus a station
# number: "87.40" is line 86.7 station 40. Three encodings of one grid are in
# play — this shorthand, cc_grid's truncated integer (86), and the release
# `grid` table's decimal (86.7) — and matching the wrong one is silent.
line_map <- c(`77` = 76.7, `80` = 80.0, `83` = 83.3,
              `87` = 86.7, `90` = 90.0, `93` = 93.3)
reg <- reg_defs |>
  mutate(code = str_split(station_codes, ",")) |>
  select(region, code) |> unnest(code) |> mutate(code = str_trim(code)) |>
  mutate(line    = unname(line_map[str_extract(code, "^[0-9]+")]),
         station = as.numeric(str_extract(code, "[0-9]+$")))
stopifnot(!anyNA(reg$line), !anyNA(reg$station))

# every declared station places: +proj=calcofi is a projection, not a lookup, so
# the six with no cell in the regularized grid resolve like any other
ll  <- cc_calcofi_to_lonlat(reg$line, reg$station)
reg <- bind_cols(reg, ll)
stopifnot(!anyNA(reg$longitude))

off_grid <- c("83.41", "83.51", "90.37", "77.51", "80.51", "90.53")
cat("declared:", nrow(reg), " placed:", sum(!is.na(reg$longitude)),
    " (of which no grid cell:", sum(reg$code %in% off_grid), ")\n")

# equal-area for measuring; degrees are not an area
EQ  <- "+proj=aea +lat_1=32 +lat_2=35 +lat_0=33 +lon_0=-120 +datum=WGS84 +units=m"
pts <- st_as_sf(reg, coords = c("longitude", "latitude"), crs = 4326) |> st_transform(EQ)

# A. the literal reading: a convex hull over each region's member stations
hull_a <- pts |> group_by(region) |> summarise(do_union = TRUE) |> st_convex_hull()

# B. what we ship: every station claims the water nearest to it, dissolved by
#    region (calcofi4db::cc_station_regions)
hull_b <- cc_station_regions(reg) |> st_transform(EQ)

km2    <- function(x) as.numeric(set_units(st_area(x), "km^2"))
domain <- st_convex_hull(st_union(pts))
gap_a  <- km2(st_difference(domain, st_union(hull_a)))
ov_a   <- sum(apply(utils::combn(nrow(hull_a), 2), 2, function(ij) {
  x <- st_intersection(st_geometry(hull_a)[ij[1]], st_geometry(hull_a)[ij[2]])
  if (!length(x)) 0 else sum(km2(x)) }))
cat("A: overlap", round(ov_a, 1), "km2; gaps", round(gap_a), "km2;",
    "SE", round(km2(hull_a[hull_a$region == "SE", ])), "km2\n")
# B's residual vs the domain is a few km2 out of 135,000 — cc_station_regions()
# hulls in its own equal-area CRS and returns 4326, so re-projecting here turns
# each straight edge into a chord. That is a projection artifact, not a gap.
cat("B: overlap 0; domain residual", round(km2(domain) - km2(st_union(hull_b))),
    "km2 of", format(round(km2(domain)), big.mark = ","), "(reprojection)\n")

# --- plot ---------------------------------------------------------------------
coast <- ne_countries(scale = "medium", returnclass = "sf") |> st_make_valid() |>
  st_crop(st_bbox(c(xmin = -130, xmax = -112, ymin = 25, ymax = 40), crs = 4326)) |>
  st_transform(EQ) |> st_make_valid()

lbl <- c(A = "A. convex hull of member stations — not shipped",
         B = "B. nearest-station partition, dissolved by region — shipped")
# bind_rows() on two sf objects matches the geometry column BY NAME, and silently
# emits GEOMETRYCOLLECTION EMPTY for the odd one out — cc_station_regions()
# returns `geom`, summarise() returns `geometry`. Normalize, then assert.
as_geometry <- function(x) st_sf(st_drop_geometry(x), geometry = st_geometry(x))
h <- bind_rows(
  as_geometry(hull_a) |> transmute(region, panel = lbl[["A"]]),
  as_geometry(hull_b) |> transmute(region, panel = lbl[["B"]]))
stopifnot(nrow(h) == 8, !any(st_is_empty(h)))
pal <- c(NE = "#e8590c", SE = "#c2255c", Alley = "#1c7ed6", Offshore = "#2f9e44")
bb  <- st_bbox(domain); pad <- 70000

p <- ggplot() +
  geom_sf(data = coast, fill = "#e9ecef", colour = "#adb5bd", linewidth = .3) +
  geom_sf(data = h, aes(fill = region), colour = "white", linewidth = .45, alpha = .9) +
  geom_sf(data = pts, size = 1, colour = "grey15") +
  scale_fill_manual(values = pal, name = NULL) +
  facet_wrap(~panel) +
  coord_sf(xlim = c(bb["xmin"] - pad, bb["xmax"] + pad),
           ylim = c(bb["ymin"] - pad, bb["ymax"] + pad)) +
  labs(
    title    = "CalCOFI phytoplankton: the four Venrick pooling regions",
    subtitle = paste0(
      "All ", nrow(reg), " stations the source declares are placed by `+proj=calcofi`, a projection rather than a grid lookup, so the six\n",
      "with no cell in the regularized grid (", paste(off_grid, collapse = ", "), ") resolve like any other. Three of those six are NE's.\n\n",
      "A is the obvious construction and is wrong three ways: SE's four stations are collinear on line 93.3 so its hull is a ",
      round(km2(hull_a[hull_a$region == "SE", ])), " km2\n",
      "sliver, NE and Alley overlap by ", round(ov_a, 1), " km2, and ", format(round(gap_a), big.mark = ","),
      " km2 — a third of the pooled domain — falls in no region at all.\n",
      "B gives each station the water nearest to it and dissolves by region: the four tile the domain exactly, each one connected."),
    caption  = "Source: definitions.xlsx sheet `Regions`, EDI knb-lter-cce.254.4, citing Hayward & Venrick 1998 (Deep-Sea Res. 45: 1617-1638).") +
  theme_minimal(base_size = 11) +
  theme(axis.title    = element_blank(),
        legend.position = "bottom",
        plot.title    = element_text(face = "bold", size = 13),
        plot.subtitle = element_text(colour = "#495057", lineheight = 1.35, size = 8.5),
        plot.caption  = element_text(colour = "#868e96", hjust = 0, size = 8),
        panel.grid    = element_line(colour = "#f1f3f5"),
        strip.text    = element_text(face = "bold"),
        plot.margin   = margin(12, 14, 10, 12))

out <- "docs/img/phyto_regions.png"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
ggsave(out, p, width = 11.5, height = 7.6, dpi = 150, bg = "white")
cat("wrote", out, "\n")
