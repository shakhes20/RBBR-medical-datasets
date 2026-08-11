# ============================================================================
# 03_evaluate_results.R
#
# Computes evaluation metrics from the RBBR models/predictions produced by
# 02_train_model.R, and compares them against the paper's reported results:
#
#   Table 2 (R^2, BIC of the best Boolean rule set per dataset)
#   Table 3 (5-fold CV ACC / AUROC / Rule Number / Rule Length, benchmarked
#            against DeepRED, REM-D, ECLAIRE, for Lung Cancer Prediction and
#            Diagnostic Breast Cancer only)
#   Fig. 3  (ROC / PR curves across 5 binary-target datasets)
#
# Outputs (all under results/tables/):
#   - metrics_by_dataset.csv       : ACC, AUROC, precision, sensitivity,
#                                     specificity, F1 (mean +/- SD over folds)
#   - best_rule_sets.csv           : top rule set's R^2 and BIC per dataset,
#                                     compared to paper's Table 2 values
#   - table3_benchmark_comparison.csv : RBBR reproduced ACC/AUROC/RN/RL vs.
#                                        paper's Table 3 values (Lung Cancer
#                                        Prediction, Diagnostic Breast Cancer)
#   - confusion_matrices.rds       : per-dataset aggregate confusion matrix
#
# Usage:
#   source("scripts/02_train_model.R")   # if not already run
#   source("scripts/03_evaluate_results.R")
# ============================================================================

source("scripts/00_utils.R")
ensure_dirs()

req_files <- c("trained_models.rds", "fold_predictions.rds")
for (f in req_files) {
  if (!file.exists(file.path(PROCESSED_DIR, f))) {
    stop(sprintf("Run scripts/02_train_model.R first to produce %s", file.path(PROCESSED_DIR, f)))
  }
}
trained_models   <- readRDS(file.path(PROCESSED_DIR, "trained_models.rds"))
fold_predictions <- readRDS(file.path(PROCESSED_DIR, "fold_predictions.rds"))

# ---- Paper's reported values for comparison (transcribed from Table 2,
# Table 3, and Table 1 of Eskandarian & Malekpour, 2026) -------------------

PAPER_TABLE2 <- data.frame(
  dataset_key = c("lung_cancer_binary", "lung_cancer_3level", "wisconsin_bc",
                   "diagnostic_bc", "heart_failure", "diabetes_risk"),
  paper_r2  = c(0.92, 0.87, 0.87, 0.88, 0.55, 0.65),
  paper_bic = c(-207, -3806, -2425, -2449, -1541, -1259),
  stringsAsFactors = FALSE
)

PAPER_TABLE3 <- data.frame(
  dataset_key = c("lung_cancer_binary", "lung_cancer_binary", "lung_cancer_binary", "lung_cancer_binary",
                   "diagnostic_bc", "diagnostic_bc", "diagnostic_bc", "diagnostic_bc"),
  method = c("DeepRED", "REM-D", "ECLAIRE", "RBBR",
             "DeepRED", "REM-D", "ECLAIRE", "RBBR"),
  paper_acc_mean  = c(59.5, 59.5, 93.2, 98.3,  91.4, 91.4, 94.4, 96.5),
  paper_acc_sd    = c(17.4, 17.4, 3.4,  3.7,   1.5,  1.5,  2.5,  2.1),
  paper_auroc_mean = c(59.6, 59.6, 93.6, 98.0, 89.9, 90.0, 93.9, 95.9),
  paper_auroc_sd   = c(17.1, 17.1, 3.2,  4.5,  2.2,  2.0,  2.7,  2.3),
  paper_rn_mean = c(2.0, 2.0, 3.6, 3.2,   2.0, 2.0, 32.8, 4.6),
  paper_rn_sd   = c(0.0, 0.0, 1.86, 0.45, 0.0, 0.0, 12.73, 0.55),
  paper_rl_mean = c(0.0, 0.0, 1.18, 2.2,  1.0, 1.0, 2.13, 3.0),
  paper_rl_sd   = c(0.0, 0.0, 0.23, 0.447, 0.0, 0.0, 0.27, 0.0),
  stringsAsFactors = FALSE
)

# ============================================================================
# 1. Per-fold classification metrics -> mean +/- SD per dataset
# ============================================================================
log_step("Computing per-fold classification metrics...")

