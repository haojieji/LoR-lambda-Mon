# $LoR\lambda$-Mon
This project implements $LoR\lambda$-Mon, an adaptive monitoring framework designed for reducing the monitoring overhead of fine-grained performance monitoring. The model automatically identifies sparse causal structures of multi-metric, calculate low-rank frequency for each metric to sampling coarse normal state with minimal overhead, calculate lambda frequency to predicting anomalies.

paperID_1224_Appendix.pdf is our appendix including the proof of Theorem 4.1 (Causal Matrix Completion).

## Dataset Description

File: mysql_510_608_withLabels.mat

This dataset is exported from our self-built database performance monitoring platform.
It includes 77 performance metrics, each accompanied by its definition and the corresponding PromQL query.
The first 20 minutes of data are used as the training set, while the remaining 40 minutes serve as the test set.
The fault injection strategies for both training and testing are described in the accompanying shell script.

## Code Structure

LoRlambda_Mon.m:
The core file of our adaptive monitoring model. It implements all modules illustrated in Figure 3 of the paper. Running this script generates visualizations of the sparse causal structure, including DAGs for different metric clusters and the corresponding adjacency matrix.

Sub-functions:
subfunc_clustering_by_SSC.m: Performs the sparsification step.
subfunc_CausalStructureLearning.m: Implements the causal structure learning step.
subfunc_RCMI_ACE.m: Identifies root-cause metrics using the ACE method.
subfunc_robust_AnomalyDetect_Cauchy.m: An existing anomaly detection method based on robust estimation.
subfunc_robust_OAM_LoRLambda.m: Implements the LoRLambda-sampling method (corresponding to Section 5.1).
subfunc_robust_OAM_learn_mbp.m: Learns the Lambda model using the EM algorithm.
subfunc_robust_OAM_update_mbp.m: Incrementally updates the Lambda model with newly collected anomaly data.

