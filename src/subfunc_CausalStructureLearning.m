% subfunc_CausalStructureLearning
%
% Learn the sparse causal structure for each metric cluster.
%
% Input:
%   p_groups      Cluster assignment for each metric
%   p_numClusters Number of clusters
%   W             Training window, M-by-time
%
% Output:
%   r_B              Weighted causal adjacency matrix
%   r_Stru           Binary causal adjacency matrix
%   r_Ord            Metric order in each cluster
%   r_IDX_root       Metrics with no parents in each learned DAG
%   r_IDX_intermedia Metrics with both parents and children in each DAG
function [r_B, r_Stru, r_Ord, r_IDX_root, r_IDX_intermedia] = subfunc_CausalStructureLearning(p_groups, p_numClusters, W)
    M = size(W,1);
    r_B = zeros(M, M);
    r_Stru = zeros(M, M);
    r_Ord = zeros(p_numClusters, M);

    r_IDX_root = zeros(p_numClusters, M);
    r_IDX_intermedia = zeros(p_numClusters, M);
    for i = 1:p_numClusters
        IDX_i = find(p_groups' == i);
        [r_Stru_i, r_B_i, r_Ord_i] = subfunc_CausalDiscovery_Dlingam(IDX_i, W);

        r_B(r_Ord_i, r_Ord_i) = r_B_i;
        r_Stru(r_Ord_i, r_Ord_i) = r_Stru_i;
        r_Ord(i,1:length(r_Ord_i)) = r_Ord_i;

        % Root metrics are source nodes in the learned DAG.  Anomaly
        % separation is handled by the robust anomaly-detection/sampling
        % stages instead of a separate root-cause helper.
        idx_root_local = find(sum(r_Stru_i, 2) == 0);
        idx_intermedia_local = find(sum(r_Stru_i, 2) > 0 & sum(r_Stru_i, 1)' > 0);

        r_IDX_root_i = r_Ord_i(idx_root_local);
        r_IDX_intermedia_i = r_Ord_i(idx_intermedia_local);
        r_IDX_root(i, 1:length(r_IDX_root_i)) = r_IDX_root_i;
        r_IDX_intermedia(i, 1:length(r_IDX_intermedia_i)) = r_IDX_intermedia_i;

    end
end
