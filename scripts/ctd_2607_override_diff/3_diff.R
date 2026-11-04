# Dry-run diff for dropping the 2607 rows of metadata/calcofi/ctd-cast/flag_overrides.csv (2026-10-20).
# Run 1_emulate.R, 2_derived.R, 3_diff.R in order from the workflows checkout. CC_DIFF_DIR is a scratch
# directory holding the provider zip unzipped to $CC_DIFF_DIR/z2607/x/
# (gs://calcofi-files-public/_sync/calcofi/ctd-cast/download/20-2607SH_CTDPrelim.zip). The release side
# is read from v2026.10.19 over https. 1_emulate.R first reproduces the released 2607 obs_ctd_full with
# the override ON (0 value and 0 qual mismatches over 2,364,714 rows), then rebuilds it with the override
# OFF; 2_derived.R does the same for ctd-derived (sigma_theta_ave, spiciness0, MLDs); 3_diff.R prints the
# per-series rows changed / filled / removed and the largest change. calcofi4db is loaded with
# devtools::load_all(), never installed.
suppressMessages({library(dplyr); library(tidyr); library(readr); library(glue)})
S   <- Sys.getenv("CC_DIFF_DIR")
em <- readRDS(file.path(S, "emul_2607.rds")); rd <- readRDS(file.path(S, "released_2607_derived.rds"))
dd <- readRDS(file.path(S, "derived_2607.rds"))
thin <- rd$rel_obs |> filter(measurement_type == "temperature_ave") |> distinct(sample_key, depth_m)
agg <- function(x) x |> group_by(sample_key, depth_m, measurement_type) |>
  summarize(value = mean(value), qual = suppressWarnings(max(as.numeric(qual), na.rm = TRUE)), .groups = "drop") |>
  mutate(qual = ifelse(is.infinite(qual), NA_real_, qual))
a <- agg(em$on); b <- agg(em$off)
j <- full_join(a, b, by = c("sample_key", "depth_m", "measurement_type"), suffix = c(".on", ".off")) |>
  mutate(in_thin = paste(sample_key, depth_m) %in% paste(thin$sample_key, thin$depth_m),
         kind = case_when(is.na(value.on) & !is.na(value.off) ~ "filled",
                          !is.na(value.on) & is.na(value.off) ~ "removed",
                          abs(value.on - value.off) > 1e-9 ~ "value_changed",
                          (is.na(qual.on) != is.na(qual.off)) | (!is.na(qual.on) & !is.na(qual.off) & qual.on != qual.off) ~ "qual_only",
                          TRUE ~ "same"),
         d = value.off - value.on)
tab <- j |> filter(kind != "same") |> group_by(measurement_type) |>
  summarize(value_changed = sum(kind == "value_changed"), filled = sum(kind == "filled"), removed = sum(kind == "removed"),
            qual_only = sum(kind == "qual_only"), largest_abs_change = suppressWarnings(max(abs(d[kind == "value_changed"]), na.rm = TRUE)),
            in_published_thin = sum(in_thin & kind %in% c("value_changed", "filled", "removed")),
            n_casts = n_distinct(sample_key), .groups = "drop") |>
  mutate(largest_abs_change = ifelse(is.infinite(largest_abs_change), NA, round(largest_abs_change, 4)))
options(width = 250); print(as.data.frame(tab), row.names = FALSE)
write_csv(tab, file.path(S, "diff_ctd_cast_2607.csv"))
cat("\nrows by series that differ, totals: value_changed", sum(tab$value_changed), " filled", sum(tab$filled),
    " removed", sum(tab$removed), " qual_only", sum(tab$qual_only), "\n")
cat("casts touched:", paste(sort(unique(sub("calcofi_ctd-cast:cast:2607_", "", j$sample_key[j$kind != "same"]))), collapse = " "), "\n")
# ave rows by cast
print(j |> filter(measurement_type == "temperature_ave", kind != "same") |> count(sample_key, kind) |> as.data.frame())

# derived products
dcmp <- function(x, y, by) full_join(x, y, by = by, suffix = c(".on", ".off")) |>
  mutate(kind = case_when(is.na(value.on) & !is.na(value.off) ~ "filled", !is.na(value.on) & is.na(value.off) ~ "removed",
                          abs(value.on - value.off) > 1e-9 ~ "changed", TRUE ~ "same"), d = value.off - value.on)
bins_l <- bind_rows(lapply(c("sigma_theta_ave", "spiciness0"), function(t)
  list(on = dd$on$bins, off = dd$off$bins) |> (\(l) dcmp(transmute(l$on, sample_key, depth_m, measurement_type = t, value = .data[[t]]),
                                                     transmute(l$off, sample_key, depth_m, measurement_type = t, value = .data[[t]]),
                                                     c("sample_key", "depth_m", "measurement_type")))()))
bins_l <- bins_l |> mutate(in_thin = paste(sample_key, depth_m) %in% paste(thin$sample_key, thin$depth_m))
dtab <- bins_l |> filter(kind != "same") |> group_by(measurement_type) |>
  summarize(changed = sum(kind == "changed"), filled = sum(kind == "filled"), removed = sum(kind == "removed"),
            largest_abs_change = round(max(abs(d), na.rm = TRUE), 4),
            in_published_thin = sum(in_thin), n_casts = n_distinct(sample_key), .groups = "drop")
cat("\nDERIVED per-bin (full 1 m bins; in_published_thin = at depths in obs):\n"); print(as.data.frame(dtab), row.names = FALSE)
cst <- dcmp(rename(dd$on$cast, value = value) , dd$off$cast, c("sample_key", "measurement_type"))
ctab <- cst |> filter(kind != "same") |> group_by(measurement_type) |>
  summarize(changed = sum(kind == "changed"), filled = sum(kind == "filled"), removed = sum(kind == "removed"),
            largest_abs_change_m = round(max(abs(d), na.rm = TRUE), 3), n_casts = n_distinct(sample_key), .groups = "drop")
cat("\nDERIVED per-cast MLD:\n"); print(as.data.frame(ctab), row.names = FALSE)
print(cst |> filter(kind != "same") |> as.data.frame())
write_csv(dtab, file.path(S, "diff_derived_bins_2607.csv")); write_csv(ctab, file.path(S, "diff_derived_cast_2607.csv"))

# validation of derived ON against released
cat("\nVALIDATION derived ON vs release (thin depths):\n")
print(bins_l |> filter(in_thin) |> inner_join(rd$rel_obs |> rename(value.rel = value), by = c("sample_key", "depth_m", "measurement_type")) |>
  group_by(measurement_type) |> summarize(n = n(), mismatch_1e6 = sum(abs(value.on - value.rel) > 1e-6, na.rm = TRUE),
                                          max_abs = max(abs(value.on - value.rel), na.rm = TRUE)) |> as.data.frame())
print(dd$on$cast |> inner_join(rd$rel_cast |> rename(value.rel = value), by = c("sample_key", "measurement_type")) |>
  group_by(measurement_type) |> summarize(n = n(), mismatch_1e6 = sum(abs(value - value.rel) > 1e-6, na.rm = TRUE),
                                          max_abs = max(abs(value - value.rel), na.rm = TRUE)) |> as.data.frame())
