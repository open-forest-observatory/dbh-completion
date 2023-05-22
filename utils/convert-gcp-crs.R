# convert a gcp table in lat/long to utm

library(sf)
library(terra)
library(dplyr)
library(tidyverse)


gcps = read.csv("/ofo-share/dbh-completion_data/drone-imagery-base/oblique-origcomb/gcps/prepared/gcp_table.csv", header = FALSE)

gcp_sf = st_as_sf(gcps, coords = c(2,3), crs = 4326) |> st_transform(26910)

coords = st_coordinates(gcp_sf)

gcp_sf$lon = coords[,1]
gcp_sf$lat = coords[,2]

st_geometry(gcp_sf) = NULL

gcp_sf = gcp_sf |>
  select(1,3,4,2)

write.csv(gcp_sf, "/ofo-share/dbh-completion_data/drone-imagery-base/oblique-origcomb/gcps/prepared/gcp_table_utm.csv", row.names = FALSE, col.names = NULL)         
