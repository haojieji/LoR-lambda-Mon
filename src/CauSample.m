function results = CauSample(datasetName)
% CAUSAMPLE Run adaptive sampling and reconstruction on a bundled dataset.
%
%   results = CauSample('tpc_c')
%   results = CauSample('online_boutique')
%   results = CauSample('sock_shop')
%   CauSample() selects TPC-C; 'oltp' remains a compatibility alias.
%
%   The runner loads causample_config, prepares metric matrices, calls
%   causample_pipeline, and evaluates sampling ratio, NMAE, anomaly F1,
%   and processing time. Run prepare_causample_data once before TPC-C.
%   See README.md for requirements and docs/data_format.md for input scope.

if nargin < 1 || isempty(datasetName)
    datasetName = 'tpc_c';
end

srcDir = fileparts(mfilename('fullpath'));
addpath(srcDir);

% -------------------------------------------------------------------------
% 1. Configuration and data loading
% -------------------------------------------------------------------------
run(fullfile(srcDir, 'causample_config.m'));

[dataset, params] = causample_dataset_config(datasetName, params);

if ~exist(dataset.path, 'file')
    if strcmp(dataset.type, 'raw') && isfield(dataset, 'csv_path') && exist(dataset.csv_path, 'file')
        error(['Dataset MAT file not found: %s\n' ...
               'Create it from the bundled TPC-C CSV with: cd(''%s''); import_dataset_from_csv'], ...
               dataset.path, srcDir);
    end
    error('Dataset MAT file not found: %s', dataset.path);
end

fprintf('=== CauSample dataset: %s ===\n', dataset.name);

data = load_causample_dataset(dataset, params);
X = data.X;
X_e = data.X_e;
Labels_anomalies_X = data.Labels_anomalies_X;
X_min = data.X_min;
X_max = data.X_max;
X_max_min = data.X_max_min;
columnIDX = data.columnIDX;
columnNames = data.columnNames;
clear data;

T = dataset.batch_size;
w = dataset.window_size;
w_size = T * w - T + 1;
dataset.enhanced_window_size = w_size;

if size(X_e, 1) ~= size(X, 1)
    error('X_e has %d metrics but X has %d metrics.', size(X_e, 1), size(X, 1));
end
if size(Labels_anomalies_X, 1) ~= size(X, 1)
    error('Labels_anomalies_X has %d metrics but X has %d metrics.', ...
          size(Labels_anomalies_X, 1), size(X, 1));
end
if numel(columnNames) ~= size(X, 1)
    error('columnNames has %d entries but X has %d metrics.', numel(columnNames), size(X, 1));
end

param = params;
param.visualization_enable = visualization.enable;

% -------------------------------------------------------------------------
% 2. Run CauSample
% -------------------------------------------------------------------------
[X_e_hat, X_e_hat_normal, Omega_e, Omega_r_e, Omega_L_e, ...
    Omega_Anomalies_e, Times_sample, Overhead_cputime_decision, ...
    Overhead_cputime_sampling, Overhead_cputime_reconstruction, ...
    Overhead_cputime_modelupdate] = ...
    causample_pipeline(X, X_e, w, w_size, T, param, columnIDX, columnNames);

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
% window, matching the experiment setup.
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
    evaluate_anomaly_preservation(X_hat, Labels_anomalies_X, M, w, T);

avg_Overhead_cputime_decision = mean(Overhead_cputime_decision(1, w_size + 1:num_batch));
avg_Overhead_cputime_sampling = mean(Overhead_cputime_sampling(1, w_size + 1:num_batch));
avg_Overhead_cputime_reconstruction = mean(Overhead_cputime_reconstruction(1, w_size + 1:num_batch));
avg_Overhead_cputime_modelupdate = mean(Overhead_cputime_modelupdate(1, w_size + 1:num_batch));
time_sample_permetric = mean(Times_sample(Times_sample ~= 0));

results = struct( ...
    'dataset', dataset.name, ...
    'sampling_ratio', perf_sampleratio, ...
    'NMAE', perf_NMAE, ...
    'perf_Precision', perf_Precision, ...
    'perf_Recall', perf_Recall, ...
    'perf_F1', perf_F1, ...
    'X_e_hat', X_e_hat, ...
    'time_sample_permetric', time_sample_permetric, ...
    'avg_cpu_decision', avg_Overhead_cputime_decision, ...
    'avg_cpu_sampling', avg_Overhead_cputime_sampling, ...
    'avg_cpu_reconstruction', avg_Overhead_cputime_reconstruction, ...
    'avg_cpu_modelupdate', avg_Overhead_cputime_modelupdate);

disp('=== CauSample summary ===');
disp(results);
end
