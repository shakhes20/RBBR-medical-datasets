#############################################################################
# examples/lung_cancer_prediction_example.R
#
# RBBR-medical-datasets -- worked example
#
# Dataset : Lung Cancer Prediction (Kaggle "lung cancer"), 59 patients,
#           4 clinical/lifestyle features (Age, Smokes, AreaQ, Alcohol),
#           binary target `Result` (0 = no cancer, 1 = cancer).
#
# Goal    : Demonstrate the published RBBR package (CRAN: RBBR) on the
#           small, real-world screening dataset used in the RBBR paper.
#           RBBR searches all subsets of up to 3 features, converts each
#           subset into Boolean conjunctions, fits a ridge regression per
#           subset, and selects the rule set with the best BIC. Reported
#           in the paper: the best rule set (Age, AreaQ, Alcohol) reaches
#           R^2 = 0.92, BIC = -207 on the full dataset.
#
# Usage   : 1. Place the raw CSV at the path in `raw_data_path` below
#              (default: data/raw/lung_cancer_examples.csv).
#           2. Edit the CONFIG section only.
#           3. Run: Rscript examples/lung_cancer_prediction_example.R
#############################################################################

## ------------------------------------------------------------------------
## CONFIG -- edit this section only
## ------------------------------------------------------------------------

raw_data_path <- "data/raw/lung_cancer_examples.csv"

# Identifier columns to drop before modeling (not clinical features)
id_cols_to_drop <- c("Name", "Surname")

# Name of the binary target column (0/1)
target_col <- "Result"

# Directory for saved model, rules, and evaluation output
output_dir <- "results/lung_cancer_prediction_example"

# Train/test split and reproducibility
test_fraction <- 0.2
random_seed <- 42

# RBBR hyperparameters (see ?rbbr_train / ?rbbr_predictor)
rbbr_max_feature <- 3
rbbr_mode <- "1L"
rbbr_slope <- 10
rbbr_weight_threshold <- 0
rbbr_balancing <- TRUE
rbbr_num_cores <- NA
rbbr_num_top_rules <- 5
rbbr_verbose <- TRUE

## ------------------------------------------------------------------------
## SETUP
## ------------------------------------------------------------------------

required_pkgs <- c("RBBR", "readr", "PRROC", "ggplot2")
for (pkg in required_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
}

suppressPackageStartupMessages({
  library(RBBR)
  library(readr)
  library(PRROC)
  library(ggplot2)
})

dir_created_ok <- dir.create(output_dir, recursive = TRUE, showWarnings = TRUE)
if (!dir.exists(output_dir)) {
  stop(sprintf(
    "Could not create output_dir '%s' (resolved to '%s') from working directory '%s'.\n  Check write permissions, or that the parent path exists / is spelled correctly.",
    output_dir, file.path(getwd(), output_dir), getwd()
  ))
}
cat(sprintf("Output directory ready: %s\n", normalizePath(output_dir)))
set.seed(random_seed)

## ------------------------------------------------------------------------
## 1. LOAD & CLEAN
## ------------------------------------------------------------------------

cat("Loading:", raw_data_path, "\n")
data_raw <- as.data.frame(read_csv(raw_data_path, show_col_types = FALSE))

# Drop identifier columns (patient name / surname carry no clinical signal)
data_clean <- data_raw[, !(colnames(data_raw) %in% id_cols_to_drop)]

cat(sprintf("Dropped ID columns: %s\n", paste(id_cols_to_drop, collapse = ", ")))

# Harmonize the misspelled "Alkhol" column name from the raw CSV, if present
if ("Alkhol" %in% colnames(data_clean)) {
  colnames(data_clean)[colnames(data_clean) == "Alkhol"] <- "Alcohol"
}

cat(sprintf("Working dataset: %d rows x %d columns (incl. target)\n",
            nrow(data_clean), ncol(data_clean)))

stopifnot(target_col %in% colnames(data_clean))
stopifnot(all(data_clean[[target_col]] %in% c(0, 1)))

cat("\nClass distribution:\n")
print(table(data_clean[[target_col]]))

## ------------------------------------------------------------------------
## 2. REORDER COLUMNS & RESCALE PREDICTORS TO [0, 1] -- RBBR requires the
##    target variable in the LAST column, and predictors on [0,1].
## ------------------------------------------------------------------------

