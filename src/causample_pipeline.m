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
%   Outputs include reconstructed data, sampling matrices, and timings.
%   The _e suffix denotes the self-embedded timeline. See src/README.md
%   and docs/algorithm_overview.md for the paper-to-code map.

[M, N] = size(X_e);
num_batch = floor(N/T);
W = [];
W_idx = [];

%% Low-Rank Sampler: temporal history and rank state (Section 4.2)
[U_W, U_W_idx, U_W_basis, U_W_basis_idx, ranks, U_W_union, U_W_union_idx] = ...
    Low_Rank_Sampler('initialize', T, w_size, M);

beta_count = 0;
incomplete_batch = 0;

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
Omega = zeros(size(X));
Omega_r = zeros(size(X));
Omega_L = zeros(size(X));
Omega_Cauchy_spike = zeros(size(X));
Omega_Cauchy_dip = zeros(size(X));
Omega_Anomalies = zeros(size(X));
Labels_Anomalies_X_hat = zeros(size(X));

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

r_ranks = zeros(M, num_batch);

r_estimators = zeros(M, num_batch);

r_iscomplete = zeros(M, num_batch);
r_incomplete_batchs = zeros(1, num_batch);

Times_sample = zeros(1,num_batch);
Overhead_cputime_decision = zeros(1,num_batch);
Overhead_cputime_sampling = zeros(1,num_batch);
Overhead_cputime_reconstruction = zeros(1,num_batch);
Overhead_cputime_modelupdate = zeros(1,num_batch);

