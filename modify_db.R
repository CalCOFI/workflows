source(here::here("libs/db.R")) # defines variables: con, dir_gdrive

# 2022-06-19: + ctd_casts.geom for API timeseries/ to run spatial intersections
dbSendQuery(con,
  "ALTER TABLE ctd_casts ADD COLUMN geom geometry(Point, 4326)")
dbSendQuery(con,
  "UPDATE ctd_casts SET geom = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)")

