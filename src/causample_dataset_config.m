function [dataset, params] = causample_dataset_config(datasetName, params)
%CAUSAMPLE_DATASET_CONFIG Resolve bundled dataset settings and overrides.
%   [dataset, params] = causample_dataset_config(datasetName, params)
%   applies dataset-specific overrides to the supplied algorithm parameters.
%   The default dataset is 'tpc_c'; 'oltp', 'tpcc', and 'TPC-C' are aliases.

if nargin < 1 || isempty(datasetName)
    datasetName = 'tpc_c';
end
if nargin < 2
    params = struct();
end
datasetName = lower(strtrim(char(datasetName)));
if any(strcmp(datasetName, {'oltp', 'tpcc', 'tpc-c'}))
    datasetName = 'tpc_c';
end

srcDir = fileparts(mfilename('fullpath'));
datasetDir = fullfile(srcDir, '..', 'dataset');
dataset = struct();
dataset.id = datasetName;

switch datasetName
    case 'tpc_c'
        dataset.name = 'TPC-C';
        dataset.path = fullfile(datasetDir, 'TPC_C_metrics_with_labels.mat');
        dataset.csv_path = fullfile(datasetDir, 'TPC_C_metrics_with_labels.csv');
        dataset.type = 'raw';
        dataset.batch_size = 100;
        dataset.window_size = 23;
        dataset.max_time_steps = 11600;

    case 'online_boutique'
        dataset.name = 'Online Boutique';
        dataset.path = fullfile(datasetDir, 'BARO_OB_w7T50.mat');
        dataset.type = 'preprocessed';
        dataset.batch_size = 50;
        dataset.window_size = 7;
        dataset.max_time_steps = 700;
        params.theta_r = 5e-6;
        params.theta_c = 1;

    case 'sock_shop'
        dataset.name = 'Sock Shop';
        dataset.path = fullfile(datasetDir, 'BARO_SS_w7T50.mat');
        dataset.type = 'preprocessed';
        dataset.batch_size = 50;
        dataset.window_size = 7;
        dataset.max_time_steps = 700;
        params.theta_r = 5e-7;
        params.theta_c = 1e-4;

    otherwise
        error(['Unknown dataset "%s". Use ''tpc_c'', ''online_boutique'', ' ...
               'or ''sock_shop'' (''oltp'' is an alias for ''tpc_c'').'], datasetName);
end
end
