% LoRlambda_Mon.m
% Reproducible entry point for LoRlambda-Mon.
%
% This script loads the dataset, preprocesses it, runs the monitoring
% pipeline, and prints the headline evaluation metrics.  The algorithm
% itself lives in LoR_lambda_Mon.m so it can also be called from tests,
% notebooks, or custom experiments.

clear;
clc;

srcDir = fileparts(mfilename('fullpath'));
addpath(srcDir);

% -------------------------------------------------------------------------
% 1. Configuration and data loading
% -------------------------------------------------------------------------
run(fullfile(srcDir, 'config.m'));

if ~startsWith(dataset.path, filesep)
    dataset.path = fullfile(srcDir, dataset.path);
end

if ~exist(dataset.path, 'file')
    error(['Dataset MAT file not found: %s\n' ...
           'Create it from the bundled CSV with: cd(''%s''); import_dataset_from_csv'], ...
           dataset.path, srcDir);
end

load(dataset.path, 'dataMatrix', 'columnNames');

% data_preprocess reads dataMatrix/columnNames and writes X, X_e, labels,
% normalization metadata, and selected metric names into this workspace.
run(fullfile(srcDir, 'data_preprocess.m'));

T = dataset.batch_size;
w = dataset.window_size;
w_size = dataset.enhanced_window_size;
param = params;
param.visualization_enable = visualization.enable;

if isfield(param, 'random_seed') && ~isempty(param.random_seed)
    rng(param.random_seed);
end

% -------------------------------------------------------------------------
% 2. Run LoRlambda-Mon
% -------------------------------------------------------------------------
[X_e_hat, X_e_hat_normal, Omega, Omega_r, Omega_L, Omega_e, Omega_r_e, ...
    Omega_L_e, r_ranks, r_estimators, r_iscomplete, r_IDX_groups, ...
    r_numClusters, r_B, r_Ord, eigns, IDX_root, IDX_intermedia, ...
    r_incomplete_batchs, Omega_Cauchy_spike, Omega_Cauchy_dip, ...
    Omega_Anomalies, Omega_Anomalies_e, Lambda, Lambda_normalize, ...
    OAM_mu, OAM_A, OAM_beta, Labels_Anomalies_X_hat, ...
    Overhead_cputime_decision, Overhead_cputime_sampling, ...
    Overhead_cputime_inference, Overhead_cputime_modelupdate] = ...
    LoR_lambda_Mon(X, X_e, w, w_size, T, param, columnIDX, columnNames);

% -------------------------------------------------------------------------
% 3. Evaluation in the original metric scale
% -------------------------------------------------------------------------
[M, N] = size(X_e);
num_batch = floor(N / T);

for i = 1:M
    if X_max_min(1, i) > 0
        X(i, :) = X(i, :) * X_max_min(1, i) + X_min(1, i);
        X_e(i, :) = X_e(i, :) * X_max_min(1, i) + X_min(1, i);
        X_e_hat(i, :) = X_e_hat(i, :) * X_max_min(1, i) + X_min(1, i);
        X_e_hat_normal(i, :) = X_e_hat_normal(i, :) * X_max_min(1, i) + X_min(1, i);
    else
        X(i, :) = X(i, :) * X_max(1, i);
        X_e(i, :) = X_e(i, :) * X_max(1, i);
        X_e_hat(i, :) = X_e_hat(i, :) * X_max(1, i);
        X_e_hat_normal(i, :) = X_e_hat_normal(i, :) * X_max(1, i);
    end
end

% Sampling rate and NMAE are evaluated only after the training/enhancement
% window, matching the paper experiment setup.
test_range = w_size * T + 1 : num_batch * T;
Omega_all = double(Omega_e | Omega_Anomalies_e);
perf_sampleratio = sum(Omega_all(:, test_range), 'all') / ((num_batch - w_size) * T * M);

perf_sampleratios = zeros(1, M);
perf_sampleratios_normal = zeros(1, M);
perf_sampleratios_normal_r = zeros(1, M);
perf_sampleratios_normal_L = zeros(1, M);
perf_NMAEs = zeros(1, M);

for i = 1:M
    perf_NMAEs(i) = sum(abs(X_e_hat(i, test_range) - X_e(i, test_range))) / ...
                    sum(abs(X_e(i, test_range)));
    perf_sampleratios(i) = nnz(Omega_all(i, test_range) == 1) / ((num_batch - w_size) * T);
    perf_sampleratios_normal(i) = nnz(Omega_e(i, test_range) == 1) / ((num_batch - w_size) * T);
    perf_sampleratios_normal_r(i) = nnz(Omega_r_e(i, test_range) == 1) / ((num_batch - w_size) * T);
    perf_sampleratios_normal_L(i) = nnz(Omega_L_e(i, test_range) == 1) / ((num_batch - w_size) * T);
end
perf_NMAE = mean(perf_NMAEs);

X_hat = X;
X_hat_normal = X;
X_hat(:, w * T + 1:end) = X_e_hat(:, w_size * T + 1:end);
X_hat_normal(:, w * T + 1:end) = X_e_hat_normal(:, w_size * T + 1:end);

[perf_Precision, perf_Recall, perf_F1, perf_label_anomalies] = ...
    get_perf_OAM_precision_recall(X_hat, Labels_anomalies_X, M, w, T);

avg_Overhead_cputime_decision = mean(Overhead_cputime_decision(1, w_size + 1:num_batch));
avg_Overhead_cputime_sampling = mean(Overhead_cputime_sampling(1, w_size + 1:num_batch));
avg_Overhead_cputime_inference = mean(Overhead_cputime_inference(1, w_size + 1:num_batch));
avg_Overhead_cputime_modelupdate = mean(Overhead_cputime_modelupdate(1, w_size + 1:num_batch));

results = struct( ...
    'sampling_rate', perf_sampleratio, ...
    'NMAE', perf_NMAE, ...
    'precision', perf_Precision, ...
    'recall', perf_Recall, ...
    'F1', perf_F1, ...
    'avg_cpu_decision', avg_Overhead_cputime_decision, ...
    'avg_cpu_sampling', avg_Overhead_cputime_sampling, ...
    'avg_cpu_inference', avg_Overhead_cputime_inference, ...
    'avg_cpu_modelupdate', avg_Overhead_cputime_modelupdate);

disp('=== LoRlambda-Mon summary ===');
disp(results);
