## Repository Structure

RBBR-medical-datasets/
├── README.md              # Project overview, method, usage instructions
├── LICENSE                # MIT license for this repository's code
├── data/
│   └── data_sources.md    # Links and descriptions of the 6 open datasets used
├── scripts/
│   ├── 01_preprocessing.R # Data cleaning, encoding, normalization
│   ├── 02_train_model.R   # RBBR model training on each dataset
│   ├── 03_evaluate_results.R # Accuracy and other performance metrics
│   └── 04_generate_figures.R # Reproduces paper's figures/tables (optional)
└── results/
    └── (output tables, figures, saved model summaries)
