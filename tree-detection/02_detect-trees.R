## Takes a CHM and makes a map of treetops

library(sf)
library(terra)
library(here)
library(tidyverse)
library(lidR)



## Layers to process
# plots_file = "surveys/crater/intermediate/crater_foc.geojson"
# plot_buffer = 400
focal_area_file = "/ofo-share/dbh-completion_data/aois/ground_map_mask_precise.geojson"
chm_file = "/ofo-share/dbh-completion_data/tree-detection-products/composite_20230520T0519_chm.tif"
treetop_out_file = "/ofo-share/dbh-completion_data/tree-detection-products/composite_20230520T0519_ttops.gpkg"

# focal_area = "boundaries/emerald-boundary-from-photos.gpkg"
# chm_file = "chms/emerald-120m_20230401T2215_chm.tif"
# treetop_out_file = "ttops/emerald-120m_20230401T2215_ttops.gpkg"
# 

focal_area = st_read(focal_area_file) |> st_transform(3310) |> st_buffer(25)
focal_area_inner = st_buffer(focal_area, -10) # to remove the edge trees

# find the chm file
chm = rast(chm_file)


# crop and mask it
chm_crop = crop(chm,focal_area %>% st_transform(crs(chm)) %>% vect)
chm_mask = mask(chm_crop,focal_area %>% st_transform(crs(chm)) %>% vect)
chm = chm_mask

cat("Fix extraneous vals")
# if it's taller than 50, set to 50
# chm[chm>55] = 55.1 ## need to set this larger for future projects probably
chm[chm < 0] = -0.1


chm_res = res(chm) %>% mean

# #resample coarser : no longer doing this
# chm_coarse = project(chm, y = "epsg:3310", res = 0.25)
chm_coarse = chm

# apply smooth
smooth_size = 7
weights = matrix(1,nrow=smooth_size,ncol=smooth_size)
chm_smooth = focal(chm_coarse, weights, fun=mean)


cat("Detecting trees\n")

lin <- function(x){
  win = x*0.11 + 0
  win[win < 0.5] = 0.5
  win[win > 100] = 100
  return(win)
  } # window filter function to use in next step

# need to write to file so we can load with raster package so it gets stored in memory
writeRaster(chm_smooth, "/ofo-share/dbh-completion_data/tmp/chm.tif", overwrite = TRUE)

chm_smooth = raster::raster("/ofo-share/dbh-completion_data/tmp/chm.tif")
chm_smooth = chm_smooth * 1

treetops <- locate_trees(chm_smooth, lmf(ws = lin, shape = "circular", hmin = 5))
gc()

treetops = as(treetops,"sf")

treetops = treetops |>
  rename(coarse_smoothed_chm_height = Z)

# crop to the inner buffer
treetops = st_intersection(treetops,focal_area_inner %>% st_transform(st_crs(treetops)))

# pull the height from the highres unsmoothed CHM
height = terra::extract(chm, treetops |> st_transform(crs(chm)))[,2]
treetops$highres_chm_height = height

# pull the height from the coarse unsmoothed CHM
height = terra::extract(chm_coarse, treetops)[,2]
treetops$coarse_unsmoothed_chm_height = height


# get the overall height as the max of the three
treetops$Z = pmax(treetops$coarse_unsmoothed_chm_height, treetops$coarse_smoothed_chm_height, treetops$highres_chm_height)

## Save treetops
st_write(treetops,treetop_out_file, delete_dsn=TRUE, quiet=TRUE)

# ## Save buffer
# st_write(plots_buff, datadir("temp/plots_buff2.gpkg"))
