# CauSample

CauSample is an adaptive metric sampling framework that uses learned local causal dependencies in two ways:

- **Reduce reconstruction samples:** local parent representations guide child-metric sample budgets, while temporal representations support root metrics.
- **Guide anomaly sampling:** a model of anomaly propagation directs additional sampling between base samples.

This repository contains the MATLAB implementation and selected TPC-C, Online Boutique, and Sock Shop inputs.

## Quick start

Requirements: MATLAB R2021b or later, with the Statistics and Machine Learning, Signal Processing, and Optimization Toolboxes.

Open MATLAB in this repository's `src` directory, then choose a dataset below.

**TPC-C:** the bundled input is CSV. Before the first run, generate `dataset/TPC_C_metrics_with_labels.mat`:

```matlab
prepare_causample_data
results = CauSample('tpc_c');
```

Once the MAT file exists, subsequent runs only require `CauSample('tpc_c')`.

**Online Boutique and Sock Shop:** MAT inputs are already included, so no preparation is required. Run either command directly:

```matlab
results = CauSample('online_boutique');
results = CauSample('sock_shop');
```

`oltp` remains an alias for `tpc_c`. To compare runs, use the same parameters and set `rng(seed, 'twister')` before each call.

### Input checks

After preparing the selected input, run its check from `src`:

```matlab
validate_causample('tpc_c')
validate_causample('online_boutique')
validate_causample('sock_shop')
```

These checks load the inputs and verify source availability and basic dimensions. `test_causample(datasetName)` additionally checks the component-file inventory and asserts that validation succeeds. Neither command runs the sampling and reconstruction algorithm. File checksums are in [SHA256SUMS](SHA256SUMS).

## Datasets

| Dataset | Bundled input | Description |
| --- | --- | --- |
| TPC-C | [TPC_C_metrics_with_labels.csv.gz](dataset/TPC_C_metrics_with_labels.csv.gz) | Database metrics collected under a TPC Benchmark C workload; `prepare_causample_data` creates the MAT input. |
| Online Boutique (OB) | [BARO_OB_w7T50.mat](dataset/BARO_OB_w7T50.mat) | Metrics collected from the Online Boutique microservice application. |
| Sock Shop (SS) | [BARO_SS_w7T50.mat](dataset/BARO_SS_w7T50.mat) | Metrics collected from the Sock Shop microservice application. |

