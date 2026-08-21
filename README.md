# RBBR Applied to Open Medical Datasets

This repository contains analysis code, a reusable pipeline template, and
two worked examples applying the Regression-Based Boolean Rule (RBBR)
method to open medical datasets, as described in our paper:

**"Interpretable Predictive Modeling for Medical Data Using Boolean Rule-aware Regression"**
Mohammad Eskandarian, Seyed Amir Malekpour (bioRxiv, 2026)
Link: <https://www.biorxiv.org/content/10.64898/2026.05.14.725084v1>
DOI: [10.64898/2026.05.14.725084](https://doi.org/10.64898/2026.05.14.725084)

## Authorship and roles

This repository — the reusable preprocessing/training/evaluation pipeline
in `scripts/`, and the two worked examples with their independently-run,
checked-in results in `examples/` and `results/` — was designed and built
by **Mohammad Eskandarian** (TU Bergakademie Freiberg), as the data
management and reproducibility workflow accompanying our paper. This
matches the paper's own Author Contributions statement: *"M.E. performed
the data curation, formal analysis, and validation. M.E. also contributed
to the visualization, writing of the original draft, and review and
editing of the manuscript."*

The RBBR method itself and its general-purpose R package (the modeling
engine this workflow depends on, via `RBBR::rbbr_scaling()`,
`RBBR::rbbr_train()`, and `RBBR::rbbr_predictor()`) were developed
separately by my co-author **Dr. Seyed Amir Malekpour** (CompBioIPM/RBBR,
CRAN), who *"contributed to the conceptualization and methodology"* of the
paper. The package is used here as an external dependency, not authored in
this repository.

## Method
RBBR derives clinically interpretable Boolean rules (conjunctions of up to
three clinical features) from patient data, uses them as inputs to a ridge
regression model to predict binary or multi-class disease outcomes, and
selects the most parsimonious, predictive rule sets via the Bayesian
Information Criterion (BIC).

## Datasets

Six publicly available medical datasets are documented in
[`data/data_sources.md`](./data/data_sources.md) (direct links, feature
descriptions, license terms for each):

1. **Lung Cancer Dataset v1** (Kaggle) — 59 samples, 4 features, binary — see `examples/`
2. **Three-level Lung Cancer** (Kaggle) — 1,000 samples, 23 features, 3-class — see `examples/`
3. **Wisconsin Breast Cancer** (UCI) — 699 samples, 9 features, binary
4. **Diagnostic Breast Cancer** (UCI) — 569 samples, 30 features, binary
5. **Heart Failure Prediction** (Kaggle) — 746 samples (after preparation), 11 features, binary
6. **Early Stage Diabetes Risk** (UCI) — 520 samples, 16 features, binary

The two datasets used in the worked `examples/` (#1 and #2 above) are
**bundled directly in this repo** at `data/raw/` — no download needed to
run either example. The remaining four datasets (#3–#6, used by the
generic `scripts/` template) are **not bundled** — license terms vary by
dataset (some UCI sets are CC BY 4.0; Kaggle sets require checking the
source page). Download those from the links in `data/data_sources.md` and
place them in `data/raw/` before running `scripts/01_preprocessing.R`
against them.

## Contents
- `scripts/01_preprocessing.R` — clean a raw dataset and rescale it via
  `RBBR::rbbr_scaling()`, ready for training. Single-dataset, config-driven:
  point it at one dataset at a time.
- `scripts/02_train_model.R` — 5-fold cross-validated training with
  `RBBR::rbbr_train()`, saving per-fold models and extracted Boolean rules.
- `scripts/03_evaluate_results.R` — held-out performance per fold
  (accuracy, AUC, AUPRC, Cohen's kappa) via `RBBR::rbbr_predictor()`,
  across a range of rule-ensemble sizes.
- `examples/lung_cancer_prediction_example.R` — end-to-end run on the
  59-sample binary Lung Cancer Prediction dataset. Independently recovers
  a rule set close to the paper's Table 2 Rule Set 1 for this dataset
  (Age, AreaQ, Alcohol). See
  [`examples/lung_cancer_prediction_RESULTS.md`](./examples/lung_cancer_prediction_RESULTS.md).
- `examples/lung_cancer_three_level_example.R` — a **one-vs-rest**
  application of RBBR to the 3-class Three-level Lung Cancer dataset
  (three binary models combined by probability argmax) — a different
  modeling strategy from the paper's single ordinal-target rule set for
  this dataset, presented as a complementary analysis rather than a
  reproduction. 95.5% overall accuracy, Cohen's kappa = 0.930. See
  [`examples/lung_cancer_three_level_RESULTS.md`](./examples/lung_cancer_three_level_RESULTS.md).
- `data/data_sources.md` — links, descriptions, and license terms for all
  six datasets.
- `data/raw/` — place downloaded raw CSVs here (gitignored; see `.gitignore`).
- `results/` — checked-in outputs (rules, predictions, metrics, plots)
  for both `examples/` scripts.

## Usage

```r
install.packages("RBBR")  # https://github.com/CompBioIPM/RBBR

# Reusable single-dataset template:
source("scripts/01_preprocessing.R")
source("scripts/02_train_model.R")
source("scripts/03_evaluate_results.R")

# Worked examples (each is self-contained, config header at the top):
source("examples/lung_cancer_prediction_example.R")
source("examples/lung_cancer_three_level_example.R")
```

Or from the command line:

```bash
Rscript scripts/01_preprocessing.R
Rscript scripts/02_train_model.R
Rscript scripts/03_evaluate_results.R

Rscript examples/lung_cancer_prediction_example.R
Rscript examples/lung_cancer_three_level_example.R
```
**Before running:** download the relevant raw dataset(s) per
`data/data_sources.md` and place them in `data/raw/` at the path each
script's config section expects.

## Scope
`scripts/01-03` are a reusable **template** for applying RBBR to one
dataset at a time via `RBBR::rbbr_scaling()` / `rbbr_train()` /
`rbbr_predictor()` — they have not been run as a batch across all six
datasets, and this repo does not claim to reproduce every table or figure
in the paper. The two `examples/` are fully executed, with real held-out
results checked into `results/`. See [`structure.md`](./structure.md) for
the full layout and scope note.

## Citation
If you use this workflow, please cite our paper:
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

MIT License (code). Dataset licenses are separate and documented per-dataset
in `data/data_sources.md`.
