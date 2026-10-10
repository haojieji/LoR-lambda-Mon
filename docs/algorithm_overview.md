# CauSample algorithm overview

CauSample combines a Low-Rank Sampler and an Anomaly Sampler to collect performance metrics and reconstruct fine-grained data. Both samplers use the same sparse causal structure (SCS), which groups locally correlated metrics and identifies parent-child dependencies. [CauSample.m](../src/CauSample.m) runs a selected dataset; [causample_pipeline.m](../src/causample_pipeline.m) coordinates training, collection, reconstruction, and model updates.

## Two sampling paths

The **Low-Rank Sampler** uses normal metric variations to determine base sampling frequencies. Root metrics use temporal history; child metrics use their local causal dependencies. These representations guide per-metric sampling and support reconstruction of unsampled values.

The **Anomaly Sampler** learns anomaly propagation through self and parent excitation using an SCS-constrained multivariate Hawkes process. Its predicted anomaly probabilities guide additional sampling around likely anomalies. The Composite Sampler combines these observations with the base samples, and newly collected anomalies inform subsequent predictions.

SCS extraction uses the original, fully collected training data. The Anomaly Detector, described within Section 4.1, then prepares normal data and anomaly events for the two sampling paths. After collection, the Fine-Grained Reconstructor combines temporal and causal information and restores sampled values in the final output. The Model Updater incorporates newly collected anomalies into the propagation model; the Low-Rank Sampler maintains temporal history and rank estimates for subsequent batches.

## Components and paper sections

All source files below are in `src/`.

| Component | Paper section | Main source files |
| --- | --- | --- |
| Sparse Causal Structure Extractor | 4.1 | [Sparse_Causal_Structure_Extractor.m](../src/Sparse_Causal_Structure_Extractor.m) coordinates metric grouping in [cluster_correlated_metrics.m](../src/cluster_correlated_metrics.m) and structure extraction in [extract_sparse_causal_structure.m](../src/extract_sparse_causal_structure.m), which calls [discover_causal_dependencies.m](../src/discover_causal_dependencies.m). |
| Anomaly Detector | Within 4.1 | [Anomaly_Detector_Training.m](../src/Anomaly_Detector_Training.m) prepares enhanced training data; [Anomaly_Detector_Window.m](../src/Anomaly_Detector_Window.m) detects anomalies in an original data window; [Anomaly_Detector_Sampled.m](../src/Anomaly_Detector_Sampled.m) handles collected observations. These remain three separate functions. |
| Low-Rank Sampler | 4.2 | [Low_Rank_Sampler.m](../src/Low_Rank_Sampler.m) maintains temporal histories and rank estimates and calculates base sample budgets. |
| Anomaly Sampler | 4.3 | [Anomaly_Sampler_Training.m](../src/Anomaly_Sampler_Training.m) learns propagation parameters offline; [Anomaly_Sampler.m](../src/Anomaly_Sampler.m) evaluates anomaly occurrence rates and normalized probabilities at candidate times. |
| Composite Sampler | 4.4 | [Composite_Sampler.m](../src/Composite_Sampler.m) combines base and anomaly samples, using [generate_base_schedule.m](../src/generate_base_schedule.m) for the base schedule. |
| Fine-Grained Reconstructor | 4.5 | [Fine_Grained_Reconstructor.m](../src/Fine_Grained_Reconstructor.m) handles current-batch and delayed reconstruction, using [fit_reconstruction_coefficients.m](../src/fit_reconstruction_coefficients.m) and [augment_temporal_history.m](../src/augment_temporal_history.m). |
| Model Updater | 4.6 | [Model_Updater.m](../src/Model_Updater.m) updates anomaly propagation parameters. [causample_pipeline.m](../src/causample_pipeline.m) coordinates this with temporal-history maintenance in [Low_Rank_Sampler.m](../src/Low_Rank_Sampler.m) for later batches. |

The pipeline retains orchestration, batch state, timings, and visualization.
Retained legacy auxiliaries, including
`refine_causal_structure.m`, are outside the main path; the
[source guide](../src/README.md#helpers-and-attribution) identifies them and
preserves their attributions.

## Data and notation

| Symbol in code | Meaning |
| --- | --- |
| `M` | Number of metrics after preprocessing |
| `X` | Normalized metric-by-time matrix |
| `T` | Number of time steps per batch |
| `w` | Training-window batch count, corresponding to paper `W` |
| `w_size` | Enhanced training-batch count, `T*w - T + 1` |
| `X_e` | Enhanced training segments followed by online batches |
| `B`, `Stru`, `Ord` | Weighted adjacency, binary adjacency, and causal order |
| `U_W` | Historical temporal columns used by reconstruction |
| `Omega_e` | Sampling matrix for observations retained as normal values |
| `Omega_Anomalies_e` | Sampling matrix for collected anomalies |

## Entry points and evaluation

[CauSample.m](../src/CauSample.m) loads shared parameters from [causample_config.m](../src/causample_config.m), applies dataset settings through [causample_dataset_config.m](../src/causample_dataset_config.m), invokes preprocessing and the core algorithm, and reports sampling ratio, NMAE, anomaly precision/recall/F1, and timing measurements. These evaluation categories are described in Section 5.1.

[prepare_causample_data.m](../src/prepare_causample_data.m) prepares the bundled TPC-C input with [import_dataset_from_csv.m](../src/import_dataset_from_csv.m). [preprocess_metric_data.m](../src/preprocess_metric_data.m) prepares metric matrices, labels, normalization information, and enhanced training segments. [evaluate_anomaly_preservation.m](../src/evaluate_anomaly_preservation.m) compares anomalies in the reconstructed output with the per-metric Cauchy labels. [validate_causample.m](../src/validate_causample.m) shares the dataset configuration with the runner and checks input availability and dimensions.

See the [README](../README.md) for usage, the [data format guide](data_format.md) for input requirements and label protocol, and the [source guide](../src/README.md) for a suggested reading order and helper attributions.
