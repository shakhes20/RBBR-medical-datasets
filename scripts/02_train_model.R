# ============================================================================
# 02_train_model.R
#
# Trains the RBBR model (Regression-Based Boolean Rule) on each of the
# preprocessed datasets, following the paper's Materials and Methods:
#   - Boolean rules built from subsets of up to 3 clinical features
#     (max_feature = 3)
#   - Ridge regression fit per rule set, regularization lambda tuned via
#     5-fold cross-validation
#   - Best rule set per dataset selected by lowest BIC
#   - RBBR::rbbr_train() performs generation of Boolean rules, ridge fitting,
#     and BIC ranking internally (see RBBR package documentation:
#     https://github.com/CompBioIPM/RBBR)
#
# For evaluation metrics matching Table 3 of the paper (ACC, AUROC over
# 5-fold CV), this script also trains/predicts across 5 stratified folds
# per dataset and saves per-fold predictions for 03_evaluate_results.R to
# score.
#
# Usage:
#   source("scripts/01_preprocessing.R")   # if not already run
#   source("scripts/02_train_model.R")
# ============================================================================

source("scripts/00_utils.R")
ensure_dirs()
library(RBBR)

if (!file.exists(file.path(PROCESSED_DIR, "all_datasets.rds"))) {
  stop("Run scripts/01_preprocessing.R first to produce data/processed/all_datasets.rds")
}
processed <- readRDS(file.path(PROCESSED_DIR, "all_datasets.rds"))

if (length(processed) == 0) {
  stop("No processed datasets found. Check 01_preprocessing.R output/warnings.")
}

# ---- RBBR hyperparameters (paper's Materials and Methods) -------------------
# max_feature = 3: "we use Boolean rules involving up to three input
#   features" (Methods; also stated in Abstract and Boolean Rule Generation).
# balancing: the paper does not explicitly report the `balancing` argument
#   value; TRUE is RBBR's documented default and is used here for datasets
#   with meaningful class imbalance (see majority-class % in Table 1,
#   e.g. Wisconsin BC 65.5%, Diagnostic BC 62.7%, Diabetes 61.5%).
# num_top_rules for prediction: the paper's Table 2 rule sets contain
#   multiple rules combined with OR (e.g. 4 rules for Diabetes, 3-4 for most
#   datasets), consistent with using several top-BIC rules; we default to
#   the number of positive-coefficient rules RBBR itself selects per the
#   documented rbbr_train()/rbbr_predictor() workflow, i.e. num_top_rules
#   matching the top rule set's rule count (default 5 as a generous cap,
#   adjustable per dataset below).

RBBR_PARAMS <- list(
  max_feature      = 3,
  mode             = "1L",
  slope            = 10,
  weight_threshold = 0,
  balancing        = TRUE,
  num_cores        = max(1, parallel::detectCores() - 1),
  verbose          = FALSE
)

N_FOLDS <- 5
SEED    <- 42

# Datasets with a binary 0/1 target trained/evaluated as classification
# (rbbr_predictor returns predicted probabilities). The 3-level lung cancer
# dataset has an ordinal 0/1/2 target and is treated as regression per the
# RBBR package's documented behavior for continuous targets (see README:
# "when dealing with a continuous target variable, the rbbr_predictor()
# output can be regarded as the predicted target value").
BINARY_DATASETS <- c(
  "lung_cancer_binary", "wisconsin_bc", "diagnostic_bc",
  "heart_failure", "diabetes_risk"
)

trained_models  <- list()
fold_predictions <- list()

for (key in names(processed)) {
  data <- processed[[key]]
  target_col <- names(data)[ncol(data)]
  log_step(sprintf("Training RBBR on %s (%s, n=%d, p=%d)...",
                    DATASET_INFO[[key]]$name, key, nrow(data), ncol(data) - 1))

  y <- data[[target_col]]
  folds <- make_stratified_folds(y, k = N_FOLDS, seed = SEED)

  fold_preds_this_dataset <- vector("list", N_FOLDS)

  for (fold_i in seq_len(N_FOLDS)) {
    test_idx  <- folds[[fold_i]]
    train_idx <- setdiff(seq_len(nrow(data)), test_idx)

    data_train <- data[train_idx, , drop = FALSE]
    data_test  <- data[test_idx, , drop = FALSE]

    trained_fold <- tryCatch({
      do.call(rbbr_train, c(list(data = data_train), RBBR_PARAMS))
    }, error = function(e) {
      warning(sprintf("[%s] fold %d: rbbr_train() failed: %s", key, fold_i, conditionMessage(e)))
      NULL
    })

    if (is.null(trained_fold)) next

    data_test_x <- data_test[, seq_len(ncol(data_test) - 1), drop = FALSE]
    y_test      <- data_test[[target_col]]

    # Number of top rules to combine for prediction: use however many rules
    # RBBR's best (lowest-BIC) model retained with positive weight, capped
    # at 5 to stay consistent with the multi-rule OR-combined sets reported
    # in Table 2 of the paper.
    n_top <- if (!is.null(trained_fold$boolean_rules) && nrow(trained_fold$boolean_rules) > 0) {
      min(5, nrow(trained_fold$boolean_rules))
    } else {
      1
    }

    y_pred <- tryCatch({
      rbbr_predictor(
        trained_fold, data_test_x,
        num_top_rules = n_top,
        slope         = RBBR_PARAMS$slope,
        num_cores     = RBBR_PARAMS$num_cores,
        verbose       = FALSE
      )
    }, error = function(e) {
      warning(sprintf("[%s] fold %d: rbbr_predictor() failed: %s", key, fold_i, conditionMessage(e)))
      NULL
    })

    if (is.null(y_pred)) next

    fold_preds_this_dataset[[fold_i]] <- data.frame(
      fold = fold_i,
      row_id = test_idx,
      y_true = y_test,
      y_pred = as.numeric(y_pred)
    )
  }

  fold_predictions[[key]] <- do.call(rbind, fold_preds_this_dataset)

  # Also fit one full-data model per dataset (used for reporting the
  # top Boolean rule set / R^2 / BIC, matching Table 2's presentation of a
  # single best rule set per dataset rather than per-fold rule sets).
  full_model <- tryCatch({
    do.call(rbbr_train, c(list(data = data), RBBR_PARAMS))
  }, error = function(e) {
    warning(sprintf("[%s] full-data rbbr_train() failed: %s", key, conditionMessage(e)))
    NULL
  })
  trained_models[[key]] <- full_model

  log_step(sprintf("Finished %s: %d/%d folds scored.",
                    key, sum(!sapply(fold_preds_this_dataset, is.null)), N_FOLDS))
}

saveRDS(trained_models, file.path(PROCESSED_DIR, "trained_models.rds"))
saveRDS(fold_predictions, file.path(PROCESSED_DIR, "fold_predictions.rds"))

log_step(sprintf(
  "Training complete for %d/%d datasets. Models saved to %s, fold predictions to %s.",
  sum(!sapply(trained_models, is.null)), length(processed),
  file.path(PROCESSED_DIR, "trained_models.rds"),
  file.path(PROCESSED_DIR, "fold_predictions.rds")
))
