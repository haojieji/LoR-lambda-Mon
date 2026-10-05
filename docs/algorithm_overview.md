# CauSample algorithm overview

CauSample combines a Low-Rank Sampler and an Anomaly Sampler to collect performance metrics and reconstruct fine-grained data. Both samplers use the same sparse causal structure (SCS), which groups locally correlated metrics and identifies parent-child dependencies. [CauSample.m](../src/CauSample.m) runs a selected dataset; [causample_pipeline.m](../src/causample_pipeline.m) coordinates training, collection, reconstruction, and model updates.

## Two sampling paths

The **Low-Rank Sampler** uses normal metric variations to determine base sampling frequencies. Root metrics use temporal history; child metrics use their local causal dependencies. These representations guide per-metric sampling and support reconstruction of unsampled values.

The **Anomaly Sampler** learns anomaly propagation through self and parent excitation using an SCS-constrained multivariate Hawkes process. Its predicted anomaly probabilities guide additional sampling around likely anomalies. The Composite Sampler combines these observations with the base samples, and newly collected anomalies inform subsequent predictions.

SCS extraction uses the original, fully collected training data. The Anomaly Detector, described within Section 4.1, then prepares normal data and anomaly events for the two sampling paths. After collection, the Fine-Grained Reconstructor combines temporal and causal information and restores sampled values in the final output. The Model Updater incorporates newly collected events and refreshes the representations used by later batches.

## Components and paper sections

All source files below are in `src/`.

| Component | Paper section | Main source files |
| --- | --- | --- |
| Sparse Causal Structure Extractor | 4.1 | [cluster_correlated_metrics.m](../src/cluster_correlated_metrics.m) groups metrics; [extract_sparse_causal_structure.m](../src/extract_sparse_causal_structure.m), [discover_causal_dependencies.m](../src/discover_causal_dependencies.m), and [refine_causal_structure.m](../src/refine_causal_structure.m) (auxiliary) infer and refine their dependencies. |
| Anomaly Detector | Within 4.1 | [detect_training_anomalies.m](../src/detect_training_anomalies.m) prepares enhanced training data; [detect_window_anomalies.m](../src/detect_window_anomalies.m) detects anomalies in a window; [detect_sampled_anomalies.m](../src/detect_sampled_anomalies.m) handles collected observations. |
| Low-Rank Sampler | 4.2 | Frequency calculation and temporal-rank bookkeeping in [causample_pipeline.m](../src/causample_pipeline.m) |
| Anomaly Sampler | 4.3 | [learn_anomaly_model.m](../src/learn_anomaly_model.m) |
| Composite Sampler | 4.4 | [composite_sampler.m](../src/composite_sampler.m), [generate_base_schedule.m](../src/generate_base_schedule.m) |
| Fine-Grained Reconstructor | 4.5 | Reconstruction blocks in [causample_pipeline.m](../src/causample_pipeline.m), [fit_reconstruction_coefficients.m](../src/fit_reconstruction_coefficients.m), [augment_temporal_history.m](../src/augment_temporal_history.m) |
| Model Updater | 4.6 | Update blocks in [causample_pipeline.m](../src/causample_pipeline.m) refresh temporal history for subsequent reconstruction; [update_anomaly_model.m](../src/update_anomaly_model.m) updates anomaly propagation parameters. |

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

[CauSample.m](../src/CauSample.m) selects a dataset, loads [causample_config.m](../src/causample_config.m), invokes preprocessing and the core algorithm, and reports sampling ratio, NMAE, anomaly precision/recall/F1, and timing measurements. These evaluation categories are described in Section 5.1.

[prepare_causample_data.m](../src/prepare_causample_data.m) prepares the bundled OLTP input with [import_dataset_from_csv.m](../src/import_dataset_from_csv.m). [preprocess_metric_data.m](../src/preprocess_metric_data.m) prepares metric matrices, labels, normalization information, and enhanced training segments. [evaluate_anomaly_preservation.m](../src/evaluate_anomaly_preservation.m) compares anomalies in the reconstructed output with the per-metric Cauchy labels. [validate_causample.m](../src/validate_causample.m) checks dataset availability and dimensions.

See the [README](../README.md) for usage, the [data format guide](data_format.md) for input requirements and label protocol, and the [source guide](../src/README.md) for a suggested reading order and helper attributions.
