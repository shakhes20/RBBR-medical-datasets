# ============================================================================
# 00_utils.R
# Shared helper functions used across 01_preprocessing.R, 02_train_model.R,
# 03_evaluate_results.R, and 04_generate_figures.R.
#
# This file is not one of the four numbered pipeline scripts; it is sourced
# by each of them, e.g.:
#     source("scripts/00_utils.R")
#
# Reference: Eskandarian & Malekpour (2026), "Interpretable Predictive
# Modeling for Medical Data Using Boolean Rule-aware Regression", bioRxiv,
# doi:10.64898/2026.05.14.725084
# ============================================================================

# ---- Directory setup --------------------------------------------------------

RAW_DIR       <- "data/raw"
PROCESSED_DIR <- "data/processed"
RESULTS_DIR   <- "results"
TABLES_DIR    <- file.path(RESULTS_DIR, "tables")
FIGURES_DIR   <- file.path(RESULTS_DIR, "figures")

ensure_dirs <- function() {
  dirs <- c(RAW_DIR, PROCESSED_DIR, RESULTS_DIR, TABLES_DIR, FIGURES_DIR)
  for (d in dirs) {
    if (!dir.exists(d)) dir.create(d, recursive = TRUE)
  }
}

# ---- Dataset registry ---------------------------------------------------
# Table 1 of the paper. Used for sanity-checking loaded data against the
# reported sample size / feature count / class balance.

DATASET_INFO <- list(
  lung_cancer_binary = list(
    name = "Lung Cancer Prediction",
    n_expected = 59, p_expected = 4, n_classes = 2,
    majority_pct = 52.5, source = "Kaggle"
  ),
  lung_cancer_3level = list(
    name = "Three-level Lung Cancer",
    n_expected = 1000, p_expected = 23, n_classes = 3,
    majority_pct = 36.5, source = "Kaggle"
  ),
  wisconsin_bc = list(
    name = "Wisconsin Breast Cancer",
    n_expected = 699, p_expected = 9, n_classes = 2,
    majority_pct = 65.5, source = "UCI"
  ),
  diagnostic_bc = list(
    name = "Diagnostic Breast Cancer",
    n_expected = 569, p_expected = 30, n_classes = 2,
    majority_pct = 62.7, source = "UCI"
  ),
  heart_failure = list(
    name = "Heart Failure Prediction",
    n_expected = 746, p_expected = 11, n_classes = 2,
    majority_pct = 52.3, source = "Kaggle"
  ),
  diabetes_risk = list(
    name = "Early Stage Diabetes Risk",
    n_expected = 520, p_expected = 16, n_classes = 2,
    majority_pct = 61.5, source = "UCI"
  )
)

check_dataset_shape <- function(data, dataset_key, tolerance_n = 0.05) {
  info <- DATASET_INFO[[dataset_key]]
  n <- nrow(data)
  p <- ncol(data) - 1  # last column is target
  n_lo <- floor(info$n_expected * (1 - tolerance_n))
  n_hi <- ceiling(info$n_expected * (1 + tolerance_n))
  if (n < n_lo || n > n_hi) {
    warning(sprintf(
      "[%s] Loaded %d rows; paper reports %d (Table 1). Check raw file / filtering steps.",
      info$name, n, info$n_expected
    ))
  }
  if (p != info$p_expected) {
    warning(sprintf(
      "[%s] Loaded %d features; paper reports %d (Table 1). Column layout may differ from the paper's preprocessing.",
      info$name, p, info$p_expected
    ))
  }
  invisible(TRUE)
}

# ---- Missing-value helpers -------------------------------------------------

# Simple, transparent imputation: median for numeric columns, mode for
# categorical/factor columns. RBBR's rbbr_scaling() requires complete,
# numeric-encoded input, so imputation must happen before scaling.
impute_median_mode <- function(df) {
  for (col in names(df)) {
    x <- df[[col]]
    if (is.numeric(x)) {
      if (anyNA(x)) {
        med <- stats::median(x, na.rm = TRUE)
        df[[col]][is.na(x)] <- med
      }
    } else {
      if (anyNA(x)) {
        tab <- table(x)
        mode_val <- names(tab)[which.max(tab)]
        df[[col]][is.na(x)] <- mode_val
      }
    }
  }
  df
}

# ---- Encoding helpers -------------------------------------------------------

# Encode a Yes/No, Male/Female, Positive/Negative style binary column to 0/1.
# Returns a numeric vector. `positive_level` maps to 1.
encode_binary <- function(x, positive_level) {
  x_chr <- trimws(as.character(x))
  as.numeric(x_chr == positive_level)
}

# One-hot encode a categorical column (excluding NA), returning a data.frame
# of 0/1 indicator columns named "<colname>_<level>".
one_hot_encode <- function(x, colname) {
  x <- as.factor(x)
  levs <- levels(x)
  out <- as.data.frame(
    stats::model.matrix(~ x - 1),
    stringsAsFactors = FALSE
  )
  names(out) <- paste0(colname, "_", levs)
  out
}

# ---- Train/test split -------------------------------------------------------

