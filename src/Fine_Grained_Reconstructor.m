function varargout = Fine_Grained_Reconstructor(operation, varargin)
% FINE_GRAINED_RECONSTRUCTOR Estimate unsampled root and child metric values.
%   Section IV-E: Fine-Grained Reconstructor.
%   batch: reconstruct root metrics from temporal history, then fit child metrics
%   using parent data. If the sampled residual
%   is at least yita, regularized ALS combines this parent dictionary with a
%   separate block of the child's own history.
%   delayed: retry a pending batch after fully collected recovery batches.
%
%   U_W is T-by-history_count-by-M; U_W_idx identifies its occupied columns.
%   Omega_t/Anomalies_t_omega are M-by-T observation indicators.
%   X_e_hat_t/X_e_hat_t_normal are M-by-T estimates with/without sampled anomalies.
%   r_estimators/r_iscomplete store residuals/completion flags by metric and batch.
%   B(child,parent) identifies an edge; batch children follow the supplied order.
%   Delayed recovery processes root metrics first, then children by metric index.
%   Observed values are restored after fitting.
%   See ../algorithm_overview.md for the reconstruction workflow.

switch operation
    case 'batch'
        [varargout{1:nargout}] = reconstruct_batch(varargin{:});
    case 'delayed'
        [varargout{1:nargout}] = reconstruct_delayed(varargin{:});
    otherwise
        error('Unknown Fine-Grained Reconstructor operation: %s', operation);
end
end

function [X_e_hat_t, X_e_hat_t_normal, r_estimators, r_iscomplete, ranks] = ...
    reconstruct_batch(IDX_root_i, IDX_child_i, U_W, U_W_idx, Omega_t, Anomalies_t_omega, ...
    X_t_omega, X_t, X_e_hat_t, X_e_hat_t_normal, r_estimators, r_iscomplete, ranks, B, param, t)
% 1. Test each root against its own temporal history.
for metric_idx = IDX_root_i
    history_count = length(find(U_W_idx(metric_idx,:)~=0));
    sample_time_indices = find(Omega_t(metric_idx,:)~=0);
    anomaly_time_indices = find(Anomalies_t_omega(metric_idx,:)==1);
    sample_values = X_t_omega(metric_idx, sample_time_indices)';
    if history_count>0
        metric_history = U_W(:,1:history_count,metric_idx);
        sample_history_projection = metric_history(sample_time_indices,:) * pinv(metric_history(sample_time_indices,:));
        residual_estimate = (norm(sample_values - sample_history_projection*sample_values)^2) / (norm(sample_values)^2+eps);
    else
        residual_estimate = 1;
    end
    r_estimators(metric_idx,t) = residual_estimate;

    if residual_estimate < param.yita
        % Reconstruct a root using its historical temporal representation Equation (19).
        reconstructed_root_values = metric_history*pinv(metric_history(sample_time_indices,:))*sample_values;
        X_e_hat_t(metric_idx,:) = reconstructed_root_values';
        X_e_hat_t(metric_idx, sample_time_indices) = sample_values';
        X_e_hat_t_normal(metric_idx,:) = X_e_hat_t(metric_idx,:);
        X_e_hat_t(metric_idx, anomaly_time_indices) = X_t(metric_idx, anomaly_time_indices);

        r_iscomplete(metric_idx,t) = 1;
        ranks(metric_idx) = ranks(metric_idx) - 1;
    else
        r_iscomplete(metric_idx,t) = 0;

        X_e_hat_t(metric_idx, sample_time_indices) = sample_values';
        X_e_hat_t_normal(metric_idx, sample_time_indices) = sample_values';
        X_e_hat_t(metric_idx, anomaly_time_indices) = X_t(metric_idx, anomaly_time_indices);
        disp(['Root reconstruction unavailable for metric ', num2str(metric_idx)])
    end
end

