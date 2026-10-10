% CauSample configuration.
%
% Dataset paths and overrides are shared through causample_dataset_config.m.
% Select a dataset through the public runner:
%   CauSample
%   CauSample('online_boutique')
%   CauSample('sock_shop')
%
% This file stores implemented algorithm and visualization settings.
% Dataset-specific overrides are applied afterwards by causample_dataset_config.

% Algorithm parameters
params = struct();

% Low-Rank Sampler parameters
params.theta_r = 5e-6;      % Base sample-budget scale for root metrics
params.theta_c = 1e-1;      % Base sample-budget scale for child metrics
params.yita = 1e-6;         % Normalized projection residual tolerance

% Reconstruction and recovery parameters
params.beta = 2;             % Recovery batch count, not the Hawkes decay parameter
params.als_max_iter = 1000;  % Maximum iterations for ALS
params.als_tol = 0.001;      % Tolerance for ALS convergence

% Anomaly detection parameters
% These affect online detection and labels generated from raw TPC-C data.
% Bundled BARO labels and evaluate_anomaly_preservation use fixed 0.08/0.92
% thresholds; changing these settings does not change that evaluation protocol.
params.SPIKE_LIMIT = 0.92;   % Threshold for spike anomalies
params.DIP_LIMIT = 0.08;     % Threshold for dip anomalies

% Anomaly Sampler / Model Updater parameters
params.anomaly_max_iter = 100;   % Maximum iterations for anomaly-model EM
params.anomaly_tolerance = 1e-3;   % Convergence tolerance for anomaly-model EM
params.verbose = true;       % Print batch-level progress

% Visualization parameters
visualization = struct();
visualization.enable = true;  % Enable visualization
