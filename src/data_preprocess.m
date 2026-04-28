% data_preprocess.m
% Convert the loaded dataset into the matrices expected by LoRlambda-Mon.
%
% Required input variables (usually loaded from the OLTP MAT dataset):
%   dataMatrix  - time-by-metric numeric matrix
%   columnNames - metric names, or the original CSV header including timestamp
%
% Output variables:
%   X                   M-by-N normalized metric matrix
%   X_e                 Enhanced matrix used by the sliding-window model
%   Labels_anomalies_X  Cauchy-based anomaly labels on the original timeline
%   columnIDX           Original metric indices kept after filtering
%   columnNames         Names corresponding to the filtered metric universe
%   X_min/X_max/...     Metadata used to restore the original scale

if ~exist('dataMatrix', 'var') || ~exist('columnNames', 'var')
    error('data_preprocess requires dataMatrix and columnNames in the workspace.');
end

if exist('dataset', 'var')
    T = dataset.batch_size;
    w = dataset.window_size;
    max_time_steps = dataset.max_time_steps;
else
    T = 100;
    w = 23;
    max_time_steps = 11600;
end

if exist('params', 'var')
    SPIKE_LIMIT = params.SPIKE_LIMIT;
    DIP_LIMIT = params.DIP_LIMIT;
else
    SPIKE_LIMIT = 0.92;
    DIP_LIMIT = 0.08;
end

columnNames = string(columnNames);
numDataColumns = size(dataMatrix, 2);
normalizedNames = lower(erase(columnNames, "_"));
hasTrailingLabels = numel(columnNames) >= 3 && ...
    strcmp(normalizedNames(end-1), "label1") && strcmp(normalizedNames(end), "label2");

% Accept either a metric-only name vector or the original CSV header
% [timestamp, metric_1, ..., metric_M, label1, label2].
if numel(columnNames) == numDataColumns + 3
    metricNames = columnNames(2:end-2);
elseif numel(columnNames) == numDataColumns + 1 && hasTrailingLabels
    % Some legacy MAT files store dataMatrix as [metrics, label1, label2].
    metricNames = columnNames(2:end-2);
    dataMatrix = dataMatrix(:, 1:end-2);
    numDataColumns = size(dataMatrix, 2);
elseif numel(columnNames) == numDataColumns + 1
    metricNames = columnNames(2:end);
elseif numel(columnNames) == numDataColumns
    metricNames = columnNames;
else
    error('columnNames has %d entries but dataMatrix has %d columns.', ...
          numel(columnNames), numDataColumns);
end

% Keep only informative, fully observed metrics.  Metrics that are all zero,
% contain NaN, or are zero in more than half of the timeline are removed.
X = [];
columnIDX = [];
for i = 1:numDataColumns
    metricSeries = dataMatrix(:, i);
    if all(metricSeries == 0) || any(isnan(metricSeries))
        continue;
    end
    if nnz(metricSeries == 0) > (size(dataMatrix, 1) / 2)
        continue;
    end

    X = [X metricSeries]; %#ok<AGROW>
    columnIDX = [columnIDX i]; %#ok<AGROW>
end

columnNames = metricNames(columnIDX);

% Reproduce the paper experiment window while avoiding out-of-bounds access
% if a user provides a shorter custom dataset.
max_time_steps = min(max_time_steps, size(X, 1));
X = X(1:max_time_steps, :)';

% Label anomalies before normalization with the same robust Cauchy detector
% used by the online monitor.
Omega_Cauchy_large = zeros(size(X));
Omega_Cauchy_small = zeros(size(X));
Cauchy_Trans = @(x, m) (x >= m) .* x + ...
                       (x < m) .* ((2*m/pi) .* tan((pi*(x - m)) ./ (2*m + eps)) + m);
[~, Omega_Cauchy_large, Omega_Cauchy_small] = ...
    subfunc_robust_AnomalyDetect_Cauchy_w(X, SPIKE_LIMIT, DIP_LIMIT, ...
    Omega_Cauchy_large, Omega_Cauchy_small, Cauchy_Trans);
Labels_anomalies_X = double(Omega_Cauchy_large | Omega_Cauchy_small);

% Normalize each metric to make sampling and reconstruction comparable across
% metrics with different physical units.
X_min = zeros(1, size(X, 1));
X_max_min = zeros(1, size(X, 1));
X_max = zeros(1, size(X, 1));
for i = 1:size(X, 1)
    X_min(1, i) = min(X(i, :));
    X_max(1, i) = max(X(i, :));
    X_max_min(1, i) = X_max(1, i) - X_min(1, i);
    if X_max_min(1, i) > eps
        X(i, :) = (X(i, :) - X_min(1, i)) / X_max_min(1, i);
    elseif X_max(1, i) > 0
        X(i, :) = X(i, :) / X_max(1, i);
    end
end

% Build the enhanced input matrix.  The first T*w samples are transformed
% with a sliding self-embedding window; later data is appended batch by batch.
w_size = T * w - T + 1;
if exist('dataset', 'var')
    dataset.enhanced_window_size = w_size;
end

index = 1;
X_e = [];
for i = 1:w_size
    X_e(:, (index-1)*T+1:index*T) = X(:, i:i+T-1); %#ok<SAGROW>
    index = index + 1;
end

lastStart = size(X, 2) - T + 1;
for i = T*w + 1:T:lastStart
    X_e(:, (index-1)*T+1:index*T) = X(:, i:i+T-1); %#ok<SAGROW>
    index = index + 1;
end
