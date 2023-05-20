## Takes a CHM and makes a map of treetops

library(sf)
library(terra)
library(here)
library(tidyverse)
library(lidR)

data_dir = readLines(here("data_dir.txt"), n=1)

## Convenience functions ####
#source(here("scripts/convenience_functions.R"))

sites = c("crater", "valley", "chips", "delta")


#### START ####


for(site in sites) {
  
  ## Layers to process
  # plots_file = "surveys/crater/intermediate/crater_foc.geojson"
  # plot_buffer = 400
  focal_area_file = paste0("cross-site/boundaries/", site, ".gpkg")
  chm_file = paste0("cross-site/chms/", site, ".tif")
  treetop_out_file = paste0("cross-site/ttops/", site, ".gpkg")
  
  # focal_area = "boundaries/emerald-boundary-from-photos.gpkg"
  # chm_file = "chms/emerald-120m_20230401T2215_chm.tif"
  # treetop_out_file = "ttops/emerald-120m_20230401T2215_ttops.gpkg"
  # 
  
  focal_area = st_read(file.path(data_dir, focal_area_file))
  focal_area_inner = st_buffer(focal_area, -10) # to remove the edge trees
  
  # find the chm file
  chm = rast(file.path(data_dir, chm_file))
  
  
  # crop and mask it
  chm_crop = crop(chm,focal_area %>% st_transform(crs(chm)) %>% vect)
  chm_mask = mask(chm_crop,focal_area %>% st_transform(crs(chm)) %>% vect)
  chm = chm_mask
  
  cat("Fix extraneous vals")
  # if it's taller than 50, set to 50
  # chm[chm>55] = 55.1 ## need to set this larger for future projects probably
  chm[chm < 0] = -0.1
  
  
  chm_res = res(chm) %>% mean
  
  #resample coarser
  chm_coarse = project(chm, y = "epsg:3310", res = 0.25)
  
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
  
  writeRaster(chm_smooth, file.path(data_dir, "temp/chm.tif"), overwrite = TRUE)
  
  chm_smooth = raster::raster(file.path(data_dir, "temp/chm.tif"))
  chm_smooth = chm_smooth * 1
  
  treetops <- locate_trees(chm_smooth, lmf(ws = lin, shape = "circular", hmin = 5))
  gc()
  
  treetops = as(treetops,"sf")
  
  treetops = treetops |>
    rename(coarse_smoothed_chm_height = Z)
  
  # crop to the inner buffer
  treetops = st_intersection(treetops,focal_area_inner %>% st_transform(st_crs(treetops)))
  
  # pull the height from the highres unsmoothed CHM
  height = terra::extract(chm, treetops)[,2]
  treetops$highres_chm_height = height
  
  # pull the height from the coarse unsmoothed CHM
  height = terra::extract(chm_coarse, treetops)[,2]
  treetops$coarse_unsmoothed_chm_height = height
  
  
  # get the overall height as the max of the three
  treetops$Z = pmax(treetops$coarse_unsmoothed_chm_height, treetops$coarse_smoothed_chm_height, treetops$highres_chm_height)
  
  ## Save treetops
  st_write(treetops,file.path(data_dir, treetop_out_file), delete_dsn=TRUE, quiet=TRUE)
}

# ## Save buffer
# st_write(plots_buff, datadir("temp/plots_buff2.gpkg"))
