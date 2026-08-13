suppressPackageStartupMessages({
  library(dplyr); library(sf); library(ggplot2); library(calcofi4r); library(rnaturalearth)
})

# Venrick pooling regions, verbatim from definitions.xlsx sheet `Regions`
# (EDI knb-lter-cce.254.4), which cites Hayward & Venrick 1998.
regions <- tribble(
  ~region,    ~code,
  "NE",       c("83.41","83.51","87.40","90.30","90.37"),
  "SE",       c("93.30","93.40","93.50","93.60"),
  "Alley",    c("77.51","77.60","77.70","80.51","80.60","80.70","83.60","87.50","87.60","90.53"),
  "Offshore", c("77.80","80.80","83.70","83.80","83.90","87.70","87.80","87.90",
                "90.60","90.70","90.80","90.90","93.70","93.80","93.90")) |>
  tidyr::unnest(code)

# The sheet writes each station as a 2-digit line shorthand + station, e.g.
# "87.40" = line 86.7, station 40. cc_grid encodes the same lines as truncated
# INTEGERS (86, not 86.7), so map onto that rather than the decimal form the
# release `grid` table uses — the two are different encodings of one grid, and
# matching the wrong one silently drops most of the stations.
line_map <- c("77" = 76L, "80" = 80L, "83" = 83L, "87" = 86L, "90" = 90L, "93" = 93L)
regions <- regions |>
  mutate(line    = unname(line_map[sub("[.].*$", "", code)]),
         station = as.integer(sub("^.*[.]", "", code)))

g <- cc_grid |> mutate(line = as.integer(sta_lin), station = as.integer(sta_pos))
r <- regions |> left_join(st_drop_geometry(g) |> mutate(in_grid = TRUE) |>
                            select(line, station, sta_key, in_grid),
                          by = c("line", "station"))
cat("declared:", nrow(r), " resolving:", sum(!is.na(r$in_grid)), "\n")
cat("missing :", paste(r$code[is.na(r$in_grid)], collapse = ", "), "\n")

g_reg <- g |> inner_join(r |> filter(!is.na(in_grid)) |> select(sta_key, region), by = "sta_key")

coast <- ne_countries(scale = "medium", returnclass = "sf")
pal   <- c(NE = "#e8590c", SE = "#c2255c", Alley = "#1c7ed6", Offshore = "#2f9e44")

# zoom to the pooling regions, not to the whole 218-cell historical grid, which
# runs to 20°N / 135°W and would render these four regions as a smudge
bb <- st_bbox(g_reg)
pad_x <- 1.6; pad_y <- 1.0

# region labels: mean of the member cells' centroids. Deliberately NOT
# st_union() |> st_centroid() — the union of 28 grid polygons was pathologically
# slow here and buys nothing for a text anchor.
ctr <- suppressWarnings(st_coordinates(st_centroid(st_geometry(g_reg))))
lab <- st_drop_geometry(g_reg) |>
  mutate(x = ctr[, 1], y = ctr[, 2]) |>
  group_by(region) |> summarise(x = mean(x), y = mean(y), .groups = "drop")

n_miss <- r |> filter(is.na(in_grid)) |> count(region, name = "n_missing")
n_all  <- r |> count(region, name = "n_declared")
tally  <- n_all |> left_join(n_miss, by = "region") |>
  mutate(n_missing = coalesce(n_missing, 0L),
         lab = paste0(region, " ", n_declared - n_missing, "/", n_declared)) |>
  arrange(desc(n_missing), region)

p <- ggplot() +
  geom_sf(data = coast, fill = "#e9ecef", colour = "#adb5bd", linewidth = .3) +
  geom_sf(data = g, fill = "#f8f9fa", colour = "#dee2e6", linewidth = .2) +
  geom_sf(data = g_reg, aes(fill = region), colour = "white", linewidth = .4, alpha = .95) +
  geom_label(data = lab, aes(x, y, label = region, colour = region),
             fill = "white", alpha = .85, size = 3.5, fontface = "bold",
             label.size = 0, show.legend = FALSE) +
  scale_fill_manual(values = pal, guide = "none") +
  scale_colour_manual(values = pal, guide = "none") +
  coord_sf(xlim = c(bb["xmin"] - pad_x, bb["xmax"] + pad_x),
           ylim = c(bb["ymin"] - pad_y, bb["ymax"] + pad_y)) +
  labs(
    title    = "CalCOFI phytoplankton: the four Venrick pooling regions",
    subtitle = paste0(
      "Coloured cells are the ", sum(!is.na(r$in_grid)), " of ", nrow(r),
      " stations the source declares that resolve to a cell in the regularized\n",
      "CalCOFI grid (pale grey). Resolving per region — ",
      paste(tally$lab, collapse = ",  "), ".\n",
      "The six that do not resolve (", paste(r$code[is.na(r$in_grid)], collapse = ", "),
      ") are intermediate inshore\nstations outside the modern pattern. ",
      "NE is the problem case: 2 of its 5, so a hull over those two\nwould place NE materially wrong."),
    caption  = "Source: definitions.xlsx sheet `Regions`, EDI knb-lter-cce.254.4, citing Hayward & Venrick 1998 (Deep-Sea Res. 45: 1617-1638).") +
  theme_minimal(base_size = 11) +
  theme(axis.title    = element_blank(),
        plot.title    = element_text(face = "bold", size = 13),
        plot.subtitle = element_text(colour = "#495057", lineheight = 1.35, size = 9.5),
        plot.caption  = element_text(colour = "#868e96", hjust = 0, size = 8),
        panel.grid    = element_line(colour = "#f1f3f5"),
        plot.margin   = margin(12, 14, 10, 12))

out <- "docs/img/phyto_regions.png"
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
ggsave(out, p, width = 8, height = 8.6, dpi = 150, bg = "white")
cat("wrote", out, "\n")
