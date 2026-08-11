# ============================================================================
# 01_preprocessing.R
#
# Loads, cleans, encodes, and rescales the six medical datasets used in:
#   Eskandarian & Malekpour (2026), "Interpretable Predictive Modeling for
#   Medical Data Using Boolean Rule-aware Regression", bioRxiv,
#   doi:10.64898/2026.05.14.725084
#
# Datasets (paper Table 1):
#   1. Lung Cancer Prediction        (Kaggle, n=59,  p=4,  binary)
#   2. Three-level Lung Cancer       (Kaggle, n=1000,p=23, 3-class)
#   3. Wisconsin Breast Cancer       (UCI,    n=699, p=9,  binary)
#   4. Diagnostic Breast Cancer      (UCI,    n=569, p=30, binary)
#   5. Heart Failure Prediction      (Kaggle, n=746, p=11, binary; 746 after
#                                     the paper's data preparation)
#   6. Early Stage Diabetes Risk     (UCI,    n=520, p=16, binary)
#
# The three UCI datasets are downloaded automatically. The three Kaggle
# datasets require a Kaggle account and cannot be fetched programmatically
# without authentication; this script expects their raw CSVs to already be
# present in data/raw/ (see the "KAGGLE - MANUAL DOWNLOAD REQUIRED" comments
# below for exact filenames and download links) and will stop with a clear
# error message naming the missing file if they are not found.
#
# Output: one cleaned, RBBR-ready (scaled, target-in-last-column) data.frame
# per dataset, saved as data/processed/<key>.rds, plus a combined
# data/processed/all_datasets.rds list for convenience in later scripts.
#
# Usage:
#   source("scripts/01_preprocessing.R")
# ============================================================================

source("scripts/00_utils.R")
ensure_dirs()

# RBBR::rbbr_scaling() rescales each feature to (0,1) per the paper's Boolean
# Rule Generation section ("continuous or multi-level discrete features are
# first rescaled to the (0,1) interval"). We use it directly rather than
# reimplementing scaling, to guarantee identical behavior to rbbr_train().
if (!requireNamespace("RBBR", quietly = TRUE)) {
  stop(
    "The RBBR package is required for scaling and training.\n",
    "Install with: install.packages(\"RBBR\")\n",
    "(source: https://github.com/CompBioIPM/RBBR)"
  )
}
library(RBBR)

processed <- list()


# ============================================================================
# 3. WISCONSIN BREAST CANCER (UCI id=15) — auto-downloaded
# ============================================================================
log_step("Loading Wisconsin Breast Cancer (UCI)...")

wbc_zip  <- file.path(RAW_DIR, "wisconsin_bc.zip")
wbc_file <- file.path(RAW_DIR, "breast-cancer-wisconsin.data")

if (!file.exists(wbc_file)) {
  download.file(
    "https://archive.ics.uci.edu/static/public/15/breast+cancer+wisconsin+original.zip",
    destfile = wbc_zip, mode = "wb", quiet = TRUE
  )
  unzip(wbc_zip, files = "breast-cancer-wisconsin.data", exdir = RAW_DIR)
}

wbc_cols <- c(
  "Sample_code_number", "Clump_thickness", "Uniformity_cell_size",
  "Uniformity_cell_shape", "Marginal_adhesion", "Single_epithelial_cell_size",
  "Bare_nuclei", "Bland_chromatin", "Normal_nucleoli", "Mitoses", "Class"
)
wbc_raw <- read.csv(
  wbc_file, header = FALSE, col.names = wbc_cols,
  na.strings = "?", stringsAsFactors = FALSE
)

# Drop ID column (not a clinical feature); Bare_nuclei has ~16 missing values
# in the original data (UCI dataset description: "Has Missing Values? Yes").
wbc <- wbc_raw[, setdiff(wbc_cols, "Sample_code_number")]
wbc$Bare_nuclei <- as.numeric(wbc$Bare_nuclei)
wbc <- impute_median_mode(wbc)

# Class: 2 = benign, 4 = malignant -> 0/1, malignant = 1 (disease-positive)
wbc$Class <- as.numeric(wbc$Class == 4)

check_dataset_shape(wbc, "wisconsin_bc")
wbc_scaled <- rbbr_scaling(wbc)  # target (last col) passes through unscaled/binary
processed$wisconsin_bc <- wbc_scaled
saveRDS(wbc_scaled, file.path(PROCESSED_DIR, "wisconsin_bc.rds"))
log_step(sprintf("Wisconsin Breast Cancer ready: %d x %d", nrow(wbc_scaled), ncol(wbc_scaled)))


