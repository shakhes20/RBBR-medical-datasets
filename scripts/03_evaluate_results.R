#############################################################################
# 03_evaluate_results.R
#
# Purpose:
#   Load the per-fold RBBR models trained by 02_train_model.R, predict on
#   each fold's held-out test set with rbbr_predictor(), and compute
#   standard classification metrics (accuracy, AUC, AUPRC, Cohen's kappa)
#   -- both per fold and averaged across folds. Also reports how
#   performance changes as more top-BIC rules are ensembled together
#   (num_top_rules = 1, 2, 3, ...).
#
# Usage:
#   1. Run 01_preprocessing.R and 02_train_model.R first.
#   2. Edit the CONFIG section only.
#   3. Run: Rscript scripts/03_evaluate_results.R
#############################################################################

## ------------------------------------------------------------------------
## CONFIG -- edit this section only
## ------------------------------------------------------------------------

# Path to the same processed dataset used in 02_train_model.R
processed_data_path <- "data/processed/dataset1_clean.csv"

# Must match dataset_name / model_output_dir used in 02_train_model.R
dataset_name <- "dataset1"
model_output_dir <- "results/models"

# Where the evaluation summary (CSV) and plot (PDF) are written
eval_output_dir <- "results/evaluation"

# Cross-validation setup (must match 02_train_model.R)
num_folds <- 5

# How many top-BIC rules to test ensembling over, e.g. 1:5 tries
# num_top_rules = 1, 2, 3, 4, 5 and reports accuracy/AUC for each
num_top_rules_range <- 1:5

# Classification threshold applied to rbbr_predictor() probabilities
classification_threshold <- 0.5

# RBBR prediction hyperparameters (should match training slope)
rbbr_slope <- 10
rbbr_num_cores <- NA
rbbr_verbose <- FALSE

## ------------------------------------------------------------------------
## SETUP
## ------------------------------------------------------------------------

required_pkgs <- c("RBBR", "readr", "PRROC", "ROCR", "irr", "ggplot2")
for (pkg in required_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
}

suppressPackageStartupMessages({
  library(RBBR)
  library(readr)
  library(PRROC)
  library(ROCR)
  library(irr)
  library(ggplot2)
})

dir.create(eval_output_dir, recursive = TRUE, showWarnings = TRUE)
if (!dir.exists(eval_output_dir)) {
  stop(sprintf(
    "Could not create eval_output_dir '%s' (resolved to '%s') from working directory '%s'.\n  Check write permissions, or that the parent path exists / is spelled correctly.",
    eval_output_dir, file.path(getwd(), eval_output_dir), getwd()
  ))
}

## ------------------------------------------------------------------------
## 1. LOAD DATA
## ------------------------------------------------------------------------

data_all <- as.data.frame(read_csv(processed_data_path, show_col_types = FALSE))
target_col_index <- ncol(data_all)

## ------------------------------------------------------------------------
## 2. HELPER: compute metrics from predicted probabilities + true labels
## ------------------------------------------------------------------------

compute_metrics <- function(prob, labels, threshold = classification_threshold) {
  pred_class <- ifelse(prob >= threshold, 1, 0)

  auc_val <- tryCatch({
    roc.curve(scores.class0 = prob, weights.class0 = labels)$auc
  }, error = function(e) NA)

  auprc_val <- tryCatch({
    pr.curve(scores.class0 = prob, weights.class0 = labels)$auc.davis.goadrich
  }, error = function(e) NA)

  accuracy_val <- mean(pred_class == labels)

  kappa_val <- tryCatch({
    irr::kappa2(cbind(pred_class, labels))$value
  }, error = function(e) NA)

  data.frame(accuracy = accuracy_val, auc = auc_val, auprc = auprc_val, kappa = kappa_val)
}

## ------------------------------------------------------------------------
## 3. EVALUATE EACH FOLD ACROSS num_top_rules_range
## ------------------------------------------------------------------------

