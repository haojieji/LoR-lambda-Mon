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
U_W = zeros(T,w_size,M);
U_W_idx = zeros(M, w_size);
U_W_basis = zeros(T,w_size,M);
U_W_basis_idx = zeros(M,w_size);
ranks = zeros(1,M);
U_W_union = [];
U_W_union_idx = [];

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
        U_W(:,t,:) = X_t';
        U_W_idx(:,t) = ones(M,1)*t;
        U_W_union(:,t,:) = X_t';
        U_W_union_idx(t) = t;
        X_e_hat(:, (t-1)*T+1 : t*T) = X_t;
        Omega_e(:, (t-1)*T+1 : t*T) = 1;
        for i = 1:M
            r_i = ranks(i);
            U_W_basis_i = U_W_basis(:,1:r_i,i);
            X_t_i = X_t(i,:)';
            P_UWbasis_i = U_W_basis_i * pinv(U_W_basis_i);
            estimator = (norm(X_t_i - P_UWbasis_i * X_t_i)^2) / (norm(X_t_i)^2+eps);
            r_estimators(i,t) = estimator;

            if estimator > param.yita
                r_i = r_i + 1;
                U_W_basis(:, r_i, i) = X_t_i;
                U_W_basis_idx(i,r_i) = t;
                ranks(i) = r_i;
            end
        end

        if t==w_size
            % Sparse Causal Structure Extractor: use original training data.
            X_train = X(:,1:w*T);
            [IDX_groups, numClusters, eigns,~] = cluster_correlated_metrics(X_train);
            [B, Stru, Ord, IDX_root, IDX_intermedia] = extract_sparse_causal_structure(IDX_groups, numClusters, X_train);

            % Anomaly Detector: prepare normal data and anomaly events.
            [W, U_W, Omega_Cauchy_spike_e, Omega_Cauchy_dip_e, Cauchy_MEDIANs, Cauchy_MADs] = detect_training_anomalies(W, U_W, param.SPIKE_LIMIT, param.DIP_LIMIT, Omega_Cauchy_spike_e, Omega_Cauchy_dip_e, Cauchy_Trans);
            U_W_union = U_W;
            Omega_Anomalies_e = double(Omega_Cauchy_spike_e | Omega_Cauchy_dip_e);
            Omega_e = Omega_e - Omega_Anomalies_e;
            X_e_hat_normal(:,1:w_size*T) = W;

            [X_train, Omega_Cauchy_spike, Omega_Cauchy_dip, Cauchy_MEDIANs, Cauchy_MADs, ~] = detect_window_anomalies(X_train, param.SPIKE_LIMIT, param.DIP_LIMIT, Omega_Cauchy_spike, Omega_Cauchy_dip, Cauchy_Trans);
            Omega(:,1:w*T) = 1;
            Omega_Anomalies = double(Omega_Cauchy_spike | Omega_Cauchy_dip);

            % Anomaly Sampler: learn SCS-constrained propagation parameters.
            [anomaly_mu, anomaly_A, anomaly_beta,S_mu,S_A,S_beta, events, Par] = learn_anomaly_model(Omega_Anomalies, w*T, M, anomaly_max_iter, anomaly_tolerance, Stru);
            for i = 1:M
                for j = 1:w*T
                    % lambda_i(j)
                    lambda_i_j = anomaly_mu(i);
                    for m_prime = Par{i}
                        past_events = events{m_prime}(events{m_prime}<=j);
                        if ~isempty(past_events)
                            dt = j-past_events;
                            contrib = anomaly_A(i, m_prime) * anomaly_beta(i, m_prime) * exp(-anomaly_beta(i, m_prime)*dt);
                            lambda_i_j = lambda_i_j + sum(contrib);
                        end
                    end
                    Lambda(i,j) = lambda_i_j;
                end
                Lambda_normalize(i,1:w*T) = Lambda(i,1:w*T)./max(Lambda(i,1:w*T));
            end

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
        % Remove expired historical columns and update their rank estimates.
        for i = 1:M
            temp = length( find(U_W_idx(i,:)~=0) );
            if temp > 0
                if idx_oldest == U_W_idx(i,1) %
                    X_oldest_i = U_W(:,1,i);
                    U_W(:,1:temp-1,i) = U_W(:,2:temp,i);
                    U_W(:,temp,i) = 0;
                    U_W_idx(i,1:temp-1) = U_W_idx(i,2:temp);
                    U_W_idx(i,temp:w_size) = 0;

                    U_W_i = U_W(:,1:temp-1,i);
                    P_UW = U_W_i*pinv(U_W_i);
                    estimator = (norm(X_oldest_i - P_UW*X_oldest_i)^2) / (norm(X_oldest_i)^2+eps);
                    r_estimators(i,t) = estimator;
                    if estimator > param.yita
                        ranks(i) = ranks(i) - 1;
                    end
                end
            end
        end

        ranks = ranks + 1;
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
            for i = 1:M
                temp = length(find(U_W_idx(i,:)~=0));
                U_W_i = U_W(:,1:temp,i);
                X_t_i = X_t(i,:)';
                P_UW_i = U_W_i * pinv(U_W_i);
                estimator = (norm(X_t_i - P_UW_i * X_t_i)^2) / (norm(X_t_i)^2+eps);
                r_estimators(i,t) = estimator;
                if estimator > param.yita
                    ranks(i) = ranks(i) + 1;
                end
                U_W(:,temp+1,i) = X_t_i;
                U_W_idx(i,temp+1) = t;
            end
            Overhead_cputime_decision(t) = Overhead_cputime_decision(t) + (cputime-cputime_decision_start);
            % s1 U_W_Union
            U_W_union(:,size(U_W_union,2)+1,:) = X_t';
            temp = length(U_W_union_idx);
            U_W_union_idx(temp+1) = t;
            r_iscomplete(:,t) = 1;

            X_e_hat(:, (t-1)*T+1 : t*T) = X_e_hat_t;
            if beta_count == param.beta || t == num_batch

                % Separate recent anomalies and update event/history data.
                [W, U_W_union, ~, ~, Cauchy_MEDIANs,Cauchy_MADs,events,new_events,Omega_Cauchy] = detect_sampled_anomalies(W, U_W_union, U_W_union_idx, beta_count, param.SPIKE_LIMIT, param.DIP_LIMIT, Cauchy_MEDIANs, Cauchy_MADs, Cauchy_Trans, T,t,w_size,w, events,new_events, Omega_e,Omega_Anomalies_e,X_e_hat, W_idx);

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
                IDX_unrecover = find(r_iscomplete(:,incomplete_batch)==0)';
                if ~isempty(IDX_unrecover)
                    IDX_root_unrecover = [];
                    for ic = 1:numClusters
                        temp = length(find(IDX_root(ic,:)~=0));
                        IDX_root_ic = IDX_root(ic, 1:temp);
                        IDX_root_unrecover = [IDX_root_unrecover intersect(IDX_unrecover, IDX_root_ic)];
                    end
                    IDX_other_unrecover = setdiff(IDX_unrecover, IDX_root_unrecover);

                    for iru = IDX_root_unrecover
                        %
                        Omega_iru = Omega_e(iru, (incomplete_batch-1)*T+1:incomplete_batch*T);
                        Omega_iru_idx = find(Omega_iru==1);
                        Omega_iru_anomalies = Omega_Anomalies_e(iru, (incomplete_batch-1)*T+1:incomplete_batch*T);
                        Omega_iru_anomalies_idx = find(Omega_iru_anomalies==1);

                        X_e_hat_iru = X_e_hat(iru, (incomplete_batch-1)*T+1:incomplete_batch*T)';
                        X_e_hat_iru_omega = X_e_hat_iru(Omega_iru_idx);
                        X_e_hat_iru_omega_anomalies = X_e_hat_iru(Omega_iru_anomalies_idx);

                        enhanced_columns = augment_temporal_history(U_W_union(:,end-beta_count+1:end,iru), U_W_union_idx(end-beta_count+1:end)); %enhanced subspace
                        U_W_union_iru = [U_W_union(:,1:end-beta_count,iru) enhanced_columns];
                        X_e_hat_iru = U_W_union_iru*pinv(U_W_union_iru(Omega_iru_idx,:))*X_e_hat_iru_omega;

                        X_e_hat_iru(Omega_iru_idx,1) = X_e_hat_iru_omega;
                        X_e_hat_normal(iru, (incomplete_batch-1)*T+1:incomplete_batch*T) = X_e_hat_iru';
                        X_e_hat_iru(Omega_iru_anomalies_idx,1) = X_e_hat_iru_omega_anomalies;
                        X_e_hat(iru, (incomplete_batch-1)*T+1:incomplete_batch*T) = X_e_hat_iru';

                        r_iscomplete(iru, incomplete_batch) = 1;
                    end
                    for iou = IDX_other_unrecover
                        IDX_j_parent = find(B(iou,:)~=0);
                        U_W_j_parent = X_e_hat(IDX_j_parent, (incomplete_batch-1)*T+1:incomplete_batch*T)';

                        for j_par = IDX_j_parent
                            temp = length(U_W_union_idx);
                            U_W_j_par = U_W_union(:,1:temp,j_par);
                            U_W_j_parent = [U_W_j_parent U_W_j_par];
                        end
                        U_W_union_iou = U_W_union(:,:,iou);

                        Omega_iou = Omega_e(iou, (incomplete_batch-1)*T+1:incomplete_batch*T);
                        Omega_iou_idx = find(Omega_iou==1);
                        Omega_iou_anomalies = Omega_Anomalies_e(iou, (incomplete_batch-1)*T+1:incomplete_batch*T);
                        Omega_iou_anomalies_idx = find(Omega_iou_anomalies==1);

                        X_e_hat_iou = X_e_hat(iou, (incomplete_batch-1)*T+1:incomplete_batch*T)';
                        X_e_hat_iou_omega = X_e_hat_iou(Omega_iou_idx);
                        X_e_hat_iou_omega_anomalies = X_e_hat_iou(Omega_iou_anomalies_idx);

                        U_W_j_parent_omega = U_W_j_parent(Omega_iou_idx,:);
                        U_W_union_iou_omega = U_W_union_iou(Omega_iou_idx,:);

                        [alpha_cau, alpha_his] = fit_reconstruction_coefficients(X_e_hat_iou_omega, U_W_j_parent_omega, U_W_union_iou_omega, param.als_max_iter, param.als_tol);
                        X_e_hat_iou = U_W_j_parent*alpha_cau + U_W_union_iou*alpha_his;
                        X_e_hat_iou(Omega_iou_idx) = X_e_hat_iou_omega;
                        X_e_hat_normal(iou, (incomplete_batch-1)*T+1:incomplete_batch*T) = X_e_hat_iou';
                        X_e_hat_iou(Omega_iou_anomalies_idx) = X_e_hat_iou_omega_anomalies;
                        X_e_hat(iou, (incomplete_batch-1)*T+1:incomplete_batch*T) = X_e_hat_iou';

                        r_iscomplete(iou, incomplete_batch) = 1;
                    end
                end
                Overhead_cputime_reconstruction(t) = cputime - cputime_reconstruction_start;
                % s4
                if all(r_iscomplete(:, incomplete_batch))
                    disp(["OK", incomplete_batch]);
                end

                % Model Updater: incorporate newly sampled anomalies (Section 4.6).
                cputime_modelupdate_start = cputime;
                [anomaly_mu,anomaly_A,anomaly_beta, S_mu,S_A,S_beta] = update_anomaly_model(anomaly_mu,anomaly_A,anomaly_beta, events, new_events, w,T, M, anomaly_max_iter, anomaly_tolerance, S_mu,S_A,S_beta, Par, W_idx);
                Overhead_cputime_modelupdate(t) = cputime - cputime_modelupdate_start;
                for i = 1:M
                    for j = (t-w_size+w-beta_count)*T+1:(t-w_size+w)*T
                        % lambda_i(j)
                        lambda_i_j = anomaly_mu(i);
                        for m_prime = Par{i}
                            past_events = events{m_prime}(events{m_prime}<=j);
                            if ~isempty(past_events)
                                dt = j-past_events;
                                contrib = anomaly_A(i, m_prime) * anomaly_beta(i, m_prime) * exp(-anomaly_beta(i, m_prime)*dt);
                                lambda_i_j = lambda_i_j + sum(contrib);
                            end
                        end
                        Lambda(i,j) = lambda_i_j;
                    end
                    Lambda_normalize(i,(t-w_size+w-beta_count)*T+1:(t-w_size+w)*T) = Lambda(i,(t-w_size+w-beta_count)*T+1:(t-w_size+w)*T)./max(Lambda(i,:));
                end

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

                    if ismember(j_ord_idx, IDX_root_i)
                        % Root metric: use its temporal-rank estimate.
                        r_j = ranks(j_ord_idx);
                        numSamples_j = max(param.theta_r*r_j*log(r_j), 1);
                    else
                        % Child metric: use its local causal rank (parent count).
                        j_parent_idx = Ord_i(B_i(j,:) ~=0);
                        r_j = length(j_parent_idx);
                        numSamples_j = max(param.theta_c*r_j*log(r_j), 1);
                    end
                    % Composite Sampler: combine base collection with anomaly-guided
                    % candidates; detected anomalies update the shared event history.
                    [Omega_t_j_ord_idx, Omega_t_j_ord_idx_r,Omega_t_j_ord_idx_L, Anomalies_t_omega_j_ord_idx, Omega_Anomalies_e, events, new_events, Lambda,Lambda_normalize] = composite_sampler(j_ord_idx, numSamples_j, T, param, X_t(j_ord_idx, :), X_e_hat, Omega_e, Omega_Anomalies_e, events,new_events, Par, Cauchy_MEDIANs,Cauchy_MADs,Cauchy_Trans, W_idx, w_size,w, anomaly_mu,anomaly_A,anomaly_beta, Lambda,Lambda_normalize);

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
                for j = IDX_root_i
                    temp = length(find(U_W_idx(j,:)~=0));
                    idx_t_omega = find(Omega_t(j,:)~=0);
                    idx_t_omega_anomalies = find(Anomalies_t_omega(j,:)==1); %----------------------
                    %idx_t_omega = unique([idx_t_omega, idx_t_omega_anomalies]);
                    X_t_omega_j = X_t_omega(j, idx_t_omega)';
                    if temp>0
                        U_W_j = U_W(:,1:temp,j);
                        P_UWj_omega = U_W_j(idx_t_omega,:) * pinv(U_W_j(idx_t_omega,:));
                        estimator_j = (norm(X_t_omega_j - P_UWj_omega*X_t_omega_j)^2) / (norm(X_t_omega_j)^2+eps);
                    else
                        estimator_j = 1;
                    end
                    r_estimators(j,t) = estimator_j;

                    if estimator_j < param.yita
                        % Reconstruct a root using its historical temporal representation.
                        X_e_hat_t_j = U_W_j*pinv(U_W_j(idx_t_omega,:))*X_t_omega_j;
                        X_e_hat_t(j,:) = X_e_hat_t_j';
                        X_e_hat_t(j, idx_t_omega) = X_t_omega_j';
                        X_e_hat_t_normal(j,:) = X_e_hat_t(j,:);
                        X_e_hat_t(j, idx_t_omega_anomalies) = X_t(j, idx_t_omega_anomalies);

                        r_iscomplete(j,t) = 1;
                        ranks(j) = ranks(j) - 1;
                    else
                        r_iscomplete(j,t) = 0;

                        X_e_hat_t(j, idx_t_omega) = X_t_omega_j';
                        X_e_hat_t_normal(j, idx_t_omega) = X_t_omega_j';
                        X_e_hat_t(j, idx_t_omega_anomalies) = X_t(j, idx_t_omega_anomalies);
                        disp(['Root reconstruction unavailable for metric ', num2str(j)])
                    end
                end

                % Reconstruct children using causal and temporal representations.
                for j = IDX_other_i

                    IDX_j_parent = find(B(j,:)~=0);
                    iscomplete_j = 1;
                    if ismember(0, r_iscomplete(IDX_j_parent,t))
                        iscomplete_j = 0;
                    else
                        U_W_j_parent = X_e_hat_t(IDX_j_parent,:)';
                        %U_W_j_parent = [];
                        for j_par = IDX_j_parent
                            temp = length(find(U_W_idx(j_par,:)~=0));
                            U_W_j_par = U_W(:,1:temp,j_par);
                            U_W_j_parent = [U_W_j_parent U_W_j_par];
                        end
                        temp = length(find(U_W_idx(j,:)~=0));
                        if temp>0
                            U_W_j = U_W(:,1:temp,j);
                        else
                            iscomplete_j = 0;
                        end
                    end
                    idx_t_omega = find(Omega_t(j,:)==1);
                    idx_t_omega_anomalies = find(Anomalies_t_omega(j,:)==1); %--------------------------
                    X_t_omega_j = X_t_omega(j,idx_t_omega)';

                    if iscomplete_j
                        U_W_j_parent = [U_W_j_parent U_W_j];
                        U_W_j_parent_omega = U_W_j_parent(idx_t_omega, :);
                        P_UWjparent_omega = U_W_j_parent_omega * pinv(U_W_j_parent_omega);
                        estimator_j = (norm(X_t_omega_j  - P_UWjparent_omega*X_t_omega_j)^2) / (norm(X_t_omega_j)^2+eps);
                    else
                        estimator_j = 1;
                    end
                    r_estimators(j,t) = estimator_j;
                    if estimator_j < param.yita

                        X_e_hat_j = U_W_j_parent * pinv(U_W_j_parent_omega) * X_t_omega_j;
                        X_e_hat_t(j, :) = X_e_hat_j';
                        X_e_hat_t(j, idx_t_omega) = X_t_omega(j,idx_t_omega);
                        X_e_hat_t_normal(j,:) = X_e_hat_t(j,:);
                        X_e_hat_t(j, idx_t_omega_anomalies) = X_t(j,idx_t_omega_anomalies);

                        r_iscomplete(j,t) = 1;
                    else
                        if iscomplete_j
                            [alpha_cau, alpha_his] = fit_reconstruction_coefficients(X_t_omega_j, U_W_j_parent_omega, U_W_j(idx_t_omega,:), param.als_max_iter, param.als_tol);
                            X_e_hat_j = U_W_j_parent*alpha_cau + U_W_j*alpha_his;
                            X_e_hat_t(j,:) = X_e_hat_j';
                            X_e_hat_t(j, idx_t_omega) = X_t_omega(j,idx_t_omega);
                            X_e_hat_t_normal(j,:) = X_e_hat_t(j,:);
                            X_e_hat_t(j, idx_t_omega_anomalies) = X_t(j,idx_t_omega_anomalies);
                            r_iscomplete(j,t) = 1;
                        else
                            r_iscomplete(j,t) = 0;
                            X_e_hat_t(j, idx_t_omega) = X_t_omega_j';
                            X_e_hat_t_normal(j, idx_t_omega) = X_t_omega_j';
                            X_e_hat_t(j, idx_t_omega_anomalies) = X_t(j, idx_t_omega_anomalies);
                            disp(['Child reconstruction unavailable for metric ', num2str(j)])
                        end
                    end
                    ranks(j) = ranks(j) - 1;
                end
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
            [anomaly_mu,anomaly_A,anomaly_beta, S_mu,S_A,S_beta] = update_anomaly_model(anomaly_mu,anomaly_A,anomaly_beta, events, new_events, w,T, M, anomaly_max_iter, anomaly_tolerance, S_mu,S_A,S_beta, Par, W_idx);
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