for t = 1:num_batch
    if verbose
        fprintf('Processing batch %d/%d\n', t, num_batch);
    end
    W_idx = [W_idx t];
    %% Offline preparation: fully collected history window
    if t<=w_size
        X_t = X_e(:,(t-1)*T+1 : t*T);
        W(:,(t-1)*T+1 : t*T) = X_t;
        [U_W, U_W_idx, U_W_union, U_W_union_idx, U_W_basis, U_W_basis_idx, ranks, r_estimators] = ...
            Low_Rank_Sampler('train', X_t, t, M, param, U_W, U_W_idx, U_W_union, ...
            U_W_union_idx, U_W_basis, U_W_basis_idx, ranks, r_estimators);
        X_e_hat(:, (t-1)*T+1 : t*T) = X_t;
        Omega_e(:, (t-1)*T+1 : t*T) = 1;

        if t==w_size
            % Sparse Causal Structure Extractor: use original training data.
            X_train = X(:,1:w*T);
            [B, Stru, Ord, IDX_root, IDX_intermedia, IDX_groups, numClusters, eigns] = ...
                Sparse_Causal_Structure_Extractor(X_train);

            % Anomaly Detector: prepare normal data and anomaly events.
            [W, U_W, Omega_Cauchy_spike_e, Omega_Cauchy_dip_e, Cauchy_MEDIANs, Cauchy_MADs] = Anomaly_Detector_Training(W, U_W, param.SPIKE_LIMIT, param.DIP_LIMIT, Omega_Cauchy_spike_e, Omega_Cauchy_dip_e, Cauchy_Trans);
            U_W_union = U_W;
            Omega_Anomalies_e = double(Omega_Cauchy_spike_e | Omega_Cauchy_dip_e);
            Omega_e = Omega_e - Omega_Anomalies_e;
            X_e_hat_normal(:,1:w_size*T) = W;

            [X_train, Omega_Cauchy_spike, Omega_Cauchy_dip, Cauchy_MEDIANs, Cauchy_MADs, ~] = Anomaly_Detector_Window(X_train, param.SPIKE_LIMIT, param.DIP_LIMIT, Omega_Cauchy_spike, Omega_Cauchy_dip, Cauchy_Trans);
            Omega(:,1:w*T) = 1;
            Omega_Anomalies = double(Omega_Cauchy_spike | Omega_Cauchy_dip);

            % Anomaly Sampler: learn SCS-constrained propagation parameters.
            [anomaly_mu, anomaly_A, anomaly_beta,S_mu,S_A,S_beta, events, Par] = Anomaly_Sampler_Training(Omega_Anomalies, w*T, M, anomaly_max_iter, anomaly_tolerance, Stru);
            [Lambda, Lambda_normalize] = Anomaly_Sampler('history', M, 1:w*T, 1:w*T, ...
                events, Par, anomaly_mu, anomaly_A, anomaly_beta, Lambda, Lambda_normalize);

            if enableVisualization
                rank_M_svd = rank(X_train');
                figure;
                for i = 1:numClusters
                    IDX_i = find(IDX_groups==i);
                    numMetrics_i = length(IDX_i);
                    Ord_i = Ord(i, 1:numMetrics_i);
                    B_i = B(Ord_i, Ord_i);
                    % preprocess_metric_data returns columnNames already filtered
                    % to the metric rows used by X/X_e.  In that normal
                    % path Ord_i indexes columnNames directly.  Keep support
                    % for older/custom callers that pass an unfiltered
                    % metric-name vector by using columnIDX only when the
                    % name vector is large enough for those original metric
                    % indices.
                    if numel(columnNames) == M
                        columnNameIDX = Ord_i;
                    elseif numel(columnNames) >= max(columnIDX)
                        columnNameIDX = columnIDX(Ord_i);
                    else
                        error(['columnNames has %d entries, which cannot label ' ...
                               '%d preprocessed metrics.'], numel(columnNames), M);
                    end

                    subplot(2, ceil(numClusters/2), i);
                    G = digraph(B_i');
                    h=plot(G, 'Layout', 'layered', 'NodeLabel', columnNames(columnNameIDX), 'ArrowSize', 12, 'LineWidth', 1.5, 'NodeColor', [0.2 0.6 1]);
                    title(['DAG of cluster ', num2str(i)])
                    ranks_Ord = ranks(Ord_i);
                    rank_causal = 0;
                    for j = 1:size(B_i,1)
                        rank_causal = max(rank_causal, length(find(B_i(j,:)>0)));
                    end
                    ranks_Ord_str = strjoin(string(ranks_Ord), ', ');
                    legend_text = sprintf('causal rank=%d, temporal ranks=[%s], svd rank=%d', rank_causal, ranks_Ord_str, rank_M_svd);

                    legend(h, legend_text, 'Location', 'best');
                end
                figure;
                for i = 1:numClusters
                    IDX_i = find(IDX_groups==i);
                    numMetrics_i = length(IDX_i);
                    Ord_i = Ord(i, 1:numMetrics_i);
                    B_i = B(Ord_i, Ord_i);

                    subplot(2, ceil(numClusters/2), i);
                    heatmap(B_i, 'XLabel', 'parent', 'YLabel', 'child', 'Title', 'Causal weight matrix');
                    colormap jet;
                    colorbar;
                end
            end
        end
        r_iscomplete(:,t) = 1;
    else
        %% Online sampling and reconstruction: process the next batch
        X_t = X_e(:, (t-1)*T+1 : t*T);
        % Low-Rank Sampler: advance the window and update temporal ranks.
        % Remove the oldest batch from the data window.
        cputime_decision_start = cputime;
        idx_oldest = W_idx(1);
        W_idx = W_idx(2:end);
        W(:, (size(W,2)+1):(size(W,2)+T) ) = X_t;
        W = W(:, T+1:end);
        [U_W, U_W_idx, ranks, r_estimators] = ...
            Low_Rank_Sampler('advance', idx_oldest, M, w_size, param, t, ...
            U_W, U_W_idx, ranks, r_estimators);
        Overhead_cputime_decision(t) = cputime - cputime_decision_start;

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

        % *******************************************************************************
        % Collect full batches when the current representation is insufficient.
        if incomplete_batch > 0
            %
            cputime_sampling_start = cputime;
            Omega_t = ones(M, T);
            X_e_hat_t = X_t;
            X_e_hat_t_normal = X_t;
            beta_count = beta_count+1;
            Overhead_cputime_sampling(t) = cputime - cputime_sampling_start;
            %
            cputime_decision_start = cputime;
            [U_W, U_W_idx, ranks, r_estimators] = ...
                Low_Rank_Sampler('observe', X_t, t, M, param, U_W, U_W_idx, ranks, r_estimators);
            Overhead_cputime_decision(t) = Overhead_cputime_decision(t) + (cputime-cputime_decision_start);
            % s1 U_W_Union
            U_W_union(:,size(U_W_union,2)+1,:) = X_t';
            temp = length(U_W_union_idx);
            U_W_union_idx(temp+1) = t;
            r_iscomplete(:,t) = 1;

            X_e_hat(:, (t-1)*T+1 : t*T) = X_e_hat_t;
            if beta_count == param.beta || t == num_batch

                % Separate recent anomalies and update event/history data.
                [W, U_W_union, ~, ~, Cauchy_MEDIANs,Cauchy_MADs,events,new_events,Omega_Cauchy] = Anomaly_Detector_Sampled(W, U_W_union, U_W_union_idx, beta_count, param.SPIKE_LIMIT, param.DIP_LIMIT, Cauchy_MEDIANs, Cauchy_MADs, Cauchy_Trans, T,t,w_size,w, events,new_events, Omega_e,Omega_Anomalies_e,X_e_hat, W_idx);

                X_e_hat_normal(:,(t-beta_count)*T:t*T) = W(:,(length(W_idx)-beta_count)*T:length(W_idx)*T);

                Omega_Anomalies_e(:,(t-beta_count)*T+1:t*T) = Omega_Cauchy;
                Omega_Anomalies(:,(t-beta_count-w_size+w)*T+1:(t-w_size+w)*T) = Omega_Cauchy;
                Omega_t_r = ones(M, beta_count*T);
                Omega_t_r(Omega_Cauchy==1) = 0;
                Omega_r_e(:,(t-beta_count)*T+1:t*T) = Omega_t_r;
                Omega_L_e(:,(t-beta_count)*T+1:t*T) = Omega_t_r;
                Omega_r(:,(t-beta_count-w_size+w)*T+1:(t-w_size+w)*T) = Omega_t_r;
                Omega_L(:,(t-beta_count-w_size+w)*T+1:(t-w_size+w)*T) = Omega_t_r;

                % s2
                cputime_reconstruction_start = cputime;
                [X_e_hat, X_e_hat_normal, r_iscomplete] = ...
                    Fine_Grained_Reconstructor('delayed', r_iscomplete, incomplete_batch, ...
                    numClusters, IDX_root, Omega_e, Omega_Anomalies_e, X_e_hat, ...
                    X_e_hat_normal, U_W_union, U_W_union_idx, beta_count, B, param, T);
                Overhead_cputime_reconstruction(t) = cputime - cputime_reconstruction_start;
                % s4
                if all(r_iscomplete(:, incomplete_batch))
                    disp(["OK", incomplete_batch]);
                end

                % Model Updater: incorporate newly sampled anomalies (Section 4.6).
                cputime_modelupdate_start = cputime;
                [anomaly_mu,anomaly_A,anomaly_beta, S_mu,S_A,S_beta] = Model_Updater(anomaly_mu,anomaly_A,anomaly_beta, events, new_events, w,T, M, anomaly_max_iter, anomaly_tolerance, S_mu,S_A,S_beta, Par, W_idx);
                Overhead_cputime_modelupdate(t) = cputime - cputime_modelupdate_start;
                [Lambda, Lambda_normalize] = Anomaly_Sampler('history', M, ...
                    (t-w_size+w-beta_count)*T+1:(t-w_size+w)*T, [], events, Par, ...
                    anomaly_mu, anomaly_A, anomaly_beta, Lambda, Lambda_normalize);

                incomplete_batch = 0;
                beta_count = 0;
            end
        else
            % *******************************************************************************************
            %
            for i = 1:numClusters

                % Identify root and child metrics in each local DAG.
                IDX_i = find(IDX_groups==i);
                Ord_i = Ord(i, 1:length(IDX_i));
                B_i = B(Ord_i, Ord_i);
                Stru_i = Stru(Ord_i, Ord_i);
                num_root_i = length( find(IDX_root(i,:) ~= 0) );
                IDX_root_i = IDX_root(i, 1:num_root_i);
                IDX_other_i = Ord_i(~ismember(Ord_i, IDX_root_i));

                time_sample = tic;
                cputime_sampling_start = cputime;
                % Low-Rank Sampler: determine root and child base sample budgets.
                for j = 1:size(B_i,1)
                    j_ord_idx = Ord_i(j);

                    numSamples_j = Low_Rank_Sampler('budget', j_ord_idx, IDX_root_i, ...
                        ranks, Ord_i, B_i, j, param);
                    % Composite Sampler: combine base collection with anomaly-guided
                    % candidates; detected anomalies update the shared event history.
                    [Omega_t_j_ord_idx, Omega_t_j_ord_idx_r,Omega_t_j_ord_idx_L, Anomalies_t_omega_j_ord_idx, Omega_Anomalies_e, events, new_events, Lambda,Lambda_normalize] = Composite_Sampler(j_ord_idx, numSamples_j, T, param, X_t(j_ord_idx, :), X_e_hat, Omega_e, Omega_Anomalies_e, events,new_events, Par, Cauchy_MEDIANs,Cauchy_MADs,Cauchy_Trans, W_idx, w_size,w, anomaly_mu,anomaly_A,anomaly_beta, Lambda,Lambda_normalize);

                    Omega_t(j_ord_idx, :) = Omega_t_j_ord_idx;
                    Omega_t_r(j_ord_idx, :) = Omega_t_j_ord_idx_r;
                    Omega_t_L(j_ord_idx, :) = Omega_t_j_ord_idx_L;
                    X_t_omega(j_ord_idx, :) = X_t(j_ord_idx, :) .* Omega_t_j_ord_idx;
                    Anomalies_t_omega(j_ord_idx,:) = Anomalies_t_omega_j_ord_idx;
                end
                cputime_sampling_i = cputime - cputime_sampling_start;
                Overhead_cputime_sampling(t) = Overhead_cputime_sampling(t) + cputime_sampling_i;
                Time_sample_t = Time_sample_t + toc(time_sample);
                % Fine-Grained Reconstructor: recover roots from temporal history.
                cputime_reconstruction_start = cputime;
                [X_e_hat_t, X_e_hat_t_normal, r_estimators, r_iscomplete, ranks] = ...
                    Fine_Grained_Reconstructor('batch', IDX_root_i, IDX_other_i, U_W, ...
                    U_W_idx, Omega_t, Anomalies_t_omega, X_t_omega, X_t, X_e_hat_t, ...
                    X_e_hat_t_normal, r_estimators, r_iscomplete, ranks, B, param, t);
                cputime_reconstruction_i = cputime - cputime_reconstruction_start;
                Overhead_cputime_reconstruction(t) = Overhead_cputime_reconstruction(t) + cputime_reconstruction_i;

                r_iscomplete_root_i = find(r_iscomplete(IDX_root_i,t) == 0)';
                if ~isempty(r_iscomplete_root_i)
                    incomplete_batch = t;
                    beta_count = 0;
                end
                r_iscomplete_other_i = find( r_iscomplete(IDX_other_i,t) == 0)';
                if ~isempty(r_iscomplete_other_i)
                    incomplete_batch = t;
                    beta_count = 0;
                end

            end% for i=1:numClusters

            % Model Updater: incorporate newly sampled anomalies (Section 4.6).
            cputime_modelupdate_start = cputime;
            [anomaly_mu,anomaly_A,anomaly_beta, S_mu,S_A,S_beta] = Model_Updater(anomaly_mu,anomaly_A,anomaly_beta, events, new_events, w,T, M, anomaly_max_iter, anomaly_tolerance, S_mu,S_A,S_beta, Par, W_idx);
            Overhead_cputime_modelupdate(t) = cputime - cputime_modelupdate_start;

            X_e_hat_normal(:, (t-1)*T+1 : t*T) = X_e_hat_t_normal;
            Omega_Anomalies(:, (t-w_size+w-1)*T+1 : (t-w_size+w)*T) = Anomalies_t_omega;
            Omega_r_e(:, (t-1)*T+1 : t*T) = Omega_t_r;
            Omega_L_e(:, (t-1)*T+1 : t*T) = Omega_t_L;
            Omega_r(:, (t-w_size+w-1)*T+1 : (t-w_size+w)*T) = Omega_t_r;
            Omega_L(:, (t-w_size+w-1)*T+1 : (t-w_size+w)*T) = Omega_t_L;
        end
        % *******************************************************************************************
        X_e_hat(:, (t-1)*T+1 : t*T) = X_e_hat_t;
        %X_hat_normal(:, (t-1)*T+1 : t*T) = X_hat_t_normal;
        Omega_e(:, (t-1)*T+1 : t*T) = Omega_t;
        Omega(:, (t-w_size+w-1)*T+1 : (t-w_size+w)*T) = Omega_t;

        Times_sample(t) = Time_sample_t/M;
        r_ranks(:,t) = ranks';

        r_incomplete_batchs(t) = incomplete_batch;

        % Identify anomalies in the reconstructed batch for output analysis.
        % Refresh the robust detector statistics.
        range_w = ((W_idx(1)-1)*T+1 : W_idx(w_size)*T);
        X_range_w = X_e_hat(:, range_w);
        Cauchy_MEDIANs_hat = median( X_range_w' );
        Cauchy_MADs_hat = median(abs(X_range_w' - Cauchy_MEDIANs_hat));
        Cauchy_Trans_t = zeros(size(X_e_hat_t));
        Cauchy_CDF_t = zeros(size(X_e_hat_t));
        Omega_Cauchy_spike_t = zeros(size(X_e_hat_t));
        Omega_Cauchy_dip_t = zeros(size(X_e_hat_t));
        for i = 1:M
            Cauchy_Trans_t(i,:) = Cauchy_Trans( X_e_hat_t(i,:), Cauchy_MEDIANs_hat(i) );
            Cauchy_CDF_t(i,:) = (1/pi) * atan( (Cauchy_Trans_t(i,:)-Cauchy_MEDIANs_hat(i))/(Cauchy_MADs_hat(i)+eps) ) + 0.5;
            Omega_Cauchy_spike_t(i, Cauchy_CDF_t(i,:)>param.SPIKE_LIMIT) = 1; % spike
            Omega_Cauchy_dip_t(i, Cauchy_CDF_t(i,:)<param.DIP_LIMIT) = 1; % dip
        end
        Labels_Anomalies_X_hat(:, (t-w_size+w-1)*T+1:(t-w_size+w)*T) = double(Omega_Cauchy_spike_t | Omega_Cauchy_dip_t);

    end
end

end
