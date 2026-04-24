% Simple validation script for LoRlambda-Mon
% This script checks if the main components can be loaded and executed

try
    fprintf('=== LoRlambda-Mon Validation ===\n');
    
    % Check if config file exists
    if exist('config.m', 'file')
        fprintf('✓ Config file exists\n');
    else
        fprintf('✗ Config file missing\n');
        return;
    end
    
    % Load configuration
    run('config.m');
    fprintf('✓ Configuration loaded successfully\n');
    
    % Check if dataset exists
    if exist(dataset.path, 'file')
        fprintf('✓ Dataset file exists\n');
    else
        fprintf('✗ Dataset file missing: %s\n', dataset.path);
        return;
    end
    
    % Load dataset
    load(dataset.path);
    fprintf('✓ Dataset loaded successfully\n');
    
    % Check if data_preprocess exists
    if exist('data_preprocess.m', 'file')
        fprintf('✓ data_preprocess.m exists\n');
    else
        fprintf('✗ data_preprocess.m missing\n');
        return;
    end
    
    % Run data preprocessing
    run('data_preprocess.m');
    fprintf('✓ Data preprocessing completed\n');
    
    % Check if main function exists
    if exist('LoR_lambda_Mon', 'file')
        fprintf('✓ LoR_lambda_Mon function exists\n');
    else
        fprintf('✗ LoR_lambda_Mon function missing\n');
        return;
    end
    
    fprintf('\n=== All validation checks passed! ===\n');
    fprintf('The LoRlambda-Mon framework is ready to use.\n');
    
catch ME
    fprintf('✗ Validation failed: %s\n', ME.message);
    fprintf('Error in file: %s\n', ME.stack(1).file);
    fprintf('Error at line: %d\n', ME.stack(1).line);
end