# Stratified train/test split preserving class proportions, matching the
# paper's use of 5-fold cross-validation for evaluation (Table 3, Fig. 3).
# For a single held-out split (e.g., quick sanity checks), use split_ratio.
stratified_split <- function(data, target_col, split_ratio = 0.8, seed = 42) {
  set.seed(seed)
  y <- data[[target_col]]
  idx_train <- c()
  for (cls in unique(y)) {
    cls_idx <- which(y == cls)
    n_train <- floor(length(cls_idx) * split_ratio)
    idx_train <- c(idx_train, sample(cls_idx, n_train))
  }
  list(
    train = data[idx_train, , drop = FALSE],
    test  = data[-idx_train, , drop = FALSE]
  )
}

# Create k stratified folds (list of length k, each a vector of row indices
# held out as the test fold), matching the paper's 5-fold CV protocol used
# for Table 3 and Fig. 3.
make_stratified_folds <- function(y, k = 5, seed = 42) {
  set.seed(seed)
  folds <- vector("list", k)
  for (cls in unique(y)) {
    cls_idx <- sample(which(y == cls))
    fold_assign <- cut(seq_along(cls_idx), breaks = k, labels = FALSE)
    for (i in seq_len(k)) {
      folds[[i]] <- c(folds[[i]], cls_idx[fold_assign == i])
    }
  }
  folds
}

# ---- Metrics -----------------------------------------------------------

# Binary classification metrics from predicted probabilities and true 0/1
# labels, at a given threshold (default 0.5).
binary_metrics <- function(y_true, y_prob, threshold = 0.5) {
  y_pred <- as.numeric(y_prob >= threshold)
  tp <- sum(y_pred == 1 & y_true == 1)
  tn <- sum(y_pred == 0 & y_true == 0)
  fp <- sum(y_pred == 1 & y_true == 0)
  fn <- sum(y_pred == 0 & y_true == 1)

  acc  <- (tp + tn) / length(y_true)
  prec <- if ((tp + fp) > 0) tp / (tp + fp) else NA_real_
  sens <- if ((tp + fn) > 0) tp / (tp + fn) else NA_real_  # recall / sensitivity
  spec <- if ((tn + fp) > 0) tn / (tn + fp) else NA_real_
  f1   <- if (!is.na(prec) && !is.na(sens) && (prec + sens) > 0) {
    2 * prec * sens / (prec + sens)
  } else NA_real_

  list(
    accuracy    = acc,
    precision   = prec,
    sensitivity = sens,
    specificity = spec,
    f1          = f1,
    confusion   = matrix(c(tn, fp, fn, tp), nrow = 2, byrow = TRUE,
                          dimnames = list(Actual = c("0", "1"), Predicted = c("0", "1")))
  )
}

# AUROC via the Mann-Whitney U statistic (rank-sum formula). Avoids requiring
# the pROC/ROCR packages as a hard dependency, though either could be used.
compute_auroc <- function(y_true, y_prob) {
  pos <- y_prob[y_true == 1]
  neg <- y_prob[y_true == 0]
  n1 <- length(pos); n0 <- length(neg)
  if (n1 == 0 || n0 == 0) return(NA_real_)
  r <- rank(c(pos, neg))
  r_pos <- sum(r[seq_len(n1)])
  auc <- (r_pos - n1 * (n1 + 1) / 2) / (n1 * n0)
  auc
}

# Full ROC curve coordinates (FPR, TPR) swept across observed probability
# thresholds, for Fig. 3-style plots.
roc_curve <- function(y_true, y_prob) {
  thresholds <- sort(unique(c(0, y_prob, 1)), decreasing = TRUE)
  tpr <- numeric(length(thresholds))
  fpr <- numeric(length(thresholds))
  P <- sum(y_true == 1)
  N <- sum(y_true == 0)
  for (i in seq_along(thresholds)) {
    th <- thresholds[i]
    pred <- as.numeric(y_prob >= th)
    tp <- sum(pred == 1 & y_true == 1)
    fp <- sum(pred == 1 & y_true == 0)
    tpr[i] <- if (P > 0) tp / P else NA_real_
    fpr[i] <- if (N > 0) fp / N else NA_real_
  }
  data.frame(threshold = thresholds, fpr = fpr, tpr = tpr)
}

# Precision-Recall curve coordinates, for Fig. 3-style plots.
pr_curve <- function(y_true, y_prob) {
  thresholds <- sort(unique(c(0, y_prob, 1)), decreasing = TRUE)
  precision <- numeric(length(thresholds))
  recall    <- numeric(length(thresholds))
  P <- sum(y_true == 1)
  for (i in seq_along(thresholds)) {
    th <- thresholds[i]
    pred <- as.numeric(y_prob >= th)
    tp <- sum(pred == 1 & y_true == 1)
    fp <- sum(pred == 1 & y_true == 0)
    precision[i] <- if ((tp + fp) > 0) tp / (tp + fp) else NA_real_
    recall[i]    <- if (P > 0) tp / P else NA_real_
  }
  data.frame(threshold = thresholds, precision = precision, recall = recall)
}

# ---- Small print helper for pipeline logging --------------------------------

log_step <- function(msg) {
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%H:%M:%S"), msg))
}
