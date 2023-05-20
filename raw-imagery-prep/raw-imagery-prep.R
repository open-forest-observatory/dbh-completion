# Take a geospatial polygon and a folder of photos and subset the photos to those that fall within the polygon and save to a new folder

library(exifr)
library(tidyverse)
library(sf)

# orig_photo_dir = "/ofo-share/dbh-completion_data/drone-imagery-base/nadir"
# subset_photo_dir = "/ofo-share/dbh-completion_data/drone-imagery-prepped/nadir-v2"

# orig_photo_dir = "/ofo-share/dbh-completion_data/drone-imagery-base/oblique-ns"
# subset_photo_dir = "/ofo-share/dbh-completion_data/drone-imagery-prepped/oblique-ns-v2"
# 
# orig_photo_dir = "/ofo-share/dbh-completion_data/drone-imagery-base/oblique-ew"
# subset_photo_dir = "/ofo-share/dbh-completion_data/drone-imagery-prepped/oblique-ew-v2"
# 
orig_photo_dir = "/ofo-share/dbh-completion_data/drone-imagery-base/oblique-origcomb"
subset_photo_dir = "/ofo-share/dbh-completion_data/drone-imagery-prepped/oblique-v3"
gcps_path = "/ofo-share/dbh-completion_data/drone-imagery-base/oblique-origcomb/gcps/prepared/gcp_imagecoords_table.csv"


focal_polygon_path = "/ofo-share/dbh-completion_data/aois/ground_map_mask_precise.geojson"



photo_files = list.files(orig_photo_dir, full.names = TRUE, pattern = "JPG$", recursive = TRUE)

exif = read_exif(photo_files)

exif_simp = exif |>
  select(SourceFile, GPSLatitude, GPSLongitude)

# find any images with the exact same coords (duplicated image) and delete the duplicate
dups = duplicated(exif |> select(GPSLatitude, GPSLongitude))

# also find which images are used for GCPs
gcps = read.csv(gcps_path, header = FALSE)

#

exif_keep = exif_simp[!dups,]

photos_sf = st_as_sf(exif_keep, coords = c("GPSLongitude", "GPSLatitude"), crs = 4326)

img_has_gcp = sapply(photos_sf$SourceFile, function(x) any(sapply(gcps$V2, str_detect, string = fixed(x))))

# define the AOI to keep the images from: stem map buffered by 75 m
aoi = st_read(focal_polygon_path) |> st_transform(3310) |> st_buffer(75)

photos_intersect_index = st_intersects(photos_sf, aoi |> st_transform(st_crs(photos_sf)), sparse = FALSE)

# for oblique
photos_intersect = photos_sf[photos_intersect_index[,1] | img_has_gcp,]
# for nadir
photos_intersect = photos_sf[photos_intersect_index[,1],]


# for oblique, thin to every other (i.e. reduce forward overlap)
photos_thinned = photos_intersect[(1:(floor(nrow(photos_intersect)/2)))*2, ]
photos_gcps = photos_sf[img_has_gcp, ]
photos_keep = bind_rows(photos_thinned, photos_gcps)
photos_keep = photos_keep[!duplicated(photos_keep), ]

# for nadir
photos_keep = photos_intersect

# copy the subsetted photos to the output dir
for(i in 1:nrow(photos_keep)) {
  
  source_file = photos_keep[i, ]$SourceFile
  
  file_minus_orig_dir = str_replace(source_file, fixed(orig_photo_dir), replacement = "")
  dest_file = file.path(subset_photo_dir, file_minus_orig_dir)
  
  if(!(dir.exists(dirname(dest_file)))) dir.create(dirname(dest_file), recursive = TRUE)
  
  file.copy(source_file, dest_file, )
  
}

## Note that after exporting the clipped oblique-ns and oblique-ew, I then manually combined them into a folder called "oblique". I then also created a new folder called "composite" that combined the nadir and oblique.
