# Take the predicted trees gpkg and pull in the ground-based survey data

library(sf)
library(tidyverse)

trees_pred = st_read("/ofo-share/dbh-completion_data/tree-detection-products/composite_20230520T0519_ttops.gpkg")
crowns_pred = st_read("/ofo-share/dbh-completion_data/tree-detection-products/composite_20230520T0519_crowns.gpkg")

pairings = read_csv("/ofo-share/dbh-completion_data/tree-map-comparison-outputs/matched_tree_lists/trees_matched_composite_20230520T0519_ttops_all.csv") |>
  select(predicted_tree_id, observed_tree_id)

field_data = st_read("/ofo-share/dbh-completion_data/ground-truth-stem-map/rectified/ground_map_mask_precise_forcomp.gpkg") |>
  select(observed_tree_id, observed_height = Height, observed_dbh = DBH, observed_species = Species, observed_status = Status, observed_ht_to_crown = Height_to_crown, observed_health_1 = Health_1, observed_health_2 = Health_2, observed_health_3= Health_3, )

st_geometry(field_data) = NULL


trees_pred = trees_pred |>
  select(predicted_tree_id, predicted_height = height)

trees_pred = trees_pred |>
  left_join(pairings) |>
  left_join(field_data)

st_write(trees_pred, "/ofo-share/dbh-completion_data/tree-map-comparison-outputs/detected-ttops-w-field-data.gpkg", delete_dsn = TRUE)

# add the same info to the crowns
crowns_pred = select(crowns_pred, )
crowns_pred = st_join(crowns_pred, trees_pred |> st_transform(st_crs(crowns_pred)))

st_write(crowns_pred, "/ofo-share/dbh-completion_data/tree-map-comparison-outputs/detected-crowns-w-field-data.gpkg", delete_dsn = TRUE)
