function outputPath = import_dataset_from_csv(csvPath, outputPath, datasetType)
%IMPORT_DATASET_FROM_CSV Build MAT files consumed by LoRlambda-Mon.
%
% Usage
%   cd src
%   import_dataset_from_csv
%   import_dataset_from_csv('../dataset/combined_metrics_510_608_with_labels.csv')
%   import_dataset_from_csv('path/to/simple_data.csv', ...
%       '../dataset/BARO_OB_w7T50.mat', 'baro')
%
% The default OLTP mode reads [timestamp, metrics..., label1, label2] and
% saves a raw MAT file.  BARO mode reads [timestamp, metrics...] and saves a
% preprocessed MAT file that can be run directly with LoRlambda_Mon.

srcDir = fileparts(mfilename('fullpath'));
run(fullfile(srcDir, 'config.m'));

if nargin < 3 || isempty(datasetType)
    datasetType = 'oltp';
end
datasetType = lower(strtrim(char(datasetType)));

if nargin < 1 || isempty(csvPath)
    csvPath = '../dataset/combined_metrics_510_608_with_labels.csv';
end
if nargin < 2 || isempty(outputPath)
    outputPath = '../dataset/mysql_510_608_withLabels.mat';
end

csvPath = resolvePath(srcDir, csvPath);
outputPath = resolvePath(srcDir, outputPath);

if ~exist(csvPath, 'file')
    error('CSV file not found: %s', csvPath);
end

opts = detectImportOptions(csvPath);
opts.VariableNamingRule = 'preserve';
tbl = readtable(csvPath, opts);
rawColumnNames = string(tbl.Properties.VariableNames);

switch datasetType
    case 'oltp'
        if width(tbl) < 4
            error('OLTP CSV must contain timestamp, at least one metric, label1, and label2.');
        end

        timestamps = tbl{:, 1};
        label1 = tbl{:, end-1};
        label2 = tbl{:, end};
        dataMatrix = table2array(tbl(:, 2:end-2));
        columnNames = rawColumnNames;

        outputDir = fileparts(outputPath);
        if ~isempty(outputDir) && exist(outputDir, 'dir') ~= 7
            mkdir(outputDir);
        end

        save(outputPath, 'dataMatrix', 'columnNames', 'timestamps', ...
            'label1', 'label2', 'csvPath');

    case 'baro'
        if width(tbl) < 2
            error('BARO CSV must contain timestamp and at least one metric column.');
        end

        timestamps = tbl{:, 1};
        timeVector = parseTimeVector(timestamps);
        dataMatrix = table2array(tbl(:, 2:end));
        columnNames = rawColumnNames(2:end);

        dataset = struct();
        dataset.batch_size = 50;
        dataset.window_size = 7;
        dataset.max_time_steps = 700;

        run(fullfile(srcDir, 'data_preprocess.m'));

        outputDir = fileparts(outputPath);
        if ~isempty(outputDir) && exist(outputDir, 'dir') ~= 7
            mkdir(outputDir);
        end

        save(outputPath, 'dataMatrix', 'rawColumnNames', 'columnNames', ...
            'timestamps', 'timeVector', 'csvPath', 'X', 'X_e', ...
            'Labels_anomalies_X', 'X_min', 'X_max', 'X_max_min', ...
            'columnIDX', 'Omega_Cauchy_large', 'Omega_Cauchy_small');

    otherwise
        error('Unknown dataset type "%s". Use ''oltp'' or ''baro''.', datasetType);
end

fprintf('Saved LoRlambda-Mon dataset MAT file: %s\n', outputPath);
end

function timeVector = parseTimeVector(timeStamps)
try
    timeVector = datetime(timeStamps, 'ConvertFrom', 'excel');
catch
    try
        timeVector = datetime(timeStamps, 'ConvertFrom', 'datenum');
    catch
        try
            timeVector = datetime(timeStamps, 'ConvertFrom', 'posixtime');
        catch
            timeVector = timeStamps;
        end
    end
end
end

function resolvedPath = resolvePath(baseDir, pathText)
pathText = char(pathText);
if startsWith(pathText, filesep) || ...
        ~isempty(regexp(pathText, '^[A-Za-z]:[\\/]', 'once')) || ...
        startsWith(pathText, '\\')
    resolvedPath = pathText;
else
    resolvedPath = fullfile(baseDir, pathText);
end
end
