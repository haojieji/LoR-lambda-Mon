# CauSample

Code, data, and supplementary proofs for **CauSample**, an adaptive metric sampling framework that uses a sparse causal structure (SCS) in two ways:

- **Causal sampling bound:** local causal correlations guide per-metric sampling frequencies to reduce the samples needed for fine-grained reconstruction.
- **Anomaly sampling:** directed dependencies guide anomaly propagation modeling and additional sampling to capture transient anomalies.

**[Supplementary material: appendix.pdf](appendix.pdf)** contains the complete sampling-bound proof and additional mathematical details.

## Contents

| Directory or file | Contents |
| --- | --- |
| [src/](src/) | MATLAB implementation and data preparation utilities |
| [dataset/](dataset/README.md) | TPC-C/OLTP trace, fault timeline, and selected Online Boutique and Sock Shop metric data |
| [docs/algorithm_overview.md](docs/algorithm_overview.md) | Mapping from paper components to implementation files |
| [docs/data_format.md](docs/data_format.md) | Data formats, preprocessing, and evaluation labels |
| [appendix.pdf](appendix.pdf) | Supplementary proofs and derivations |
| [SHA256SUMS](SHA256SUMS) | Checksums for the released data and appendix |

This artifact provides the implementation, bundled inputs, and supplementary material for inspection. The OB/SS files contain selected preprocessed traces from BARO; the repository does not include the complete baseline and parameter-sweep scripts needed to regenerate every paper figure. Existing MATLAB entry-point names are retained for compatibility.

## Requirements

- MATLAB R2021b or later.
- Statistics and Machine Learning Toolbox, Signal Processing Toolbox, and Optimization Toolbox.

## Quick start

Download the repository and open MATLAB in its `src` directory:

```matlab
cd('path/to/artifact/src')

% Prepare the bundled OLTP input; the two BARO MAT files are already included.
prepare_causample_data

% Run a dataset and return its evaluation results.
results = LoRlambda_Mon('oltp');
% results = LoRlambda_Mon('online_boutique');
% results = LoRlambda_Mon('sock_shop');
```

`LoRlambda_Mon.m` is the experiment entry point, and `LoR_lambda_Mon.m` contains the core algorithm. The runner reports sampling ratio, normalized mean absolute error (NMAE), anomaly precision/recall/F1, and processing times. See the [component mapping](docs/algorithm_overview.md) to locate each sampler, reconstruction, and update routine.

The `.csv.gz` files in [dataset/](dataset/README.md) provide compact downloads for the anonymous mirror. `prepare_causample_data` decompresses the labeled CSV when needed and creates the OLTP MAT file without changing the bundled inputs.

## Configuration and data checks

Common parameters and visualization settings are in [src/config.m](src/config.m). Dataset-specific batch/window sizes and overrides are in [src/LoRlambda_Mon.m](src/LoRlambda_Mon.m). Set `visualization.enable = false` for runs without plots.

```matlab
validate_lorlambda_mon('oltp')
validate_lorlambda_mon('online_boutique')
validate_lorlambda_mon('sock_shop')
```

These utilities check input availability and matrix dimensions. They are separate from running the sampling algorithm. The release packaging has been checked for file integrity and links; full MATLAB experiments were not rerun during packaging.

## Data sources

The OLTP data were collected using the TPC Benchmark C (TPC-C) workload. Online Boutique and Sock Shop inputs are selected metric traces from the [BARO artifact](https://github.com/phamquiluan/baro). The [dataset inventory](dataset/README.md) records the files and dimensions, and the [data-format guide](docs/data_format.md) explains the labels used by the included evaluator.

## License and attribution

See [LICENSE](LICENSE) for the project license. Existing third-party notices in the source files are retained; their attribution and applicable terms remain in effect.