# ============================================================================
# 4. DIAGNOSTIC BREAST CANCER (UCI id=17) — auto-downloaded
# ============================================================================
log_step("Loading Diagnostic Breast Cancer (UCI)...")

dbc_zip  <- file.path(RAW_DIR, "diagnostic_bc.zip")
dbc_file <- file.path(RAW_DIR, "wdbc.data")

if (!file.exists(dbc_file)) {
  download.file(
    "https://archive.ics.uci.edu/static/public/17/breast+cancer+wisconsin+diagnostic.zip",
    destfile = dbc_zip, mode = "wb", quiet = TRUE
  )
  unzip(dbc_zip, files = "wdbc.data", exdir = RAW_DIR)
}

# 30 features = 10 base measures x (mean, SE, worst), per UCI variable table.
base_feats <- c(
  "radius", "texture", "perimeter", "area", "smoothness",
  "compactness", "concavity", "concave_points", "symmetry", "fractal_dimension"
)
dbc_feat_cols <- c(paste0(base_feats, "1"), paste0(base_feats, "2"), paste0(base_feats, "3"))
dbc_cols <- c("ID", "Diagnosis", dbc_feat_cols)

dbc_raw <- read.csv(
  dbc_file, header = FALSE, col.names = dbc_cols, stringsAsFactors = FALSE
)

dbc <- dbc_raw[, c(dbc_feat_cols, "Diagnosis")]
dbc$Diagnosis <- encode_binary(dbc$Diagnosis, positive_level = "M")  # malignant = 1
# No missing values in this dataset (UCI: "Has Missing Values? No").

check_dataset_shape(dbc, "diagnostic_bc")
dbc_scaled <- rbbr_scaling(dbc)
processed$diagnostic_bc <- dbc_scaled
saveRDS(dbc_scaled, file.path(PROCESSED_DIR, "diagnostic_bc.rds"))
log_step(sprintf("Diagnostic Breast Cancer ready: %d x %d", nrow(dbc_scaled), ncol(dbc_scaled)))


# ============================================================================
# 6. EARLY STAGE DIABETES RISK (UCI id=529) — auto-downloaded
# ============================================================================
log_step("Loading Early Stage Diabetes Risk (UCI)...")

diab_zip  <- file.path(RAW_DIR, "diabetes_risk.zip")
diab_file <- file.path(RAW_DIR, "diabetes_data_upload.csv")

if (!file.exists(diab_file)) {
  download.file(
    "https://archive.ics.uci.edu/static/public/529/early+stage+diabetes+risk+prediction+dataset.zip",
    destfile = diab_zip, mode = "wb", quiet = TRUE
  )
  unzip(diab_zip, files = "diabetes_data_upload.csv", exdir = RAW_DIR)
}

diab_raw <- read.csv(diab_file, stringsAsFactors = FALSE, check.names = TRUE)
# Original columns: Age, Gender, Polyuria, Polydipsia, sudden weight loss,
# weakness, Polyphagia, Genital thrush, visual blurring, Itching, Irritability,
# delayed healing, partial paresis, muscle stiffness, Alopecia, Obesity, class

diab <- diab_raw
binary_symptom_cols <- setdiff(names(diab), c("Age", "Gender", "class"))
for (col in binary_symptom_cols) {
  diab[[col]] <- encode_binary(diab[[col]], positive_level = "Yes")
}
diab$Gender <- encode_binary(diab$Gender, positive_level = "Male")  # paper's Fig. rules refer to "Gender" as a binary feature
diab$class  <- encode_binary(diab$class, positive_level = "Positive")

# Reorder so target ("class") is last, as required by rbbr_scaling()/rbbr_train()
diab <- diab[, c(setdiff(names(diab), "class"), "class")]
diab <- impute_median_mode(diab)  # no missing values expected, but safe to include

check_dataset_shape(diab, "diabetes_risk")
diab_scaled <- rbbr_scaling(diab)
processed$diabetes_risk <- diab_scaled
saveRDS(diab_scaled, file.path(PROCESSED_DIR, "diabetes_risk.rds"))
log_step(sprintf("Early Stage Diabetes Risk ready: %d x %d", nrow(diab_scaled), ncol(diab_scaled)))


