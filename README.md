# RBBR Applied to Open Medical Datasets

This repository contains the analysis code, workflow, and documentation for applying
the Regression-Based Boolean Rule (RBBR) method to six open medical datasets, as
described in our paper:

**"Interpretable Predictive Modeling for Medical Data Using Boolean Rule-aware Regression"**
Mohammad Eskandarian, Seyed Amir Malekpour (bioRxiv, 2026)
Link: <https://www.biorxiv.org/content/10.64898/2026.05.14.725084v1>
DOI: [10.64898/2026.05.14.725084](https://doi.org/10.64898/2026.05.14.725084)

## Method

This work uses the RBBR method and its R package implementation, developed by
Dr. Seyed Amir Malekpour (CompBioIPM/RBBR), available on CRAN and GitHub:
<https://github.com/CompBioIPM/RBBR>

RBBR derives clinically interpretable Boolean rules (conjunctions of up to three
clinical features) from patient data, uses them as inputs to a ridge regression
model to predict binary or multi-class disease outcomes, and selects the most
parsimonious, predictive rule sets via the Bayesian Information Criterion (BIC).

## Datasets

Six publicly available medical datasets (see `data/data_sources.md` for full
details, direct links, and license terms):

1. **Lung Cancer Prediction** (Kaggle) — 59 samples, 4 features, binary
2. **Three-level Lung Cancer** (Kaggle) — 1,000 samples, 23 features, 3-class
3. **Wisconsin Breast Cancer** (UCI) — 699 samples, 9 features, binary
4. **Diagnostic Breast Cancer** (UCI) — 569 samples, 30 features, binary
5. **Heart Failure Prediction** (Kaggle) — 746 samples (after preparation), 11 features, binary
6. **Early Stage Diabetes Risk** (UCI) — 520 samples, 16 features, binary

The three **UCI** datasets are downloaded automatically by `01_preprocessing.R`.
The three **Kaggle** datasets require a Kaggle account and must be downloaded
manually (or via the `kaggle` CLI) — see `data/data_sources.md` for exact
instructions and expected file paths.

## Contents

- `scripts/00_utils.R` — shared helper functions (sourced by all other scripts)
- `scripts/01_preprocessing.R` — data loading, cleaning, encoding, and RBBR-scaling
- `scripts/02_train_model.R` — RBBR model training with 5-fold cross-validation
- `scripts/03_evaluate_results.R` — performance evaluation and comparison to the paper's reported results
- `scripts/04_generate_figures.R` — ROC/PR curves and R² comparison figures
- `data/data_sources.md` — links, descriptions, and license terms for all six datasets
- `data/raw/` — place downloaded raw CSVs here (not tracked in git; see `.gitignore`)
- `data/processed/` — cleaned, RBBR-ready `.rds` files produced by `01_preprocessing.R`
- `results/tables/` — CSV outputs from `03_evaluate_results.R`
- `results/figures/` — PNG figures from `04_generate_figures.R`

## Usage

```r
install.packages("RBBR")  # https://github.com/CompBioIPM/RBBR

# Run the full pipeline in order:
source("scripts/01_preprocessing.R")
source("scripts/02_train_model.R")
source("scripts/03_evaluate_results.R")
source("scripts/04_generate_figures.R")
```

Or from the command line:

```bash
Rscript scripts/01_preprocessing.R
Rscript scripts/02_train_model.R
Rscript scripts/03_evaluate_results.R
Rscript scripts/04_generate_figures.R
```

**Before running:** download the three Kaggle datasets per
`data/data_sources.md` and place them in `data/raw/`. The three UCI
datasets are fetched automatically. `01_preprocessing.R` will proceed with
whichever datasets are available and print a clear warning listing any
that are missing.

## What each script reproduces

| Script | Reproduces |
|---|---|
| `01_preprocessing.R` | Table 1 (dataset characteristics: N, features, classes) |
| `02_train_model.R` | Boolean rule generation + ridge regression + BIC ranking (Materials and Methods); 5-fold CV protocol used for Table 3 / Fig. 3 |
| `03_evaluate_results.R` | Table 2 (best rule set R², BIC per dataset); Table 3 (ACC, AUROC, Rule Number, Rule Length for Lung Cancer Prediction and Diagnostic Breast Cancer) |
| `04_generate_figures.R` | Fig. 3 (ROC and PR curves across five binary-target datasets) |

**Known reproduction gaps** (documented in-line in the scripts):
- The paper does not state the exact filtering rule used to reduce the
  Heart Failure Prediction dataset from 918 to 746 records; a plausible
  filter (removing zero `Cholesterol`/`RestingBP`) is applied and logged.
- `balancing` and exact `num_top_rules` values for `rbbr_train()` /
  `rbbr_predictor()` are not explicitly stated in the paper for every
  dataset; documented defaults/assumptions are used (see comments in
  `02_train_model.R`).
- Table 3's DeepRED, REM-D, and ECLAIRE benchmark numbers are external
  tools not reimplemented here; only RBBR's reproduced numbers are
  compared against the paper's reported RBBR row.

## Citation

If you use this workflow, please cite our paper and Dr. Malekpour's RBBR package:

```bibtex
@article{eskandarian2026rbbr,
  title   = {Interpretable Predictive Modeling for Medical Data Using Boolean Rule-aware Regression},
  author  = {Eskandarian, Mohammad and Malekpour, Seyed Amir},
  journal = {bioRxiv},
  year    = {2026},
  doi     = {10.64898/2026.05.14.725084}
}
```

## License

MIT License
