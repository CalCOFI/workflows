librarian::shelf(
  here, readr)
source(here("../apps/libs/db.R")) # defines variables: con, dir_gdrive

# 2022-10-10: + ctd_bottles.

# 2022-06-27: ctd_bottles.cst_cnt -> cast_count to match ctd_casts.*
q("ALTER TABLE ctd_bottles RENAME COLUMN cst_cnt TO cast_count")

# 2022-06-20: rename *species_codes* tables
#q("ALTER TABLE species_codes RENAME TO species_codes_old")
q("ALTER TABLE new_species_codes RENAME TO species_codes")

# 2022-06-20: + `species_groups` table
d_spp_grps <- read_csv(here("data/larvae/spp_grps.csv"))
d_spp      <- read_csv(here("data/larvae/spp.csv"))

d_grps <- d_spp_grps %>%
  rename(
    common_name_g = common_name) %>%
  left_join(
    d_spp %>%
      rename(
        spccode = calcofi_species_code),
    by = "scientific_name") %>%
  select(spp_group = group, spccode)

dbWriteTable(con, "species_groups", d_grps, overwrite=T)

# 2022-06-20: + larvae_counts.count into field_labels
read_csv("data/field_labels.csv") %>%
  filter(plot_title == "Larvae") %>%
  dbAppendTable(con, "field_labels", .)

# 2022-06-20: + stations.date for API /timeseries
q("ALTER TABLE tows ADD COLUMN date DATE")
q("UPDATE tows SET date = DATE(datetime)")

# 2022-06-19: + ctd_casts.geom for API timeseries/ to run spatial intersections
q("ALTER TABLE ctd_casts ADD COLUMN geom geometry(Point, 4326)")
q("UPDATE ctd_casts SET geom = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)")

# 2022-06-19: + stations.geom for oceano app
q("ALTER TABLE stations ADD COLUMN geom geometry(Point, 4326)")
q("UPDATE stations SET geom = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)")