predictor_cols <- setdiff(colnames(data_clean), target_col)
data_clean <- data_clean[, c(predictor_cols, target_col)]

data_scaled <- rbbr_scaling(data_clean)

## ------------------------------------------------------------------------
## 3. TRAIN / TEST SPLIT
## ------------------------------------------------------------------------

n <- nrow(data_scaled)
test_idx <- sample(seq_len(n), size = floor(test_fraction * n))
train_idx <- setdiff(seq_len(n), test_idx)

cat(sprintf("\nSplit: %d train / %d test\n", length(train_idx), length(test_idx)))

train_data <- data_scaled[train_idx, ]
test_data  <- data_scaled[test_idx, ]
test_data_x <- test_data[, predictor_cols, drop = FALSE]
test_labels <- test_data[[target_col]]

## ------------------------------------------------------------------------
## 4. TRAIN RBBR MODEL
## ------------------------------------------------------------------------

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

cat("\nTop Boolean rules inferred (by BIC):\n")
print(head(trained_model$boolean_rules, 5))

saveRDS(trained_model, file.path(output_dir, "model.rds"))
write_csv(trained_model$boolean_rules, file.path(output_dir, "rules.csv"))

## ------------------------------------------------------------------------
## 5. PREDICT & EVALUATE ON THE HELD-OUT TEST SET
## ------------------------------------------------------------------------

prob <- rbbr_predictor(
  trained_model,
  test_data_x,
  num_top_rules = rbbr_num_top_rules,
  slope         = rbbr_slope,
  num_cores     = rbbr_num_cores,
  verbose       = rbbr_verbose
)

pred_class <- ifelse(prob >= 0.5, 1, 0)
accuracy_val <- mean(pred_class == test_labels)

auc_val <- tryCatch({
  roc.curve(scores.class0 = prob, weights.class0 = test_labels)$auc
}, error = function(e) NA)

auprc_val <- tryCatch({
  pr.curve(scores.class0 = prob, weights.class0 = test_labels)$auc.davis.goadrich
}, error = function(e) NA)

cat(sprintf("\nHeld-out test set (n = %d):\n", length(test_labels)))
cat(sprintf("  Accuracy : %.3f\n", accuracy_val))
cat(sprintf("  AUC      : %.3f\n", auc_val))
cat(sprintf("  AUPRC    : %.3f\n", auprc_val))

confusion <- table(True = test_labels, Predicted = pred_class)
cat("\nConfusion matrix (held-out test set):\n")
print(confusion)

## ------------------------------------------------------------------------
## 6. SAVE RESULTS
## ------------------------------------------------------------------------

results_table <- data.frame(
  true_label = test_labels,
  predicted_label = pred_class,
  predicted_prob = prob
)
write_csv(results_table, file.path(output_dir, "test_predictions.csv"))

summary_df <- data.frame(
  metric = c("accuracy", "auc", "auprc"),
  value = c(accuracy_val, auc_val, auprc_val)
)
write_csv(summary_df, file.path(output_dir, "summary_metrics.csv"))

# ROC curve plot
roc_obj <- tryCatch(
  roc.curve(scores.class0 = prob, weights.class0 = test_labels, curve = TRUE),
  error = function(e) NULL
)

if (!is.null(roc_obj)) {
  roc_df <- as.data.frame(roc_obj$curve[, 1:2])
  colnames(roc_df) <- c("FPR", "Sensitivity")

  p <- ggplot(roc_df, aes(x = FPR, y = Sensitivity)) +
    geom_line(color = "steelblue", linewidth = 1) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey60") +
    labs(title = "Lung Cancer Prediction -- RBBR ROC Curve (held-out test set)",
         x = "False Positive Rate", y = "Sensitivity") +
    theme_minimal()

  ggsave(file.path(output_dir, "roc_curve.pdf"), plot = p, width = 5, height = 4)
  ggsave(file.path(output_dir, "roc_curve.png"), plot = p, width = 5, height = 4, dpi = 150)
}

cat("\nAll outputs written to:", output_dir, "\n")
cat("  - model.rds             : trained RBBR model\n")
cat("  - rules.csv              : interpretable Boolean rules, ranked by BIC\n")
cat("  - test_predictions.csv   : per-patient held-out predictions\n")
cat("  - summary_metrics.csv    : accuracy / AUC / AUPRC\n")
cat("  - roc_curve.pdf/.png     : ROC curve on the held-out test set\n")
