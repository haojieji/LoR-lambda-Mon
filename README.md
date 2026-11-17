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

## Datasets

| Dataset | Bundled input | Description |
| --- | --- | --- |
| TPC-C | [TPC_C_metrics_with_labels.csv.gz](dataset/TPC_C_metrics_with_labels.csv.gz) | Database metrics collected under a TPC Benchmark C workload; `prepare_causample_data` creates the MAT input. |
| Online Boutique (OB) | [BARO_OB_w7T50.mat](dataset/BARO_OB_w7T50.mat) | Metrics collected from the Online Boutique microservice application. |
| Sock Shop (SS) | [BARO_SS_w7T50.mat](dataset/BARO_SS_w7T50.mat) | Metrics collected from the Sock Shop microservice application. |

OB/SS inputs originate from the [BARO artifact](https://github.com/phamquiluan/baro). The [dataset directory](dataset/README.md) also contains the original TPC-C CSV files and fault timeline.

## Source structure

```text
src/
  CauSample.m                         % Dataset runner
  causample_pipeline.m                % Offline and online workflow
  Sparse_Causal_Structure_Extractor.m  % Local clustering and causal discovery
  Anomaly_Detector_Training.m          % Training-data anomaly separation
  Anomaly_Detector_Window.m            % Window-level anomaly detection
  Anomaly_Detector_Sampled.m           % Detection in collected observations
  Low_Rank_Sampler.m                  % Temporal ranks and base sample budgets
  Anomaly_Sampler_Training.m          % Offline anomaly-model learning
  Anomaly_Sampler.m                   % Anomaly intensity prediction
  Composite_Sampler.m                 % Base and anomaly-guided sampling
  Fine_Grained_Reconstructor.m        % Reconstruction of unsampled values
  Model_Updater.m                     % Online anomaly-model updates
  causample_config.m                  % Shared parameters
  causample_dataset_config.m          % Dataset settings and overrides
```

Start with `CauSample.m` and `causample_pipeline.m`, then follow the component files. The [source guide](src/README.md) maps them to the paper's sections and lists supporting routines.

## Documentation

The following documents are in the repository root:

- [Algorithm overview](algorithm_overview.md): offline and online workflow, notation, implementation conventions, and evaluation outputs.
- [Data format and evaluation](data_format.md): dataset preparation, input variables, preprocessing, training and online timelines, evaluation labels, and input checks.

## Parameters

[causample_config.m](src/causample_config.m) defines shared settings. [causample_dataset_config.m](src/causample_dataset_config.m) then applies dataset-specific settings and overrides:

| Dataset key | Batch length `T` | Training batches `w` | `theta_r` | `theta_c` |
| --- | ---: | ---: | ---: | ---: |
| `tpc_c` | 100 | 23 | 5e-6 | 0.1 |
| `online_boutique` | 50 | 7 | 5e-6 | 1 |
| `sock_shop` | 50 | 7 | 5e-7 | 1e-4 |

`theta_r` and `theta_c` scale root- and child-metric base budgets. For root metrics, self-embedding supplies overlapping training segments, and the small default `theta_r` values scale the resulting rank-based budgets. Temporal ranks and parent counts are inferred from the data and learned SCS rather than set as hyperparameters. The code's `w` corresponds to the paper's window size `W`.

`yita` controls the residual tolerance in rank maintenance and reconstruction. `params.beta` counts recovery batches, distinct from the anomaly model's decay matrix. `SPIKE_LIMIT`/`DIP_LIMIT` set detection thresholds. ALS and anomaly-model iteration settings control their respective solvers. Set `visualization.enable = false` to disable plots.

See [LICENSE](LICENSE) for the project license; third-party notices remain in their source files.