# ============================================================================
# 1. LUNG CANCER PREDICTION (Kaggle, 59 x 4) — KAGGLE: MANUAL DOWNLOAD REQUIRED
# ============================================================================
log_step("Loading Lung Cancer Prediction (Kaggle)...")

# Per the paper: a 59-sample, 4-feature (Age, Smokes, AreaQ, Alcohol) subset
# of the Kaggle "cancer patient data sets" family, used for binary
# lung-cancer prediction. This is a different, smaller table than dataset #2
# below (23 features, 1000 rows, 3-class), even though both trace back to
# the same Kaggle uploader/collection.
#
# Kaggle downloads require an authenticated account; this script cannot
# fetch it automatically. To proceed:
#   1. Go to https://www.kaggle.com/datasets/thedevastator/cancer-patients-and-air-pollution-a-new-link
#      (or the specific ~59-row table referenced in the paper, if hosted
#      as a separate Kaggle asset)
#   2. Download the CSV and place it at: data/raw/lung_cancer_binary.csv
#   3. Ensure it has (at minimum) columns for Age, Smoking status, AreaQ,
#      Alcohol use, and a binary cancer outcome column. Adjust the column
#      names below (lc_bin_cols) to match your file's actual headers.

lc_bin_file <- file.path(RAW_DIR, "lung_cancer_binary.csv")

if (!file.exists(lc_bin_file)) {
  warning(sprintf(
    paste(
      "SKIPPED: Lung Cancer Prediction (binary) dataset not found at %s.",
      "Download from Kaggle and place it there (see comments in",
      "01_preprocessing.R), then re-run this script.", sep = "\n"
    ),
    lc_bin_file
  ))
} else {
  lc_bin_raw <- read.csv(lc_bin_file, stringsAsFactors = FALSE, check.names = TRUE)

  # Expected columns (adjust to match actual Kaggle headers if they differ):
  #   Age, Smokes, AreaQ, Alcohol, <target>
  expected_cols <- c("Age", "Smokes", "AreaQ", "Alcohol")
  missing_cols <- setdiff(expected_cols, names(lc_bin_raw))
  if (length(missing_cols) > 0) {
    warning(sprintf(
      "Lung Cancer Prediction file is missing expected columns: %s. Update the column-mapping block in 01_preprocessing.R to match your file.",
      paste(missing_cols, collapse = ", ")
    ))
  } else {
    # Identify the target column: anything not in expected_cols and not an
    # obvious ID column. If your file names it differently (e.g. "Result",
    # "Cancer", "Class"), set target_col_name explicitly below.
    target_col_name <- setdiff(names(lc_bin_raw), c(expected_cols, "index", "Patient_Id", "Id"))
    if (length(target_col_name) != 1) {
      stop(
        "Could not unambiguously identify the target column for the Lung Cancer ",
        "Prediction (binary) dataset. Set `target_col_name` explicitly in ",
        "01_preprocessing.R to the name of the cancer-outcome column in your CSV."
      )
    }

    lc_bin <- lc_bin_raw[, c(expected_cols, target_col_name)]
    names(lc_bin)[ncol(lc_bin)] <- "Cancer"

    # Encode: Smokes/Alcohol as binary if character; Age/AreaQ left numeric
    # for rbbr_scaling() to rescale to (0,1). Target encoded 0/1.
    if (!is.numeric(lc_bin$Smokes))  lc_bin$Smokes  <- encode_binary(lc_bin$Smokes, "Yes")
    if (!is.numeric(lc_bin$Alcohol)) lc_bin$Alcohol <- encode_binary(lc_bin$Alcohol, "Yes")
    if (!is.numeric(lc_bin$Cancer)) {
      # Try common encodings for a binary cancer outcome
      lc_bin$Cancer <- encode_binary(lc_bin$Cancer, positive_level = "YES")
    }
    lc_bin <- impute_median_mode(lc_bin)

    check_dataset_shape(lc_bin, "lung_cancer_binary")
    lc_bin_scaled <- rbbr_scaling(lc_bin)
    processed$lung_cancer_binary <- lc_bin_scaled
    saveRDS(lc_bin_scaled, file.path(PROCESSED_DIR, "lung_cancer_binary.rds"))
    log_step(sprintf("Lung Cancer Prediction ready: %d x %d", nrow(lc_bin_scaled), ncol(lc_bin_scaled)))
  }
}


