<!-- Suggested additions to the existing repo root README.md -->

## Status note on `scripts/`

`01_preprocessing.R`, `02_train_model.R`, and `03_evaluate_results.R` in
this update are runnable and use the published `RBBR` package
end-to-end (config-driven, relative paths only). Two files referenced
elsewhere in this README are **not yet included**:
`scripts/00_utils.R` and `scripts/04_generate_figures.R`. Until those
land, run `01`-`03` directly rather than via a `00_utils.R` source step.

---

## Additional analysis (beyond the paper)

Separate from the paper-reproduction pipeline above, `examples/`
contains a **standalone, non-reproduction** analysis:

[`examples/lung_cancer_three_level_example.R`](./examples/lung_cancer_three_level_example.R)
applies RBBR to the Three-level Lung Cancer dataset using a **one-vs-rest**
decomposition (three binary RBBR models combined by probability argmax) --
a different modeling strategy from the single ordinal-target rule set
reported in Table 2 of the paper. It reaches 95.5% overall 3-class
accuracy (Cohen's kappa = 0.930) with a distinct, interpretable Boolean
rule set per risk class. Full write-up and discussion of how this relates
to (and differs from) the paper's own Table 2 result:
[`examples/lung_cancer_three_level_RESULTS.md`](./examples/lung_cancer_three_level_RESULTS.md).

This is presented as an extension built on top of the public RBBR
package API, not as a reproduction of the paper's reported numbers for
this dataset.
