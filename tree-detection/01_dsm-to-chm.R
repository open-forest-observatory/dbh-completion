## Function to compare a drone map with a ground map and, ultimately, compare all drone maps in the directory with the ground map

library(tidyverse)
library(sf)
library(terra)
library(here)


# The root of the data directory
data_dir = readLines(here("data_dir.txt"), n=1)

#source(here("scripts/convenience_functions.R"))

#### Inputs ####

# Project area boundary
focal_area = st_read(file.path(data_dir, "boundaries/delta-boundary-from-photos.gpkg")) |> st_buffer(5)
# DTM
dtm = rast(file.path(data_dir, "str-disp_drone-data_imagery-processed/outputs/120m-01/DeltaB-120m_20230310T1701_dtm.tif"))
# DSM file
dsm = rast(file.path(data_dir, "str-disp_drone-data_imagery-processed/outputs/120m-01/DeltaB-120m_20230310T1701_dsm.tif"))

# Project area boundary
focal_area = st_read(file.path(data_dir, "boundaries/emerald-boundary-from-photos.gpkg"))
# DTM
dtm = rast(file.path(data_dir, "str-disp_drone-data_imagery-processed/outputs/flattened-120m/emerald-120m_20230401T2215_dtm.tif"))
# DSM file
dsm = rast(file.path(data_dir, "str-disp_drone-data_imagery-processed/outputs/flattened-120m/emerald-120m_20230401T2215_dsm.tif"))




# crop and mask DSM to project roi
dsm = crop(dsm, focal_area %>% st_transform(crs(dsm)))
dsm = mask(dsm,focal_area %>% st_transform(crs(dsm)))

dtm = crop(dtm, focal_area %>% st_transform(crs(dtm)))
dtm = mask(dtm,focal_area %>% st_transform(crs(dtm)))

# interpolate the the dtm to the res, extent, etc of the DSM
dtm_interp = project(dtm, dsm)


#### Calculate canopy height model ####
#### and save to tif

# calculate canopy height model
chm = dsm - dtm_interp

# downscale to 0.12 m
chm_proj = project(chm,y = "epsg:26910", res=0.12, method="bilinear")

# create dir if doesn't exist, then write
writeRaster(chm_proj,file.path(data_dir, "chms/emerald-120m_20230401T2215_chm.tif"), overwrite=TRUE) # naming it metashape because it's just based on metashape dsm (and usgs dtm) -- to distinguish from one generated from point cloud

gc()
