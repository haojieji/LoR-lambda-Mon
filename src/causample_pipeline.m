function [X_e_hat, X_e_hat_normal, Omega_e, Omega_r_e, Omega_L_e, Omega_Anomalies_e, Times_sample, ...
    Overhead_cputime_decision, Overhead_cputime_sampling, Overhead_cputime_reconstruction, ...
    Overhead_cputime_modelupdate] = ...
    causample_pipeline(X, X_e, w, w_size, T, param, columnIDX, columnNames)
% CAUSAMPLE_PIPELINE Coordinate the components of CauSample.
%
%   Offline: extract the SCS from the original training data, separate
%   anomalies, prepare low-rank representations, and learn the anomaly model.
%   Online: update temporal ranks, combine base and anomaly-guided sampling,
%   reconstruct each batch, and update the anomaly model from sampled events.
%
%   Inputs
%     X           Normalized metric matrix on the original timeline (M-by-N).
%     X_e         Self-embedded training data followed by online batches.
%     w           Training-window length in batches (paper W).
%     w_size      Number of self-embedded training segments.
%     T           Number of time steps per batch.
%     param       Parameters from causample_config.
%     columnIDX   Retained metric indices in the input data.
%     columnNames Metric names used for plot labels.
%
%   Internal notation
%     W           Current data window; unlike paper W, this is a matrix.
%     B           Causal weight matrix; B(m,p) denotes p -> m (paper W).
%     Stru, Ord   Binary causal adjacency and within-cluster order.
%     U_W         Historical columns spanning each metric's temporal subspace.
%     ranks       Per-metric temporal-rank estimates.
%     Omega_*     Binary sampling or anomaly indicator matrices.
%     anomaly_*   Hawkes background, excitation, and decay parameters.
%     Lambda      Anomaly occurrence rates before normalization.
%     Lambda_normalize  Corresponding normalized anomaly probabilities.
%
%   Outputs
%     X_e_hat, X_e_hat_normal    M-by-N_e reconstructions with/without anomalies.
%     Omega_e, Omega_r_e, Omega_L_e, Omega_Anomalies_e
%                               M-by-N_e normal, base, additional, anomaly flags.
%     Times_sample              Wall-clock sampling seconds per metric/batch.
%     Overhead_cputime_*         CPU seconds per batch for each named stage.
%   batch_idx indexes X_e segments; w_size segments initialize the history.
%   pending_batch is zero in normal operation or the segment awaiting recovery.
%   The _e suffix denotes the self-embedded timeline. See src/README.md
%   and docs/algorithm_overview.md for the paper-to-code map.

[M, N] = size(X_e);
num_batch = floor(N/T);
W = [];
W_idx = [];

%% Low-Rank Sampler: temporal history and rank state (Section 4.2)
[U_W, U_W_idx, U_W_basis, U_W_basis_idx, ranks, U_W_union, U_W_union_idx] = ...
    Low_Rank_Sampler('initialize', T, w_size, M);

% A nonzero pending_batch switches to full collection until recovery is retried.
recovery_batch_count = 0;
pending_batch = 0;

% Anomaly Detector: robust Cauchy statistics.
Cauchy_MEDIANs = zeros(1, M);
Cauchy_MADs = zeros(1, M);
Cauchy_Trans = @(x, m) (x >= m) .* x + ...
                       (x < m) .* ( (2*m/pi) .* tan( (pi*(x - m))./(2*m + eps) ) + m );
% Allocate reconstructed values and sampling matrices.
X_e_hat = zeros(M,N);
X_e_hat_normal = zeros(M,N);
Omega_e = zeros(M,N);
Omega_r_e = zeros(M,N);
Omega_L_e = zeros(M,N);
Omega_Cauchy_spike_e = zeros(M,N);
Omega_Cauchy_dip_e = zeros(M,N);
Omega_Anomalies_e = zeros(M,N);
Omega_Cauchy_spike = zeros(size(X));
Omega_Cauchy_dip = zeros(size(X));
Omega_Anomalies = zeros(size(X));

% Anomaly Sampler: Hawkes parameters and EM settings.
anomaly_max_iter = 100;
anomaly_tolerance = 1e-3;
if isfield(param, 'anomaly_max_iter')
    anomaly_max_iter = param.anomaly_max_iter;
end
if isfield(param, 'anomaly_tolerance')
    anomaly_tolerance = param.anomaly_tolerance;
end

enableVisualization = true;
if isfield(param, 'visualization_enable')
    enableVisualization = param.visualization_enable;
end

verbose = true;
if isfield(param, 'verbose')
    verbose = param.verbose;
end
Lambda = zeros(size(X));
Lambda_normalize = zeros(size(X));
events = cell(M,1);

r_estimators = zeros(M, num_batch);

r_iscomplete = zeros(M, num_batch);

