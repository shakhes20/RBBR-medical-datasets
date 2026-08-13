# data/raw/

Raw input CSVs for the two worked examples are **bundled directly in this
repo**:

- **`lung_cancer_examples.csv`** (59 rows) — used by
  `examples/lung_cancer_prediction_example.R`. Source: "Lung Cancer
  Dataset" on Kaggle (yusufdede/lung-cancer-dataset). Check the Kaggle
  page for current license/redistribution terms.
- **`cancer_patient_data_sets.csv`** (1000 rows) — used by
  `examples/lung_cancer_three_level_example.R`. Source: "Cancer Patient
  Data Sets" on Kaggle. Check the Kaggle page for current
  license/redistribution terms.

Both files are tracked in git (see the explicit exceptions in the repo
root `.gitignore`), so cloning this repo is enough to run either example
script immediately — no manual download needed.

For any of the **other four datasets** referenced in
[`../data_sources.md`](../data_sources.md) (Wisconsin Breast Cancer,
Diagnostic Breast Cancer, Heart Failure Prediction, Early Stage Diabetes
Risk), you'll need to download the source file yourself and place it here
before pointing `scripts/01_preprocessing.R` at it — see
`data_sources.md` for links and license terms per dataset.

