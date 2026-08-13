# data/raw/

# data/raw/

Raw input CSVs go here. They are **not bundled in this repo** (Kaggle/UCI
dataset redistribution terms vary by dataset — see `../data_sources.md`),
so each contributor should download the source file(s) themselves and
place them here before running the scripts in `scripts/` or `examples/`.

For the two worked examples specifically:

- **Lung cancer prediction example** (binary, n=59): download the
  "Lung Cancer Dataset" from Kaggle (yusufdede/lung-cancer-dataset),
  save as `data/raw/lung_cancer_examples.csv`, then run
  `examples/lung_cancer_prediction_example.R`.
- **Three-level lung cancer example** (one-vs-rest, n=1000): download
  the "Cancer Patient Data Sets" dataset from Kaggle, save as
  `data/raw/cancer_patient_data_sets.csv`, then run
  `examples/lung_cancer_three_level_example.R`.

This folder's contents are gitignored by default (`data/raw/*.csv` etc. in
the repo root `.gitignore`) — this `README.md` is the only tracked file
here, so the folder itself still shows up in a fresh clone.