metrics_rows <- list()
roc_data_list <- list()  # for 04_generate_figures.R
confusion_list <- list()

for (key in names(fold_predictions)) {
  preds <- fold_predictions[[key]]
  if (is.null(preds) || nrow(preds) == 0) {
    warning(sprintf("[%s] No fold predictions available; skipping metrics.", key))
    next
  }

  is_binary_target <- all(preds$y_true %in% c(0, 1)) &&
    length(unique(preds$y_true)) == 2

  if (!is_binary_target) {
    # 3-level lung cancer: report R^2-style fit and MAE instead of
    # classification metrics, since the target is ordinal/continuous
    # (see rbbr_predictor() documentation: continuous target -> predicted
    # value, not a probability).
    ss_res <- sum((preds$y_true - preds$y_pred)^2)
    ss_tot <- sum((preds$y_true - mean(preds$y_true))^2)
    r2_cv  <- 1 - ss_res / ss_tot
    mae_cv <- mean(abs(preds$y_true - preds$y_pred))
    metrics_rows[[key]] <- data.frame(
      dataset_key = key, name = DATASET_INFO[[key]]$name,
      metric_type = "regression (ordinal target)",
      accuracy_mean = NA, accuracy_sd = NA,
      auroc_mean = NA, auroc_sd = NA,
      r2_cv = r2_cv, mae_cv = mae_cv,
      stringsAsFactors = FALSE
    )
    next
  }

  per_fold <- do.call(rbind, lapply(split(preds, preds$fold), function(fp) {
    m <- binary_metrics(fp$y_true, fp$y_pred)
    auc <- compute_auroc(fp$y_true, fp$y_pred)
    data.frame(accuracy = m$accuracy, auroc = auc,
               precision = m$precision, sensitivity = m$sensitivity,
               specificity = m$specificity, f1 = m$f1)
  }))

  metrics_rows[[key]] <- data.frame(
    dataset_key = key, name = DATASET_INFO[[key]]$name,
    metric_type = "classification",
    accuracy_mean = mean(per_fold$accuracy, na.rm = TRUE) * 100,
    accuracy_sd   = stats::sd(per_fold$accuracy, na.rm = TRUE) * 100,
    auroc_mean    = mean(per_fold$auroc, na.rm = TRUE) * 100,
    auroc_sd      = stats::sd(per_fold$auroc, na.rm = TRUE) * 100,
    r2_cv = NA, mae_cv = NA,
    stringsAsFactors = FALSE
  )

  # Pooled ROC/PR curve (all folds' predictions combined) for Fig. 3-style plots
  roc_data_list[[key]] <- list(
    roc = roc_curve(preds$y_true, preds$y_pred),
    pr  = pr_curve(preds$y_true, preds$y_pred)
  )

  agg_pred <- as.numeric(preds$y_pred >= 0.5)
  confusion_list[[key]] <- table(
    Actual = factor(preds$y_true, levels = c(0, 1)),
    Predicted = factor(agg_pred, levels = c(0, 1))
  )
}

metrics_df <- do.call(rbind, metrics_rows)
write.csv(metrics_df, file.path(TABLES_DIR, "metrics_by_dataset.csv"), row.names = FALSE)
saveRDS(roc_data_list, file.path(PROCESSED_DIR, "roc_pr_data.rds"))
saveRDS(confusion_list, file.path(TABLES_DIR, "confusion_matrices.rds"))

log_step(sprintf("Saved %s", file.path(TABLES_DIR, "metrics_by_dataset.csv")))


# ============================================================================
# 2. Best Boolean rule set per dataset: R^2 / BIC, vs. paper's Table 2
# ============================================================================
log_step("Extracting best Boolean rule sets (R^2, BIC) and comparing to Table 2...")

best_rules_rows <- list()
for (key in names(trained_models)) {
  model <- trained_models[[key]]
  if (is.null(model) || is.null(model$boolean_rules) || nrow(model$boolean_rules) == 0) {
    next
  }
  # boolean_rules is sorted by BIC per RBBR's documented output (see README
  # example: "head(trained_model$boolean_rules)" shows ascending BIC / best
  # model first).
  top_rule <- model$boolean_rules[1, ]
  best_rules_rows[[key]] <- data.frame(
    dataset_key = key,
    name = DATASET_INFO[[key]]$name,
    boolean_rule = top_rule$Boolean_Rule,
    reproduced_r2  = as.numeric(top_rule$R2),
    reproduced_bic = as.numeric(top_rule$BIC),
    stringsAsFactors = FALSE
  )
}
best_rules_df <- do.call(rbind, best_rules_rows)

