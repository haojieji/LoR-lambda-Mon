% CauSample configuration.
%
% Dataset paths and overrides are shared through causample_dataset_config.m.
% Select a dataset through the public runner:
%   CauSample
%   CauSample('online_boutique')
%   CauSample('sock_shop')
%
% This file only stores algorithm, visualization, and logging parameters.

% Algorithm parameters
params = struct();

% Low-Rank Sampler parameters
params.theta_r = 5e-6;      % Base sample-budget scale for root metrics
params.theta_c = 1e-1;      % Base sample-budget scale for child metrics
params.yita = 1e-6;         % Normalized projection residual tolerance

% Model parameters
params.beta = 2;             % Full batches collected after a subspace mismatch
params.als_max_iter = 1000;  % Maximum iterations for ALS
params.als_tol = 0.001;      % Tolerance for ALS convergence
params.epsilon_delta = 2.7;  % Legacy spike threshold kept for reproducibility
params.epsilon_gamma = 0.2;  % Legacy dip threshold kept for reproducibility

% Anomaly detection parameters
params.SPIKE_LIMIT = 0.92;   % Threshold for spike anomalies
params.DIP_LIMIT = 0.08;     % Threshold for dip anomalies

% Anomaly Sampler / Model Updater parameters
params.anomaly_max_iter = 100;   % Maximum iterations for anomaly-model EM
params.anomaly_tolerance = 1e-3;   % Convergence tolerance for anomaly-model EM
params.verbose = true;       % Print batch-level progress

% Visualization parameters
visualization = struct();
visualization.enable = true;  % Enable visualization
visualization.save_figures = false; % Save figures to disk
visualization.figure_format = 'png'; % Figure format

% Logging parameters
logging = struct();
logging.enable = true;        % Enable logging
logging.log_file = 'causample.log'; % Log file path
logging.log_level = 'info';   % Log level: 'debug', 'info', 'warning', 'error'
