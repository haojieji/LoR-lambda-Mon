function [r_Stru_i, r_B_i, r_Ord] = discover_causal_dependencies(IDX_i, W)
% DISCOVER_CAUSAL_DEPENDENCIES Order, prune, and fit one metric cluster.
%   Sparse Causal Structure Extractor, Step 2 (Section 4.1).
%   IDX_i is a row vector of K original metric indices into M-by-N training
%   data W. Return K-by-K adjacency r_Stru_i and weights r_B_i in causal-order
%   coordinates: (a,b) means r_Ord(b) -> r_Ord(a). r_Ord is a row vector of
%   original metric indices, not cluster-local positions.
%   Working orders/adjacency use positions 1:K in W(IDX_i,:); ols3 reorders
%   the fitted matrix before return. KernelICA attribution is retained below.

    cluster_data = W(IDX_i, :);
    [cluster_metric_count, num_times] = size(cluster_data);
    residual_data = cluster_data;
    local_order = [];
    remaining_local_indices = 1:cluster_metric_count;
    % 1. Center each metric before residual-dependence ordering.
    residual_data = bsxfun(@minus, residual_data, mean(residual_data, 2));

    r_Stru_i = ones(cluster_metric_count,cluster_metric_count);

    % 2. Repeatedly select the least dependent remaining metric.
    iteration=1;
    while length(local_order) < cluster_metric_count-1
        candidates = setdiff(remaining_local_indices, local_order);
        % Residual slice (:,:,k) removes candidate k from remaining metrics.
        candidate_residuals = computeR( residual_data, candidates, remaining_local_indices, r_Stru_i);
        iteration = iteration+1;
        % Choose the candidate with the lowest residual-dependence score.
        if length(candidates) ==1
            selected_local_idx = candidates;
        else
            selected_local_idx = findindex( residual_data, candidate_residuals, candidates, remaining_local_indices);
        end
        % Append its cluster-local position to the causal order.
        local_order = [local_order selected_local_idx];

        remaining_local_indices(remaining_local_indices == selected_local_idx) = [];

        % Prune dependencies between the remaining residuals.
        r_Stru_i = rmSuprious( candidate_residuals, remaining_local_indices, selected_local_idx, r_Stru_i );

        % Continue with the selected metric's effect removed.
        residual_data = candidate_residuals(:,:,selected_local_idx);
    end
    local_order = [local_order remaining_local_indices];
    r_Ord = IDX_i(local_order);

    ordered_structure = r_Stru_i(local_order, local_order);
    ordered_structure = tril(ordered_structure, -1);
    r_Stru_i(local_order, local_order) = ordered_structure;

    % 3. Fit retained edges; ols3 returns weights in causal-order coordinates.

    r_B_i = ols3(cluster_data, local_order, r_Stru_i);
    r_Stru_i = r_B_i ~= 0;
end

function [J] = my_call_contrast(x)
% Author: Yasuhiro Sogawa
% Modified by SS (27 Sep 2010)
% my_call_contrast - set parameters of KernelICA.
% and call a contrast function employed in KernelICA.
% The details of the parameters are shown in section 4.5,
% "Kernel Independent Component Analysis" (F. R. Bachand and M.I.Jordan).

[m,N]=size(x);

% set the parameters
contrast='kgv';
% contrast='kcca';
if N < 1000
    sigma=1;
    kappa=2e-2;
else % Added by SS (24 Sep 2010)
    sigma = 1/2;
    kappa = 2e-3;
end

kernel='gaussian';

mc=m;
kparam.kappas=kappa*ones(1,mc);
kparam.etas=kappa*1e-2*ones(1,mc);
kparam.neigs=N*ones(1,mc);
kparam.nchols=N*ones(1,mc);
kparam.kernel=kernel;
kparam.sigmas=sigma*ones(1,mc);

% Commented out by SS (24 Sep 2010)
% % scales data
% covmatrix=x*x'/N;
% sqrcovmatrix=sqrtm(covmatrix);
% invsqrcovmatrix=inv(sqrcovmatrix);
% x=invsqrcovmatrix*x;

% perform contrast function
J = contrast_ica(contrast,x,kparam);

end

function R = computeR( X, candidates, U_K, M )
% M is retained for signature compatibility; residuals do not consult it.

    [p,n] = size( X );
    R = zeros(p,n,p);
    Cov = cov(X');

    for j = candidates
        if Cov(j,j)~=0
            for i = setdiff(U_K, j)
                % Regress each remaining row on candidate j.
                R(i,:,j) = X(i,:) - Cov(i,j)/Cov(j,j)*X(j,:);
            end
        end
    end

end

function index = findindex( X, R, candidates, U_K )

    p = size(X,1);

    % calculate T
    T_MI = NaN(1,p);

    minT = -1; %% SS (24 Sep 2010)

    for j = candidates

        if minT == -1 %% SS (24 Sep 2010) Input: minT, X, R, j
            T_MI(j) = 0;
            for i = setdiff(U_K, j)
                if all(R(i,:,j) == 0)
                    R(i,:,j) = R(i,:,j) + 1e-10 * randn(1, size(R,2));
                end
                J = my_call_contrast([R(i,:,j); X(j,:)]); %using kernel based independence measure
                if isnan(J)
                    warning('NaN detected, using fallback value');
                    J = 0;
                end
                T_MI(j) = T_MI(j) + J;
            end
            minT = T_MI(j);
        else
            T_MI(j) = 0;
            for i = setdiff(U_K, j)
                if all(R(i,:,j) == 0)
                    R(i,:,j) = R(i,:,j) + 1e-10 * randn(1, size(R,2));
                end
                J = my_call_contrast([R(i,:,j); X(j,:)]); %using kernel based independence measure
                if isnan(J)
                    warning('NaN detected, using fallback value');
                    J = 0;
                end
                T_MI(j) = T_MI(j) + J;
                if T_MI(j) > minT
                    T_MI(j) = Inf;
                    break;
                end
            end
            minT = min( [ T_MI(j), minT ] );
        end %% SS (24 Sep 2010) Output: minT, T(j)

        T_MI(j)

    end
    % find argmin T
    [minval, index] = min(T_MI);

end

% Prune both candidate directions when the residual pair is independent
% after removing the selected metric; indices remain cluster-local.
function r_Stru = rmSuprious( Res, K_Ord, index, r_Stru )
    R = Res(:,:,index);
    for j = 1:length(K_Ord)
        j_ord = K_Ord(j);
        for i = j+1:length(K_Ord)
            i_ord = K_Ord(i);
            if r_Stru(j_ord,i_ord)==1 || r_Stru(i_ord,j_ord)==1
                J = my_call_contrast(R([j_ord i_ord],:)); %using kernel based independence measure
                if J < 0.001
                    r_Stru(j_ord, i_ord) = 0;
                    r_Stru(i_ord, j_ord) = 0;
                end
            end
        end
    end
end
