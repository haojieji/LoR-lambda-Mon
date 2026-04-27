function outputPath = import_dataset_from_csv(csvPath, outputPath)
%IMPORT_DATASET_FROM_CSV Build the MAT file consumed by LoRlambda-Mon.
%
% Usage
%   cd src
%   import_dataset_from_csv
%   import_dataset_from_csv('../dataset/combined_metrics_510_608_with_labels.csv')
%
% The generated MAT file is ignored by Git because it can be recreated from
% the CSV.  It contains the variables expected by data_preprocess.m:
%   dataMatrix, columnNames, timestamps, label1, label2.

srcDir = fileparts(mfilename('fullpath'));
run(fullfile(srcDir, 'config.m'));

if nargin < 1 || isempty(csvPath)
    csvPath = dataset.csv_path;
end
if nargin < 2 || isempty(outputPath)
    outputPath = dataset.path;
end

if ~startsWith(csvPath, filesep)
    csvPath = fullfile(srcDir, csvPath);
end
if ~startsWith(outputPath, filesep)
    outputPath = fullfile(srcDir, outputPath);
end

if ~exist(csvPath, 'file')
    error('CSV file not found: %s', csvPath);
end

T = readtable(csvPath, 'VariableNamingRule', 'preserve');
columnNames = string(T.Properties.VariableNames);

if width(T) < 4
    error('Expected timestamp, at least one metric column, label1, and label2.');
end

timestamps = T{:, 1};
label1 = T{:, end-1};
label2 = T{:, end};
dataMatrix = table2array(T(:, 2:end-2));

outputDir = fileparts(outputPath);
if ~isempty(outputDir) && exist(outputDir, 'dir') ~= 7
    mkdir(outputDir);
end

save(outputPath, 'dataMatrix', 'columnNames', 'timestamps', 'label1', 'label2', 'csvPath');
fprintf('Saved LoRlambda-Mon dataset MAT file: %s\n', outputPath);
end
