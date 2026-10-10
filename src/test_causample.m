function test_causample(datasetName)
%TEST_CAUSAMPLE Run input preflight checks for one dataset.
%
% Usage
%   test_causample
%   test_causample('tpc_c')
%   test_causample('online_boutique')
%   test_causample('sock_shop')
%
% This input preflight delegates loading and preprocessing to
% validate_causample. It does not execute the sampling/reconstruction
% algorithm or verify its results. Run CauSample for the full experiment.

if nargin < 1 || isempty(datasetName)
    datasetName = 'tpc_c';
end

fprintf('=== CauSample input preflight ===\n');
srcDir = fileparts(mfilename('fullpath'));
addpath(srcDir);

fprintf('\n1. Checking configuration and required files...\n');
requiredFiles = {'causample_config.m', 'causample_dataset_config.m', ...
    'causample_pipeline.m', ...
    'CauSample.m', 'import_dataset_from_csv.m', 'prepare_causample_data.m', ...
    'preprocess_metric_data.m', 'load_causample_dataset.m', 'validate_causample.m', ...
    'Sparse_Causal_Structure_Extractor.m', 'Low_Rank_Sampler.m', ...
    'Anomaly_Sampler.m', 'Anomaly_Sampler_Training.m', ...
    'Composite_Sampler.m', 'Fine_Grained_Reconstructor.m', 'Model_Updater.m', ...
    'Anomaly_Detector_Training.m', 'Anomaly_Detector_Window.m', ...
    'Anomaly_Detector_Sampled.m'};
for iFile = 1:numel(requiredFiles)
    assert(exist(fullfile(srcDir, requiredFiles{iFile}), 'file') == 2, ...
        'Required source file is missing: %s', requiredFiles{iFile});
end
fprintf('OK  Source files found\n');

fprintf('\n2. Validating dataset inputs...\n');
assert(validate_causample(datasetName), ...
    'CauSample validation failed. Check the validation output and prepare the dataset before retrying.');

fprintf('\n=== Input preflight passed ===\n');
end
