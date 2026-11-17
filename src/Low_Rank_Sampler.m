function varargout = Low_Rank_Sampler(operation, varargin)
% LOW_RANK_SAMPLER Maintain temporal histories and base sample budgets.
%   Section IV-B: Low-Rank Sampler.
%   initialize: allocate history, basis, rank, and batch-index arrays.
%   train/observe: incorporate a fully collected training/recovery batch.
%   advance: expire old history and provisionally increment temporal ranks.
%   budget: use temporal rank for root metrics and parent count for child metrics.
%
%   U_W is T-by-history_count-by-M; U_W_idx stores enhanced batch indices.
%   Zero indices mark unused columns. ranks is 1-by-M; r_estimators stores
%   sampled residuals by metric and batch. Only fully collected batches enter
%   U_W. The budget uses theta_r or theta_c and is at least one sample.
%   The paper-to-code map and budget convention are in ../algorithm_overview.md.

switch operation
    case 'initialize'
        [varargout{1:nargout}] = initialize_history(varargin{:});
    case 'train'
        [varargout{1:nargout}] = add_training_segment(varargin{:});
    case 'advance'
        [varargout{1:nargout}] = advance_history(varargin{:});
    case 'observe'
        [varargout{1:nargout}] = add_recovery_segment(varargin{:});
    case 'budget'
        [varargout{1:nargout}] = sample_budget(varargin{:});
    otherwise
        error('Unknown Low-Rank Sampler operation: %s', operation);
end
end

function [U_W, U_W_idx, U_W_basis, U_W_basis_idx, ranks, U_W_union, U_W_union_idx] = ...
    initialize_history(T, w_size, M)
U_W = zeros(T,w_size,M);
U_W_idx = zeros(M, w_size);
U_W_basis = zeros(T,w_size,M);
U_W_basis_idx = zeros(M,w_size);
ranks = zeros(1,M);
U_W_union = [];
U_W_union_idx = [];
end

function [U_W, U_W_idx, U_W_union, U_W_union_idx, U_W_basis, U_W_basis_idx, ranks, ...
    r_estimators] = ...
    add_training_segment(X_t, batch_idx, M, param, U_W, U_W_idx, U_W_union, U_W_union_idx, ...
    U_W_basis, U_W_basis_idx, ranks, r_estimators)
U_W(:,batch_idx,:) = X_t';
U_W_idx(:,batch_idx) = ones(M,1)*batch_idx;
U_W_union(:,batch_idx,:) = X_t';
U_W_union_idx(batch_idx) = batch_idx;
for metric_idx = 1:M
    r_i = ranks(metric_idx);
    U_W_basis_i = U_W_basis(:,1:r_i,metric_idx);
    X_t_i = X_t(metric_idx,:)';
    P_UWbasis_i = U_W_basis_i * pinv(U_W_basis_i);
    estimator = (norm(X_t_i - P_UWbasis_i * X_t_i)^2) / (norm(X_t_i)^2+eps);
    r_estimators(metric_idx,batch_idx) = estimator;

    if estimator > param.yita
        r_i = r_i + 1;
        U_W_basis(:, r_i, metric_idx) = X_t_i;
        U_W_basis_idx(metric_idx,r_i) = batch_idx;
        ranks(metric_idx) = r_i;
    end
end
end

function [U_W, U_W_idx, ranks, r_estimators] = ...
    advance_history(oldest_batch_idx, M, w_size, param, batch_idx, U_W, U_W_idx, ranks, ...
    r_estimators)
% Each metric keeps its occupied history columns at the front of U_W.
for metric_idx = 1:M
    history_count = length( find(U_W_idx(metric_idx,:)~=0) );
    if history_count > 0
        if oldest_batch_idx == U_W_idx(metric_idx,1)
            X_oldest_i = U_W(:,1,metric_idx);
            U_W(:,1:history_count-1,metric_idx) = U_W(:,2:history_count,metric_idx);
            U_W(:,history_count,metric_idx) = 0;
            U_W_idx(metric_idx,1:history_count-1) = U_W_idx(metric_idx,2:history_count);
            U_W_idx(metric_idx,history_count:w_size) = 0;

            U_W_i = U_W(:,1:history_count-1,metric_idx);
            P_UW = U_W_i*pinv(U_W_i);
            estimator = (norm(X_oldest_i - P_UW*X_oldest_i)^2) / (norm(X_oldest_i)^2+eps);
            r_estimators(metric_idx,batch_idx) = estimator;
            if estimator > param.yita
                ranks(metric_idx) = ranks(metric_idx) - 1;
            end
        end
    end
end

% Preserve the current-batch rank increment for every metric.
ranks = ranks + 1;
end

function [U_W, U_W_idx, ranks, r_estimators] = ...
    add_recovery_segment(X_t, batch_idx, M, param, U_W, U_W_idx, ranks, r_estimators)
for metric_idx = 1:M
    history_count = length(find(U_W_idx(metric_idx,:)~=0));
    U_W_i = U_W(:,1:history_count,metric_idx);
    X_t_i = X_t(metric_idx,:)';
    P_UW_i = U_W_i * pinv(U_W_i);
    estimator = (norm(X_t_i - P_UW_i * X_t_i)^2) / (norm(X_t_i)^2+eps);
    r_estimators(metric_idx,batch_idx) = estimator;
    if estimator > param.yita
        ranks(metric_idx) = ranks(metric_idx) + 1;
    end
    U_W(:,history_count+1,metric_idx) = X_t_i;
    U_W_idx(metric_idx,history_count+1) = batch_idx;
end
end

function sample_count = sample_budget(metric_idx, root_metric_indices, ranks, ...
    ordered_metric_indices, B_cluster, local_metric_idx, param)
if ismember(metric_idx, root_metric_indices)
    % Root metric: use its temporal-rank estimate.
    r_j = ranks(metric_idx);
    sample_count = max(param.theta_r*r_j*log(r_j), 1);
else
    % Child metric: scale the local rank term using its parent count.
    % The implementation does not explicitly evaluate the joint K,l,delta bound.
    parent_metric_indices = ordered_metric_indices(B_cluster(local_metric_idx,:) ~=0);
    r_j = length(parent_metric_indices);
    sample_count = max(param.theta_c*r_j*log(r_j), 1);
end
end
