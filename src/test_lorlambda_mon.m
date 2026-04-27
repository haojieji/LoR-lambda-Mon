function test_lorlambda_mon()
%TEST_LORLAMBDA_MON Minimal smoke tests for the public scripts.
%
% This test avoids the full LoRlambda-Mon run because the full experiment can
% be slow.  Use LoRlambda_Mon.m for reproduction once validation passes.

fprintf('=== LoRlambda-Mon smoke tests ===\n');
srcDir = fileparts(mfilename('fullpath'));
addpath(srcDir);

fprintf('\n1. Checking configuration and required files...\n');
run(fullfile(srcDir, 'config.m'));
assert(exist(fullfile(srcDir, 'LoR_lambda_Mon.m'), 'file') == 2);
assert(exist(fullfile(srcDir, 'LoRlambda_Mon.m'), 'file') == 2);
assert(exist(fullfile(srcDir, 'import_dataset_from_csv.m'), 'file') == 2);
fprintf('✓ Source files found\n');

fprintf('\n2. Checking dataset availability...\n');
datasetPath = dataset.path;
if ~startsWith(datasetPath, filesep)
    datasetPath = fullfile(srcDir, datasetPath);
end
if exist(datasetPath, 'file') ~= 2
    fprintf('! Dataset MAT file not found. Run import_dataset_from_csv before full tests.\n');
    fprintf('=== Smoke tests complete with dataset warning ===\n');
    return;
end

fprintf('\n3. Testing preprocessing...\n');
load(datasetPath, 'dataMatrix', 'columnNames');
run(fullfile(srcDir, 'data_preprocess.m'));
assert(exist('X', 'var') == 1 && exist('X_e', 'var') == 1);
fprintf('✓ Preprocessing produced X (%dx%d) and X_e (%dx%d)\n', ...
    size(X, 1), size(X, 2), size(X_e, 1), size(X_e, 2));

fprintf('\n=== Smoke tests passed ===\n');
end
