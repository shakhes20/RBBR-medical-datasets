#############################################################################
# 01_preprocessing.R
#
# Purpose:
#   Load a raw medical dataset, clean it (missing values, categorical
#   encoding, outlier-robust rescaling to [0,1]) and write out a
#   model-ready dataset for RBBR (Boolean Rule-aware Regression).
#
# Usage:
#   1. Place your raw CSV in the folder set by `raw_data_path` below
#      (default: data/raw/).
#   2. Edit the CONFIG section only -- no paths elsewhere in this script
#      need to be touched.
#   3. Run: Rscript scripts/01_preprocessing.R
#      (or source() it from an R session started at the repo root)
#############################################################################

## ------------------------------------------------------------------------
## CONFIG -- edit this section only
## ------------------------------------------------------------------------

# Path to the raw input CSV, relative to the repo root
raw_data_path <- "data/raw/dataset1.csv"

# Path where the cleaned, model-ready CSV will be written
processed_data_path <- "data/processed/dataset1_clean.csv"

# Name of the target/outcome column in the raw CSV
target_col <- "Result"

# Is the target binary (0/1, or two-level factor)? If FALSE, the target
# column is left untouched (numeric) rather than being coerced to 0/1.
target_is_binary <- TRUE

# Upper quantile used for outlier-robust rescaling of numeric predictors
# (values above this quantile are capped at 1). 0.975 matches the
# convention used across the RBBR-medical-datasets analyses.
outlier_quantile <- 0.975

# How to handle missing values: "omit" (drop rows with any NA) or
# "median" (impute numeric columns with the column median)
missing_value_strategy <- "omit"

## ------------------------------------------------------------------------
## SETUP
## ------------------------------------------------------------------------

if (!requireNamespace("readr", quietly = TRUE)) install.packages("readr")

suppressPackageStartupMessages({
  library(readr)
})

# Ensure output directory exists (created relative to repo root)
dir.create(dirname(processed_data_path), recursive = TRUE, showWarnings = FALSE)

## ------------------------------------------------------------------------
## 1. LOAD
## ------------------------------------------------------------------------

cat("Loading raw data from:", raw_data_path, "\n")
data_raw <- read_csv(raw_data_path, show_col_types = FALSE)

cat("Raw dataset dimensions:", nrow(data_raw), "rows x", ncol(data_raw), "columns\n")

if (!(target_col %in% colnames(data_raw))) {
  stop(sprintf(
    "target_col '%s' not found in raw data. Available columns: %s",
    target_col, paste(colnames(data_raw), collapse = ", ")
  ))
}

## ------------------------------------------------------------------------
## 2. MISSING VALUES
## ------------------------------------------------------------------------

missing_summary <- colSums(is.na(data_raw))
cat("\nMissing values per column:\n")
print(missing_summary[missing_summary > 0])

if (missing_value_strategy == "omit") {

  n_before <- nrow(data_raw)
  data_clean <- na.omit(data_raw)
  cat(sprintf(
    "\nDropped %d rows containing missing values (%d -> %d rows)\n",
    n_before - nrow(data_clean), n_before, nrow(data_clean)
  ))

} else if (missing_value_strategy == "median") {

  data_clean <- data_raw
  for (col in colnames(data_clean)) {
    if (is.numeric(data_clean[[col]]) && any(is.na(data_clean[[col]]))) {
      med_val <- median(data_clean[[col]], na.rm = TRUE)
      n_imputed <- sum(is.na(data_clean[[col]]))
      data_clean[[col]][is.na(data_clean[[col]])] <- med_val
      cat(sprintf("Imputed %d missing values in '%s' with median (%.4f)\n",
                  n_imputed, col, med_val))
    }
  }
  # Any remaining NAs (e.g. in non-numeric columns) are dropped
  data_clean <- na.omit(data_clean)

} else {
  stop("missing_value_strategy must be 'omit' or 'median'")
}

## ------------------------------------------------------------------------
## 3. ENCODE CATEGORICAL COLUMNS
## ------------------------------------------------------------------------

categorical_cols <- names(data_clean)[sapply(data_clean, is.character)]

if (length(categorical_cols) > 0) {
  cat("\nEncoding categorical columns:", paste(categorical_cols, collapse = ", "), "\n")
  for (col in categorical_cols) {
    data_clean[[col]] <- as.numeric(factor(data_clean[[col]]))
  }
} else {
  cat("\nNo character/categorical columns detected -- skipping encoding step.\n")
}

## ------------------------------------------------------------------------
## 4. OUTLIER-ROBUST RESCALING TO [0, 1]
## ------------------------------------------------------------------------
# For each predictor column: shift to start at 0, divide by the
# `outlier_quantile`-th percentile (so extreme outliers are capped at 1
# rather than compressing the rest of the distribution).

rescale_column <- function(x, q = outlier_quantile) {
  x <- as.numeric(x)
  x <- x - min(x, na.rm = TRUE)
  q_val <- quantile(x, probs = q, na.rm = TRUE)
  if (q_val > 0) {
    x <- x / q_val
  }
  x <- sapply(x, function(v) min(1, v))
  x
}

predictor_cols <- setdiff(colnames(data_clean), target_col)

data_scaled <- data_clean
for (col in predictor_cols) {
  data_scaled[[col]] <- rescale_column(data_scaled[[col]])
}

## ------------------------------------------------------------------------
## 5. TARGET VARIABLE
## ------------------------------------------------------------------------

if (target_is_binary) {
  tgt <- data_scaled[[target_col]]
  if (is.character(tgt)) tgt <- factor(tgt)
  if (is.factor(tgt)) {
    if (nlevels(tgt) != 2) {
      stop(sprintf(
        "target_is_binary = TRUE but '%s' has %d levels, not 2.",
        target_col, nlevels(tgt)
      ))
    }
    tgt <- as.numeric(tgt) - 1  # maps two-level factor to 0/1
  } else {
    uniq_vals <- sort(unique(tgt))
    if (!all(uniq_vals %in% c(0, 1))) {
      stop(sprintf(
        "target_is_binary = TRUE but '%s' contains values other than 0/1: %s",
        target_col, paste(uniq_vals, collapse = ", ")
      ))
    }
  }
  data_scaled[[target_col]] <- tgt
} else {
  cat("\ntarget_is_binary = FALSE -- leaving target column as-is (not rescaled).\n")
}

## ------------------------------------------------------------------------
## 6. SANITY CHECKS
## ------------------------------------------------------------------------

predictor_range <- range(as.matrix(data_scaled[, predictor_cols]), na.rm = TRUE)
cat(sprintf("\nPredictor value range after scaling: [%.4f, %.4f]\n",
            predictor_range[1], predictor_range[2]))

if (predictor_range[1] < 0 || predictor_range[2] > 1) {
  warning("Some predictor values fall outside [0, 1] -- check rescale_column logic.")
}

cat("Final cleaned dataset dimensions:", nrow(data_scaled), "rows x", ncol(data_scaled), "columns\n")

## ------------------------------------------------------------------------
## 7. WRITE OUTPUT
## ------------------------------------------------------------------------

write_csv(data_scaled, processed_data_path)
cat("\nCleaned, scaled dataset written to:", processed_data_path, "\n")
