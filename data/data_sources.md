# Data Sources

This project uses six publicly available medical datasets, matching Table 1 of:

> Eskandarian, M., Malekpour, S.A. (2026). *Interpretable Predictive Modeling for
> Medical Data Using Boolean Rule-aware Regression*. bioRxiv.
> doi: [10.64898/2026.05.14.725084](https://doi.org/10.64898/2026.05.14.725084)

Each dataset was obtained from its respective public source and used for academic
research purposes. No raw patient-identifiable data is redistributed in this
repository beyond what the original source already makes public.

| # | Dataset | Source | N (paper) | Features | Classes | |
|---|---|---|---|---|---|---|
| 1 | Lung Cancer Prediction | Kaggle | 59 | 4 | 2 | |
| 2 | Three-level Lung Cancer | Kaggle | 1000 | 23 | 3 |  |
| 3 | Wisconsin Breast Cancer | UCI | 699 | 9 | 2 | Y |
| 4 | Diagnostic Breast Cancer | UCI | 569 | 30 | 2 |  |
| 5 | Heart Failure Prediction | Kaggle | 746* | 11 | 2 |  |
| 6 | Early Stage Diabetes Risk | UCI | 520 | 16 | 2 | Yes |

\* Paper reports 746 records "after data preparation" from the raw 918-record
Kaggle file; see the filtering note under Heart Failure Prediction below.

## 1. Lung Cancer Prediction Dataset

* **Source:** Kaggle — *Cancer Patient / Lung Cancer Patient Dataset* family
* **Link:** https://www.kaggle.com/datasets/thedevastator/cancer-patients-and-air-pollution-a-new-link
* **Description:** A subset containing **59 samples and 4 features** (Age,
  Smokes, AreaQ, Alcohol) used for binary lung-cancer prediction. This is a
  smaller table than dataset #2 below, even though both trace back to the
  same Kaggle uploader/collection — double-check which specific table/CSV
  on the Kaggle page matches this 59×4 shape before downloading.
* **Expected local path:** `data/raw/lung_cancer_binary.csv`
* **License:** Kaggle dataset license/terms apply; refer to the Kaggle page
  for current terms before redistribution.

## 2. Three-level Lung Cancer Dataset

* **Source:** Kaggle — *Cancer Patient / Lung Cancer Patient Dataset*
* **Link:** https://www.kaggle.com/datasets/thedevastator/cancer-patients-and-air-pollution-a-new-link
* **Description:** **1,000 patient records**, **23 predictive features**
  (demographics, lifestyle, environmental exposure, genetic risk, clinical
  symptoms). Target: 3-level lung cancer risk (Low / Medium / High).
* **Expected local path:** `data/raw/lung_cancer_3level.csv`
* **License:** Kaggle dataset license/terms apply.

## 3. Wisconsin Breast Cancer Dataset

* **Source:** UCI Machine Learning Repository — *Breast Cancer Wisconsin (Original)*
* **Link:** https://archive.ics.uci.edu/dataset/15/breast+cancer+wisconsin+original
* **Description:** **699 samples, 9 features** from FNA cytology (clump
  thickness, cell size/shape uniformity, marginal adhesion, bare nuclei,
  bland chromatin, normal nucleoli, mitoses). Target: benign vs. malignant.
  `Bare_nuclei` contains missing values (imputed via median in
  `01_preprocessing.R`).
* **Downloaded automatically** by `01_preprocessing.R` from:
  `https://archive.ics.uci.edu/static/public/15/breast+cancer+wisconsin+original.zip`
* **License:** CC BY 4.0 (DOI: 10.24432/C5HP4Z)

## 4. Diagnostic Breast Cancer Dataset

* **Source:** UCI Machine Learning Repository — *Breast Cancer Wisconsin (Diagnostic)*
* **Link:** https://archive.ics.uci.edu/dataset/17/breast+cancer+wisconsin+diagnostic
* **Description:** **569 samples, 30 real-valued features** (mean/SE/worst
  of 10 nuclear measurements: radius, texture, perimeter, area, smoothness,
  compactness, concavity, concave points, symmetry, fractal dimension).
  Target: benign vs. malignant. No missing values.
* **Downloaded automatically** by `01_preprocessing.R` from:
  `https://archive.ics.uci.edu/static/public/17/breast+cancer+wisconsin+diagnostic.zip`
* **License:** CC BY 4.0 (DOI: 10.24432/C5DW2B)

## 5. Heart Failure Prediction Dataset

* **Source:** Kaggle — *Heart Failure Prediction Dataset* by fedesoriano
* **Link:** https://www.kaggle.com/datasets/fedesoriano/heart-failure-prediction
* **Description:** **918 raw records, 11 clinical features** (age, sex,
  chest pain type, resting BP, cholesterol, fasting blood sugar, resting
  ECG, max heart rate, exercise angina, Oldpeak, ST slope). Target:
  `HeartDisease`. Combines five public heart-disease datasets (Cleveland,
  Hungary, Switzerland, Long Beach VA, Statlog).
* **Paper uses 746 records after data preparation.** The manuscript does
  not specify the exact filtering rule. `01_preprocessing.R` applies a
  commonly used cleaning step for this dataset (dropping rows with
  physiologically implausible zero values in `Cholesterol` and
  `RestingBP`) and logs the resulting row count; if it does not land at
  exactly 746, treat this as an open reproduction gap and adjust the
  filter once the exact criterion is confirmed.
* **Expected local path:** `data/raw/heart_failure.csv`
* **License:** ODbL 1.0 (Kaggle); underlying UCI data separately licensed.

## 6. Early Stage Diabetes Risk Prediction Dataset

* **Source:** UCI Machine Learning Repository — *Early Stage Diabetes Risk Prediction*
* **Link:** https://archive.ics.uci.edu/dataset/529/early+stage+diabetes+risk+prediction+dataset
* **Description:** **520 patient records, 16 features** collected via
  questionnaire at Sylhet Diabetes Hospital, Bangladesh (age, gender,
  polyuria, polydipsia, sudden weight loss, weakness, polyphagia, genital
  thrush, visual blurring, itching, irritability, delayed healing, partial
  paresis, muscle stiffness, alopecia, obesity). Target: diabetes risk
  (Positive/Negative).
* **Downloaded automatically** by `01_preprocessing.R` from:
  `https://archive.ics.uci.edu/static/public/529/early+stage+diabetes+risk+prediction+dataset.zip`
* **License:** CC BY 4.0 (DOI: 10.24432/C5VG8H)

## Manual download instructions (Kaggle datasets #1, #2, #5)

Kaggle requires an authenticated account and cannot be scraped
programmatically without an API token. To supply these three datasets:

1. Create a free Kaggle account (if you don't have one) and sign in.
2. Visit each dataset link above and download the CSV.
3. Place the file at the **exact path** listed under "Expected local path"
   above, inside `data/raw/`.
4. Re-run `Rscript scripts/01_preprocessing.R`. If your CSV's column names
   differ from what the script expects, `01_preprocessing.R` will raise a
   clear warning/error naming the missing or ambiguous column — update the
   column-mapping block for that dataset accordingly.

Alternatively, if you have a Kaggle API token configured
(`~/.kaggle/kaggle.json`), you can fetch these programmatically with the
[`kaggle` CLI](https://github.com/Kaggle/kaggle-api), e.g.:

```bash
kaggle datasets download -d thedevastator/cancer-patients-and-air-pollution-a-new-link -p data/raw/ --unzip
kaggle datasets download -d fedesoriano/heart-failure-prediction -p data/raw/ --unzip
```

## Notes on Reuse

All datasets are publicly accessible from their respective original
sources. Users of this repository should download the datasets directly
from the links above and place them in `data/raw/` before running the
scripts in `scripts/`. Datasets may have different licensing and
attribution requirements; consult each source's current license/terms
before redistributing raw data. This repository does not redistribute raw
patient-identifiable information.
