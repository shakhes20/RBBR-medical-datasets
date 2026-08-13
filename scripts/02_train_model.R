#############################################################################
# 02_train_model.R
#
# Purpose:
#   Run k-fold cross-validated training of an RBBR (Boolean Rule-aware
#   Regression) model on a preprocessed dataset (output of
#   01_preprocessing.R), using the published RBBR package. Saves, per
#   fold: the trained model object, its extracted Boolean rules, and the
#   train/test row indices (for reproducibility and use by
#   03_evaluate_results.R).
#
# Usage:
#   1. Run 01_preprocessing.R first (or point processed_data_path at any
#      CSV that already has predictors in [0,1] and target as the last
#      column).
#   2. Edit the CONFIG section only.
#   3. Run: Rscript scripts/02_train_model.R
#############################################################################

## ------------------------------------------------------------------------
## CONFIG -- edit this section only
## ------------------------------------------------------------------------

# Path to the cleaned, scaled dataset (output of 01_preprocessing.R)
processed_data_path <- "data/processed/dataset1_clean.csv"

# Short name used to label saved outputs for this dataset (no spaces)
dataset_name <- "dataset1"

# Directory where per-fold trained models / rules / fold indices are written
model_output_dir <- "results/models"

# Cross-validation setup
num_folds <- 5
random_seed <- 42

# RBBR hyperparameters (see ?rbbr_train)
rbbr_max_feature <- 3          # max number of features combined per Boolean rule
rbbr_mode <- "1L"              # "1L" (1-layer) or "2L" (2-layer) rules
rbbr_slope <- 10                # sigmoid slope
rbbr_weight_threshold <- 0      # min |weight| for a conjunction to be reported active
rbbr_balancing <- TRUE          # class-balance the training fold internally
rbbr_num_cores <- NA            # NA = automatic; set an integer to fix core count
rbbr_verbose <- TRUE

## ------------------------------------------------------------------------
## SETUP
## ------------------------------------------------------------------------

if (!requireNamespace("RBBR", quietly = TRUE)) install.packages("RBBR")
if (!requireNamespace("readr", quietly = TRUE)) install.packages("readr")
if (!requireNamespace("caret", quietly = TRUE)) install.packages("caret")

suppressPackageStartupMessages({
  library(RBBR)
  library(readr)
  library(caret)
})

dir.create(model_output_dir, recursive = TRUE, showWarnings = TRUE)
if (!dir.exists(model_output_dir)) {
  stop(sprintf(
    "Could not create model_output_dir '%s' (resolved to '%s') from working directory '%s'.\n  Check write permissions, or that the parent path exists / is spelled correctly.",
    model_output_dir, file.path(getwd(), model_output_dir), getwd()
  ))
}

set.seed(random_seed)

## ------------------------------------------------------------------------
## 1. LOAD DATA
## ------------------------------------------------------------------------

cat("Loading processed data from:", processed_data_path, "\n")
data_all <- as.data.frame(read_csv(processed_data_path, show_col_types = FALSE))

target_col_index <- ncol(data_all)
Y <- data_all[[target_col_index]]

cat(sprintf(
  "Dataset '%s': %d rows, %d predictors, target = '%s'\n",
  dataset_name, nrow(data_all), ncol(data_all) - 1, colnames(data_all)[target_col_index]
))
cat("Class balance:\n")
print(table(Y) / length(Y))

## ------------------------------------------------------------------------
## 2. CREATE & SAVE CV FOLDS
## ------------------------------------------------------------------------

folds <- createFolds(Y, k = num_folds)
folds_path <- file.path(model_output_dir, paste0(dataset_name, "_folds.rds"))
saveRDS(folds, file = folds_path)
cat("Saved fold assignments to:", folds_path, "\n")

## ------------------------------------------------------------------------
## 3. TRAIN ONE RBBR MODEL PER FOLD
## ------------------------------------------------------------------------

for (cv_index in seq_len(num_folds)) {

  cat(sprintf("\n===== Fold %d / %d =====\n", cv_index, num_folds))

  test_indices  <- folds[[cv_index]]
  train_indices <- setdiff(seq_len(nrow(data_all)), test_indices)

  train_data <- data_all[train_indices, ]
  test_data  <- data_all[test_indices, ]

  start_time <- Sys.time()
  trained_model <- rbbr_train(
    train_data,
    max_feature      = rbbr_max_feature,
    mode             = rbbr_mode,
    slope            = rbbr_slope,
    weight_threshold = rbbr_weight_threshold,
    balancing        = rbbr_balancing,
    num_cores        = rbbr_num_cores,
    verbose          = rbbr_verbose
  )
  run_time <- difftime(Sys.time(), start_time, units = "secs")
  cat(sprintf("Fold %d training time: %.1f sec\n", cv_index, as.numeric(run_time)))

  # Save the trained model object (needed by 03_evaluate_results.R)
  model_path <- file.path(model_output_dir, sprintf("%s_fold%d_model.rds", dataset_name, cv_index))
  saveRDS(list(trained_model = trained_model,
               train_indices = train_indices,
               test_indices  = test_indices,
               run_time_secs = as.numeric(run_time)),
          file = model_path)

  # Save the extracted Boolean rules for this fold as a readable CSV
  rules_path <- file.path(model_output_dir, sprintf("%s_fold%d_rules.csv", dataset_name, cv_index))
  write_csv(trained_model$boolean_rules, rules_path)

  cat("Top rules for this fold:\n")
  print(head(trained_model$boolean_rules))
  cat("Saved model to:", model_path, "\n")
  cat("Saved rules to:", rules_path, "\n")
}

cat("\nAll folds trained. Run 03_evaluate_results.R next to compute held-out performance.\n")
