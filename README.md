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

## Outputs and evaluation

`results = CauSample(datasetName)` returns a structure and prints its fields. Evaluation uses online observations after training. The returned fields are:

| Field | Meaning | Paper section |
| --- | --- | --- |
| `dataset` | Dataset name | — |
| `sampling_ratio` | Fraction of online metric entries marked as sampled | V-A |
| `NMAE` | Normalized mean absolute reconstruction error on the original metric scale | V-A |
| `perf_Precision`, `perf_Recall`, `perf_F1` | Anomaly-preservation scores against per-metric Cauchy labels, pooled across online metric entries | V-A |
| `avg_processing_time` | Mean CPU seconds per online batch: `avg_cpu_sampling + avg_cpu_modelupdate + avg_cpu_reconstruction` | V-A (Processing time) |
| `avg_cpu_sampling` | Mean CPU seconds per online batch for sampling, including budget calculation | IV-D |
| `avg_cpu_reconstruction` | Mean CPU seconds per online batch for reconstruction | IV-E |
| `avg_cpu_modelupdate` | Mean CPU seconds per online batch for model updating | IV-F |
| `time_sample_permetric` | Mean of nonzero per-batch elapsed sampling times divided by the metric count; separate from `avg_processing_time` | — |
| `X_e_hat` | Reconstructed metric matrix on the original value scale, including the embedded training prefix | IV-E |

## Datasets

| Dataset | Bundled input | Description |
| --- | --- | --- |
| TPC-C | [TPC_C_metrics_with_labels.csv.gz](dataset/TPC_C_metrics_with_labels.csv.gz) | Database metrics collected under a TPC Benchmark C workload. |
| Online Boutique (OB) | [BARO_OB_w7T50.mat](dataset/BARO_OB_w7T50.mat) | Metrics collected from the Online Boutique microservice application. |
| Sock Shop (SS) | [BARO_SS_w7T50.mat](dataset/BARO_SS_w7T50.mat) | Metrics collected from the Sock Shop microservice application. |

OB/SS inputs originate from the [BARO artifact](https://github.com/phamquiluan/baro). The [dataset directory](dataset/README.md) also contains the original TPC-C CSV files and fault timeline.

## Project guide

This README covers running the project, configuring parameters, and interpreting outputs. The guides below provide further details.

| Guide | Contents |
| --- | --- |
| [Source guide](src/README.md) | Paper-to-code mapping, supporting routines, and helper attribution |
| [Algorithm overview](algorithm_overview.md) | Offline and online workflow and internal state |
| [Data format and preprocessing](data_format.md) | Input schemas, preprocessing, embedded timelines, and saved MAT metadata |
| [Dataset inventory](dataset/README.md) | Complete file list and previews |

## Parameters

[causample_config.m](src/causample_config.m) defines shared settings. [causample_dataset_config.m](src/causample_dataset_config.m) then applies dataset-specific settings and overrides:

| Dataset key | Batch length `T` | Training batches `w` | Sampling coefficient for root metrics (`theta_r`) | Sampling coefficient for child metrics (`theta_c`) |
| --- | ---: | ---: | ---: | ---: |
| `tpc_c` | 100 | 23 | 5e-6 | 0.1 |
| `online_boutique` | 50 | 7 | 5e-6 | 1 |
| `sock_shop` | 50 | 7 | 5e-7 | 1e-4 |

Following the sampling-coefficient convention in Section V-A (Parameter Settings), `theta_r` and `theta_c` absorb the effects of $\mu$, $c$, and $\delta$ in the base-frequency formulas (Equations (8) and (10), Section IV-B) into tunable coefficients for root and child metrics, respectively. They scale the corresponding base sample budgets to adjust sampling rates.

For root metrics, self-embedding supplies overlapping training segments, and the small default sampling coefficients scale the resulting rank-based budgets. Temporal ranks and parent counts are inferred from the data and learned SCS rather than set as hyperparameters. The code's `w` corresponds to the paper's window size `W`.

`yita` controls the residual tolerance in rank maintenance and reconstruction. `params.beta` counts recovery batches, distinct from the anomaly model's decay matrix. `SPIKE_LIMIT`/`DIP_LIMIT` set detection thresholds. ALS and anomaly-model iteration settings control their respective solvers. Set `visualization.enable = false` to disable plots.

See [LICENSE](LICENSE) for the project license; third-party notices remain in their source files.