if (!is.null(best_rules_df)) {
  comparison_df <- merge(best_rules_df, PAPER_TABLE2, by = "dataset_key", all.x = TRUE)
  comparison_df$r2_diff  <- comparison_df$reproduced_r2  - comparison_df$paper_r2
  comparison_df$bic_diff <- comparison_df$reproduced_bic - comparison_df$paper_bic
  write.csv(comparison_df, file.path(TABLES_DIR, "best_rule_sets.csv"), row.names = FALSE)
  log_step(sprintf("Saved %s", file.path(TABLES_DIR, "best_rule_sets.csv")))
} else {
  warning("No trained models produced Boolean rule sets; check 02_train_model.R output.")
}


# ============================================================================
# 3. Table 3 style benchmark comparison (Lung Cancer Prediction, Diagnostic
#    Breast Cancer) -- RBBR's reproduced ACC/AUROC vs. paper's reported
#    values for RBBR (this script does not reproduce DeepRED/REM-D/ECLAIRE,
#    which are separate external tools not implemented here; their paper
#    values are included for reference only).
# ============================================================================
log_step("Building Table 3-style benchmark comparison for RBBR...")

table3_keys <- c("lung_cancer_binary", "diagnostic_bc")
rbbr_repro <- metrics_df[metrics_df$dataset_key %in% table3_keys &
                            metrics_df$metric_type == "classification", ]

# Rule Number (RN) / Rule Length (RL): approximate using the trained model's
# retained positive-coefficient rules from the full-data fit (Table 2 rule
# sets), consistent with the paper's definition ("RN ... number of Boolean
# rules with positive coefficients ... RL ... number of features in a rule").
rn_rl_rows <- list()
for (key in table3_keys) {
  model <- trained_models[[key]]
  if (is.null(model) || is.null(model$boolean_rules)) next
  top_rule <- model$boolean_rules[1, ]
  # Boolean_Rule string contains one or more OR-combined conjunctions;
  # count occurrences of "AND"/"∧"-joined clauses as a proxy for RN, and
  # count feature tokens per clause as a proxy for RL. This is a heuristic
  # reconstruction from the printed rule string -- for an authoritative
  # RN/RL, use the weight_threshold-filtered coefficient vector directly
  # from the RBBR model object if / when the package exposes it.
  rule_str <- as.character(top_rule$Boolean_Rule)
  rn_approx <- lengths(regmatches(rule_str, gregexpr("\\[", rule_str)))
  rl_approx <- mean(lengths(regmatches(rule_str, gregexpr("[A-Za-z_.]+", rule_str))) / max(rn_approx, 1))
  rn_rl_rows[[key]] <- data.frame(dataset_key = key, rn_reproduced = rn_approx, rl_reproduced = rl_approx)
}
rn_rl_df <- do.call(rbind, rn_rl_rows)

table3_repro <- merge(rbbr_repro, rn_rl_df, by = "dataset_key", all.x = TRUE)
table3_repro$method <- "RBBR (reproduced)"

table3_paper_rbbr_only <- PAPER_TABLE3[PAPER_TABLE3$method == "RBBR", ]

table3_comparison <- merge(
  table3_repro[, c("dataset_key", "accuracy_mean", "accuracy_sd", "auroc_mean", "auroc_sd",
                    "rn_reproduced", "rl_reproduced")],
  table3_paper_rbbr_only[, c("dataset_key", "paper_acc_mean", "paper_acc_sd",
                              "paper_auroc_mean", "paper_auroc_sd", "paper_rn_mean", "paper_rl_mean")],
  by = "dataset_key", all.x = TRUE
)
write.csv(table3_comparison, file.path(TABLES_DIR, "table3_benchmark_comparison.csv"), row.names = FALSE)
write.csv(PAPER_TABLE3, file.path(TABLES_DIR, "table3_paper_reference.csv"), row.names = FALSE)

log_step(sprintf("Saved %s and %s",
                  file.path(TABLES_DIR, "table3_benchmark_comparison.csv"),
                  file.path(TABLES_DIR, "table3_paper_reference.csv")))

log_step("Evaluation complete. Review results/tables/ for full comparison against the paper.")
