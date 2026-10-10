function [r_B, r_Stru, r_Ord, r_IDX_root, r_IDX_intermedia] = ...
    extract_sparse_causal_structure(p_groups, p_numClusters, W)
% EXTRACT_SPARSE_CAUSAL_STRUCTURE Discover dependencies within metric groups.
%   Sparse Causal Structure Extractor, Step 2 (Section 4.1).
%   W is M-by-N original training data. p_groups is M-by-1 with labels
%   1:p_numClusters. Return M-by-M causal weights r_B and binary adjacency
%   r_Stru in original metric coordinates: (m,p) denotes parent p -> child m.
%   r_Ord, r_IDX_root, and r_IDX_intermedia are p_numClusters-by-M arrays of
%   original metric indices, packed before zero padding. Each r_Ord row is
%   in causal order; intermediate nodes have both parents and children.
%   Per-cluster matrices returned by discover_causal_dependencies instead
%   use positions in r_Ord_i; map both axes back when inserting them below.

    M = size(W,1);
    r_B = zeros(M, M);
    r_Stru = zeros(M, M);
    r_Ord = zeros(p_numClusters, M);

    r_IDX_root = zeros(p_numClusters, M);
    r_IDX_intermedia = zeros(p_numClusters, M);
    for cluster_idx = 1:p_numClusters
        cluster_metric_indices = find(p_groups' == cluster_idx);
        [r_Stru_i, r_B_i, r_Ord_i] = discover_causal_dependencies(cluster_metric_indices, W);

        r_B(r_Ord_i, r_Ord_i) = r_B_i;
        r_Stru(r_Ord_i, r_Ord_i) = r_Stru_i;
        r_Ord(cluster_idx,1:length(r_Ord_i)) = r_Ord_i;

        % Row sums count parents; column sums count children in causal order.
        root_order_positions = find(sum(r_Stru_i, 2) == 0);
        intermediate_order_positions = find(sum(r_Stru_i, 2) > 0 & sum(r_Stru_i, 1)' > 0);

        r_IDX_root_i = r_Ord_i(root_order_positions);
        r_IDX_intermedia_i = r_Ord_i(intermediate_order_positions);
        r_IDX_root(cluster_idx, 1:length(r_IDX_root_i)) = r_IDX_root_i;
        r_IDX_intermedia(cluster_idx, 1:length(r_IDX_intermedia_i)) = r_IDX_intermedia_i;
    end
end
