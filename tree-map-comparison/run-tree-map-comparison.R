library(sf)
library(tidyverse)
library(here)
library(furrr)

## Function definitions
source("tree-map-comparison/lib/prep-tree-maps.R")
source("tree-map-comparison/lib/match-trees.R")
source("tree-map-comparison/lib/tree-det-stats.R")
source("tree-map-comparison/lib/connect-matches.R")
source("tree-map-comparison/lib/area-based-stats.R")
source("tree-map-comparison/lib/combine-stats-make-corr-plots.R")

# Path to the observed (reference) stem map. It is assumed that this stem map includes exhaustive survey of trees with heights down to 50% of the minimum height class evaluated (currently hard-coded at 10 m, so heights down to at least 5 m). If the dataset has smaller trees, removing them first will make this run faster.
#    If you wish to include matching for "overstory trees only", this stem map should be pre-attributed with a column called "under-neighbor" that indicates whether a tree is understory or overstory.
#    This attribution is performed by the script scripts/ground_stem_map_assign_under_neighbor.R
observed_trees_filepath = "/ofo-share/dbh-completion_data/ground-truth-stem-map/rectified/ept_trees_01_rectified.geojson"
# Path to the field plot boundary. This defines the outer edge of the field (observed trees) plot. It is assumed that the predicted tree stem map extends at least to this boundary if not beyond.
plot_bound_filepath =  "/ofo-share/dbh-completion_data/aois/ground_map_mask_precise.geojson"

# Location of temp directory (holds intermediate files between the comparison steps) and the directory for comparison outputs
tmp_dir = "/ofo-share/dbh-completion_data/tmp"
output_dir = "/ofo-share/dbh-completion_data/tree-map-comparison-outputs"

# Location of the predicted tree maps to evaluate
predicted_trees_path = "/ofo-share/dbh-completion_data/tree-detection-products"

INTERNAL_BUFFER_DIST = 10 # By how many meters to buffer in from the plot edge when computing precision and recall to ensure all predicted trees have a fair chance to match to an observed tree and vice-versa

# Maximum number of predicted trees, beyond which consider it an extremely poor tree detection and skip it
MAX_PREDICTED_TREES = 50000


#### BEGIN STEM MAP COMPARISON WORKFLOW ####


# Make a new observed trees file that can be overwritten and used
obs_trees = st_read(observed_trees_filepath)
obs_trees_path = dirname(observed_trees_filepath)
observed_trees_filepath = file.path(obs_trees_path, "ground_map_mask_precise_forcomp.gpkg")
st_write(obs_trees, observed_trees_filepath, delete_dsn = TRUE)

# Prepare the observed tree dataset for comparison by adding the necessary attributes (including: whether in internally buffered area, which predicted tree the observed tree is matched to) and projecting the predicted tree dataset to the observed tree dataset
# This function saves the prepared tree dataset back to its original filename
prep_observed_tree_map_for_comparison(observed_trees_filepath = observed_trees_filepath,
                                      plot_bound_filepath =  plot_bound_filepath,
                                      internal_plot_buffer_dist = INTERNAL_BUFFER_DIST) # By how many meters to buffer in from the plot edge when computing precision and recall to ensure all predicted trees have a fair chance to match to an observed tree


# Open the observed trees to see how many there are overall and in the internal area (used to exclude predicted tree sets if there are many more predicted than observed trees)
observed_trees = st_read(observed_trees_filepath)
observed_trees_internal = observed_trees[observed_trees$internal_area == TRUE, ]



## Function to evaluate one predicted treetop set (to parallelize)

