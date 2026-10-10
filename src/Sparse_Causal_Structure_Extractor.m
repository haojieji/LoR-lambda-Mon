function [B, Stru, Ord, IDX_root, IDX_intermedia, IDX_groups, numClusters, eigns] = ...
    Sparse_Causal_Structure_Extractor(X_train)
% SPARSE_CAUSAL_STRUCTURE_EXTRACTOR Learn the SCS from original training data.
%   Paper Section 4.1: first cluster locally correlated metrics, then discover
%   directed dependencies within each cluster. Call before anomaly separation.
%
%   X_train is a metric-by-time matrix of the original training observations.
%   B(m,p) is the fitted weight for p -> m; Stru is its binary adjacency.
%   Ord stores per-cluster causal orders, and IDX_root/IDX_intermedia contain
%   root/intermediate metric identifiers with zero padding. IDX_groups gives
%   cluster assignments; numClusters and eigns describe the clustering.
%   The numerical routines and their parameters are unchanged.

[IDX_groups, numClusters, eigns, ~] = cluster_correlated_metrics(X_train);
[B, Stru, Ord, IDX_root, IDX_intermedia] = ...
    extract_sparse_causal_structure(IDX_groups, numClusters, X_train);
end
