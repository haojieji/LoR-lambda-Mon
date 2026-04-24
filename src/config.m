% LoRlambda-Mon Configuration File
% This file contains configuration parameters for the LoRlambda-Mon framework
% You can modify these parameters to customize the behavior of the system

% Dataset configuration
dataset = struct();
dataset.path = '../dataset/mysql_510_608_withLabels.mat';
dataset.batch_size = 100; % T
dataset.window_size = 23; % w
dataset.enhanced_window_size = 2201; % w_size

% Algorithm parameters
params = struct();

% Sampling rate parameters
params.theta_r = 5e-6;      % Sampling rate parameter for root metrics
params.theta_c = 1e-1;      % Sampling rate parameter for child metrics
params.yita = 1e-6;         % Threshold for subspace estimation
params.thr_ACE = 0.1;       % Threshold for ACE method

% Model parameters
params.beta = 2;             % Batch size for model updates
params.als_max_iter = 1000;  % Maximum iterations for ALS
params.als_tol = 0.001;      % Tolerance for ALS convergence

% Anomaly detection parameters
params.SPIKE_LIMIT = 0.92;   % Threshold for spike anomalies
params.DIP_LIMIT = 0.08;     % Threshold for dip anomalies

% Online anomaly monitoring parameters
params.OAM_max_iter = 100;   % Maximum iterations for online model
params.OAM_epsilon = 1e-3;   % Convergence tolerance for online model

% Visualization parameters
visualization = struct();
visualization.enable = true;  % Enable visualization
visualization.save_figures = false; % Save figures to disk
visualization.figure_format = 'png'; % Figure format

% Logging parameters
logging = struct();
logging.enable = true;        % Enable logging
logging.log_file = 'lorlambda_mon.log'; % Log file path
logging.log_level = 'info';   % Log level: 'debug', 'info', 'warning', 'error'