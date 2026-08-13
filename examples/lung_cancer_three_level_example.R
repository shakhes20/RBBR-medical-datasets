#############################################################################
# examples/lung_cancer_three_level_example.R
#
# RBBR-medical-datasets -- worked example
#
# Dataset : Three-level Lung Cancer Risk (Kaggle "cancer patient data sets"),
#           1000 patients, 23 clinical/lifestyle features, 3-class target
#           `Level` in {Low, Medium, High}.
#
# Goal    : Demonstrate the published RBBR package (CRAN: RBBR) on a real,
#           multi-class clinical dataset via a one-vs-rest ensemble of
#           binary RBBR models -- one per class -- combined by probability
#           argmax. Each binary model yields its own set of interpretable
#           Boolean rules, so this example also shows what class-specific
#           interpretability looks like for a 3-class diagnostic problem.
#
#           Note: rbbr_train()/rbbr_predictor() are documented for binary
#           (or continuous) targets. One-vs-rest is the standard, fully
#           documented-API way to extend that to a 3-class outcome.
#
# Usage   : 1. Place the raw CSV at the path in `raw_data_path` below.
#           2. Edit the CONFIG section only.
#           3. Run: Rscript examples/lung_cancer_three_level_example.R
#############################################################################

## ------------------------------------------------------------------------
## CONFIG -- edit this section only
## ------------------------------------------------------------------------

raw_data_path <- "data/raw/cancer_patient_data_sets.csv"

# Columns to drop before modeling (identifiers, not clinical features)
id_cols_to_drop <- c("index", "Patient Id")

# Name of the multi-class target column
target_col <- "Level"

# The 3 class labels, in the order results/plots will report them
class_labels <- c("Low", "Medium", "High")

# Directory for saved models, rules, and evaluation output
output_dir <- "results/lung_cancer_three_level_example"

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

required_pkgs <- c("RBBR", "readr", "PRROC", "irr", "ggplot2")
for (pkg in required_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
}

