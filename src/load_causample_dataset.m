function data = load_causample_dataset(dataset, params)
%LOAD_CAUSAMPLE_DATASET Read raw or prepared metrics for runner and preflight.
%   data = load_causample_dataset(dataset, params) uses the resolved dataset
%   path/type from causample_dataset_config. Raw inputs are preprocessed with
%   the supplied dataset sizes and anomaly thresholds. Prepared inputs retain
%   their saved matrices and are converted to the runner's existing types.
%   Returned columnNames always correspond to the metric rows in X and X_e.

switch dataset.type
    case 'raw'
        raw = load(dataset.path, 'dataMatrix', 'columnNames');
        assert(isfield(raw, 'dataMatrix'), 'MAT file lacks dataMatrix.');
        assert(isfield(raw, 'columnNames'), 'MAT file lacks columnNames.');
        data = preprocess_metric_data(raw.dataMatrix, raw.columnNames, dataset, params);

    case 'preprocessed'
        requiredVars = {'X', 'X_e', 'Labels_anomalies_X', 'X_min', ...
                        'X_max', 'X_max_min', 'columnIDX', 'columnNames'};
        data = load(dataset.path, requiredVars{:});
        for iVar = 1:numel(requiredVars)
            if ~isfield(data, requiredVars{iVar})
                error('Preprocessed dataset lacks required variable: %s', requiredVars{iVar});
            end
        end

        data.X = double(data.X);
        data.X_e = double(data.X_e);
        data.Labels_anomalies_X = double(data.Labels_anomalies_X);
        data.X_min = double(data.X_min);
        data.X_max = double(data.X_max);
        data.X_max_min = double(data.X_max_min);
        data.columnIDX = double(data.columnIDX);
        data.columnNames = string(data.columnNames);

        % Legacy BARO files may save the original metric-name vector. Align
        % it once so both the runner and preflight see the same metric rows.
        if numel(data.columnNames) ~= size(data.X, 1)
            if numel(data.columnIDX) == size(data.X, 1) && ...
                    max(data.columnIDX) <= numel(data.columnNames)
                data.columnNames = data.columnNames(data.columnIDX);
                data.columnIDX = 1:size(data.X, 1);
            else
                error('columnNames cannot be aligned with the %d metrics in X.', size(data.X, 1));
            end
        end

    otherwise
        error('Unsupported dataset type: %s', dataset.type);
end
end
