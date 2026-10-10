function ok = validate_causample(datasetName)
%VALIDATE_CAUSAMPLE Check source availability and prepared input dimensions.
%   This input preflight does not run sampling, reconstruction, or evaluation.
%
% Usage
%   validate_causample
%   validate_causample('tpc_c')
%   validate_causample('online_boutique')
%   validate_causample('sock_shop')

ok = false;

try
    if nargin < 1 || isempty(datasetName)
        datasetName = 'tpc_c';
    end

    fprintf('=== CauSample validation ===\n');

    srcDir = fileparts(mfilename('fullpath'));
    addpath(srcDir);

    configPath = fullfile(srcDir, 'causample_config.m');
    assert(exist(configPath, 'file') == 2, 'causample_config.m is missing.');
    run(configPath);
    fprintf('OK  Configuration loaded\n');

    [dataset, params] = causample_dataset_config(datasetName, params);
    datasetName = dataset.id;

    assert(exist(fullfile(srcDir, 'causample_pipeline.m'), 'file') == 2, ...
        'Core function causample_pipeline.m is missing.');
    assert(exist(fullfile(srcDir, 'CauSample.m'), 'file') == 2, ...
        'Runner function CauSample.m is missing.');
    assert(exist(fullfile(srcDir, 'preprocess_metric_data.m'), 'file') == 2, ...
        'preprocess_metric_data.m is missing.');
    assert(exist(fullfile(srcDir, 'load_causample_dataset.m'), 'file') == 2, ...
        'load_causample_dataset.m is missing.');
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

    data = load_causample_dataset(dataset, params);
    X = data.X;
    X_e = data.X_e;
    Labels_anomalies_X = data.Labels_anomalies_X;
    X_min = data.X_min;
    X_max = data.X_max;
    X_max_min = data.X_max_min;
    columnNames = data.columnNames;
    fprintf('OK  Dataset MAT file loaded and metric names aligned\n');

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
    fprintf('\nAll validation checks passed. Run CauSample(''%s'') for the experiment.\n', datasetName);
    ok = true;
catch ME
    fprintf('Validation failed: %s\n', ME.message);
    if ~isempty(ME.stack)
        fprintf('  at %s:%d\n', ME.stack(1).file, ME.stack(1).line);
    end
end
end
