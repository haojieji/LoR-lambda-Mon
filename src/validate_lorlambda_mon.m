function ok = validate_lorlambda_mon(datasetName)
%VALIDATE_LORLAMBDA_MON Lightweight project health check.
%
% Usage
%   validate_lorlambda_mon
%   validate_lorlambda_mon('oltp')
%   validate_lorlambda_mon('online_boutique')
%   validate_lorlambda_mon('sock_shop')

ok = false;

try
    if nargin < 1 || isempty(datasetName)
        datasetName = 'oltp';
    end
    datasetName = lower(strtrim(char(datasetName)));

    fprintf('=== LoRlambda-Mon validation ===\n');

    srcDir = fileparts(mfilename('fullpath'));
    addpath(srcDir);

    configPath = fullfile(srcDir, 'config.m');
    assert(exist(configPath, 'file') == 2, 'config.m is missing.');
    run(configPath);
    fprintf('OK  Configuration loaded\n');

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

        case 'sock_shop'
            dataset = struct();
            dataset.name = 'Sock Shop';
            dataset.path = '../dataset/BARO_SS_w7T50.mat';
            dataset.type = 'preprocessed';
            dataset.batch_size = 50;
            dataset.window_size = 7;
            dataset.max_time_steps = 700;

        otherwise
            error(['Unknown dataset "%s". Use ''oltp'', ''online_boutique'', ' ...
                   'or ''sock_shop''.'], datasetName);
    end

    dataset.path = resolvePath(srcDir, dataset.path);
    if isfield(dataset, 'csv_path')
        dataset.csv_path = resolvePath(srcDir, dataset.csv_path);
    end

    assert(exist(fullfile(srcDir, 'LoR_lambda_Mon.m'), 'file') == 2, ...
        'Core function LoR_lambda_Mon.m is missing.');
    assert(exist(fullfile(srcDir, 'LoRlambda_Mon.m'), 'file') == 2, ...
        'Runner function LoRlambda_Mon.m is missing.');
    assert(exist(fullfile(srcDir, 'data_preprocess.m'), 'file') == 2, ...
        'data_preprocess.m is missing.');
    fprintf('OK  Source files found\n');

    fprintf('Dataset: %s\n', dataset.name);
    if exist(dataset.path, 'file') ~= 2
        fprintf('! Dataset MAT file is not present: %s\n', dataset.path);
        if strcmp(dataset.type, 'raw') && isfield(dataset, 'csv_path') && exist(dataset.csv_path, 'file') == 2
            fprintf('  Create it with: cd(''%s''); import_dataset_from_csv\n', srcDir);
            fprintf('OK  Source CSV exists: %s\n', dataset.csv_path);
            return;
        end
        error('Dataset MAT file does not exist: %s', dataset.path);
    end

    switch dataset.type
        case 'raw'
            load(dataset.path, 'dataMatrix', 'columnNames');
            assert(exist('dataMatrix', 'var') == 1, 'MAT file lacks dataMatrix.');
            assert(exist('columnNames', 'var') == 1, 'MAT file lacks columnNames.');
            fprintf('OK  Raw dataset MAT file loaded\n');

            run(fullfile(srcDir, 'data_preprocess.m'));

        case 'preprocessed'
            requiredVars = {'X', 'X_e', 'Labels_anomalies_X', 'X_min', ...
                            'X_max', 'X_max_min', 'columnIDX', 'columnNames'};
            data = load(dataset.path, requiredVars{:});
            for iVar = 1:numel(requiredVars)
                assert(isfield(data, requiredVars{iVar}), ...
                    'MAT file lacks %s.', requiredVars{iVar});
            end

            X = double(data.X);
            X_e = double(data.X_e);
            Labels_anomalies_X = double(data.Labels_anomalies_X);
            X_min = double(data.X_min);
            X_max = double(data.X_max);
            X_max_min = double(data.X_max_min);
            columnIDX = double(data.columnIDX);
            columnNames = string(data.columnNames);

            if numel(columnNames) ~= size(X, 1)
                assert(numel(columnIDX) == size(X, 1) && max(columnIDX) <= numel(columnNames), ...
                    'columnNames cannot be aligned with X using columnIDX.');
                columnNames = columnNames(columnIDX);
                columnIDX = 1:size(X, 1); %#ok<NASGU>
            end

            fprintf('OK  Preprocessed dataset MAT file loaded\n');
    end

    T = dataset.batch_size;
    w = dataset.window_size;
    w_size = T * w - T + 1;

    assert(size(X, 1) == numel(columnNames), ...
        'size(X, 1) must match numel(columnNames).');
    assert(size(X_e, 1) == size(X, 1), ...
        'size(X_e, 1) must match size(X, 1).');
    assert(size(Labels_anomalies_X, 1) == size(X, 1), ...
        'size(Labels_anomalies_X, 1) must match size(X, 1).');
    assert(numel(X_min) == size(X, 1) && numel(X_max) == size(X, 1) && ...
           numel(X_max_min) == size(X, 1), ...
        'Normalization vectors must match the number of metrics.');
    assert(w_size == T * w - T + 1, 'Invalid enhanced window size.');
    assert(size(X, 2) >= T * w, 'Dataset must contain at least T*w samples.');
    assert(size(X_e, 2) >= w_size * T, 'X_e is too short for the enhanced window.');

    fprintf('OK  Dimensions verified (%d metrics, %d raw samples, %d enhanced samples)\n', ...
        size(X, 1), size(X, 2), size(X_e, 2));
    fprintf('\nAll validation checks passed. Run LoRlambda_Mon(''%s'') for the experiment.\n', datasetName);
    ok = true;
catch ME
    fprintf('Validation failed: %s\n', ME.message);
    if ~isempty(ME.stack)
        fprintf('  at %s:%d\n', ME.stack(1).file, ME.stack(1).line);
    end
end
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
