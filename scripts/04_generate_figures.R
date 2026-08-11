# ============================================================================
# 04_generate_figures.R
#
# Reproduces the paper's key figures from the pipeline's saved outputs:
#
#   Fig. 3 style: ROC and PR curves across the five binary-target datasets
#                 (Lung Cancer Prediction, Wisconsin Breast Cancer,
#                 Diagnostic Breast Cancer, Heart Failure Prediction,
#                 Early Stage Diabetes Risk), pooled over 5-fold CV
#                 predictions.
#
#   Table 2 summary bar chart: R^2 of the best Boolean rule set per dataset,
#                 reproduced vs. paper-reported, for a quick visual check.
#
# Fig. 1 (schematic of Boolean rule inference) and Fig. 2 (MSE/coefficients
# vs. log(lambda) for one illustrative 3-feature subset) are conceptual /
# illustrative figures in the paper rather than dataset-level result plots;
# reproducing them exactly would require access to RBBR's internal
# lambda-path and per-rule coefficient trace, which is not part of the
# documented rbbr_train()/rbbr_predictor() return value. If RBBR exposes
# a $lambda_path or $coef_path component in a future version, a Fig. 2
# style plot could be added here using glmnet-style plotting.
#
# Outputs (all under results/figures/):
#   - roc_curves_all_datasets.png
#   - pr_curves_all_datasets.png
#   - r2_comparison_reproduced_vs_paper.png
#
# Usage:
#   source("scripts/03_evaluate_results.R")   # if not already run
#   source("scripts/04_generate_figures.R")
# ============================================================================

source("scripts/00_utils.R")
ensure_dirs()

roc_pr_file <- file.path(PROCESSED_DIR, "roc_pr_data.rds")
best_rules_file <- file.path(TABLES_DIR, "best_rule_sets.csv")

if (!file.exists(roc_pr_file)) {
  stop("Run scripts/03_evaluate_results.R first to produce ", roc_pr_file)
}
roc_data_list <- readRDS(roc_pr_file)

# Paper's Fig. 3 color scheme, for visual consistency with the manuscript
DATASET_COLORS <- c(
  lung_cancer_binary = "red",
  wisconsin_bc        = "green3",
  diagnostic_bc       = "blue",
  heart_failure       = "brown",
  diabetes_risk       = "orange"
)
DATASET_LABELS <- c(
  lung_cancer_binary = "Lung Cancer Pred",
  wisconsin_bc        = "Wisconsin Breast Cancer",
  diagnostic_bc       = "Diagnostic Breast Cancer",
  heart_failure       = "Heart Failure Prediction",
  diabetes_risk       = "Diabetes Risk Prediction"
)

# ============================================================================
# ROC curves (Fig. 3, left panel)
# ============================================================================
log_step("Generating ROC curve figure...")

png(file.path(FIGURES_DIR, "roc_curves_all_datasets.png"), width = 900, height = 800, res = 130)
plot(NA, xlim = c(0, 1), ylim = c(0, 1),
     xlab = "FPR", ylab = "Sensitivity", main = "ROC curve")
abline(a = 0, b = 1, col = "gray80", lty = 2)

plotted_keys <- c()
for (key in names(DATASET_COLORS)) {
  if (is.null(roc_data_list[[key]])) next
  roc_df <- roc_data_list[[key]]$roc
  roc_df <- roc_df[order(roc_df$fpr), ]
  lines(roc_df$fpr, roc_df$tpr, col = DATASET_COLORS[[key]], lwd = 2)
  plotted_keys <- c(plotted_keys, key)
}
if (length(plotted_keys) > 0) {
  legend("bottomright", legend = DATASET_LABELS[plotted_keys],
         col = DATASET_COLORS[plotted_keys], lwd = 2, cex = 0.8, bty = "n")
}
dev.off()
log_step(sprintf("Saved %s", file.path(FIGURES_DIR, "roc_curves_all_datasets.png")))


# ============================================================================
# PR curves (Fig. 3, right panel)
# ============================================================================
log_step("Generating PR curve figure...")

png(file.path(FIGURES_DIR, "pr_curves_all_datasets.png"), width = 900, height = 800, res = 130)
plot(NA, xlim = c(0, 1), ylim = c(0, 1),
     xlab = "Recall", ylab = "Precision", main = "PR curve")

plotted_keys <- c()
for (key in names(DATASET_COLORS)) {
  if (is.null(roc_data_list[[key]])) next
  pr_df <- roc_data_list[[key]]$pr
  pr_df <- pr_df[order(pr_df$recall), ]
  lines(pr_df$recall, pr_df$precision, col = DATASET_COLORS[[key]], lwd = 2)
  plotted_keys <- c(plotted_keys, key)
}
if (length(plotted_keys) > 0) {
  legend("bottomleft", legend = DATASET_LABELS[plotted_keys],
         col = DATASET_COLORS[plotted_keys], lwd = 2, cex = 0.8, bty = "n")
}
dev.off()
log_step(sprintf("Saved %s", file.path(FIGURES_DIR, "pr_curves_all_datasets.png")))


# ============================================================================
# R^2 comparison: reproduced vs. paper (Table 2)
# ============================================================================
if (file.exists(best_rules_file)) {
  log_step("Generating R^2 comparison figure (reproduced vs. paper, Table 2)...")

  comp <- read.csv(best_rules_file, stringsAsFactors = FALSE)
  comp <- comp[!is.na(comp$paper_r2), ]

  if (nrow(comp) > 0) {
    png(file.path(FIGURES_DIR, "r2_comparison_reproduced_vs_paper.png"),
        width = 1000, height = 700, res = 130)

    bar_mat <- rbind(comp$reproduced_r2, comp$paper_r2)
    colnames(bar_mat) <- DATASET_LABELS[comp$dataset_key]
    colnames(bar_mat)[is.na(colnames(bar_mat))] <- comp$dataset_key[is.na(colnames(bar_mat))]

    op <- par(mar = c(8, 4, 3, 1))
    bp <- barplot(bar_mat, beside = TRUE,
                   col = c("steelblue", "gray60"),
                   ylim = c(0, 1), las = 2, cex.names = 0.75,
                   ylab = expression(R^2),
                   main = "Best Boolean rule set R\u00b2: reproduced vs. paper (Table 2)")
    legend("topright", legend = c("Reproduced", "Paper (Table 2)"),
           fill = c("steelblue", "gray60"), bty = "n", cex = 0.8)
    par(op)
    dev.off()
    log_step(sprintf("Saved %s", file.path(FIGURES_DIR, "r2_comparison_reproduced_vs_paper.png")))
  } else {
    log_step("No datasets with both reproduced and paper R^2 available; skipping R^2 comparison figure.")
  }
} else {
  log_step(sprintf("%s not found; skipping R^2 comparison figure. Run 03_evaluate_results.R first.", best_rules_file))
}

log_step("Figure generation complete. See results/figures/.")
