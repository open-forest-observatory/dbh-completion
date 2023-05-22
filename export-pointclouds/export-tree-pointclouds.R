# Take the landscape pointclouds and crop them to specific trees

library(lidR)
library(sf)
library(tidyverse)


trees_foc = c(390, 468, 395, 292, 390, 260, 538, 224, 641, 380, 425, 324, 452, 673, 611, 500, 486, 660, 515, 269)

crowns = st_read("/ofo-share/dbh-completion_data/tree-map-comparison-outputs/detected-crowns-w-field-data.gpkg")

cloud_path = "/ofo-share/dbh-completion_data/point-clouds-cropped/full-landscape/composite_20230520T0519_points.laz"
cloud_path = "/ofo-share/dbh-completion_data/point-clouds-cropped/full-landscape/nadir_20230519T2355_points.laz"
cloud_path = "/ofo-share/dbh-completion_data/point-clouds-cropped/full-landscape/compositeMildfilt_20230521T0024_points.laz"
cloud_path = "/ofo-share/dbh-completion_data/point-clouds-cropped/full-landscape/compositeHighres_20230521T0023_points.laz"
cloud_path = "/ofo-share/dbh-completion_data/point-clouds-cropped/full-landscape/oblique_20230521T0021_points.laz"
cloud_path = "/ofo-share/dbh-completion_data/point-clouds-cropped/full-landscape/compositeMildfiltHighresNousgs_20230521T1723_points.laz"
cloud_path = "/ofo-share/dbh-completion_data/point-clouds-cropped/full-landscape/compositeMildfiltMedres_20230521T1723_points.laz"

out_cloud_path = "/ofo-share/dbh-completion_data/point-clouds-cropped/individual-trees"


cloud = readLAS(cloud_path)

cloud_name = cloud_path |> basename() |> tools::file_path_sans_ext()

crowns = st_transform(crowns, crs(cloud))

# Go through each tree and crop and save

for(i in 1:length(trees_foc)) {
  
  tree_foc = trees_foc[i]
  
  crown_foc = crowns |> filter(predicted_tree_id == tree_foc) 
  
  # buffer by 1 m
  crown_foc = crown_foc |> st_transform(3310) |> st_buffer(1)
  
  sp_foc = crown_foc$observed_species
  
  if(is.na(sp_foc)) sp_foc = "XXXX"
  
  crown_foc = st_transform(crown_foc, crs(cloud))
  
  cloud_cropped = clip_roi(cloud, crown_foc)
  
  filename_write = paste0(cloud_name, "-tree_", tree_foc, "_", sp_foc, ".laz")
  
  path_write = file.path(out_cloud_path, filename_write)
  
  writeLAS(cloud_cropped, path_write)
  
}
