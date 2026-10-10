function [B, Stru, Ord, IDX_root, IDX_intermedia, IDX_groups, numClusters, eigns] = ...
    Sparse_Causal_Structure_Extractor(X_train)
% SPARSE_CAUSAL_STRUCTURE_EXTRACTOR Learn the sparse causal structure (SCS).
%   Paper Section 4.1: cluster locally correlated metrics, then discover
%   directed dependencies within each cluster, before anomaly separation.
%
%   Input X_train is M-by-N original training data (metrics by time).
%   B and Stru are M-by-M causal weights and binary adjacency: (m,p) means
%   parent p -> child m in original metric coordinates. Ord, IDX_root, and
%   IDX_intermedia are numClusters-by-M arrays of original metric indices,
%   with occupied entries first and zero padding. Ord gives each cluster's
%   causal order; IDX_intermedia selects nodes with both parents and children.
%   IDX_groups is M-by-1, with labels 1:numClusters; eigns is the M-by-1 sorted
%   spectral eigenvalue vector. The public output order is retained.

[IDX_groups, numClusters, eigns, ~] = cluster_correlated_metrics(X_train);
[B, Stru, Ord, IDX_root, IDX_intermedia] = ...
    extract_sparse_causal_structure(IDX_groups, numClusters, X_train);
end
