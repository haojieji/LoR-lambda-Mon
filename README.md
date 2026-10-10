# CauSample

Code, data, and supplementary proofs for **CauSample**, an adaptive metric sampling framework that uses a sparse causal structure (SCS) in two ways:

- **Causal sampling bound:** local causal correlations guide per-metric sampling frequencies to reduce the samples needed for fine-grained reconstruction.
- **Anomaly sampling:** directed dependencies guide anomaly propagation modeling and additional sampling to capture transient anomalies.

**[Supplementary material: appendix.pdf](appendix.pdf)** contains the complete sampling-bound proof and additional mathematical details.

## Contents

| Directory or file | Contents |
| --- | --- |
| [src/](src/README.md) | MATLAB implementation, suggested reading order, and helper attribution |
| [dataset/](dataset/README.md) | TPC-C trace, fault timeline, and selected Online Boutique and Sock Shop metric data |
| [docs/algorithm_overview.md](docs/algorithm_overview.md) | Mapping from paper components to implementation files |
| [docs/data_format.md](docs/data_format.md) | Data formats, preprocessing, and evaluation labels |
| [appendix.pdf](appendix.pdf) | Supplementary proofs and derivations |
| [SHA256SUMS](SHA256SUMS) | Checksums for the released data and appendix |

This artifact provides the implementation, bundled inputs, and supplementary material for inspection. The OB/SS files contain selected preprocessed traces from BARO; the repository does not include the complete baseline and parameter-sweep scripts needed to regenerate every paper figure.

## Requirements

- MATLAB R2021b or later.
- Statistics and Machine Learning Toolbox, Signal Processing Toolbox, and Optimization Toolbox.

## Quick start

Download the repository and open MATLAB in its `src` directory:

```matlab
cd('path/to/artifact/src')

% Prepare the bundled TPC-C input; the two BARO MAT files are already included.
prepare_causample_data

% Run a dataset and return its evaluation results.
results = CauSample('tpc_c');
% results = CauSample('online_boutique');
% results = CauSample('sock_shop');
```

[CauSample.m](src/CauSample.m) is the public runner, and [causample_pipeline.m](src/causample_pipeline.m) coordinates the core algorithm. `tpc_c` is the canonical TPC-C dataset key; the earlier key `oltp` remains a compatibility alias. The runner reports sampling ratio, normalized mean absolute error (NMAE), anomaly precision/recall/F1, and processing times. To read the implementation alongside Sections 4.1–4.6 of the paper, start with the [component mapping](docs/algorithm_overview.md) and [source guide](src/README.md).

The `.csv.gz` files in [dataset/](dataset/README.md) provide compact downloads for the anonymous mirror. `prepare_causample_data` decompresses `TPC_C_metrics_with_labels.csv.gz` when needed and creates `TPC_C_metrics_with_labels.mat` without changing the bundled inputs.

## Configuration and data checks

Common parameters and visualization settings are in [src/causample_config.m](src/causample_config.m). Dataset keys, file paths, batch/window sizes, and overrides are in [src/causample_dataset_config.m](src/causample_dataset_config.m), shared by the runner and validator. Set `visualization.enable = false` for runs without plots.

```matlab
validate_causample('tpc_c')
validate_causample('online_boutique')
validate_causample('sock_shop')
```

These utilities check input availability and matrix dimensions. [test_causample.m](src/test_causample.m) provides the same input preflight together with source-file checks; it does not execute sampling or reconstruction. Neither replaces an experiment through `CauSample`.

The preprocessing regression check compares the explicit function with the preceding script implementation on synthetic inputs. From the repository root, run:

```matlab
addpath('tests')
test_preprocess_metric_data
```

Full MATLAB experiments and runtime performance were not revalidated during this readability refactor.

## Data sources

The TPC-C data were collected using the TPC Benchmark C workload. Online Boutique and Sock Shop inputs are selected metric traces from the [BARO artifact](https://github.com/phamquiluan/baro). The [dataset inventory](dataset/README.md) records the files, dimensions, and earlier filenames, and the [data-format guide](docs/data_format.md) explains the labels used by the included evaluator.

## License and attribution

See [LICENSE](LICENSE) for the project license, including the original project copyright attribution. Third-party notices and applicable terms remain in their source files; the [source guide](src/README.md#helpers-and-attribution) groups the included helpers and their recorded attributions.
