function prepare_causample_data()
%PREPARE_CAUSAMPLE_DATA Prepare the bundled inputs for CauSample.
% Run once before LoRlambda_Mon. Existing MAT files are left unchanged.

srcDir = fileparts(mfilename('fullpath'));
datasetDir = fullfile(srcDir, '..', 'dataset');
csvPath = fullfile(datasetDir, 'combined_metrics_510_608_with_labels.csv');
matPath = fullfile(datasetDir, 'mysql_510_608_withLabels.mat');

if exist(matPath, 'file') ~= 2
    if exist(csvPath, 'file') ~= 2
        gzipPath = [csvPath '.gz'];
        if exist(gzipPath, 'file') ~= 2
            error('Download the labeled OLTP CSV or CSV.GZ into dataset/.');
        end
        gunzip(gzipPath, datasetDir);
    end
    import_dataset_from_csv(csvPath, matPath, 'oltp');
end

baroFiles = {'BARO_OB_w7T50.mat', 'BARO_SS_w7T50.mat'};
for i = 1:numel(baroFiles)
    if exist(fullfile(datasetDir, baroFiles{i}), 'file') ~= 2
        error('Missing bundled input: dataset/%s', baroFiles{i});
    end
end
fprintf('CauSample inputs are ready. Run LoRlambda_Mon with a dataset name.\n');
end