# ============================================================================
# 2. THREE-LEVEL LUNG CANCER (Kaggle, 1000 x 23) — KAGGLE: MANUAL DOWNLOAD REQUIRED
# ============================================================================
log_step("Loading Three-level Lung Cancer (Kaggle)...")

# Download from:
#   https://www.kaggle.com/datasets/thedevastator/cancer-patients-and-air-pollution-a-new-link
# Place the CSV at: data/raw/lung_cancer_3level.csv
# This is the well-known "cancer patient data sets" table: ~1000 rows,
# 23 predictive features (age, gender, air pollution, alcohol use, dust
# allergy, occupational hazards, genetic risk, chronic lung disease, diet,
# obesity, smoking, passive smoker, chest pain, coughing of blood, fatigue,
# weight loss, shortness of breath, wheezing, swallowing difficulty, clubbing
# of finger nails, frequent cold, dry cough, snoring) plus a 3-level target
# "Level" (Low / Medium / High).

lc3_file <- file.path(RAW_DIR, "lung_cancer_3level.csv")

if (!file.exists(lc3_file)) {
  warning(sprintf(
    paste(
      "SKIPPED: Three-level Lung Cancer dataset not found at %s.",
      "Download from Kaggle and place it there (see comments in",
      "01_preprocessing.R), then re-run this script.", sep = "\n"
    ),
    lc3_file
  ))
} else {
  lc3_raw <- read.csv(lc3_file, stringsAsFactors = FALSE, check.names = TRUE)

  # Drop ID / index-style columns if present
  id_like <- intersect(names(lc3_raw), c("index", "Index", "Patient_Id", "Patient.Id", "Id"))
  lc3 <- lc3_raw[, setdiff(names(lc3_raw), id_like)]

  target_candidates <- intersect(names(lc3), c("Level", "level", "Target", "target"))
  if (length(target_candidates) != 1) {
    stop(
      "Could not identify the 3-level target column ('Level') in the Three-level ",
      "Lung Cancer CSV. Rename the outcome column to 'Level' or update ",
      "01_preprocessing.R's `target_candidates` accordingly."
    )
  }
  target_col <- target_candidates[1]

  # Age: numeric, left for rbbr_scaling(). Gender often coded 1/2 in this
  # Kaggle table already; leave numeric if so, else encode Male=1.
  if (!is.numeric(lc3$Gender)) {
    lc3$Gender <- encode_binary(lc3$Gender, positive_level = "Male")
  }
  # Multi-level ordinal symptom/risk columns (typically already 1-9 scales
  # in this dataset) are left as numeric and rescaled to (0,1) by
  # rbbr_scaling(), consistent with the paper's stated preprocessing
  # ("continuous or multi-level discrete features are first rescaled to
  # the (0,1) interval").

  # Encode 3-level target Low/Medium/High -> 0/1/2 (ordinal), stored as the
  # last column. Note rbbr_train()/rbbr_predictor() are documented for
  # binary (0/1) and continuous targets; for this 3-class task the paper
  # reports R^2/BIC from the ridge regression fit rather than a
  # probability-threshold classification, so this ordinal encoding is used
  # directly as the regression response.
  lvl <- toupper(trimws(as.character(lc3[[target_col]])))
  lc3[[target_col]] <- as.numeric(factor(lvl, levels = c("LOW", "MEDIUM", "HIGH"))) - 1

  lc3 <- lc3[, c(setdiff(names(lc3), target_col), target_col)]
  names(lc3)[ncol(lc3)] <- "Level"
  lc3 <- impute_median_mode(lc3)

  check_dataset_shape(lc3, "lung_cancer_3level")
  lc3_scaled <- rbbr_scaling(lc3)
  processed$lung_cancer_3level <- lc3_scaled
  saveRDS(lc3_scaled, file.path(PROCESSED_DIR, "lung_cancer_3level.rds"))
  log_step(sprintf("Three-level Lung Cancer ready: %d x %d", nrow(lc3_scaled), ncol(lc3_scaled)))
}


# ============================================================================
# 5. HEART FAILURE PREDICTION (Kaggle, 918 raw -> 746 after paper's prep)
#    — KAGGLE: MANUAL DOWNLOAD REQUIRED
# ============================================================================
log_step("Loading Heart Failure Prediction (Kaggle)...")

