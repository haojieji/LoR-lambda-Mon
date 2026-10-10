# CauSample source guide

Start with `results = CauSample('tpc_c');` after running `prepare_causample_data` in this directory. The other dataset keys are `online_boutique` and `sock_shop`; `oltp` remains a compatibility alias for `tpc_c`. See the [project README](../README.md) for requirements and the [data-format guide](../docs/data_format.md) for input preparation.

## Suggested reading order

1. [CauSample.m](CauSample.m): public runner, output metrics, and timing summaries. [causample_config.m](causample_config.m) holds shared algorithm and visualization parameters; [causample_dataset_config.m](causample_dataset_config.m) supplies dataset keys, paths, sizes, and overrides to both the runner and validator.
2. [preprocess_metric_data.m](preprocess_metric_data.m): metric filtering, per-metric labels, normalization, and overlapping training windows for raw input.
3. [causample_pipeline.m](causample_pipeline.m): the main training and online loop. Read its stages alongside the [paper-to-code component mapping](../docs/algorithm_overview.md).
4. Follow the component files below for the details of each stage.
5. [evaluate_anomaly_preservation.m](evaluate_anomaly_preservation.m): anomaly precision, recall, and F1 under the bundled label protocol. [validate_causample.m](validate_causample.m) and [test_causample.m](test_causample.m) provide input validation and a lightweight smoke check.

## Paper components

| Paper section | Implementation |
| --- | --- |
| 4.1 — Sparse Causal Structure Extractor | [Sparse_Causal_Structure_Extractor.m](Sparse_Causal_Structure_Extractor.m) coordinates [cluster_correlated_metrics.m](cluster_correlated_metrics.m) and [extract_sparse_causal_structure.m](extract_sparse_causal_structure.m), which uses [discover_causal_dependencies.m](discover_causal_dependencies.m). |
| 4.1 — Anomaly Detector | [Anomaly_Detector_Training.m](Anomaly_Detector_Training.m), [Anomaly_Detector_Window.m](Anomaly_Detector_Window.m), and [Anomaly_Detector_Sampled.m](Anomaly_Detector_Sampled.m) keep the enhanced-training, original-window, and sampled-observation paths separate. |
| 4.2 — Low-Rank Sampler | [Low_Rank_Sampler.m](Low_Rank_Sampler.m) maintains temporal histories and rank estimates and computes base sample budgets. |
| 4.3 — Anomaly Sampler | [Anomaly_Sampler_Training.m](Anomaly_Sampler_Training.m) learns the SCS-constrained propagation model offline; [Anomaly_Sampler.m](Anomaly_Sampler.m) evaluates anomaly occurrence rates and normalized probabilities at candidate times. |
| 4.4 — Composite Sampler | [Composite_Sampler.m](Composite_Sampler.m) combines base and anomaly samples; [generate_base_schedule.m](generate_base_schedule.m) spaces the base samples. |
| 4.5 — Fine-Grained Reconstructor | [Fine_Grained_Reconstructor.m](Fine_Grained_Reconstructor.m) handles current-batch and delayed reconstruction, using [fit_reconstruction_coefficients.m](fit_reconstruction_coefficients.m) and [augment_temporal_history.m](augment_temporal_history.m). |
| 4.6 — Model Updater | [Model_Updater.m](Model_Updater.m) updates anomaly propagation parameters from collected events. The pipeline coordinates these updates with temporal-history maintenance in [Low_Rank_Sampler.m](Low_Rank_Sampler.m). |

[causample_pipeline.m](causample_pipeline.m) remains the orchestration layer for these components, including batch state, timing, and visualization. This mapping identifies implementation responsibilities; it does not establish full mathematical or experimental validation against the paper.

## Helpers and attribution

The following helper families support the paper components. Source-file notices remain authoritative for attribution and applicable terms; this guide does not replace those notices or the [project license](../LICENSE), which retains its original copyright attribution.

| Family | Files and recorded attribution |
| --- | --- |
| Sparse representation and graph construction | [OMP_mat_func.m](OMP_mat_func.m), [ols3.m](ols3.m), [BuildAdjacency.m](BuildAdjacency.m), and [thrC.m](thrC.m) provide OMP, regression, adjacency, and thresholding helpers. |
| Spectral clustering and normalization | [SpectralClustering_wo_n.m](SpectralClustering_wo_n.m) cites the normalized spectral clustering method of Ng, Jordan, and Weiss. [litekmeans.m](litekmeans.m) records Xi Peng's attribution, research references, redistribution terms, and an embedded MathWorks notice. [cnormalize_inplace.m](cnormalize_inplace.m) and [vararginParser.m](vararginParser.m) retain Chong You's copyright notices; [cnormalize.m](cnormalize.m) supplies column normalization. |
| KernelICA and causal-discovery support | [contrast_ica.m](contrast_ica.m) and [chol_gauss.m](chol_gauss.m) retain Francis R. Bach's copyright notices. The KernelICA wrapper comments in [discover_causal_dependencies.m](discover_causal_dependencies.m) credit Yasuhiro Sogawa and reference Bach and Jordan's Kernel Independent Component Analysis. |

The following legacy auxiliaries are retained for inspection and are not part of the current main pipeline:

- [refine_causal_structure.m](refine_causal_structure.m), whose KernelICA wrapper comments also credit Yasuhiro Sogawa and reference Bach and Jordan.
- [OMP_ordering_mat_func.m](OMP_ordering_mat_func.m) and [OMP_ordering_mat_func_optimized.m](OMP_ordering_mat_func_optimized.m), alternative ordering helpers.
- [iperm.m](iperm.m), [nmi.m](nmi.m), and [adjusted_rand_index.m](adjusted_rand_index.m), permutation and clustering-score utilities.
- [hungarian.m](hungarian.m), which credits Niclas Borlin and the Carpaneto–Toth assignment algorithm, and [tridecomp.m](tridecomp.m), which credits Matthias Bethge.

Data preparation is separate from these numerical helpers: [prepare_causample_data.m](prepare_causample_data.m) prepares the bundled inputs and [import_dataset_from_csv.m](import_dataset_from_csv.m) imports the labeled TPC-C CSV.
