# Take a geospatial polygon and a folder of photos and subset the photos to those that fall within the polygon and save to a new folder

library(exifr)
library(tidyverse)
library(sf)

orig_photo_dir = "/ofo-share/dbh-completion_data/drone-imagery-base/nadir"
subset_photo_dir = "/ofo-share/dbh-completion_data/drone-imagery-prepped/nadir"

# orig_photo_dir = "/ofo-share/dbh-completion_data/drone-imagery-base/oblique-ns"
# subset_photo_dir = "/ofo-share/dbh-completion_data/drone-imagery-prepped/oblique-ns"

# orig_photo_dir = "/ofo-share/dbh-completion_data/drone-imagery-base/oblique-ew"
# subset_photo_dir = "/ofo-share/dbh-completion_data/drone-imagery-prepped/oblique-ew"


focal_polygon_path = "/ofo-share/dbh-completion_data/aois/ground_map_mask_precise.geojson"



photo_files = list.files(orig_photo_dir, full.names = TRUE, pattern = "JPG$", recursive = TRUE)

exif = read_exif(photo_files) |>
  select(SourceFile, GPSLatitude, GPSLongitude)

# find any images with the exact same coords (duplicated image) and delete the duplicate
dups = duplicated(exif |> select(GPSLatitude, GPSLongitude))

exif = exif[!dups,]

photos_sf = st_as_sf(exif, coords = c("GPSLongitude", "GPSLatitude"), crs = 4326)

# define the AOI to keep the images from: stem map buffered by 75 m
aoi = st_read(focal_polygon_path) |> st_transform(3310) |> st_buffer(75)

photos_intersect_index = st_intersects(photos_sf, aoi |> st_transform(st_crs(photos_sf)), sparse = FALSE)

photos_intersect = photos_sf[photos_intersect_index[,1],]

# # for oblique, thin to every other (i.e. reduce forward overlap)
# photos_intersect = photos_intersect[(1:(floor(nrow(photos_intersect)/2)))*2,]

# copy the subsetted photos to the output dir
for(i in 1:nrow(photos_intersect)) {
  
  source_file = photos_intersect[i, ]$SourceFile
  
  file_minus_orig_dir = str_replace(source_file, fixed(orig_photo_dir), replacement = "")
  dest_file = file.path(subset_photo_dir, file_minus_orig_dir)
  
  if(!(dir.exists(dirname(dest_file)))) dir.create(dirname(dest_file), recursive = TRUE)
  
  file.copy(source_file, dest_file, )
  
}

## Note that after exporting the clipped oblique-ns and oblique-ew, I then manually combined them into a folder called "oblique". I then also created a new folder called "composite" that combined the nadir and oblique.