all_results <- data.frame()

for (cv_index in seq_len(num_folds)) {

  model_path <- file.path(model_output_dir, sprintf("%s_fold%d_model.rds", dataset_name, cv_index))
  if (!file.exists(model_path)) {
    warning(sprintf("Missing model file for fold %d: %s -- skipping.", cv_index, model_path))
    next
  }

  fold_obj <- readRDS(model_path)
  trained_model <- fold_obj$trained_model
  test_indices  <- fold_obj$test_indices

  test_data   <- data_all[test_indices, ]
  test_data_x <- test_data[, -target_col_index, drop = FALSE]
  labels      <- test_data[[target_col_index]]

  cat(sprintf("\n===== Fold %d / %d (n_test = %d) =====\n", cv_index, num_folds, length(labels)))

  for (top_n in num_top_rules_range) {

    prob <- tryCatch({
      rbbr_predictor(
        trained_model,
        test_data_x,
        num_top_rules = top_n,
        slope         = rbbr_slope,
        num_cores     = rbbr_num_cores,
        verbose       = rbbr_verbose
      )
    }, error = function(e) {
      warning(sprintf("Fold %d, num_top_rules=%d failed: %s", cv_index, top_n, conditionMessage(e)))
      rep(NA_real_, length(labels))
    })

    metrics <- compute_metrics(prob, labels)
    metrics$fold <- cv_index
    metrics$num_top_rules <- top_n
    metrics$run_time_secs <- fold_obj$run_time_secs

    all_results <- rbind(all_results, metrics)
    cat(sprintf("  top_rules=%d  acc=%.3f  auc=%.3f  auprc=%.3f  kappa=%.3f\n",
                top_n, metrics$accuracy, metrics$auc, metrics$auprc, metrics$kappa))
  }
}

## ------------------------------------------------------------------------
## 4. SAVE PER-FOLD RESULTS
## ------------------------------------------------------------------------

results_path <- file.path(eval_output_dir, paste0(dataset_name, "_fold_metrics.csv"))
write_csv(all_results, results_path)
cat("\nSaved per-fold metrics to:", results_path, "\n")

## ------------------------------------------------------------------------
## 5. SUMMARY: mean +/- sd across folds, per num_top_rules
## ------------------------------------------------------------------------

summary_stats <- aggregate(
  cbind(accuracy, auc, auprc, kappa) ~ num_top_rules,
  data = all_results,
  FUN = function(x) c(mean = mean(x, na.rm = TRUE), sd = sd(x, na.rm = TRUE))
)

summary_path <- file.path(eval_output_dir, paste0(dataset_name, "_summary_metrics.csv"))
# Flatten the matrix columns produced by aggregate() before writing
summary_flat <- do.call(data.frame, summary_stats)
write_csv(summary_flat, summary_path)

cat("\nMean performance across folds by num_top_rules:\n")
print(summary_flat)
cat("\nSaved summary metrics to:", summary_path, "\n")

## ------------------------------------------------------------------------
## 6. PLOT: accuracy & AUC vs. number of ensembled top rules
## ------------------------------------------------------------------------

plot_data <- all_results
plot_data$num_top_rules <- factor(plot_data$num_top_rules)

p <- ggplot(plot_data, aes(x = num_top_rules, y = auc)) +
  geom_boxplot(fill = "steelblue", alpha = 0.6) +
  geom_jitter(width = 0.1, alpha = 0.6) +
  labs(
    title = paste0(dataset_name, ": AUC across CV folds by number of ensembled rules"),
    x = "Number of top-BIC rules ensembled",
    y = "AUC"
  ) +
  theme_minimal()

plot_path <- file.path(eval_output_dir, paste0(dataset_name, "_auc_by_num_rules.pdf"))
ggsave(plot_path, plot = p, width = 6, height = 4)
cat("Saved evaluation plot to:", plot_path, "\n")
