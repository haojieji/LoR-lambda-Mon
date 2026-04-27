% validate_lorlambda_mon.m
% Lightweight project health check.  It verifies paths, required variables,
% and preprocessing without running the full experiment.

try
    fprintf('=== LoRlambda-Mon validation ===\n');

    srcDir = fileparts(mfilename('fullpath'));
    addpath(srcDir);

    configPath = fullfile(srcDir, 'config.m');
    assert(exist(configPath, 'file') == 2, 'config.m is missing.');
    run(configPath);
    fprintf('✓ Configuration loaded\n');

    datasetPath = dataset.path;
    csvPath = dataset.csv_path;
    if ~startsWith(datasetPath, filesep)
        datasetPath = fullfile(srcDir, datasetPath);
    end
    if ~startsWith(csvPath, filesep)
        csvPath = fullfile(srcDir, csvPath);
    end

    assert(exist(fullfile(srcDir, 'LoR_lambda_Mon.m'), 'file') == 2, ...
        'Core function LoR_lambda_Mon.m is missing.');
    assert(exist(fullfile(srcDir, 'LoRlambda_Mon.m'), 'file') == 2, ...
        'Runner script LoRlambda_Mon.m is missing.');
    assert(exist(fullfile(srcDir, 'data_preprocess.m'), 'file') == 2, ...
        'data_preprocess.m is missing.');
    fprintf('✓ Source files found\n');

    if exist(datasetPath, 'file') ~= 2
        fprintf('! Dataset MAT file is not present: %s\n', datasetPath);
        if exist(csvPath, 'file') == 2
            fprintf('  Create it with: cd(''%s''); import_dataset_from_csv\n', srcDir);
            fprintf('✓ Source CSV exists: %s\n', csvPath);
        else
            error('Neither MAT dataset nor source CSV exists. Expected CSV: %s', csvPath);
        end
        return;
    end

    load(datasetPath, 'dataMatrix', 'columnNames');
    assert(exist('dataMatrix', 'var') == 1, 'MAT file lacks dataMatrix.');
    assert(exist('columnNames', 'var') == 1, 'MAT file lacks columnNames.');
    fprintf('✓ Dataset MAT file loaded\n');

    run(fullfile(srcDir, 'data_preprocess.m'));
    assert(exist('X', 'var') == 1 && exist('X_e', 'var') == 1, ...
        'Preprocessing did not produce X and X_e.');
    fprintf('✓ Preprocessing completed (%d metrics, %d raw samples, %d enhanced samples)\n', ...
        size(X, 1), size(X, 2), size(X_e, 2));

    fprintf('\nAll validation checks passed. Run LoRlambda_Mon for the full experiment.\n');
catch ME
    fprintf('✗ Validation failed: %s\n', ME.message);
    if ~isempty(ME.stack)
        fprintf('  at %s:%d\n', ME.stack(1).file, ME.stack(1).line);
    end
end
