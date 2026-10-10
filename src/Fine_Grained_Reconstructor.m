function varargout = Fine_Grained_Reconstructor(operation, varargin)
% FINE_GRAINED_RECONSTRUCTOR Recover unsampled root and child metric values.
%   Paper Section 4.5. The pipeline supplies sampled values, temporal history,
%   causal weights and existing recovery state through one of two operations:
%     batch   : reconstruct one DAG's roots, then its children in causal order.
%     delayed : revisit an incomplete batch after collecting recovery batches.
%   Local function signatures specify the inputs and outputs of each path.
%   Root metrics use temporal history; children also use parent trajectories.
%   Both paths restore sampled values, including captured anomalies. Existing
%   completion flags and rank adjustments are returned to the pipeline.

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
    reconstruct_batch(IDX_root_i, IDX_other_i, U_W, U_W_idx, Omega_t, Anomalies_t_omega, ...
    X_t_omega, X_t, X_e_hat_t, X_e_hat_t_normal, r_estimators, r_iscomplete, ranks, B, param, t)
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
end

function [X_e_hat, X_e_hat_normal, r_iscomplete] = ...
    reconstruct_delayed(r_iscomplete, incomplete_batch, numClusters, IDX_root, Omega_e, ...
    Omega_Anomalies_e, X_e_hat, X_e_hat_normal, U_W_union, U_W_union_idx, beta_count, B, param, T)
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
end
