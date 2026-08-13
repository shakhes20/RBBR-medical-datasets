# Data Sources

This project uses six publicly available medical datasets, matching Table 1 of:

> Eskandarian, M., Malekpour, S.A. (2026). *Interpretable Predictive Modeling for
> Medical Data Using Boolean Rule-aware Regression*. bioRxiv.
> doi: [10.64898/2026.05.14.725084](https://doi.org/10.64898/2026.05.14.725084)

Each dataset was used under its respective open license/terms for academic research
purposes. No raw patient-identifiable data is redistributed in this repository
beyond what the original source already makes public.

## 1. Lung Cancer Dataset (Version 1)

* **Source:** Yusuf Dede, Kaggle — *Lung Cancer Dataset, Version 1*
* **Link:** [Kaggle — Lung Cancer Dataset](https://www.kaggle.com/datasets/yusufdede/lung-cancer-dataset)
* **Description:** The dataset contains **59 patient records** with information on
  age, smoking habits, air-pollution-related exposure (`AreaQ`), and alcohol
  consumption (`Alkhol`). The original dataset also contains `Name` and `Surname`,
  which were excluded from the predictive analysis. The target variable, `Result`,
  is binary and indicates the presence (`1`) or absence (`0`) of lung cancer. After
  excluding the identifying name fields, the dataset used in this study contains
  **4 predictive features: Age, Smokes, AreaQ, and Alkhol**, and one binary target
  variable (`Result`).
* **Expected local path:** `data/raw/lung_cancer_examples.csv` (matches
  `examples/lung_cancer_prediction_example.R`'s config)
* **License:** The licensing terms of the original Kaggle dataset should be checked
  on the source page before redistribution.

## 2. Lung Cancer Dataset (Version 2 — Three-Level)

* **Source:** Kaggle — *Lung Cancer Prediction Dataset* (Cancer Patient Data Sets)
* **Link:** https://www.kaggle.com/ (search "Cancer Patient Data Sets")
* **Description:** This dataset contains **1,000 patient records** describing
  demographic characteristics, lifestyle factors, environmental exposures, genetic
  risk factors, and clinical symptoms associated with lung cancer. It includes
  **23 predictive features**, such as age, gender, air pollution, alcohol use,
  occupational hazards, genetic risk, chronic lung disease, smoking, passive
  smoking, chest pain, fatigue, weight loss, shortness of breath, wheezing, and
  other symptoms. The target variable, `Level`, contains **three classes**,
  representing different levels of lung cancer risk — used here as a **multi-class
  classification** problem.
* **Expected local path:** `data/raw/cancer_patient_data_sets.csv` (matches
  `examples/lung_cancer_three_level_example.R`'s config)
* **License:** The licensing terms of the original Kaggle dataset should be checked
  on the source page before redistribution.

## 3. Wisconsin Breast Cancer Dataset

* **Source:** UCI Machine Learning Repository — *Breast Cancer Wisconsin (Original)*
* **Link:** [UCI — Breast Cancer Wisconsin (Original)](https://archive.ics.uci.edu/dataset/15/breast+cancer+wisconsin+original)
* **Description:** **699 patient samples** described by **9 predictive features**
  derived from fine-needle aspiration cytology: `Clump Thickness`, `Uniformity of
  Cell Size`, `Uniformity of Cell Shape`, `Marginal Adhesion`, `Single Epithelial
  Cell Size`, `Bare Nuclei`, `Bland Chromatin`, `Normal Nucleoli`, and `Mitoses`.
  The target variable, `Class`, distinguishes between **benign and malignant**
  tumors (**binary classification**).
* **License:** **CC BY 4.0**. Follow the attribution requirements specified by the
  UCI Machine Learning Repository.

## 4. Diagnostic Breast Cancer Dataset

* **Source:** UCI Machine Learning Repository — *Breast Cancer Wisconsin (Diagnostic)*
* **Link:** [UCI — Breast Cancer Wisconsin (Diagnostic)](https://archive.ics.uci.edu/dataset/17/breast+cancer+wisconsin+diagnostic)
* **Description:** **569 samples** and **30 real-valued predictive features**
  computed from digitized FNA images of breast masses (`radius`, `texture`,
  `perimeter`, `area`, `smoothness`, `compactness`, `concavity`, `concave points`,
  `symmetry`, `fractal dimension`; mean, standard error, and worst values for
  each). The target variable, `Diagnosis`, distinguishes between **benign and
  malignant** tumors (**binary classification**).
* **License:** **CC BY 4.0**. Follow the attribution requirements specified by the
  UCI Machine Learning Repository.

## 5. Heart Failure Prediction Dataset

* **Source:** Kaggle — fedesoriano, *Heart Failure Prediction Dataset*
* **Link:** [Kaggle — Heart Failure Prediction Dataset](https://www.kaggle.com/datasets/fedesoriano/heart-failure-prediction)
* **Description:** Clinical and demographic information used to predict heart
  disease presence. The original dataset contains **918 patient records** and
  **11 features** (`Age`, `Sex`, `ChestPainType`, `RestingBP`, `Cholesterol`,
  `FastingBS`, `RestingECG`, `MaxHR`, `ExerciseAngina`, `Oldpeak`, `ST_Slope`).
  Target: `HeartDisease` (binary). After data preparation, **746 records** were
  used in this study — the paper does not state its exact filtering rule; treat
  the 918→746 reduction as an open reproduction gap if you rebuild this dataset
  from scratch (**binary classification**).
* **License:** The licensing terms of the original Kaggle dataset should be checked
  on the source page before redistribution.

## 6. Early Stage Diabetes Risk Prediction Dataset

* **Source:** UCI Machine Learning Repository — *Early Stage Diabetes Risk Prediction*
* **Link:** [UCI — Early Stage Diabetes Risk Prediction](https://archive.ics.uci.edu/dataset/529/early+stage+diabetes+risk+prediction+dataset)
* **Description:** **520 patient records** and **16 predictive features**
  describing demographics and diabetes-related symptoms (`Age`, `Gender`,
  `Polyuria`, `Polydipsia`, `sudden weight loss`, `weakness`, `Polyphagia`,
  `Genital thrush`, `visual blurring`, `Itching`, `Irritability`,
  `delayed healing`, `partial paresis`, `muscle stiffness`, `Alopecia`,
  `Obesity`). Target: early-stage diabetes risk (**binary classification**).
* **License:** **CC BY 4.0**. Follow the attribution requirements specified by the
  UCI Machine Learning Repository.

## Notes on reuse

All datasets listed above are publicly accessible from their original sources.
Download the data directly from the links above and place the corresponding files
in `data/raw/` (see `data/raw/README.md`) before running the scripts in
`scripts/` or `examples/`.

Datasets #1 and #2 (both Kaggle lung cancer datasets) are the two used in this
repo's `examples/` — their expected local filenames/paths are noted above to
match each example script's config section exactly.

Licensing and attribution requirements differ per dataset; consult the current
license/terms on each original source page before redistributing raw data. This
repository does not redistribute raw patient-identifiable information beyond what
each original provider already makes public.
