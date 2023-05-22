## Takes ttops and a CHM and makes a map of tree crowns (TAOs)

library(sf)
library(terra)
library(here)
library(tidyverse)
library(lidR)
library(nngeo)
library(smoothr)

chm_file = "/ofo-share/dbh-completion_data/tree-detection-products/composite_20230520T0519_chm.tif"
treetop_file = "/ofo-share/dbh-completion_data/tree-detection-products/composite_20230520T0519_ttops.gpkg"
tao_out_file = "/ofo-share/dbh-completion_data/tree-detection-products/composite_20230520T0519_crowns.gpkg"

focal_area_file = "/ofo-share/dbh-completion_data/aois/ground_map_mask_precise.geojson"

chm = rast(chm_file)
ttops = st_read(treetop_file)
#st_crs(ttops) = 26910

# create mask so we only keep the CHM from around treetops (speeds up processing?)
mask_poly = st_buffer(ttops, 30) |> st_union() |> st_transform(crs(chm))
chm = mask(chm, vect(mask_poly))
  
taos = silva2016(chm, ttops |> st_transform(crs(chm)), max_cr_factor = 0.24, exclusion = 0.1)()

taos <- as.polygons(taos)
taos <- st_as_sf(taos)
taos <- st_cast(taos, "MULTIPOLYGON")
taos <- st_cast(taos, "POLYGON")
taos <- st_remove_holes(taos)
taos <- st_make_valid(taos)
taos <- smooth(taos, method = "ksmooth", smoothness = 3)
taos <- st_simplify(taos, preserveTopology = TRUE, dTolerance = 0.1)

# assign TAOs the treetop height and remove those that have no treetops in them
taos = st_join(taos, ttops |> st_transform(st_crs(taos)))
taos = taos[,-1]
taos = taos[!is.na(taos$Z),]

# remove crowns that fall outside the buffer
focal_area = st_read(focal_area_file) |> st_transform(3310) |> st_buffer(25)
focal_area_inner = st_buffer(focal_area, -10) # to remove the edge trees
focal_area_line = st_cast(focal_area_inner, "MULTILINESTRING")

taos_intersect = st_intersects(taos,focal_area_line |> st_transform(st_crs(taos)), sparse = FALSE)
taos = taos[!taos_intersect[,1],]

st_write(taos, tao_out_file, delete_dsn = TRUE)