% 2. Reconstruct children in the supplied causal order.
for metric_idx = IDX_child_i

    parent_metric_indices = find(B(metric_idx,:)~=0);
    can_fit_child = 1;
    if ismember(0, r_iscomplete(parent_metric_indices,t))
        can_fit_child = 0;
    else
        reconstruction_dictionary = X_e_hat_t(parent_metric_indices,:)';
        for parent_metric_idx = parent_metric_indices
            history_count = length(find(U_W_idx(parent_metric_idx,:)~=0));
            parent_history = U_W(:,1:history_count,parent_metric_idx);
            reconstruction_dictionary = [reconstruction_dictionary parent_history];
        end
        history_count = length(find(U_W_idx(metric_idx,:)~=0));
        if history_count>0
            metric_history = U_W(:,1:history_count,metric_idx);
        else
            can_fit_child = 0;
        end
    end
    sample_time_indices = find(Omega_t(metric_idx,:)==1);
    anomaly_time_indices = find(Anomalies_t_omega(metric_idx,:)==1);
    sample_values = X_t_omega(metric_idx,sample_time_indices)';

    % test the child can be reconstructed by its parents
    if can_fit_child
        sample_dictionary = reconstruction_dictionary(sample_time_indices, :);
        sample_dictionary_projection = sample_dictionary * pinv(sample_dictionary);
        residual_estimate = (norm(sample_values  - sample_dictionary_projection*sample_values)^2) / (norm(sample_values)^2+eps);
    else
        residual_estimate = 1;
    end
    r_estimators(metric_idx,t) = residual_estimate;
    if residual_estimate < param.yita
        % reconstructed by its parents Section IV-E
        reconstructed_values = reconstruction_dictionary * pinv(sample_dictionary) * sample_values;
        X_e_hat_t(metric_idx, :) = reconstructed_values';
        X_e_hat_t(metric_idx, sample_time_indices) = X_t_omega(metric_idx,sample_time_indices);
        X_e_hat_t_normal(metric_idx,:) = X_e_hat_t(metric_idx,:);
        X_e_hat_t(metric_idx, anomaly_time_indices) = X_t(metric_idx,anomaly_time_indices);

        r_iscomplete(metric_idx,t) = 1;
    else
        if can_fit_child
            % reconstructed by its parents and its temporal history Equation (20).
            [alpha_cau, alpha_his] = fit_reconstruction_coefficients(sample_values, sample_dictionary, metric_history(sample_time_indices,:), param.als_max_iter, param.als_tol);
            reconstructed_values = reconstruction_dictionary*alpha_cau + metric_history*alpha_his;
            X_e_hat_t(metric_idx,:) = reconstructed_values';
            X_e_hat_t(metric_idx, sample_time_indices) = X_t_omega(metric_idx,sample_time_indices);
            X_e_hat_t_normal(metric_idx,:) = X_e_hat_t(metric_idx,:);
            X_e_hat_t(metric_idx, anomaly_time_indices) = X_t(metric_idx,anomaly_time_indices);
            r_iscomplete(metric_idx,t) = 1;
        else
            r_iscomplete(metric_idx,t) = 0;
            X_e_hat_t(metric_idx, sample_time_indices) = sample_values';
            X_e_hat_t_normal(metric_idx, sample_time_indices) = sample_values';
            X_e_hat_t(metric_idx, anomaly_time_indices) = X_t(metric_idx, anomaly_time_indices);
            disp(['Child reconstruction unavailable for metric ', num2str(metric_idx)])
        end
    end
    ranks(metric_idx) = ranks(metric_idx) - 1;
end
end

function [X_e_hat, X_e_hat_normal, r_iscomplete] = ...
    reconstruct_delayed(r_iscomplete, incomplete_batch, numClusters, IDX_root, Omega_e, ...
    Omega_Anomalies_e, X_e_hat, X_e_hat_normal, U_W_union, U_W_union_idx, beta_count, B, param, T)
