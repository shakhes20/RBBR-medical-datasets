# Repository Structure

```
RBBR-medical-datasets/
├── README.md
├── LICENSE
├── structure.md                 <- this file
├── .gitignore
├── data/
│   ├── data_sources.md          <- dataset descriptions, links, licenses
│   ├── raw/                     <- downloaded/uploaded raw CSVs (gitignored)
│   └── processed/                <- cleaned .rds files (gitignored; regenerate via scripts/01)
├── scripts/
│   ├── 00_utils.R                <- shared helpers (sourced by 01-04)
│   ├── 01_preprocessing.R        <- load, clean, encode, scale all 6 datasets
│   ├── 02_train_model.R          <- RBBR training, 5-fold CV
│   ├── 03_evaluate_results.R     <- metrics + comparison to paper's Table 2/3
│   └── 04_generate_figures.R     <- ROC/PR curves, R^2 comparison plot
└── results/
    ├── tables/                   <- CSV outputs (metrics, rule sets, benchmarks)
    └── figures/                  <- PNG figures
```

## Data flow

```
data/raw/*.csv or auto-download
        |
        v
scripts/01_preprocessing.R  --> data/processed/<dataset>.rds
                                 data/processed/all_datasets.rds
                                 results/tables/preprocessing_summary.csv
        |
        v
scripts/02_train_model.R    --> data/processed/trained_models.rds
                                 data/processed/fold_predictions.rds
        |
        v
scripts/03_evaluate_results.R --> results/tables/metrics_by_dataset.csv
                                   results/tables/best_rule_sets.csv
                                   results/tables/table3_benchmark_comparison.csv
                                   data/processed/roc_pr_data.rds
        |
        v
scripts/04_generate_figures.R --> results/figures/roc_curves_all_datasets.png
                                   results/figures/pr_curves_all_datasets.png
                                   results/figures/r2_comparison_reproduced_vs_paper.png
```

Each script is idempotent and can be re-run independently as long as its
upstream `.rds` inputs exist in `data/processed/`.