eval_one_predicted_set = function(predicted_trees_filepath) {
  
  cat(" Evaluating", predicted_trees_filepath, "*******\n                                  ")
  
  ## Check if already exists
  predicted_tree_dataset_name = tools::file_path_sans_ext(basename(predicted_trees_filepath))
  output_filename = paste0("stats_",predicted_tree_dataset_name,".csv")
  # Create alternate filename that is used as a placholeder when we don't actually process the dataset, to mark that we condiered processing it and decided to skip it (so when we rerun, we don't try again)
  output_filename_placeholder = paste0("stats_",predicted_tree_dataset_name,".placeholder_txt")
  output_filepath = paste0(output_dir, "/tree_detection_evals/", output_filename)
  output_filepath_placeholder = paste0(output_dir, "/tree_detection_evals/", output_filename_placeholder)
  
  if(file.exists(output_filepath) | file.exists(output_filepath_placeholder)) {
    cat("Stats file already exists:", output_filepath, ", skipping.\n")
    return(TRUE)
  }
  
  
  ### Check for a reasonable number of predicted trees and skip if unreasonable
  
  ## How many predicted trees are there? Reject sets where there are way too many
  predicted_trees = st_read(predicted_trees_filepath)
  
  # If there is > MAX_PREDICTED_TREES, it's an unrealistic tree detection; skip
  if(nrow(predicted_trees) > MAX_PREDICTED_TREES) {
    cat("@@@@@@ Over", MAX_PREDICTED_TREES, "predicted trees. Skipping. @@@@@@\n")
    write_file("Placeholder text", output_filepath_placeholder)
    return(FALSE)
  }
  
  # Prepare the predicted tree dataset for comparison by adding the necessary attributes (including: whether in internally buffered area, which predicted tree the observed tree is matched to) and projecting the predicted tree dataset to the observed tree dataset
  # This function saves the prepared tree dataset back to its original filename
  prep_predicted_tree_map_for_comparison(predicted_trees_filepath = predicted_trees_filepath,
                                         plot_bound_filepath =  plot_bound_filepath,
                                         internal_plot_buffer_dist = INTERNAL_BUFFER_DIST) # By how many meters to buffer in from the plot edge when computing precision and recall to ensure all predicted trees have a fair chance to match to an observed tree
  
  
  ### Check for a reasonable number of predicted trees and skip if unreasonable
  
  ## How many predicted trees are there? Reject sets where there are way too many
  predicted_trees = st_read(predicted_trees_filepath)
  predicted_trees_internal = predicted_trees[predicted_trees$internal_area == TRUE, ]
  
  # How many times more predicted trees then observed trees are there?
  overprediction_factor = nrow(predicted_trees_internal) / nrow(observed_trees_internal)
  
  # If overpredicting by a factor of 8 or more, skip (trying to compute accuracy for huge ttop datasets is very slow)
  if(overprediction_factor > 8) {
    cat("@@@@@@ Too many trees predicted (overprediction factor: ", overprediction_factor, "). Skipping. @@@@@@\n")
    write_file("Placeholder text", output_filepath_placeholder)
    return(FALSE)
  }
  
  # If underpredicting by a factor of 0.05 or smaller, skip (functions don't work when there are no trees)
  if(overprediction_factor < 0.05) {
    cat("@@@@@@ Too few trees predicted (overprediction factor: ", overprediction_factor, "). Skipping. @@@@@@\n")
    write_file("Placeholder text", output_filepath_placeholder)
    return(FALSE)
  }
  
  
  # This function saves (in tmp_dir) a gpkg of the observed trees, with a column indicating which predicted tree (if any) it was matched to
  match_trees(observed_trees_filepath = observed_trees_filepath,
              predicted_trees_filepath = predicted_trees_filepath,
              tmp_dir = tmp_dir,
              search_height_proportion = 0.5, # Within what fraction (+ or -) of the observed tree height is a predicted tree allowed to match
              additional_overstory_comparison = TRUE, # In addition to comparing against *all* observed trees, should we compare against *overstory trees only*. If so, the observed trees stem map file needs to have an attribute "under_neighbor" previously assigned by the script scripts/ground_stem_map_assign_under_neighbor.R
              search_distance_fun_slope = 0.1, # The slope of the linear function for relating observed tree height to the potential matching distance
              search_distance_fun_intercept = 1)  # The intercept of the linear function for relating observed tree height to the potential matching distance
  
  # This function saves individual tree detection accuracy statistics (sensitivity, precision, F-score, etc) in tmp_dir
  tree_det_stats(predicted_trees_filepath = predicted_trees_filepath,
                 tmp_dir = tmp_dir,
                 output_dir = output_dir)
  
  # This function saves area-based accuracy statistics in tmp_dir
  area_based_stats(observed_trees_filepath = observed_trees_filepath,
                   predicted_trees_filepath = predicted_trees_filepath,
                   focal_region_polygon_filepath = plot_bound_filepath,
                   tmp_dir = tmp_dir,
                   virtual_plot_size = 30, # The height and width of contiguous square grid cells laid over the field plot for computing area-based statistics
                   additional_overstory_comparison = TRUE) # In addition to comparing against *all* observed trees, should we compare against *overstory trees only*. If so, the observed trees stem map file needs to have an attribute "under_neighbor" previously assigned by the script scripts/ground_stem_map_assign_under_neighbor.R
  
  # This function combines the individual tree detection and area-based accuracy statistics and saves in output_dir/tree_detection_evals
  combine_stats(tmp_dir = tmp_dir,
                output_dir = output_dir,
                predicted_trees_filepath = predicted_trees_filepath)
  
  # This function compares the heights of paired predicted and observed trees and makes a height correspondence scatterplot and saves it in output_dir/correlation_figures
  make_height_corr_plots(output_dir = output_dir,
                         predicted_trees_filepath = predicted_trees_filepath)
  
  # This function draws lines to connect paired ground and drone trees
  connect_matches(tmp_dir = tmp_dir,
                 output_dir = output_dir,
                 predicted_trees_filepath = predicted_trees_filepath)
  
  
}


predicted_ttop_files = list.files(predicted_trees_path, full.names = TRUE, pattern = "ttops\\.gpkg$")

plan(multisession)
furrr_options(scheduling = Inf)
future_walk(predicted_ttop_files, eval_one_predicted_set)

