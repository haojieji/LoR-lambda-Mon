% Test script for LoRlambda-Mon
% This script tests the functionality and performance of the LoRlambda-Mon framework

function test_lorlambda_mon()
    fprintf('=== LoRlambda-Mon Test Suite ===\n');
    fprintf('\n1. Testing basic functionality...\n');
    
    try
        % Run the main script
        run('LoRlambda_Mon.m');
        fprintf('✓ Basic functionality test passed\n');
    catch ME
        fprintf('✗ Basic functionality test failed: %s\n', ME.message);
        return;
    end
    
    fprintf('\n2. Testing data preprocessing...\n');
    test_data_preprocessing();
    
    fprintf('\n=== Test Suite Complete ===\n');
end

function test_data_preprocessing()
    try
        % Load dataset
        run('config.m');
        load(dataset.path);
        
        % Run data preprocessing
        run('data_preprocess.m');
        
        % Check results
        if exist('X', 'var') && exist('X_e', 'var')
            fprintf('✓ Data preprocessing test passed\n');
            fprintf('  Input data shape: %dx%d\n', size(X, 1), size(X, 2));
            fprintf('  Enhanced data shape: %dx%d\n', size(X_e, 1), size(X_e, 2));
        else
            fprintf('✗ Data preprocessing test failed: Output variables not found\n');
        end
    catch ME
        fprintf('✗ Data preprocessing test failed: %s\n', ME.message);
    end
end