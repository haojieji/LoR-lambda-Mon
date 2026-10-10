function ok = test_preprocess_metric_data()
%TEST_PREPROCESS_METRIC_DATA Compare the explicit API with the frozen script.
%   From the repository root, run:
%     addpath('tests'); test_preprocess_metric_data
%   This deterministic regression check exercises preprocessing and the shared
%   loader. It does not execute the sampling/reconstruction algorithm.

testDir = fileparts(mfilename('fullpath'));
originalPath = path;
restorePath = onCleanup(@() path(originalPath)); %#ok<NASGU>
addpath(fullfile(testDir, '..', 'src'));
baselinePath = fullfile(testDir, 'fixtures', 'preprocess_metric_data_36b0ca1.m');

% Ten zeros are retained; eleven zeros and a NaN beyond the truncation point
% are rejected. Constant positive/negative metrics cover normalization fallbacks.
t = (1:20)';
withNaN = t;
withNaN(end) = NaN;
dataMatrix = [t, zeros(20, 1), withNaN, ...
    [zeros(11, 1); (1:9)'], [zeros(10, 1); (1:10)'], ...
    3 * ones(20, 1), -3 * ones(20, 1), ...
    [10 + mod((1:18)', 3); 100; 1]];
metricNames = ["trend", "all_zero", "nan_after_limit", "mostly_zero", ...
    "half_zero", "positive_constant", "negative_constant", "spikes_and_dips"];
dataset = struct('batch_size', 3, 'window_size', 2, 'max_time_steps', 17);
params = struct('SPIKE_LIMIT', 0.92, 'DIP_LIMIT', 0.08);
labels = [mod(t, 2), mod(t, 3)];

% Cover every supported header layout, including legacy embedded label columns
% and a column name vector whose orientation must be preserved.
matrices = {dataMatrix, dataMatrix, dataMatrix, [dataMatrix, labels], dataMatrix};
headers = {metricNames, ["timestamp", metricNames], ...
    ["timestamp", metricNames, "label1", "label2"], ...
    ["timestamp", metricNames, "Label_1", "Label_2"], metricNames'};
for iCase = 1:numel(headers)
    expected = runBaseline(matrices{iCase}, headers{iCase}, dataset, params, baselinePath);
    actual = preprocess_metric_data(matrices{iCase}, headers{iCase}, dataset, params);
    assertSameFields(actual, expected);
end

actual = preprocess_metric_data(dataMatrix, metricNames, dataset, params);
assert(isequal(actual.columnIDX, [1, 5, 6, 7, 8]), 'Metric filtering changed.');
assert(isequal(actual.columnNames, metricNames(actual.columnIDX)), 'Metric names are misaligned.');
assert(isequal(size(actual.X), [5, 17]), 'Original trace truncation changed.');
assert(isequal(size(actual.X_e), [5, 21]), 'Enhanced timeline length changed.');
assert(isequal(actual.X_e(:, 1:3), actual.X(:, 1:3)), 'First embedding window changed.');
assert(isequal(actual.X_e(:, 4:6), actual.X(:, 2:4)), 'Overlapping window changed.');
assert(isequal(actual.X_e(:, 13:end), actual.X(:, 7:15)), 'Complete post-training batches changed.');
assert(all(actual.X(3, :) == 1), 'Positive constant normalization changed.');
assert(all(actual.X(4, :) == -3), 'Negative constant normalization changed.');

% A cap above the available length keeps the complete original timeline while
% the enhanced timeline omits its two-sample incomplete final batch.
dataset.max_time_steps = 100;
actual = preprocess_metric_data(dataMatrix, metricNames, dataset, params);
expected = runBaseline(dataMatrix, metricNames, dataset, params, baselinePath);
assertSameFields(actual, expected);
assert(isequal(size(actual.X), [5, 20]) && isequal(size(actual.X_e), [5, 24]), ...
    'Short-input cap or incomplete-tail behavior changed.');

% Exercise caller-supplied thresholds, rather than only the configured defaults.
params.SPIKE_LIMIT = 0.85;
params.DIP_LIMIT = 0.15;
actual = preprocess_metric_data(dataMatrix, metricNames, dataset, params);
expected = runBaseline(dataMatrix, metricNames, dataset, params, baselinePath);
assertSameFields(actual, expected);

testLoader(dataMatrix, metricNames, dataset, params, actual);
ok = true;
fprintf('Preprocessing and dataset-loader regression checks passed.\n');
end

function expected = runBaseline(dataMatrix, columnNames, dataset, params, baselinePath)
% Execute the unchanged script in an isolated workspace with explicit inputs.
run(baselinePath);
expected = struct('X', X, 'X_e', X_e, ...
    'Labels_anomalies_X', Labels_anomalies_X, ...
    'X_min', X_min, 'X_max', X_max, 'X_max_min', X_max_min, ...
    'columnIDX', columnIDX, 'columnNames', columnNames, ...
    'Omega_Cauchy_large', Omega_Cauchy_large, ...
    'Omega_Cauchy_small', Omega_Cauchy_small);
end

function assertSameFields(actual, expected)
% Compare values, classes, and vector orientations without numeric tolerance.
fields = fieldnames(expected);
assert(isequal(sort(fieldnames(actual)), sort(fields)), 'Prepared fields changed.');
for iField = 1:numel(fields)
    field = fields{iField};
    assert(isequaln(actual.(field), expected.(field)), ...
        'Preprocessing differs from the frozen baseline for field %s.', field);
    assert(strcmp(class(actual.(field)), class(expected.(field))), ...
        'Preprocessing changed the class of field %s.', field);
end
end

function testLoader(dataMatrix, columnNames, dataset, params, prepared)
% Check raw loading, MAT field preservation, and both prepared-name layouts.
matPath = [tempname, '.mat'];
removeFixture = onCleanup(@() delete(matPath)); %#ok<NASGU>
save(matPath, 'dataMatrix', 'columnNames');
dataset.path = matPath;
dataset.type = 'raw';
assertSameFields(load_causample_dataset(dataset, params), prepared);

save(matPath, '-struct', 'prepared');
roundTrip = load(matPath);
assertSameFields(roundTrip, prepared);
dataset.type = 'preprocessed';
requiredFields = {'X', 'X_e', 'Labels_anomalies_X', 'X_min', ...
    'X_max', 'X_max_min', 'columnIDX', 'columnNames'};
expected = rmfield(prepared, {'Omega_Cauchy_large', 'Omega_Cauchy_small'});
assertSameFields(load_causample_dataset(dataset, params), expected);

% The legacy layout stores all original names; loading aligns the retained
% names and resets indices exactly as the original runner/validator did.
prepared.columnNames = columnNames;
save(matPath, '-struct', 'prepared');
expected.columnIDX = 1:size(prepared.X, 1);
assertSameFields(load_causample_dataset(dataset, params), expected);
assert(isequal(sort(fieldnames(expected)), sort(requiredFields(:))), ...
    'Unexpected shared-loader fields.');
end
