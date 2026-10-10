function prepare_causample_data()
%PREPARE_CAUSAMPLE_DATA Prepare the bundled inputs for CauSample.
% Run once before CauSample. Existing MAT files are left unchanged.

dataset = causample_dataset_config('tpc_c');
datasetDir = fileparts(dataset.path);
csvPath = dataset.csv_path;
matPath = dataset.path;

if exist(matPath, 'file') ~= 2
    if exist(csvPath, 'file') ~= 2
        gzipPath = [csvPath '.gz'];
        if exist(gzipPath, 'file') ~= 2
            error('Download the labeled TPC-C CSV or CSV.GZ into dataset/.');
        end
        gunzip(gzipPath, datasetDir);
    end
    import_dataset_from_csv(csvPath, matPath, 'tpc_c');
end

baroFiles = {'BARO_OB_w7T50.mat', 'BARO_SS_w7T50.mat'};
for i = 1:numel(baroFiles)
    if exist(fullfile(datasetDir, baroFiles{i}), 'file') ~= 2
        error('Missing bundled input: dataset/%s', baroFiles{i});
    end
end
fprintf('CauSample inputs are ready. Run CauSample with a dataset name.\n');
end
