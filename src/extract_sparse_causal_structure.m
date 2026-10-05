function [r_B, r_Stru, r_Ord, r_IDX_root, r_IDX_intermedia] = ...
    extract_sparse_causal_structure(p_groups, p_numClusters, W)
% EXTRACT_SPARSE_CAUSAL_STRUCTURE Discover dependencies within metric groups.
%   Sparse Causal Structure Extractor, Step 2 (Section 4.1).
%   Inputs: p_groups contains metric cluster assignments, p_numClusters is
%   their count, and W contains the original metric-by-time training data.
%   Outputs: r_B contains causal weights (row m, column p means p -> m),
%   r_Stru is the binary adjacency, and r_Ord stores within-cluster orders.
%   r_IDX_root lists root metrics; r_IDX_intermedia lists metrics with both
%   parents and children. Zero entries pad the per-cluster output arrays.

    M = size(W,1);
    r_B = zeros(M, M);
    r_Stru = zeros(M, M);
    r_Ord = zeros(p_numClusters, M);

    r_IDX_root = zeros(p_numClusters, M);
    r_IDX_intermedia = zeros(p_numClusters, M);
    for i = 1:p_numClusters
        IDX_i = find(p_groups' == i);
        [r_Stru_i, r_B_i, r_Ord_i] = discover_causal_dependencies(IDX_i, W);

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