incomplete_metric_indices = find(r_iscomplete(:,incomplete_batch)==0)';
if ~isempty(incomplete_metric_indices)
    incomplete_root_indices = [];
    for cluster_idx = 1:numClusters
        root_count = length(find(IDX_root(cluster_idx,:)~=0));
        cluster_root_indices = IDX_root(cluster_idx, 1:root_count);
        incomplete_root_indices = [incomplete_root_indices intersect(incomplete_metric_indices, cluster_root_indices)];
    end
    incomplete_child_indices = setdiff(incomplete_metric_indices, incomplete_root_indices);

    % 1. Enrich each root's recovery history with shifted adjacent batches.
    for root_metric_idx = incomplete_root_indices
        root_sample_mask = Omega_e(root_metric_idx, (incomplete_batch-1)*T+1:incomplete_batch*T);
        root_sample_times = find(root_sample_mask==1);
        root_anomaly_mask = Omega_Anomalies_e(root_metric_idx, (incomplete_batch-1)*T+1:incomplete_batch*T);
        root_anomaly_times = find(root_anomaly_mask==1);

        root_values = X_e_hat(root_metric_idx, (incomplete_batch-1)*T+1:incomplete_batch*T)';
        root_sample_values = root_values(root_sample_times);
        root_anomaly_values = root_values(root_anomaly_times);

        enhanced_columns = augment_temporal_history(U_W_union(:,end-beta_count+1:end,root_metric_idx), U_W_union_idx(end-beta_count+1:end));
        root_dictionary = [U_W_union(:,1:end-beta_count,root_metric_idx) enhanced_columns];
        root_values = root_dictionary*pinv(root_dictionary(root_sample_times,:))*root_sample_values;

        root_values(root_sample_times,1) = root_sample_values;
        X_e_hat_normal(root_metric_idx, (incomplete_batch-1)*T+1:incomplete_batch*T) = root_values';
        root_values(root_anomaly_times,1) = root_anomaly_values;
        X_e_hat(root_metric_idx, (incomplete_batch-1)*T+1:incomplete_batch*T) = root_values';

        r_iscomplete(root_metric_idx, incomplete_batch) = 1;
    end
    % 2. Fit children using parent data and the child's own history.
    % setdiff above preserves the existing sorted original-index traversal.
    for child_metric_idx = incomplete_child_indices
        parent_metric_indices = find(B(child_metric_idx,:)~=0);
        parent_dictionary = X_e_hat(parent_metric_indices, (incomplete_batch-1)*T+1:incomplete_batch*T)';

        for parent_metric_idx = parent_metric_indices
            history_count = length(U_W_union_idx);
            parent_history = U_W_union(:,1:history_count,parent_metric_idx);
            parent_dictionary = [parent_dictionary parent_history];
        end
        child_history = U_W_union(:,:,child_metric_idx);

        child_sample_mask = Omega_e(child_metric_idx, (incomplete_batch-1)*T+1:incomplete_batch*T);
        child_sample_times = find(child_sample_mask==1);
        child_anomaly_mask = Omega_Anomalies_e(child_metric_idx, (incomplete_batch-1)*T+1:incomplete_batch*T);
        child_anomaly_times = find(child_anomaly_mask==1);

        child_values = X_e_hat(child_metric_idx, (incomplete_batch-1)*T+1:incomplete_batch*T)';
        child_sample_values = child_values(child_sample_times);
        child_anomaly_values = child_values(child_anomaly_times);

        sample_parent_dictionary = parent_dictionary(child_sample_times,:);
        sample_child_history = child_history(child_sample_times,:);

        [alpha_cau, alpha_his] = fit_reconstruction_coefficients(child_sample_values, sample_parent_dictionary, sample_child_history, param.als_max_iter, param.als_tol);
        child_values = parent_dictionary*alpha_cau + child_history*alpha_his;
        child_values(child_sample_times) = child_sample_values;
        X_e_hat_normal(child_metric_idx, (incomplete_batch-1)*T+1:incomplete_batch*T) = child_values';
        child_values(child_anomaly_times) = child_anomaly_values;
        X_e_hat(child_metric_idx, (incomplete_batch-1)*T+1:incomplete_batch*T) = child_values';

        r_iscomplete(child_metric_idx, incomplete_batch) = 1;
    end
end
end
