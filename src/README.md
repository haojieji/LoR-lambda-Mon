# Source guide

This guide maps the paper's components to their MATLAB source files. See the [quick start](../README.md#quick-start) for running the project and the [algorithm overview](../algorithm_overview.md) for workflow and internal state.

## Paper-to-code map

| Paper section | Component | Main implementation |
| --- | --- | --- |
| IV-A | Sparse Causal Structure Extractor | [Sparse_Causal_Structure_Extractor.m](Sparse_Causal_Structure_Extractor.m) calls [cluster_correlated_metrics.m](cluster_correlated_metrics.m), then [extract_sparse_causal_structure.m](extract_sparse_causal_structure.m) and [discover_causal_dependencies.m](discover_causal_dependencies.m). |
| Within IV-A | Anomaly Detector | [Anomaly_Detector_Training.m](Anomaly_Detector_Training.m), [Anomaly_Detector_Window.m](Anomaly_Detector_Window.m), and [Anomaly_Detector_Sampled.m](Anomaly_Detector_Sampled.m) handle training data, original windows, and collected observations separately. |
| IV-B | Low-Rank Sampler | [Low_Rank_Sampler.m](Low_Rank_Sampler.m) maintains temporal history/rank estimates and computes base budgets. |
| IV-C | Anomaly Sampler | [Anomaly_Sampler_Training.m](Anomaly_Sampler_Training.m) learns propagation parameters; [Anomaly_Sampler.m](Anomaly_Sampler.m) evaluates intensities. |
| IV-D | Composite Sampler | [Composite_Sampler.m](Composite_Sampler.m) coordinates base/additional sampling; [generate_base_schedule.m](generate_base_schedule.m) generates base schedules. |
| IV-E | Fine-Grained Reconstructor | [Fine_Grained_Reconstructor.m](Fine_Grained_Reconstructor.m) uses [fit_reconstruction_coefficients.m](fit_reconstruction_coefficients.m) and [augment_temporal_history.m](augment_temporal_history.m). |
| IV-F | Model Updater | [Model_Updater.m](Model_Updater.m) updates the anomaly model from sampled events. |
| V-A | Evaluation | [CauSample.m](CauSample.m) and [evaluate_anomaly_preservation.m](evaluate_anomaly_preservation.m); see [output and metric definitions](../README.md#outputs-and-evaluation). |

## Supporting files

- **Entry point and orchestration:** [CauSample.m](CauSample.m) loads configuration and data, invokes [causample_pipeline.m](causample_pipeline.m), and returns the evaluated results.
- **Configuration:** [causample_config.m](causample_config.m) and [causample_dataset_config.m](causample_dataset_config.m); see [parameter settings](../README.md#parameters).
- **Data preparation:** [prepare_causample_data.m](prepare_causample_data.m) and [import_dataset_from_csv.m](import_dataset_from_csv.m) create the TPC-C input; [load_causample_dataset.m](load_causample_dataset.m) calls [preprocess_metric_data.m](preprocess_metric_data.m) for raw input.
- **Input checks:** [validate_causample.m](validate_causample.m) and [test_causample.m](test_causample.m); see [check instructions and scope](../README.md#input-checks).
- **Visualization:** [plot_causal_structure.m](plot_causal_structure.m).

## Helpers and attribution

Retain each helper's source notice and applicable license:

- Sparse representation and graph construction: `OMP_mat_func.m`, `ols3.m`, `BuildAdjacency.m`, `thrC.m`.
- Clustering: `SpectralClustering_wo_n.m` cites Ng, Jordan, and Weiss; `litekmeans.m` retains Xi Peng's attribution and embedded notices. `cnormalize_inplace.m` and `vararginParser.m` retain Chong You's notices; `cnormalize.m` normalizes columns.
- KernelICA: `contrast_ica.m` and `chol_gauss.m` retain Francis R. Bach's notices. The wrapper in `discover_causal_dependencies.m` credits Yasuhiro Sogawa and references Bach and Jordan.