suppressPackageStartupMessages({
  library(RBBR)
  library(readr)
  library(PRROC)
  library(irr)
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

data_clean <- data_raw[, !(colnames(data_raw) %in% id_cols_to_drop)]

cat(sprintf("Dropped ID columns: %s\n", paste(id_cols_to_drop, collapse = ", ")))
cat(sprintf("Working dataset: %d rows x %d columns (incl. target)\n",
            nrow(data_clean), ncol(data_clean)))

stopifnot(all(class_labels %in% unique(data_clean[[target_col]])))

cat("\nClass distribution:\n")
print(table(data_clean[[target_col]]))

## ------------------------------------------------------------------------
## 2. TRAIN / TEST SPLIT (shared across all 3 one-vs-rest models, so every
##    class model is evaluated on the exact same held-out patients)
## ------------------------------------------------------------------------

n <- nrow(data_clean)
test_idx <- sample(seq_len(n), size = floor(test_fraction * n))
train_idx <- setdiff(seq_len(n), test_idx)

cat(sprintf("\nSplit: %d train / %d test\n", length(train_idx), length(test_idx)))

## ------------------------------------------------------------------------
## 3. ONE-VS-REST: build a binary target per class, scale, train, predict
## ------------------------------------------------------------------------

predictor_cols <- setdiff(colnames(data_clean), target_col)

ovr_models <- list()
test_probs <- matrix(NA_real_, nrow = length(test_idx), ncol = length(class_labels),
                      dimnames = list(NULL, class_labels))

for (cls in class_labels) {

  cat(sprintf("\n===== One-vs-rest model: '%s' vs rest =====\n", cls))

  # Binary target: 1 if this class, 0 otherwise; placed as the LAST column
  # (required by RBBR)
  data_binary <- data_clean[, predictor_cols]
  data_binary[[cls]] <- as.numeric(data_clean[[target_col]] == cls)

  # Scale predictors to [0,1] via RBBR's own scaling (leaves target as-is)
  data_scaled <- rbbr_scaling(data_binary)

  train_data <- data_scaled[train_idx, ]
  test_data  <- data_scaled[test_idx, ]
  test_data_x <- test_data[, predictor_cols, drop = FALSE]
  test_labels <- test_data[[cls]]

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

  prob <- rbbr_predictor(
    trained_model,
    test_data_x,
    num_top_rules = rbbr_num_top_rules,
    slope         = rbbr_slope,
    num_cores     = rbbr_num_cores,
    verbose       = rbbr_verbose
  )

  test_probs[, cls] <- prob

  # Per-class (one-vs-rest) AUC
  auc_val <- tryCatch({
    roc.curve(scores.class0 = prob, weights.class0 = test_labels)$auc
  }, error = function(e) NA)
  cat(sprintf("'%s' vs rest -- held-out AUC: %.3f\n", cls, auc_val))

  # Save model + rules for this class
  saveRDS(trained_model, file.path(output_dir, sprintf("model_%s_vs_rest.rds", cls)))
  write_csv(trained_model$boolean_rules,
            file.path(output_dir, sprintf("rules_%s_vs_rest.csv", cls)))

  cat(sprintf("Top Boolean rules distinguishing '%s' from other classes:\n", cls))
  print(head(trained_model$boolean_rules, 3))

  ovr_models[[cls]] <- trained_model
}

## ------------------------------------------------------------------------
## 4. COMBINE ONE-VS-REST PROBABILITIES INTO A SINGLE 3-CLASS PREDICTION
## ------------------------------------------------------------------------

predicted_class <- class_labels[apply(test_probs, 1, which.max)]
true_class <- data_clean[[target_col]][test_idx]

confusion <- table(True = true_class, Predicted = predicted_class)
cat("\nConfusion matrix (held-out test set):\n")
print(confusion)

overall_accuracy <- mean(predicted_class == true_class)
cat(sprintf("\nOverall 3-class accuracy: %.3f\n", overall_accuracy))

kappa_val <- tryCatch({
  irr::kappa2(data.frame(
    rater1 = factor(true_class, levels = class_labels),
    rater2 = factor(predicted_class, levels = class_labels)
  ))$value
}, error = function(e) NA)
cat(sprintf("Cohen's kappa: %.3f\n", kappa_val))

## ------------------------------------------------------------------------
## 5. SAVE RESULTS
## ------------------------------------------------------------------------

results_table <- data.frame(
  true_class = true_class,
  predicted_class = predicted_class,
  test_probs
)
write_csv(results_table, file.path(output_dir, "test_predictions.csv"))

summary_df <- data.frame(
  metric = c("overall_accuracy", "cohens_kappa"),
  value = c(overall_accuracy, kappa_val)
)
write_csv(summary_df, file.path(output_dir, "summary_metrics.csv"))

confusion_df <- as.data.frame(confusion)
p <- ggplot(confusion_df, aes(x = Predicted, y = True, fill = Freq)) +
  geom_tile() +
  geom_text(aes(label = Freq), color = "white", size = 5) +
  scale_fill_gradient(low = "steelblue", high = "darkred") +
  scale_y_discrete(limits = rev(class_labels)) +
  scale_x_discrete(limits = class_labels) +
  labs(title = "Lung Cancer Risk Level -- One-vs-Rest RBBR Confusion Matrix",
       x = "Predicted", y = "True") +
  theme_minimal()

ggsave(file.path(output_dir, "confusion_matrix.pdf"), plot = p, width = 5, height = 4)
ggsave(file.path(output_dir, "confusion_matrix.png"), plot = p, width = 5, height = 4, dpi = 150)

cat("\nAll outputs written to:", output_dir, "\n")
cat("  - model_<class>_vs_rest.rds   : trained RBBR model per class\n")
cat("  - rules_<class>_vs_rest.csv   : interpretable Boolean rules per class\n")
cat("  - test_predictions.csv        : per-patient held-out predictions\n")
cat("  - summary_metrics.csv         : overall accuracy / kappa\n")
cat("  - confusion_matrix.pdf/.png   : visual summary\n")
