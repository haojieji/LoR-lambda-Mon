% LoRlambda-Mon configuration.
%
% Dataset selection is intentionally kept in LoRlambda_Mon.m so the public
% running interface stays simple:
%   LoRlambda_Mon
%   LoRlambda_Mon('online_boutique')
%   LoRlambda_Mon('sock_shop')
%
% This file only stores algorithm, visualization, and logging parameters.

% Algorithm parameters
params = struct();

% Sampling rate parameters
params.theta_r = 5e-6;      % Sampling rate parameter for root metrics
params.theta_c = 1e-1;      % Sampling rate parameter for child metrics
params.yita = 1e-6;         % Threshold for subspace estimation

% Model parameters
params.beta = 2;             % Batch size for model updates
params.als_max_iter = 1000;  % Maximum iterations for ALS
params.als_tol = 0.001;      % Tolerance for ALS convergence
params.epsilon_delta = 2.7;  % Legacy spike threshold kept for reproducibility
params.epsilon_gamma = 0.2;  % Legacy dip threshold kept for reproducibility

% Anomaly detection parameters
params.SPIKE_LIMIT = 0.92;   % Threshold for spike anomalies
params.DIP_LIMIT = 0.08;     % Threshold for dip anomalies

% Online anomaly monitoring parameters
params.OAM_max_iter = 100;   % Maximum iterations for online model
params.OAM_epsilon = 1e-3;   % Convergence tolerance for online model
params.verbose = true;       % Print batch-level progress

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