OB/SS inputs originate from the [BARO artifact](https://github.com/phamquiluan/baro). The [dataset directory](dataset/README.md) also contains the original TPC-C CSV files and fault timeline.

## Project guide

Start with [CauSample.m](src/CauSample.m), which invokes [causample_pipeline.m](src/causample_pipeline.m). This README is the reference for running the project, configuring parameters, and interpreting outputs.

| Guide | Contents |
| --- | --- |
| [Source guide](src/README.md) | Paper-to-code mapping, supporting routines, and helper attribution |
| [Algorithm overview](algorithm_overview.md) | Offline and online workflow, internal state, and implementation conventions |
| [Data format and preprocessing](data_format.md) | Input schemas, preprocessing, embedded timelines, and saved MAT metadata |
| [Dataset inventory](dataset/README.md) | Complete file list, provenance, and previews |

## Parameters

[causample_config.m](src/causample_config.m) defines shared settings. [causample_dataset_config.m](src/causample_dataset_config.m) then applies dataset-specific settings and overrides:

| Dataset key | Batch length `T` | Training batches `w` | `theta_r` | `theta_c` |
| --- | ---: | ---: | ---: | ---: |
| `tpc_c` | 100 | 23 | 5e-6 | 0.1 |
| `online_boutique` | 50 | 7 | 5e-6 | 1 |
| `sock_shop` | 50 | 7 | 5e-7 | 1e-4 |

`theta_r` and `theta_c` scale root- and child-metric base budgets. For root metrics, self-embedding supplies overlapping training segments, and the small default `theta_r` values scale the resulting rank-based budgets. Temporal ranks and parent counts are inferred from the data and learned SCS rather than set as hyperparameters. The code's `w` corresponds to the paper's window size `W`.

`yita` controls the residual tolerance in rank maintenance and reconstruction. `params.beta` counts recovery batches, distinct from the anomaly model's decay matrix. `SPIKE_LIMIT`/`DIP_LIMIT` set detection thresholds. ALS and anomaly-model iteration settings control their respective solvers. Set `visualization.enable = false` to disable plots.

## Outputs and evaluation

`results = CauSample(datasetName)` returns a structure and prints its fields. Evaluation uses online observations after training. The returned fields are:

| Field | Meaning |
| --- | --- |
| `dataset` | Dataset name |
| `sampling_ratio` | Fraction of online metric entries marked as sampled; see [sampling ratio](#sampling-ratio) |
| `NMAE` | Normalized mean absolute reconstruction error on the original metric scale |
| `perf_Precision`, `perf_Recall`, `perf_F1` | Anomaly-preservation scores pooled across online metric entries |
| `avg_processing_time` | Sum of the three component CPU-time averages per online batch; see [processing time](#processing-time) |
| `avg_cpu_sampling` | Mean CPU seconds per online batch for the sampling region (Section IV-D, including budget calculation) |
| `avg_cpu_reconstruction` | Mean CPU seconds per online batch for reconstruction (Section IV-E) |
| `avg_cpu_modelupdate` | Mean CPU seconds per online batch for model updating (Section IV-F) |
| `time_sample_permetric` | Mean of nonzero per-batch elapsed sampling times divided by the metric count |
| `X_e_hat` | Reconstructed metric matrix on the original value scale, including the embedded training prefix; its online suffix starts at column `w_size*T+1` |

### Sampling ratio

The numerator counts the union of recorded normal and anomaly sampling indicators over the online period; the denominator is the number of online metric entries. Recovery indicators can overlap, so their counts must not simply be added.

The retained implementation writes base anomaly positions in enhanced time and additional anomaly positions in original time in the same matrix. Evaluation excludes the enhanced training prefix, so the reported ratio can omit acquired anomaly samples. It is a ratio of recorded indicators, not a validated count of all acquired entries.

### Reconstruction error

For each metric, NMAE divides the sum of absolute reconstruction errors by the sum of absolute reference values over online observations, then averages these ratios across metrics. Both reconstruction and reference values are on the original metric scale.

### Anomaly detection

The evaluator detects anomalies in the reconstructed output and compares them with per-metric Cauchy labels. TP, FP, and FN are pooled across metrics and online time points before precision, recall, and F1 are calculated. Undefined zero-denominator scores return zero. The original TPC-C label columns, fault timeline, and upstream BARO fault annotations are not used directly as evaluation labels.

`params.SPIKE_LIMIT`/`DIP_LIMIT` affect online detection and labels generated from raw TPC-C data. They do not replace the saved OB/SS labels or the evaluator's fixed 0.08/0.92 thresholds. Changing these parameters therefore does not redefine the full evaluation protocol.

### Processing time

`avg_processing_time` reports the three-component aggregation used for the **Processing time** results in Section V-A and Figures 8, 11, and 12:

```matlab
avg_processing_time = avg_cpu_sampling + avg_cpu_modelupdate + avg_cpu_reconstruction;
```

It sums the average per-batch processing times for sampling (Section IV-D), reconstruction (Section IV-E), and model updating (Section IV-F). Each component is averaged over the same post-training batches, including zero entries when a stage does not run. Delayed reconstruction is charged to the batch in which it is retried.

The existing timers use MATLAB's [cputime](https://www.mathworks.com/help/matlab/ref/cputime.html), so the unit is **CPU seconds per online batch**. Section V-A describes wall-clock time; this output preserves the plotted component sum and is not an end-to-end wall-clock measurement.

| Component | Code inside the existing timer |
| --- | --- |
| Sampling | In normal batches: base-budget calculation, `Composite_Sampler`, and construction of sample indicators and observations. In recovery batches: full-sampling indicators, data copies, and the recovery counter. |
| Reconstruction | Calls to `Fine_Grained_Reconstructor` for normal batches or delayed recovery, accumulated across local DAGs when applicable. |
| Model updating | Calls to `Model_Updater` in normal batches and when recovery is retried. |

The separate `Low_Rank_Sampler('advance')` and `Low_Rank_Sampler('observe')` calls, their surrounding window/history maintenance, recovery anomaly processing, and recovery intensity-history refresh remain outside these timers. Input loading, offline training, final evaluation, and surrounding batch bookkeeping are also excluded. Sampling operates on the loaded traces, so these timings do not measure live data collection or network waiting.

`time_sample_permetric` uses `tic`/`toc` instead: it divides each normal batch's elapsed sampling time by the metric count, then averages only nonzero entries. Recovery batches contribute zero and are excluded from that average. This separate elapsed-time diagnostic is not part of `avg_processing_time`.

See [LICENSE](LICENSE) for the project license; third-party notices remain in their source files.