# Download from: https://www.kaggle.com/datasets/fedesoriano/heart-failure-prediction
# Place the CSV at: data/raw/heart_failure.csv
# Raw file has 918 records / 11 features + target HeartDisease. The paper
# reports using 746 records "after data preparation" -- the paper does not
# specify the exact filtering rule. A commonly used cleaning step for this
# dataset is to drop physiologically implausible zero values in
# RestingBP and/or Cholesterol (a known data-quality issue in this Kaggle
# release, e.g. Cholesterol == 0 for ~172 rows). We apply that filter below
# and report the resulting n; if it does not land at exactly 746, adjust
# the filter to match the paper's exact criterion once available, and note
# the discrepancy in results/tables/dataset_summary.csv (produced by
# 03_evaluate_results.R).

hf_file <- file.path(RAW_DIR, "heart_failure.csv")

if (!file.exists(hf_file)) {
  warning(sprintf(
    paste(
      "SKIPPED: Heart Failure Prediction dataset not found at %s.",
      "Download from Kaggle and place it there (see comments in",
      "01_preprocessing.R), then re-run this script.", sep = "\n"
    ),
    hf_file
  ))
} else {
  hf_raw <- read.csv(hf_file, stringsAsFactors = FALSE, check.names = TRUE)

  # Documented columns: Age, Sex, ChestPainType, RestingBP, Cholesterol,
  # FastingBS, RestingECG, MaxHR, ExerciseAngina, Oldpeak, ST_Slope,
  # HeartDisease
  hf <- hf_raw

  n_before <- nrow(hf)
  hf <- hf[hf$Cholesterol > 0 & hf$RestingBP > 0, ]
  n_after <- nrow(hf)
  log_step(sprintf(
    "Heart Failure: filtered zero Cholesterol/RestingBP rows: %d -> %d rows (paper reports 746).",
    n_before, n_after
  ))
  if (n_after != 746) {
    warning(sprintf(
      "Heart Failure Prediction: filtered to %d rows, paper reports 746. The exact filtering rule used in the paper is not fully specified; verify against the manuscript's data-preparation description if exact reproduction of n=746 is required.",
      n_after
    ))
  }

  # Categorical -> encoded numeric (kept simple/interpretable, consistent
  # with the paper's Boolean-rule features like Sex, ChestPainType, ST_Slope)
  hf$Sex <- encode_binary(hf$Sex, positive_level = "M")
  hf$ExerciseAngina <- encode_binary(hf$ExerciseAngina, positive_level = "Y")
  # Ordinal-ish categoricals: encode as factor levels (integer codes), left
  # for rbbr_scaling() to rescale to (0,1)
  hf$ChestPainType <- as.numeric(factor(hf$ChestPainType))
  hf$RestingECG    <- as.numeric(factor(hf$RestingECG))
  hf$ST_Slope      <- as.numeric(factor(hf$ST_Slope))

  hf <- hf[, c(setdiff(names(hf), "HeartDisease"), "HeartDisease")]
  hf <- impute_median_mode(hf)

  check_dataset_shape(hf, "heart_failure")
  hf_scaled <- rbbr_scaling(hf)
  processed$heart_failure <- hf_scaled
  saveRDS(hf_scaled, file.path(PROCESSED_DIR, "heart_failure.rds"))
  log_step(sprintf("Heart Failure Prediction ready: %d x %d", nrow(hf_scaled), ncol(hf_scaled)))
}


# ============================================================================
# Save combined list + summary for downstream scripts
# ============================================================================
saveRDS(processed, file.path(PROCESSED_DIR, "all_datasets.rds"))

summary_df <- do.call(rbind, lapply(names(processed), function(k) {
  d <- processed[[k]]
  data.frame(
    dataset_key = k,
    name        = DATASET_INFO[[k]]$name,
    n_loaded    = nrow(d),
    p_loaded    = ncol(d) - 1,
    n_expected  = DATASET_INFO[[k]]$n_expected,
    p_expected  = DATASET_INFO[[k]]$p_expected,
    stringsAsFactors = FALSE
  )
}))
write.csv(summary_df, file.path(TABLES_DIR, "preprocessing_summary.csv"), row.names = FALSE)

log_step(sprintf(
  "Preprocessing complete. %d of 6 datasets loaded successfully. See %s for details.",
  length(processed), file.path(TABLES_DIR, "preprocessing_summary.csv")
))
if (length(processed) < 6) {
  missing <- setdiff(names(DATASET_INFO), names(processed))
  log_step(sprintf(
    "Missing datasets (need manual Kaggle download): %s",
    paste(missing, collapse = ", ")
  ))
}
