# Repository Structure

```
RBBR-medical-datasets/
├── README.md
├── LICENSE                          MIT (code). Dataset licenses are separate -- see data/data_sources.md
├── structure.md                     this file
├── .gitignore
│
├── data/
│   ├── data_sources.md              links, sample/feature counts, and license terms for all 6 datasets
│   └── raw/
│       ├── README.md                which raw files are bundled vs. must be downloaded
│       ├── lung_cancer_examples.csv         bundled (n=59; binary example)
│       └── cancer_patient_data_sets.csv     bundled (n=1000; three-level example)
│
├── scripts/                         reusable single-dataset pipeline template (config-driven, relative paths)
│   ├── 01_preprocessing.R           clean + RBBR::rbbr_scaling() one raw dataset -> a model-ready CSV
│   ├── 02_train_model.R             5-fold CV training via RBBR::rbbr_train(), saves per-fold models + rules
│   └── 03_evaluate_results.R        per-fold held-out metrics (accuracy, AUC, AUPRC, kappa) via RBBR::rbbr_predictor()
│
├── examples/                        two concrete, executed applications with real, checked-in results
│   ├── lung_cancer_prediction_example.R       binary Lung Cancer Prediction dataset (n=59)
│   ├── lung_cancer_prediction_RESULTS.md      write-up: rules, ROC/AUC, comparison to the paper's Table 2 rule set
│   ├── lung_cancer_three_level_example.R      three-level Lung Cancer Risk dataset (n=1000), one-vs-rest RBBR
│   └── lung_cancer_three_level_RESULTS.md     write-up: rules per class, confusion matrix, inference
│
└── results/
    ├── lung_cancer_prediction_example/
    │   ├── rules.csv                 inferred Boolean rules, ranked by BIC
    │   ├── test_predictions.csv      held-out predictions
    │   ├── summary_metrics.csv       accuracy / AUC / AUPRC
    │   └── roc_curve.png
    └── lung_cancer_three_level_example/
        ├── rules.csv (3 sheets)
        └── confusion_matrix.png
```

## Scope note


`scripts/01-03` are a **reusable single-dataset template** -- point the
config block at any one of the six datasets and run the pipeline. They
have not (yet) been run as a batch across all six datasets, and this repo
does not claim to reproduce every table/figure in the paper. The two
`examples/` are the verified, executed content: each has a real held-out
test run, checked-in results, and an explicit discussion of how it relates
to (or differs from) the paper.
