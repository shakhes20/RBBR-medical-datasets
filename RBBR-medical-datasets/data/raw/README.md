# data/raw/

Raw input CSVs go here. They are **not bundled in this repo** (Kaggle/UCI
dataset redistribution terms vary by dataset), so each contributor should
download the source file(s) themselves and place them here before running
the scripts in `scripts/` or `examples/`.

For the lung cancer one-vs-rest example specifically:

- Download the "Cancer Patient Data Sets" (lung cancer risk levels)
  dataset from Kaggle.
- Save it as `data/raw/cancer_patient_data_sets.csv`.
- Then run `examples/lung_cancer_three_level_example.R` from the repo
  root.

This folder is intentionally excluded from `.gitignore`-tracked data via
this placeholder file only — add your own `.gitignore` entry for
`data/raw/*.csv` if you don't want raw data committed to the repo.
