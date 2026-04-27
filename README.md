# LoRλ-Mon

LoRλ-Mon is a sparse causal structure-driven adaptive multi-metric monitoring framework.  It is designed to minimize monitoring overhead for massive fine-grained metrics while still effectively observing critical, fleeting anomaly events.

The project is organized so readers can reproduce the paper experiment, inspect each algorithm stage, and adapt the code to their own multi-metric monitoring datasets.

## What the project does

LoRλ-Mon reduces monitoring overhead by deciding **which metric values need to be sampled** and when anomaly-sensitive metrics should be observed more frequently.  It combines:

- **Sparse causal structure learning** (**Section 5.1**) to group metrics and learn parent/child relationships.
- **Anomaly separator** (**Section 5.2**) to separate normal metric dynamics from anomaly-driven observations.
- **Low-rank sampling** (**Sections 5.3.1 and 6.2**) with a tighter sampling bound than the optimal sampling bound, reducing the overhead of monitoring normal data.
- **Lambda-based sampling** (**Sections 5.3.2 and 6.2**) based on the observation that anomalies propagate across related performance metrics.  LoRλ-Mon uses a sparse-causal-structure-driven Hawkes process to capture this dynamic anomaly propagation and predict future anomaly probability.
- **Fine-grained inference** to infer missing fine-grained data via temporal and causal correlations across multiple metrics.

See [`docs/algorithm_overview.md`](docs/algorithm_overview.md) for a code-level walkthrough.

## Repository layout

```text
LoR-lambda-Mon/
├── README.md
├── CONTRIBUTING.md
├── docs/
│   ├── algorithm_overview.md
│   └── data_format.md
├── dataset/
│   ├── combined_metrics_510_608.csv
│   ├── combined_metrics_510_608_with_labels.csv
│   ├── fault_timeline_510_608.csv
│   └── *.png
├── src/
│   ├── config.m                         # Experiment constants
│   ├── import_dataset_from_csv.m         # Rebuild ignored MAT dataset
│   ├── validate_lorlambda_mon.m          # Lightweight health check
│   ├── LoRlambda_Mon.m                   # Reproducible paper experiment runner
│   ├── LoR_lambda_Mon.m                  # Core online monitoring algorithm
│   ├── data_preprocess.m                 # Filtering, labeling, normalization
│   └── subfunc_*.m                       # Algorithm components
├── testbed/
│   ├── run_oltpbench.sh
│   ├── fault_orchestrator_paper.sh
│   └── testbed_framework.png
└── paperID_1224_Appendix.pdf
```

## Prerequisites

- MATLAB R2021b or later.
- MATLAB toolboxes used by the experiment:
  - Statistics and Machine Learning Toolbox
  - Signal Processing Toolbox
  - Optimization Toolbox

## Quick start

### 1. Clone the project

```bash
git clone <repository-url>
cd LoR-lambda-Mon
```

### 2. Create the MATLAB dataset file

The repository stores CSV files.  The `.mat` file used by MATLAB is generated locally and ignored by Git.

```matlab
cd('path/to/LoR-lambda-Mon/src')
import_dataset_from_csv
```

This creates:

```text
dataset/mysql_510_608_withLabels.mat
```

More details are in [`docs/data_format.md`](docs/data_format.md).

### 3. Validate the setup

```matlab
cd('path/to/LoR-lambda-Mon/src')
validate_lorlambda_mon
```

### 4. Run the paper experiment

```matlab
cd('path/to/LoR-lambda-Mon/src')
LoRlambda_Mon
```

The runner prints a `results` struct containing the main metrics:

- sampling rate
- NMAE
- precision
- recall
- F1 score
- average CPU overhead for decision, sampling, inference, and model update

## Configuration

Edit [`src/config.m`](src/config.m) to change dataset paths or algorithm parameters.

Common settings:

```matlab
dataset.path = '../dataset/mysql_510_608_withLabels.mat';
dataset.csv_path = '../dataset/combined_metrics_510_608_with_labels.csv';
dataset.batch_size = 100;            % T
dataset.window_size = 23;            % w
dataset.enhanced_window_size = 2201; % T*w - T + 1

params.random_seed = 1;     % Reproducible lambda-sampling randomness
params.theta_r = 5e-6;      % Root/normal-data sampling parameter
params.theta_c = 1e-1;      % Child/effect-metric sampling parameter
params.yita = 1e-6;         % Subspace estimation threshold
params.beta = 2;            % Model update batch interval
params.SPIKE_LIMIT = 0.92;  % Cauchy spike threshold
params.DIP_LIMIT = 0.08;    % Cauchy dip threshold
```

Set `visualization.enable = false` in `src/config.m` for headless runs.

## Dataset and testbed

The experiment dataset contains Prometheus-style MySQL/Kubernetes performance metrics collected from the testbed below.

![Testbed framework](./testbed/testbed_framework.png)

The labeled time series visualization marks anomalous periods in red:

![Time series with labels](./dataset/time_series_visualization_510_608_withLabels.png)

Fault-injection scripts are in [`testbed/`](testbed/):

- `run_oltpbench.sh`: launches OLTPBench workload generation.
- `fault_orchestrator_paper.sh`: injects workload, CPU, and memory faults.

## Main source files

| File | Purpose |
| --- | --- |
| `src/LoRlambda_Mon.m` | End-to-end reproduction script and evaluation summary |
| `src/LoR_lambda_Mon.m` | Core LoRλ-Mon online algorithm |
| `src/data_preprocess.m` | Metric filtering, Cauchy labeling, normalization, enhanced matrix construction |
| `src/subfunc_clustering_by_SSC.m` | Sparse subspace clustering |
| `src/subfunc_CausalStructureLearning.m` | Sparse causal structure learning |
| `src/subfunc_robust_OAM_LoRLambda_w.m` | Low-rank plus lambda-based adaptive sampling |

## Citation

If you use this code in research, please cite the paper.  Replace the placeholder fields below with the final publication metadata.

```bibtex
@inproceedings{LoRlambdaMon,
  title = {$LoR\lambda$-Mon: Low-overhead and Robust QoS Metrics Monitoring based on Sparse Causal Structure},
  author = {Your Name and Co-authors},
  booktitle = {To appear},
  year = {2026}
}
```

## License

This project is released under the MIT License.  See [`LICENSE`](LICENSE).
