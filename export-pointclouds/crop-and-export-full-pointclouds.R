# Take the pointclouds, crop to focal area (stem map + 25 m), save as laz

library(lidR)
library(sf)

focal_area = st_read("/ofo-share/dbh-completion_data/aois/ground_map_mask_precise.geojson") |> st_transform(3310) |> st_buffer(25)

cloud = readLAS("/ofo-share/dbh-completion_data/metashape-outputs/compositeMildfilt_20230521T0024_points.las")

focal_area = st_transform(focal_area,crs(cloud))

cloud_crop = clip_roi(cloud, focal_area)

writeLAS(cloud_crop, "/ofo-share/dbh-completion_data/point-clouds-cropped/full-landscape/compositeMildfilt_20230521T0024_points.laz")







focal_area = st_read("/ofo-share/dbh-completion_data/aois/ground_map_mask_precise.geojson") |> st_transform(3310) |> st_buffer(25)

cloud = readLAS("/ofo-share/dbh-completion_data/metashape-outputs/compositeHighres_20230521T0023_points.las")

focal_area = st_transform(focal_area,crs(cloud))

cloud_crop = clip_roi(cloud, focal_area)

writeLAS(cloud_crop, "/ofo-share/dbh-completion_data/point-clouds-cropped/full-landscape/compositeHighres_20230521T0023_points.laz")







focal_area = st_read("/ofo-share/dbh-completion_data/aois/ground_map_mask_precise.geojson") |> st_transform(3310) |> st_buffer(25)

cloud = readLAS("/ofo-share/dbh-completion_data/metashape-outputs/compositeMildfiltHighresNousgs_20230521T1723_points.las")

focal_area = st_transform(focal_area,crs(cloud))

cloud_crop = clip_roi(cloud, focal_area)

writeLAS(cloud_crop, "/ofo-share/dbh-completion_data/point-clouds-cropped/full-landscape/compositeMildfiltHighresNousgs_20230521T1723_points.laz")





focal_area = st_read("/ofo-share/dbh-completion_data/aois/ground_map_mask_precise.geojson") |> st_transform(3310) |> st_buffer(25)

cloud = readLAS("/ofo-share/dbh-completion_data/metashape-outputs/compositeMildfiltMedres_20230521T1723_points.las")

focal_area = st_transform(focal_area,crs(cloud))

cloud_crop = clip_roi(cloud, focal_area)

writeLAS(cloud_crop, "/ofo-share/dbh-completion_data/point-clouds-cropped/full-landscape/compositeMildfiltMedres_20230521T1723_points.laz")






focal_area = st_read("/ofo-share/dbh-completion_data/aois/ground_map_mask_precise.geojson") |> st_transform(3310) |> st_buffer(25)

cloud = readLAS("/ofo-share/dbh-completion_data/metashape-outputs/oblique_20230521T0021_points.las")

focal_area = st_transform(focal_area,crs(cloud))

cloud_crop = clip_roi(cloud, focal_area)

writeLAS(cloud_crop, "/ofo-share/dbh-completion_data/point-clouds-cropped/full-landscape/oblique_20230521T0021_points.laz")








cloud = readLAS("/ofo-share/dbh-completion_data/metashape-outputs/nadir_20230519T2355_points.las")

focal_area = st_transform(focal_area,crs(cloud))

cloud_crop = clip_roi(cloud, focal_area)

writeLAS(cloud_crop, "/ofo-share/dbh-completion_data/point-clouds-cropped/full-landscape/nadir_20230519T2355_points.laz")