Times_sample = zeros(1,num_batch);
Overhead_cputime_decision = zeros(1,num_batch);
Overhead_cputime_sampling = zeros(1,num_batch);
Overhead_cputime_reconstruction = zeros(1,num_batch);
Overhead_cputime_modelupdate = zeros(1,num_batch);

for batch_idx = 1:num_batch
    if verbose
        fprintf('Processing batch %d/%d\n', batch_idx, num_batch);
    end
    W_idx = [W_idx batch_idx];
    %% Offline preparation: fully collected history window
    if batch_idx<=w_size
        X_t = X_e(:,(batch_idx-1)*T+1 : batch_idx*T);
        W(:,(batch_idx-1)*T+1 : batch_idx*T) = X_t;
        [U_W, U_W_idx, U_W_union, U_W_union_idx, U_W_basis, U_W_basis_idx, ranks, r_estimators] = ...
            Low_Rank_Sampler('train', X_t, batch_idx, M, param, U_W, U_W_idx, U_W_union, ...
            U_W_union_idx, U_W_basis, U_W_basis_idx, ranks, r_estimators);
        X_e_hat(:, (batch_idx-1)*T+1 : batch_idx*T) = X_t;
        Omega_e(:, (batch_idx-1)*T+1 : batch_idx*T) = 1;

        if batch_idx==w_size
            % Sparse Causal Structure Extractor: use original training data.
            X_train = X(:,1:w*T);
            [B, Stru, Ord, IDX_root, ~, IDX_groups, numClusters, ~] = ...
                Sparse_Causal_Structure_Extractor(X_train);

            % Anomaly Detector: prepare normal data and anomaly events.
            [W, U_W, Omega_Cauchy_spike_e, Omega_Cauchy_dip_e, ...
                Cauchy_MEDIANs, Cauchy_MADs] = Anomaly_Detector_Training( ...
                W, U_W, param.SPIKE_LIMIT, param.DIP_LIMIT, ...
                Omega_Cauchy_spike_e, Omega_Cauchy_dip_e, Cauchy_Trans);
            U_W_union = U_W;
            Omega_Anomalies_e = double(Omega_Cauchy_spike_e | Omega_Cauchy_dip_e);
            Omega_e = Omega_e - Omega_Anomalies_e;
            X_e_hat_normal(:,1:w_size*T) = W;

            [X_train, Omega_Cauchy_spike, Omega_Cauchy_dip, ...
                Cauchy_MEDIANs, Cauchy_MADs, ~] = Anomaly_Detector_Window( ...
                X_train, param.SPIKE_LIMIT, param.DIP_LIMIT, ...
                Omega_Cauchy_spike, Omega_Cauchy_dip, Cauchy_Trans);

            Omega_Anomalies = double(Omega_Cauchy_spike | Omega_Cauchy_dip);

            % Anomaly Sampler: learn SCS-constrained propagation parameters.
            [anomaly_mu, anomaly_A, anomaly_beta, S_mu, S_A, S_beta, ...
                events, Par] = Anomaly_Sampler_Training(Omega_Anomalies, ...
                w*T, M, anomaly_max_iter, anomaly_tolerance, Stru);
            [Lambda, Lambda_normalize] = Anomaly_Sampler('history', M, 1:w*T, 1:w*T, ...
                events, Par, anomaly_mu, anomaly_A, anomaly_beta, Lambda, Lambda_normalize);

            if enableVisualization
                plot_causal_structure(X_train, B, Ord, IDX_groups, numClusters, ...
                    ranks, columnIDX, columnNames);
            end
        end
        r_iscomplete(:,batch_idx) = 1;
    else
        %% Online sampling and reconstruction: process the next batch
        X_t = X_e(:, (batch_idx-1)*T+1 : batch_idx*T);
        % Low-Rank Sampler: advance the window and update temporal ranks.
        % Remove the oldest batch from the data window.
        cputime_decision_start = cputime;
        idx_oldest = W_idx(1);
        W_idx = W_idx(2:end);
        W(:, (size(W,2)+1):(size(W,2)+T) ) = X_t;
        W = W(:, T+1:end);
        [U_W, U_W_idx, ranks, r_estimators] = ...
            Low_Rank_Sampler('advance', idx_oldest, M, w_size, param, batch_idx, ...
            U_W, U_W_idx, ranks, r_estimators);
        Overhead_cputime_decision(batch_idx) = cputime - cputime_decision_start;

        Time_sample_t = 0;

        % Reuse the learned SCS and initialize batch-level sampling matrices.
        Omega_t = zeros(M, T);
        Omega_t_r = zeros(M, T);
        Omega_t_L = zeros(M, T);
        X_t_omega = zeros(M, T);
        X_e_hat_t = zeros(M, T);
        X_e_hat_t_normal = zeros(M, T);

        Anomalies_t_omega = zeros(M, T);
        new_events = cell(M,1);

        % Collect full batches when the current representation is insufficient.
        if pending_batch > 0

            cputime_sampling_start = cputime;
            Omega_t = ones(M, T);
            X_e_hat_t = X_t;
            X_e_hat_t_normal = X_t;
            recovery_batch_count = recovery_batch_count+1;
            Overhead_cputime_sampling(batch_idx) = cputime - cputime_sampling_start;

            cputime_decision_start = cputime;
            [U_W, U_W_idx, ranks, r_estimators] = ...
                Low_Rank_Sampler('observe', X_t, batch_idx, M, param, U_W, U_W_idx, ranks, r_estimators);
            Overhead_cputime_decision(batch_idx) = Overhead_cputime_decision(batch_idx) + (cputime-cputime_decision_start);
            % Extend the history used for delayed reconstruction.
            U_W_union(:,size(U_W_union,2)+1,:) = X_t';
            num_union_columns = length(U_W_union_idx);
            U_W_union_idx(num_union_columns+1) = batch_idx;
            r_iscomplete(:,batch_idx) = 1;

            X_e_hat(:, (batch_idx-1)*T+1 : batch_idx*T) = X_e_hat_t;
            if recovery_batch_count == param.beta || batch_idx == num_batch

                % Separate recent anomalies and update event/history data.
                [W, U_W_union, ~, ~, Cauchy_MEDIANs, Cauchy_MADs, ...
                    events, new_events, Omega_Cauchy] = Anomaly_Detector_Sampled( ...
                    W, U_W_union, U_W_union_idx, recovery_batch_count, ...
                    param.SPIKE_LIMIT, param.DIP_LIMIT, Cauchy_MEDIANs, ...
                    Cauchy_MADs, Cauchy_Trans, T, batch_idx, w_size, w, ...
                    events, new_events, Omega_e, Omega_Anomalies_e, X_e_hat, W_idx);

                X_e_hat_normal(:,(batch_idx-recovery_batch_count)*T:batch_idx*T) = W(:,(length(W_idx)-recovery_batch_count)*T:length(W_idx)*T);

                Omega_Anomalies_e(:,(batch_idx-recovery_batch_count)*T+1:batch_idx*T) = Omega_Cauchy;
                Omega_Anomalies(:,(batch_idx-recovery_batch_count-w_size+w)*T+1:(batch_idx-w_size+w)*T) = Omega_Cauchy;
                Omega_t_r = ones(M, recovery_batch_count*T);
                Omega_t_r(Omega_Cauchy==1) = 0;
                Omega_r_e(:,(batch_idx-recovery_batch_count)*T+1:batch_idx*T) = Omega_t_r;
                Omega_L_e(:,(batch_idx-recovery_batch_count)*T+1:batch_idx*T) = Omega_t_r;

                % Retry reconstruction of the pending batch.
                cputime_reconstruction_start = cputime;
                [X_e_hat, X_e_hat_normal, r_iscomplete] = ...
                    Fine_Grained_Reconstructor('delayed', r_iscomplete, pending_batch, ...
                    numClusters, IDX_root, Omega_e, Omega_Anomalies_e, X_e_hat, ...
                    X_e_hat_normal, U_W_union, U_W_union_idx, recovery_batch_count, B, param, T);
                Overhead_cputime_reconstruction(batch_idx) = cputime - cputime_reconstruction_start;
                % Report whether all pending metrics were reconstructed.
                if all(r_iscomplete(:, pending_batch))
                    disp(["OK", pending_batch]);
                end

                % Model Updater: incorporate newly sampled anomalies (Section 4.6).
                cputime_modelupdate_start = cputime;
                [anomaly_mu, anomaly_A, anomaly_beta, S_mu, S_A, S_beta] = ...
                    Model_Updater(anomaly_mu, anomaly_A, anomaly_beta, events, ...
                    new_events, w, T, M, anomaly_max_iter, anomaly_tolerance, ...
                    S_mu, S_A, S_beta, Par, W_idx);
                Overhead_cputime_modelupdate(batch_idx) = cputime - cputime_modelupdate_start;
                [Lambda, Lambda_normalize] = Anomaly_Sampler('history', M, ...
                    (batch_idx-w_size+w-recovery_batch_count)*T+1:(batch_idx-w_size+w)*T, [], events, Par, ...
                    anomaly_mu, anomaly_A, anomaly_beta, Lambda, Lambda_normalize);

                pending_batch = 0;
                recovery_batch_count = 0;
            end
        else

            for cluster_idx = 1:numClusters

                % Identify root and child metrics in each local DAG.
                IDX_i = find(IDX_groups==cluster_idx);
                Ord_i = Ord(cluster_idx, 1:length(IDX_i));
                B_i = B(Ord_i, Ord_i);
                num_root_i = length( find(IDX_root(cluster_idx,:) ~= 0) );
                IDX_root_i = IDX_root(cluster_idx, 1:num_root_i);
                IDX_child_i = Ord_i(~ismember(Ord_i, IDX_root_i));

                time_sample = tic;
                cputime_sampling_start = cputime;
                % Low-Rank Sampler: determine root and child base sample budgets.
                for local_metric_idx = 1:size(B_i,1)
                    metric_idx = Ord_i(local_metric_idx);

                    sample_budget = Low_Rank_Sampler('budget', metric_idx, IDX_root_i, ...
                        ranks, Ord_i, B_i, local_metric_idx, param);
                    % Composite Sampler: combine base collection with anomaly-guided
                    % candidates; detected anomalies update the shared event history.
                    [normal_samples_m, base_samples_m, additional_samples_m, ...
                        sampled_anomalies_m, Omega_Anomalies_e, events, ...
                        new_events, Lambda, Lambda_normalize] = Composite_Sampler( ...
                        metric_idx, sample_budget, T, param, X_t(metric_idx, :), ...
                        X_e_hat, Omega_e, Omega_Anomalies_e, events, new_events, ...
                        Par, Cauchy_MEDIANs, Cauchy_MADs, Cauchy_Trans, W_idx, ...
                        w_size, w, anomaly_mu, anomaly_A, anomaly_beta, ...
                        Lambda, Lambda_normalize);

                    Omega_t(metric_idx, :) = normal_samples_m;
                    Omega_t_r(metric_idx, :) = base_samples_m;
                    Omega_t_L(metric_idx, :) = additional_samples_m;
                    X_t_omega(metric_idx, :) = X_t(metric_idx, :) .* normal_samples_m;
                    Anomalies_t_omega(metric_idx,:) = sampled_anomalies_m;
                end
                cputime_sampling_i = cputime - cputime_sampling_start;
                Overhead_cputime_sampling(batch_idx) = Overhead_cputime_sampling(batch_idx) + cputime_sampling_i;
                Time_sample_t = Time_sample_t + toc(time_sample);
                % Reconstruct roots from temporal history and children from parents/history.
                cputime_reconstruction_start = cputime;
                [X_e_hat_t, X_e_hat_t_normal, r_estimators, r_iscomplete, ranks] = ...
                    Fine_Grained_Reconstructor('batch', IDX_root_i, IDX_child_i, U_W, ...
                    U_W_idx, Omega_t, Anomalies_t_omega, X_t_omega, X_t, X_e_hat_t, ...
                    X_e_hat_t_normal, r_estimators, r_iscomplete, ranks, B, param, batch_idx);
                cputime_reconstruction_i = cputime - cputime_reconstruction_start;
                Overhead_cputime_reconstruction(batch_idx) = Overhead_cputime_reconstruction(batch_idx) + cputime_reconstruction_i;

                incomplete_root_indices = find(r_iscomplete(IDX_root_i,batch_idx) == 0)';
                if ~isempty(incomplete_root_indices)
                    pending_batch = batch_idx;
                    recovery_batch_count = 0;
                end
                incomplete_child_indices = find( r_iscomplete(IDX_child_i,batch_idx) == 0)';
                if ~isempty(incomplete_child_indices)
                    pending_batch = batch_idx;
                    recovery_batch_count = 0;
                end

            end % Process all local DAGs.

            % Model Updater: incorporate newly sampled anomalies (Section 4.6).
            cputime_modelupdate_start = cputime;
            [anomaly_mu, anomaly_A, anomaly_beta, S_mu, S_A, S_beta] = ...
                Model_Updater(anomaly_mu, anomaly_A, anomaly_beta, events, ...
                new_events, w, T, M, anomaly_max_iter, anomaly_tolerance, ...
                S_mu, S_A, S_beta, Par, W_idx);
            Overhead_cputime_modelupdate(batch_idx) = cputime - cputime_modelupdate_start;

            X_e_hat_normal(:, (batch_idx-1)*T+1 : batch_idx*T) = X_e_hat_t_normal;
            Omega_Anomalies(:, (batch_idx-w_size+w-1)*T+1 : (batch_idx-w_size+w)*T) = Anomalies_t_omega;
            Omega_r_e(:, (batch_idx-1)*T+1 : batch_idx*T) = Omega_t_r;
            Omega_L_e(:, (batch_idx-1)*T+1 : batch_idx*T) = Omega_t_L;

        end

        X_e_hat(:, (batch_idx-1)*T+1 : batch_idx*T) = X_e_hat_t;
        Omega_e(:, (batch_idx-1)*T+1 : batch_idx*T) = Omega_t;

        Times_sample(batch_idx) = Time_sample_t/M;

    end
end

end
