function results = LoRlambda_Mon(datasetName)
% LoRlambda_Mon Reproducible entry point for LoRlambda-Mon.
%
% Usage
%   LoRlambda_Mon                  % run the default OLTP dataset
%   LoRlambda_Mon('oltp')          % run OLTP explicitly
%   LoRlambda_Mon('online_boutique')
%   LoRlambda_Mon('sock_shop')
%
% The algorithm itself lives in LoR_lambda_Mon.m so it can also be called
% from tests, notebooks, or custom experiments.

if nargin < 1 || isempty(datasetName)
    datasetName = 'oltp';
end
datasetName = lower(strtrim(char(datasetName)));

srcDir = fileparts(mfilename('fullpath'));
addpath(srcDir);

% -------------------------------------------------------------------------
% 1. Configuration and data loading
% -------------------------------------------------------------------------
run(fullfile(srcDir, 'config.m'));

switch datasetName
    case 'oltp'
        dataset = struct();
        dataset.name = 'OLTP';
        dataset.path = '../dataset/mysql_510_608_withLabels.mat';
        dataset.csv_path = '../dataset/combined_metrics_510_608_with_labels.csv';
        dataset.type = 'raw';
        dataset.batch_size = 100;
        dataset.window_size = 23;
        dataset.max_time_steps = 11600;

    case 'online_boutique'
        dataset = struct();
        dataset.name = 'Online Boutique';
        dataset.path = '../dataset/BARO_OB_w7T50.mat';
        dataset.type = 'preprocessed';
        dataset.batch_size = 50;
        dataset.window_size = 7;
        dataset.max_time_steps = 700;
        params.theta_r=5e-6;
        params.theta_c=1;

    case 'sock_shop'
        dataset = struct();
        dataset.name = 'Sock Shop';
        dataset.path = '../dataset/BARO_SS_w7T50.mat';
        dataset.type = 'preprocessed';
        dataset.batch_size = 50;
        dataset.window_size = 7;
        dataset.max_time_steps = 700;
        params.theta_r=5e-7;
        params.theta_c=1e-4;

    otherwise
        error(['Unknown dataset "%s". Use ''oltp'', ''online_boutique'', ' ...
               'or ''sock_shop''.'], datasetName);
end

dataset.path = resolvePath(srcDir, dataset.path);
if isfield(dataset, 'csv_path')
    dataset.csv_path = resolvePath(srcDir, dataset.csv_path);
end

if ~exist(dataset.path, 'file')
    if strcmp(dataset.type, 'raw') && isfield(dataset, 'csv_path') && exist(dataset.csv_path, 'file')
        error(['Dataset MAT file not found: %s\n' ...
               'Create it from the bundled OLTP CSV with: cd(''%s''); import_dataset_from_csv'], ...
               dataset.path, srcDir);
    end
    error('Dataset MAT file not found: %s', dataset.path);
end

fprintf('=== LoRlambda-Mon dataset: %s ===\n', dataset.name);

switch dataset.type
    case 'raw'
        load(dataset.path, 'dataMatrix', 'columnNames');

        % data_preprocess reads dataMatrix/columnNames and writes X, X_e,
        % labels, normalization metadata, and selected metric names into
        % this workspace.
        run(fullfile(srcDir, 'data_preprocess.m'));

    case 'preprocessed'
        requiredVars = {'X', 'X_e', 'Labels_anomalies_X', 'X_min', ...
                        'X_max', 'X_max_min', 'columnIDX', 'columnNames'};
        data = load(dataset.path, requiredVars{:});
        for iVar = 1:numel(requiredVars)
            if ~isfield(data, requiredVars{iVar})
                error('Preprocessed dataset lacks required variable: %s', requiredVars{iVar});
            end
        end

        X = double(data.X);
        X_e = double(data.X_e);
        Labels_anomalies_X = double(data.Labels_anomalies_X);
        X_min = double(data.X_min);
        X_max = double(data.X_max);
        X_max_min = double(data.X_max_min);
        columnIDX = double(data.columnIDX);
        columnNames = string(data.columnNames);

        % Some legacy BARO MAT files keep the original metric-name vector.
        % Align names to the filtered metric rows used by X/X_e here so the
        % rest of the pipeline can use a simple metric-only name vector.
        if numel(columnNames) ~= size(X, 1)
            if numel(columnIDX) == size(X, 1) && max(columnIDX) <= numel(columnNames)
                columnNames = columnNames(columnIDX);
                columnIDX = 1:size(X, 1);
            else
                error('columnNames cannot be aligned with the %d metrics in X.', size(X, 1));
            end
        end

    otherwise
        error('Unsupported dataset type: %s', dataset.type);
end

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
% 2. Run LoRlambda-Mon
% -------------------------------------------------------------------------
[X_e_hat, X_e_hat_normal, Omega_e, Omega_r_e, Omega_L_e, ...
    Omega_Anomalies_e, Times_sample, Overhead_cputime_decision, ...
    Overhead_cputime_sampling, Overhead_cputime_inference, ...
    Overhead_cputime_modelupdate] = ...
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
    get_perf_OAM_precision_recall(X_hat, Labels_anomalies_X, M, w, T);

avg_Overhead_cputime_decision = mean(Overhead_cputime_decision(1, w_size + 1:num_batch));
avg_Overhead_cputime_sampling = mean(Overhead_cputime_sampling(1, w_size + 1:num_batch));
avg_Overhead_cputime_inference = mean(Overhead_cputime_inference(1, w_size + 1:num_batch));
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
    'avg_cpu_inference', avg_Overhead_cputime_inference, ...
    'avg_cpu_modelupdate', avg_Overhead_cputime_modelupdate);

disp('=== LoRlambda-Mon summary ===');
disp(results);
end

function resolvedPath = resolvePath(baseDir, pathText)
pathText = char(pathText);
if startsWith(pathText, filesep) || ...
        ~isempty(regexp(pathText, '^[A-Za-z]:[\\/]', 'once')) || ...
        startsWith(pathText, '\\')
    resolvedPath = pathText;
else
    resolvedPath = fullfile(baseDir, pathText);
end
end
