# CauSample source guide

Start with `results = CauSample('oltp');` after running `prepare_causample_data` in this directory. The other dataset names are `online_boutique` and `sock_shop`. See the [project README](../README.md) for requirements and the [data-format guide](../docs/data_format.md) for input preparation.

## Suggested reading order

1. [CauSample.m](CauSample.m): public runner, dataset settings, output metrics, and timing summaries. [causample_config.m](causample_config.m) holds shared algorithm and visualization parameters.
2. [preprocess_metric_data.m](preprocess_metric_data.m): metric filtering, per-metric labels, normalization, and overlapping training windows for raw input.
3. [causample_pipeline.m](causample_pipeline.m): the main training and online loop. Read its stages alongside the [paper-to-code component mapping](../docs/algorithm_overview.md).
4. Follow the component files below for the details of each stage.
5. [evaluate_anomaly_preservation.m](evaluate_anomaly_preservation.m): anomaly precision, recall, and F1 under the bundled label protocol. [validate_causample.m](validate_causample.m) and [test_causample.m](test_causample.m) provide input validation and a lightweight smoke check.

## Paper components

| Paper section | Implementation |
| --- | --- |
| 4.1 — Sparse Causal Structure Extractor | [cluster_correlated_metrics.m](cluster_correlated_metrics.m), [extract_sparse_causal_structure.m](extract_sparse_causal_structure.m), [discover_causal_dependencies.m](discover_causal_dependencies.m), [refine_causal_structure.m](refine_causal_structure.m) (auxiliary) |
| 4.1 — Anomaly Detector | [detect_training_anomalies.m](detect_training_anomalies.m), [detect_window_anomalies.m](detect_window_anomalies.m), [detect_sampled_anomalies.m](detect_sampled_anomalies.m) |
| 4.2 — Low-Rank Sampler | Sampling-frequency and temporal-rank calculations in [causample_pipeline.m](causample_pipeline.m) |
| 4.3 — Anomaly Sampler | [learn_anomaly_model.m](learn_anomaly_model.m) learns the SCS-constrained anomaly propagation model. |
| 4.4 — Composite Sampler | [composite_sampler.m](composite_sampler.m) combines base and anomaly samples; [generate_base_schedule.m](generate_base_schedule.m) spaces the base samples. |
| 4.5 — Fine-Grained Reconstructor | Reconstruction blocks in [causample_pipeline.m](causample_pipeline.m), [fit_reconstruction_coefficients.m](fit_reconstruction_coefficients.m), [augment_temporal_history.m](augment_temporal_history.m) |
| 4.6 — Model Updater | Representation updates in [causample_pipeline.m](causample_pipeline.m) and anomaly model updates in [update_anomaly_model.m](update_anomaly_model.m) |

## Helpers and attribution

The following helper families support the paper components. Source-file notices remain authoritative for attribution and applicable terms; this guide does not replace those notices or the [project license](../LICENSE), which retains its original copyright attribution.

| Family | Files and recorded attribution |
| --- | --- |
| Sparse representation and graph construction | [OMP_mat_func.m](OMP_mat_func.m), [OMP_ordering_mat_func.m](OMP_ordering_mat_func.m), [OMP_ordering_mat_func_optimized.m](OMP_ordering_mat_func_optimized.m), [ols3.m](ols3.m), [BuildAdjacency.m](BuildAdjacency.m), and [thrC.m](thrC.m) provide OMP, regression, adjacency, and thresholding helpers. |
| Spectral clustering and normalization | [SpectralClustering_wo_n.m](SpectralClustering_wo_n.m) cites the normalized spectral clustering method of Ng, Jordan, and Weiss. [litekmeans.m](litekmeans.m) records Xi Peng's attribution, research references, redistribution terms, and an embedded MathWorks notice. [cnormalize_inplace.m](cnormalize_inplace.m) and [vararginParser.m](vararginParser.m) retain Chong You's copyright notices; [cnormalize.m](cnormalize.m) supplies column normalization. |
| KernelICA and causal-discovery support | [contrast_ica.m](contrast_ica.m) and [chol_gauss.m](chol_gauss.m) retain Francis R. Bach's copyright notices. The KernelICA wrapper comments in [discover_causal_dependencies.m](discover_causal_dependencies.m) and [refine_causal_structure.m](refine_causal_structure.m) credit Yasuhiro Sogawa and reference Bach and Jordan's Kernel Independent Component Analysis. |
| Assignment, decomposition, and clustering scores | [hungarian.m](hungarian.m) credits Niclas Borlin and the Carpaneto–Toth assignment algorithm; [tridecomp.m](tridecomp.m) credits Matthias Bethge. [iperm.m](iperm.m), [nmi.m](nmi.m), and [adjusted_rand_index.m](adjusted_rand_index.m) provide permutation and clustering-score utilities. |

Data preparation is separate from these numerical helpers: [prepare_causample_data.m](prepare_causample_data.m) prepares the bundled inputs and [import_dataset_from_csv.m](import_dataset_from_csv.m) imports OLTP CSV data.
