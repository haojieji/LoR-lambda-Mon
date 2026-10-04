# CauSample algorithm overview

CauSample combines a Low-Rank Sampler and an Anomaly Sampler to collect performance metrics and reconstruct fine-grained data. Both samplers use the same sparse causal structure (SCS), which groups locally correlated metrics and identifies parent-child dependencies. The MATLAB entry points retain their historical `LoRlambda_Mon` names.

## Two sampling paths

The **Low-Rank Sampler** uses normal metric variations to determine base sampling frequencies. Root metrics use temporal history; child metrics use their local causal dependencies. These representations guide per-metric sampling and support reconstruction of unsampled values.

The **Anomaly Sampler** learns anomaly propagation through self and parent excitation using an SCS-constrained multivariate Hawkes process. Its predicted event intensities guide additional sampling around likely anomalies. The Composite Sampler combines these observations with the base samples, and newly collected anomalies inform subsequent predictions.

SCS extraction uses the original, fully collected training data. The Anomaly Detector then prepares normal data and anomaly events for the two sampling paths. After collection, the Fine-Grained Reconstructor combines temporal and causal information and restores sampled values in the final output.

## Components and paper sections

All source files below are in `src/`.

| Component | Paper section | Main source files |
| --- | --- | --- |
| Sparse Causal Structure Extractor | 4.1 | [subfunc_clustering_by_SSC.m](../src/subfunc_clustering_by_SSC.m), [OMP_mat_func.m](../src/OMP_mat_func.m), [subfunc_CausalStructureLearning.m](../src/subfunc_CausalStructureLearning.m), [subfunc_CausalDiscovery_Dlingam.m](../src/subfunc_CausalDiscovery_Dlingam.m) |
| Anomaly Detector | Within 4.1 | [subfunc_robust_AnomalyDetect_Cauchy.m](../src/subfunc_robust_AnomalyDetect_Cauchy.m), [subfunc_robust_AnomalyDetect_Cauchy_w.m](../src/subfunc_robust_AnomalyDetect_Cauchy_w.m) |
| Low-Rank Sampler | 4.2 | Frequency calculation and temporal-rank bookkeeping in [LoR_lambda_Mon.m](../src/LoR_lambda_Mon.m) |
| Anomaly Sampler | 4.3 | [subfunc_robust_OAM_learn_mbp.m](../src/subfunc_robust_OAM_learn_mbp.m) |
| Composite Sampler | 4.4 | [subfunc_robust_OAM_LoRLambda_w.m](../src/subfunc_robust_OAM_LoRLambda_w.m), [Get_Array_equalInterval.m](../src/Get_Array_equalInterval.m) |
| Fine-Grained Reconstructor | 4.5 | Reconstruction blocks in [LoR_lambda_Mon.m](../src/LoR_lambda_Mon.m), [subfunc_inferEffect_ALS.m](../src/subfunc_inferEffect_ALS.m), [subfunc_enhance_U.m](../src/subfunc_enhance_U.m) |
| Model Updater | 4.6 | [subfunc_robust_OAM_update_mbp.m](../src/subfunc_robust_OAM_update_mbp.m) |

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

[LoRlambda_Mon.m](../src/LoRlambda_Mon.m) selects a dataset, loads [config.m](../src/config.m), invokes preprocessing and the core algorithm, and reports sampling ratio, NMAE, anomaly precision/recall/F1, and timing measurements. These evaluation categories are described in Section 5.1.

[import_dataset_from_csv.m](../src/import_dataset_from_csv.m) converts input files. [data_preprocess.m](../src/data_preprocess.m) prepares metric matrices, labels, normalization information, and enhanced training segments. [validate_lorlambda_mon.m](../src/validate_lorlambda_mon.m) checks dataset availability and dimensions.

See the [README](../README.md) for usage and [data format guide](data_format.md) for input requirements. Existing third-party research attributions and source notices remain applicable to the SSC/OMP, spectral clustering, KernelICA, and other included helpers.
