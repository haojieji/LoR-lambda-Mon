function varargout = Low_Rank_Sampler(operation, varargin)
% LOW_RANK_SAMPLER Maintain temporal ranks and determine base sample budgets.
%   Paper Section 4.2. The pipeline calls these operations in batch order:
%     initialize : allocate temporal representations and rank state.
%     train      : add a fully collected training segment and test its rank.
%     advance    : remove expired history and estimate the new window rank.
%     observe    : add a fully collected recovery segment to temporal history.
%     budget     : use temporal rank for a root or parent count for a child.
%   Local function signatures below list each operation's inputs and outputs.
%   U_W stores historical columns; ranks stores per-metric temporal estimates.
%   The budget output is a sample count passed to Composite_Sampler, which
%   constructs the base schedule. No new clipping or rounding is introduced.

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

function [U_W, U_W_idx, U_W_union, U_W_union_idx, U_W_basis, U_W_basis_idx, ranks, r_estimators] = ...
    add_training_segment(X_t, t, M, param, U_W, U_W_idx, U_W_union, U_W_union_idx, ...
    U_W_basis, U_W_basis_idx, ranks, r_estimators)
U_W(:,t,:) = X_t';
U_W_idx(:,t) = ones(M,1)*t;
U_W_union(:,t,:) = X_t';
U_W_union_idx(t) = t;
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
end

function [U_W, U_W_idx, ranks, r_estimators] = ...
    advance_history(idx_oldest, M, w_size, param, t, U_W, U_W_idx, ranks, r_estimators)
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
end

function [U_W, U_W_idx, ranks, r_estimators] = ...
    add_recovery_segment(X_t, t, M, param, U_W, U_W_idx, ranks, r_estimators)
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
end

function numSamples_j = sample_budget(j_ord_idx, IDX_root_i, ranks, Ord_i, B_i, j, param)
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
end
