# $LoR\lambda$-Mon

$LoR\lambda$-Mon is an adaptive monitoring framework designed for low-overhead and robust fine-grained QoS metrics monitoring. At its core lies the **Lo**w-**R**ank and **λ**-based Frequency Estimation **Model** ($LoR\lambda$), which incorporates the following key features:

## Key Features

**Sparse Causal Structure (SCS)**
Reveals that each performance metric is typically influenced by only a few other metrics, forming disjoint Directed Acyclic Graphs (DAGs). This structure enables optimal model complexity to overcome the Bias-Variance Dilemma.

**Root-cause Metric Identification**
Identifies all root-cause metrics within each DAG to enhance monitoring data inference accuracy.

**Low-Rank-based Frequency Estimation Model**

- Calculates sampling frequency for root-cause metrics based on historical low-rank structure
- Determines sampling frequency for effect metrics using Causal Matrix Completion

**Lambda-based Frequency Estimation Model**

- Predicts anomaly occurrence probability by learning inter-anomaly excitation patterns from historical data
- Computes sampling frequency for each metric based on anomaly probability

**Fine-grained Inference**
Reconstructs unsampled data across all metrics using both intra-metric temporal patterns and inter-metric causal relationships.

The complete pipeline is illustrated in Figure 3 of our paper.

## Quick Start

### Prerequisites

- **MATLAB** R2021b or later
- **Standard MATLAB Toolboxes**:
  - Statistics and Machine Learning Toolbox
  - Signal Processing Toolbox
  - Optimization Toolbox

### Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd LoRlambda-Mon
   ```

2. **Download the dataset**:
   - The dataset file `mysql_510_608_withLabels.mat` should be placed in the `dataset/` directory
   - If you don't have the dataset, please refer to the [Dataset](#dataset) section for details

3. **Run the main script**:
   ```matlab
   cd src
   LoRlambda_Mon
   ```

## Usage

### Basic Usage

Simply run the main script to execute the complete monitoring pipeline:

```matlab
% In MATLAB command window
cd('path/to/LoRlambda-Mon/src')
LoRlambda_Mon
```

### Output

Running the script will generate:

1. **Sparse Causal Structure** visualizations
2. **DAGs** for different metric clusters
3. **Adjacency matrices** for causal relationships
4. **Monitoring Results** including:
   - Sampling rate
   - CPU time
   - NMAE (Normalized Mean Absolute Error)
   - Precision, Recall, F1-score

### Configuration

The main script uses default parameters that work well for the provided dataset. You can modify the parameters in the `config.m` file:

```matlab
% Dataset configuration
dataset.path = '../dataset/mysql_510_608_withLabels.mat';
dataset.batch_size = 100; % T
dataset.window_size = 23; % w
dataset.enhanced_window_size = 2201; % w_size

% Algorithm parameters
params.theta_r = 5e-6;      % Sampling rate parameter for root metrics
params.theta_c = 1e-1;      % Sampling rate parameter for child metrics
params.yita = 1e-6;         % Threshold for subspace estimation
params.thr_ACE = 0.1;       % Threshold for ACE method
params.beta = 2;             % Batch size for model updates
params.als_max_iter = 1000;  % Maximum iterations for ALS
params.als_tol = 0.001;      % Tolerance for ALS convergence
params.SPIKE_LIMIT = 0.92;   % Threshold for spike anomalies
params.DIP_LIMIT = 0.08;     % Threshold for dip anomalies
```

## Project Structure

```
LoRlambda-Mon/
├── src/                   % Source code
│   ├── LoRlambda_Mon.m        % Main script
│   ├── data_preprocess.m       % Data preprocessing
│   ├── OMP_ordering_mat_func.m % OMP algorithm
│   ├── ols3.m                  % Ordinary Least Squares
│   ├── litekmeans.m            % K-means clustering
│   ├── cnormalize.m            % Data normalization
│   ├── subfunc_*.m             % Various subfunctions
├── dataset/               % Data files
│   ├── mysql_510_608_withLabels.mat     % Processed dataset
│   ├── combined_metrics_510_608.csv     % Raw metrics data
│   ├── combined_metrics_510_608_with_labels.csv % Labeled data
│   ├── fault_timeline_510_608.csv       % Fault injection timeline
│   └── *.png                     % Visualization figures
├── testbed/               % Testbed scripts
│   ├── fault_orchestrator_paper.sh  % Fault injection script
│   ├── run_oltpbench.sh             % OLTPBench runner
│   └── testbed_framework.png        % Testbed architecture
├── paperID_1224_Appendix.pdf  % Appendix with proofs
└── README.md                % This file
```

## Dataset

The collected data is exported as **combine_metrics_510_608.csv**, with fault injection time ranges recorded in **fault_timeline_510_608.csv**. We employ a Cauchy distribution-based anomaly detection method (SIGMOD'18 [1]) to label data points deviating from normal states. The complete labeled dataset is organized as **combine_metrics_510_608_with_labels.csv**, where:

- `label_1`: Fault injection time range
- `label_2`: Anomaly labels

This processed dataset serves as input to our framework: `mysql_510_608_withLabels.mat`

### Dataset Details

- **76 performance metrics**, each with corresponding definitions and PromQL queries
- **Visualization**: The figure below shows the time series data, with red segments indicating anomalies:

![time_series_visualization_510_608](./dataset/time_series_visualization_510_608.png)

![time_series_visualization_510_608—_label](./dataset/time_series_visualization_510_608_withLabels.png)

The red color denotes the anomaly.

## Testbed

Our testbed architecture is shown below. OLTPBench deployed on a server accesses the MySQL database running on a Kubernetes cluster. We collect numerous metrics using Prometheus to generate a millisecond-level multi-metric dataset.

![testbed_framework](./testbed/testbed_framework.png)

### Fault Injection

We inject three common types of faults:

- Abnormal workload
- CPU saturation
- Memory saturation

The fault injection strategy described in our paper's Evaluation section is implemented in `fault_orchestrator_paper.sh`. Simply run this file after launching OLTPBench `run_oltpbench.sh`.

## Sub-functions

- **`subfunc_clustering_by_SSC.m`**: Performs sparsification using Sparse Subspace Clustering
- **`subfunc_CausalStructureLearning.m`**: Implements causal structure learning
- **`subfunc_RCMI_ACE.m`**: Identifies root-cause metrics using ACE method
- **`subfunc_robust_AnomalyDetect_Cauchy.m`**: Robust anomaly detection based on Cauchy distribution
- **`subfunc_robust_OAM_LoRLambda.m`**: Implements LoRLambda-sampling (Section 5.1)
- **`subfunc_robust_OAM_learn_mbp.m`**: Learns Lambda model using EM algorithm
- **`subfunc_robust_OAM_update_mbp.m`**: Incrementally updates Lambda model with new anomaly data

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Citation

If you use this code in your research, please cite our paper:

```
@inproceedings{LoRlambda-Mon,
  title={$LoR\lambda$-Mon: Low-overhead and Robust QoS Metrics Monitoring based on Sparse Causal Structure},
  author={Your Name and Co-authors},
  booktitle={},
  year={2026}
}
```

## Contributing

We welcome contributions to improve this project. Please feel free to submit issues and pull requests.

## Appendix

**paperID_1224_Appendix.pdf** contains the proof of Theorem 4.1 (Causal Matrix Completion).

