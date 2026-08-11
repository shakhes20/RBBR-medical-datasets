
# RBBR Applied to Open Medical Datasets

This repository contains the analysis code, workflow, and documentation for applying
the Regression-Based Boolean Rule (RBBR) method to six open medical datasets, as
described in our paper:

**"Interpretable Predictive Modeling for Medical Data Using Boolean Rule-aware Regression"**
Mohammad Eskandarian, Amir Malekpour (bioRxiv, 2026)
Link: https://www.biorxiv.org/content/10.64898/2026.05.14.725084v1

## Method
This work uses the RBBR method and its R package implementation, developed by
Dr. Amir Malekpour (CompBioIPM/RBBR), available on CRAN and GitHub:
https://github.com/CompBioIPM/RBBR

## Datasets
This repository documents the preprocessing and analysis workflow applied to six
publicly available medical datasets: [list each dataset name + source link/DOI here].

## Contents
- `scripts/01_preprocessing.R` — data cleaning and preparation
- `scripts/02_train_model.R` — RBBR model training
- `scripts/03_evaluate_results.R` — performance evaluation
- `scripts/04_generate_figures.R` — figures/tables reproduction
- `data/data_sources.md` — links to original open datasets

## Usage
```r
install.packages("RBBR")
source("scripts/01_preprocessing.R")
```

## Citation
If you use this workflow, please cite our paper and Dr. Malekpour's RBBR package.

## License
MIT License
